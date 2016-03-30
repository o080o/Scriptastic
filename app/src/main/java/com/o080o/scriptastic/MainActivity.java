package com.o080o.scriptastic;

import android.app.Activity;
import android.app.Service;
import android.content.ComponentName;
import android.content.Context;
import android.content.Intent;
import android.content.ServiceConnection;
import android.os.Bundle;
import android.os.IBinder;
import android.util.Log;

import org.keplerproject.luajava.LuaObject;

import sk.kottman.androlua.*;


public class MainActivity extends Activity {
    LuaService.LuaBinder luaService;
    ServiceConnection connection;
    LuaVM lua;

    @Override
    public void onCreate(Bundle savedInstanceState) {
        //start the Lua service to handle the VM in the background

        Intent serviceIntent = new Intent(this, LuaService.class);
        serviceIntent.putExtra("LUA_INITCODE", "package.path = package.path .. ';/sdcard/scriptastic/?.lua'");
        serviceIntent.putExtra("LUA_SERVICE_TITLE", "Scriptastic");
        serviceIntent.putExtra("LUA_SERVICE_ICON", R.drawable.lua_notification_icon);
        serviceIntent.putExtra("LUA_SERVICE_LARGE_ICON", R.mipmap.ic_launcher);


        startService(serviceIntent);
        connection = new ServiceConnection() {
            @Override
            public void onServiceConnected(ComponentName name, IBinder service) {
                Log.d("scriptastic", "service connected!");

                luaService = (LuaService.LuaBinder)service;
                lua = luaService.getLuaVM();
                lua.addPackagePath("/sdcard/scriptastic");
                LuaObject t = lua.safeEval("return require('MainActivity')", "init");
                lua.safeEval("service:log('hello from lua')", "init");
            }

            @Override
            public void onServiceDisconnected(ComponentName name) {

            }
        };
        bindService(serviceIntent, connection, Context.BIND_AUTO_CREATE);

        super.onCreate(savedInstanceState);
    }

    @Override
    public void onDestroy(){
        unbindService(connection);
        super.onDestroy();
    }
}
