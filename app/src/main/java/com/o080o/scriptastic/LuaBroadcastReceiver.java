package com.o080o.scriptastic;

import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.util.Log;

import org.keplerproject.luajava.LuaObject;

/**
 * Created by o080o on 3/25/16.
 */
public class LuaBroadcastReceiver extends BroadcastReceiver {
    LuaObject func;
    public LuaBroadcastReceiver(LuaObject func) {
        super();
        this.func = func;
    }
    @Override
    public void onReceive(Context context, Intent intent) {
        Log.d("scriptastic", "broadcast receiver execute");
        try {
            func.call(new Object[]{context, intent});
        }catch(Exception e){
            Log.d("scriptastic", e.toString()+e.getMessage());
        }
    }
}
