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
import java.io.File;
import java.io.FileNotFoundException;
import java.io.FileReader;
import java.io.IOException;
import java.io.InputStream;
import java.io.PrintStream;
import java.util.ArrayList;
import java.util.Scanner;

/**
 * Created by o080o on 3/30/16.
 */
public class LuaService extends Service {
    public LuaVM lua;
    public int notificationId=1;
    private Server server;
    private ArrayList<String> packagePath = new ArrayList<String>();
    private Handler handler;

    public class LuaBinder extends Binder{
        public LuaObject eval(String src, String chunk){
            Log.d("service", "executing: " + src);
            return LuaService.this.lua.safeEval(src,chunk);
        }
        public LuaVM getLuaVM(){return LuaService.this.lua;}
        public LuaService getService(){return LuaService.this;}
        public void startServer(int port){
            if(server==null || !server.running) {
                server = new Server(LuaService.this, LuaService.this.lua, port);
                server.start();
            }
        }
        public void stopServer(){server.close();}
    }
    private final IBinder binder = new LuaBinder();

    @Override
    public void onCreate () {
        StrictMode.setThreadPolicy(StrictMode.ThreadPolicy.LAX);
        Log.d("scriptastic", "starting Lua service");
        handler = new Handler(this.getMainLooper());
        resetVM();
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


    @Override
    public IBinder onBind(Intent intent) {
        return binder;
    }

    //public functions for use in lua code...
    public void log(String str){Log.d("lua", str);}
    public String stash(LuaObject obj, String key){return lua.stash(obj, key);}
    public int getRef(LuaObject obj){return obj.getRef();}
    public void releaseRef(int ref){lua.releaseRef(ref);}
    public void post(Runnable task, long time){handler.postDelayed(task, time);}
    public void post(Runnable task){handler.post(task);}
    public void post(final LuaObject task){
        post(new Runnable() {
            @Override
            public void run() {
                lua.safeEval(task);
            }
        });
    }
    public void post(final LuaObject task, long time){
        post(new Runnable() {
            @Override
            public void run() {
                lua.safeEval(task);
            }
        }, time);
    }

    //provide some access to the VM. **ONLY ACCESSIBLE WITHIN THIS PACKAGE** for security.
    // we don't want arbitrary code resetting our VM.
    void resetVM(){
        lua = new LuaVM();
        lua.addPackagePath(this.getFilesDir().getAbsolutePath());
        lua.addAssets(this.getAssets());
        lua.setGlobal("service", this); //would rather not expose the service... or make the service interface non-privledged.
        //lua.setGlobal("context", R.mipmap.ic_launcher);
    }

}
