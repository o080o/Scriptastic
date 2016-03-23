password = require 'android'.new()


function password.create (me)

    me.title = me:textView{
        'Enter user name and password:',
        size='20sp',textColor='white'
    }
    me.name = me:editText{'Your UserName',inputType='textPersonName'}
    me.password = me:editText{'Your Password',inputType='textPassword'}
    me.viewPassword = me:checkBox 'view password'

    me:on_click(me.viewPassword,function(v)
        local type = v:isChecked() and 'text' or 'textPassword'
        me:setEditArgs(me.password,{inputType=type})
    end)

    local function get_text (v)
        return v:getText():toString()
    end

    local function only_connect()
        local name = get_text(me.name)
        local password = get_text(me.password)

        if name=='' or password=='' then
            me:alert('Problem!','ok','Must fill in name and password!')
            return
        end

    end

    me:options_menu {
        "source",function()
            me:luaActivity('example.pretty','example.password')
        end,
    }

    local v = me:vbox{
        scrollable = true;
        margin = {20,10,20,10};
        background = '#447744';
        me.title,
        me.name,{width='200sp'},
        me.password,{width='200sp'},
        me.viewPassword,
        me:button('Login',only_connect),{fill=false,gravity='center_horizontal'},
        me:button('Test Values',function()
            me.name:setText 'Patsy Stone'
            me.password:setText 'fabulous'
        end),{fill=false,gravity='center'},
    }
    return v

end

return password


