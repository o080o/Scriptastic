package com.o080o.scriptastic;

import android.util.Log;

import org.keplerproject.luajava.LuaException;
import org.keplerproject.luajava.LuaObject;
import org.keplerproject.luajava.LuaState;
import org.keplerproject.luajava.LuaStateFactory;

/**
 * Created by o080o on 3/30/16.
 */

public class LuaVM {
    private LuaState L;
    public LuaVM(){
        newState();
    }

    public synchronized void newState() {
        L = LuaStateFactory.newLuaState();
        L.openLibs();
    }
    public synchronized void addPackagePath(String filesDir){
        try {
            L.getGlobal("package");            // package
            L.getField(-1, "path");            // package path
            String customPath = filesDir + "/?.lua;" + filesDir + "/?/init.lua";
            L.pushString(";" + customPath);    // package path custom
            L.concat(2);                       // package pathCustom
            L.setField(-2, "path");            // package
            L.pop(1);
            Log.d("lua", "appended search pachage path: " + filesDir);
        } catch (Exception e) {
            Log.d("lua", "Could not set package path: " + e.getMessage());
        }
    }
    public void destroy(){
        Log.d("lua", "destroying lua state");
        L.close();
        L = null;
    }
    public synchronized LuaObject eval(String src, String chunkName) throws LuaException {
        L.setTop(0);
        int ok = L.LloadBuffer(src.getBytes(),chunkName);
        if (ok == 0) {
            L.getGlobal("debug");
            L.getField(-1,"traceback");
            // stack is now -3 chunk -2 debug -1 traceback
            L.remove(-2);
            L.pushValue(-2);
            ok = L.pcall(0, 0, -2);
            if (ok == 0) {
                return L.getLuaObject(0);
            }
        }
        throw new LuaException(LuaObject.errorReason(ok) + ": " + L.toString(-1));
    }

    public synchronized LuaObject safeEval(String src,String chunkName) {
        LuaObject res = null;
        try {
            res = eval(src,chunkName);
        } catch(LuaException e) {
            Log.d("lua", e.getMessage()+"\n");
        }
        return res;
    }

    public synchronized void setGlobal(String name, Object value) {
        L.pushJavaObject(value);
        L.setGlobal(name);
    }

    public synchronized Object invokeMethod(Object modTable, String name, Object... args) {
        if (modTable == null)
            return null;
        Object res = null;
        try {
            LuaObject f = ((LuaObject)modTable).getField(name);
            if (f.isNil())
                return null;
            res = f.call(args);
        } catch (Exception e) {
            Log.d("lua", "method "+name+": "+e.getMessage());
        }
        return res;
    }



}
