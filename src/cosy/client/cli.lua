local Copas     = require "copas"
local Arguments = require "argparse"
local Colors    = require "ansicolors"
local Et        = require "etlua"
local Json      = require "cjson"
local Lfs       = require "lfs"
local Ltn12     = require "ltn12"
local Http      = require "socket.http"
local Serpent   = require "serpent"
local Url       = require "socket.url"
local Yaml      = require "yaml"
local Client    = require "cosy.client"

local request = function (url, options)
  local body = {}
  options         = options         or {}
  options.headers = options.headers or {}
  options.headers ["Accept"] = "application/json"
  if options.json then
    options.body = Json.encode (options.json)
    options.headers ["Content-type"  ] = "application/json"
    options.headers ["Content-length"] = #options.body
  end
  options.allow_error = true
  local _, status = Http.request {
    url      = url,
    method   = options.method,
    headers  = options.headers,
    sink     = Ltn12.sink.table (body),
    source   = options.body and Ltn12.source.string (options.body),
    redirect = true,
  }
  body = table.concat (body)
  body = body ~= "" and Json.decode (body) or nil
  return status, body
end

local parser = Arguments () {
  name        = "cosy-cli",
  description = "cosy command-line interface",
}
parser:option "--profile" {
  description = "name of the configuration",
  default     = "default",
  defmode     = "u",
}
parser:option "--server" {
  description = "URL of the cosy server",
  default     = "http://localhost:8080/",
  defmode     = "a",
  convert     = function (x)
    local parsed = Url.parse (x)
    if not parsed.host then
      return nil, "server is not a valid url"
    end
    parsed.url = x
    return parsed
  end,
}
parser:option "--authentication" {
  description = "authentication token",
}
parser:mutex (
  parser:flag "--shell" {
    description = "use shell-friendly output",
  },
  parser:flag "--json" {
    description = "use JSON output",
  },
  parser:flag "--lua" {
    description = "use Lua output",
  },
  parser:flag "--yaml" {
    description = "use YAML output",
  }
)
local commands = {}
parser:command_target "command"
parser:require_command (false)

local function touser (x)
  local user = x:match "^([^/]+)$"
  if not user then
    error "user must be in the format 'user'"
  end
  return user
end

local function toproject (x)
  local project = x:match "^([^/]+)$"
  if not project then
    error "project must be in the format 'project'"
  end
  return project
end

local function toresource (x)
  local project, resource = x:match "^([^/]+)/([^/]+)$"
  if not project or not resource then
    error "resource must be in the format 'project/resource'"
  end
  return {
    project  = project,
    resource = resource,
  }
end

local function toexecution (x)
  local project, resource, execution = x:match "^([^/]+)/([^/]+)/([^/]+)$"
  if not project or not resource then
    error "execution must be in the format 'project/resource/execution'"
  end
  return {
    project   = project,
    resource  = resource,
    execution = execution,
  }
end

commands.info = parser:command "info" {
  description = "get information about the server",
}
commands.tag = {}
commands.tag.list = parser:command "tag:list" {
  description = "get all the existing tags",
}
commands.tag.of = parser:command "tag:info" {
  description = "get information about a tag",
}
commands.tag.of:argument "tag" {
  description = "tag to show",
}

commands.user = {}
commands.user.list = parser:command "user:list" {
  description = "get all the existing users",
}
commands.user.info = parser:command "user:info" {
  description = "get information about a user",
}
commands.user.info:argument "user" {
  description = "identifier of user to show",
  convert     = touser,
}
commands.user.update = parser:command "user:update" {
  description = "update information about a user",
}
commands.user.update:argument "user" {
  description = "identifier of user to update",
  convert     = touser,
}
commands.user.delete = parser:command "user:delete" {
  description = "delete a user",
}
commands.user.delete:argument "user" {
  description = "identifier of user to delete",
  convert     = touser,
}

