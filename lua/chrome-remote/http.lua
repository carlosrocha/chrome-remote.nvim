local http_codec = require('chrome-remote.http_codec')
local uv = vim.loop
local json = vim.json

-- This whole module isn't meant to implement the spec as defined on
-- https://datatracker.ietf.org/doc/html/rfc2616
-- it's only the minimum implementation required to interact with cdp
-- Do not use it for any other case

local http = {}

---@class http_request
---@field method string
---@field host string
---@field port integer
---@field resource string
---@field headers string[][]
---@field content? string

---@class http_response<T>
---@field status_code string
---@field status_text string
---@field headers table<string, string>
---@field content? any

local function post_process_response(response)
  local result = {
    status_code = response.status_code,
    status_text = response.status_text,
    content = response.content,
    ok = response.status_code >= 200 and response.status_code < 300,
  }

  if response.content and response.headers['content-type'] then
    local content_type = response.headers['content-type']
    if vim.startswith(content_type:lower(), 'application/json') then
      local success, decoded = pcall(json.decode, response.content)
      if success then
        result.content = decoded
      end
    end
  end

  return result
end

---@param request http_request
---@param callback? fun(err: any, res: http_response)
function http.make_request(request, callback)
  local addrinfo = uv.getaddrinfo(request.host, nil, { family = 'inet', protocol = 'tcp' })
  assert(addrinfo, 'no suitable address found for ' .. request.host)

  local decoder = coroutine.wrap(http_codec.decode)
  local sock = uv.new_tcp()
  sock:connect(addrinfo[1].addr, request.port, function(err)
    assert(not err, err)
    sock:write(http_codec.encode(request))
    sock:read_start(function(err, chunk)
      assert(not err, err)
      if not chunk then
        return
      end

      local response = decoder(chunk)
      if response and callback then
        callback(nil, post_process_response(response))
      end
    end)
  end)
end

return http
