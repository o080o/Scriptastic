--- Androlua plot library.
-- @module android.plot
local G = luajava.package 'android.graphics'
local L = luajava.package 'java.lang'
local V = luajava.package 'android.view'
local array = require 'android.array'
local append = table.insert

local Plot = { array = array }

-- OOP support
local function make_object (obj,T)
    T.__index = T
    return setmetatable(obj,T)
end

local function make_callable (type,ctor)
    setmetatable(type,{
        __call = function(_,...) return ctor(...) end
    })
end

local function union (A,B)
    if A.left > B.left then A.left = B.left end
    if A.bottom > B.bottom then A.bottom = B.bottom end
    if A.right < B.right then A.right = B.right end
    if A.top < B.top then A.top = B.top end
end

local Color = G.Color
local FILL,STROKE = G.Paint_Style.FILL,G.Paint_Style.STROKE
local WHITE,BLACK = Color.WHITE, Color.BLACK

local set_alpha

local function PC (clr,default)
    if type(clr) == 'string' then
        local c,alpha = clr:match '([^:]+):(.+)'
        if alpha then
            print(c,alpha)
            c = PC(c)
            alpha = tonumber(alpha)
            return set_alpha(c,alpha)
        end
    end
    return android.parse_color(clr or default)
end

function set_alpha (c,alpha)
    c = PC(c)
    local R,G,B = Color:red(c),Color:green(c),Color:blue(c)
    alpha = (alpha/100)*255
    return Color:argb(alpha,R,G,B)
end

local function newstroke ()
    local style = G.Paint()
    style:setStyle(STROKE)
    return style
end

local function set_color(style,clr)
    style:setColor(PC(clr))
end

local function fill_paint (clr)
    local style = G.Paint()
    style:setStyle(FILL)
    set_color(style,clr)
    return style
end

local function stroke_paint (clr,width,effect)
    local style = newstroke()
    set_color(style,clr)
    if width then
        style:setStrokeWidth(width)
        style:setAntiAlias(true)
    end
    if effect then
        style:setPathEffect(effect)
    end
    return style
end

local function text_paint (size,clr)
    local style = newstroke()
    style:setTextSize(size)
    if clr then
        set_color(style,clr)
    end
    style:setAntiAlias(true)
    return style
end

local function plot_object_array ()
    local arr = array()
    arr:forall_method 'update'
    arr:forall_method 'draw'
    return arr
end

local flot_colours = {PC"#edc240", PC"#afd8f8", PC"#cb4b4b", PC"#4da74d", PC"#9440ed"}

local Series,Axis,Legend,Anot,TextAnot = {},{},{},{},{}

function Plot.new (t)
    local self = make_object({},Plot)
    if not t.theme then
        t.theme = {textColor='BLACK',background='WHITE'}
    end
    t.theme.color = t.theme.color or t.theme.textColor
    t.theme.colors = t.theme.colors or flot_colours
    self.background = fill_paint(t.background or t.theme.background)
    self.area = fill_paint(t.fill or t.theme.background)
    self.color = t.color or t.theme.color
    self.axis_paint = stroke_paint(self.color)
    self.aspect_ratio = t.aspect_ratio or 1
    self.margin = {}
    self.series = plot_object_array()
    self.annotations = plot_object_array()
    self.grid = t.grid
    if t.axes == false then
        t.xaxis = {invisible=true}
        t.yaxis = {invisible=true}
    end
    self.xaxis = Axis.new(self,t.xaxis or {})
    self.xaxis.horz = true
    self.yaxis = Axis.new(self,t.yaxis or {})

    self.theme = t.theme
    self.interactive = t.interactive

    local W = android.me.metrics.widthPixels
    local defpad = W/30
    if t.padding then
        defpad = t.padding
    end
    self.padding = {defpad,defpad,defpad,defpad}
    self.pad = defpad
    self.sample_width = 2*self.pad

    self.colours = self.theme.colors

    if #t == 0 then error("must provide at least one Series!") end -- relax this later??
    for _,s in ipairs(t) do
        self:add_series(s)
    end

    if t.annotations then
        for _,a in ipairs(t.annotations) do
            self:add_annotation(a)
        end
    end

    if t.legend ~= false then
        self.legend = Legend.new(self,t.legend)
    end

    return self
