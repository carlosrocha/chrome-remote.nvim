---@class connection_params
---@field protocol string
---@field host string
---@field port integer
---@field resource string
---@field addr string

return {
  ---@param url string
  ---@return connection_params
  parse = function(url)
    -- TODO: very naive parser, always assumes port and resource
    local protocol, host, port, resource = string.match(url, '([^:]+)://([^:]+):([^/]+)(.*)')
    assert(protocol, 'protocol needed on url')
    assert(host, 'host needed on url')
    assert(port, 'port needed on url')
    assert(resource, 'resource needed on url')

    return {
      protocol = protocol,
      host = host,
      port = tonumber(port),
      resource = resource,
    }
  end,
}
