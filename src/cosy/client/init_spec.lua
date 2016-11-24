local oldprint = print
_G.print = function (...)
  oldprint (...)
  io.stdout:flush ()
end
local Coromake  = require "coroutine.make"
_G.coroutine    = Coromake ()
local Copas     = require "copas"
local Jwt       = require "jwt"
local Time      = require "socket".gettime
local Http      = require "cosy.client.http"
local Instance  = require "cosy.instance"

local Config = {
  num_workers = 1,
  mode        = "development",
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

describe ("cosy client", function ()

  local instance, server_url

  setup (function ()
    instance   = Instance.create (Config)
    server_url = instance.server
  end)

  teardown (function ()
    while true do
      local info, status = Http.json {
        url    = server_url,
        method = "GET",
      }
      assert.are.equal (status, 200)
      if info.stats.services == 0 then
        break
      end
      os.execute [[ sleep 1 ]]
    end
  end)

  teardown (function ()
    instance:delete ()
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
      assert.is_not_nil (star.user)
      assert.is_not_nil (star.project)
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

  it ("can create alias", function ()
    local token  = make_token (identities.rahan)
    local Client = require "cosy.client"
    local client = Client.new {
      url   = server_url,
      token = token,
    }
    local project  = client:create_project {}
    local resource = project:create_resource {}
    resource:alias "my-alias"
    project:delete ()
  end)

  it ("can list aliases", function ()
    local token  = make_token (identities.rahan)
    local Client = require "cosy.client"
    local client = Client.new {
      url   = server_url,
      token = token,
    }
    local project  = client:create_project {}
    local resource = project:create_resource {}
    resource:alias "my-alias"
    local count = 0
    for alias, r in resource:aliases () do
      assert.are.equal (alias, "my-alias")
      assert.are.equal (resource.id, r.id)
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

  -- ======================================================================

  it ("can create execution", function ()
    local token  = make_token (identities.rahan)
    local Client = require "cosy.client"
    local client = Client.new {
      url   = server_url,
      token = token,
    }
    local project   = client :create_project  {}
    local resource  = project:create_resource {}
    local execution = resource:execute "sylvainlasnier/echo"
    execution:delete () -- FIXME: should be replaced by project:delete ()
  end)

  it ("can list executions", function ()
    local token  = make_token (identities.rahan)
    local Client = require "cosy.client"
    local client = Client.new {
      url   = server_url,
      token = token,
    }
    local project   = client :create_project  {}
    local resource  = project:create_resource {}
    local execution = resource:execute ("sylvainlasnier/echo", {
      name        = "name",
      description = "description",
    })
    local count = 0
    for e in resource:executions () do
      assert.is_not_nil (e.id)
      assert.is_not_nil (e.name)
      assert.is_not_nil (e.description)
      count = count + 1
    end
    assert.are.equal (count, 1)
    execution:delete () -- FIXME: should be replaced by project:delete ()
  end)

  it ("can access execution info", function ()
    local token  = make_token (identities.rahan)
    local Client = require "cosy.client"
    local client = Client.new {
      url   = server_url,
      token = token,
    }
    local project   = client :create_project  {}
    local resource  = project:create_resource {}
    local execution = resource:execute ("sylvainlasnier/echo", {
      name        = "name",
      description = "description",
    })
    for e in resource:executions () do
      assert.is_not_nil (e.name)
      assert.is_not_nil (e.description)
      for _, v in e:__pairs () do
        assert (v)
      end
    end
    execution:delete () -- FIXME: should be replaced by project:delete ()
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
    execution:delete () -- FIXME: should be replaced by project:delete ()
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
    execution:delete () -- FIXME: should be replaced by project:delete ()
  end)

  -- ======================================================================

  it ("can create editor", function ()
    local token  = make_token (identities.rahan)
    local Client = require "cosy.client"
    local client = Client.new {
      url   = server_url,
      token = token,
    }
    local project  = client :create_project  {}
    local resource = project:create_resource {}
    local result   = false
    Copas.addthread (function ()
      local editor = resource:edit ()
      result = true
      editor:close ()
    end)
    Copas.loop ()
    assert.is_truthy (result)
  end)

  it ("can modify the model", function ()
    local token  = make_token (identities.rahan)
    local Client = require "cosy.client"
    local client = Client.new {
      url   = server_url,
      token = token,
    }
    local project  = client :create_project  {}
    local resource = project:create_resource {}
    local current  = false
    local remote   = false
    Copas.addthread (function ()
      local editor = resource:edit ()
      editor (function (_, layer, _)
        layer.mydata = 1
      end)
      while not editor.remote.layer.mydata do
        editor:wait (function (_, key) return key == "mydata" end)
      end
      current = editor.current.layer.mydata
      remote  = editor.remote .layer.mydata
      editor:close ()
    end)
    Copas.loop ()
    assert.are.equal (current, 1)
    assert.are.equal (remote , 1)
  end)

  it ("can require a submodel", function ()
    local token  = make_token (identities.rahan)
    local Client = require "cosy.client"
    local client = Client.new {
      url   = server_url,
      token = token,
    }
    local project  = client :create_project  {}
    local toload   = project:create_resource {}
    local resource = project:create_resource {}
    local model    = false
    local loaded   = false
    Copas.addthread (function ()
      local editor = resource:edit ()
      editor (function (L, layer, _)
        layer.mydata = L.require (toload.cli_id)
      end)
      while not editor.remote.layer.mydata do
        editor:wait (function (_, key) return key == "mydata" end)
      end
      model  = editor.remote.layer
      loaded = editor.remote.layer.mydata
      editor:close ()
    end)
    Copas.loop ()
    assert.is_not_nil (model)
    assert.is_not_nil (loaded)
  end)

  it ("can modify concurrently the model", function ()
    local token  = make_token (identities.rahan)
    local Client = require "cosy.client"
    local client = Client.new {
      url   = server_url,
      token = token,
    }
    local project  = client :create_project  {}
    local resource = project:create_resource {}
    local results  = {}
    Copas.addthread (function ()
      local editor = resource:edit ()
      editor (function (_, layer)
        layer.mydata = 1
      end)
      while editor.remote.layer.mydata ~= 2 do
        editor:wait (function (_, key) return key == "mydata" end)
      end
      results [1] = {
        current = editor.current,
        remote  = editor.remote,
      }
      editor:close ()
    end)
    Copas.addthread (function ()
      local editor = resource:edit ()
      while editor.remote.layer.mydata ~= 1 do
        editor:wait (function (_, key) return key == "mydata" end)
      end
      editor (function (_, layer)
        layer.mydata = 2
      end)
      while editor.remote.layer.mydata ~= 2 do
        editor:wait (function (_, key) return key == "mydata" end)
      end
      results [2] = {
        current = editor.current,
        remote  = editor.remote,
      }
      editor:close ()
    end)
    Copas.loop ()
    assert.are.equal (results [1].current.layer.mydata, results [1].remote.layer.mydata)
    assert.are.equal (results [2].current.layer.mydata, results [2].remote.layer.mydata)
    assert.are.equal (results [1].current.layer.mydata, results [2].current.layer.mydata)
    assert.are.equal (results [1].current.layer.mydata, 2)
  end)

end)
