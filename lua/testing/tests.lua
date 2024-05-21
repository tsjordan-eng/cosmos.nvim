local cosmos = require('cosmos')
describe("REST API", function()
	-- before_each(function()
	--   bounter = 0
	-- end)

	it("converts script URL to API URL", function()
		local url =
		'http://localhost:2900/tools/scriptrunner/?file=DRIFTER2DEV%2Fprocedures%2Fsim_circle.rb'
		local script_api = cosmos.convert_script_url_to_url(url)
		local expected_script_api = 'http://localhost:2900/script-api/scripts/DRIFTER2DEV/procedures/sim_circle.rb'
		assert.equals(expected_script_api, script_api)
	end)

	it("converts script URL to download API URL", function()
		local url =
		'http://localhost:2900/tools/scriptrunner/?file=DRIFTER2DEV%2Fprocedures%2Fsim_circle.rb'
		local script_api = cosmos.convert_script_url_to_download_url(url)
		local expected_script_api = 'http://localhost:2900/script-api/scripts/DRIFTER2DEV/procedures/sim_circle.rb?scope=DEFAULT'
		assert.equals(expected_script_api, script_api)
	end)

	it("converts script URL to lock API URL", function()
		local url =
		'http://localhost:2900/tools/scriptrunner/?file=DRIFTER2DEV%2Fprocedures%2Fsim_circle.rb'
		local script_api = cosmos.convert_script_url_to_lock_url(url)
		local expected_script_api = 'http://localhost:2900/script-api/scripts/DRIFTER2DEV/procedures/sim_circle.rb/lock?scope=DEFAULT'
		assert.equals(expected_script_api, script_api)
	end)

	it("converts script URL to unlock API URL", function()
		local url =
		'http://localhost:2900/tools/scriptrunner/?file=DRIFTER2DEV%2Fprocedures%2Fsim_circle.rb'
		local script_api = cosmos.convert_script_url_to_unlock_url(url)
		local expected_script_api = 'http://localhost:2900/script-api/scripts/DRIFTER2DEV/procedures/sim_circle.rb/unlock?scope=DEFAULT'
		assert.equals(expected_script_api, script_api)
	end)

	it("converts script URL to run API URL", function()
		local url =
		'http://localhost:2900/tools/scriptrunner/?file=DRIFTER2DEV%2Fprocedures%2Fsim_circle.rb'
		local script_api = cosmos.convert_script_url_to_run_url(url)
		local expected_script_api = 'http://localhost:2900/script-api/scripts/DRIFTER2DEV/procedures/sim_circle.rb/run?scope=DEFAULT'
		assert.equals(expected_script_api, script_api)
	end)

	it("determines file type from script URL", function()
		local url =
		'http://localhost:2900/tools/scriptrunner/?file=DRIFTER2DEV%2Fprocedures%2Fsim_circle.rb'
		local script_api = cosmos.convert_script_url_to_download_url(url)
		local expected_script_api = 'http://localhost:2900/script-api/scripts/DRIFTER2DEV/procedures/sim_circle.rb?scope=DEFAULT'
		assert.equals(expected_script_api, script_api)
	end)

end)

-- {"identifier":"{\"channel\":\"RunningScriptChannel\",\"id\":521}","message":{{"type":"output","line":"2024/05/19 04:33:10.002 (cmd_tlm_test.rb:469):CHECK:TARGET2EDU2 SOFTWARESTATUSMESSAGE COMMANDPROCESSORSTATUS_NUMCOMMANDSRECEIVED  ==  50 + 1 success with value == 51 after waiting 5.89152173 seconds\n","color":"BLACK"}
-- {"identifier":"{\"channel\":\"RunningScriptChannel\",\"id\":521}","message":{"type":"line","filename":"DRIFTER2EDU2/procedures/sim_circle.rb","line_no":55,"state":"error"}}
-- {"type":"ping","message":1716234836}
describe("Websockets", function()

	it("handles script message updates", function()
		local json_msg = [[
{
  "type": "output",
  "line": "2024/05/19 04:33:10.002 (cmd_tlm_test.rb:469): CHECK: DRIFTER2EDU2 SOFTWARESTATUSMESSAGE COMMANDPROCESSORSTATUS_NUMCOMMANDSRECEIVED  ==  50 + 1 success with value == 51 after waiting 5.89152173 seconds\n",
  "color": "BLACK"
}]]
		local expected_script_msg = {}
		expected_script_msg[1] = '2024/05/19 04:33:10.002 (cmd_tlm_test.rb:469): CHECK: DRIFTER2EDU2 SOFTWARESTATUSMESSAGE COMMANDPROCESSORSTATUS_NUMCOMMANDSRECEIVED  ==  50 + 1 success with value == 51 after waiting 5.89152173 seconds'
		local parsed_msg = cosmos.parse_output(json_msg)
		assert.equal(table.concat(expected_script_msg), table.concat(parsed_msg))
		assert(vim.deep_equal(expected_script_msg, parsed_msg))
	end)


end)
