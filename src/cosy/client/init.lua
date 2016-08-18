local Coromake  = require "coroutine.make"
_G.coroutine    = Coromake ()
local Copas     = require "copas"
local Json      = require "dkjson"
local Layer     = require "layeredata"
local Websocket = require "websocket"
local Http      = require "cosy.client.http"

local function assert (condition, err)
  if not condition then
    error (err)
  end
end

local Resource    = {}
local Permissions = {}
local User        = {}
local Project     = {}
local Client      = {}

Client.__index = Client

function Client.new (options)
  local result = setmetatable ({
    url     = options.url,
    token   = options.token,
    force   = options.force,
    unique  = {
      users     = setmetatable ({}, { __mode = "v" }),
      projects  = setmetatable ({}, { __mode = "v" }),
      resources = setmetatable ({}, { __mode = "v" }),
    },
  }, Client)
  local info, status = Http.json {
    url     = result.url,
    method  = "GET",
    headers = {
      Authorization = result.token and "Bearer " .. result.token,
    },
  }
  assert (status == 200, { status = status })
  for k, v in pairs (info) do
    result [k] = v
  end
  if info.authentified then
    result.authentified = User.__new (result, info.authentified.id)
  end
  return result
end

function Client.info (client)
  assert (getmetatable (client) == Client)
  local data, status = Http.json {
    url     = client.url,
    method  = "GET",
    headers = {
      Authorization = client.token and "Bearer " .. client.token,
    },
  }
  assert (status == 200, { status = status })
  return data
end

function Client.tags (client)
  assert (getmetatable (client) == Client)
  local data, status = Http.json {
    url     = client.url .. "/tags/",
    method  = "GET",
    headers = {
      Authorization = client.token and "Bearer " .. client.token,
    },
  }
  assert (status == 200, { status = status })
  local coroutine = Coromake ()
  return coroutine.wrap (function ()
    for _, tag in ipairs (data) do
      coroutine.yield {
        client = client,
        id     = tag.id,
        count  = tag.count,
      }
    end
  end)
end

function Client.tagged (client, tag)
  assert (getmetatable (client) == Client)
  local data, status = Http.json {
    url     = client.url .. "/tags/" .. tag,
    method  = "GET",
    headers = {
      Authorization = client.token and "Bearer " .. client.token,
    },
  }
  assert (status == 200, { status = status })
  local coroutine = Coromake ()
  return coroutine.wrap (function ()
    for _, t in ipairs (data) do
      coroutine.yield {
        id      = t.id,
        user    = User   .__new (client, t.user_id),
        project = Project.__new (client, t.project_id),
        data    = false,
      }
    end
  end)
end

function Client.users (client)
  assert (getmetatable (client) == Client)
  local data, status = Http.json {
    url     = client.url .. "/users/",
    method  = "GET",
    headers = {
      Authorization = client.token and "Bearer " .. client.token,
    },
  }
  assert (status == 200, { status = status })
  local coroutine = Coromake ()
  return coroutine.wrap (function ()
    for _, user in ipairs (data) do
      coroutine.yield (User.__new (client, user.id))
    end
  end)
end

function Client.user (client, id)
  assert (getmetatable (client) == Client)
  local user = User.__new (client, id)
  User.load (user)
  return user
end

function User.__new (client, id)
  assert (getmetatable (client) == Client)
  local result = client.unique.users [id]
  if not result then
    result = setmetatable ({
      client = client,
      id     = id,
      data   = false,
    }, User)
    client.unique.users [id] = result
  end
  return result
end

function User.load (user)
  assert (getmetatable (user) == User)
  if user.data then
    return user
  end
  local client = user.client
  local data, status = Http.json {
    url     = client.url .. "/users/" .. user.id,
    method  = "GET",
    headers = {
      Authorization = client.token and "Bearer " .. client.token,
    },
  }
  assert (status == 200, { status = status })
  user.data = data
  return user
end

function User.delete (user)
  assert (getmetatable (user) == User)
  local client    = user.client
  local _, status = Http.json {
    url     = client.url .. "/users/" .. user.id,
    method  = "DELETE",
    headers = {
      Authorization = client.token and "Bearer " .. client.token,
    },
  }
  assert (status == 204, { status = status })
  user.data = false
end

function User.__index (user, key)
  assert (getmetatable (user) == User)
  if User [key] then
    return User [key]
  end
  User.load (user)
  return user.data [key]
end

function User.__newindex (user, key, value)
  assert (getmetatable (user) == User)
  User.load (user)
  local client    = user.client
  local _, status = Http.json {
    url     = client.url .. "/users/" .. user.id,
    method  = "PATCH",
    headers = {
      Authorization = client.token and "Bearer " .. client.token,
    },
    body    = {
      [key] = value,
    }
  }
  assert (status == 204, { status = status })
  user.data = false
