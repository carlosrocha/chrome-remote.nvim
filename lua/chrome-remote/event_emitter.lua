---@class EventEmitter
---@field private handlers table<string, table<fun(), fun()>>
local EventEmitter = {}
EventEmitter.__index = EventEmitter

function EventEmitter.new()
  return EventEmitter.init(setmetatable({}, EventEmitter))
end

function EventEmitter.init(obj)
  obj.handlers = {}
  return obj
end

---@param event string
---@param handler fun(...): any
function EventEmitter:on(event, handler)
  if not self.handlers[event] then
    self.handlers[event] = {}
  end
  self.handlers[event][handler] = handler
  return self
end

---@param event string
function EventEmitter:emit(event, ...)
  if self.handlers[event] then
    for handler in pairs(self.handlers[event]) do
      local ok, err = pcall(handler, ...)
      if not ok then
        vim.schedule(function()
          vim.api.nvim_err_writeln(vim.inspect(err))
        end)
      end
    end
  end
end

return EventEmitter
