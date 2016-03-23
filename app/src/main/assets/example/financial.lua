-- AndroLua plot version of this Flot example:
-- http://people.iola.dk/olau/flot/examples/multiple-axes.html
-- (Except we don't have multiple axes - yet)

local financial = require 'android'.new()
local Plot = require 'android.plot'
local plotdata = require 'example.plotdata'

function financial.create (me)

    local plot = Plot.new {
        interactive=true,
        grid=true,
        legend = { corner='CB'},
        xaxis = { type='date'},
        -- series are in the array part
        {
            label='oil price US$',tag='oil',
            data = plotdata.oilprices,
            xunits='msec',
            width=2,
        },
        {   label='USD EUR Exchange Rate',
            data = plotdata.exchangerates,
            xunits='msec',
            width=2,
            scale_to_y = 'oil',
        },
        annotations = {
            {
                y = 100,color='red',tag='line'
            },
            {
                text='Inverse Correlation: Oil Price USD/EUR',
                size='20sp'
            },
        }
    }
    -- can access series data and use array methods
    local oil = plot:get_series 'oil'
    local idx = oil.ydata:find_linear(100)
    -- time is already in Unix-style!
    local t = oil.xdata:at(idx)

    -- this text annotation is positioned at the start point of
    -- the annotation with tag 'line'
    plot:add_annotation {
        text="$100 limit reached at "..os.date('%Y-%m-%d',t),
        anot='line',point='start',
    }

    me:options_menu {
        "source",function()
            me:luaActivity('example.pretty','example.financial')
        end,
    }

    return plot:view(me)
end

return financial

