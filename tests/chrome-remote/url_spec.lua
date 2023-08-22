local url = require('chrome-remote.url')

describe('url', function()
  describe('parse', function()
    it('ws url', function()
      local expected = {
        protocol = 'ws',
        host = '127.0.0.1',
        port = 9222,
        resource = '/devtools/page/XXX',
      }

      assert.are.same(expected, url.parse('ws://127.0.0.1:9222/devtools/page/XXX'))
    end)
  end)
end)
