package com.o080o.scriptastic;

import android.app.Activity;
import android.app.IntentService;
import android.app.Notification;
import android.app.NotificationManager;
import android.app.Service;
import android.content.Context;
import android.content.Intent;
import android.content.ServiceConnection;
import android.graphics.BitmapFactory;
import android.os.Binder;
import android.os.Handler;
import android.os.IBinder;
import android.os.StrictMode;
import android.support.v4.app.NotificationCompat;
import android.util.Log;

import org.keplerproject.luajava.LuaObject;

/**
 * Created by o080o on 3/30/16.
 */
public class LuaService extends Service {
    public LuaVM lua;
    public int notificationId=1;

    public class LuaBinder extends Binder{
        public LuaObject eval(String src, String chunk){
            Log.d("service", "executing: " + src);
            return LuaService.this.lua.safeEval(src,chunk);
        }
        public LuaVM getLuaVM(){return LuaService.this.lua;}
    }
    private final IBinder binder = new LuaBinder();

    @Override
    public void onCreate () {
        StrictMode.setThreadPolicy(StrictMode.ThreadPolicy.LAX);
        Log.d("scriptastic", "starting Lua service");
        lua = new LuaVM();
        lua.addPackagePath(this.getFilesDir().getAbsolutePath());
        lua.setGlobal("service", this);
        lua.setGlobal("context", this);
    }

    @Override
    public int onStartCommand (Intent intent, int flags, int startid) {
        //make a dummy notification to start the service in the foreground (we'll update it in handleIntent)
        Notification notification = new NotificationCompat.Builder(this).build();
        startForeground(notificationId, notification);

        //don't let this service die!!
        //return START_REDELIVER_INTENT;
        return START_NOT_STICKY;
    }

    public void log(String str){Log.d("lua", str);}

    protected void handleIntent(Intent intent){
        // run a bit of code in the lua VM.
        String src = intent.getStringExtra("LUA_INITCODE");
        if (src != null) {
            lua.safeEval(src, "init");
        }
        // get parameters...
        String title = intent.getStringExtra("LUA_SERVICE_TITLE");
        if (title==null) {
            title=getPackageName();
        }
        int icon = intent.getIntExtra("LUA_SERVICE_ICON", 0);
        int largeIcon = intent.getIntExtra("LUA_SERVICE_LARGE_ICON", 0);
        String content = "running...";
        //make thi notification builder with the proper parameters
        NotificationCompat.Builder builder = new NotificationCompat.Builder(this);
        builder.setContentTitle(title);
        builder.setContentText(content);
        builder.setSmallIcon(icon);
        builder.setLargeIcon(BitmapFactory.decodeResource(getResources(), largeIcon, new BitmapFactory.Options()));
        //update the ongoing notification
        NotificationManager notificationManager =
                (NotificationManager) getSystemService(this.NOTIFICATION_SERVICE);
        notificationManager.notify(notificationId, builder.build());
    }


    // currently this is just so that the main activity knows when the service is up...
    // will support a remote script running option
    @Override
    public IBinder onBind(Intent intent) {
        return binder;
    }

}
