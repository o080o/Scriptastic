-- round to nearby lower multiple of base
local function floorInBase (n,base)
    return base * math.floor(n/base)
end

return function (axis,width)
    local noTicks
    if type(axis.ticks) == 'number' then
        noTicks = axis.ticks
    else
        noTicks = 0.3 * math.sqrt(width)
    end

    local delta = (axis.max - axis.min)/noTicks

    local maxDec = axis.tickDecimals;
    local dec = - math.floor(math.log10(delta));
    if maxDec and dec > maxDec then
        dec = maxDec
    end

    magn = math.pow(10, -dec)
    norm = delta / magn -- norm is between 1.0 and 10.0

    if norm < 1.5 then
        size = 1
    elseif norm < 3 then
        size = 2
        -- special case for 2.5, requires an extra decimal
        if norm > 2.25 and (maxDec == nil or dec + 1 <= maxDec) then
            size = 2.5
            dec = dec + 1
        end
    elseif norm < 7.5 then
        size = 5
    else
        size = 10
    end

    size = size*magn;

    if axis.minTickSize and size < axis.minTickSize then
        size = axis.minTickSize
    end

    local tickDecimals = math.max(0, maxDec and maxDec or dec)
    local tickSize = axis.tickSize or size;

   -- print('ticks',axis.tickDecimals,axis.tickSize)

    if tickDecimals == 0 then
        axis.format = '%d'
    else
        axis.format = '%.'..tickDecimals..'f'
    end

    local ticks = {}
    local start = floorInBase(axis.min,tickSize)
    local i = 0
    local v = -math.huge
    while v < axis.max do
        v = start + i * tickSize
        i = i + 1
        ticks[i] = v
    end
    ticks.format = axis.format
    return ticks

end

