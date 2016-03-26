package.path = package.path .. ";/sdcard/scriptastic/?.lua"
function loadFromSDCard()
	return require('start')
end
local ok,mod=pcall(loadFromSDCard)
if ok and mod then
	return mod
else --provide a default view.... because why not
	service:log("could not load user file: "..tostring(ok))
	service:log(tostring(mod))
	local import = require'scriptastic.luajavautils'.import

	local TextView = import'android.widget.TextView'
	local LinearLayout = import'android.widget.LinearLayout'
	local ScrollView = import'android.widget.ScrollView'


	local main = {}
	function main.onCreate(activity, arg, state)

		local layout = LinearLayout(activity)
		layout:setOrientation(LinearLayout.VERTICAL)

		local scrollview = ScrollView(activity)
		scrollview:addView(layout)

		for i=1,100 do
			local txt = TextView(activity)
			txt:setText("another text widget, #"..tostring(i))
			layout:addView(txt)
		end
		return scrollview
	end
	return main
end