end

local function add (arr,obj)
    append(arr,obj)
    if obj.tag then arr[obj.tag] = obj end
    obj.idx = #arr
end

function Plot:add_series (s)
    add(self.series,Series.new (self,s))
end

function Plot:add_annotation (a)
    local anot = a.text and TextAnot.new(self,a) or Anot.new(self,a)
    add(self.annotations,anot)
end

function Plot:get_series (idx)
    return self.series[idx]  -- array index _or_ tag
end

function Plot:get_annotation (idx)
    return self.annotations[idx]  -- array index _or_ tag
end

make_callable(Plot,Plot.new)

function Plot:calculate_bounds_if_needed (force)
    local xaxis, yaxis = self.xaxis, self.yaxis
    -- have to update Axis bounds if they haven't been set...
    -- calculate union of all series bounds
    if force or not xaxis:has_bounds() or not yaxis:has_bounds() then
        local huge = math.huge
        local bounds = {left=huge,right=-huge,bottom=huge,top=-huge}
        for s in self.series:iter() do
            union(bounds,s:bounds())
        end
        if (force and not xaxis.fixed_bounds) or not xaxis:has_bounds() then
            xaxis:set_bounds(bounds.left,bounds.right,true)
        end
        if (force and not yaxis.fixed_bounds) or not yaxis:has_bounds() then
            yaxis:set_bounds(bounds.bottom,bounds.top,true)
        end
    end
end

function Plot:update_and_paint (noforce)
    self.force = not noforce
    self:update()
    if self.View then self.View:invalidate() end
end

function Plot:set_xbounds (x1,x2)
    self.xaxis:set_bounds(x1,x2)
    self:update_and_paint(true)
end

function Plot:set_ybounds (y1,y2)
    self.yaxis:set_bounds(y1,y2)
    self:update_and_paint(true)
end

function Plot:update (width,height,fixed_width,fixed_height)
    if width then
        if fixed_width and width > 0 then
            self.width = width
        else
            height = 400
            self.width = height
        end
    elseif not self.init then
        -- we aren't ready for business yet
        return
    end

    local xaxis,yaxis = self.xaxis,self.yaxis

    self:calculate_bounds_if_needed(self.force)
    self.force = false

    xaxis:init()
    yaxis:init()

    if not self.init then
        local P = self.padding
        local L,T,R,B = P[1],P[2],P[3],P[4]
        local AR,BW,BH = self.aspect_ratio
        local X,Y = xaxis.thick,yaxis.thick

        -- margins around boxes
        local M = 7
        self.outer_margin = {left=M,top=M,right=M,bottom=M} --outer
        -- padding around plot
        self.margin = {
            left = L + Y,
            top = T,
            right = R,
            bottom = B + X
        }

        -- we now know the extents of the axes and can size our plot area
        if fixed_width and width > 0 then
            BW = width - L - R - Y
            BH = AR*BW
            self.width = width
            self.height = BH + X + T + B
        else
            BH = height - T - B - X
            BW = BH/AR
            self.width = BH + Y + L + R
            self.height = height
        end
        self.boxheight = BH
        self.boxwidth = BW

        self.init = true
    end

    -- we have the exact self area dimensions and can now scale data properly
    xaxis:setup_scale()
    yaxis:setup_scale()

    self.annotations:update()

end

