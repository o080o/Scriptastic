package com.o080o.scriptastic;

import android.app.Activity;
import android.content.ComponentName;
import android.content.Context;
import android.content.Intent;
import android.content.ServiceConnection;
import android.os.Bundle;
import android.os.IBinder;
import android.util.Log;
import android.view.ContextMenu;
import android.view.Menu;
import android.view.MenuItem;
import android.view.View;

import org.keplerproject.luajava.LuaException;
import org.keplerproject.luajava.LuaObject;

/**
 * Created by o080o on 3/30/16.
 */
public class LuaActivity extends Activity implements ServiceConnection{

    public LuaObject self;
    protected LuaVM lua;
    protected LuaService.LuaBinder binder;
    private String modName;
    private String modKey;
    private int objRef = LuaVM.NULLREF;
    private String objRefStr;

    /** Called when the activity is first created. */
    @Override
    public void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);

        Intent thisIntent = getIntent();
        modName = thisIntent.getStringExtra("LUA_MODNAME");
        modKey = thisIntent.getStringExtra("LUA_MODKEY");
        //objRef = thisIntent.getIntExtra("LUA_OBJREF", LuaVM.NULLREF);
        objRefStr = thisIntent.getStringExtra("LUA_OBJREF");    //lua can't find the right putExtra method for numbers. sometimes uses bytes instead.
        if (objRefStr!=null) {                                  // to avoid that, we will explicitly typecast to/from strings to avoid overloaded methods
            objRef = new Integer(objRefStr);
        }

        if(lua==null) { //should *always* happen
            Intent serviceIntent = new Intent(this, LuaService.class);
            bindService(serviceIntent, this, Context.BIND_AUTO_CREATE);
        }
    }

    @Override
    protected void onActivityResult(int request, int result, Intent data) {
        lua.invokeMethod(self, "onActivityResult", request, result, data);
    }

    @Override
    public void onPause() {
        super.onPause();
        if (lua != null){ lua.invokeMethod(self,"onPause"); }
    }

    @Override
    public void onResume() {
        super.onResume();
        if (lua != null){ lua.invokeMethod(self,"onResume"); }
    }

    @Override
    public void onStart() {
        super.onStart();
        if (lua != null){ lua.invokeMethod(self,"onStart"); }
    }
    @Override
    public void onSaveInstanceState(Bundle state) {
        super.onSaveInstanceState(state);
        if (lua != null){ lua.invokeMethod(self,"onSaveInstanceState", state); }
    }

    @Override
    public void onRestoreInstanceState(Bundle savedState) {
        if (lua != null){ lua.invokeMethod(self,"onRestoreInstanceState", savedState); }
    }

    @Override
    public void onStop() {
        super.onStop();
        if (lua != null){ lua.invokeMethod(self,"onStop"); }
    }

    @Override
    public void onDestroy() {
        super.onDestroy();
        if (lua != null){ lua.invokeMethod(self, "onDestroy"); }
        unbindService(this);
    }

    @Override
    public boolean onCreateOptionsMenu(Menu menu) {
        Object res = null;
        if (lua != null){
            res = lua.invokeMethod(self,"onCreateOptionsMenu", menu);
        }
        if (res == null) {
            return false;
        } else {
            return true;
        }
    }

    @Override
    public boolean onOptionsItemSelected(MenuItem item) {
        Object res = null;
        if (lua != null) {
            res = lua.invokeMethod(self, "onOptionsItemSelected", item);
        }

        if (res == null) {
            return super.onOptionsItemSelected(item);
        } else {
            return true;
        }
    }

    @Override
    public void onCreateContextMenu(ContextMenu menu, View v, ContextMenu.ContextMenuInfo menuInfo){
        super.onCreateContextMenu(menu, v, menuInfo);
        if (lua != null){ lua.invokeMethod(self,"onCreateContextMenu", menu, v, menuInfo); }
    }

    @Override
    public boolean onContextItemSelected(MenuItem item) {

        Object res = null;
        if (lua != null) {
            res = lua.invokeMethod(self, "onContextItemSelected", item);
        }

        if (res == null) {
            return super.onContextItemSelected(item);
        } else {
            return true;
        }

    }

    public void onServiceConnected(ComponentName name, IBinder iservice) {
        binder = (LuaService.LuaBinder)iservice;
        lua = binder.getLuaVM();

        Log.d("LuaActivity", "LuaActivity connected");
        if (modKey!=null){
            Log.d("LuaActivity", modKey);
            self = lua.fetch(modKey);
            Log.d("LuaActivity", self.toString());
        }
        if (modName!=null){
            Log.d("LuaActivity", modName);
            self = lua.safeEval("return require'" + modName + "'", "tmp");
        }
        if (objRef!=LuaVM.NULLREF){
            Log.d("LuaActivity", new Integer(objRef).toString());
            self = lua.objectFromReference(objRef);
            lua.releaseRef(objRef);
        }
        setSelf(self);
    }

    public void onServiceDisconnected(ComponentName name) {
        this.lua = null;
    }

    public void setSelf(LuaObject newSelf){
        self = newSelf;
        if (self==null){
            Log.d("lua", "Can't use nil value as a LuaActivity");
            return;
        }
        if (lua==null){
            Log.d("lua", "Can't set self of LuaActivity before LuaService connected");
            return;
        }

        try {
            //self.setField("activity", this);
            self.setField("service", binder);
        }catch (LuaException e){Log.d("lua", "could not set fields of 'self':" + e.getMessage());}

        Object view = lua.invokeMethod(self, "onCreate", this);
        if (view instanceof View) {
            setContentView((View) view);
        } else {
            //what do we do??
            Log.d("lua", "onCreate must return a View");
            finish();
            return;
        }

        lua.invokeMethod(self, "onStart");
        lua.invokeMethod(self, "onResume");
    }

}
