pretty = require 'android'.new()
local utils = require 'android.utils'

local LP = luajava.package
local L = LP 'java.lang'
local G = LP 'android.graphics'
local W = LP 'android.widget'
local T = LP 'android.text'
local S = LP 'android.text.style'
local IO = LP 'java.io'


local lua_keyword = {
    ["and"] = true, ["break"] = true,  ["do"] = true,
    ["else"] = true, ["elseif"] = true, ["end"] = true,
    ["false"] = true, ["for"] = true, ["function"] = true,
    ["if"] = true, ["in"] = true,  ["local"] = true, ["nil"] = true,
    ["not"] = true, ["or"] = true, ["repeat"] = true,
    ["return"] = true, ["then"] = true, ["true"] = true,
    ["until"] = true,  ["while"] = true
}

local sep = package.config:sub(1,1)

function readmodule (me,mod)
    mod = mod:gsub('%.',sep)
    for m in package.path:gmatch('[^;]+') do
        local nm = m:gsub('?',mod)
        local f = io.open(nm,'r')
        if f then
            local contents = f:read '*a'
            f:close()
            return contents
        end
    end
    -- try assets?
    local am = me.a:getAssets()
    local f = am:open(mod..'.lua')
    return utils.readstring(f)
end


function pretty.create (me,mod)
    mod = mod or 'example.pretty'

    local show_pretty = true
    if mod:match '!$' then
        show_pretty = false
        mod = mod:sub(1,-2)
    end
    me.a:setTitle("Showing "..mod)
    local source = readmodule(me,mod,package.path)

    local text
    if show_pretty then
        text = T.SpannableString(source)

        local s_comment = G.Color.RED
        local s_string = G.Color.GREEN
        local s_keyword = G.Color:parseColor '#AAAAFF'

        local slen = #source

        local function span (style,i1,i2)
            text:setSpan(S.ForegroundColorSpan(style),i1-1,i2,0)
        end

        local i1,i2,is,ie = 1,1
        while true do
            i2 = source:find('%S',i2) -- next non-space
            if not i2 then break end
            is,ie = source:find ('^%-%-.-\n',i2)
            if is then
                span(s_comment,is,ie-1)
            else
                quote = source:match ('^(%[%[)',i2) or source:match([[^(["'])]],i2)
                if quote then
                    if quote == '[[' then quote = '%]%]' end
                    _,ie = source:find(quote,i2+1)
                    span(s_string,i2,ie)
                else
                    is,ie,word = source:find ('^(%a+)[^%d_]',i2)
                    if is and lua_keyword[word] then
                        span(s_keyword,is,ie-1)
                    else
                        _,ie = source:find('^%S*',i2)
                       ie = i2
                    end
                end
            end
            i2 = ie+1
        end
    end

    local view = me:textView{size='12sp',scrollable=true}
    if show_pretty then
        view:setText(text,W.TextView_BufferType.SPANNABLE)
    else
        view:setText(source)
    end
    return view

end

return pretty
