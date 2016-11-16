package com.o080o.scriptastic;

import android.content.res.AssetManager;
import android.util.Log;

import org.keplerproject.luajava.JavaFunction;
import org.keplerproject.luajava.LuaException;
import org.keplerproject.luajava.LuaObject;
import org.keplerproject.luajava.LuaState;
import org.keplerproject.luajava.LuaStateFactory;

import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.io.PipedInputStream;
import java.io.PipedOutputStream;
import java.io.PrintStream;
import java.util.ArrayList;

/**
 * Created by o080o on 3/30/16.
 */

public class LuaVM {
    public static int NULLREF = -1;
    private LuaState L;
    private LuaObject stash;
    private ArrayList<PipedOutputStream> outputStreams = new ArrayList<>(3);
    private ArrayList<String> packagePath = new ArrayList<>();
    private int REGISTRYINDEX;

    public LuaVM(){
        L = LuaStateFactory.newLuaState();
        L.openLibs();
        REGISTRYINDEX = LuaState.LUA_REGISTRYINDEX;

        //create a private stash object to save LuaObjects across JVM and LVM
        L.createTable(0,0);
        stash = L.getLuaObject(-1);

        //redirect print statements to one, or several, output stream
        JavaFunction print = new JavaFunction(L) {
            @Override
            public int execute() throws LuaException {
                StringBuilder output = new StringBuilder();
                for (int i = 2; i <= L.getTop(); i++) {
                    int type = L.type(i);
                    String stype = L.typeName(type);
                    String val = null;
                    if (stype.equals("userdata")) {
                        Object obj = L.toJavaObject(i);
                        if (obj != null) // handle Java objects specially...
                            val = obj.toString();
                    }
                    if (val == null) {
                        L.getGlobal("tostring");
                        L.pushValue(i);
                        L.call(1, 1);
                        val = L.toString(-1);
                        L.pop(1);
                    }
                    output.append(val);
                    output.append("\t");
                }
                output.append("\n");

                byte[] out = output.toString().getBytes();
                for(int i=0;i<outputStreams.size();i++){
                    try {
                        outputStreams.get(i).write(out);
                    }catch (IOException e){
                        Log.d("lua", "failed to write output to stream");
                    }
                }
                return 0;
            }
        };
        try {
            print.register("print");
        }catch(LuaException e){
            Log.d("lua", "could not register print function");
        }
        //register a "log" function that writes only to the debug log
        //redirect print statements to one, or several, output stream
        JavaFunction log = new JavaFunction(L) {
            @Override
            public int execute() throws LuaException {
                StringBuilder output = new StringBuilder();
                for (int i = 2; i <= L.getTop(); i++) {
                    int type = L.type(i);
                    String stype = L.typeName(type);
                    String val = null;
                    if (stype.equals("userdata")) {
                        Object obj = L.toJavaObject(i);
                        if (obj != null) // handle Java objects specially...
                            val = obj.toString();
                    }
                    if (val == null) {
                        L.getGlobal("tostring");
                        L.pushValue(i);
                        L.call(1, 1);
                        val = L.toString(-1);
                        L.pop(1);
                    }
                    output.append(val);
                    output.append("\t");
                }
                output.append("\n");
                Log.d("lua", output.toString());
                return 0;
            }
        };
        try {
            log.register("log");
        }catch(LuaException e){
            Log.d("lua", "could not register log function");
        }

    }

    public InputStream getStdOut() throws IOException{
        PipedInputStream inputStream = new PipedInputStream(1024);
        PipedOutputStream outputStream = new PipedOutputStream(inputStream);
        outputStreams.add(outputStream);
        return inputStream;
    }

    public void addAssets(final AssetManager am){
        synchronized (L) {
            JavaFunction assetLoader = new JavaFunction(L) {
            @Override
            public int execute() throws LuaException {
                String name = L.toString(-1);
                name = name.replace('.', '/');
                InputStream is;
                try {
                    try {
                        is = am.open(name + ".lua");
                    } catch (IOException e) {
                        is = am.open(name + "/init.lua");
                    }
                    byte[] bytes = readAll(is).getBytes();
                    L.LloadBuffer(bytes, name);
                    return 1;
                } catch (Exception e) {
                    ByteArrayOutputStream os = new ByteArrayOutputStream();
                    e.printStackTrace(new PrintStream(os));
                    L.pushString("Cannot load module "+name+":\n"+os.toString());
                    return 1;
                }
            }
        }; //might be OK outside synchronized block

            L.getGlobal("package");            // package
            L.getField(-1, "loaders");         // package loaders
            int nLoaders = L.objLen(-1);       // package loaders

            try {
                L.pushJavaFunction(assetLoader);   // package loaders loader
                L.rawSetI(-2, nLoaders + 1);       // package loaders
                L.pop(1);                          // package
            } catch (LuaException e) {
                Log.d("lua", e.getMessage());
            }
            L.pop(1);
        }
    }

