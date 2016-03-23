--- Basic utilities for making LuaJava more convenient to use.
-- Note that many of these functions are currently global!
-- @module android.import

local append,pcall,getmetatable = table.insert,pcall,getmetatable
local new, bindClass = luajava.new, luajava.bindClass
local Array

local function new_len (a)
    return Array:getLength(a)
end

local function new_tostring (o)
   return o:toString()
end

local function primitive_type (t)
    local ok,res = pcall(function() return t.TYPE end)
    if ok then return res end
end

local function call (t,...)
    local obj,stat
    if select('#',...) == 1 and type(select(1,...))=='table' then
        local T = select(1,...)
        t = primitive_type(t) or t
        if #T == 0 and T.n then -- e.g. String{n=10}
            T = T.n
        end
        obj = make_array(t,T)
        getmetatable(obj).__len = new_len
    else
        stat,obj = pcall(new,t,...)
    end
	getmetatable(obj).__tostring = new_tostring
	return obj
end

local function massage_classname (classname)
    if classname:find('_') then
        classname = classname:gsub('_','$')
    end
    return classname
end

local classes = {}

--- import a Java class.
-- Like `luajava.bindClass` except it caches classes by class name
-- and makes the result callable, ending the need for explicit `luajava.new` calls.
-- Inner classes are not accessed with a '$' but with '_'.
-- If a single Lua table is passed to such a constructor, this means
-- 'make an array of these values'; if the table is just `{n=number}`, then
-- make an array of this size. If you use an object wrapper like `java.lang.Double`
-- then it will create an array of the _primitive_ type.
-- @see make_array
-- @param klassname - the fully qualified Java class name
function bind (klassname)
    local res
    klassname = massage_classname(klassname)
    if not classes[klassname] then
        local res,class = pcall(bindClass,klassname)
        if res then
            local mt = getmetatable(class)
            mt.__call = call
            classes[klassname] = class
            return class
        else
            return nil,class
        end
    else
        return classes[klassname]
    end
end

local function import_class (classname,packagename,T)
    local class,err = bind(packagename)
    if class then
        T[classname] = class
    end
    return class,err
end

local lookupMT = {
	__index = function(T,classname)
        classname = massage_classname(classname)
        for i,p in ipairs(T._packages) do
            local class = import_class(classname,p..classname,T)
            if class then return class end
        end
        error("cannot find "..classname)
	end
}

--- represents a Java package.
-- @param P the full package path
-- @param T optional table to receive the cached results
-- @return package
-- @usage L = luajava.package 'java.lang'; s = L.String()
function luajava.package (P,T)
    local pack = T or {}
    if P ~= '' then P = P..'.' end
    pack._packages={P}
    setmetatable(pack,lookupMT)
    return pack
end

--- convenient way to access Java classes globally.
-- However, not a good idea in larger programs. You will have
-- to call `luajava.set_global_package_search` or set the global
--  `GLOBAL_PACKAGE_SEARCH` before requiring `import`.
-- @param P a package path to add to the global lookup paths.
function import (P)
    if not rawget(_G,'_packages') then
        error('global package lookup not initialized')
    end
    local i = P:find('%.%*$')
    if i then -- a wildcard; put into the package list, including the final '.'
        append(_G._packages,P:sub(1,i))
    else
        local classname = P:match('([%w_]+)$')
        local klass = import_class(classname,P)
        if not klass then
            error("cannot find "..P)
        end
        return klass
    end
end

--- enable global lookup of java classes
function luajava.set_global_package_search()
    luajava.package('',_G)
end

--- create a 'class' implementing a Java interface.
-- Thin wrapper over `luajava.createProxy`
function proxy (classname,obj)
    classname = massage_classname(classname)
	-- if the classname contains dots it's assumed to be fully qualified
	if classname:find('.',1,true) then
		return luajava.createProxy(classname,obj)
	end
	-- otherwise, it must lie on the package path!
    if rawget(_G,'_packages') then
        for i,p in ipairs(_G._packages) do
            local ok,res = pcall(luajava.createProxy,p..classname, obj)
            if ok then return res end
        end
    end
	error ("cannot find "..classname)
end

--- return a Lua iterator over an Iterator.
function enum(e)
   return function()
      if e:hasNext() then
        return e:next()
     end
   end
end

Array = bind 'java.lang.reflect.Array'

--- create a Java array.
-- @param Type Java type
-- @param list table of Lua values, or a size
function make_array (Type,list)
    local len
    local init = type(list)=='table'
    if init then
        len = #list
    else
        len = list
    end
    local arr = Array:newInstance(Type,len)
    if arr == nil then return end
    if init then
        for i,v in ipairs(list) do
            arr[i] = v
        end
    end
    return arr
end


if GLOBAL_PACKAGE_SEARCH then
    luajava.set_global_package_search()
    import 'java.lang.*'
    import 'java.util.*'
end


