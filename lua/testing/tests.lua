describe("some basics", function()
	-- before_each(function()
	--   bounter = 0
	-- end)

	local cosmos = require('cosmos')
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

	it("determines file type from script URL", function()
		local url =
		'http://localhost:2900/tools/scriptrunner/?file=DRIFTER2DEV%2Fprocedures%2Fsim_circle.rb'
		local script_api = cosmos.convert_script_url_to_download_url(url)
		local expected_script_api = 'http://localhost:2900/script-api/scripts/DRIFTER2DEV/procedures/sim_circle.rb?scope=DEFAULT'
		assert.equals(expected_script_api, script_api)
	end)

end)
