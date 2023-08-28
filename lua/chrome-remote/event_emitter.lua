---@class EventEmitter
---@field private _handlers table<string, table<fun(), fun()>>
local EventEmitter = {}
EventEmitter.__index = EventEmitter

function EventEmitter.init(obj)
  obj._handlers = {}
  return obj
end

---@param event string
---@param handler fun(...): any
---@return EventEmitter
function EventEmitter:on(event, handler)
  if not self._handlers[event] then
    self._handlers[event] = {}
  end
  self._handlers[event][handler] = handler
  return self
end

---@param event string
function EventEmitter:emit(event, ...)
  if self._handlers[event] then
    for handler in pairs(self._handlers[event]) do
      local ok, err = pcall(handler, ...)
      if not ok then
        vim.schedule(function()
          vim.api.nvim_err_writeln(vim.inspect(err))
        end)
      end
    end
  end
end

---@protected
function EventEmitter:_clear_event_emitter()
  self._handlers = {}
end

return EventEmitter
