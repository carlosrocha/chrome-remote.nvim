local defaults = require('chrome-remote')
local http = require('chrome-remote.http')

local M = {}

local function merge(opts, params)
  return vim.tbl_deep_extend('force', defaults.__get_conf().connection, opts, params)
end

-- Request the list of the available open targets/tabs of the remote instance.
-- GET /json/list
---@param opts? chrome_conn_config
---@param callback fun(err: any, result: http_response<chrome_target[]>?)
function M.list(opts, callback)
  local params = {
    method = 'get',
    resource = '/json/list',
  }

  return http.make_request(merge(opts or {}, params), callback)
end

-- Fetch the Chrome Debugging Protocol descriptor.
-- GET /json/protocol
---@param opts? chrome_conn_config
---@param callback fun(err: any, result: http_response?)
function M.protocol(opts, callback)
  local params = {
    method = 'get',
    resource = '/json/protocol',
  }

  return http.make_request(merge(opts or {}, params), callback)
end

-- Create a new target/tab in the remote instance.
-- PUT /json/new?{url}
---@param url? string
---@param opts? chrome_conn_config
---@param callback fun(err: any, result: http_response)
function M.new(url, opts, callback)
  local params = {
    method = 'put',
    resource = '/json/new?' .. (url or ''),
  }

  return http.make_request(merge(opts, params), callback)
end

-- Brings a page into the foreground (activate a tab).
-- GET /json/activate/{targetId}
---@param target_id? string
---@param opts? chrome_conn_config
---@param callback fun(err: any, result: http_response)
function M.activate(target_id, opts, callback)
  assert(target_id, 'target_id is required for this operation')
  local params = {
    method = 'get',
    resource = '/json/activate/' .. target_id,
  }

  return http.make_request(merge(opts or {}, params), callback)
end

-- Close an open target/tab of the remote instance.
-- GET /json/close/{targetId}
---@param target_id? string
---@param opts? chrome_conn_config
---@param callback fun(err: any, result: http_response)
function M.close(target_id, opts, callback)
  assert(target_id, 'targetId is required for this operation')
  local params = {
    method = 'get',
    resource = '/json/close/' .. target_id,
  }

  return http.make_request(merge(opts or {}, params), callback)
end

return M
