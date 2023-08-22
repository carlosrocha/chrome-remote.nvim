local bit = require('bit')

local rshift = bit.rshift
local lshift = bit.lshift
local band = bit.band
local bor = bit.bor
local bxor = bit.bxor
local byte = string.byte
local char = string.char

local M = {}

---@alias websocket_frame { fin: boolean, opcode: integer, masking_key?: string, payload: string|integer }

---@enum opcodes
M.opcodes = {
  CONT = 0x0,
  TEXT = 0x1,
  BIN = 0x2,
  CLOSE = 0x8,
  PING = 0x9,
  PONG = 0xA,
}

---@param i integer
local function byte_len(i)
  local bytes = 0
  while i > 0 do
    bytes = bytes + 1
    i = rshift(i, 8) -- Shift right by 8 bits
  end
  return bytes
end

---@param frame websocket_frame
---@return string
function M.encode(frame)
  assert(not frame.masking_key or #frame.masking_key == 4, 'masking_key should be 4 bytes')

  -- first byte, just the fin bit
  local b = frame.fin and 0x80 or 0
  local result = char(bor(b, frame.opcode))

  -- second byte
  b = frame.masking_key and 0x80 or 0

  local len
  if type(frame.payload) == 'number' then
    len = byte_len(frame.payload)
  else
    len = #frame.payload
  end

  if len < 126 then
    result = result .. char(bor(b, len))
  elseif len < 65536 then
    result = result .. char(bor(b, 126), band(rshift(len, 8), 0xff), band(len, 0xff))
  else
    local high = len / 0x100000000
    result = result
      .. char(
        bor(b, 127),
        band(rshift(high, 24), 0xff),
        band(rshift(high, 16), 0xff),
        band(rshift(high, 8), 0xff),
        band(high, 0xff),
        band(rshift(len, 24), 0xff),
        band(rshift(len, 16), 0xff),
        band(rshift(len, 8), 0xff),
        band(len, 0xff)
      )
  end

  if frame.masking_key then
    local masking_key = { string.byte(frame.masking_key, 1, #frame.masking_key) }
    local masked = {}
    for i = 1, len do
      masked[i] = char(bxor(byte(frame.payload, i), masking_key[((i - 1) % 4) + 1]))
    end
    return result .. frame.masking_key .. table.concat(masked)
  elseif type(frame.payload) == 'number' then
    -- TODO: only 2 byte bin payloads are supported
    return result .. string.char(rshift(frame.payload, 8), band(frame.payload, 0xff))
  else
    return result .. frame.payload
  end
end

-- Frames are described here: https://tools.ietf.org/html/rfc6455#section-5.2
---@param buffer string
---@return websocket_frame frame
function M.decode(buffer)
  while true do
    local pos = 1

    while #buffer < 2 do
      buffer = buffer .. (coroutine.yield() or error('expected more data'))
    end

    local result = {}
    result.fin = band(rshift(byte(buffer, pos), 7), 1) == 1
    result.opcode = band(byte(buffer, pos), 15)
    pos = pos + 1

    local mask = rshift(byte(buffer, pos), 7) == 1
    assert(not mask, 'masking not supported')

    local payload_len = band(byte(buffer, pos), 127)
    pos = pos + 1

    if payload_len == 126 then
      while #buffer < pos + 2 do
        buffer = buffer .. (coroutine.yield() or error('expected more data'))
      end
      payload_len = bor(lshift(byte(buffer, pos), 8), byte(buffer, pos + 1))
      pos = pos + 2
    elseif payload_len == 127 then
      while #buffer < pos + 8 do
        buffer = buffer .. (coroutine.yield() or error('expected more data'))
      end
      payload_len = bor(
        lshift(byte(buffer, pos), 24),
        lshift(byte(buffer, pos + 1), 16),
        lshift(byte(buffer, pos + 2), 8),
        byte(buffer, pos + 3)
      ) * 0x100000000 + bor(
        lshift(byte(buffer, pos + 4), 24),
        lshift(byte(buffer, pos + 5), 16),
        lshift(byte(buffer, pos + 6), 8),
        byte(buffer, pos + 7)
      )
      pos = pos + 8
    end

    local payload_end = pos + payload_len - 1
    while #buffer < payload_end do
      buffer = buffer .. (coroutine.yield() or error('expected more data'))
    end

    if result.opcode == M.opcodes.CLOSE and payload_len == 2 then
      -- parse payload as status code
      local code = string.sub(buffer, pos, payload_end)
      result.payload = lshift(byte(code, 1), 8) + byte(code, 2)
    else
      result.payload = string.sub(buffer, pos, payload_end)
    end

    pos = payload_end + 1
    buffer = string.sub(buffer, pos) .. coroutine.yield(result)
  end
end

return M
