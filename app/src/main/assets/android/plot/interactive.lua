-- interactive logic for AndroLua Plot

local function xclip (x1,x2,xd,axis)
    local xmin, xmax = axis.old_min, axis.old_max
    if x1+xd < xmin then
        return xmin, xmin + (x2-x1)
    elseif x2+xd > xmax then
        return xmax - (x2-x1), xmax
    end
    return x1+xd,x2+xd
end

return function (plot)

    local unscalex, unscaley

    function plot.touch(kind,idx,x,y,dir,z)
        if not unscalex then
            unscalex,unscaley = plot.xaxis.unscale,plot.yaxis.unscale
        end
        x,y = unscalex(x),unscaley(y)
        --print('touch',kind,idx,x,y,dir)
        if z then -- wipes and pinches give us a distance as well
            local is_x = dir=='X'
            local axis = is_x and plot.xaxis or plot.yaxis
            local zs = z*axis.pix2plot
            local v1,v2 = axis.min, axis.max
            if kind=='PINCH' then
                zs = zs/2
                v1 = v1 + zs
                v2 = v2 - zs
            elseif kind=='SWIPE' then
                v1,v2 = xclip(v1,v2,zs,axis)
            end
            if is_x then
                --print('bounds',v1,v2)
                plot:set_xbounds(v1,v2)
            else
                plot:set_ybounds(v1,v2)
            end
        end
    end

    return require 'android.touch'(plot)
end

