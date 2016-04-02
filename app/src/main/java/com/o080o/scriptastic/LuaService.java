package com.o080o.scriptastic;

import android.app.Activity;
import android.app.IntentService;
import android.app.Notification;
import android.app.NotificationManager;
import android.app.Service;
import android.content.Context;
import android.content.Intent;
import android.content.ServiceConnection;
import android.content.res.AssetManager;
import android.graphics.BitmapFactory;
import android.os.Binder;
import android.os.Handler;
import android.os.IBinder;
import android.os.StrictMode;
import android.support.v4.app.NotificationCompat;
import android.util.Log;

import org.keplerproject.luajava.JavaFunction;
import org.keplerproject.luajava.LuaException;
import org.keplerproject.luajava.LuaObject;

import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.io.PrintStream;

/**
 * Created by o080o on 3/30/16.
 */
public class LuaService extends Service {
    public LuaVM lua;
    public int notificationId=1;
    private Server server;

    public class LuaBinder extends Binder{
        public LuaObject eval(String src, String chunk){
            Log.d("service", "executing: " + src);
            return LuaService.this.lua.safeEval(src,chunk);
        }
        public LuaVM getLuaVM(){return LuaService.this.lua;}
        public void startServer(int port){
            server = new Server(LuaService.this, LuaService.this.lua, port);
            server.start();
        }
        public void stopServer(){server.close();}
    }
    private final IBinder binder = new LuaBinder();

    @Override
    public void onCreate () {
        StrictMode.setThreadPolicy(StrictMode.ThreadPolicy.LAX);
        Log.d("scriptastic", "starting Lua service");
        lua = new LuaVM();
        lua.addPackagePath(this.getFilesDir().getAbsolutePath());
        lua.addAssets(this.getAssets());
        lua.setGlobal("service", this);
        lua.setGlobal("context", this);
    }

    @Override
    public int onStartCommand (Intent intent, int flags, int startid) {
        //make a dummy notification to start the service in the foreground (we'll let other classes update it...)
        Notification notification = new NotificationCompat.Builder(this).build();
        startForeground(notificationId, notification);
        //don't let this service die!!
        //return START_REDELIVER_INTENT;
        return START_NOT_STICKY;
    }

    public void log(String str){Log.d("lua", str);}


    @Override
    public IBinder onBind(Intent intent) {
        return binder;
    }

    public String stash(LuaObject obj, String key){return lua.stash(obj, key);}

}
