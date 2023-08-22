local M = {}

---@alias chrome_conn_config { host: string, port: integer }
---@alias chrome_config { connection: chrome_conn_config }

---@type chrome_config
local default_config = {
  connection = {
    host = 'localhost',
    port = 9222,
  },
}

function M.__get_conf()
  return default_config
end

---@param config chrome_config
function M.setup(config)
  default_config = vim.tbl_deep_extend('force', default_config, config or {})
end

return M
