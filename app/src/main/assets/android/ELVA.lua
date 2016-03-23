-- ELVA.lua
-- Expandable List View Adapter using a Lua table.
require 'android.import'

return function(groups,overrides)
    local ELA = {}
    local my_observable = bind 'android.database.DataSetObservable'()

    function ELA.areAllItemsEnabled ()
        return true
    end

    function ELA.getGroup (groupPos)
        return groups[groupPos+1].group
    end

    function ELA.getGroupCount ()
        return #groups
    end

    function ELA.getChild (groupPos,childPos)
        return groups[groupPos+1][childPos+1]
    end

    function ELA.getChildrenCount (groupPos)
        return #groups[groupPos+1]
    end

    function ELA.getChildId (groupPos,childPos)
        return childPos+1
    end

    function ELA.getCombinedChildId (groupPos,childPos)
        return 1000*groupPos + childPos
    end

    function ELA.getCombinedGroupId (groupPos)
        return groupPos+1
    end

    function ELA.getGroupId (groupPos)
        return groupPos+1
    end

    function ELA.hasStableIds ()
        return false
    end

    function ELA.isChildSelectable (groupPos,childPos)
        return true
    end

    function ELA.isEmpty ()
        return ELA.getGroupCount() == 0
    end

    function ELA.onGroupCollapsed (groupPos)
        --print('collapse',groupPos)
    end

    function ELA.onGroupExpanded (groupPos)
        --print('expand',groupPos)
    end

    function ELA.registerDataSetObserver (observer)
        my_observable:registerObserver(observer)
    end

    function ELA.unregisterDataSetObserver (observer)
        my_observable:unregisterObserver(observer)
    end

    function ELA.notifyDataSetChanged()
        my_observable:notifyChanged()
    end

    function ELA.notifyDataSetInvalidated()
        my_observable:notifyInvalidated()
    end

    local getGroupView, getChildView = overrides.getGroupView, overrides.getChildView
    if not getGroupView or not getChildView then
        error('must override getGroupView and getChildView')
    else
        overrides.getGroupView = nil
        overrides.getChildView = nil
        getGroupView = android.safe(getGroupView)
        getChildView = android.safe(getChildView)
    end

    function ELA.getGroupView (groupPos,expanded,view,parent)
        return getGroupView(ELA.getGroup(groupPos),groupPos,expanded,view,parent)
    end

    function ELA.getChildView (groupPos,childPos,lastChild,view,parent)
        return getChildView (ELA.getChild(groupPos,childPos),groupPos,childPos,lastChild,view,parent)
    end

    -- allow for overriding any of the others...
    for k,v in pairs(overrides) do
        ELA[k] = v
    end

    return proxy('android.widget.ExpandableListAdapter,sk.kottman.androlua.NotifyInterface',ELA)

end
