require 'android.import'
local utils = require 'android.utils'
local N = luajava.package 'java.net'

return function (thrd,arg)
    local addr = arg:get 'addr'
    local port = arg:get 'port'
    local server = addr=='*'
    local client, reader, line
    if not server then
        if type(addr) == 'userdata' then
            client = addr
        else
            client = utils.open_socket(addr,port)
        end
    else
        server = N.ServerSocket(port)
        client = server:accept()
    end
    arg:put('socket',client)
    reader = utils.buffered_reader(client:getInputStream())
    client:setKeepAlive(true)
    pcall(function()
        line = reader:readLine()
        while line do
            thrd:setProgress(line)
            line = reader:readLine()
        end
    end)
    reader:close()
    client:close()
    if server then server:close() end
    return 'ok'
end
