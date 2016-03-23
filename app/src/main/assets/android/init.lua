-----------------
-- AndroLua Activity Framework
-- @module android
require 'android.import'

-- public for now...
android = {}
local android = android

local LS = service -- which is global for now
local LPK = luajava.package
local L = LPK 'java.lang'
local C = LPK 'android.content'
local W = LPK 'android.widget'
local app = LPK 'android.app'
local V = LPK 'android.view'
local A = LPK 'android'
local G = LPK 'android.graphics'

local append = table.insert

--- Utilities
-- @section utils

--- split a string using a delimiter.
-- @string s
-- @string delim
-- @treturn {string}
function android.split (s,delim)
    local res,pat = {},'[^'..delim..']+'
    for p in s:gmatch(pat) do
        append(res,p)
    end
    return res
end
-- mebbe have a module for these useful things (or Microlight?)
local split = android.split

--- copy items from `src` to `dest`.
-- @tab src
-- @tab dest (may be `nil`, in which case create)
-- @bool dont_overwrite if `true` then don't overwrite fields in `dest`
-- that already exist.
function android.copytable (src,dest,dont_overwrite)
    dest = dest or {}
    for k,v in pairs(src) do
        if not dont_overwrite or dest[k]==nil then
            dest[k] = v
        end
    end
    return dest
end

local app_package

