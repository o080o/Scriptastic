package com.o080o.scriptastic;

import android.content.Intent;
import android.os.Bundle;

import sk.kottman.androlua.*;


public class MainActivity extends LuaActivity {
    @Override
    public void onCreate(Bundle savedInstanceState) {
        //start the Lua service to handle the VM in the background
        Intent serviceIntent = new Intent(this, Lua.class);
        serviceIntent.putExtra("LUA_INITCODE", "package.path = package.path .. ';/sdcard/scriptastic/?.lua'");
        serviceIntent.putExtra("LUA_SERVICE_TITLE", "Scriptastic");
        serviceIntent.putExtra("LUA_SERVICE_ICON", R.drawable.lua_notification_icon );
        serviceIntent.putExtra("LUA_SERVICE_LARGE_ICON", R.mipmap.ic_launcher );
        serviceIntent.putExtra("LUA_START_TCP", true);

                startService(serviceIntent);
        //load a module to display the settings or something usefull when you actually *open* the app.
        setLuaModule("main");
        //bind to the service
        Lua.bind(this, this);


        super.onCreate(savedInstanceState);
    }
}