commands.project = {}
commands.project.list = parser:command "project:list" {
  description = "get all the existing projects",
}
commands.project.create = parser:command "project:create" {
  description = "create a new project",
}
commands.project.create:option "--name" {
  description = "project name",
}
commands.project.create:option "--description" {
  description = "project description",
}
commands.project.info = parser:command "project:info" {
  description = "get information about a project",
}
commands.project.info:argument "project" {
  description = "identifier of project to show",
  convert     = toproject,
}
commands.project.update = parser:command "project:update" {
  description = "update information about a project",
}
commands.project.update:option "--name" {
  description = "project name",
}
commands.project.update:option "--description" {
  description = "project description",
}
commands.project.update:argument "project" {
  description = "identifier of project to update",
  convert     = toproject,
}
commands.project.delete = parser:command "project:delete" {
  description = "delete a project",
}
commands.project.delete:argument "project" {
  description = "identifier of project to delete",
  convert     = toproject,
}
commands.project.tags = parser:command "project:tags" {
  description = "get all tags of a project",
}
commands.project.tags:argument "project" {
  description = "identifier of project to use",
  convert     = toproject,
}
commands.project.tag = parser:command "project:tag" {
  description = "add a tag to a project",
}
commands.project.tag:argument "project" {
  description = "identifier of project to tag",
  convert     = toproject,
}
commands.project.tag:argument "tag" {
  description = "tag to add",
}
commands.project.untag = parser:command "project:untag" {
  description = "remove a tag from a project",
}
commands.project.untag:argument "project" {
  description = "identifier of project to untag",
  convert     = toproject,
}
commands.project.untag:argument "tag" {
  description = "tag to remove",
}
commands.project.stars = parser:command "project:stars" {
  description = "get all stars of a project",
}
commands.project.stars:argument "project" {
  description = "identifier of project to use",
  convert     = toproject,
}
commands.project.star = parser:command "project:star" {
  description = "add a star to a project",
}
commands.project.star:argument "project" {
  description = "identifier of project to star",
  convert     = toproject,
}
commands.project.unstar = parser:command "project:unstar" {
  description = "remove a star from a project",
}
commands.project.unstar:argument "project" {
  description = "identifier of project to unstar",
  convert     = toproject,
}

commands.permissions = {}
commands.permissions.set = parser:command "permissions:set" {
  description = "grant a permission to a project",
}
commands.permissions.set:argument "project" {
  description = "identifier of project to use",
  convert     = toproject,
}
commands.permissions.set:argument "identifier" {
  description = "identifier of user or project granted the permission",
}
commands.permissions.set:argument "permission" {
  description = "permission level to grant (admin, write, read or none)",
  convert     = function (x)
    if  x ~= "admin"
    and x ~= "write"
    and x ~= "read"
    and x ~= "none" then
      return nil, "permission must be none, read, write or admin"
    end
    return x
  end
}
commands.permissions.unset = parser:command "permissions:unset" {
  description = "deny a permission from a project",
}
commands.permissions.unset:argument "project" {
  description = "identifier of project to use",
  convert     = toproject,
}
commands.permissions.unset:argument "identifier" {
  description = "identifier of user or project denied the permission",
}

