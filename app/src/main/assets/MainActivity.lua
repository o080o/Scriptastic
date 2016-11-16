--package.path = package.path .. ";/sdcard/scriptastic/?.lua"

local function loadFromSDCard()
	return require('main')
end
local function loadFromAssets()
	return require('scriptastic/main_fallback')
end

local ok,mod=pcall(loadFromSDCard)
if ok and mod then
	return mod
else
	service:log("could not load from sdcard")
	service:log(tostring(mod))
	-- if there is no specified user activity file, load the fallback.
	local ok, mod = pcall(loadFromAssets)
	if ok and mod then --make sure that worked
		return mod
	else --if it didn't.....
		service:log("could not load from assets")
		service:log(tostring(mod))
		-- this should never happen! but if we can't find anything else to
		-- load, we should at least inform the user that something terrible
		-- went wrong.
		service:log("could not load user file or fallback"..tostring(ok))
		local import = require'scriptastic.luajavautils'.import
		local TextView = import'android.widget.TextView'
		local main = { onCreate = function(self, activity)
			local textview = TextView(activity)
			textview:setText("Could not load activity. Fallback activity unavailable.")
			return textview
		end }
		return main
	end
end
