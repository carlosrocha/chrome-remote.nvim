test:
	nvim --headless -c "PlenaryBustedDirectory tests/chrome-remote" -c "cquit 1"
.PHONY: test

fmt:
	stylua -g 'lua/**/*.lua' -g 'tests/**/*.lua' -g '!**/_meta/*.lua' -- .
.PHONY: fmt

lint:
	luacheck lua/chrome-remote
.PHONY: lint
