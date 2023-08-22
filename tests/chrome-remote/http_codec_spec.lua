local http_codec = require('chrome-remote.http_codec')

describe('http', function()
  describe('encode', function()
    local scenarios = {
      {
        title = 'simple',
        input = {
          method = 'GET',
          resource = '/hello',
          host = 'localhost',
          port = 9222,
        },
        expected = 'GET /hello HTTP/1.1\r\nhost:localhost:9222\r\n\r\n',
      },
      {
        title = 'with headers',
        input = {
          method = 'GET',
          resource = '/hello',
          host = 'localhost',
          port = 9222,
          headers = {
            { 'user-agent', 'nvim' },
          },
        },
        expected = 'GET /hello HTTP/1.1\r\nhost:localhost:9222\r\nuser-agent:nvim\r\n\r\n',
      },
      {
        title = 'with headers and content',
        input = {
          method = 'GET',
          resource = '/hello',
          host = 'localhost',
          port = 9222,
          headers = {
            { 'user-agent', 'nvim' },
          },
          content = 'hello world',
        },
        expected = 'GET /hello HTTP/1.1\r\nhost:localhost:9222\r\ncontent-length:11\r\nuser-agent:nvim\r\n\r\nhello world',
      },
      {
        title = 'websocket handshake',
        input = {
          method = 'GET',
          host = '127.0.0.1',
          port = 9222,
          resource = '/devtools/XXX',
          headers = {
            { 'upgrade', 'websocket' },
            { 'connection', 'upgrade' },
            { 'sec-websocket-key', '123' },
            { 'sec-websocket-version', '13' },
          },
        },
        expected = 'GET /devtools/XXX HTTP/1.1\r\nhost:127.0.0.1:9222\r\nupgrade:websocket\r\nconnection:upgrade\r\nsec-websocket-key:123\r\nsec-websocket-version:13\r\n\r\n',
      },
    }

    for _, s in ipairs(scenarios) do
      it(s.title, function()
        assert.equal(s.expected, http_codec.encode(s.input))
      end)
    end
  end)

  describe('decode', function()
    local scenarios = {
      {
        title = 'simple',
        input = 'HTTP/1.1 200 OK\r\nContent-length:5\r\n\r\nhello',
        expected = {
          status_code = 200,
          status_text = 'OK',
          content = 'hello',
          headers = {
            ['content-length'] = '5',
          },
        },
      },
      {
        title = 'fragmented header',
        input = { 'HTTP/1.1 200 OK', '\r\nContent-length:5', '\r\n\r\nhello' },
        expected = {
          status_code = 200,
          status_text = 'OK',
          content = 'hello',
          headers = {
            ['content-length'] = '5',
          },
        },
      },
      {
        title = 'fragmented content',
        input = { 'HTTP/1.1 200 OK\r\nContent-length:5\r\n\r\nhel', 'lo' },
        expected = {
          status_code = 200,
          status_text = 'OK',
          content = 'hello',
          headers = {
            ['content-length'] = '5',
          },
        },
      },
    }

    for _, s in ipairs(scenarios) do
      it(s.title, function()
        local decoder = coroutine.wrap(http_codec.decode)

        if type(s.input) == 'table' then
          local result
          for _, frag in ipairs(s.input) do
            result = decoder(frag)
          end
          assert.are.same(s.expected, result)
        else
          assert.are.same(s.expected, decoder(s.input))
        end
      end)
    end
  end)
end)
