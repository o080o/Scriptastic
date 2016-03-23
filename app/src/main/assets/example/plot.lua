-- demonstrates Androlua plotting library
local draw = require 'android'.new()
local Plot = require 'android.plot'

function draw.create (me)
    me.a:setTitle 'Androlua Plot Example'
    ME = me
    local pi = math.pi
    local xx,sin,cos = {},{},{}
    local i = 1
    for x = 0, 2*pi, 0.1 do
        xx[i] = x
        sin[i] = math.sin(x)
        cos[i] = math.cos(x)
        i = i + 1
    end

    local samples = Plot.array{0.1, 0.8*pi,1.2*pi,2*pi-0.3}

    local plot = Plot.new {
        grid = true,
        fill = '#EFEFFF', -- fill the plot area with light blue
        aspect_ratio = 0.5,  -- plot area is twice as wide as its height
        -- legend is in left-bottom corner, arranged horizontally, filled with yellow
        legend = {
            corner='LB',across=true,fill='#FFFFEF',
        },
        xaxis = { -- we have our own ticks with labels - UTF-8 is fine...
            ticks = {{0,'0'},{pi/2,'π/2'},{pi,'π'},{3*pi/2,'3π/2'},{2*pi,'2π'}},
        },
        -- our series follow...
        {   label = 'sin', width=2,
            xdata = xx, ydata = sin,
        },
        {   label = 'cos', width=2,
            xdata = xx, ydata = cos,
        },
        {
            -- doesn't have label, won't be in legend
            width=8,points='circle',
            xdata = samples,
            ydata = samples:map(math.cos)
        }
    }

    local xvalues = Plot.array(0,10,0.1)

    local spi = math.sqrt(2*math.pi)

    local function norm_distrib (x,mu,sigma)
        local sfact = 2*sigma^2
        return math.exp(-(x-mu)^2/sfact)/(spi*sigma)
    end

    local plot2 = Plot.new {
        aspect_ratio = 0.5,
        padding = pad,
        legend = {box=false,corner='LT'},
        {
            label = 'μ = 5, σ = 1',width=2,color='#000000',
            xdata = xvalues,
            ydata = xvalues:map(norm_distrib,5,1),
            tag = '5'
        },
        {
            label = 'μ = 6, σ = 0.7',width=2,color='#AAAAAA',
            xdata = xvalues,
            ydata = xvalues:map(norm_distrib,6,0.7),
            tag = '6'
        },
        annotations = {
            {x = 4, series='5', points=true},
            {x1 = 5.5, x2 = 6.5, color='#10000000',series=2},
        }
    }

    me:options_menu {
        "source",function()
            me:luaActivity('example.pretty','example.plot!')
        end,
    }

    me.theme = {textColor='BLACK',background='WHITE'}
    local caption = me:textStyle{size='15sp',gravity='center'}

    return me:vbox{
        caption 'Plot Examples',
        plot:view(me),
        plot2:view(me)
    }
end

return draw
