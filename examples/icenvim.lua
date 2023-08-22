-- NB: This is not a plugin, this is just a proof of concept of using this library
-- The steps we perform are the following:
-- 1. Get all the textareas
-- 2. Attach to each element an onfocus event handler that calls our binding
-- 3. When we receive a call to our binding we start the editor
-- 4. Any change to the buffer will be sent to the textarea value

-- internal function used to calculate the cursor position within the text
-- so it can be passed to the textarea
local function calc_pos(cursor, lines)
  local pos = 0
  if cursor[1] > 1 then
    for i = 1, cursor[1] do
      pos = pos + #lines[i]
    end
  end
  return pos + cursor[2]
end

local function start(url)
  local client = require('chrome-remote.chrome').new()
  client:open_url(url)

  local editor_open = false
  local function start_editor(args)
    if editor_open then
      return
    end
    editor_open = true

    local initial_lines = vim.split(args.value, '\n')
    local ui = vim.api.nvim_list_uis()[1]
    local bufnr = vim.api.nvim_create_buf(true, true)
    vim.api.nvim_buf_set_lines(bufnr, 0, #initial_lines, false, initial_lines)
    local winnr = vim.api.nvim_open_win(bufnr, true, {
      title = args.label,
      border = 'double',
      relative = 'win',
      row = math.floor((ui.height / 2) - (ui.height / 4)),
      col = math.floor((ui.width / 2) - (ui.width / 4)),
      height = math.floor(ui.height / 2),
      width = math.floor(ui.width / 2),
    })
    vim.api.nvim_win_set_buf(winnr, bufnr)

    -- kill the buf/win when focus is lost
    vim.api.nvim_create_autocmd({ 'BufLeave', 'WinLeave' }, {
      buffer = bufnr,
      callback = function()
        editor_open = false
        vim.api.nvim_win_close(winnr, true)
        vim.api.nvim_buf_delete(bufnr, { force = true })
      end,
    })

    vim.api.nvim_create_autocmd({ 'TextChanged', 'TextChangedI' }, {
      buffer = bufnr,
      callback = function()
        local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
        local pos = calc_pos(vim.api.nvim_win_get_cursor(winnr), lines)
        local newval = table.concat(lines, '\n')

        client.Runtime:callFunctionOn({
          objectId = args.object_id,
          -- set the value, plus keep the textarea's view into the vim cursor
          functionDeclaration = string.format(
            [[function() {
              this.value = %s;
              this.selectionStart = this.selectionEnd = %d;
              this.blur();
              this.focus();
            }]],
            vim.json.encode(newval),
            pos
          ),
        })
      end,
    })
  end

  client.Runtime:enable()
  client.Runtime:addBinding({ name = 'icenvim_onfocus' })
  client.Runtime:bindingCalled(function(params)
    if params.name == 'icenvim_onfocus' then
      vim.schedule(function()
        start_editor(vim.json.decode(params.payload))
      end)
    end
  end)

  local err, doc = client.DOM:getDocument({ depth = 0 })
  local err, result = client.DOM:querySelectorAll({
    nodeId = doc.root.nodeId,
    selector = 'textarea:not([readonly])',
  })

  for _, node_id in ipairs(result.nodeIds) do
    local err, node = client.DOM:resolveNode({ nodeId = node_id })
    client.Runtime:callFunctionOn({
      objectId = node.object.objectId,
      -- send us back the object_id, initial val, and try to find a good label
      functionDeclaration = string.format(
        [[function() {
        this.addEventListener('focus', function() {
          window.icenvim_onfocus(JSON.stringify({
            object_id: %s,
            value: this.value,
            label: [this.labels?.length ? this.labels[0].textContent : '', this.name, this.id].find(e => e),
          }));
        });
      }]],
        vim.json.encode(node.object.objectId)
      ),
    })
  end
end

require('chrome-remote.actions').list(nil, function(err, choice)
  coroutine.wrap(start)(choice.webSocketDebuggerUrl)
end)
