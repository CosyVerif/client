local Coromake  = require "coroutine.make"
_G.coroutine    = Coromake ()
local Copas     = require "copas"
local Json      = require "cjson"
local Layer     = require "layeredata"
local Websocket = require "websocket"
local Http      = require "cosy.client.http"

local Client      = {}
local Execution   = {}
local Resource    = {}
local Permissions = {}
local Project     = {}
local User        = {}

local function assert (condition, t)
  if not condition then
    error (t)
  else
    return condition
  end
end

-- ======================================================================

Client.__index = Client

function Client.new (options)
  local result = setmetatable ({
    url     = options.url,
    token   = options.token,
    force   = options.force,
    unique  = {
      users      = setmetatable ({}, { __mode = "v" }),
      projects   = setmetatable ({}, { __mode = "v" }),
      resources  = setmetatable ({}, { __mode = "v" }),
      executions = setmetatable ({}, { __mode = "v" }),
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
    result.authentified = User.__new (result, info.authentified.path)
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
    for _, tag in ipairs (data.tags) do
      coroutine.yield {
        client = client,
        id     = tag.id,
        path   = tag.path,
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
    for _, t in ipairs (data.tags) do
      coroutine.yield {
        id      = t.id,
        user    = User   .__new (client, t.user),
        project = Project.__new (client, t.project),
      }
    end
  end)
end

-- ======================================================================

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
    for _, user in ipairs (data.users) do
      coroutine.yield (User.__new (client, user.path))
    end
  end)
end

function Client.user (client, id)
  assert (getmetatable (client) == Client)
  local user = User.__new (client, "/users/" .. id)
  User.load (user)
  return user
end

function User.__new (client, path)
  assert (getmetatable (client) == Client)
  local result = client.unique.users [path]
  if not result then
    local id = path:match "^/users/([^/]+)$"
    result = setmetatable ({
      client = client,
      path   = path,
      data   = false,
      id     = id,
      cli_id = id,
      url    = client.url .. path,
    }, User)
    client.unique.users [path] = result
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
    url     = user.url,
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
    url     = user.url,
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
    url     = user.url,
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

-- ======================================================================

function Project.__new (client, path)
  assert (getmetatable (client) == Client)
  local result = client.unique.projects [path]
  if not result then
    local id = path:match "^/projects/([^/]+)$"
    result = {
      client = client,
      path   = path,
      data   = false,
      id     = id,
      cli_id = id,
      url    = client.url .. path,
    }
    result.permissions = setmetatable ({
      client  = client,
      project = result,
      data    = false,
    }, Permissions)
    result = setmetatable (result, Project)
    client.unique.projects [path] = result
  end
  return result
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
    for _, project in ipairs (data.projects) do
      coroutine.yield (Project.__new (client, project.path))
    end
  end)
end

function Client.project (client, id)
  assert (getmetatable (client) == Client)
  local project = Project.__new (client, "/projects/" .. id)
  Project.load (project)
  return project
end

function Client.create_project (client, t)
  assert (getmetatable (client) == Client)
  local data, status = Http.json {
    url     = client.url .. "/projects/",
    method  = "POST",
    headers = {
      Authorization = client.token and "Bearer " .. client.token,
    },
    body    = t,
  }
  assert (status == 201, { status = status })
  return Project.__new (client, data.path)
end

function Project.load (project)
  assert (getmetatable (project) == Project)
  if project.data then
    return project
  end
  local client = project.client
  local data, status = Http.json {
    url     = project.url,
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
    url     = project.url,
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
    url     = project.url,
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
    url     = project.url .. "/tags/",
    method  = "GET",
    headers = {
      Authorization = client.token and "Bearer " .. client.token,
    },
  }
  assert (status == 200, { status = status })
  local coroutine = Coromake ()
  return coroutine.wrap (function ()
    for _, tag in ipairs (data.tags) do
      coroutine.yield {
        id      = tag.id,
        user    = User   .__new (client, tag.user),
        project = Project.__new (client, tag.project),
      }
    end
  end)
end

function Project.tag (project, tag)
  assert (getmetatable (project) == Project)
  local client    = project.client
  local _, status = Http.json {
    url     = project.url .. "/tags/" .. tag,
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
    url     = project.url .. "/tags/" .. tag,
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
    url     = project.url .. "/stars",
    method  = "GET",
    headers = {
      Authorization = client.token and "Bearer " .. client.token,
    },
  }
  assert (status == 200, { status = status })
  local coroutine = Coromake ()
  return coroutine.wrap (function ()
    for _, star in ipairs (data.stars) do
      coroutine.yield {
        user    = User   .__new (client, star.user),
        project = Project.__new (client, star.project),
      }
    end
  end)
end

function Project.star (project)
  assert (getmetatable (project) == Project)
  local client    = project.client
  local _, status = Http.json {
    url     = project.url .. "/stars",
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
    url     = project.url .. "/stars",
    method  = "DELETE",
    headers = {
      Authorization = client.token and "Bearer " .. client.token,
    },
  }
  assert (status == 204, { status = status })
  return project
end

-- ======================================================================

function Permissions.load (permissions)
  assert (getmetatable (permissions) == Permissions)
  if permissions.data then
    return permissions
  end
  local client = permissions.client
  local data, status = Http.json {
    url     = client.url .. permissions.project.path .. "/permissions/",
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
    if granted.type == "user" then
      who = User   .__new (client, granted.who)
    elseif granted.type == "project" then
      who = Project.__new (client, granted.who)
    end
    permissions.data [who] = granted.permission
  end
end

function Permissions.__index (permissions, key)
  assert (getmetatable (permissions) == Permissions)
  if Permissions [key] then
    return Permissions [key]
  end
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
      url     = client.url .. permissions.project.path .. "/permissions/" .. key,
      method  = "DELETE",
      headers = {
        Authorization = client.token and "Bearer " .. client.token,
      },
    }
    assert (status == 204)
  else
    local _, status = Http.json {
      url     = client.url .. permissions.project.path .. "/permissions/" .. key,
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

-- ======================================================================

function Resource.__new (project, path)
  assert (getmetatable (project) == Project)
  local client = project.client
  local result = client.unique.resources [path]
  if not result then
    local pid, rid = path:match "^/projects/([^/]+)/resources/([^/]+)$"
    result = {
      client  = client,
      project = project,
      path    = path,
      data    = false,
      id      = rid,
      cli_id  = pid .. "/" .. rid,
      url     = client.url .. path,
    }
    result = setmetatable (result, Resource)
    client.unique.resources [path] = result
  end
  return result
end

function Project.create_resource (project, t)
  assert (getmetatable (project) == Project)
  local client = project.client
  local data, status = Http.json {
    url     = project.url .. "/resources/",
    method  = "POST",
    headers = {
      Authorization = client.token and "Bearer " .. client.token,
    },
    body    = t,
  }
  assert (status == 201, { status = status })
  return Resource.__new (project, data.path)
end

function Project.resources (project)
  assert (getmetatable (project) == Project)
  local client = project.client
  local data, status = Http.json {
    url     = project.url .. "/resources/",
    method  = "GET",
    headers = {
      Authorization = client.token and "Bearer " .. client.token,
    },
  }
  assert (status == 200, { status = status })
  local coroutine = Coromake ()
  return coroutine.wrap (function ()
    for _, resource in ipairs (data.resources) do
      coroutine.yield (Resource.__new (project, resource.path))
    end
  end)
end

function Project.resource (project, id)
  assert (getmetatable (project) == Project)
  local resource = Resource.__new (project, project.path .. "/resources/" .. id)
  Resource.load (resource)
  return resource
end

function Resource.load (resource)
  assert (getmetatable (resource) == Resource)
  if resource.data then
    return resource
  end
  local client  = resource.client
  local data, status = Http.json {
    url     = resource.url,
    method  = "GET",
    headers = {
      Authorization = client.token and "Bearer " .. client.token,
    },
  }
  assert (status == 200, { status = status })
  resource.data = data
  return resource
end

function Resource.open (resource)
  assert (getmetatable (resource) == Resource)
  local client    = resource.client
  local _, status = Http.json {
    url      = resource.url .. "/editor",
    method   = "GET",
    redirect = false,
    headers  = {
      Authorization = client.token and "Bearer " .. client.token,
    },
  }
  assert (status == 202 or status == 302, { status = status })
  local headers
  for _ = 1, 60 do
    _, status, headers = Http.json {
      url      = resource.url .. "/editor",
      method   = "GET",
      redirect = false,
      headers  = {
        Authorization = client.token and "Bearer " .. client.token,
      },
    }
    if status == 302 then
      return headers.location
    end
    os.execute [[ sleep 1 ]]
  end
  assert (false, { status = status })
end

function Resource.close (resource)
  assert (getmetatable (resource) == Resource)
  local client    = resource.client
  local _, status = Http.json {
    url      = resource.url .. "/editor",
    method   = "DELETE",
    headers  = {
      Authorization = client.token and "Bearer " .. client.token,
    },
  }
  assert (status == 202, { status = status })
end

function Resource.delete (resource)
  assert (getmetatable (resource) == Resource)
  local client    = resource.client
  local _, status = Http.json {
    url     = resource.url,
    method  = "DELETE",
    headers = {
      Authorization = client.token and "Bearer " .. client.token,
    },
  }
  assert (status == 204, { status = status })
  resource.data = false
end

function Resource.copy (resource, project)
  assert (getmetatable (resource) == Resource)
  assert (getmetatable (project ) == Project)
  return project:create_resource {
    name        = resource.data.name,
    description = resource.data.description,
    data        = resource.data.data,
  }
end

function Resource.aliases (resource)
  assert (getmetatable (resource) == Resource)
  local client  = resource.client
  local project = resource.project
  local result, status = Http.json {
    url      = resource.url .. "/aliases",
    method   = "GET",
    headers  = {
      Authorization = client.token and "Bearer " .. client.token,
    },
  }
  assert (status == 200, { status = status })
  local coroutine = Coromake ()
  return coroutine.wrap (function ()
    for _, x in ipairs (result.aliases) do
      coroutine.yield (x.id, Resource.__new (project, x.resource))
    end
  end)
end

function Resource.alias (resource, alias)
  assert (getmetatable (resource) == Resource)
  assert (type (alias) == "string")
  local client = resource.client
  local _, status = Http.json {
    url      = resource.url .. "/aliases/" .. alias,
    method   = "PUT",
    headers  = {
      Authorization = client.token and "Bearer " .. client.token,
    },
  }
  assert (status == 201 or status == 202, { status = status })
end

function Resource.unalias (resource, alias)
  assert (getmetatable (resource) == Resource)
  assert (type (alias) == "string")
  local client = resource.client
  local _, status = Http.json {
    url      = resource.url .. "/aliases/" .. alias,
    method   = "DELETE",
    headers  = {
      Authorization = client.token and "Bearer " .. client.token,
    },
  }
  assert (status == 204, { status = status })
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
  local _, status = Http.json {
    url     = resource.url,
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

-- ======================================================================

function Execution.__new (resource, path)
  assert (getmetatable (resource) == Resource)
  local client = resource.client
  local result = client.unique.executions [path]
  if not result then
    local pid, rid, eid = path:match "^/projects/([^/]+)/resources/([^/]+)/executions/([^/]+)$"
    result = {
      client   = client,
      project  = resource.project,
      resource = resource,
      path     = path,
      data     = false,
      id       = eid,
      cli_id   = pid .. "/" .. rid .. "/" .. eid,
      url      = client.url .. path,
    }
    result = setmetatable (result, Execution)
    client.unique.executions [path] = result
  end
  return result
end

function Resource.execute (resource, image, options)
  assert (getmetatable (resource) == Resource)
  assert (type (image) == "string")
  local client = resource.client
  local t      = {
    image    = image,
  }
  for k, v in pairs (options or {}) do
    t [k] = v
  end
  local data, status = Http.json {
    url     = resource.url .. "/executions/",
    method  = "POST",
    headers = {
      Authorization = client.token and "Bearer " .. client.token,
    },
    body    = t,
  }
  assert (status == 202, { status = status })
  return Execution.__new (resource, data.path)
end

function Resource.executions (resource)
  assert (getmetatable (resource) == Resource)
  local client = resource.client
  local data, status = Http.json {
    url     = resource.url .. "/executions/",
    method  = "GET",
    headers = {
      Authorization = client.token and "Bearer " .. client.token,
    },
  }
  assert (status == 200, { status = status })
  local coroutine = Coromake ()
  return coroutine.wrap (function ()
    for _, execution in ipairs (data.executions) do
      coroutine.yield (Execution.__new (resource, execution.path))
    end
  end)
end

function Resource.execution (resource, id)
  assert (getmetatable (resource) == Resource)
  local execution = Execution.__new (resource, resource.path .. "/executions/" .. id)
  Execution.load (execution)
  return execution
end

function Execution.load (execution)
  assert (getmetatable (execution) == Execution)
  if execution.data then
    return execution
  end
  local client  = execution.client
  local data, status = Http.json {
    url     = execution.url,
    method  = "GET",
    headers = {
      Authorization = client.token and "Bearer " .. client.token,
    },
  }
  assert (status == 200, { status = status })
  execution.data = data
  return execution
end

function Execution.delete (execution)
  assert (getmetatable (execution) == Execution)
  local client    = execution.client
  local _, status = Http.json {
    url     = execution.url,
    method  = "DELETE",
    headers = {
      Authorization = client.token and "Bearer " .. client.token,
    },
  }
  assert (status == 202, { status = status })
  execution.data = false
end

function Execution.__index (execution, key)
  assert (getmetatable (execution) == Execution)
  if Execution [key] then
    return Execution [key]
  end
  Execution.load (execution)
  return execution.data [key]
end

function Execution.__newindex (execution, key, value)
  assert (getmetatable (execution) == Execution)
  Execution.load (execution)
  local client    = execution.client
  local _, status = Http.json {
    url     = execution.url,
    method  = "PATCH",
    headers = {
      Authorization = client.token and "Bearer " .. client.token,
    },
    body    = {
      [key] = value,
    }
  }
  assert (status == 204, { status = status })
  execution.data = false
end

function Execution.__pairs (execution)
  assert (getmetatable (execution) == Execution)
  Execution.load (execution)
  local coroutine = Coromake ()
  return coroutine.wrap (function ()
    coroutine.yield ("client"  , execution.client)
    coroutine.yield ("project" , execution.project)
    coroutine.yield ("resource", execution.resource)
    if execution.data then
      for key, value in pairs (execution.data) do
        coroutine.yield (key, value)
      end
    end
  end)
end

-----

local Editor = {}

Editor.__index = Editor

function Resource.edit (resource)
  assert (getmetatable (resource) == Resource)
  Resource.load (resource)
  local url
  for _ = 1, 20 do
    local _, status, headers = Http.json {
      copas    = true,
      redirect = false,
      url      = resource.url .. "/editor",
      method   = "GET",
      headers  = {
        Authorization = resource.client.token and "Bearer " .. resource.client.token,
      },
    }
    if status == 302 then
      url = headers.location
      break
    end
    Copas.sleep (5)
  end
  assert (url, url)
  local editor = setmetatable ({
    Layer     = setmetatable ({}, { __index = Layer }),
    client    = resource.client,
    url       = url:gsub ("^http", "ws"),
    websocket = nil,
    running   = true,
    base      = {},
    current   = {},
    remote    = {},
    requests  = {},
    answers   = {},
    resource  = resource,
  }, Editor)
  editor.Layer.require = function (module)
    local loaded = Layer.loaded [module]
    if loaded then
      local layer = Layer.hidden [loaded].layer
      local info  = Layer.hidden [layer]
      return info.proxy, info.ref
    end
    local co = coroutine.running ()
    local t  = {}
    local id = #editor.requests+1
    editor.requests [id] = {
      module   = module,
      callback = function (answer)
        t.module = answer.module
        Copas.wakeup (co)
      end,
    }
    editor.websocket:send (Json.encode {
      id     = id,
      type   = "require",
      module = module,
    })
    Copas.sleep (-math.huge)
    editor.requests [id] = nil
    local layer, ref = editor:load (t.module, { name = module })
    Layer.loaded [module] = layer
    return layer, ref
  end
  local websocket = Websocket.client.copas {}
  websocket:connect (editor.url, "cosy")
  if resource.client.authentified then
    websocket:send (Json.encode {
      id    = 1,
      type  = "authenticate",
      token = resource.client.token,
      user  = resource.client.authentified.path,
    })
    local answer = websocket:receive ()
    answer = Json.decode (answer)
    assert (answer.success, answer.reason)
  end
  local answer = websocket:receive ()
  answer = Json.decode (answer)
  assert (answer.type == "update")
  local layer, ref = editor:load (answer.patch)
  local current = Layer.new { temporary = true }
  local remote  = Layer.new { temporary = true }
  current [Layer.key.refines] = { layer }
  remote  [Layer.key.refines] = { layer }
  editor.base   .layer = layer
  editor.base   .ref   = ref
  editor.current.layer = current
  editor.current.ref   = ref
  editor.remote .layer = remote
  editor.remote .ref   = ref
  editor.websocket     = websocket
  editor.receiver      = Copas.addthread (function ()
    while editor.running do
      pcall (Editor.receive, editor)
    end
  end)
  editor.patcher       = Copas.addthread (function ()
    while editor.running do
      pcall (Editor.patch, editor)
    end
  end)
  return editor
end

function Editor.receive (editor)
  assert (getmetatable (editor) == Editor)
  local message = editor.websocket:receive ()
  if not message then
    return
  end
  message = Json.decode (message)
  if message.type == "answer" then
    local request = assert (editor.requests [message.id])
    request.callback (message)
  elseif message.type == "update" then
    local layer = assert (editor:load (message.patch, { within = editor.remote }))
    Layer.merge (layer, editor.base.layer)
    local refines = editor.remote.layer [Layer.key.refines]
    refines [2]   = nil
  end
end

function Editor.wait (editor, condition)
  assert (getmetatable (editor) == Editor)
  assert (condition == nil or type (condition) == "function")
  local co = coroutine.running ()
  local t  = {}
  t.observer = Layer.observe (editor.remote.layer, function (coroutine, proxy, key, value)
    if condition and condition (proxy, key, value) then
      t.observer:disable ()
      coroutine.yield ()
      Copas.addthread (function ()
        Copas.wakeup (co)
      end)
    end
  end)
  Copas.sleep (-math.huge)
end

function Editor.update (editor, f)
  assert (getmetatable (editor) == Editor)
  local created, err = editor:load (f, { within = editor.current })
  if not created then
    error (err)
  end
  local patch   = type (f) == "string"
              and f
               or Layer.dump (created)
  editor.requests [#editor.requests+1] = {
    source   = f,
    patch    = patch,
    callback = function (answer)
      editor.answers [#editor.answers+1] = answer
      Copas.wakeup (editor.patcher)
    end,
  }
  editor.websocket:send (Json.encode {
    id    = #editor.requests,
    type  = "patch",
    patch = patch,
  })
end

function Editor.patch (editor)
  local answer = editor.answers [1]
  if answer then
    if answer.success then
      local request = assert (editor.requests [answer.id])
      local layer   = assert (editor:load (request.source, { within = editor.remote }))
      Layer.merge (layer, editor.base.layer)
    end
    local refines = editor.current.layer [Layer.key.refines]
    for i = 2, Layer.len (refines) do
      refines [i] = refines [i+1]
    end
    editor.requests [answer.id] = nil
    table.remove (editor.answers, 1)
  else
    Copas.sleep (-math.huge)
  end
end

function Editor.__call (editor, f)
  assert (getmetatable (editor) == Editor)
  return editor:update (f)
end

function Editor.load (editor, patch, options)
  assert (getmetatable (editor) == Editor)
  assert (options == nil or type (options) == "table")
  options = options or {}
  if options.within then
    assert (getmetatable (options.within.layer) == Layer.Proxy)
    assert (getmetatable (options.within.ref  ) == Layer.Reference)
  end
  local loaded, ok, err
  if type (patch) == "string" then
    if _G.loadstring then
      loaded, err = _G.loadstring (patch)
    else
      loaded, err = _G.load (patch, nil, "t")
    end
    if not loaded then
      return nil, err
    end
    ok, loaded = pcall (loaded)
    if not ok then
      return nil, loaded
    end
  elseif type (patch) == "function" then
    loaded = patch
  end
  if not loaded then
    return nil, "no patch"
  end
  local layer, ref
  if options.within then
    layer, ref = Layer.new {
      name      = options.name,
      temporary = true,
    }, options.within.ref
    local refines = options.within.layer [Layer.key.refines]
    refines [Layer.len (refines)+1] = layer
    local old = Layer.write_to (options.within.layer, layer)
    ok, err = pcall (loaded, editor.Layer, options.within.layer, options.within.ref)
    Layer.write_to (options.within.layer, old)
  else
    layer, ref = Layer.new {
      name      = options.name,
      temporary = false,
    }
    ok, err = pcall (loaded, editor.Layer, layer, ref)
  end
  if not ok then
    return nil, err
  end
  return layer, ref
end

function Editor.close (editor)
  assert (getmetatable (editor) == Editor)
  editor.running = false
  editor.websocket:close ()
  Copas.wakeup (editor.receiver)
  Copas.wakeup (editor.patcher)
end

return Client
