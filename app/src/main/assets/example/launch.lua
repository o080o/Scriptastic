-- Androlua examples
local launch = require 'android'.new()

local groups = {
    {group='GUI','list','expanded','pretty'},
    {group='Graphics','draw','plot','financial'},
    {group='Forms','form','password','.questions'},
}

local text = [[
Androlua examples, by category.
All of these activities have an option menu for viewing their source.
]]

function launch.create(me)
    local groupStyle = me:textStyle{paddingLeft='35sp',size='30sp'}
    local childStyle = me:textStyle{paddingLeft='50sp',size='20sp'}
    local elv,adapter
    elv,adapter = me:luaExpandableListView (groups,{

        getGroupView = function (group,groupPos,expanded,view,parent)
            return me:hbox {groupStyle(group)}
        end;

        getChildView = function  (child,groupPos,childPos,lastChild,view,parent)
            return childStyle(child)
        end;

        onChildClick = function(child)
            if child:match '^%.' then
                child = child:sub(2)
            else
                child = 'example.'..child
            end
            me:luaActivity(child)
            return true
        end;

    })

    me:options_menu {
        "source",function()
            me:luaActivity('example.pretty','example.launch')
        end,
    }

    return me:vbox{
        me:textView{text,size='20sp',textColor='#EEEEFF'},
        elv
    }
end

return launch

