local _       = require "copas"
local Et      = require "etlua"
local Hashids = require "hashids"
local Json    = require "cjson"
local Jwt     = require "jwt"
local Mime    = require "mime"
local Time    = require "socket".gettime
local Http    = require "cosy.client.http"

local Config = {
  auth0       = {
    domain        = assert (os.getenv "AUTH0_DOMAIN"),
    client_id     = assert (os.getenv "AUTH0_ID"    ),
    client_secret = assert (os.getenv "AUTH0_SECRET"),
    api_token     = assert (os.getenv "AUTH0_TOKEN" ),
  },
  docker      = {
    username = assert (os.getenv "DOCKER_USER"  ),
    api_key  = assert (os.getenv "DOCKER_SECRET"),
  },
}

local identities = {
  rahan  = "github|1818862",
  crao   = "google-oauth2|103410538451613086005",
  naouna = "twitter|2572672862",
}

local function make_token (subject, contents, duration)
  local claims = {
    iss = Config.auth0.domain,
    aud = Config.auth0.client_id,
    sub = subject,
    exp = duration and duration ~= math.huge and Time () + duration,
    iat = Time (),
    contents = contents,
  }
  return Jwt.encode (claims, {
    alg = "HS256",
    keys = { private = Config.auth0.client_secret },
  })
end

local function make_false_token (subject, contents, duration)
  local claims = {
    iss = Config.auth0.domain,
    aud = Config.auth0.client_id,
    sub = subject,
    exp = duration and duration ~= math.huge and Time () + duration,
    iat = Time (),
    contents = contents,
  }
  return Jwt.encode (claims, {
    alg = "HS256",
    keys = { private = Config.auth0.client_id },
  })
end

local branch = assert (os.getenv "COSY_BRANCH" or os.getenv "WERCKER_GIT_BRANCH")
if not branch or branch == "master" then
  local file = assert (io.popen ("git rev-parse --abbrev-ref HEAD", "r"))
  branch = assert (file:read "*line")
  file:close ()
end

