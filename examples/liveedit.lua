-- NB: This is not a plugin, this is just a proof of concept of using this library
-- The steps we perform are the following:
-- 1. Intercept all requests on the page, look for the first document request and save it
-- 2. wait for that request to finish, then fetch the body
-- 3. open a floating window with that content
-- 4. on change set the document content

local function start(url)
  local client = require('chrome-remote.chrome').new()
  local err = client:open_url(url)
  if err then
    print(vim.inspect(err))
  end

  local request

  -- This function will be called once the root html has finished loading
  local function start_editor(result)
    local initial_lines = vim.split(result.body, '\n')
    local ui = vim.api.nvim_list_uis()[1]
    local bufnr = vim.api.nvim_create_buf(true, true)
    vim.api.nvim_buf_set_lines(bufnr, 0, #initial_lines, false, initial_lines)
    vim.api.nvim_buf_set_option(bufnr, 'filetype', 'html')
    local winnr = vim.api.nvim_open_win(bufnr, true, {
      title = request.documentURL,
      border = 'double',
      relative = 'win',
      row = math.floor((ui.height / 2) - (ui.height / 4)),
      col = math.floor((ui.width / 2) - (ui.width / 2.5)),
      height = math.floor(ui.height / 2),
      width = math.floor(ui.width / 1.25),
    })
    vim.api.nvim_win_set_buf(winnr, bufnr)

    vim.api.nvim_create_autocmd({ 'TextChanged', 'TextChangedI' }, {
      buffer = bufnr,
      callback = function()
        client.Page:setDocumentContent({
          frameId = request.frameId,
          html = table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), '\n'),
        })
      end,
    })
    vim.api.nvim_create_autocmd({ 'BufLeave', 'WinLeave' }, {
      buffer = bufnr,
      callback = function()
        vim.api.nvim_buf_delete(bufnr, { force = true })
        client:close()
      end,
    })
  end

  -- save the first document which will be the root html document
  -- https://chromedevtools.github.io/devtools-protocol/tot/Network/#event-requestWillBeSent
  client.Network:requestWillBeSent(function(params)
    if not request and params.type == 'Document' then
      request = params
    end
  end)

  -- Wait for that request to finish so we can safely fetch the response body, then start the editor
  -- https://chromedevtools.github.io/devtools-protocol/tot/Network/#event-loadingFinished
  client.Network:loadingFinished(function(params)
    if request and params.requestId == request.requestId then
      client.Network:getResponseBody(
        { requestId = request.requestId },
        vim.schedule_wrap(function(err, result)
          start_editor(result)
        end)
      )
    end
  end)

  -- Enable Networking events, and reload the page to start
  client.Network:enable()
  client.Page:reload()
end

require('chrome-remote.actions').new(nil, function(err, target)
  coroutine.wrap(start)(target.webSocketDebuggerUrl)
end)
