local base64 = require('chrome-remote.base64')

describe('base64', function()
  describe('encode', function()
    for i, scenario in ipairs({
      { input = '', expected = '' },
      { input = 'A', expected = 'QQ==' },
      { input = 'AB', expected = 'QUI=' },
      { input = 'abc', expected = 'YWJj' },
      { input = 'Hello, World!', expected = 'SGVsbG8sIFdvcmxkIQ==' },
      {
        input = string.char(
          0x1,
          0x2,
          0x3,
          0x4,
          0x5,
          0x6,
          0x7,
          0x8,
          0x9,
          0xA,
          0xB,
          0xC,
          0xD,
          0xE,
          0xF,
          0x10
        ),
        expected = 'AQIDBAUGBwgJCgsMDQ4PEA==',
      },
    }) do
      it(tostring(i), function()
        assert.are.same(scenario.expected, base64.encode(scenario.input))
      end)
    end
  end)
end)
