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

import java.io.Serializable;

import sk.kottman.androlua.*;


public class MainActivity extends LuaActivity {
    @Override
    public void onCreate(Bundle savedInstanceState) {
        //LuaObject module=lua.safeEval("return {}", ".");
        //modify the intent that started this activity
        //Intent thisIntent = getIntent();
        //thisIntent.putExtra("LUA_SELF", module);

        //start the Lua service to handle the VM in the background
        Intent serviceIntent = new Intent(this, LuaService.class);
        startService(serviceIntent);
        self = null;
        super.onCreate(savedInstanceState);
    }

    @Override
    public void onServiceConnected(ComponentName name, IBinder service) {
        super.onServiceConnected(name, service);
        ((LuaService.LuaBinder)service).startServer(3333); //start an interactive shell server (telnet works)
        lua.addPackagePath("/sdcard/scriptastic");
        lua.safeEval("package.loaded = {}", "."); //force reload all packages.
        LuaObject t = lua.safeEval("return require('MainActivity')", "init");
        lua.safeEval("service:log('hello from lua')", "init");
        setSelf(t);
    }
}
