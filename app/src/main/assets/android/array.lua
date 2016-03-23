--- Array class.
-- Useful array object specialized for numerical values, although most
-- operations work with arbitrary values as well. Functions taking functions
-- may accept _string lambdas_, which have either a placeholder '_' or two
-- placeholders '_1' or '_2'. As a special case, if the expression has no
-- identifier chars, it's assumed to be a binary operator. So '+' is equivalent
-- to '_1+_2'
-- The '+','-','*','/' operators are overloaded, so expressions like `2*x+1` or 'x+y'
-- work as expected. With two array arguments, '*' and '/' mean element-wise operations.
-- @module android.array

local array = {}
array.__index = array

local function _array (a)
    return setmetatable(a,array)
end

--- array constructor.
-- Useful for generating a set of values between `x1` and `x2`.
-- @param x1 initial value in range, or a table of values. (If that table
-- is itself an `array` then this acts like a copy constructor)
-- @param x2 final value in range
-- @param dx interval.
-- @treturn array
function array.new (x1,x2,dx)
    local xvalues = {}
    if x1 ~= nil then
        if type(x1) == 'table' then
            if getmetatable(x1) == array then
                return x1:sub()
            else
                return _array(x1)
            end
        end
        local i = 1
        for x = x1, x2 , dx do
            xvalues[i] = x
            i = i + 1
        end
    end
    return _array(xvalues)
end

local _function_cache = {}

local function _function_arg (f)
    if type(f) == 'string' then
        if _function_cache[f] then return _function_cache[f] end
        if not f:match '[_%a]' then f = '_1'..f..'_2' end
        local args = f:match '_2' and '_1,_2' or '_'
        local chunk,err = loadstring('return function('..args..') return '..f..' end',f)
        if err then error("bad function argument "..err,3) end
        local fn = chunk()
        _function_cache[f] = fn
        return fn
    end
    return f
end

local function _map (src,i1,i2,dest,j,f,...)
    f = _function_arg(f)
    for i = i1,i2 do
        dest[j] = f(src[i],...)
        j = j + 1
    end
    return dest
end

--- map a function over this array.
-- @param f a function, callable or 'string lambda'
-- @param ... any other arguments to the function
-- @treturn array
function array:map (f,...)
    return _array(_map(self,1,#self,{},1,f,...))
end

--- apply the function to each element of this array.
-- @param f function as in `array.map`
function array:apply (f,...)
    _map(self,1,#self,self,1,f,...)
end

--- map a function over two arrays.
-- @param f as with `array.may` but must have at least two arguments.
-- @tparam array other
-- @treturn array
function array:map2 (f,other)
    if #self ~= #other then error("arrays not the same size",2) end
    f = _function_arg(f)
    local res = {}
    for i = 1,#self do
        res[i] = f(self[i],other[i])
    end
    return _array(res)
end

--- find the index corresponding to `value`.
-- If it isn't an exact match, will give an index with a
-- _fractional part_.
-- @param value
-- @treturn number
function array:find_linear (value)
    for i = 1,#self do
        local v = self[i]
        if v >= value then
            if v > value then
                local x1,x2 = self[i-1],self[i]
                return i-1 + (value-x1)/(x2-x1)
            else
                return i -- on the nose!
            end
        end
    end
end

local floor = math.floor

local function fsplit (x)
    local i = floor(x)
    return i, x - i
end

--- get the numerical value at `idx`.
-- As with `array.find_linear` this index may have
-- a fractional part, allowing for linear interpolation.
-- @return number
function array:at (idx)
    local i,delta = fsplit(idx)
    local res = self[i]
    if delta ~= 0 then
        res = delta*(self[i+1]-self[i])
    end
    return res
end

array.append, array.remove = table.insert, table.remove

--- extend this array with values from `other`
-- @tparam array other
function array:extend (other)
    _map(other,1,#other,self,#self+1,'_')
end

--- get a 'slice' of the array.
-- This works like `string.sub`; `i2` may be a negative integer.
-- Like with `array.at` the indices may have fractional parts.
function array:sub (i1,i2)
    i1 = i1 or 1
    i2 = i2 or -1
    if i2 < 0 then i2 = #self + i2 + 1 end  -- -1 is #self, and so forth
    local res,j = {},1
    local int1,int2 = floor(i1),floor(i2)
    if i1 ~= int1 then
        res[j] = self:at(i1)
        j = j + 1
    end
    for i = int1,int2 do
        res[j] = self[i]
        j = j + 1
    end
    if i2 ~= int2 then
        res[j] = self:at(i2)
    end
    return _array(res)
end

--- concatenation
-- @tparam list other
-- @treturn array
function array:__concat (other)
    local res = self:sub(1)
    res:extend(other)
    return res
end

local function mapm(a1,op,a2)
  local M = type(a2)=='table' and array.map2 or array.map
  return M(a1,op,a2)
end

--- elementwise arithmetric operations
function array.__add(a1,a2) return mapm(a1,'_1 + _2',a2) end
function array.__sub(a1,a2) return mapm(a1,'_1 - _2',a2) end
function array.__div(a1,a2) return mapm(a1,'_1 / _2',a2) end
function array.__mul(a1,a2) return mapm(a2,'_1 * _2',a1) end

function array:__tostring ()
    local n,cb = #self,']'
    if n > 15 then
        n = 15
        cb = '...]'
    end
    local strs = _map(self,1,n,{},1,tostring)
    return '['..table.concat(strs,',')..cb
end

--- adds a given method to this array for calling that method over all objects.
function array:forall_method (name)
    self[name] = function (self,...)
        for i = 1,#self do
            local obj = self[i]
            obj[name](obj,...)
        end
    end
end

--- create an iterator over this array's values.
-- @param f optional function for filtering the
-- iterator
-- @return an iterator
function array:iter (f)
    local i = 0
    if not f then
        return function()
            i = i + 1
            return self[i]
        end
    else
        f = _function_arg(f)
        return function()
            local val
            repeat
                i = i + 1
                val = self[i]
            until val == nil or f(val)
            return val
        end
    end
end

--- get the minimum and maximum values of this array.
-- The values must be comparable!
-- @return minimum
-- @return maximum
function array:minmax ()
    local min,max = math.huge,-math.huge
    for i = 1,#self do
        local val = self[i]
        if val > max then max = val end
        if val < min then min = val end
    end
    return min,max
end

--- 'reduce' an array using a function.
-- @param f a function
function array:reduce (f)
    f = _function_arg(f)
    local res = self[1]
    for i = 2,#self do
        res = f(self[i],res)
    end
    return res
end

--- sum all values in an array
function array:sum ()
    return self:reduce '+'
end

--- scale an array so that the sum of its values is one.
-- @return this array
function array:normalize ()
    self:apply('/',self:sum())
    return self
end

--- create a function which scales values between two ranges.
-- @number xmin input min
-- @number xmax input max
-- @number min  output min
-- @number max  output max
-- @treturn func of one argument
function array.scaler (xmin,xmax,min,max)
    local xd = xmax-xmin
    local scl = (max-min)/xd
    return function(x)
        return scl*(x - xmin) + min
    end
end

--- scale this array to the specified range
-- @number min output min
-- @number max output max
-- @return this array
function array:scale_to (min,max)
    local xmin,xmax = self:minmax()
    self:apply(array.scaler(xmin,xmax,min,max))
    return self
end

setmetatable(array,{
    __call = function(_,...) return array.new(...) end
})

return array
