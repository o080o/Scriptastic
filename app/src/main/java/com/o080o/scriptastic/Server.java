package com.o080o.scriptastic;

import android.app.Notification;
import android.app.NotificationManager;
import android.content.Context;
import android.graphics.Bitmap;
import android.graphics.BitmapFactory;
import android.os.Handler;
import android.os.Vibrator;
import android.support.v4.app.NotificationCompat;
import android.util.Log;
import android.widget.Toast;

import org.keplerproject.luajava.LuaException;
import org.keplerproject.luajava.LuaObject;

import java.io.BufferedReader;
import java.io.BufferedWriter;
import java.io.File;
import java.io.FileWriter;
import java.io.IOException;
import java.io.InputStream;
import java.io.InputStreamReader;
import java.io.PipedInputStream;
import java.io.PrintWriter;
import java.net.ServerSocket;
import java.net.Socket;
import java.util.ArrayList;

/**
 * Created by o080o on 4/1/16.
 */
public class Server extends Thread {
    protected boolean running;

    protected int listenPort;
    protected Handler handler;
    protected LuaVM lua;
    protected Context context;
    private int notificationID=45678765;

    protected ArrayList<Socket> attachedClients = new ArrayList<>(5);

    public Server(Context context, LuaVM lua, int listenPort) {
        this.lua = lua;
        this.listenPort = listenPort;
        this.context = context;
        // Get a handler that can be used to post to the main thread
        handler = new Handler(context.getMainLooper());
        lua.setGlobal("mainThread", handler);
    }

    public void setVM(Context context, LuaVM lua){
        this.lua = lua;
        this.context = context;
        // Get a handler that can be used to post to the main thread
        handler = new Handler(context.getMainLooper());
        lua.setGlobal("mainThread", handler);
    }

    //stop the server and all active clients...
    public void close(){
        running = false;
    }
    //create of update a notification informing the user how many clients are currently connected
    protected void updateNotification(){
        handler.post(new Runnable() {
            @Override
            public void run() {

                Bitmap icon = BitmapFactory.decodeResource(context.getResources(), R.mipmap.ic_launcher);
                Notification notification = new NotificationCompat.Builder(context)
                        .setSmallIcon(R.drawable.lua_notification_icon)
                        .setLargeIcon(icon)
                        .setContentTitle("Scriptastic")
                        .setContentText("Connected Clients:" + Integer.toString(attachedClients.size()))
                        .setOngoing(true)
                        .setPriority(Notification.PRIORITY_HIGH)
                        .build();
                notification.defaults |= Notification.DEFAULT_SOUND;
                notification.defaults |= Notification.DEFAULT_VIBRATE;
                NotificationManager notificationManager =
                        (NotificationManager) context.getSystemService(Context.NOTIFICATION_SERVICE);
                if(attachedClients.isEmpty()){
                    notificationManager.cancel(notificationID);
                } else {
                    notificationManager.notify(notificationID, notification);
                }

            }
        });
    }
    //accept a client, and notify the user.
    protected Socket acceptClient(ServerSocket server) throws IOException{
        Socket client = server.accept();
        Log.d("client", "client accepted");
        attachedClients.add(client);
        updateNotification();
        return client;
    }



    protected void disconnectClient(Socket client) throws IOException{
        client.close();
        Log.d("client", "client disconnected");
        attachedClients.remove(client);
        updateNotification();
    }

    //push the client into its *own* thread.
    protected void handleClient(final Socket client){
        new Thread(new Runnable(){
            @Override
            public void run() {
                String line;
                try {
                    BufferedReader in = new BufferedReader(new InputStreamReader(client.getInputStream()));
                    final PrintWriter out = new PrintWriter(client.getOutputStream());
                    InputStream stdout = lua.getStdOut();
                    byte[] buffer = new byte[1024];

                    out.print(">");
                    out.flush();
                    while (running && (line = in.readLine()) != null) {
                        if(line.startsWith("=")){line = "return (" + line.substring(1) + ")";}
                        try {
                            LuaObject res = lua.eval(line, "tmp");
                            while(stdout.available()>0){
                                int read = stdout.read(buffer);
                                out.print(new String(buffer, 0, read));
                            }
                            if (!res.isNil()) {
                                out.println(res);
                            }
                        }catch(LuaException e){
                            out.println(e.getMessage());
                        }
                        out.print(">");
                        out.flush();
                    }
                } catch (IOException e){
                    Log.d("scriptastic", "client error" + e.toString());
                }
                //close client socket.
                try {
                    disconnectClient(client);
                } catch (IOException e){
                    Log.d("scriptastic", "failed to close socket" + e.toString());
                }
            }
        }).start();
    }

    @Override
    public void run() {
        running = true;
        try {
            ServerSocket server = new ServerSocket(listenPort);
            Log.d("scriptastic", "Server started on port " + listenPort);
            while (running) {
                Socket client = acceptClient(server);
                handleClient(client);
            }
            server.close();
        } catch (Exception e) {
            Log.d("scriptastic", "server " + e.toString());
        }
    }
}
