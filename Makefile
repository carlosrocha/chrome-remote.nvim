test:
	nvim --headless -c "PlenaryBustedDirectory tests/chrome-remote" -c "cquit 1"
.PHONY: test

fmt:
	stylua -g lua/**/*.lua tests/**/*.lua
.PHONY: fmt

lint:
	luacheck lua/chrome-remote
.PHONY: lint
