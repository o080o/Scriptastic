-- parse inputType specifications

local T = luajava.package 'android.text'

local function decamelify (rest)
    rest = rest:gsub('(%l)(%u)',function(l,u)
        return l..'_'..u
    end)
    return rest:upper()
end

-- known input classes. Some of these are synthetic, e.g.
-- 'date' is short for 'datetimeDate'
local kinds = {text=true,number=true,phone=true,datetime=true,
    date={'datetime','date'},time={'datetime','time'}
}

-- these are the known flag patterns for the input classes above;
-- anything else is a variation
local variations = {
    TEXT = {'^CAP','^AUTO','^MULTI','^NO'},
    NUMBER = {'^PASSWORD'},
}

local function check_flag (kind,rest)
    if not variations[kind] then return false end
    for _,v in ipairs(variations[kind]) do
        if rest:match(v) then return true end
    end
end

return function (input)
    local tt = android.split(input,'|')
    local IT = 0
    local type_flag = {}
    for _,t in ipairs(tt) do
        local kind,rest = t:match '(%l+)(.*)'
        local what = kinds[kind]
        if type(what) == 'table' then
            kind = what[1]
            rest = what[2]
        end
        if what then
            kind = kind:upper()
            if not type_flag[kind] then -- only add this flag once!
                --print('kind',kind)
                IT = IT + T.InputType['TYPE_CLASS_'..kind]
                type_flag[kind] = true
            end
            if rest ~= '' then
                rest = decamelify(rest)
                if check_flag(kind,rest) then
                    rest = '_FLAG_'..rest
                else
                    rest = '_VARIATION_'..rest
                end
                --print('rest',rest)
                local ok,type = pcall(function()
                    return T.InputType['TYPE_'..kind..rest]
                end)
                if not ok then error('unknown inputType flag') end
                IT = IT + type
            end
        else
            error('unknown inputType '..kind)
        end
    end
    return IT
end