end

function User.__pairs (user)
  assert (getmetatable (user) == User)
  User.load (user)
  local coroutine = Coromake ()
  return coroutine.wrap (function ()
    coroutine.yield ("client", user.client)
    if user.data then
      for key, value in pairs (user.data) do
        coroutine.yield (key, value)
      end
    end
  end)
end

function Client.projects (client)
  assert (getmetatable (client) == Client)
  local data, status = Http.json {
    url     = client.url .. "/projects/",
    method  = "GET",
    headers = {
      Authorization = client.token and "Bearer " .. client.token,
    },
  }
  assert (status == 200, { status = status })
  local coroutine = Coromake ()
  return coroutine.wrap (function ()
    for _, project in ipairs (data) do
      coroutine.yield (Project.__new (client, project.id))
    end
  end)
end

function Client.project (client, id)
  assert (getmetatable (client) == Client)
  local project = Project.__new (client, id)
  Project.load (project)
  return project
end

function Client.create_project (client, t)
  assert (getmetatable (client) == Client)
  t = t or {}
  local data, status = Http.json {
    url     = client.url .. "/projects/",
    method  = "POST",
    headers = {
      Authorization = client.token and "Bearer " .. client.token,
    },
    body    = t,
  }
  assert (status == 201, { status = status })
  return Project.__new (client, data.id)
end

function Project.__new (client, id)
  assert (getmetatable (client) == Client)
  local result = client.unique.projects [id]
  if not result then
    result = {
      client = client,
      id     = id,
      data   = false,
    }
    result.permissions = setmetatable ({
      client  = client,
      project = result,
      data    = false,
    }, Permissions)
    result = setmetatable (result, Project)
    client.unique.projects [id] = result
  end
  return result
end

function Project.load (project)
  assert (getmetatable (project) == Project)
  if project.data then
    return project
  end
  local client = project.client
  local data, status = Http.json {
    url     = client.url .. "/projects/" .. project.id,
    method  = "GET",
    headers = {
      Authorization = client.token and "Bearer " .. client.token,
    },
  }
  assert (status == 200, { status = status })
  project.data = data
  return project
end

function Project.delete (project)
  assert (getmetatable (project) == Project)
  local client    = project.client
  local _, status = Http.json {
    url     = client.url .. "/projects/" .. project.id,
    method  = "DELETE",
    headers = {
      Authorization = client.token and "Bearer " .. client.token,
    },
  }
  assert (status == 204, { status = status })
  project.data = false
end

function Project.__index (project, key)
  assert (getmetatable (project) == Project)
  if Project [key] then
    return Project [key]
  end
  Project.load (project)
  return project.data [key]
end

function Project.__newindex (project, key, value)
  assert (getmetatable (project) == Project)
  Project.load (project)
  local client    = project.client
  local _, status = Http.json {
    url     = client.url .. "/projects/" .. project.id,
    method  = "PATCH",
    headers = {
      Authorization = client.token and "Bearer " .. client.token,
    },
    body    = {
      [key] = value,
    }
  }
  assert (status == 204, { status = status })
  project.data = false
end

function Project.__pairs (project)
  assert (getmetatable (project) == Project)
  Project.load (project)
  local coroutine = Coromake ()
  return coroutine.wrap (function ()
    coroutine.yield ("client", project.client)
    if project.data then
      for key, value in pairs (project.data) do
        coroutine.yield (key, value)
      end
    end
  end)
end

function Project.tags (project)
  assert (getmetatable (project) == Project)
  local client = project.client
  local data, status = Http.json {
    url     = client.url .. "/projects/" .. project.id .. "/tags/",
    method  = "GET",
    headers = {
      Authorization = client.token and "Bearer " .. client.token,
    },
  }
  assert (status == 200, { status = status })
  local coroutine = Coromake ()
  return coroutine.wrap (function ()
    for _, tag in ipairs (data) do
      coroutine.yield {
        id      = tag.id,
        user    = User   .__new (client, tag.user_id),
        project = Project.__new (client, tag.project_id),
        data    = false,
      }
    end
  end)
end

function Project.tag (project, tag)
  assert (getmetatable (project) == Project)
  local client    = project.client
  local _, status = Http.json {
    url     = client.url .. "/projects/" .. project.id .. "/tags/" .. tag,
    method  = "PUT",
    headers = {
      Authorization = client.token and "Bearer " .. client.token,
    },
  }
  assert (status == 201 or status == 202, { status = status })
  return project
end

