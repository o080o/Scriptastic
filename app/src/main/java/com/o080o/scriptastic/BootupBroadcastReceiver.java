package com.o080o.scriptastic;

import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;

import sk.kottman.androlua.Lua;

/**
 * Created by o080o on 3/25/16.
 */
public class BootupBroadcastReceiver extends BroadcastReceiver {
    @Override
    public void onReceive(Context context, Intent intent) {
        //start the Lua service to handle the VM in the background
        Intent serviceIntent = new Intent(context, LuaService.class);
        context.startService(serviceIntent);
    }
}
