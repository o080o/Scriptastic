-- a simple Expandable List View in Lua
-- You have to at least provide `getGroupView` and `getChildView`;
-- the first must provide some padding to avoid the icon. Note that these
-- functions are passed an extra first value which is the group or view object.
expanded = require 'android'.new()

-- the data is a list of entries, which are lists of children plus a corresponding
-- 'group' field
-- In this case, we fill in the children just before the group is expanded,
-- i.e. it's a lazy list.
groups = {
    {group='os'},
    {group='coroutine'},
    {group='io'},
}

function expanded.create(me)
    local groupStyle = me:textStyle{paddingLeft='35sp',size='30sp'}
    local childStyle = me:textStyle{paddingLeft='50sp',size='20sp'}
    local elv,adapter
    elv,adapter = me:luaExpandableListView (groups,{

        onGroupExpanded = function (groupPos)
            -- this is the group data
            local group = groups[groupPos+1].group
            -- and the group's children should be here
            local children = groups[groupPos+1]
            if #children == 0 then
                for key in pairs(_G[group]) do
                    table.insert(children,key)
                end
                adapter:notifyDataSetChanged()
            end
        end;


        getGroupView = function (group,groupPos,expanded,view,parent)
            return me:hbox {groupStyle(group)}
        end;

        getChildView = function  (child,groupPos,childPos,lastChild,view,parent)
            return childStyle(child)
        end;

        -- may optionally override this as well - remember to return a boolean!
        onChildClick = function(child)
            me:toast('child: '..child)
            return true
        end;

    })

    me:options_menu {
        "source",function()
            me:luaActivity('example.pretty','example.expanded')
        end,
    }

    return elv
end

return expanded