function Project.untag (project, tag)
  assert (getmetatable (project) == Project)
  local client    = project.client
  local _, status = Http.json {
    url     = client.url .. "/projects/" .. project.id .. "/tags/" .. tag,
    method  = "DELETE",
    headers = {
      Authorization = client.token and "Bearer " .. client.token,
    },
  }
  assert (status == 204, { status = status })
  return project
end

function Project.stars (project)
  assert (getmetatable (project) == Project)
  local client = project.client
  local data, status = Http.json {
    url     = client.url .. "/projects/" .. project.id .. "/stars",
    method  = "GET",
    headers = {
      Authorization = client.token and "Bearer " .. client.token,
    },
  }
  assert (status == 200, { status = status })
  local coroutine = Coromake ()
  return coroutine.wrap (function ()
    for _, star in ipairs (data) do
      coroutine.yield (star)
    end
  end)
end

function Project.star (project)
  assert (getmetatable (project) == Project)
  local client    = project.client
  local _, status = Http.json {
    url     = client.url .. "/projects/" .. project.id .. "/stars",
    method  = "PUT",
    headers = {
      Authorization = client.token and "Bearer " .. client.token,
    },
  }
  assert (status == 201 or status == 202, { status = status })
  return project
end

function Project.unstar (project)
  assert (getmetatable (project) == Project)
  local client    = project.client
  local _, status = Http.json {
    url     = client.url .. "/projects/" .. project.id .. "/stars",
    method  = "DELETE",
    headers = {
      Authorization = client.token and "Bearer " .. client.token,
    },
  }
  assert (status == 204, { status = status })
  return project
end

function Permissions.load (permissions)
  assert (getmetatable (permissions) == Permissions)
  if permissions.data then
    return permissions
  end
  local client = permissions.client
  local data, status = Http.json {
    url     = client.url .. "/projects/" .. permissions.project.id .. "/permissions/",
    method  = "GET",
    headers = {
      Authorization = client.token and "Bearer " .. client.token,
    },
  }
  assert (status == 200, { status = status })
  permissions.data = {
    anonymous = data.anonymous,
    user      = data.user,
  }
  for _, granted in ipairs (data.granted) do
    local who
    local _, user_status = Http.json {
      url     = client.url .. "/users/" .. granted.identity_id,
      method  = "GET",
      headers = {
        Authorization = client.token and "Bearer " .. client.token,
      },
    }
    local _, project_status = Http.json {
      url     = client.url .. "/projects/" .. granted.identity_id,
      method  = "GET",
      headers = {
        Authorization = client.token and "Bearer " .. client.token,
      },
    }
    if user_status == 200 then
      who = User.__new (client, granted.identity_id)
    elseif project_status == 200 then
      who = Project.__new (client, granted.identity_id)
    end
    permissions.data [who] = granted.permission
  end
end

function Permissions.__index (permissions, key)
  assert (getmetatable (permissions) == Permissions)
  Permissions.load (permissions)
  return permissions.data [key]
end

function Permissions.__newindex (permissions, key, value)
  assert (getmetatable (permissions) == Permissions)
  Permissions.load (permissions)
  local client = permissions.client
  key = type (key) == "string" and key or key.id
  if value == nil then
    local _, status = Http.json {
      url     = client.url .. "/projects/" .. permissions.project.id .. "/permissions/" .. key,
      method  = "DELETE",
      headers = {
        Authorization = client.token and "Bearer " .. client.token,
      },
    }
    assert (status == 204)
  else
    local _, status = Http.json {
      url     = client.url .. "/projects/" .. permissions.project.id .. "/permissions/" .. key,
      method  = "PUT",
      headers = {
        Authorization = client.token and "Bearer " .. client.token,
      },
      body    = {
        permission = value,
      }
    }
    assert (status == 201 or status == 202, { status = status })
  end
  permissions.data = false
end

function Permissions.__pairs (permissions)
  assert (getmetatable (permissions) == Permissions)
  Permissions.load (permissions)
  local coroutine = Coromake ()
  return coroutine.wrap (function ()
    if permissions.data then
      for key, value in pairs (permissions.data) do
        coroutine.yield (key, value)
      end
    end
  end)
end

function Project.create_resource (project, t)
  assert (getmetatable (project) == Project)
  local client = project.client
  local data, status = Http.json {
    url     = client.url .. "/projects/" .. project.id .. "/resources/",
    method  = "POST",
    headers = {
      Authorization = client.token and "Bearer " .. client.token,
    },
    body    = t,
  }
  assert (status == 201, { status = status })
  return Resource.__new (client, project, data.id)
end

