local Test = require "cosy.server.test"
local Et   = require "etlua"

describe ("client", function ()
  Test.environment.use ()

  local request

  before_each (function ()
    Test.clean_db ()
    local app    = Test.environment.app    ()
    local server = Test.environment.server ()
    local req    = Test.environment.request ()
    if server then
      local url = Et.render ("http://<%- host %>:<%- port %>", {
        host = "localhost",
        port = server.app_port,
      })
      request = function (u, options)
        return req (nil, url .. u, options)
      end
    else
      request = function (u, options)
        return req (app, u, options)
      end
    end
  end)

  before_each (function ()
    local token = Test.make_token (Test.identities.naouna)
    local Client = require "cosy.client"
    local client = Client.new {
      url     = "",
      request = request,
      token   = token,
    }
    local project = client:create_project {
      name        = "naouna",
      description = "Naouna project",
    }
    project:tag  "naouna"
    project:star ()
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
      url     = "",
      request = request,
    }
    assert.is_nil (client.authentified)
    assert.is_not_nil (client.server)
    assert.is_not_nil (client.auth)
  end)

  it ("can be instantiated with authentication", function ()
    local token  = Test.make_token (Test.identities.rahan)
    local Client = require "cosy.client"
    local client = Client.new {
      url     = "",
      request = request,
      token   = token,
    }
    assert.is_not_nil (client.authentified)
    assert.is_not_nil (client.server)
    assert.is_not_nil (client.auth)
  end)

  it ("cannot be instantiated with invalid authentication", function ()
    local token = Test.make_false_token (Test.identities.rahan)
    assert.has.errors (function ()
      local Client = require "cosy.client"
      Client.new {
        url     = "",
        request = request,
        token   = token,
      }
    end)
  end)

  it ("can access server information", function ()
    local Client = require "cosy.client"
    local client = Client.new {
      url     = "",
      request = request,
    }
    local info = client:info ()
    assert.is_not_nil (info.server)
  end)

  -- ======================================================================

  it ("can list tags", function ()
    local token  = Test.make_token (Test.identities.rahan)
    local Client = require "cosy.client"
    local client = Client.new {
      url     = "",
      request = request,
      token   = token,
    }
    for tag in client:tags () do
      assert.is_not_nil (tag.id)
      assert.is_not_nil (tag.count)
    end
  end)

  it ("can get tag information", function ()
    local token  = Test.make_token (Test.identities.rahan)
    local Client = require "cosy.client"
    local client = Client.new {
      url     = "",
      request = request,
      token   = token,
    }
    for tag in client:tagged "naouna" do
      assert.is_not_nil (tag.id)
      assert.is_not_nil (tag.user)
      assert.is_not_nil (tag.project)
    end
  end)

  -- ======================================================================

  it ("can list users", function ()
    local token  = Test.make_token (Test.identities.rahan)
    local Client = require "cosy.client"
    local client = Client.new {
      url     = "",
      request = request,
      token   = token,
    }
    for user in client:users () do
      assert.is_not_nil (user.id)
    end
  end)

  it ("can access user info", function ()
    local token  = Test.make_token (Test.identities.rahan)
    local Client = require "cosy.client"
    local client = Client.new {
      url     = "",
      request = request,
      token   = token,
    }
    local user = client:user (client.authentified.id)
    assert.is_not_nil (user.nickname)
    assert.is_not_nil (user.reputation)
    for _, v in pairs (user) do
      local _ = v
    end
  end)

  it ("can update user info", function ()
    local token  = Test.make_token (Test.identities.rahan)
    local Client = require "cosy.client"
    local client = Client.new {
      url     = "",
      request = request,
      token   = token,
      force   = true,
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
    local token  = Test.make_token (Test.identities.rahan)
    local Client = require "cosy.client"
    local client = Client.new {
      url     = "",
      request = request,
      token   = token,
    }
    client.authentified:delete ()
  end)

  -- ======================================================================

  it ("can create project", function ()
    local token  = Test.make_token (Test.identities.rahan)
    local Client = require "cosy.client"
    local client = Client.new {
      url     = "",
      request = request,
      token   = token,
    }
    client:create_project {}
  end)

  it ("can list projects", function ()
    local token  = Test.make_token (Test.identities.rahan)
    local Client = require "cosy.client"
    local client = Client.new {
      url     = "",
      request = request,
      token   = token,
    }
    for project in client:projects () do
      assert.is_not_nil (project.id)
    end
  end)

  it ("can access project info", function ()
    local token  = Test.make_token (Test.identities.rahan)
    local Client = require "cosy.client"
    local client = Client.new {
      url     = "",
      request = request,
      token   = token,
    }
    local project = client:create_project {
      name        = "name",
      description = "description",
    }
    project = client:project (project.id)
    assert.is_not_nil (project.name)
    assert.is_not_nil (project.description)
    for _, v in pairs (project) do
      assert (v)
    end
  end)

  it ("can update project info", function ()
    local token  = Test.make_token (Test.identities.rahan)
    local Client = require "cosy.client"
    local client = Client.new {
      url     = "",
      request = request,
      token   = token,
    }
    local project = client:create_project ()
    project.name = "my project"
  end)

  it ("can delete project", function ()
    local token  = Test.make_token (Test.identities.rahan)
    local Client = require "cosy.client"
    local client = Client.new {
      url     = "",
      request = request,
      token   = token,
    }
    local project = client:create_project ()
    project:delete ()
  end)

  -- ======================================================================

  it ("can get project tags", function ()
    local token  = Test.make_token (Test.identities.rahan)
    local Client = require "cosy.client"
    local client = Client.new {
      url     = "",
      request = request,
      token   = token,
    }
    local project = client:create_project ()
    project:tag "my-project"
    for tag in project:tags () do
      assert.is_not_nil (tag.id)
      assert.is_not_nil (tag.user)
      assert.is_not_nil (tag.project)
    end
  end)

  it ("can tag project", function ()
    local token  = Test.make_token (Test.identities.rahan)
    local Client = require "cosy.client"
    local client = Client.new {
      url     = "",
      request = request,
      token   = token,
    }
    local project = client:create_project ()
    project:tag "my-tag"
  end)

  it ("can untag project", function ()
    local token  = Test.make_token (Test.identities.rahan)
    local Client = require "cosy.client"
    local client = Client.new {
      url     = "",
      request = request,
      token   = token,
    }
    local project = client:create_project ()
    project:tag   "my-tag"
    project:untag "my-tag"
  end)

  -- ======================================================================

  it ("can get project stars", function ()
    local token  = Test.make_token (Test.identities.rahan)
    local Client = require "cosy.client"
    local client = Client.new {
      url     = "",
      request = request,
      token   = token,
    }
    local project = client:create_project ()
    project:star ()
    for star in project:stars () do
      assert.is_not_nil (star.user_id)
      assert.is_not_nil (star.project_id)
    end
  end)

  it ("can star project", function ()
    local token  = Test.make_token (Test.identities.rahan)
    local Client = require "cosy.client"
    local client = Client.new {
      url     = "",
      request = request,
      token   = token,
    }
    local project = client:create_project ()
    project:star ()
  end)

  it ("can unstar project", function ()
    local token  = Test.make_token (Test.identities.rahan)
    local Client = require "cosy.client"
    local client = Client.new {
      url     = "",
      request = request,
      token   = token,
    }
    local project = client:create_project ()
    project:star   ()
    project:unstar ()
  end)

  -- ======================================================================

  it ("can list permissions", function ()
    local token  = Test.make_token (Test.identities.rahan)
    local Client = require "cosy.client"
    local client = Client.new {
      url     = "",
      request = request,
      token   = token,
    }
    local project = client:create_project ()
    assert.is_not_nil (project.permissions.anonymous)
    assert.is_not_nil (project.permissions.user)
    assert.is_not_nil (project.permissions [project])
    assert.is_not_nil (project.permissions [client.authentified])
    for who, permission in pairs (project.permissions) do
      local _, _ = who, permission
    end
  end)

  it ("can add permission", function ()
    local token  = Test.make_token (Test.identities.rahan)
    local Client = require "cosy.client"
    local client = Client.new {
      url     = "",
      request = request,
      token   = token,
    }
    local naouna
    for user in client:users () do
      if user.id ~= client.authentified.id then
        naouna = user
      end
    end
    local project = client:create_project ()
    project.permissions.anonymous = "read"
    project.permissions.user      = "write"
    project.permissions [naouna]  = "admin"
  end)

  it ("can remove permission", function ()
    local token  = Test.make_token (Test.identities.rahan)
    local Client = require "cosy.client"
    local client = Client.new {
      url     = "",
      request = request,
      token   = token,
    }
    local naouna
    for user in client:users () do
      if user.id ~= client.authentified.id then
        naouna = user
      end
    end
    local project = client:create_project ()
    project.permissions [naouna]  = "admin"
    project.permissions [naouna]  = nil
  end)

  -- ======================================================================

  it ("can create resource", function ()
    local token  = Test.make_token (Test.identities.rahan)
    local Client = require "cosy.client"
    local client = Client.new {
      url     = "",
      request = request,
      token   = token,
    }
    local project = client:create_project {}
    project:create_resource {}
  end)

  it ("can list resources", function ()
    local token  = Test.make_token (Test.identities.rahan)
    local Client = require "cosy.client"
    local client = Client.new {
      url     = "",
      request = request,
      token   = token,
    }
    local project = client:create_project {}
    project:create_resource {
      name        = "name",
      description = "description",
    }
    for resource in project:resources () do
      assert.is_not_nil (resource.id)
      assert.is_not_nil (resource.name)
      assert.is_not_nil (resource.description)
    end
  end)

  it ("can access resource info", function ()
    local token  = Test.make_token (Test.identities.rahan)
    local Client = require "cosy.client"
    local client = Client.new {
      url     = "",
      request = request,
      token   = token,
    }
    local project = client:create_project {}
    project:create_resource {
      name        = "name",
      description = "description",
    }
    for resource in project:resources () do
      assert.is_not_nil (resource.name)
      assert.is_not_nil (resource.description)
      for _, v in pairs (resource) do
        assert (v)
      end
    end
  end)

  it ("can update resource info", function ()
    local token  = Test.make_token (Test.identities.rahan)
    local Client = require "cosy.client"
    local client = Client.new {
      url     = "",
      request = request,
      token   = token,
    }
    local project  = client:create_project {}
    local resource = project:create_resource {}
    resource.name = "name"
  end)

  it ("can delete resource", function ()
    local token  = Test.make_token (Test.identities.rahan)
    local Client = require "cosy.client"
    local client = Client.new {
      url     = "",
      request = request,
      token   = token,
    }
    local project  = client:create_project {}
    local resource = project:create_resource {}
    resource:delete ()
  end)

  -- ======================================================================

end)
