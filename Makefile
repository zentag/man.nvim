.PHONY: test

test:
	nvim --headless --noplugin \
		-u lua/tests/minimal.lua \
		-c "lua require('plenary.test_harness').test_directory_command([[lua/tests/ { init = 'lua/tests/minimal.lua' }]])"
