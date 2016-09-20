require "copas"

local Arguments = require "argparse"
local Colors    = require "ansicolors"
local Json      = require "cjson"
local Lfs       = require "lfs"
local Ltn12     = require "ltn12"
local Http      = require "socket.http"
local Serpent   = require "serpent"
local Url       = require "socket.url"
local Yaml      = require "yaml"
local I18n      = require "cosy.i18n"
local Client    = require "cosy.client"

local i18n = I18n.new {} + require "cosy.client.i18n"

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
  description = i18n ["description:cli"] % {},
}
parser:option "--profile" {
  description = i18n ["description:profile"] % {},
  default     = "default",
  defmode     = "u",
}
parser:option "--server" {
  description = i18n ["description:server"] % {},
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
  description = i18n ["description:authentication"] % {},
}
parser:mutex (
  parser:flag "--json" {
    description = i18n ["description:json"] % {},
  },
  parser:flag "--lua" {
    description = i18n ["description:lua"] % {},
  },
  parser:flag "--yaml" {
    description = i18n ["description:yaml"] % {},
  }
)
local commands = {}
parser:command_target "command"
parser:require_command (false)

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

commands.info = parser:command "info" {
  description = i18n ["description:info"] % {},
}
commands.tag = {}
commands.tag.list = parser:command "tag:list" {
  description = i18n ["description:tag:list"] % {},
}
commands.tag.of = parser:command "tag:info" {
  description = i18n ["description:tag:info"] % {},
}
commands.tag.of:argument "tag" {
  description = i18n ["description:tag"] % {},
}

commands.user = {}
commands.user.list = parser:command "user:list" {
  description = i18n ["description:user:list"] % {},
}
commands.user.info = parser:command "user:info" {
  description = i18n ["description:user:info"] % {},
}
commands.user.info:argument "user" {
  description = i18n ["description:user-id"] % {},
}
commands.user.update = parser:command "user:update" {
  description = i18n ["description:user:update"] % {},
}
commands.user.update:argument "user" {
  description = i18n ["description:user-id"] % {},
}
commands.user.delete = parser:command "user:delete" {
  description = i18n ["description:user:delete"] % {},
}
commands.user.delete:argument "user" {
  description = i18n ["description:user-id"] % {},
}

commands.project = {}
commands.project.list = parser:command "project:list" {
  description = i18n ["description:project:list"] % {},
}
commands.project.create = parser:command "project:create" {
  description = i18n ["description:project:create"] % {},
}
commands.project.info = parser:command "project:info" {
  description = i18n ["description:project:info"] % {},
}
commands.project.info:argument "project" {
  description = i18n ["description:project-id"] % {},
}
commands.project.update = parser:command "project:update" {
  description = i18n ["description:project:update"] % {},
}
commands.project.update:option "--name" {
  description = i18n ["description:name"] % {},
}
commands.project.update:option "--description" {
  description = i18n ["description:description"] % {},
}
commands.project.update:argument "project" {
  description = i18n ["description:project-id"] % {},
}
commands.project.delete = parser:command "project:delete" {
  description = i18n ["description:project:delete"] % {},
}
commands.project.delete:argument "project" {
  description = i18n ["description:project-id"] % {},
}
commands.project.tags = parser:command "project:tags" {
  description = i18n ["description:project:tags"] % {},
}
commands.project.tags:argument "project" {
  description = i18n ["description:project-id"] % {},
}
commands.project.tag = parser:command "project:tag" {
  description = i18n ["description:project:tag"] % {},
}
commands.project.tag:argument "project" {
  description = i18n ["description:project-id"] % {},
}
commands.project.tag:argument "tag" {
  description = i18n ["description:tag"] % {},
}
commands.project.untag = parser:command "project:untag" {
  description = i18n ["description:project:untag"] % {},
}
commands.project.untag:argument "project" {
  description = i18n ["description:project-id"] % {},
}
commands.project.untag:argument "tag" {
  description = i18n ["description:tag"] % {},
}
commands.project.stars = parser:command "project:stars" {
  description = i18n ["description:project:stars"] % {},
}
commands.project.stars:argument "project" {
  description = i18n ["description:project-id"] % {},
}
commands.project.star = parser:command "project:star" {
  description = i18n ["description:project:star"] % {},
}
commands.project.star:argument "project" {
  description = i18n ["description:project-id"] % {},
}
commands.project.unstar = parser:command "project:unstar" {
  description = i18n ["description:project:unstar"] % {},
}
commands.project.unstar:argument "project" {
  description = i18n ["description:project-id"] % {},
}

commands.permissions = {}
commands.permissions.set = parser:command "permissions:set" {
  description = i18n ["description:permissions:set"] % {},
}
commands.permissions.set:argument "project" {
  description = i18n ["description:project-id"] % {},
}
commands.permissions.set:argument "identifier" {
  description = i18n ["description:identifier"] % {},
}
commands.permissions.set:argument "permission" {
  description = i18n ["description:permission"] % {},
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
  description = i18n ["description:permissions:unset"] % {},
}
commands.permissions.unset:argument "project" {
  description = i18n ["description:project-id"] % {},
}
commands.permissions.unset:argument "identifier" {
  description = i18n ["description:identifier"] % {},
}