function Plot:next_colour ()
    return self.colours [#self.series % #self.colours + 1]
end

function Plot:resized(w,h)
    -- do we even use this anymore?
    self.width = w
    self.height = h
end

-- get all series with labels, plus the largest label.
function Plot:fetch_labelled_series ()
    local series = array()
    local wlabel = ''
    for s in self.series:iter '_.label~=nil' do
        series:append(s)
        if #s.label > #wlabel then
            wlabel = s.label
        end
    end
    return series, wlabel
end

function Plot.draw(plot,c)
    c:drawPaint(plot.background)

    c:save()
    c:translate(plot.margin.left,plot.margin.top)
    local bounds = G.Rect(0,0,plot.boxwidth,plot.boxheight)
    if plot.area then
        c:drawRect(bounds,plot.area)
    end
    c:drawRect(bounds,plot.axis_paint)
    c:clipRect(bounds)
    plot.series:draw(c)
    plot.annotations:draw(c)
    c:restore()
    plot.xaxis:draw(c)
    plot.yaxis:draw(c)
    c:translate(plot.margin.left,plot.margin.top)
    if plot.legend then
        plot.legend:draw(c)
    end
end

function Plot:measure (pwidth,pheight,width_fixed, height_fixed)
    if not self.initialized then
        --print(pwidth,pheight,width_fixed,height_fixed)
        self:update(pwidth,pheight,width_fixed,height_fixed)
        self.initialized = true
    end
    return self.width,self.height
end

function Plot:view (me)
    local MeasureSpec = V.View_MeasureSpec
    self.me = me
    --me.plot = self
    local tbl =  {
        onDraw = function(c) self:draw(c) end,
        onSizeChanged = function(w,h) self:resized(w,h) end,
        onMeasure = function(wspec,hspec)
            local pwidth = MeasureSpec:getSize(wspec)
            local pheight = MeasureSpec:getSize(hspec)
            local width_fixed = MeasureSpec:getMode(wspec) --== MeasureSpec.EXACTLY
            local height_fixed = MeasureSpec:getMode(hspec) --== MeasureSpec.EXACTLY
            local p,w = self:measure(pwidth,pheight,width_fixed,height_fixed)
            self.View:measuredDimension(p,w)
            return true
        end
    }
    if self.interactive then
        tbl.onTouchEvent = require 'android.plot.interactive'(self)
    end
    self.View = me:luaView(tbl)
    return self.View
end

function Plot:corner (cnr,width,height,M)
    local WX,HY = self.boxwidth,self.boxheight
    M = M or self.outer_margin
    local H,V = cnr:match '(.)(.)'
    local x,y
    if H == 'L' then
        x = M.left
    elseif H == 'R' then
        x = WX - (width + M.right)
    elseif H == 'C' then
        x = (WX - width)/2
    end
    if V == 'T' then
        y = M.top
    elseif V == 'B' then
        y = HY - (height + M.bottom)
    elseif V == 'C' then
        y = (HY - height)/2
    end
    if not x or not y then
        error("bad corner specification",2)
    end
    return x,y
end

function Plot:align (cnr,width,height,M,xp,yp)
    local H,V = cnr:match '(.)(.)'
    local dx,dy
    M = M or self.outer_margin
    if H == 'L' then
        dx = - M.left - width
    elseif H == 'R' then
        dx = M.right
    end
    if V == 'T' then
        dy = - M.top - height
    elseif V == 'B' then
        dy = M.bottom
    end
    if not dx or not dy then
        error("bad align specification",2)
    end
    return xp+dx,yp+dy
end

-- Axis class ------------

function Axis.new (plot,self)
    make_object(self,Axis)
    self.plot = plot
    if self.invisible then
        self.thick = 0
        return self
    end
    self.grid = self.grid or plot.grid

    if self.min and self.max then
        self.fixed_bounds = true
    end

    self.label_size = android.me:parse_size(self.label_size or '12sp')
    self.label_paint = text_paint(self.label_size,plot.color)

    if self.grid then
        self.grid = stroke_paint(set_alpha(plot.color,30),1)
    end

    self.explicit_ticks = type(self.ticks)=='table' and #self.ticks > 0

    return self
end

function Axis:has_bounds ()
    return self.min and self.max or self.explicit_ticks
end

function Axis:set_bounds (min,max,init)
    if init then
        self.old_min, self.old_max = min, max
        self.initial_ticks = true
    elseif not max then
        min, max = self.old_min, self.old_max
    end
    self.unchanged = false
    self.min = min
    self.max = max
end

function Axis:zoomed ()
    return self.min > self.old_min or self.max < self.old_max
end

local DAMN_SMALL = 10e-16

local function eq (x,y)
    return math.abs(x-y) < DAMN_SMALL
end

function Axis:init()
    if self.invisible or self.unchanged then return end
    self.unchanged = true
    local plot = self.plot

    if not self.explicit_ticks then
        local W = plot.width
        if not self.horz then W = plot.aspect_ratio*W end
        if self.type == 'date' then
            self.ticks = require 'android.plot.time_intervals' (self,W)
        else
            self.ticks = require 'android.plot.intervals' (self,W)
        end
    end
    local ticks = self.ticks

    -- how to convert values to strings for labels;
    -- format can be a string (for `string.format`) or a function
    local format = ticks.format
    if type(format) == 'string' then
        local fmt = format
        format = function(v) return fmt:format(v) end
    elseif not format then
        format = tostring
    end

    local wlabel = ''
    -- We have an array of ticks. Ensure that it is an array of {value,label} pairs
    for i = 1,#ticks do
        local tick = ticks[i]
        local label
        if type(tick) == 'number' then
            label = format(tick)
            ticks[i] = {tick,label}
        else
            label = tick[2]
        end
        if #label > #wlabel then
            wlabel = label
        end
    end

    -- adjust our bounds to match ticks, and give some vertical space for series
    local start_tick, end_tick = ticks[1][1], ticks[#ticks][1]

    self.min = self.min or start_tick
    self.max = self.max or end_tick

    if not self.horz then
        local D = (self.max - self.min)/20
        if not eq(self.max,0) and eq(self.max,end_tick) then
            self.max = self.max + D
        end
        if not eq(self.min,0) and eq(self.min,start_tick) then
            self.min = self.min - D
        end
    end

    if self.initial_ticks then
        if self.min > start_tick then
            self.min = start_tick
        end
        if self.max < end_tick then
            self.max = end_tick
        end
        self.initial_ticks = false
    end

    -- finding our 'thickness', which is the extent in the perp. direction
    -- (we'll use this to adjust our plotting area size and position)
    self.label_width = self:get_label_extent(wlabel)
    if not self.horz then
        -- cool, have to find width of y-Axis label on the left...
        self.thick = math.floor(1.1*self.label_width)
    else
        self.thick = self.label_size
    end
    self.tick_width = self.label_size
end

function Axis:get_label_extent(wlabel,paint)
    local rect = G.Rect()
    paint = paint or self.label_paint
    -- work with a real Java string to get the actual length of a UTF-8 string!
    local str = L.String(wlabel)
    paint:getTextBounds(wlabel,0,str:length(),rect)
    return rect:width(),rect:height()
end

function Axis:setup_scale ()
    local horz,plot = self.horz,self.plot
    local W = horz and plot.boxwidth or plot.boxheight
    local delta = self.max - self.min
    local m,c
    if horz then
        m = W/delta
        c = -self.min*W/delta
    else
        m = -W/delta
        c = self.max*W/delta
    end

    self.scale = function(v)
        return m*v + c
    end

    local minv = 1/m
    local cinv = - c/m
    local M = self.horz and plot.margin.left or plot.margin.top

    self.unscale = function(p)
        return minv*(p-M) + cinv
    end
    self.pix2plot = self.horz and minv or -minv
end

function Axis:draw (c)
    if self.invisible then return end -- i.e, we don't want to draw ticks or gridlines etc

    local tpaint,apaint,size,scale = self.label_paint,self.plot.axis_paint,self.label_size,self.scale
    local boxheight = self.plot.boxheight
    local margin = self.plot.margin
    local twidth = self.tick_width
    local lw = self.label_width
    if self.horz then
        c:save()
        c:translate(margin.left,margin.top + boxheight)
        for _,tick in ipairs(self.ticks) do
            local x = tick[1]
            if x > self.min and x < self.max then
                x = scale(x)
                --c:drawLine(x,0,x,twidth,apaint)
                if tpaint then
                    lw = self:get_label_extent(tick[2],tpaint)
                    c:drawText(tick[2],x-lw/2,size,tpaint)
                end
                if self.grid then
                    c:drawLine(x,0,x,-boxheight,self.grid)
                end
            end
        end
        c:restore()
    else
        c:save()
        local boxwidth = self.plot.boxwidth
        c:translate(margin.left,margin.top)
        for _,tick in ipairs(self.ticks) do
            local y = tick[1]
            if y > self.min and y < self.max then
                y = scale(y)
                --c:drawLine(-twidth,y,0,y,apaint)
                if tpaint then
                    c:drawText(tick[2],-lw,y,tpaint) -- y + sz !
                end
                if self.grid then
                    c:drawLine(0,y,boxwidth,y,self.grid)
                end
            end
        end
        c:restore()
    end
end

Plot.Axis = Axis

------- Series class --------

local function unzip (data)
    data = array(data)
    local xdata = data:map '_[1]'
    local ydata = data:map '_[2]'
    return xdata,ydata
end

function Series.new (plot,t)
    local self = make_object(t,Series)
    self:set_styles(plot,t)
    if not self:set_data(t,false) then
       error("must provide both xdata and ydata for series",2)
    end
    self.init = true
    return self
end

function Series:set_styles (plot,t)
    self.plot = plot
    self.xaxis = plot.xaxis
    self.yaxis = plot.yaxis
    self.path = G.Path()
    local clr = t.color or plot:next_colour()
    if not t.points and not t.lines then
        t.lines = true
    end
    if t.lines and t.color ~= 'none' then
        self.linestyle = stroke_paint(clr,t.width)
        if type(t.lines) == 'string' and t.lines ~= 'steps' then
            local w = plot.sample_width
            local pat
            if t.lines == 'dash' then
                pat = {w/4,w/4}
            elseif t.lines == 'dot' then
                pat = {w/8,w/8}
            elseif t.lines == 'dashdot' then
                pat = {w/4,w/8,w/8,w/8}
            end
            pat = G.DashPathEffect(L.Float(pat),#pat/2)
            self.linestyle:setPathEffect(pat)
        end
        if t.shadow then
            local c = set_alpha(clr,50)
            self.shadowstyle = stroke_paint(c,t.width)
        end
    end
    if t.fill then
        local cfill = t.fill
        if t.fill == true then
            cfill = set_alpha(clr,30)
        end
        t.fillstyle = fill_paint(cfill)
    elseif t.points then
        self.pointstyle = stroke_paint(clr,t.pointwidth or 10) -- Magic Number!
        local cap = t.points == 'circle' and G.Paint_Cap.ROUND or G.Paint_Cap.SQUARE
        self.pointstyle:setStrokeCap(cap)
    end
    self.color = PC(clr)
end

function Series:set_data (t,do_update)
    do_update = do_update==nil or do_update
    local set,xunits = true,self.xunits
    local xx, yy
    if t.data then -- Flot-style data
        xx, yy = unzip(t.data)
    elseif not t.xdata and not t.ydata then
       set = false
    else
        xx, yy = array(t.xdata),array(t.ydata)
    end
    if self.lines == 'steps' then
        local xs,ys,k = array(),array(),1
        if #xx == #yy then
            local n = #xx
            xx[n+1] = xx[n] + (xx[n]-xx[n-1])
        end
        for i = 1,#yy do
            xs[k] = xx[i]; ys[k] = yy[i]
            xs[k+1] = xx[i+1]; ys[k+1] = yy[i]
            k = k + 2
        end
        xx, yy = xs, ys
    end
    if self.points then
        self.xpoints, self.ypoints = xx, yy
    elseif self.fill then
        local xf, yf = array(xx),array(yy)
        local min = yf:minmax()
        xf:append(xf[#xf])
        yf:append(min)
        xf:append(xf[1])
        yf:append(min)
        self.xfill, self.yfill = xf, yf
    end
    if xunits then
        local fact
        if xunits == 'msec' then
            fact = 1/1000.0
        end
        xx = xx:map('*',fact)
    end
    local scale_to = self.scale_to_y or self.scale_to_x
    if scale_to then
        local other = self.plot:get_series(scale_to)
        local bounds = other:bounds()
        if self.scale_to_y then
            yy:scale_to(bounds.bottom,bounds.top)
        else
            yy:scale_to(bounds.left,bounds.right)
        end
    end
    self.xdata, self.ydata = xx, yy
    if do_update then
        self.cached_bounds = nil
        self.plot:update_and_paint()
    end
    return set
end

function Series:update ()

end

function Series:bounds ()
    if self.cached_bounds then
        return self.cached_bounds
    end
    if not self.xdata then error('xdata was nil!') end
    local xmin,xmax = array.minmax(self.xdata)
    if not self.ydata then error('ydata was nil!') end
    local ymin,ymax = array.minmax(self.ydata)
    self.cached_bounds = {left=xmin,top=ymax,right=xmax,bottom=ymin}
    return self.cached_bounds
end

local function draw_poly (self,c,xdata,ydata,pathstyle)
    local scalex,scaley,path = self.xaxis.scale, self.yaxis.scale, self.path
    path:reset()
    path:moveTo(scalex(xdata[1]),scaley(ydata[1]))
    -- cache the lineTo method!
    local lineTo = luajava.method(path,'lineTo',0.0,0.0)
    for i = 2,#xdata do
        lineTo(path,scalex(xdata[i]),scaley(ydata[i]))
    end
    c:drawPath(path,pathstyle)
end

function Series:draw(c)
    if self.linestyle then
        draw_poly (self,c,self.xdata,self.ydata,self.linestyle)
    end
    if self.fillstyle then
        --print('filling',self.tag)
        draw_poly (self,c,self.xfill,self.yfill,self.fillstyle)
    end
    if self.pointstyle then
        local scalex,scaley = self.xaxis.scale, self.yaxis.scale
        local xdata,ydata = self.xpoints,self.ypoints
        for i = 1,#xdata do
            c:drawPoint(scalex(xdata[i]),scaley(ydata[i]),self.pointstyle)
        end
    end
end

function Series:draw_sample(c,x,y,sw)
    if self.linestyle then
        c:drawLine(x,y,x+sw,y,self.linestyle)
    else
        c:drawPoint(x,y,self.pointstyle)
    end
    return self.label
end

function Series:get_x_intersection (x)
    local idx = self.xdata:find_linear(x)
    if not idx then return nil,"no intersection with this series possible" end
    local y = self.ydata:at(idx)
    return y,idx
end

function Series:get_data_range (idx1,idx2)
    local xx = self.xdata:sub(idx1,idx2)
    local yy = self.ydata:sub(idx1,idx2)
    return xx:map2('{_1,_2}',yy)
end

function Anot.new(plot,t)
    t.width = 1
    if t.points then t.pointwidth = 7  end  --Q: what is optimal default here?

    t.series = t.series and plot:get_series(t.series)

    -- can override default colour, which is 60% opaque series colour
    local c = t.series and t.series.color or plot.theme.color
    t.color = t.color or set_alpha(c,60)

    if t.bounds then
--~         t.x1,t.y1,t.x2,t.y2 = t[1],t[2],t[3],t[4]
    end

    -- simularly default fill colour is 40% series colour
    -- we're filling if asked explicitly with a fill colour, or if x1
    -- or y1 is defined
    if t.fill or t.x1 ~= nil or t.y1 ~= nil then --) and not (t.x or t.y) then
        t.fillstyle = fill_paint(t.fill or set_alpha(c,30))
    else
        t.lines = true
    end

    -- lean on our 'friend' Series to set up the paints and so forth!
    local self = make_object(t,Anot)
    Series.set_styles(self,plot,t)

    self.is_anot = true
    return self
end

local function lclamp (x,xmin) return math.max(x or xmin, xmin) end
local function rclamp (x,xmax) return math.min(x or xmax, xmax) end
local function clamp (x1,x2,xmin,xmax) return lclamp(x1,xmin),rclamp(x2,xmax) end

function Anot:update()
    local lines = array()
    local A = array
    local top
    local xmin,xmax,ymin,ymax = self.xaxis.min,self.xaxis.max,self.yaxis.min,self.yaxis.max
    local series = self.series
    self.points = {}

    local function append (name,xp,yp)
        local pt = {xp,yp}
        lines:append (pt)
        self.points[name] = pt
    end

    --print('y',self.y,self.y1,self.fillstyle,self.linestyle)
    if self.fillstyle then
        self.horz = x1 == nil
        if not series then -- a filled box {x1,y1,x2,y2}
            local x1,x2 = clamp(self.x1,self.x2,xmin,xmax)
            local y1,y2 = clamp(self.y1,self.y2,ymin,ymax)
            append('start',x1,y1)
            lines:extend {{x2,y1},{x2,y2}}
            append('last',x1,y2)
            lines:append{x1,y1} -- close the poly
        else
            -- must clamp x1,x2 to series bounds!
            local bounds = series:bounds()
            local x1,x2 = clamp(self.x1,self.x2,bounds.left,bounds.right)
            local top1,i1 = series:get_x_intersection(x1)
            local top2,i2 = series:get_x_intersection(x2)
            -- closed polygon including chunk of series that we can fill!
            append('start',x1,ymin)
            lines:extend (series:get_data_range(i1,i2))
            append('last',x2,ymin)
        end
    else -- line annotation
        local x,y = self.x,self.y
        self.horz = x == nil
        append('start',x or xmin,y or ymin)
        if not series then -- just a vertical or horizontal line
            append('last',x or xmax,y or ymax)
        else -- try to intersect (only x intersection for now)
            top = series:get_x_intersection(x)
            if top then
                append('intersect',x,top)
                append('last',xmin,top)
            else
                append('last',x,ymax)
            end
        end
    end

    Series.set_data(self,{ data = lines },false)

   -- maybe add a point to the intersection?
    if top then
        self.xpoints = array{self.x}
        self.ypoints = array{top}
    end
    if self.fillstyle then
        self.linestyle = nil
        self.xfill, self.yfill = self.xdata, self.ydata
        --print(self.xfill)
        --print(self.yfill)
    end
end

function Anot:draw(c)
    Series.draw(self,c)
end

function Anot:get_point (which)
    local pt = self.points[which]
    if not pt then return nil, 'no such point' end
    return pt[1],pt[2]
end

local function set_box (self,plot)
    -- inner padding
    local P = self.padding or plot.pad/2
    self.padding = {P,P,P,P} --inner
    self.plot = plot

    -- text style
    local paint
    if self.size then
        self.color = self.color or plot.color
        paint = text_paint(android.me:parse_size(self.size),self.color)
    else
        paint = plot.xaxis.label_paint
    end
    self.label_paint = paint

    -- box stuff
    self.stroke = plot.axis_paint
    self.background = fill_paint(self.fill or plot.theme.background)
end

local function text_extent (self,text)
    return self.plot.xaxis:get_label_extent(text or self.text,self.label_paint)
end

function TextAnot.new(plot,t)
    t.anot = t.anot and plot:get_annotation(t.anot)
    set_box(t,plot)
    return make_object(t,TextAnot)
end

function Plot.scale (plot,x,y)
    return plot.xaxis.scale(x),plot.yaxis.scale(y)
end

local function default_align (anot,point)
    if anot:get_point 'intersect' then
        if point ~= 'intersect' then -- points on axes
            local X,Y = 'LT','RT'
            -- order of 'first' and 'last' is reversed for horizontal lines
            if anot.horz then Y,X = X,Y end
            return point=='start' and X or Y
        else
            return 'LT'
        end
    else -- straight horizontal or vertical line
        --print('horz',anot.horz,point)
        if anot.horz then
            return point=='start' and 'RT' or 'LT'
        else
            return point=='start' and 'LT' or 'LB'
        end
    end

end

function TextAnot:update ()
    local xs,ys
    local plot = self.plot
    local w,h = text_extent(self)
    if not self.anot then -- we align to the edges of the plotbox
        self.cnr = self.corner or 'CT'
        xs,ys = plot:corner(self.cnr,w,h,empy_margin)
    else -- align to the points of the annotation
        self.cnr = self.corner or default_align(self.anot,self.point)
        px,py = self.anot:get_point(self.point)
        px,py = plot:scale(px,py)
        xs,ys = plot:align(self.cnr,w,h,empty_margin,px,py)
        --print('point',xs,ys)
    end
    self.xp = xs
    self.yp = ys + h
end

local empty_margin = {left=0,top=0,right=0,bottom=0}

function TextAnot:draw (c)
    --print('draw',self.xp,self.yp)
    c:drawText(self.text,self.xp,self.yp,self.label_paint)
end

-- Legend class ----------
function Legend.new (plot,t)
    if type(t) == 'string' then
        t = {corner = t}
    elseif t == nil then
        t = {}
    end
    t.cnr = t.corner or 'RT'
    t.sample_width = t.sample_width or plot.sample_width
    set_box(t,plot)
    return make_object(t or {},Legend)
end

function Legend:draw (c)
    local plot = self.plot
    local P = self.padding

    local series,wlabel = plot:fetch_labelled_series()

    if #series == 0 then return end -- no series to show!

    -- can now calculate our bounds and ask for our position
    local sw = self.sample_width
    local w,h = text_extent(self,wlabel)
    local W,H
    local dx,dy,n = P[1],P[2],#series
    if not self.across then
        W = P[1] + sw + dx + w + dx
        H = P[2] + n*(dy+h) - h/2
    else
        W = P[1] + n*(sw+w+2*dx)
        H = P[2] + h + dy
    end
    local margin
    local draw_box = self.box == nil or self.box == true
    if not draw_box then margin = empty_margin end
    local xs,ys = plot:corner(self.cnr,W,H,margin)

    -- draw the box
    if draw_box then
        local bounds = G.Rect(xs,ys,xs+W,ys+H)
        if self.background then
            c:drawRect(bounds,self.background)
        end
        c:drawRect(bounds,self.stroke)
    end
    self.width = W
    self.height = H

    -- draw the entries (ask series to give us a 'sample')
    local y = ys + P[2] + h/2
    local offs = h/2
    local x = xs + P[1]
    local yspacing = P[2]/2
    if self.across then y = y + h/2 end
    for _,s in ipairs(series) do
        local label = s:draw_sample(c,x,y-offs,sw)
        x = x+sw+P[1]
        c:drawText(label,x,y,self.label_paint)
        if not self.across then
            y = y + h + yspacing
            x = xs + P[1]
        else
            x = x + w/2 + 2*P[1]
        end
    end

end

-- we export this for now
_G.Plot = Plot
return Plot
