local websocket_codec = require('chrome-remote.websocket_codec')

local char = string.char
local rep = string.rep

local scenarios = {
  {
    name = 'ping frame',
    input = {
      fin = true,
      opcode = websocket_codec.opcodes.PING,
      payload = '',
    },
    output = char(
      0x89, -- 10001001: fin + ping(0x9) opcode
      0x00 -- 00001001: len = 9 (length of the 'pingdata')
    ),
  },
  {
    name = 'pong frame',
    input = {
      fin = true,
      opcode = websocket_codec.opcodes.PONG,
      payload = '',
    },
    output = char(
      0x8A, -- 10001010: fin + pong(0xA) opcode
      0x00 -- 00001001: len = 9 (length of the 'pingdata')
    ),
  },
  {
    name = 'unmasked close frame',
    input = {
      fin = true,
      opcode = websocket_codec.opcodes.CLOSE,
      payload = 1000,
    },
    output = char(
      0x88, -- 10001000: fin + close(0x8)
      0x02, -- len = 2
      0x03, -- status code
      0xe8
    ),
  },
  {
    name = 'unmasked text frame',
    input = {
      fin = true,
      opcode = websocket_codec.opcodes.TEXT,
      payload = 'hello!!!!',
    },
    output = char(
      0x81, -- 10000001: fin + text(0x1) opcode
      0x09 -- 00001001: len = 9
    ) .. 'hello!!!!',
  },
  {
    name = 'unmasked text frame length 127',
    input = {
      fin = true,
      opcode = websocket_codec.opcodes.TEXT,
      payload = rep('A', 127),
    },
    output = char(
      0x81, -- 10000001: fin + text(0x1) opcode
      0x7E, -- 01111110: using 16-bit length field
      0x00,
      0x7F -- 16-bit length = 127
    ) .. rep('A', 127),
  },
  {
    name = 'unmasked text frame length 255',
    input = {
      fin = true,
      opcode = websocket_codec.opcodes.TEXT,
      payload = rep('A', 255),
    },
    output = char(
      0x81, -- 10000001: fin + text(0x1) opcode
      0x7E, -- 01111110: using 16-bit length field
      0x00,
      0xFF -- 16-bit length = 255
    ) .. rep('A', 255),
  },
  {
    name = 'masked text frame short',
    input = {
      fin = true,
      opcode = websocket_codec.opcodes.TEXT,
      masking_key = char(0x12, 0x23, 0x29, 0x88),
      payload = 'hello world',
    },
    output = char(
      0x81, -- 10000001: fin + text(0x1) opcode
      0x8b, -- 10001011: mask flag + payload length 11 = 1011
      0x12, -- mask 1
      0x23, -- mask 2
      0x29, -- mask 3
      0x88, -- mask 4
      0x7a, -- xor'd payload follows
      0x46,
      0x45,
      0xe4,
      0x7d,
      0x03,
      0x5e,
      0xe7,
      0x60,
      0x4f,
      0x4d
    ),
  },
  {
    name = 'masked text frame long',
    input = {
      fin = true,
      opcode = websocket_codec.opcodes.TEXT,
      masking_key = char(0x12, 0x23, 0x29, 0x88),
      payload = rep('A', 255),
    },
    output = char(
      0x81, -- 10000001: fin + text(0x1) opcode
      0xFE, -- 11111110: masked (0x80) + extended length indicator (0x7E)
      0x00,
      0xFF, -- Extended length: 255
      0x12, -- mask 1
      0x23, -- mask 2
      0x29, -- mask 3
      0x88 -- mask 4
    )
      -- xor'd payload
      .. rep(char(0x53, 0x62, 0x68, 0xC9), 63)
      .. char(0x53, 0x62, 0x68),
  },
}

describe('websocket', function()
  describe('encode', function()
    for _, scenario in ipairs(scenarios) do
      it(scenario.name, function()
        assert.equal(scenario.output, websocket_codec.encode(scenario.input))
      end)
    end
  end)

  describe('decode', function()
    for _, scenario in ipairs(scenarios) do
      -- TODO: enable masked scenarios when supported
      if not vim.startswith(scenario.name, 'masked') then
        it(scenario.name, function()
          local decoder = coroutine.wrap(websocket_codec.decode)
          assert.are.same(scenario.input, decoder(scenario.output))
        end)
      end
    end
  end)
end)
