package com.o080o.scriptastic;

import android.content.Intent;
import android.net.LocalSocket;
import android.net.LocalSocketAddress;
import android.util.JsonWriter;
import android.util.Log;

import java.io.PrintWriter;


/**
 * Created by o080o on 3/25/16.
 */
public class Awesomesauce {
    public static String SOCKET_OUTPUT_EXTRA = "arst";
    public static String SOCKET_INPUT_EXTRA = "mehbeh";

    public static void setupPipes(Intent intent) {
        try {
            try (LocalSocket outputSocket = new LocalSocket()) {
                String outputSocketAdress = intent.getStringExtra(SOCKET_OUTPUT_EXTRA);
                outputSocket.connect(new LocalSocketAddress(outputSocketAdress));

                try (LocalSocket inputSocket = new LocalSocket()) {
                    String inputSocketAdress = intent.getStringExtra(SOCKET_INPUT_EXTRA);
                    inputSocket.connect(new LocalSocketAddress(inputSocketAdress));
                }
            }
        }
        catch (Exception e){
            Log.d("awesomesauce", e.getMessage());
        }
    }
}