local function get_app_package (me)
    if not app_package then
        --local package_name = me.a:toString():match '([^@]+)':gsub ('%.%a+$','') --(only gets the package of the activity, which may *not* be the package for the actual app (where R is actually located)
        local package_name = me.a:getPackageName()
        app_package = LPK(package_name)
    end
    me.app = app_package
    return app_package
end

--- return a Drawable from an name.
-- @param me
-- @string icon_name
-- @treturn G.Drawable
function android.drawable (me,icon_name)
    local a = me.a
    -- icon is [android.]NAME
    local dclass
    local name = icon_name:match '^android%.(.+)'
    if name then
        dclass = A.R_drawable
    else
        dclass = get_app_package(me).R_drawable
        name = icon_name
    end
    local did = dclass[name]
    if not did then error(name..' is not a drawable') end
    return a:getResources():getDrawable(did)
end

--- wrap a callback safely.
-- Error messages will be output using print() or logger, depending.
-- @func callback the function to be called in a protected context.
function android.safe (callback)
    return function(...)
        local ok,res = pcall(callback,...)
        if not ok then
           LS:log(res)
        elseif res ~= nil then
            return res
        end
    end
end

--- parse a colour value.
-- @param c either a number (passed through) or a string like #RRGGBB,
-- #AARRGGBB or colour names like 'red','blue','black','white' etc
function android.parse_color(c)
    if type(c) == 'string' then
        local ok
        ok,c = pcall(function() return G.Color:parseColor(c) end)
        if not ok then
            LS:log("converting colour "..tostring(c).." failed")
            return G.Color.WHITE
        end
    end
    return c
end

local TypedValue = bind 'android.util.TypedValue'

--- parse a size specification.
-- @param me
-- @param size a number is interpreted as pixels, otherwise a string like '20sp'
-- or '30dp'. (See android.util.TypedValue.COMPLEX_UNIT_*)
-- @return size in pixels
function android.parse_size(me,size)
    if type(size) == 'string' then
        local sz,unit = size:match '(%d+)(.+)'
        sz = tonumber(sz)
        if unit == 'dp' then unit = 'dip' end -- common alias
        unit = TypedValue['COMPLEX_UNIT_'..unit:upper()]
        size = TypedValue:applyDimension(unit,sz,me.metrics)
    end
    return size
end

--- suppress initial soft keyboard with edit view.
-- @param me
function android.no_initial_keyboard(me)
    local WM_LP = bind 'android.view.WindowManager_LayoutParams'
    me.a:getWindow():setSoftInputMode(WM_LP.SOFT_INPUT_STATE_HIDDEN)
end

--- make the soft keyboard go bye-bye.
-- @param v an edit view
function android.dismiss_keyboard (v)
    local ime = v:getContext():getSystemService(C.Context.INPUT_METHOD_SERVICE)
    ime:hideSoftInputFromWindow(v:getWindowToken(),0)
end


--- return a lazy table for looking up controls in a layout.
-- @param me
function android.wrap_widgets (me)
    local rclass = get_app_package(me).R_id
    return setmetatable({},{
        __index = function(t,k)
            local c = me.a:findViewById(rclass[k])
            rawset(t,k,c)
            return c
        end
    })
end

--- set the content view of this activity using the layout name.
-- @param me
-- @param name a layout name in current project
function android.set_content_view (me,name)
    me.a:setContentView(get_app_package(me).R_layout[name])
end

--- make a `V.View.OnClickListener`.
-- @param me
-- @func callback a Lua function
function android.on_click_handler (me,callback)
    return (proxy('android.view.View_OnClickListener',{
        onClick = android.safe(callback)
    }))
end

--- attach a click handler.
-- @param me
-- @param b a widget
-- @func callback a Lua function
function android.on_click (me,b,callback)
    b:setOnClickListener(me:on_click_handler(callback))
end

--- make a Vew.OnLongClickListener.
-- @param me
-- @func callback a Lua function
function android.on_long_click_handler (me,callback)
    return (proxy('android.view.View_OnLongClickListener',{
        onClick = android.safe(callback)
    }))
end

--- attach a long click handler.
-- @param me
-- @tparam widget b
-- @func callback a Lua function
function android.on_long_click (me,b,callback)
    b:setOnLongClickListener(me:on_long_click_handler(callback))
end

--- make an AdapterView.OnItemClickListener.
-- @param me
-- @tparam ListView lv
-- @func callback a Lua function
function android.on_item_click (me,lv,callback)
    lv:setOnItemClickListener(proxy('android.widget.AdapterView_OnItemClickListener',{
        onItemClick = android.safe(callback)
    }))
end


local option_callbacks,entry_table = {},{}

local function create_menu (me,is_context,t)

    local mymod = me.mod

    local view,on_create,on_select
    if is_context then
        view = t.view
        if not view then error("must provide view for context menu!") end
        me.a:registerForContextMenu(view)
        on_create, on_select = 'onCreateContextMenu','onContextItemSelected'
    else
        on_create, on_select = 'onCreateOptionsMenu','onOptionsItemSelected'
    end

    local entries = {}
    for i = 1,#t,2 do
        local label,icon = t[i]
        -- label is TITLE[|ICON]
        local title,icon_name = label:match '([^|]+)|(.+)'
        if not icon_name then
            title = label
        else
            if is_context then error 'cannot set an icon in a context menu' end
            icon = me:drawable(icon_name)
        end
        local entry = {title=title,id=#option_callbacks+1,icon = icon}
        append(entries,entry)
        append(option_callbacks,t[i+1])
    end

    entry_table[view and view:getId() or 0] = entries

    -- already patched the activity table!
    if is_context and mymod.onCreateContextMenu then return end

    mymod[on_create] = function (menu,v)
        local entries = entry_table[v and v:getId() or 0]
        local NONE = menu.NONE
        for _,entry in ipairs(entries) do
            local item = menu:add(NONE,entry.id,NONE,entry.title)
            if entry.icon then
                item:setIcon(entry.icon)
            end
        end
        return true
    end

    mymod[on_select] = function (item)
        local id = item:getItemId()
        option_callbacks[id](item,id)
        return true
    end

end

--- Properties
-- @section properties
--- view properties
-- @tfield ViewProperties theme provides default properties, does not override
-- @color background  colour of view's background
-- @int paddingLeft  inner padding
-- @int paddingRight
-- @int paddingBottom
-- @int paddingTop
-- @table android.ViewProperties

--- Text Properties
-- @color textColor colour of text
-- @int size
-- @int maxLines
-- @int minLines
-- @int lines
-- @string textStyle
-- @string typeface
-- @string gravity
-- @string inputType
-- @bool scrollable
-- @drawable drawableLeft
-- @drawable drawableRight
-- @drawable drawableTop
-- @drawable drawableBottom
-- @table android.TextProperties

--- Menus and Alerts
-- @section menus

--- create an options menu.
-- @param me
-- @param t a table containing 2n items; each row is label,callback.
-- The label is either TITLE or TITLE:ICON; if ICON is prefixed by
-- 'android.' then we look up a stock drawable, otherwise in this
-- app package.
function android.options_menu (me,t)
    create_menu(me,false,t)
end

--- create a context menu on a particular view.
-- @param me
-- @param t a table containing 2n items; each row is label,callback.
-- You cannot set icons on these menu items and `t.view` must be
-- defined!
function android.context_menu (me,t)
    create_menu(me,true,t)
end

--- show an alert.
-- @param me
-- @string title caption of dialog 'label[|drawable]' like with menus
-- above, where 'drawable' is '[android.]name'
-- @string kind either 'ok' or 'yesno'
-- @param message text within dialog, or a custom view
-- @func callback optional Lua function to be called
function android.alert(me,title,kind,message,callback)
    local Builder = bind 'android.app.AlertDialog_Builder'
    local db = Builder(me.a)
    local parts = split(title,'|')
    db:setTitle(parts[1])
    if parts[2] then
        db:setIcon(me:drawable(parts[2]))
    end
    if type(message) == 'string' then
        db:setMessage(message)
    else
        db:setView(message)
    end
    callback = callback or function() end -- for now
    local listener = proxy('android.content.DialogInterface_OnClickListener', {
        onClick = android.safe(callback)
    })
    if kind == 'ok' then
        db:setNeutralButton("OK",listener)
    elseif kind == 'yesno' then
        db:setPositiveButton("Yes",listener)
        db:setNegativeButton("No",listener)
    end
    dlg = db:create()
    dlg:setOwnerActivity(me.a)
    dlg:show()
end

--- show a toast
-- @param me
-- @string text to show
-- @bool long `true` if you want a long toast!
function android.toast(me,text,long)
    W.Toast:makeText(me.a,text,long and W.Toast.LENGTH_LONG or W.Toast.LENGTH_SHORT):show()
end

--- Creating Views
-- @section views

function android.give_id (me,w)
    if w:getId() == -1 then
        if not me.next_id then
            me.next_id = 1
        end
        w:setId(me.next_id)
        me.next_id = me.next_id + 1
    end
    return w
end


--- set View properties.
-- @see ViewProperties
-- @param me
-- @tparam V.View v
-- @param args table of properties
function android.setViewArgs (me,v,args)
    if args.id then
        v:setId(args.id)
    end
    -- @doc me.theme is an optional table of view parameters
    -- that provides defaults; does not override existing parameters.
    if me.theme then
        android.copytable(me.theme,args,true)
    end
    if args.background then
        v:setBackgroundColor(android.parse_color(args.background))
    end
    if args.paddingLeft or args.paddingRight or args.paddingBottom or args.paddingTop then
        local L,R,B,T = v:getPaddingLeft(), v:getPaddingRight(), v:getPaddingBottom(), v:getPaddingTop()
        if args.paddingLeft then
            L = me:parse_size(args.paddingLeft)
        end
        if args.paddingTop then
            T = me:parse_size(args.paddingTop)
        end
        if args.paddingRight then
            R = me:parse_size(args.paddingRight)
        end
        if args.paddingBottom then
            B = me:parse_size(args.paddingBottom)
        end
        v:setPadding(L,T,R,B)
    end
    return me:give_id(v)
end

local function parse_input_type (input)
    return require 'android.input_type' (input)
end

local SMM

--- set properties specific to `TextView` and `EditText`.
-- @see TextProperties
-- @param me
-- @tparam W.TextView txt
-- @param args table of properties
function android.setEditArgs (me,txt,args)
    me:setViewArgs(txt,args)
    if args.textColor then
        txt:setTextColor(android.parse_color(args.textColor))
    end
    if args.size then
        txt:setTextSize(me:parse_size(args.size))
    end
    if args.maxLines then
        txt:setMaxLines(args.maxLines)
    end
    if args.minLines then
        txt:setMinLines(args.minLines)
    end
    if args.lines then
        txt:setLines(args.lines)
    end
    local Typeface,tface = G.Typeface
    if args.typeface or args.textStyle then
        if args.typeface then
            tface = Typeface:create(args.typeface,Typeface.NORMAL)
        else
            tface = txt:getTypeface()
        end
        if args.textStyle then
            local style = args.textStyle:upper()
            tface = Typeface:create(tface,Typeface[style])
        end
        txt:setTypeface(tface)
    end
    if args.inputType then -- see android:inputType
        txt:setInputType(parse_input_type(args.inputType))
        if args.inputType == 'textMultiLine' then
            if args.gravity == nil then -- sensible default gravity
                args.gravity = 'top|left'
            end
            if args.scrollable then
                SMM = SMM or bind 'android.text.method.ScrollingMovementMethod':getInstance()
                txt:setMovementMethod(SMM)
            end
        end
    end
    if args.focus == false then
        txt:setFocusable(false)
    end
    if args.gravity then
        local gg = split(args.gravity,'|')
        local g = 0
        for _,p in ipairs(gg) do
            g = g + V.Gravity[p:upper()]
        end
        txt:setGravity(g)
    end
    if args.scrollable then
        local smm = bind 'android.text.method.ScrollingMovementMethod':getInstance()
        txt:setMovementMethod(smm)
    end
    local L,T,R,B = args.drawableLeft,args.drawableTop,args.drawableRight,args.drawableBottom
    local compound = L or T or R or B
    if compound then
        local def = type(compound)=='number' and 0 or nil
        txt:setCompoundDrawablesWithIntrinsicBounds(L or def,T or def,R or def,B or def)
    end
end

-- http://stackoverflow.com/questions/3506696/auto-scrolling-textview-in-android-to-bring-text-into-view?rq=1
function android:scroll_to_end (txt)
    local layout = txt:getLayout()
    if layout then
        local amt = layout:getLineTop(txt:getLineCount()) - txt:getHeight()
        if amt > 0 then
            txt:scrollTo(0,amt)
        end
    end
end


local function handle_args (args)
    if type(args) ~= 'table' then
        args = {args}
    end
    return args[1] or args.text or '',args
end

--- create a text view style.
-- @param me
-- @param args as in `android.textView`
-- @return a function that creates a text view from a string
function android.textStyle (me,args)
    return function(text)
        local targs = android.copytable(args)
        targs[1] = text
        return me:textView(targs)
    end
end

local function tab_content (callback)
    return proxy('android.widget.TabHost_TabContentFactory',{
        createTabContent = callback
    })
end

local function tab_view (v)
    return tab_content(function(s) return v end)
end

--- make a tab view.
-- @param me
-- @param tabs a list of items;
--
--  - `tag` a string identifying the tab
--  - `label` a string label, or the same args passed to `android.textView`.
--     If `tabs.style` is defined, then the string is processed using it.
--     The default is to use `tag`
--  - `content` a View, or a function returning a View, or a Lua activity module name
--
-- @treturn W.TabHost
function android.tabView (me,tabs)
    local views = {}
    me:set_content_view 'tabs'
    local tabhost = me.a:findViewById(A.R_id.tabhost)

    local lam = bind 'android.app.LocalActivityManager'(me.a,false)
    lam:dispatchCreate(me.state)
    tabhost:setup(lam)

    if tabs.changed then
        tabhost:setOnTabChangedListener(proxy('android.widget.TabHost_OnTabChangeListener',{
            onTabchanged = android.safe(tabs.changed)
        }))
    end

    for _,item in ipairs(tabs) do
        local tag,content = item.tag,item.content
        local label = item.label or tag
        local spec = tabhost:newTabSpec(tag)

        -- label is either a string, a table to be passed to textView,
        -- or a view or resource id.
        if type(label) == 'table' then
            label = me:textView(label)
        elseif type(label) == 'string' and tabs.style then
            label = tabs.style(label)
        end
        spec:setIndicator(label)

        -- content is either a string (a module name) or a function
        -- that generates a View, or a View itself
        if type(content) == 'string' then
            local mod = require (content)
            content = tab_content(function(tag)
                if not views[tag] then
                    views[tag] = mod.onCreate(me.a,item.data,me.state)
                end
                return views[tag]
            end)
        elseif type(content) == 'function' then
            content = tab_content(content)
        elseif type(content) == 'userdata' then
            content = tab_view(content)
        end
        spec:setContent(content)
        tabhost:addTab(spec)
    end

    return tabhost
end

--- create a button.
-- @param me
-- @param text of button
-- @param callback a Lua function or an existing click listener.
-- This is passed the button as its argument
-- @treturn W.Button
function android.button (me,text,callback)
    local b = W.Button(me.a)
    b:setText(text)
    if type(callback) == 'function' then
        callback = me:on_click_handler(callback)
    end
    b:setOnClickListener(callback)
    ---? set_view_args(b,args,me)
    return me:give_id(b)
end

--- create an edit widget.
-- @param me
-- @param args either a string (which is usually the hint, or the text if it
-- starts with '!') or a table with fields `textColor`, `id`, `background` or `size`
-- @treturn W.EditText
function android.editText (me,args)
    local text,args = handle_args(args)
    local txt = W.EditText(me.a)
    if text:match '^!' then
        txt:setText(text:sub(1))
    else
        txt:setHint(text)
    end
    me:setEditArgs(txt,args)
    return txt
end

-- create a text view.
-- @param me
-- @param args as with `android.editText`
-- @treturn W.TextView
function android.textView (me,args)
    local text,args = handle_args(args)
    local txt = W.TextView(me.a)
    txt:setText(text)
    me:setEditArgs(txt,args)
    return txt
end

--- create an image view.
-- @param me
-- @param args table of properties to be passed to `android.setViewArgs`
-- @treturn W.ImageView
function android.imageView(me,args)
    local text,args = handle_args(args)
    local image = W.ImageView(me.a)
    return me:setViewArgs(image,args)
end

--- create a simple list view.
-- @param me
-- @param items a list of strings
-- @treturn W.ListView
function android.listView(me,items)
    local lv = W.ListView(me.a)
    local adapter = W.ArrayAdapter(me.a,
        --A.R_layout.simple_list_item_checked,
        A.R_layout.simple_list_item_1,
        A.R_id.text1,
        L.String(items)
    )
    lv:setAdapter(adapter)
    return me:give_id(lv)
end

--- create a spinner.
-- @param me
-- @param args list of strings; if there is a `prompt` field it
-- will be used as the Spinner prompt. Alternatively strings are found
-- in `options` field
-- @treturn W.Spinner
function android.spinner (me,args)
    local items = args.options or args
    local s = W.Spinner(me.a)
    local sa = W.ArrayAdapter(me.a,
        A.R_layout.simple_spinner_item,
        A.R_id.text1,
        L.String(items)
    )
    sa:setDropDownViewResource(A.R_layout.simple_spinner_dropdown_item)
    s:setAdapter(sa)
    if items.prompt then
        s:setPrompt(items.prompt)
    end
    return me:give_id(s)
end

--- create a check box.
-- @param me
-- @param args as in `android.imageView`
-- @treturn W.CheckBox
function android.checkBox (me,args)
    local text,args = handle_args(args)
    local check = W.CheckBox(me.a)
    check:setText (text)
    return me:setViewArgs(check,args)
end

--- create a toggle button.
-- @param me
-- @param args must have `on` and `off` labels; otherwise as in `android.textView`
-- @treturn W.ToggleButton
function android.toggleButon (me,args)
    local tb = W.ToggleButton(me.a)
    tb:setTextOn (args.on)
    tb:setTextOff (args.off)
    return me:setViewArgs(tb,args)
end

--- create a radio group.
-- @param me
-- @param items a list of strings
-- @treturn W.RadioGroup
-- @treturn {W.RadioButton}
function android.radioGroup (me,items)
    local rg = W.RadioGroup(me.a)
    for i,item in ipairs(items) do
        local b = W.RadioButton(me.a)
        b:setText(item)
        rg:addView(b)
        items[i] = b
    end
    return rg,unpack(items)
end

--- create a Lua View.
-- @param me
-- @param t may be a drawing function, or a table that defines `onDraw`
-- and optionally `onSizeChanged`. It will receive the canvas.
-- @treturn .LuaView
function android.luaView(me,t)
    if type(t) == 'function' then
        t = { onDraw = t }
    end
    return me:give_id(LS:launchLuaView(me.a,t))
end

local function parse_gravity (s)
    if type(s) == 'string' then
        return V.Gravity[s:upper()]
    else
        return s
    end
end

local function linear (me,vertical,t)
    local LL = not t.radio and W.LinearLayout or W.RadioGroup
    local LP = W.LinearLayout_LayoutParams
    local wc = LP.WRAP_CONTENT
    local fp = LP.FILL_PARENT
    local xp, yp, parms
    if vertical then
        xp = fp;  yp = wc;
    else
        xp = wc;  yp = fp
    end
    local margin
    if t.margin then
        if type(t.margin) == 'number' then
            t.margin = {t.margin,t.margin,t.margin,t.margin}
        end
        margin = t.margin
    end
    local ll = LL(me.a)
    ll:setOrientation(vertical and LL.VERTICAL or LL.HORIZONTAL)
    for i = 1,#t do
        local w, gr = t[i]
        if type(w) == 'userdata' then
            local spacer
            if i < #t and type(t[i+1])~='userdata' then
                local mods = t[i+1]
                local weight,gr,nofill,width
                if type(mods) == 'string' then
                    if mods == '+' then
                        weight = 1
                    elseif mods == '...' then
                        spacer = true
                    end
                elseif type(mods) == 'table' then
                    weight = mods.weight
                    nofill = mods.fill == false
                    gr = parse_gravity(mods.gravity)
                    width = mods.width or mods.height
                end
                local axp,ayp = xp,yp
                if nofill then
                    if vertical then axp = wc else ayp = wc end
                end
                if width then
                    width = me:parse_size(width)
                    if not vertical then axp = width else ayp = width end
                end
                parms = LP(axp,ayp,weight or 0)
                i = i + 1
            else
                parms = LP(xp,yp)
            end
            if margin then
                for i=1,4 do margin[i] = me:parse_size(margin[i]) end
                parms:setMargins(margin[1],margin[2],margin[3],margin[4])
            end
            if gr then
                parms.gravity = gr
            end
            ll:addView(w,parms)
            if spacer then
                ll:addView(me:textView'',LP(xp,yp,10))
            end
        end
    end
    me:setViewArgs(ll,t)
    return ll
end

--- create a vertical layout.
-- @param me
-- @param t a list of controls, optionally separated by layout strings or tables
-- for example, `{w1,'+',w2} will give `w1` a weight of 1 in the layout;
-- tables of form {width=number,fill=false,gravity=string,weight=number}
-- Any fields are processed as in 'android.setViewArgs`
-- @treturn W.LinearLayout
function android.vbox (me,t)
    local vbox = linear(me,true,t)
    if t.scrollable then
        local hs = W.ScrollView(me.a)
        hs:addView(vbox)
        return hs
    else
        return vbox
    end
end

--- create a horizontal layout.
-- @param me
-- @param t a list of controls, as in `android.vbox`.
-- @treturn W.LinearLayout
function android.hbox (me,t)
    local hbox = linear(me,false,t)
    if t.scrollable then
        local hs = W.HorizontalScrollView(me.a)
        hs:addView(hbox)
        return hs
    else
        return hbox
    end
end

local function lua_adapter(me,items,impl)
    if type(impl) == 'function' then
        impl = { getView = impl; items = items }
    end
    return LS:createLuaListAdapter(items,impl or me)
end

--- create a Lua list view.
-- @param me
-- @param items a list of Lua values
-- @param impl optional implementation - not needed if `me`
-- has a getView function. May be a function, and then it's
-- assumed to be getView.
-- @treturn W.ListView
-- @treturn .LuaListAdapter
function android.luaListView (me,items,impl)
    local adapter = lua_adapter(me,items,impl)
    local lv = W.ListView(me.a)
    lv:setAdapter(adapter)
    lv:setTag(items)
    return me:give_id(lv), adapter
end

-- create a Lua expandable list view
-- @param me
-- @param items a list of lists, where each sublist
--  has a `group` field for the corresponding group data.
-- @param impl a table containing at least `getGroupView` and `getChildView`
-- implementations. (see `example.ela.lua`)
-- @treturn W.ListView
-- @treturn W.ExpandableListAdapter
function android.luaExpandableListView (me,items,impl)
    local onChildClick = impl.onChildClick
    impl.onChildClick = nil

    local adapter = require 'android.ELVA' (items,impl)
    local elv = W.ExpandableListView(me.a)
    elv:setAdapter(adapter)

    if onChildClick then
        onChildClick = android.safe(onChildClick)
        elv:setOnChildClickListener(proxy('android.widget.ExpandableListView_OnChildClickListener',{
            onChildClick = function(parent,view,g,c,id)
                local res = onChildClick(adapter:getChild(g,c),view,g,c,id)
                return res or false -- ensure we always return a boolean!
            end
        }))
    end
    return me:give_id(elv), adapter
end

--- create a Lua grid view.
-- @param me
-- @param items a table of Lua values
-- @number ncols number of columns (-1 for as many as possible)
-- @param impl optional implementation - not needed if `me`
-- has a getView function. May be a function, and then it's
-- assumed to be getView.
-- @return W.GridView
-- @treturn .LuaListAdapter
function android.luaGridView (me,items,ncols,impl)
    local adapter = lua_adapter(me,items,impl)
    local lv = W.GridView(me.a)
    lv:setNumColumns(ncols or -1)
    lv:setAdapter(adapter)
    return me:give_id(lv), adapter
end

--- Acitivies.
-- @section activities

--- launch a Lua activity.
-- @param me
-- @param mod a Lua module name that defines the activity
-- @param arg optional extra value to pass to activity
function android.luaActivity (me,mod,arg)
    return LS:launchLuaActivity(me.a,mod,arg)
end

local handlers = {}

--- start an activity with a callback on result.
-- Wraps `startActivityForResult`.
-- @param me
-- @tparam Intent intent
-- @func callback to be called when the result is returned.
function android.intent_for_result (me,intent,callback)
    append(handlers,callback)
    me.a:startActivityForResult(intent,#handlers)
end

function android.onActivityResult(request,result,intent,mod_handler)
    print('request',request,intent)
    local handler = handlers[request]
    if handler then
        handler(request,result,intent)
        table.remove(handlers,request)
    elseif mod_handler then
        mod_handler(request,result,intent)
    else
        android.activity_result = {request,result,intent}
    end
end

--- make a new AndroLua module.
function android.new()
    local mod = {}
    mod.onCreate = function (activity,arg,state)
        local me = {a = activity, mod = mod, state = state}
        for k,v in pairs(android) do me[k] = v end
        -- want any module functions available from the wrapper
        setmetatable(me,{
            __index = mod
        })
        android.me = me -- useful for debugging and non-activity-specific context
        mod.me = me
        mod.a = activity
        me.metrics = activity:getResources():getDisplayMetrics()
        get_app_package(me) -- initializes me.app
        local view = mod.create(me,arg)
        mod._view = view
        return view
    end
    local oldActivityResult = mod.onActivityResult
    local thisActivityResult = android.onActivityResult
    if oldActivityResult then
        mod.onActivityResult = function(r,R,i)
            thisActivityResult(r,R,i,oldActivityResult)
        end
    else
        mod.onActivityResult = thisActivityResult
    end
    return mod
end

return android
