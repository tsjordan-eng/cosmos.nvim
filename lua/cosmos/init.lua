-- Notes for Script Messages
-- local buf = vim.api.nvim_create_buf(false, true)
-- vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "Line 1", "Line 2"})
-- print(buf)
-- -- nvim_win_set_buf({window}, {buffer})                      *nvim_win_set_buf()*
--
local cosmos = {}
-- script_url: <url_base>/tools/scriptrunn/?file=<url-encoded file_path>
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

function cosmos.convert_script_url_to_download_url(script_url)
	return cosmos.convert_script_url_to_url(script_url) .. '?scope=DEFAULT'
end

function cosmos.curl(pass, url)
	return vim.fn.system("curl -s -H 'Authorization:" .. pass .. "' " .. url)
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

function cosmos.save_script(buffer, script_url)
	local save_url = cosmos.convert_script_url_to_download_url(script_url)
	local msg = { text = nil }
	msg.text = table.concat(vim.api.nvim_buf_get_lines(buffer, 0, -1, false), '\n')
	local msg_json = vim.json.encode(msg)
	local curl_cmd = "curl -s -H 'Authorization:pass' -H 'Content-Type: application/json' --data-raw '" ..
		msg_json .. "' '" .. save_url .. "'"
	vim.fn.system(curl_cmd)
end

function cosmos.get_script_url_from_buf(buffer)
	return vim.split(vim.api.nvim_buf_get_name(buffer), 'cosmos://')[2]
end

function cosmos.setup()
	vim.api.nvim_create_user_command('Cosmos',
		function(args)
			local script_url_arg = args.args

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
		end,
		{ nargs = 1 })
end

return cosmos