function Project.resources (project)
  assert (getmetatable (project) == Project)
  local client = project.client
  local data, status = Http.json {
    url     = client.url .. "/projects/" .. project.id .. "/resources/",
    method  = "GET",
    headers = {
      Authorization = client.token and "Bearer " .. client.token,
    },
  }
  assert (status == 200, { status = status })
  local coroutine = Coromake ()
  return coroutine.wrap (function ()
    for _, resource in ipairs (data) do
      coroutine.yield (Resource.__new (client, project, resource.id))
    end
  end)
end

function Resource.__new (client, project, id)
  assert (getmetatable (client) == Client)
  assert (getmetatable (project) == Project)
  local result = client.unique.resources [id]
  if not result then
    result = {
      client  = client,
      project = project,
      id      = id,
      data    = false,
    }
    result = setmetatable (result, Resource)
    client.unique.resources [id] = result
  end
  return result
end

function Resource.load (resource)
  assert (getmetatable (resource) == Resource)
  if resource.data then
    return resource
  end
  local client  = resource.client
  local project = resource.project
  local data, status = Http.json {
    url     = client.url .. "/projects/" .. project.id .. "/resources/" .. resource.id,
    method  = "GET",
    headers = {
      Authorization = client.token and "Bearer " .. client.token,
    },
  }
  assert (status == 200, { status = status })
  resource.data = data
  return resource
end

function Resource.delete (resource)
  assert (getmetatable (resource) == Resource)
  local client    = resource.client
  local project   = resource.project
  local _, status = Http.json {
    url     = client.url .. "/projects/" .. project.id .. "/resources/" .. resource.id,
    method  = "DELETE",
    headers = {
      Authorization = client.token and "Bearer " .. client.token,
    },
  }
  assert (status == 204, { status = status })
  resource.data = false
end

function Resource.__index (resource, key)
  assert (getmetatable (resource) == Resource)
  if Resource [key] then
    return Resource [key]
  end
  Resource.load (resource)
  return resource.data [key]
end

function Resource.__newindex (resource, key, value)
  assert (getmetatable (resource) == Resource)
  Resource.load (resource)
  local client    = resource.client
  local project   = resource.project
  local _, status = Http.json {
    url     = client.url .. "/projects/" .. project.id .. "/resources/" .. resource.id,
    method  = "PATCH",
    headers = {
      Authorization = client.token and "Bearer " .. client.token,
    },
    body    = {
      [key] = value,
    }
  }
  assert (status == 204, { status = status })
  resource.data = false
end

function Resource.__pairs (resource)
  assert (getmetatable (resource) == Resource)
  Resource.load (resource)
  local coroutine = Coromake ()
  return coroutine.wrap (function ()
    coroutine.yield ("client" , resource.client)
    coroutine.yield ("project", resource.project)
    if resource.data then
      for key, value in pairs (resource.data) do
        coroutine.yield (key, value)
      end
    end
  end)
end

local Editor = {}

function Resource.edit (resource)
  assert (getmetatable (resource) == Resource)
  Resource.load (resource)
  Copas.addthread (function ()
    local client = Websocket.client.copas {}
    local project = resource.project
    assert (client:connect (client.url:gsub ("http://", "ws://") .. "/projects/" .. project.id .. "/resources/" .. resource.id .. "/editor", {
      method  = "GET",
      headers = {
        Authorization = client.token and "Bearer " .. client.token,
      },
    }))
    -- populate layered data
    -- return transcation function
    local editor = setmetatable ({
      client  = client,
      current = nil,
      remote  = nil,
      changes = {},
    }, Editor)
    Copas.addthread (function ()
      while true do
        local message = client:receive ()
        if not message then
          return
        end
        message = Json.decode (message)
        if message.type == "patch" then
          if message.success then
            -- if answer to request then merge layer
            assert (editor.changes [message.id])
            -- apply on remote
            editor.changes [message.id] = nil
          else
            -- drop change
            assert (editor.changes [message.id])
            editor.changes [message.id] = nil
            editor.current = editor.remote
          end
        elseif message.type == "update" then
         -- if not, apply to remote
         assert (editor.changes [message.id])
         -- apply on remote
         editor.changes [message.id] = nil
        end
      end
    end)
    return editor
  end)
  Copas.loop ()
end

Editor.__index = Editor

function Editor.__call (editor, f)
  assert (getmetatable (editor) == Editor)
  local _ = f
  -- start record changes
  -- create new layer
  local layer = Layer.new {}
  layer [Layer.refines] = {
    editor.current,
  }
  -- local changes = {}
  -- local observer = Layer.observe (layer, function (proxy, key, value)
  --   -- TODO
  -- end)
  -- observer:enable ()
  -- pcall (f, layer)
  -- observer:disable ()
  -- end record changes
  -- send changes
  editor.client:send (Json.encode {
    type = "patch",
  })
end

function Editor.close (editor)
  assert (getmetatable (editor) == Editor)
  editor.client:close ()
end

return Client