commands.resource = {}
commands.resource.list = parser:command "resource:list" {
  description = "get all the existing resources in a project",
}
commands.resource.list:argument "project" {
  description = "identifier of project to use",
  convert     = toproject,
}
commands.resource.create = parser:command "resource:create" {
  description = "create a new resource in a project",
}
commands.resource.create:option "--name" {
  description = "resource name",
}
commands.resource.create:option "--description" {
  description = "resource description",
}
commands.resource.create:argument "project" {
  description = "project containing the resource",
  convert     = toproject,
}
commands.resource.info = parser:command "resource:info" {
  description = "get information about a resource",
}
commands.resource.info:argument "resource" {
  description = "identifier of resource to show",
  convert     = toresource,
}
commands.resource.update = parser:command "resource:update" {
  description = "update information about a resource",
}
commands.resource.update:option "--name" {
  description = "resource name",
}
commands.resource.update:option "--description" {
  description = "resource description",
}
commands.resource.update:argument "resource" {
  description = "identifier of resource to update",
  convert     = toresource,
}
commands.resource.delete = parser:command "resource:delete" {
  description = "delete a resource",
}
commands.resource.delete:argument "resource" {
  description = "identifier of resource to delete",
  convert     = toresource,
}
commands.resource.open = parser:command "resource:open" {
  description = "open collaborative editor of a resource",
}
commands.resource.open:argument "resource" {
  description = "identifier of resource to edit",
  convert     = toresource,
}
commands.resource.close = parser:command "resource:close" {
  description = "close collaborative editor of a resource",
}
commands.resource.close:argument "resource" {
  description = "identifier of edited resource",
  convert     = toresource,
}

commands.alias = {}
commands.alias.create = parser:command "alias:create" {
  description = "create an alias on a resource",
}
commands.alias.create:argument "resource" {
  description = "identifier of resource to alias",
  convert     = toresource,
}
commands.alias.create:argument "alias" {
  description = "alias name",
}
commands.alias.list = parser:command "alias:list" {
  description = "get all the existing aliases of a resource",
}
commands.alias.list:argument "resource" {
  description = "identifier of resource to use",
  convert     = toresource,
}
commands.alias.delete = parser:command "alias:delete" {
  description = "delete an alias on a resource",
}
commands.alias.delete:argument "resource" {
  description = "identifier of aliased resource",
  convert     = toresource,
}
commands.alias.delete:argument "alias" {
  description = "alias name",
}

commands.execution = {}
commands.execution.list = parser:command "execution:list" {
  description = "list all existing executions on a resource",
}
commands.execution.list:argument "resource" {
  description = "identifier of resource to use",
  convert     = toproject,
}
commands.execution.prepare = parser:command "execution:prepare" {
  description = "prepare an execution using an execution template",
}
commands.execution.prepare:argument "resource" {
  description = "identifier of execution template",
  convert     = toresource,
}
commands.execution.prepare:argument "project" {
  description = "identifier of project to put execution resource",
  convert     = toproject,
}
commands.execution.prepare:argument "argument" {
  description = "argument of the execution",
  args        = "*",
}
commands.execution.start = parser:command "execution:start" {
  description = "start an execution",
}
commands.execution.start:option "--name" {
  description = "execution name",
}
commands.execution.start:option "--description" {
  description = "execution description",
}
commands.execution.start:option "image" {
  description = "docker image to use for execution",
}
commands.execution.start:argument "resource" {
  description = "identifier of resource to use for execution",
  convert     = toresource,
}
commands.execution.info = parser:command "execution:info" {
  description = "get information about an execution",
}
commands.execution.info:argument "execution" {
  description = "identifier of execution to show",
  convert     = toexecution,
}
commands.execution.update = parser:command "execution:update" {
  description = "update information about an execution",
}
commands.execution.update:option "--name" {
  description = "execution name",
}
commands.execution.update:option "--description" {
  description = "execution description",
}
commands.execution.update:argument "execution" {
  description = "identifier of execution to update",
  convert     = toexecution,
}
commands.execution.stop = parser:command "execution:stop" {
  description = "delete an execution",
}
commands.execution.stop:argument "execution" {
  description = "identifier of execution to delete",
  convert     = toexecution,
}

local arguments = parser:parse ()

Lfs.mkdir (os.getenv "HOME" .. "/.cosy")
Lfs.mkdir (os.getenv "HOME" .. "/.cosy/" .. arguments.profile)

