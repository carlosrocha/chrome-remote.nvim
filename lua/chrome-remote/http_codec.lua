local M = {}

---@param request http_request
---@return string
function M.encode(request)
  assert(request.method and request.resource, 'method and resource are required')

  local result = string.format('%s %s HTTP/1.1\r\n', string.upper(request.method), request.resource)

  result = result
    .. string.format('%s:%s\r\n', 'host', string.format('%s:%d', request.host, request.port))

  -- TODO: we should check here if the caller did not set this before
  if request.content then
    result = result .. string.format('%s:%s\r\n', 'content-length', #request.content)
  end

  if request.headers then
    for _, v in ipairs(request.headers) do
      result = result .. string.format('%s:%s\r\n', v[1], v[2])
    end
  end

  result = result .. '\r\n'

  if request.content then
    result = result .. request.content
  end

  return result
end

---@param chunk string
---@return http_response
function M.decode(chunk)
  if #chunk < 4 then
    chunk = chunk .. coroutine.yield()
  end

  local pos = 1
  local init_frame = nil

  repeat
    for i = pos, #chunk - 3 do
      if string.sub(chunk, i, i + 3) == '\r\n\r\n' then
        init_frame = string.sub(chunk, 1, i - 1)
        goto continue
      end
    end
    -- if the loop finishes without finding the header trail
    -- ask for more data and then continue from the last position
    pos = #chunk
    chunk = chunk .. coroutine.yield()
  until init_frame
  ::continue::

  local headers = {}
  local http_line
  for line in string.gmatch(init_frame, '([^\r\n]+)') do
    if not http_line then
      http_line = line
    else
      local key, val = string.match(line, '([^:]+) *: *([^\r\n]+)')
      headers[string.lower(key)] = val
    end
  end

  local content
  if headers['content-length'] then
    local content_pos = #init_frame + 4
    local content_length = tonumber(headers['content-length'])

    while #chunk < content_pos + content_length do
      chunk = chunk .. coroutine.yield()
    end

    content = string.sub(chunk, content_pos + 1, content_pos + content_length)
  end

  local status_code, status_text = string.match(http_line, 'HTTP/1.1 (%d+) (.+)')

  return {
    status_code = tonumber(status_code),
    status_text = status_text,
    headers = headers,
    content = content,
  }
end

return M
