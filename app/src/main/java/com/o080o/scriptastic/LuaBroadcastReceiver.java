package com.o080o.scriptastic;

import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.util.Log;

/**
 * Created by o080o on 3/25/16.
 */
public class LuaBroadcastReceiver extends BroadcastReceiver {
    LuaBroadcastReceiverTask task;
    public LuaBroadcastReceiver(LuaBroadcastReceiverTask t) {
        super();
        this.task = t;
    }
    @Override
    public void onReceive(Context context, Intent intent) {
        try {
            this.task.run(context, intent);
        }catch(Exception e){
            Log.d("scriptastic", e.toString()+e.getMessage());
        }
    }
}
