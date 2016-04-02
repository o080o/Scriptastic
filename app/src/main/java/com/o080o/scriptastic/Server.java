package com.o080o.scriptastic;

import android.content.Context;
import android.os.Handler;
import android.os.Vibrator;
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

/**
 * Created by o080o on 4/1/16.
 */
public class Server extends Thread {
    private boolean running;

    private int listenPort;
    private Handler handler;
    private LuaVM lua;
    private Context context;

    public Server(Context context, LuaVM lua, int listenPort) {
        this.lua = lua;
        this.listenPort = listenPort;
        this.context = context;
        // Get a handler that can be used to post to the main thread
        handler = new Handler(context.getMainLooper());
        lua.setGlobal("mainThread", handler);
    }

    //stop the server and all active clients...
    public void close(){
        running = false;
    }
    //accept a client, and notify the user.
    public Socket acceptClient(ServerSocket server) throws IOException{
        Socket client = server.accept();
        Log.d("client", "client accepted");
        handler.post(new Runnable() {
            public void run() {
                Toast.makeText(context, context.getPackageName() + ":\n\tclient connected",
                        Toast.LENGTH_LONG).show();
                // Get instance of Vibrator from current Context
                Vibrator v = (Vibrator) context.getSystemService(Context.VIBRATOR_SERVICE);
                // Vibrate for 400 milliseconds
                v.vibrate(400);
            }
        });
        return client;
    }

    public void disconnectClient(Socket client) throws IOException{
        client.close();
        Log.d("client", "client disconnected");
        handler.post(new Runnable() {
            public void run() {
                Toast.makeText(context, context.getPackageName() + ":\n\tclient disconnected",
                        Toast.LENGTH_LONG).show();
                // Get instance of Vibrator from current Context
                Vibrator v = (Vibrator) context.getSystemService(Context.VIBRATOR_SERVICE);
                // Vibrate for 400 milliseconds
                v.vibrate(400);
            }
        });
    }

    //push the client into its *own* thread.
    public void handleClient(final Socket client){
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
