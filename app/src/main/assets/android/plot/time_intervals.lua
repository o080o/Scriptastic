local DEBUG = arg ~= nil
local MINUTE = 60
local HOUR = 60*60
local DAY = 24*HOUR
local YEAR_DAYS = 365

local floor = math.floor
local odate = os.date
local function date2table (d)
    return odate('*t',d)
end
local table2date = os.time

local function year (d)
    return date2table(d).year
end

local tmin,tmax = 4,8

local seconds = {1,2,5,15,30; s=1} -- 4s/1 to 4min/30
local minutes = {1,2,5,15,30; s=60} -- 4min/1 to 4h/30
local hours = {1,2,6,12; s=HOUR}  -- 4h/1 to 2d/6
local days = {1,2,4,7,14; s=DAY} -- 4d/1 to 4m/14
local months = {1,2,3,6; s=1}  -- 4m/1 to 4y/6
local years = {1,10; s=DAY*YEAR_DAYS}

local function match (value,intervals)
    for _,iter in ipairs(intervals) do
        local div = value/iter
        div = floor(div)
        if div >= tmin and div <= tmax then
            if DEBUG then print('divs ',div) end
            return iter*intervals.s
        end
    end
end

local function hour_format (d)
    local tm = odate('%H:%M',d)
    if tm == '00:00' then
        tm = odate('%d %b',d)
    end
    return tm
end

local function check_january (d,last)
    if last==nil or odate ('%m',d) == '01' then
        return odate(' %Y',d)
    else
        return ''
    end
end

local function date_format (d, last)
    return odate('%d %b',d)..check_january(d,last)
end

local function month_format (d,last)
    local yy = ''
    if last == nil or year(d) ~= year(last) then
        yy = odate(' %Y',d)
    end
    return odate('%b',d)..yy
end

local function nearest_month (d)
    local t = date2table(d)
    if t.day > 15 then
        t.month = t.month + 1
    end
    t.day = 1
    return table2date(t)
end

local function nearest_year (d)
    local t = date2table(d)
    if t.month > 6 then
        t.year = t.year + 1
    end
    t.month = 1
    t.day = 1
    return table2date(t)
end


local function next_month (d,nmonth)
    local t = date2table(d)
    for i = 1,nmonth do
        t.day = 28
        local m = t.month
        while m == t.month do
            d = table2date(t)
            t = date2table(d)
            t.day = t.day + 1
        end
    end
    return d
end

function classify (t1,t2)
    local span = t2 - t1  -- NB to check this!
    local day = floor(span/DAY)
    local intvl,fmt,next_tick
    if day >= 4 then
        if day <= 4*YEAR_DAYS then -- case C
            if day < 4*30 then -- four months approx
                fmt = date_format -- e.g 4 Mar
                if DEBUG then print '(days)' end
                intvl = match(day,days)
            else
                fmt = month_format
                if DEBUG then print '(months)' end
                t1 = nearest_month(t1)
                intvl = match(day/30,months)
                next_tick = next_month
            end
        else -- case D
            if DEBUG then print '(years)' end
            fmt = '%Y' -- e.g. 2012
            t1 = nearest_year(t1)
            intvl = match(day/YEAR_DAYS,years)
        end
    else
        local m = floor(span/MINUTE)
        if m < 4 then -- case A
            if DEBUG then print '(sec)' end
            fmt =  '%X'  -- e.g. 12:31:40
            intvl = match(span,seconds)
        else -- case B
            fmt = hour_format
            if m < 4*60 then -- less than 4 hours
                if DEBUG then print '(min)'end
                intvl = match(m,minutes)
            else
                if DEBUG then print '(hours)' end
                intvl = match(m/60,hours)
            end
        end
    end
    if not intvl then return print 'no match' end

    if type(fmt) == 'string' then
        local dspec = fmt
        fmt = function(x) return odate(dspec,x) end
    end
    if not next_tick then
        next_tick = function(t,tick)
            return t + tick
        end
    end
    local t,tend, oldt = t1, t2
    local res,append = {},table.insert
    while t < tend do
        append(res,{t,fmt(t,oldt)})
        oldt = t
        t = next_tick(t,intvl)
    end
    return res,intvl
end

if arg then
    require 'pl'

    local df = Date.Format()

    function test (s1,s2)
        local d1,d2 = df:parse(s1),df:parse(s2)
        print(d1,d2,d2:diff(d1))
        local res,intvl = classify(d1.time,d2.time)
        print('interval',Date(intvl,true))
        for _,item in ipairs(res) do
            print(df:tostring(item[1]),item[2])
        end
    end

    --~ test('4 Sep','6 Sep')
    --~ test('14:20','14:22')
    --test('2:05','2:20')

    local tests = {
        {'2:15','2.17'},
        {'1 Sep 23:00','2 Sep 00:05'},
        {'14:20','15:22'},
        {'2:10','16:15'},
        {'4 Sep', '6 Sep'},
        {'3 Aug 2010', '2 Feb 2011'},
        {'1 Jan 2010', '3 Mar 2016'},
    }

    if arg[1] then
        test(arg[1],arg[2])
    else
        for _,pair in ipairs(tests) do
            test(pair[1],pair[2])
            print '--------------'
        end
    end
else
    return function(axis)
        return classify(axis.min,axis.max)
    end
end

