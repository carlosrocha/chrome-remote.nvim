local endpoints = require('chrome-remote.endpoints')

local M = {}

---@param id string
local function id_short(id)
  return id:sub(1, 5) .. '…' .. id:sub(#id - 4, #id)
end

-- Display a list of the Chrome WebSocket targets, the callback is executed when a choice is made
---@param opts? chrome_conn_config
---@param callback fun(err: any, response?: chrome_target)
function M.list(opts, callback)
  endpoints.list(
    opts or {},
    vim.schedule_wrap(function(err, response)
      if err then
        callback(err)
        return
      end

      vim.ui.select(response.content, {
        prompt = 'Chrome WebSocket targets',
        format_item = function(item)
          return string.format('%s: %s (%s)', id_short(item.id), item.title, item.url)
        end,
      }, function(choice)
        callback(nil, choice)
      end)
    end)
  )
end

-- Create a new target and connect to it
---@param opts? chrome_conn_config
---@param callback fun(err: any, response?: chrome_target)
function M.new(opts, callback)
  -- url can be empty, defaults to "about:blank"
  vim.ui.input({ prompt = 'New Chrome target URL: ', default = '' }, function(url)
    if url == nil then
      return
    end

    endpoints.new(url, opts or {}, function(err, response)
      if err then
        callback(err)
      else
        callback(nil, response.content)
      end
    end)
  end)
end

return M
