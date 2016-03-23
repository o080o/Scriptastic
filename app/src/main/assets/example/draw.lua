draw = require 'android'.new()
local G = luajava.package 'android.graphics'
local L = luajava.package 'java.lang'

local paint = G.Paint()
local RED = G.Color.RED
local WHITE = G.Color.WHITE
local BLUE = G.Color.BLUE
-- note how nested classes are accessed...
local FILL = G.Paint_Style.FILL
local STROKE = G.Paint_Style.STROKE

-- http://bestsiteinthemultiverse.com/2008/11/android-graphics-example/

function draw.onDraw(c)
    paint:setStyle(FILL)
    paint:setColor(WHITE)
    c:drawPaint(paint)
    paint:setColor(BLUE)
    c:drawCircle(20,20,15,paint)
    paint:setAntiAlias(true)
    c:drawCircle(60,20,15,paint)

    paint:setAntiAlias(false)
    paint:setColor(RED)
    c:drawRect(100,5,200,30,paint)

    paint:setStyle(STROKE)
    paint:setStrokeWidth(2)
    paint:setColor(RED)
    local path = G.Path()
    path:moveTo(0,-10)
    path:lineTo(5,0)
    path:lineTo(-5,0)
    path:close()

    -- can now repeatedly draw triangles
    path:offset(10,40)
    c:drawPath(path,paint)
    path:offset(50,100)
    c:drawPath(path,paint)
    -- offsets are cumulative
    path:offset(50,100)
    c:drawPath(path,paint)

    paint:setStyle(STROKE)
    paint:setStrokeWidth(1)
    paint:setColor(G.Color.MAGENTA)
    paint:setTextSize(30)
    c:drawText("Style.STROKE",75,75,paint)

    paint:setStyle(FILL)
    paint:setAntiAlias(true)
    c:drawText("Style.FILL",75,110,paint)

    local x,y = 75,185
    paint:setColor(G.Color.GRAY)
    paint:setTextSize(25)
    local str = "Rotated"
    local rect = G.Rect()
    paint:getTextBounds(str,0,#str,rect)
    c:translate(x,y)
    paint:setStyle(STROKE)
    c:drawText(str,0,0,paint)
    c:drawRect(rect,paint)
    c:translate(-x,-y)
    c:save()
    c:rotate(90, x + rect:exactCenterX(),
       y + rect:exactCenterY())
    paint:setStyle(FILL)
    c:drawText(str,x,y,paint)
    c:restore()

    local dash = G.DashPathEffect(L.Float{20,5},1)
    paint:setPathEffect(dash)
    paint:setStrokeWidth(8)
    c:drawLine(0,300,320,300,paint)

end


function draw.create (me)
    local view = me:luaView(draw)
    me:options_menu {
        "source",function()
            me:luaActivity('example.pretty','example.draw')
        end,
    }
    return view
end

return draw
