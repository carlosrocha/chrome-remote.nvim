local uv = vim.loop
local EventEmitter = require('chrome-remote.event_emitter')
local websocket_codec = require('chrome-remote.websocket_codec')
local http_codec = require('chrome-remote.http_codec')
local base64_encode = require('lua.chrome-remote.base64').encode

local rshift = bit.rshift
local band = bit.band
local char = string.char

local function rand4()
  local num = math.floor(math.random() * 0x100000000)
  return char(
    rshift(num, 24),
    band(rshift(num, 16), 0xff),
    band(rshift(num, 8), 0xff),
    band(num, 0xff)
  )
end

---@class WebSocket : EventEmitter
---@field sock uv.uv_tcp_t
local WebSocket = setmetatable({}, { __index = EventEmitter })
local WebSocketMt = { __index = WebSocket }

---@return WebSocket
function WebSocket.new()
  return EventEmitter.init(setmetatable({}, WebSocketMt))
end

---@param params connection_params
function WebSocket:open(params, callback)
  assert(params.protocol == 'ws', 'only ws protocol supported')

  local addrinfo = uv.getaddrinfo(params.host, nil, { family = 'inet', protocol = 'tcp' })
  assert(addrinfo, 'no suitable host found')
  params.addr = addrinfo[1].addr

  local http_decoder = coroutine.wrap(http_codec.decode)
  local websocket_decoder = coroutine.wrap(websocket_codec.decode)
  local ws_key = base64_encode(table.concat({ rand4(), rand4(), rand4(), rand4() }))

  self.sock = uv.new_tcp()
  self.sock:connect(params.addr, params.port, function(err)
    if err then
      callback(err)
      return
    end

    self.sock:write(http_codec.encode({
      method = 'get',
      resource = params.resource,
      host = params.host,
      port = params.port,
      headers = {
        { 'upgrade', 'websocket' },
        { 'connection', 'upgrade' },
        { 'sec-websocket-key', ws_key },
        { 'sec-websocket-version', '13' },
      },
    }))

    local http_response
    self.sock:read_start(function(err, chunk)
      if err then
        callback(err)
        return
      end
      if not chunk then
        -- TODO: socket closed?
        return
      end

      if not http_response then
        http_response = http_decoder(chunk)
        if http_response and http_response.status_code ~= 101 then
          callback('could not upgrade to websocket', http_response)
          return
        end
        callback(nil, http_response)
        return
      end

      local decoded_frame = websocket_decoder(chunk)
      while decoded_frame do
        if not self:handle_frame(decoded_frame) then
          return
        end
        decoded_frame = websocket_decoder('')
      end
    end)
  end)

  return self
end

---@private
---@param frame websocket_frame
---@return boolean continue wether the websocket should continue reading
function WebSocket:handle_frame(frame)
  if frame.opcode == websocket_codec.opcodes.CLOSE then
    self:close()
    return false
  else
    self:emit('message', frame.payload)
    return true
  end
end

function WebSocket:close(code, http_response)
  if not self.sock then
    return
  end
  if self.sock:is_closing() then
    return
  end

  self.sock:shutdown()
  self.sock:close()
  self.sock = nil
  self:emit('close', code, http_response)
end

---@param message string
function WebSocket:write(message)
  self.sock:write(websocket_codec.encode({
    fin = true,
    opcode = websocket_codec.opcodes.TEXT,
    masking_key = rand4(),
    payload = message,
  }))
end

return WebSocket