    public String stash(LuaObject obj, String key){
        try {
            stash.setField(key, obj);
        } catch (LuaException e) {
            Log.d("lua", e.getMessage());
        }
        return key;
    }
    public LuaObject fetch(String key){
        LuaObject res=null;
        try {
            res = stash.getField(key);
        }catch(LuaException e){
            Log.d("lua", "fetching :" + key + ":" + e.getMessage());
        }
        return res;
    }
    public void releaseRef(int ref){
        L.LunRef(REGISTRYINDEX,ref);
    }
    public LuaObject objectFromReference(int ref){
        return LuaObject.fromReference(L, ref);
    }

    public void destroy(){
        Log.d("lua", "destroying lua state");
        L.close();
        L = null;
    }

    public void addPackagePath(String path){
        addPackagePath(path, packagePath.size()); //append by default. giving previous paths priority
    }
    public void addPackagePath(String path, int index){
        if(!packagePath.contains(path)) {
            packagePath.add(index, path);
            //generate a new package string..
            StringBuilder builder = new StringBuilder();
            for (int i = 0; i < packagePath.size(); i++) {
                builder.append(packagePath.get(i));
                builder.append("/?.lua;");
                builder.append(packagePath.get(i));
                builder.append("/?/init.lua;");
            }
            //now update the VM.
            LuaObject packageTable = getGlobal("package");
            try {
                packageTable.setField("path", builder.toString());
            } catch (LuaException e) {
                Log.d("lua", "could not set path:" + e.getMessage());
            }
        }
    }

    public LuaObject require(String name) {
        synchronized (L) {
            L.getGlobal("require");
            L.pushString(name);
            if (L.pcall(1, 1, 0) != 0) {
                Log.d("lua", "require " + L.toString(-1));
                return null;
            }
            return L.getLuaObject(-1);
        }
    }
    public LuaObject eval(String src, String chunkName) throws LuaException {
        int ok=0;
        String err = "?";
        synchronized (L) {
            L.setTop(0);
            ok = L.LloadBuffer(src.getBytes(), chunkName);
            if (ok == 0) {
                L.getGlobal("debug");
                L.getField(-1, "traceback");
                // stack is now -3 chunk -2 debug -1 traceback
                L.remove(-2);
                L.pushValue(-2);
                ok = L.pcall(0, 1, -2);
                if (ok == 0) {
                    return L.getLuaObject(-1);
                }
            }
            err = L.toString(-1);
        }
        throw new LuaException(LuaObject.errorReason(ok) + ": " + err);
    }
    public LuaObject eval(LuaObject func) throws LuaException {
        int ok=0;
        String err="?";
        synchronized (L) {
            L.setTop(0);
            L.pushObjectValue(func);
            L.getGlobal("debug");
            L.getField(-1, "traceback");
            // stack is now -3 func -2 debug -1 traceback
            L.remove(-2);
            L.pushValue(-2);
            ok = L.pcall(0, 1, -2);
            if (ok == 0) {
                return L.getLuaObject(-1);
            }
            err = L.toString(-1);
        }
        throw new LuaException(LuaObject.errorReason(ok) + ": " + err);
    }

    public LuaObject safeEval(LuaObject func){
        LuaObject res = null;
        try {
            res = eval(func);
        } catch(LuaException e) {
            Log.d("lua", e.getMessage()+"\n");
        }
        return res;

    }
    public LuaObject safeEval(String src,String chunkName) {
        LuaObject res = null;
        try {
            res = eval(src,chunkName);
        } catch(LuaException e) {
            Log.d("lua", e.getMessage()+"\n");
        }
        return res;
    }

    public void setGlobal(String name, Object value) {
        synchronized (L) {
            L.pushJavaObject(value);
            L.setGlobal(name);
        }
    }
    public LuaObject getGlobal(String name){
        synchronized (L) {
            L.getGlobal(name);
            LuaObject obj = L.getLuaObject(-1);
            L.pop(-1);
            return obj;
        }
    }

    private Object[] prependToArray(Object obj, Object[] args){
        Object[] newArgs = new Object[args.length+1];
        newArgs[0] = obj;
        for (int i=0; i<args.length; i++){
            newArgs[i+1] = args[i];
        }
        return newArgs;
    }
    public Object invokeMethod(LuaObject modTable, String name, Object... args) {

        if (modTable == null)
            return null;
        Object res = null;
        try {
            LuaObject f = ((LuaObject)modTable).getField(name);
            if (f.isNil())
                return null;
            res = f.call( prependToArray(modTable, args));
        } catch (Exception e) {
            Log.d("lua", "method "+name+": "+e.getMessage());
        }
        return res;
    }


    private static String readAll(InputStream input) throws Exception {
        ByteArrayOutputStream output = new ByteArrayOutputStream(4096);
        byte[] buffer = new byte[4096];
        int n = 0;
        while (-1 != (n = input.read(buffer))) {
            output.write(buffer, 0, n);
        }
        return output.toString();
    }


}