describe ("cosy client", function ()

  local server_url, docker_url
  local headers = {
    ["Authorization"] = "Basic " .. Mime.b64 (Config.docker.username .. ":" .. Config.docker.api_key),
    ["Accept"       ] = "application/json",
    ["Content-type" ] = "application/json",
  }

  setup (function ()
    local url = "https://cloud.docker.com"
    local api = url .. "/api/app/v1"
    -- Create service:
    local id  = branch .. "-" .. Hashids.new (tostring (os.time ())):encode (666)
    local stack, stack_status = Http.json {
      url     = api .. "/stack/",
      method  = "POST",
      headers = headers,
      body    = {
        name     = id,
        services = {
          { name  = "database",
            image = "postgres",
          },
          { name  = "api",
            image = Et.render ("cosyverif/server:<%- branch %>", {
              branch = branch,
            }),
            ports = {
              "8080",
            },
            links = {
              "database",
            },
            environment = {
              RESOLVERS         = "127.0.0.11",
              COSY_PREFIX       = "/usr/local",
              COSY_HOST         = "api:8080",
              COSY_BRANCH       = branch,
              POSTGRES_HOST     = "database",
              POSTGRES_USER     = "postgres",
              POSTGRES_PASSWORD = "",
              POSTGRES_DATABASE = "postgres",
              AUTH0_DOMAIN      = Config.auth0.domain,
              AUTH0_ID          = Config.auth0.client_id,
              AUTH0_SECRET      = Config.auth0.client_secret,
              AUTH0_TOKEN       = Config.auth0.api_token,
              DOCKER_USER       = Config.docker.username,
              DOCKER_SECRET     = Config.docker.api_key,
            },
          },
        },
      },
    }
    assert (stack_status == 201)
    -- Start service:
    local resource = url .. stack.resource_uri
    local _, started_status = Http.json {
      url        = resource .. "start/",
      method     = "POST",
      headers    = headers,
      timeout    = 5, -- seconds
    }
    assert (started_status == 202)
    local services
    do
      local result, status
      while true do
        result, status = Http.json {
          url     = resource,
          method  = "GET",
          headers = headers,
        }
        if status == 200 and result.state:lower () ~= "starting" then
          services = result.services
          break
        else
          os.execute "sleep 1"
        end
      end
      assert (result.state:lower () == "running")
    end
    for _, path in ipairs (services) do
      local service, service_status = Http.json {
        url     = url .. path,
        method  = "GET",
        headers = headers,
      }
      assert (service_status == 200)
      if service.name == "api" then
        local container, container_status = Http.json {
          url     = url .. service.containers [1],
          method  = "GET",
          headers = headers,
        }
        assert (container_status == 200)
        docker_url = resource
        for _, port in ipairs (container.container_ports) do
          local endpoint = port.endpoint_uri
          if endpoint and endpoint ~= Json.null then
            if endpoint:sub (-1) == "/" then
              endpoint = endpoint:sub (1, #endpoint-1)
            end
            server_url = endpoint
            for _ = 1, 5 do
              local _, status = Http.json {
                url     = server_url,
                method  = "GET",
              }
              if status == 200 then
                return
              else
                os.execute "sleep 1"
              end
            end
            assert (false)
          end
        end
      end
    end
    assert (false)
  end)

  teardown (function ()
    while true do
      local _, deleted_status = Http.json {
        url     = docker_url,
        method  = "DELETE",
        headers = headers,
      }
      if deleted_status == 202 or deleted_status == 404 then
        break
      else
        os.execute "sleep 1"
      end
    end
  end)

  -- ======================================================================

  it ("can be required", function ()
    assert.has.no.errors (function ()
      require "cosy.client"
    end)
  end)

  it ("can be instantiated without authentication", function ()
    local Client = require "cosy.client"
    local client = Client.new {
      url = server_url,
    }
    assert.is_nil (client.authentified)
    assert.is_not_nil (client.server)
    assert.is_not_nil (client.auth)
  end)

  it ("can be instantiated with authentication", function ()
    local token  = make_token (identities.rahan)
    local Client = require "cosy.client"
    local client = Client.new {
      url   = server_url,
      token = token,
    }
    assert.is_not_nil (client.authentified)
    assert.is_not_nil (client.server)
    assert.is_not_nil (client.auth)
  end)

  it ("cannot be instantiated with invalid authentication", function ()
    local token = make_false_token (identities.rahan)
    assert.has.errors (function ()
      local Client = require "cosy.client"
      Client.new {
        url   = server_url,
        token = token,
      }
    end)
  end)

  it ("can access server information", function ()
    local Client = require "cosy.client"
    local client = Client.new {
      url = server_url,
    }
    local info = client:info ()
    assert.is_not_nil (info.server)
  end)

  -- ======================================================================

  it ("can list tags", function ()
    local token  = make_token (identities.rahan)
    local Client = require "cosy.client"
    local client = Client.new {
      url   = server_url,
      token = token,
    }
    local project = client:create_project {}
    local count   = 0
    project:tag "something"
    for tag in client:tags () do
      assert.is_not_nil (tag.id)
      assert.is_not_nil (tag.count)
      count = count + 1
    end
    assert.are.equal (count, 1)
    project:delete ()
  end)

  it ("can get tag information", function ()
    local token  = make_token (identities.rahan)
    local Client = require "cosy.client"
    local client = Client.new {
      url   = server_url,
      token = token,
    }
    local project = client:create_project {}
    local count   = 0
    project:tag "something"
    for tag in client:tagged "something" do
      assert.is_not_nil (tag.id)
      assert.is_not_nil (tag.user)
      assert.is_not_nil (tag.project)
      count = count + 1
    end
    assert.are.equal (count, 1)
    project:delete ()
  end)

  -- ======================================================================

  it ("can list users", function ()
    local token  = make_token (identities.rahan)
    local Client = require "cosy.client"
    local client = Client.new {
      url   = server_url,
      token = token,
    }
    for user in client:users () do
      assert.is_not_nil (user.id)
    end
  end)

  it ("can access user info", function ()
    local token  = make_token (identities.rahan)
    local Client = require "cosy.client"
    local client = Client.new {
      url   = server_url,
      token = token,
    }
    local user  = client:user (client.authentified.id)
    local count = 0
    assert.is_not_nil (user.nickname)
    assert.is_not_nil (user.reputation)
    for _, v in user:__pairs () do
      local _ = v
      count = count + 1
    end
    assert.is_truthy (count > 0)
  end)

  it ("can update user info", function ()
    local token  = make_token (identities.rahan)
    local Client = require "cosy.client"
    local client = Client.new {
      url   = server_url,
      token = token,
    }
    for user in client:users () do
      if user.nickname == "saucisson" then
        assert.has.no.error (function ()
          user.reputation = 100
        end)
      end
    end
  end)

  it ("can delete user", function ()
    local token  = make_token (identities.rahan)
    local Client = require "cosy.client"
    local client = Client.new {
      url   = server_url,
      token = token,
    }
    client.authentified:delete ()
  end)

  -- ======================================================================

  it ("can create project", function ()
    local token  = make_token (identities.rahan)
    local Client = require "cosy.client"
    local client = Client.new {
      url   = server_url,
      token = token,
    }
    local project = client:create_project {}
    project:delete ()
  end)

  it ("can list projects", function ()
    local token  = make_token (identities.rahan)
    local Client = require "cosy.client"
    local client = Client.new {
      url   = server_url,
      token = token,
    }
    local project = client:create_project {}
    local count   = 0
    for p in client:projects () do
      assert.is_not_nil (p.id)
      count = count + 1
    end
    assert.are.equal (count, 1)
    project:delete ()
  end)

  it ("can access project info", function ()
    local token  = make_token (identities.rahan)
    local Client = require "cosy.client"
    local client = Client.new {
      url   = server_url,
      token = token,
    }
    local project = client:create_project {
      name        = "name",
      description = "description",
    }
    project = client:project (project.id)
    assert.is_not_nil (project.name)
    assert.is_not_nil (project.description)
    for _, v in project:__pairs () do
      assert (v)
    end
    project:delete ()
  end)

  it ("can update project info", function ()
    local token  = make_token (identities.rahan)
    local Client = require "cosy.client"
    local client = Client.new {
      url   = server_url,
      token = token,
    }
    local project = client:create_project ()
    project.name = "my project"
    project:delete ()
  end)

  it ("can delete project", function ()
    local token  = make_token (identities.rahan)
    local Client = require "cosy.client"
    local client = Client.new {
      url   = server_url,
      token = token,
    }
    local project = client:create_project ()
    project:delete ()
  end)

  -- ======================================================================

  it ("can get project tags", function ()
    local token  = make_token (identities.rahan)
    local Client = require "cosy.client"
    local client = Client.new {
      url   = server_url,
      token = token,
    }
    local project = client:create_project ()
    local count   = 0
    project:tag "my-project"
    for tag in project:tags () do
      assert.is_not_nil (tag.id)
      assert.is_not_nil (tag.user)
      assert.is_not_nil (tag.project)
      count = count + 1
    end
    assert.are.equal (count, 1)
    project:delete ()
  end)

  it ("can tag project", function ()
    local token  = make_token (identities.rahan)
    local Client = require "cosy.client"
    local client = Client.new {
      url   = server_url,
      token = token,
    }
    local project = client:create_project ()
    project:tag "my-tag"
    project:delete ()
  end)

  it ("can untag project", function ()
    local token  = make_token (identities.rahan)
    local Client = require "cosy.client"
    local client = Client.new {
      url   = server_url,
      token = token,
    }
    local project = client:create_project ()
    project:tag   "my-tag"
    project:untag "my-tag"
    project:delete ()
  end)

  -- ======================================================================

  it ("can get project stars", function ()
    local token  = make_token (identities.rahan)
    local Client = require "cosy.client"
    local client = Client.new {
      url   = server_url,
      token = token,
    }
    local project = client:create_project ()
    local count   = 0
    project:star ()
    for star in project:stars () do
      assert.is_not_nil (star.user_id)
      assert.is_not_nil (star.project_id)
      count = count + 1
    end
    assert.are.equal (count, 1)
    project:delete ()
  end)

  it ("can star project", function ()
    local token  = make_token (identities.rahan)
    local Client = require "cosy.client"
    local client = Client.new {
      url   = server_url,
      token = token,
    }
    local project = client:create_project ()
    project:star ()
    project:delete ()
  end)

  it ("can unstar project", function ()
    local token  = make_token (identities.rahan)
    local Client = require "cosy.client"
    local client = Client.new {
      url   = server_url,
      token = token,
    }
    local project = client:create_project ()
    project:star   ()
    project:unstar ()
    project:delete ()
  end)

  -- ======================================================================

  it ("can list permissions", function ()
    local token  = make_token (identities.rahan)
    local Client = require "cosy.client"
    local client = Client.new {
      url   = server_url,
      token = token,
    }
    local project = client:create_project ()
    assert.is_not_nil (project.permissions.anonymous)
    assert.is_not_nil (project.permissions.user)
    assert.is_not_nil (project.permissions [project])
    assert.is_not_nil (project.permissions [client.authentified])
    for who, permission in project.permissions:__pairs () do
      local _, _ = who, permission
    end
    project:delete ()
  end)

  it ("can add permission", function ()
    local token  = make_token (identities.rahan)
    local Client = require "cosy.client"
    local client = Client.new {
      url   = server_url,
      token = token,
    }
    local naouna = Client.new {
      url   = server_url,
      token = make_token (identities.naouna),
    }.authentified
    local project = client:create_project ()
    project.permissions.anonymous = "read"
    project.permissions.user      = "write"
    project.permissions [naouna]  = "admin"
    project:delete ()
  end)

  it ("can remove permission", function ()
    local token  = make_token (identities.rahan)
    local Client = require "cosy.client"
    local client = Client.new {
      url   = server_url,
      token = token,
    }
    local naouna = Client.new {
      url   = server_url,
      token = make_token (identities.naouna),
    }.authentified
    local project = client:create_project ()
    project.permissions [naouna]  = "admin"
    project.permissions [naouna]  = nil
    project:delete ()
  end)

  -- ======================================================================

  it ("can create resource", function ()
    local token  = make_token (identities.rahan)
    local Client = require "cosy.client"
    local client = Client.new {
      url   = server_url,
      token = token,
    }
    local project = client:create_project {}
    project:create_resource {}
    project:delete ()
  end)

  it ("can list resources", function ()
    local token  = make_token (identities.rahan)
    local Client = require "cosy.client"
    local client = Client.new {
      url   = server_url,
      token = token,
    }
    local project = client:create_project {}
    project:create_resource {
      name        = "name",
      description = "description",
    }
    local count = 0
    for resource in project:resources () do
      assert.is_not_nil (resource.id)
      assert.is_not_nil (resource.name)
      assert.is_not_nil (resource.description)
      count = count + 1
    end
    assert.are.equal (count, 1)
    project:delete ()
  end)

  it ("can access resource info", function ()
    local token  = make_token (identities.rahan)
    local Client = require "cosy.client"
    local client = Client.new {
      url   = server_url,
      token = token,
    }
    local project = client:create_project {}
    project:create_resource {
      name        = "name",
      description = "description",
    }
    for resource in project:resources () do
      assert.is_not_nil (resource.name)
      assert.is_not_nil (resource.description)
      for _, v in resource:__pairs () do
        assert (v)
      end
    end
    project:delete ()
  end)

  it ("can update resource info", function ()
    local token  = make_token (identities.rahan)
    local Client = require "cosy.client"
    local client = Client.new {
      url   = server_url,
      token = token,
    }
    local project  = client :create_project  {}
    local resource = project:create_resource {}
    resource.name = "name"
    project:delete ()
  end)

  it ("can delete resource", function ()
    local token  = make_token (identities.rahan)
    local Client = require "cosy.client"
    local client = Client.new {
      url   = server_url,
      token = token,
    }
    local project  = client :create_project  {}
    local resource = project:create_resource {}
    resource:delete ()
    project:delete ()
  end)

  -- ======================================================================

  it ("can create execution (resource variant)", function ()
    local token  = make_token (identities.rahan)
    local Client = require "cosy.client"
    local client = Client.new {
      url   = server_url,
      token = token,
    }
    local project  = client :create_project  {}
    local resource = project:create_resource {}
    resource:execute "sylvainlasnier/echo"
    project:delete ()
  end)

  it ("can create execution (project variant)", function ()
    local token  = make_token (identities.rahan)
    local Client = require "cosy.client"
    local client = Client.new {
      url   = server_url,
      token = token,
    }
    local project  = client :create_project  {}
    local resource = project:create_resource {}
    project:execute (resource, "sylvainlasnier/echo")
    project:delete ()
  end)

  it ("can list executions", function ()
    local token  = make_token (identities.rahan)
    local Client = require "cosy.client"
    local client = Client.new {
      url   = server_url,
      token = token,
    }
    local project  = client :create_project  {}
    local resource = project:create_resource {}
    resource:execute ("sylvainlasnier/echo", {
      name        = "name",
      description = "description",
    })
    local count = 0
    for execution in project:executions () do
      assert.is_not_nil (execution.id)
      assert.is_not_nil (execution.name)
      assert.is_not_nil (execution.description)
      count = count + 1
    end
    assert.are.equal (count, 1)
    project:delete ()
  end)

  it ("can access execution info", function ()
    local token  = make_token (identities.rahan)
    local Client = require "cosy.client"
    local client = Client.new {
      url   = server_url,
      token = token,
    }
    local project  = client :create_project  {}
    local resource = project:create_resource {}
    resource:execute ("sylvainlasnier/echo", {
      name        = "name",
      description = "description",
    })
    for execution in project:executions () do
      assert.is_not_nil (execution.name)
      assert.is_not_nil (execution.description)
      for _, v in execution:__pairs () do
        assert (v)
      end
    end
    project:delete ()
  end)

  it ("can update execution info", function ()
    local token  = make_token (identities.rahan)
    local Client = require "cosy.client"
    local client = Client.new {
      url   = server_url,
      token = token,
    }
    local project   = client :create_project  {}
    local resource  = project:create_resource {}
    local execution = resource:execute ("sylvainlasnier/echo")
    execution.name = "name"
    project:delete ()
  end)

  it ("can delete execution", function ()
    local token  = make_token (identities.rahan)
    local Client = require "cosy.client"
    local client = Client.new {
      url   = server_url,
      token = token,
    }
    local project   = client :create_project  {}
    local resource  = project:create_resource {}
    local execution = resource:execute ("sylvainlasnier/echo")
    execution:delete ()
    project:delete ()
  end)

  -- ======================================================================

end)
