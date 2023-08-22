local M = {}

local byte = string.byte
local char = string.char
local lshift = bit.lshift
local rshift = bit.rshift
local bor = bit.bor
local band = bit.band

local chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'

function M.encode(data)
  local result = {}

  local j = 1
  for i = 1, #data, 3 do
    local b1, b2, b3 = byte(data, i, i + 2)
    b2 = b2 or 0
    b3 = b3 or 0

    local idx1 = rshift(b1, 2)
    local idx2 = bor(lshift(band(b1, 0x3), 4), rshift(b2, 4))
    local idx3 = bor(lshift(band(b2, 0xF), 2), rshift(b3, 6))
    local idx4 = band(b3, 0x3F)

    result[j] = char(
      byte(chars, idx1 + 1),
      byte(chars, idx2 + 1),
      i + 1 <= #data and byte(chars, idx3 + 1) or 61,
      i + 2 <= #data and byte(chars, idx4 + 1) or 61
    )
    j = j + 1
  end

  return table.concat(result)
end

return M
