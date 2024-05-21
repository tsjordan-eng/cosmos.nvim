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

function cosmos.create_script_buffer(script_url, contents_list, window)
	local buf_name = 'cosmos://' .. script_url
	local buf = vim.fn.bufnr(buf_name)
	if buf < 0 then
		buf = vim.api.nvim_create_buf(true, false)
		vim.api.nvim_buf_set_name(buf, buf_name)
	end
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, contents_list)
	vim.api.nvim_buf_set_option(buf, 'modified', false)
	vim.api.nvim_win_set_buf(window, buf)
	vim.api.nvim_exec_autocmds('BufReadPost', { buffer = buf })
end

function cosmos.open_cosmos_script(script_url)
	local contents_list = cosmos.download_script(script_url)
	cosmos.lock_script(script_url)
	cosmos.create_script_buffer(script_url, contents_list, 0)
end

function cosmos.run_cosmos_script(script_url)
	cosmos.lock_script(script_url)
	local id = cosmos.run_script(script_url)
	cosmos.log_stream(id, script_url)
end

-- api_url: http base address (ex. http://localhost:2900)
function cosmos.log_stream(id, script_url)
	local url_base = vim.split(script_url, '/tools/scriptrunner')[1]

	-- Create Log Buffer
	local win_orig = vim.api.nvim_get_current_win()
	vim.cmd('split')
	local log_win = vim.api.nvim_get_current_win()
	local log_buf = vim.api.nvim_create_buf(true, true)
	vim.api.nvim_buf_set_name(log_buf, script_url .. '.' .. id .. '.log')
	vim.api.nvim_exec_autocmds('BufReadPost', { buffer = log_buf })
	local debug_buf = vim.api.nvim_create_buf(true, true)
	vim.api.nvim_win_set_buf(log_win, log_buf)

	-- Create Websocket --
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
		local subscriber_str = '{"command":"subscribe","identifier":"{\\"channel\\":\\"RunningScriptChannel\\",\\"id\\":' ..
			id .. '}"}'
		cosmos.ws:send_text(subscriber_str)
	end)
	-- Handle Websocket Messages
	cosmos.ws:add_on_message(
		function(frame)
			vim.schedule(function()
				vim.api.nvim_buf_set_lines(debug_buf, -1, -1, false, { frame.payload })
				local msg = vim.json.decode(frame.payload).message
				if msg then
					if type(msg) ~= 'table' then -- this is a number for ping messages
						return
					end
					if msg.type == 'output' then
						local output_lines = cosmos.parse_output(msg)
						local cursor_pos = vim.api.nvim_win_get_cursor(log_win)
						local buflines = vim.api.nvim_buf_line_count(log_buf)
						vim.api.nvim_buf_set_lines(log_buf, -1, -1, false, output_lines)
						if cursor_pos[1] == buflines then
							vim.api.nvim_win_set_cursor(log_win,
								{ buflines + #output_lines, cursor_pos[2] })
						end
					elseif msg.type == 'file' then
						local file_contents = vim.split(msg.text, '\n')
						cosmos.create_script_buffer(script_url, file_contents, win_orig)
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
			local script_url_arg = args.args
			if script_url_arg == '' then
				local buf = vim.api.nvim_get_current_buf()
				local buf_name = vim.api.nvim_buf_get_name(buf)
				script_url_arg = vim.split(buf_name, 'cosmos://')[2]
			end
			if script_url_arg == nil then
				print('Must give a script runner URL argument or first have :CosmosOpen')
				return
			end
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
