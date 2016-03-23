--- I/O Utilities
-- @module android.utils
require 'android.import'
local L = luajava.package 'java.lang'
local IO = luajava.package 'java.io'
local N = luajava.package 'java.net'
local BUFSZ = 4*1024

local utils = {}

--- read all the bytes from a stream as a byte array.
-- @tparam L.InputStream f
-- @treturn [byte]
function utils.readbytes(f)
    local buff = L.Byte{n = BUFSZ}
    local out = IO.ByteArrayOutputStream(BUFSZ)
    local n = f:read(buff)
    while n ~= -1 do
        out:write(buff,0,n)
        n = f:read(buff,0,BUFSZ)
    end
    f:close()
    return out:toByteArray()
end

--- read all the bytes from a stream as a string.
-- @tparam L.InputStream f
-- @treturn string
function utils.readstring(f)
    return tostring(L.String(utils.readbytes(f)))
end

function utils.open_socket (host,port,timeout)
    local client = N.Socket()
    local addr = N.InetSocketAddress(host,port)
    local ok,err = pcall(function()
        client:connect(addr,timeout or 300)
    end)
    if ok then return client else return nil,err end
end

function utils.buffered_reader (stream)
    return IO.BufferedReader(IO.InputStreamReader(stream))
end

function utils.reader_writer (c)
    local r = utils.buffered_reader(c:getInputStream())
    local w = IO.PrintWriter(c:getOutputStream())
    return r,w
end

return utils

