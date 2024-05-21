-- Notes for Script Messages
-- local buf = vim.api.nvim_create_buf(false, true)
-- vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "Line 1", "Line 2"})
-- print(buf)
-- -- nvim_win_set_buf({window}, {buffer})                      *nvim_win_set_buf()*
--
local cosmos = {}
-- script_url: <url_base>/tools/scriptrunner/?file=<url-encoded file_path>
function cosmos.convert_script_url_to_url(script_url)
	local url_base = vim.split(script_url, '/tools/scriptrunner')[1]
	local file_path = vim.split(script_url, '=')[2]
	file_path = string.gsub(file_path, '%%2F', '/')
	local api_url = url_base .. '/script-api/scripts/' .. file_path
	return api_url
end

function cosmos.convert_script_url_to_lock_url(script_url)
	return cosmos.convert_script_url_to_url(script_url) .. '/lock?scope=DEFAULT'
end

function cosmos.convert_script_url_to_unlock_url(script_url)
	return cosmos.convert_script_url_to_url(script_url) .. '/unlock?scope=DEFAULT'
end

function cosmos.convert_script_url_to_run_url(script_url)
	return cosmos.convert_script_url_to_url(script_url) .. '/run?scope=DEFAULT'
end

function cosmos.convert_script_url_to_download_url(script_url)
	return cosmos.convert_script_url_to_url(script_url) .. '?scope=DEFAULT'
end

function cosmos.curl(pass, url)
	return vim.fn.system("curl -s -H 'Authorization:" .. pass .. "' " .. url)
end

function cosmos.curl_data(pass, url, msg_json)
	local curl_cmd = "curl -s -H 'Authorization:" .. pass .. "' -H 'Content-Type: application/json' --data-raw '" ..
		msg_json .. "' '" .. url .. "'"
	return vim.fn.system(curl_cmd)
end

function cosmos.download_script(script_url)
	local download_url = cosmos.convert_script_url_to_download_url(script_url)
	local script_contents = cosmos.curl('pass', download_url)
	local contents = vim.json.decode(script_contents).contents
	return vim.split(contents, '\n')
end

function cosmos.lock_script(script_url)
	local lock_url = cosmos.convert_script_url_to_lock_url(script_url)
	cosmos.curl('pass', lock_url)
end

function cosmos.unlock_script(script_url)
	local unlock_url = cosmos.convert_script_url_to_unlock_url(script_url)
	cosmos.curl('pass', unlock_url)
end

-- returns Running Script ID
function cosmos.run_script(script_url)
	local run_url = cosmos.convert_script_url_to_run_url(script_url)
	local run_args = '{ "environment": [] }'
	local id = cosmos.curl_data('pass', run_url, run_args)
	return id
end

function cosmos.save_script(buffer, script_url)
	local save_url = cosmos.convert_script_url_to_download_url(script_url)
	local msg = { text = nil }
	msg.text = table.concat(vim.api.nvim_buf_get_lines(buffer, 0, -1, false), '\n')
	local msg_json = vim.json.encode(msg)
	cosmos.curl_data('pass', save_url, msg_json)
end

function cosmos.get_script_url_from_buf(buffer)
	return vim.split(vim.api.nvim_buf_get_name(buffer), 'cosmos://')[2]
end

function cosmos.open_cosmos_script(script_url_arg)
	local contents_list = cosmos.download_script(script_url_arg)
	cosmos.lock_script(script_url_arg)

	local buf_name = 'cosmos://' .. script_url_arg
	local buf = vim.fn.bufnr(buf_name)
	if buf < 0 then
		buf = vim.api.nvim_create_buf(true, false)
		vim.api.nvim_buf_set_name(buf, buf_name)
	end
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, contents_list)
	vim.api.nvim_buf_set_option(buf, 'modified', false)
	vim.api.nvim_win_set_buf(0, buf)
	vim.api.nvim_exec_autocmds('BufReadPost', { buffer = buf })
end

function cosmos.run_cosmos_script(script_url)
	cosmos.lock_script(script_url)
	local id = cosmos.run_script(script_url)
	cosmos.log_stream(id, script_url)
end

-- api_url: http base address (ex. http://localhost:2900)
function cosmos.log_stream(id, script_url)
	local url_base = vim.split(script_url, '/tools/scriptrunner')[1]
	local subscriber_str = '{"command":"subscribe","identifier":"{\\"channel\\":\\"RunningScriptChannel\\",\\"id\\":' ..
		id .. '}"}'

	vim.cmd('split')
	local win = vim.api.nvim_get_current_win()
	local buf_log = vim.api.nvim_create_buf(true, true)
	vim.api.nvim_buf_set_name(buf_log, script_url .. '.' .. id .. '.log')
	vim.api.nvim_exec_autocmds('BufReadPost', { buffer = buf_log })
	local buf_debug = vim.api.nvim_create_buf(true, true)
	vim.api.nvim_win_set_buf(win, buf_log)

	local Websocket = require('websocket').Websocket
	local base_address = vim.split(url_base, 'http://', {})[2]
	base_address = vim.split(base_address, ':', {})[1]
	cosmos.ws = Websocket:new({
		host = base_address,
		port = 2900,
		path = '/script-api/cable?scope=DEFAULT&authorization=pass',
		origin = "http://localhost",
		auto_connect = false
	})
	cosmos.ws:add_on_connect(function()
		cosmos.ws:send_text(subscriber_str)
	end)
	cosmos.ws:add_on_message(
		function(frame)
			vim.schedule(function()
				vim.api.nvim_buf_set_lines(buf_debug, -1, -1, false, { frame.payload })
				local msg = vim.json.decode(frame.payload).message
				if msg then
					if type(msg) ~= 'table' then -- this is a number for ping messages
						return
					end
					if msg.type == 'output' then
						local output_lines = cosmos.parse_output(msg)
						vim.api.nvim_buf_set_lines(buf_log, -1, -1, false, output_lines)
					end
				end
			end)
		end)
	cosmos.ws:connect()
end

-- Expects .line
-- returns array of message lines
function cosmos.parse_output(msg)
	return vim.split(msg.line, '\n', { trimempty = true })
end

function cosmos.setup()
	-- Cosmos Commands --
	vim.api.nvim_create_user_command('CosmosOpen',
		function(args)
			local script_url_arg = args.args
			cosmos.open_cosmos_script(script_url_arg)
		end,
		{ nargs = 1 })
	vim.api.nvim_create_user_command('CosmosRun',
		function(args)
			local script_url_arg = args.args or vim.api.nvim_get_current_buf()
			cosmos.run_cosmos_script(script_url_arg)
		end,
		{ nargs = '?' })

	-- Autocommands --
	vim.api.nvim_create_autocmd({ "BufWriteCmd" }, {
		pattern = { "cosmos://*" },
		callback = function()
			local buffer = vim.api.nvim_get_current_buf()
			local script_url = cosmos.get_script_url_from_buf(buffer)
			cosmos.save_script(buffer, script_url)
			vim.api.nvim_buf_set_option(buffer, 'modified', false)
			cosmos.lock_script(script_url)
		end

	})
	vim.api.nvim_create_autocmd({ "BufDelete" }, {
		pattern = { "cosmos://*" },
		callback = function()
			local buffer = vim.api.nvim_get_current_buf()
			local script_url = cosmos.get_script_url_from_buf(buffer)
			cosmos.unlock_script(script_url)
		end
	})
end

return cosmos
