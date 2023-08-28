local WebSocket = require('chrome-remote.websocket')
local EventEmitter = require('chrome-remote.event_emitter')
local endpoints = require('chrome-remote.endpoints')
local urllib = require('chrome-remote.url')
local json = vim.json

---@alias CDP.Client Chrome

---@class CDP.Error
---@field code integer
---@field message string
---@field data string

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

--- Main protocol descriptor that contains all available commands, events, and types supported
--- by the target
---@class chrome_protocol_descr
---@field version { major: string, minor: string }
---@field domains chrome_domain_descr[]

--- Targets available on Chrome, received from /json/list or /json/new
---@class chrome_target
---@field id string
---@field title string
---@field type string
---@field url string
---@field webSocketDebuggerUrl string

---@class chrome_command
---@field id integer
---@field method string
---@field sessionId? string
---@field params? any

---@alias chrome_result { id: integer, method: string, sessionId?: string, result?: any, error?: any }
---@alias chrome_event { method: string, sessionId?: string, params?: any }

--- Chrome client to connect to a remote target.
--- Emits the following events:
--- 'event'
--- '<domain>.<event_name>'
---@class Chrome: EventEmitter
---@class Chrome: CDP
---@field private last_cmd_id integer
---@field private callbacks table<string, function>
---@field private websocket? WebSocket
---@field private url? string

local Chrome = setmetatable({}, { __index = EventEmitter })

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

--- Creates a new instance
---
---@return Chrome
function Chrome.new()
  local self = EventEmitter.init(setmetatable({}, { __index = Chrome }))
  self.last_cmd_id = 0
  self.callbacks = {}
  return self
end

---@async
---@param url string
function Chrome:open_url(url)
  local params = urllib.parse(url)
  self:open(params)
end

---@private
---@param cmd_descr chrome_cmd_descr
---@param domain_descr chrome_domain_descr
---@return fun(self: { client: Chrome }, method: string)
local function create_command(cmd_descr, domain_descr)
  local cmd_name = string.format('%s.%s', domain_descr.domain, cmd_descr.name)
  return function(self, ...)
    return self.client:send(cmd_name, ...)
  end
end

---@private
---@param event_descr chrome_event_descr
---@param domain_descr chrome_domain_descr
---@return fun(self: { client: Chrome }, callback: fun(err: any, result: chrome_event))
local function create_eventcb(event_descr, domain_descr)
  local event_name = string.format('%s.%s', domain_descr.domain, event_descr.name)
  return function(self, callback)
    self.client:on(event_name, callback)
  end
end

--- Load the protocol descriptor to initialize all domains and attach them to the client.
--- This also associates each domain with its respective commands and event callbacks
---@private
---@param protocol_descr chrome_protocol_descr
function Chrome:_setup_api(protocol_descr)
  for _, domain_descr in ipairs(protocol_descr.domains) do
    self[domain_descr.domain] = setmetatable({ client = self }, {})

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

--- Open the websocket connection to the target, awaits on successful websocket connection
--- Must be run in a coroutine
---@async
---@param params connection_params
---@return any err, Chrome instance
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

  self:_setup_api(result.content)
  self.websocket = WebSocket.new()
  self.websocket:on('message', function(message)
    self:_handle_message(json.decode(message))
  end)
  self.websocket:open(params, make_callback())
  return coroutine.yield()
end

--- Closes the connection to target, and releases resources
function Chrome:close()
  self.last_cmd_id = 0
  self.callbacks = {}
  self.websocket:close()
  self.websocket = nil
end

--- Sends the command to the target
--- This is only async if no callback is provided
---@async
---@param method string In the form of <domain>.<method>
---@return any err, chrome_result? result
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
function Chrome:_handle_message(message)
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
