package com.o080o.scriptastic;
import android.content.Context;
import android.content.Intent;

/**
 * Created by o080o on 3/25/16.
 */
public interface LuaBroadcastReceiverTask {
    public void run(Context context, Intent intent);
}