commands.resource = {}
commands.resource.list = parser:command "resource:list" {
  description = i18n ["description:resource:list"] % {},
}
commands.resource.list:argument "project" {
  description = i18n ["description:project-id"] % {},
}
commands.resource.create = parser:command "resource:create" {
  description = i18n ["description:resource:create"] % {},
}
commands.resource.create:argument "project" {
  description = i18n ["description:project-id"] % {},
}
commands.resource.info = parser:command "resource:info" {
  description = i18n ["description:resource:info"] % {},
}
commands.resource.info:argument "resource" {
  description = i18n ["description:resource-id"] % {},
  convert     = toresource,
}
commands.resource.update = parser:command "resource:update" {
  description = i18n ["description:resource:update"] % {},
}
commands.resource.update:option "--name" {
  description = i18n ["description:name"] % {},
}
commands.resource.update:option "--description" {
  description = i18n ["description:description"] % {},
}
commands.resource.update:argument "resource" {
  description = i18n ["description:resource-id"] % {},
  convert     = toresource,
}
commands.resource.delete = parser:command "resource:delete" {
  description = i18n ["description:resource:delete"] % {},
}
commands.resource.delete:argument "resource" {
  description = i18n ["description:resource-id"] % {},
  convert     = toresource,
}

commands.execution = {}
commands.execution.list = parser:command "execution:list" {
  description = i18n ["description:execution:list"] % {},
}
commands.execution.list:argument "project" {
  description = i18n ["description:project-id"] % {},
}
commands.execution.create = parser:command "execution:create" {
  description = i18n ["description:execution:create"] % {},
}
commands.execution.create:argument "project" {
  description = i18n ["description:project-id"] % {},
}
commands.execution.create:argument "resource" {
  description = i18n ["description:resource-url"] % {},
  convert     = toresource,
}
commands.execution.create:argument "image" {
  description = i18n ["description:image-url"] % {},
}
commands.execution.info = parser:command "execution:info" {
  description = i18n ["description:execution:info"] % {},
}
commands.execution.info:argument "execution" {
  description = i18n ["description:execution-id"] % {},
  convert     = toresource,
}
commands.execution.update = parser:command "execution:update" {
  description = i18n ["description:execution:update"] % {},
}
commands.execution.update:option "--name" {
  description = i18n ["description:name"] % {},
}
commands.execution.update:option "--description" {
  description = i18n ["description:description"] % {},
}
commands.execution.update:argument "execution" {
  description = i18n ["description:execution-id"] % {},
  convert     = toresource,
}
commands.execution.delete = parser:command "execution:delete" {
  description = i18n ["description:execution:delete"] % {},
}
commands.execution.delete:argument "execution" {
  description = i18n ["description:execution-id"] % {},
  convert     = toresource,
}

local arguments = parser:parse ()

Lfs.mkdir (os.getenv "HOME" .. "/.cosy")
Lfs.mkdir (os.getenv "HOME" .. "/.cosy/" .. arguments.profile)

local profile = {}
do
  local file, err = io.open (os.getenv "HOME" .. "/.cosy/" .. arguments.profile .. "/config.yaml", "r")
  if not file then
    print (Colors ("%{blue blackbg}" .. i18n ["unreadable-configuration"] % {
      error = tostring (err),
    }))
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
profile.output         = arguments.json
                     and "json"
                      or profile.output
profile.output         = arguments.lua
                     and "lua"
                      or profile.output
profile.output         = arguments.yaml
                     and "yaml"
                      or profile.output
profile.output = profile.output or "yaml"

if not arguments.command then
  arguments.command = "info"
  arguments.info    = true
end

if not profile.server then
  print (Colors ("%{red blackbg}" .. i18n ["missing-server"] % {}))
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
    print (Colors ("%{red blackbg}" .. i18n ["unreachable-server"] % {
      error = Json.encode (err),
    }))
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
    local project = client:create_project {}
    project:load ()
    return project.data
  elseif arguments.command == "project:delete" then
    local project = client:project (arguments.project)
    return project:delete ()
  elseif arguments.command == "project:info" then
    local project = client:project (arguments.project)
    return project.data
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
    local resource = project:create_resource ()
    resource:load ()
    return resource.data
  elseif arguments.command == "resource:delete" then
    local project  = client:project   (arguments.resource.project)
    local resource = project:resource (arguments.resource.resource)
    return resource:delete ()
  elseif arguments.command == "resource:info" then
    local project  = client:project   (arguments.resource.project)
    local resource = project:resource (arguments.resource.resource)
    return resource.data
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
  elseif arguments.command == "execution:create" then
    local project   = client:project (arguments.project)
    local rproject  = client:project (arguments.resource.project)
    local resource  = rproject:resource (arguments.resource.resource)
    local execution = project:execute (resource, arguments.image)
    execution:load ()
    return execution.data
  elseif arguments.command == "execution:delete" then
    local project   = client:project   (arguments.execution.project)
    local execution = project:execution (arguments.execution.resource)
    return execution:delete ()
  elseif arguments.command == "execution:info" then
    local project   = client:project   (arguments.execution.project)
    local execution = project:execution (arguments.execution.resource)
    return execution.data
  elseif arguments.command == "execution:list" then
    local project = client:project (arguments.project)
    local result  = {}
    for execution in project:executions () do
      execution:load ()
      result [#result+1] = execution.data
    end
    return result
  elseif arguments.command == "execution:update" then
    local project   = client:project   (arguments.execution.project)
    local execution = project:execution (arguments.execution.resource)
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
    return user.data
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
  print (err, debug.traceback ())
end)

if ok then
  if profile.output == "json" then
    result = result and Json.encode (result)
  elseif profile.output == "lua" then
    result = result and Serpent.block (result, {
      indent   = "  ",
      comment  = false,
      sortkeys = true,
      compact  = false,
    })
  elseif profile.output == "yaml" then
    Yaml.configure {
      sort_table_keys = true,
    }
    result = result and Yaml.dump (result)
  else
    print (Colors ("%{red blackbg}" .. i18n ["invalid-output"] % {}))
    os.exit (3)
  end
  print (Colors ("%{green blackbg}" .. result))
else
  print (Colors ("%{red blackbg}" .. i18n ["command-error"] % {
    error = Json.encode (result),
  }))
  os.exit (4)
end
