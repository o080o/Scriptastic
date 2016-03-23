package sk.kottman.androlua;

import android.app.Activity;

import android.content.ComponentName;
import android.content.Intent;
import android.content.ServiceConnection;
import android.os.Bundle;
import android.os.IBinder;
import android.util.Log;
import android.view.ContextMenu;
import android.view.ContextMenu.ContextMenuInfo;
import android.view.Menu;
import android.view.MenuItem;
import android.view.View;

import org.keplerproject.luajava.*;

public class LuaActivity extends Activity implements ServiceConnection {
	Lua service;
	String modName = null;
	LuaObject modTable;
	int argRef = 0;
	Bundle state;

	/** Called when the activity is first created. */
	@Override
	public void onCreate(Bundle savedInstanceState) {
	    super.onCreate(savedInstanceState);
	    state = savedInstanceState;
	    Intent intent = getIntent();
	    modName = intent.getStringExtra("LUA_MODULE");
	    argRef = intent.getIntExtra("LUA_MODULE_ARG", 0);
		Lua.bind(this, this);	    
	}
	
	protected void setLuaModule(CharSequence mod) {
		getIntent().putExtra("LUA_MODULE", mod);
	}
	
	@Override
	protected void onActivityResult(int request, int result, Intent data) {
		service.invokeMethod(modTable,"onActivityResult",request,result,data);
	}
	
	@Override
	public void onPause() {
		super.onPause();
		service.invokeMethod(modTable,"onPause");
	}
	
	@Override
	public void onResume() {
		super.onResume();
		if (service != null)
			service.invokeMethod(modTable,"onResume");
	}
	
	@Override
	public void onStart() {
		super.onStart();		
		if (service != null)
			service.invokeMethod(modTable,"onStart");
	}
	@Override
	public void onSaveInstanceState(Bundle outState) {
		super.onSaveInstanceState(outState);
		if (service != null)
			service.invokeMethod(modTable, "onSaveInstanceState", outState);
	}
	
	@Override
	public void onRestoreInstanceState(Bundle savedState) {

	}
	
	@Override
	public void onStop() {
		super.onStop();
		service.invokeMethod(modTable,"onStop");
	}
	
	@Override
	public void onDestroy() {
		super.onDestroy();
		service.invokeMethod(modTable,"onDestroy");
		Lua.unbind(this,this);
	}
	@Override
	public boolean onCreateOptionsMenu(Menu menu) {
		Object res = service.invokeMethod(modTable, "onCreateOptionsMenu", menu);
		return res != null ? (Boolean)res : false;
	}
	
	@Override
	public boolean onOptionsItemSelected(MenuItem item) {
		Object res = service.invokeMethod(modTable, "onOptionsItemSelected", item);
		if (res == null) {
			return super.onOptionsItemSelected(item);
		} else {
			return true;
		}
	}
	
	@Override
	public void onCreateContextMenu(ContextMenu menu, View v,
	                                ContextMenuInfo menuInfo) {
	    super.onCreateContextMenu(menu, v, menuInfo);
	    service.invokeMethod(modTable, "onCreateContextMenu", menu,v,menuInfo);
	}	
	
	@Override
	public boolean onContextItemSelected(MenuItem item) {
		Object res = service.invokeMethod(modTable, "onContextItemSelected", item);
		if (res != null) {
	       return super.onContextItemSelected(item);
		} else {
			return true;
		}
	}	
	
	public void log(String msg) {
		Lua.log(msg);
	}
	
	public void onServiceConnected(ComponentName name, IBinder iservice) {
		Log.d("lua","setting activity");		
		service = ((Lua.LocalBinder)iservice).getService();
		modTable = service.require(modName);
		if (modTable == null) {
			finish();
			return;
		}
	    
	    //service.setGlobal("current_activity",this);
	    
	    Object res;
	    Object arg = null;
	    if (argRef != 0) {
	    	arg = LuaObject.fromReference(Lua.L,argRef);
	    }
	    try {
		    if (modTable.isFunction()) {	    
		    	LuaObject android = service.require("android");
		    	LuaObject aNew = android.getField("new");
		    	res = aNew.call(new Object[]{modTable});
		    	modTable = (LuaObject)res;
		    }
		    res = service.invokeMethod(modTable,"onCreate",this,arg,state);		    
		} catch (LuaException e) {
			log("onCreate "+e.getMessage());
			res = null;
		}	    
	    if (res == null) {
	    	finish();
	    	return;
	    }
	    if (res instanceof View) {
	    	setContentView((View)res);
	    } else if (! (res instanceof Boolean)){
	    	log("onCreate must return a View");
	    	finish();
	    	return;
	    }	    		
	    
	    service.invokeMethod(modTable,"onStart");
	    if (state != null) {
			super.onRestoreInstanceState(state);
	    }
	    service.invokeMethod(modTable,"onResume");
		
	}

	public void onServiceDisconnected(ComponentName name) {
		// Really should not be called!
		this.service = null;
		
	}	

}
