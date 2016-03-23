--- intents.lua
-- Wrappers for common intents like taking pictures and sending messages
-- @submodule android
require 'android'
local PK = luajava.package
local L = PK 'java.lang'
local IO = PK 'java.io'
local app = PK 'android.app'
local C = PK 'android.content'
local P = PK 'android.provider'
local RESULT_CANCELED = app.Activity.RESULT_CANCELED
local Intent = bind 'android.content.Intent'
local Uri = bind 'android.net.Uri'

--- open the Camera app and let user take a picture.
-- @param me
-- @string file
-- @func callback
function android.take_picture (me,file,callback)
    local intent = Intent(P.MediaStore.ACTION_IMAGE_CAPTURE)
    callback = android.safe(callback)
    if file then
        if not file:match '^/' then
            file = IO.File(me.a:getFilesDir(),'images'..file)
        else
            file = IO.File(file)
        end
        file:getParentFile():mkdir()
        intent:putExtra(P.MediaStore.EXTRA_OUTPUT, Uri:fromFile(file))
        me:intent_for_result (intent,function(_,result,intent)
            callback(result ~= RESULT_CANCELED,intent)
        end)
    else
        me:intent_for_result (intent,function(_,result,intent)
            local data
            print(result,intent)
            if result ~= RESULT_CANCELED then
                data = intent:getExtras():get 'data'
            end
            callback(data,result,intent)
        end)
    end
end

--- open messaging or mail app and prepare message for user.
-- @param me
-- @string subject
-- @string body
-- @string address
function android.send_message (me,subject,body,address)
    local intent
    if not subject then -- let's let the user decide
        local kind = Intent(Intent.ACTION_SEND)
        kind:setType 'text/plain'
        kind:putExtra(Intent.EXTRA_TEXT,body)
        intent = Intent:createChooser(kind,nil)
    else
        address = address or ''
        intent = Intent(Intent.ACTION_VIEW)
        intent:setData(Uri:parse ('mailto:'..address..'?subject='..subject..'&body='..body))
    end
    me.a:startActivity(intent)
end

--- choose a picture from Gallery and so forth.
-- @param me
-- @func callback
function android.pick_picture (me,callback)
    local intent = Intent()
    intent:setType 'image/*'
    intent:setAction(Intent.ACTION_GET_CONTENT)
    me:intent_for_result(Intent:createChooser(intent,nil),function(_,_,data)
        data = data:getData() -- will be a Uri
        local c = me.a:getContentResolver():query(data,L.String{'_data'},nil,nil,nil)
        c:moveToFirst()
        callback(c:getString(0))
    end)
end

--- record audio.
-- @param me
-- @string file
-- @func callback
function android.record_audio (me,file,callback)
    local intent = Intent(P.MediaStore_Audio_Media.RECORD_SOUND_ACTION)
    --intent:putExtra(P.MediaStore.EXTRA_OUTPUT, Uri(file));
    me:intent_for_result(intent,function(_,_,data)
        if data == null then return callback(nil,'no data') end
        data = data:getData()
        print('uri',data)
        local c = me.a:getContentResolver():query(data,L.String{'_data'},nil,nil,nil)
        c:moveToFirst()
        callback(c:getString(0))
    end)
end

local function get_string(c,key,def)
    local idx = c:getColumnIndex(key)
    if idx == -1 then return def end
    return c:getString(idx)
end

--- let user pick a Contact.
-- @param me
-- @func callback
function android.pick_contact(me,callback)
    local CCC = P.ContactsContract_Contacts
    local CCP = P.ContactsContract_CommonDataKinds_Phone
    local CCE = P.ContactsContract_CommonDataKinds_Email
    local intent = Intent(Intent.ACTION_PICK,CCC.CONTENT_URI)
    callback = android.safe(callback)
    me:intent_for_result(intent,function(_,result,intent)
        if result ~= RESULT_CANCELED then
            local uri = intent:getData()
            local c = me.a:managedQuery(uri,nil,nil,nil,nil)
            if c:moveToFirst() then
                local res = {uri = uri}
                res.id = get_string(c,CCC._ID)
                res.name = get_string(c,CCC.DISPLAY_NAME)
                res.thumbnail = get_string(c,CCC.PHOTO_THUMBNAIL_URI)
                if get_string(c,CCC.HAS_PHONE_NUMBER,'0') ~= '0' then
                    local phones = me.a:managedQuery(CCP.CONTENT_URI,
                        nil, CCP.CONTACT_ID..' = '..res.id,nil,nil)
                    phones:moveToFirst()
                    res.phone = get_string(phones,"data1")
                end
                local emails = me.a:managedQuery(CCE.CONTENT_URI,
                    nil, CCE.CONTACT_ID..' = '..res.id,nil,nil)
                if emails:moveToFirst() then
                    res.email = get_string(emails,"data1")
                end
                callback(res)
            else
                callback(nil,'no such contact')
            end
        else
            callback(nil,'cancelled')
        end
    end)
end

-- flags whether we're loaded or not
android.intents = true
