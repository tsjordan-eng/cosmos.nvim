-- http://localhost:2900/tools/scriptrunner/?file=DRIFTER2DEV%2Fprocedures%2Fsim_circle.rb
-- http://localhost:2900/script-api/scripts/DRIFTER2DEV/procedures/sim_circle.rb?scope=DEFAULT
-- :autocmd BufNewFile  *.h	0r ~/vim/skeleton.h
-- vim.api.nvim_create_autocmd({"BufNewFile"}, {
-- 	pattern = {"http://*scriptrunner*.rb"},
-- 	command = "echo 'matched patteeeren?'"})

-- local buf = vim.api.nvim_create_buf(false, true)
-- vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "Line 1", "Line 2"})
-- print(buf)
-- -- nvim_win_set_buf({window}, {buffer})                      *nvim_win_set_buf()*
--
local cosmos = {}
function cosmos.setup()
	vim.api.nvim_create_user_command('Cosmos',
		function(args)
			-- local url = 'http://localhost:2900/tools/scriptrunner/?file=DRIFTER2DEV%2Fprocedures%2Fsim_circle.rb'
			local file = vim.split(args.args, '=')[2]
			file = string.gsub(file, '%%2F', '/')
			local api_url = 'http://localhost:2900/script-api/scripts/' .. file
			-- Lock script for editing
			local lock_url = api_url .. 'lock?scope=DEFAULT'
			vim.fn.system("curl -H 'Authorization:pass' " .. lock_url)
			-- Download script
			local url = api_url .. '?scope=DEFAULT'
			local outp = vim.fn.system("curl -s -H 'Authorization:pass' " .. url)
			local buf = vim.api.nvim_create_buf(true, false)
			local contents = vim.json.decode(outp).contents
			local contents_list = vim.split(contents, '\n')
			vim.api.nvim_buf_set_lines(buf, 0, -1, false, contents_list)
			-- vim.api.nvim_open_win(buf, true, {relative='win', width=12, height=3, bufpos={100,10}})
			vim.api.nvim_win_set_buf(0, buf)
			vim.api.nvim_buf_set_name(buf, 'cosmos://' .. url)
			vim.api.nvim_buf_set_option(buf, 'filetype', 'ruby')
			vim.api.nvim_create_autocmd({ "BufWriteCmd" }, {
				pattern = { "cosmos://*" },
				callback = function()
					-- save_url = api.nvim_buf_get_name(0
					local msg = { text = nil }
					msg.text = table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false), '\n')
					local msg_json = vim.json.encode(msg)
					local curl_cmd = "curl -s -H 'Authorization:pass' -H 'Content-Type: application/json' --data-raw '" ..
						msg_json .. "' '" .. url .. "'"
					vim.fn.system(curl_cmd)
				end

			})
		end,
		{ nargs = 1 })
end
return cosmos
