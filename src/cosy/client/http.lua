local Ltn12 = require "ltn12"
local Json  = require "cjson"
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
  local http = options.url:match "https://"
           and Https
            or Http
  local status, _
  local retry = 10
  repeat
    _, status, _, _ = http.request (options)
    if type (status) ~= "number" then
      return nil, status
    elseif status == 500 then
      return nil, status
    elseif retry == 0 then
      return nil, status
    elseif status == 503 then
      os.execute [[ sleep 1 ]]
    end
    retry = retry - 1
  until status < 500
  result = #result ~= 0
       and Json.decode (table.concat (result))
  return result, status
end

return M
