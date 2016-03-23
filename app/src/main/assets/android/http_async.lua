require 'android.import'
local utils = require 'android.utils'

return function (thread,args)
    local res
    local url = bind'java.net.URL'(args[1])
    local connect = url:openConnection()
    local f = connect:getInputStream()
    if args[2] then -- GZIPd response!
        local GZIPIS = bind'java.util.zip.GZIPInputStream'
        local gf = GZIPIS(f)
        print('gf',gf,GZIPIS)
        res = utils.readstring(gf)
        f:close()
    else
        res = utils.readstring(f)
    end
    return res
end
