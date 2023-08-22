local WebSocket = require('chrome-remote.websocket')
local EventEmitter = require('chrome-remote.event_emitter')
local endpoints = require('chrome-remote.endpoints')
local urllib = require('chrome-remote.url')
local json = vim.json

---@class chrome_cmd_descr
---@field name string
---@field parameters any[]
---@field returns any[]

---@alias chrome_event_descr { name: string, parameters: any[] }
---@alias chrome_type_descr { id: string, type: string, properties: any[] }

---@class chrome_domain_descr
---@field domain string
---@field types chrome_type_descr[]
---@field commands chrome_cmd_descr[]
---@field events chrome_event_descr[]

---@class chrome_protocol_descr
---@field version { major: string, minor: string }
---@field domains chrome_domain_descr[]

---@class chrome_target
---@field id string
---@field title string
---@field type string
---@field url string
---@field webSocketDebuggerUrl string

---@alias chrome_command { id: integer, method: string, sessionId?: string, params?: any }
---@alias chrome_result { id: integer, method: string, sessionId?: string, result?: any, error?: any }
---@alias chrome_event { method: string, sessionId?: string, params?: any }

---@class Chrome : EventEmitter
---@field private last_cmd_id integer
---@field private callbacks table<string, function>
---@field private websocket WebSocket
---@field private url string

local Chrome = setmetatable({}, { __index = EventEmitter })
local ChromeMeta = { __index = Chrome }

local function assert_resume(thread, ...)
  local success, err = coroutine.resume(thread, ...)
  if not success then
    error(debug.traceback(thread, err), 0)
  end
end

-- Tries to create an async callback if a thread is running
local function make_callback()
  local thread = coroutine.running()
  if not thread then
    return
  end

  return function(...)
    assert_resume(thread, ...)
  end
end

---@return Chrome
function Chrome.new()
  local self = EventEmitter.init(setmetatable({}, ChromeMeta))
  self.last_cmd_id = 0
  self.callbacks = {}
  return self
end

---@param url string
function Chrome:open_url(url)
  local params = urllib.parse(url)
  self:open(params)
end

---@param cmd_descr chrome_cmd_descr
---@param domain_descr chrome_domain_descr
local function create_command(cmd_descr, domain_descr)
  local cmd_name = string.format('%s.%s', domain_descr.domain, cmd_descr.name)
  return function(self, ...)
    -- TODO: check here if self is passed correctly
    return self:send(cmd_name, ...)
  end
end

---@param event_descr chrome_event_descr
---@param domain_descr chrome_domain_descr
---@return fun(self: Chrome, callback: fun(err: any, result: chrome_event))
local function create_eventcb(event_descr, domain_descr)
  local event_name = string.format('%s.%s', domain_descr.domain, event_descr.name)
  return function(self, callback)
    -- TODO: check here if self is passed correctly
    self:on(event_name, callback)
  end
end

---@private
---@param protocol_descr chrome_protocol_descr
function Chrome:setup_api(protocol_descr)
  for _, domain_descr in ipairs(protocol_descr.domains) do
    self[domain_descr.domain] = setmetatable({ parent = self }, {
      __index = function(t, key)
        if key == 'send' then
          return function(self, ...)
            return self.parent:send(...)
          end
        elseif key == 'on' then
          return function(self, ...)
            self.parent:on(...)
          end
        else
          return self[key]
        end
      end,
    })
    if domain_descr.commands then
      for _, cmd_descr in ipairs(domain_descr.commands) do
        self[domain_descr.domain][cmd_descr.name] = create_command(cmd_descr, domain_descr)
      end
    end

    if domain_descr.events then
      for _, ev_descr in ipairs(domain_descr.events) do
        self[domain_descr.domain][ev_descr.name] = create_eventcb(ev_descr, domain_descr)
      end
    end
  end
end

-- Must be run in a coroutine
---@param params connection_params
function Chrome:open(params)
  endpoints.protocol({
    protocol = 'http',
    host = params.host,
    port = params.port,
  }, make_callback())
  local err, result = coroutine.yield()
  if err then
    return err, result
  end

  self:setup_api(result.content)
  self.websocket = WebSocket.new()
  self.websocket:on('message', function(message)
    self:handle_message(json.decode(message))
  end)
  self.websocket:open(params, make_callback())
  return coroutine.yield()
end

function Chrome:close()
  self.last_cmd_id = 0
  self.callbacks = {}
  self.websocket:close()
end

---@param method string
function Chrome:send(method, ...)
  local n = select('#', ...)
  assert(n <= 2, 'only up to 2 args allowed')

  local params, callback
  if n == 1 then
    local arg1 = select(1, ...)
    if type(arg1) == 'function' or type(arg1) == 'thread' then
      callback = arg1
    else
      params = arg1
    end
  else
    params = select(1, ...)
    callback = select(2, ...)
  end

  self.last_cmd_id = self.last_cmd_id + 1
  local cmd_id = self.last_cmd_id

  self.websocket:write(json.encode({
    id = cmd_id,
    method = method,
    params = params or vim.empty_dict(),
  }))

  if callback then
    self.callbacks[tostring(cmd_id)] = callback
  else
    local thread_cb = make_callback()
    if thread_cb then
      self.callbacks[tostring(cmd_id)] = make_callback()
      return coroutine.yield()
    end
  end
end

---@private
---@param message chrome_result|chrome_event
function Chrome:handle_message(message)
  -- command response
  if message.id then
    local cb = self.callbacks[tostring(message.id)]
    if cb then
      if message.error then
        cb(message.error)
      else
        cb(nil, message.result)
      end

      self.callbacks[tostring(message.id)] = nil
    end
  elseif message.method then
    -- event
    self:emit('event', message)
    self:emit(message.method, message.params, message.sessionId)
  end
end

return Chrome
