--- AndroLua Touch handling.
-- This module returns a function which generates a suitable `OnTouchEvent`
-- handler. When creating a custom view using @{android.luaView} you can say:
--
--    T = {
--      draw = ...;
--      onTouchEvent = require 'android.touch'(T)
--      touch = function(kind,idx,x,y,dir,movement) ... end
--    }
--    me:luaView(T)
--
-- and then `T.touch` will be called appropriately.  `kind` can one of 'TAP','DOUBLE-TAP',
-- 'PRESSED' (i.e. long-press) 'SWIPE' and 'PINCH'.  For all kinds of events, `idx` is the
-- number of pointers involved (e.g. `idx==2` means that two fingers are involved in a
-- guesture) and `x`,'y` are the view coordinates of the center of the guesture.
-- For 'SWIPE' and 'PINCH', `dir` can be 'X' or 'Y', and then `movement` is non zero.
--
-- @module android.touch
local append,out = table.insert,{}
local max,abs,sqrt = math.max,math.abs,math.sqrt

local function len (x,y)
    return sqrt(x^2 + y^2)
end

local function dist (x1,y1,x2,y2)
    return len(x1 - x2,y1 - y2)
end

local function sign (x)
    return x >= 0 and 1 or -1
end

local MotionEvent = bind 'android.view.MotionEvent'
local actions = {
    'ACTION_DOWN','ACTION_POINTER_DOWN','ACTION_UP','ACTION_POINTER_UP','ACTION_MOVE'
}

local action_map = {}
for _,aname in ipairs(actions) do
    local a = MotionEvent[aname]
    action_map[a] = aname
end

local long_press, double_tap, swipe_min = 600,300,12
local empty = {UP='ACTION_UP'}
local state = empty

local function reset_state (when)
    state = empty
end

local function newstate (kind,ev,idx)
    idx = idx or (ev:getActionIndex() + 1) -- 1-based pointer indices
    local np = ev:getPointerCount()
    local x,y = {},{}
    for i = 1,np do
        x[i] = ev:getX(i-1)
        y[i] = ev:getY(i-1)
    end
    return {UP='ACTION_UP',kind=kind,idx=idx,time=ev:getEventTime(),x=x,y=y}
end

local function movement (s1,s2,idx)
    return dist(s1.x[idx],s1.y[idx],s2.x[idx],s2.y[idx])
end

return function(obj)
return function (ev)
    local action = ev:getActionMasked()
    local aname = action_map[action]
    if aname then
        local nstate
        if aname == 'ACTION_DOWN' or aname == 'ACTION_POINTER_DOWN' then
            nstate = newstate(aname,ev)
            if state.kind == state.UP and nstate.time-state.time < double_tap then
                local idx = state.idx
                local x,y = state.x[idx],state.y[idx]
                obj.touch('DOUBLE-TAP',idx,x,y,'NONE')
                reset_state 'db'
            else
                state = nstate
                state.UP = aname == 'ACTION_POINTER_DOWN' and 'ACTION_POINTER_UP' or 'ACTION_UP'
            end
            if obj.down then obj.down(nstate.x[1],nstate.y[1]) end
        elseif aname == state.UP and state ~= empty then
            local idx = state.idx
            local x,y = state.x[idx],state.y[idx]
            nstate = newstate(aname,ev,idx)
            if obj.up then obj.up(x,y) end
            if movement(nstate,state,1) > swipe_min then -- finger(s) dragged..
                local sx,sy,nx,ny = state.x,state.y,nstate.x,nstate.y
                --local dd = deltas(nstate,state)
                -- how much the finger moved, and its direction
                local dx1,dy1 = sx[1]-nx[1],sy[1]-ny[1]
                local sgn,axis=1
                if abs(dx1) > abs(dy1) then
                    axis = 'X'
                    if dx1 < 0 then sgn = -1 end -- -ve means right..
                else
                    axis = 'Y'
                    if dy1 < 0 then sgn = -1 end -- -ve means up..
                end
                if idx > 1 then -- two fingers!
                    local dx2,dy2  = sx[2]-nx[2], sy[2]-ny[2] --dd.deltax[2], dd.deltay[2]
                    local d1,d2 = len(dx1,dy1),len(dx2,dy2)
                    local z = max(d1,d2)
                    if sign(dx1)==sign(dx2) and sign(dy1)==sign(dy2) then
                        obj.touch('SWIPE',idx,x,y,axis,sgn*z)
                    else
                        local is_x = abs(dx1) > abs(dy1)
                        local startd = dist(sx[1],sy[1],sx[2],sy[2])
                        local endd = dist(nx[1],ny[1],nx[2],ny[2])
                        if startd > endd then
                            z = -z  -- -ve means moving in...
                            x,y = (nx[1]+nx[2])/2, (ny[1]+ny[2])/2
                        else
                            x,y = (sx[1]+sx[2])/2, (sy[1]+sy[2])/2
                        end
                        obj.touch('PINCH',idx,x,y,(is_x and 'X' or 'Y'),2*z)
                    end
                else
                    obj.touch('SWIPE',idx,x,y,axis,sgn*len(dx1,dy1))
                end
                reset_state 'swipe'
            elseif nstate.time - state.time < long_press then
                obj.touch('TAP',idx,x,y,'NONE')
                -- currently we don't do double-tap with two fingers
                state = idx == 1 and nstate or empty
            else
                obj.touch('PRESSED',idx,x,y,'NONE')
                reset_state 'pressed'
            end
        elseif aname == 'ACTION_MOVE' and obj.move then
            obj.move(ev:getX(),ev:getY())
        end

    end
    return true
end
end
