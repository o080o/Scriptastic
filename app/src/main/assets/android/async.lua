-------------
-- Asynchronous utilities for running code on main thread
-- and grabbing HTTP requests and sockets in the background.
-- @module android.async

require 'android.import'
local LS = service -- global for now
local PK = luajava.package
local L = PK 'java.lang'
local U = PK 'java.util'

local async = {}

--- create a Runnable from a function.
-- @func callback
-- @treturn L.Runnable
function async.runnable (callback)
    return proxy('java.lang.Runnable',{
        run = function()
            local ok,err = pcall(callback)
            if not ok then LS:log(err) end
        end
    })
end

local handler = bind 'android.os.Handler'()
local runnable_cache = {}

--- call a function on the main thread.
-- @func callback
-- @param later optional time value in milliseconds
function async.post (callback,later)
    local runnable = runnable_cache[callback]
    if not runnable then
        -- cache runnable so we can delete it if needed
        runnable = async.runnable(callback)
        runnable_cache[callback] = runnable
    elseif later ~= nil then
        -- only keep one instance for delayed execution
        handler:removeCallbacks(runnable)
    end
    if not later then
        handler:post(runnable)
    elseif type(later) == 'number' then
        handler:postDelayed(runnable,later)
    end
end

function async.post_later (later,callback)
    async.post(callback,later)
end

function async.cancel_post (callback)
    local runnable = runnable_cache[callback]
    if runnable then
        handler:removeCallbacks(runnable)
        runnable_cache[callback] = nil
    end
end

--- read an HTTP request asynchronously.
-- @string request
-- @bool gzip
-- @func callback function to receive string result
function async.read_http(request,gzip,callback)
    return LS:createLuaThread('android.http_async',L.Object{request,gzip},nil,callback)
end

--- read lines from a socket asynchronously.
-- @string address
-- @number port
-- @func on_line called with each line read
-- @func on_error (optional) called with any error message
function async.read_socket_lines(address,port,on_line,on_error)
    local args = U.HashMap()
    args:put('addr',address)
    args:put('port',port)
    LS:createLuaThread('android.socket_async',args,
        on_line,on_error or function(...) print(...) end
    )
    return function()
        args:get('socket'):close()
    end
end

return async