local profile = {}
do
  local file, err = io.open (os.getenv "HOME" .. "/.cosy/" .. arguments.profile .. "/config.yaml", "r")
  if not file then
    print (Colors (Et.render ("%{blue blackbg}Configuration in <%- path %> is not readable, because <%- err %>.", {
      path  = os.getenv "HOME" .. "/.cosy/" .. arguments.profile .. "/config.yaml",
      error = tostring (err),
    })))
  else
    local data = file:read "*all"
    file:close ()
    profile = Yaml.load (data)
  end
end

profile.server         = arguments.server
                     and arguments.server
                      or profile.server
profile.authentication = arguments.authentication
                     and arguments.authentication
                      or profile.authentication
profile.output         = arguments.shell
                     and "shell"
                      or profile.output
profile.output         = arguments.json
                     and "json"
                      or profile.output
profile.output         = arguments.lua
                     and "lua"
                      or profile.output
profile.output         = arguments.yaml
                     and "yaml"
                      or profile.output
profile.output = profile.output or "shell"

if not arguments.command then
  arguments.command = "info"
  arguments.info    = true
end

if not profile.server then
  print (Colors ("%{red blackbg}Server URL is not configured."))
  print (parser:get_help ())
  os.exit (1)
end

do
  local file = io.open (os.getenv "HOME" .. "/.cosy/" .. arguments.profile .. "/config.yaml", "w")
  file:write (Yaml.dump (profile))
  file:close ()
end

local client

do
  local ok, err = pcall (function ()
    client = Client.new {
      url     = profile.server.url,
      request = request,
      token   = profile.authentication,
    }
  end)
  if not ok then
    print (Colors (Et.render ("%{red blackbg}Server is not reachable, because <%- error %>.", {
      error = Json.encode (err),
    })))
    os.exit (2)
  end
end

