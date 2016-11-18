local Ltn12 = require "ltn12"
local Json  = require "cjson"
local Httpc = require "copas.http"
local Http  = require "socket.http"
local Https = require "ssl.https"

local M = {}

function M.json (options)
  assert (type (options) == "table")
  local result = {}
  options.sink    = Ltn12.sink.table (result)
  options.body    = options.body and Json.encode (options.body)
  options.source  = options.body and Ltn12.source.string (options.body)
  options.headers = options.headers or {}
  options.headers ["Content-length"] = options.body and #options.body or 0
  options.headers ["Content-type"  ] = options.body and "application/json"
  options.headers ["Accept"        ] = "application/json"
  local http
  if options.copas then
    http = Httpc
  else
    http = options.url:match "https://"
           and Https
            or Http
  end
  local _, status, headers = http.request (options)
  result = #result ~= 0
       and Json.decode (table.concat (result))
  return result, status, headers
end

return M
