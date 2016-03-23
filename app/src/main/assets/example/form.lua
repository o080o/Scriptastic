form = require 'android'.new()
-- needed for creating an email..
require 'android.intents'

-- compare to this more standard implementation:
--http://mobile.tutsplus.com/tutorials/android/android-sdk-creating-forms/

function form.create (me)

    me.title = me:textView{'Enter feedback details to developer:',size='25sp'}
    me.name = me:editText{'Your Name',inputType='textPersonName'}
    me.email = me:editText{'Your Email',inputType='textEmailAddress'}
    me.kind = me:spinner {
        prompt='Enter feedback type';
        'Praise','Gripe','Suggestion','Bug'
    }
    me.details = me:editText{'Feedback Details...',inputType='textMultiLine',
        minLines=5,gravity='top|left'}
    me.emailResponse = me:checkBox 'Would you like an email response?'

    local function get_text (v)
        return v:getText():toString()
    end

    local function send_feedback()
        local name = get_text(me.name)
        local email = get_text(me.email)
        local details = get_text(me.details)
        local gripe = me.kind:getSelectedItem()

        if name=='' or email=='' then
            me:alert('Problem!','ok','Must fill in name and email address!')
            return
        end

        local body = 'To: The Gripe Department\n\n'..
            details..'\n\n'..name..'('..email..')'

        if me.emailResponse:isChecked() then
            body = body .. '\nRequires a response'
        end

        me:send_message('Application Feedback ('..gripe..')',
            body,'appfeedback@yourappsite.com')

    end

    me:options_menu {
        "source",function()
            me:luaActivity('example.pretty','example.form')
        end,
    }

    return me:vbox{
        scrollable = true;
        me.title,
        me.name,
        me.email,
        me.kind,
        me.details,
        me.emailResponse,
        me:button('Send Feedback',send_feedback),
        me:button('Test Values',function()
            me.name:setText 'Patsy Stone'
            me.email:setText 'patsy@fabulous.org'
            me.details:setText 'too slow darling!'
        end)
    }
end

return form