local ok, result = xpcall (function ()
  if arguments.command == "info" then
    return client:info ()
  elseif arguments.command == "permissions:set" then
    local project = client:project (arguments.project)
    local user
    if arguments.user == "anonymous" or arguments.user == "user" then
      user = arguments.user
    else
      user = client:user (arguments.user)
    end
    project.permissions [user] = arguments.permission
  elseif arguments.command == "permissions:unset" then
    local project = client:project (arguments.project)
    local user
    if arguments.user == "anonymous" or arguments.user == "user" then
      user = arguments.user
    else
      user = client:user (arguments.user)
    end
    project.permissions [user] = nil
  elseif arguments.command == "project:create" then
    local project = client:create_project {
      name        = arguments.name,
      description = arguments.description,
    }
    project:load ()
    return project
  elseif arguments.command == "project:delete" then
    local project = client:project (arguments.project)
    return project:delete ()
  elseif arguments.command == "project:info" then
    local project = client:project (arguments.project)
    return project
  elseif arguments.command == "project:list" then
    local result = {}
    for project in client:projects () do
      project:load ()
      result [#result+1] = project.data
    end
    return result
  elseif arguments.command == "project:star" then
    local project = client:project (arguments.project)
    return project:star ()
  elseif arguments.command == "project:stars" then
    local project = client:project (arguments.project)
    local result = {}
    for star in project:stars () do
      result [#result+1] = star
    end
    return result
  elseif arguments.command == "project:tag" then
    local project = client:project (arguments.project)
    return project:tag (arguments.tag)
  elseif arguments.command == "project:tags" then
    local project = client:project (arguments.project)
    local result = {}
    for tag in project:tags () do
      result [#result+1] = tag
    end
    return result
  elseif arguments.command == "project:unstar" then
    local project = client:project (arguments.project)
    return project:unstar ()
  elseif arguments.command == "project:untag" then
    local project = client:project (arguments.project)
    return project:untag (arguments.tag)
  elseif arguments.command == "project:update" then
    local project = client:project (arguments.project)
    return project:update {
      name        = arguments.name,
      description = arguments.description,
    }
  elseif arguments.command == "resource:create" then
    local project  = client:project (arguments.project)
    local resource = project:create_resource {
      name        = arguments.name,
      description = arguments.description,
    }
    resource:load ()
    return resource
  elseif arguments.command == "resource:delete" then
    local project  = client:project   (arguments.resource.project)
    local resource = project:resource (arguments.resource.resource)
    return resource:delete ()
  elseif arguments.command == "resource:open" then
    local project  = client:project   (arguments.resource.project)
    local resource = project:resource (arguments.resource.resource)
    return resource:open ()
  elseif arguments.command == "resource:close" then
    local project  = client:project   (arguments.resource.project)
    local resource = project:resource (arguments.resource.resource)
    return resource:close ()
  elseif arguments.command == "resource:info" then
    local project  = client:project   (arguments.resource.project)
    local resource = project:resource (arguments.resource.resource)
    return resource
  elseif arguments.command == "resource:list" then
    local project  = client:project (arguments.project)
    local result = {}
    for resource in project:resources () do
      resource:load ()
      result [#result+1] = resource.data
    end
    return result
  elseif arguments.command == "resource:update" then
    local project  = client:project   (arguments.resource.project)
    local resource = project:resource (arguments.resource.resource)
    return resource:update {
      name        = arguments.name,
      description = arguments.description,
    }
  elseif arguments.command == "alias:create" then
    local project  = client:project   (arguments.resource.project)
    local resource = project:resource (arguments.resource.resource)
    return resource:alias (arguments.alias)
  elseif arguments.command == "alias:delete" then
    local project  = client:project   (arguments.resource.project)
    local resource = project:resource (arguments.resource.resource)
    return resource:unalias (arguments.alias)
  elseif arguments.command == "alias:list" then
    local project  = client:project   (arguments.resource.project)
    local resource = project:resource (arguments.resource.resource)
    return resource:aliases ()
  elseif arguments.command == "execution:create" then
    local project    = client:project   (arguments.project)
    local resource   = project:resource (arguments.resource.resource)
    local copy       = resource:copy ()
    local parameters = {}
    Copas.addthread (function ()
      local editor = copy:edit ()
      editor (function (Layer, layer)
        local tool  = Layer.require "cosy/tool"
        local ptype = tool [Layer.key.meta].parameter_type
        local ctype = tool [Layer.key.meta].action_type
        local seen  = {}
        local function find (proxy, key, value)
          if getmetatable (value) == Layer.Proxy then
            if ptype <= value then
              parameters [value] = {
                proxy = proxy,
                key   = key,
              }
            end
            if ctype <= value then
              commands [value] = {
                proxy = proxy,
                key   = key,
              }
            end
            seen [value] = true
            for k, v in Layer.__pairs (value) do
              if not seen [v] then
                find (value, k, v)
              end
            end
          end
        end
        find (nil, nil, layer)
        parser = Arguments () {
          name        = copy.cli_id,
          description = "prepare execution for " .. copy.cli_id,
          add_help    = {
            action = function () assert (false) end
          },
        }
        for parameter in pairs (parameters) do
          local convert
          if parameter.type == "number" then
            convert = tonumber
          elseif parameter.type == "string" then
            convert = tostring
          elseif parameter.type == "boolean" then
            convert = function (x)
              if x:lower () == "true" then
                return true
              elseif x:lower () == "false" then
                return false
              else
                assert (false)
              end
            end
          elseif parameter.type == "function" then
            convert = function (x)
              return assert (loadstring (x)) ()
            end
          elseif getmetatable (parameter.type) == Layer.Proxy then
            convert = function (x)
              if parameter.update then
                return Layer.require (x)
              else
                return {
                  [Layer.key.refines] = { Layer.require (x) }
                }
              end
            end
          else
            assert (false)
          end
          parser:option ("--" .. parameter.name) {
            description = parameter.description
                       .. (parameter.type and " (" .. tostring (parameter.type) .. ")" or ""),
            default     = parameter.default,
            required    = parameter.default and false or true,
            convert     = convert,
          }
        end
        _G.arg = {}
        _G.arg [0] = copy.cli_id
        for i, x in ipairs (arguments.arguments) do
          _G.arg [i] = x
        end
        local args = parser:parse ()
        for parameter, t in pairs (parameters) do
          if args [parameter] then
            t.proxy [t.key] = args [parameter]
          end
        end
      end)
      editor:close ()
    end)
    return copy
  elseif arguments.command == "execution:start" then
    local project   = client:project   (arguments.project)
    local resource  = project:resource (arguments.resource.resource)
    if not arguments.image then
      Copas.addthread (function ()
        local editor = resource:edit ()
        editor (function (Layer, layer)
          local tool = Layer.require "cosy/tool"
          arguments.image = layer [tool.image] -- FIXME
        end)
        editor:close ()
      end)
      assert (arguments.image, "image is not defined")
    end
    local execution = resource:execute (arguments.image, {
      name        = arguments.name,
      description = arguments.description,
    })
    execution:load ()
    return execution
  elseif arguments.command == "execution:stop" then
    local project   = client:project     (arguments.execution.project)
    local resource  = project:resource   (arguments.execution.resource)
    local execution = resource:execution (arguments.execution.execution)
    return execution:delete ()
  elseif arguments.command == "execution:info" then
    local project   = client:project     (arguments.execution.project)
    local resource  = project:resource   (arguments.execution.resource)
    local execution = resource:execution (arguments.execution.execution)
    return execution
  elseif arguments.command == "execution:list" then
    local project   = client:project     (arguments.execution.project)
    local resource  = project:resource   (arguments.execution.resource)
    local result  = {}
    for execution in resource:executions () do
      execution:load ()
      result [#result+1] = execution.data
    end
    return result
  elseif arguments.command == "execution:update" then
    local project   = client:project     (arguments.execution.project)
    local resource  = project:resource   (arguments.execution.resource)
    local execution = resource:execution (arguments.execution.execution)
    return execution:update {
      name        = arguments.name,
      description = arguments.description,
    }
  elseif arguments.command == "tag:list" then
    local result = {}
    for tag in client:tags () do
      result [#result+1] = tag
    end
    return result
  elseif arguments.command == "tag:info" then
    return client:tagged (arguments.tag)
  elseif arguments.command == "user:delete" then
    local user = client:user (arguments.user)
    return user:delete ()
  elseif arguments.command == "user:info" then
    local user = client:user (arguments.user)
    return user
  elseif arguments.command == "user:list" then
    local result = {}
    for user in client:users () do
      user:load ()
      result [#result+1] = user.data
    end
    return result
  elseif arguments.command == "user:update" then
    local user = client:user (arguments.user)
    return user:update {}
  end
end, function (err)
  print (Json.encode (err), debug.traceback ())
end)

if ok then
  if profile.output == "shell" then
    if type (result) == "table" then
      result = result.cli_id or result.id
    end
    if result ~= nil then
      result = tostring (result)
    end
  elseif profile.output == "json" then
    result = result and Json.encode (result.data)
  elseif profile.output == "lua" then
    result = result and Serpent.block (result.data, {
      indent   = "  ",
      comment  = false,
      sortkeys = true,
      compact  = false,
    })
  elseif profile.output == "yaml" then
    Yaml.configure {
      sort_table_keys = true,
    }
    result = result and Yaml.dump (result.data)
  else
    print (Colors (Et.render ("%{red blackbg}Invalid output format <%- output %>.", {
      output = profile.output,
    })))
    os.exit (3)
  end
  if result ~= nil then
    if profile.output == "shell" then
      print (result)
    else
      print (Colors ("%{green blackbg}" .. result))
    end
  end
else
  io.stderr:write (Colors (Et.render ("%{red blackbg}Error in executing command: <%- error %>\n.", {
    error = Json.encode (result),
  })))
  io.stderr:flush ()
  os.exit (4)
end
