# chrome-remote.nvim

This package provides a pure Lua API that wraps the [Chrome DevTools Protocol](https://chromedevtools.github.io/devtools-protocol/).
Designed to be used with Neovim.

## Examples

Since this package does not provide a plugin, here are some ideas on how this API can be used:

### Live edit an HTML document

The following example demonstrates a live HTML editor using this API. It prompts for a URL and then opens
a new Chrome tab along with a floating window in Neovim that contains the HTML code of the root document.
As you make changes to the code within Neovim, the HTML on the target webpage is automatically updated to reflect those changes.

[Source](examples/liveedit.lua)

Demo:

https://github.com/carlosrocha/chrome-remote.nvim/assets/312351/b2947163-f783-40b3-9b3e-ec7b88865cce

### Fill out textareas in your browser from Neovim

This example shows how to connect to Chrome and fill out textareas on a webpage directly from Neovim.
It works by finding the textareas on the page and attaching focus handlers to them. When a textarea is focused,
a floating window appears in Neovim. Any changes made in the Neovim window are automatically reflected
in the corresponding textarea on the webpage. This functionality is kind of the opposite of [firenvim](https://github.com/glacambre/firenvim).

[Source](examples/icenvim.lua)

Demo:

https://github.com/carlosrocha/chrome-remote.nvim/assets/312351/314e1d2a-87e9-47ae-864a-8ac7ce9c90fd

## Installation

Using packer.nvim:

```lua
use { 'carlosrocha/chrome-remote.nvim' }
```

## Setup

### Browser

First you'll need a browser with the `remote-debugging-port` open. On Chrome you can do that by
adding the following argument to your startup command:

```
chrome --remote-debugging-port=9222
```

If you want to open a separate Chrome instance you can specify a different path for the user profile.

```
chrome --user-data-dir=<some directory>
```

You can find more detailed instructions on the [CDP homepage](https://chromedevtools.github.io/devtools-protocol/).

### API

Not much setup is needed for the API, if you are using the defaults you don't need to call this.

```lua
require('chrome-remote').setup {
  connection = {
    host = 'localhost',
    port = 9222,
  },
}
```

## Usage

### Using the API

```lua
-- most of these calls need to be run in a coroutine
coroutine.wrap(function()
  local Chrome = require('chrome-remote.chrome')
  local client = Chrome.new()
  -- you can get a list of targets by going to http://localhost:9222/json/list
  -- or you can use the provided action `require('chrome-remote.actions').list()` to get
  -- a UI selection of the targets
  client:open_url('ws://localhost:9222/devtools/page/ABC')

  -- once connected you can use the `send()` method to send commands to the Chrome target
  client:send('Page.navigate', { url = 'https://github.com' })

  -- if you expect a result from your call you can capture the return
  local err, result = client:send('DOM.getDocument', { depth = 0 })

  -- you can also use the following shortcut for the same call
  -- (don't forget to use colon to keep the `self` reference)
  local err, result = client.DOM:getDocument({ depth = 0 })

  -- to listen to events you can do the following
  client.Network:requestWillBeSent(function(err, params)
    -- check for err, then do something with params
  end)

  -- all commands and events are mapped to client.<domain>.<method>
  -- you can find them all available at https://chromedevtools.github.io/devtools-protocol/tot/
  -- or locally at http://localhost:9222/json/protocol

  -- close the connection
  client:close()
end)()
```

### Provided actions

The following UI actions are provided to help manage connections and create targets.

```lua
-- Lists the targets on the Chrome instance, then execute the callback when a choice is made
require('chrome-remote.actions').list({}, function(err, target)
  -- example of using the target selected
  client:open_url(target.webSocketDebuggerUrl)
end)

-- Creates a new target (tab) on the Chrome instance, then executes the callback with the created target
require('chrome-remote.actions').new({}, function(err, target)
  -- example of using the target selected
  client:open_url(target.webSocketDebuggerUrl)
end)
```

## Caveats

- This API currently does not support secure sockets (wss).
- Only meant for local connections, haven't tested this with remote Chrome instances.
