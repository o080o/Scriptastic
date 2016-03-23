package sk.kottman.androlua;

import android.os.AsyncTask;
import android.os.Handler;
import org.keplerproject.luajava.*;

class LuaTask extends AsyncTask<Object, Object, Object> {
	LuaThread t;
	
	public LuaTask(LuaThread t) {
		super();
		this.t = t;
	}
	@Override
	protected Object doInBackground(Object... targs) {		
		return t.loadAndRun(targs[0],targs[1]);
	}
	
	@Override
	protected void onProgressUpdate(Object... args) {
		t.callProgress(args);
	}
	
	@Override
	protected void onPostExecute(Object result) {
		t.callPost(result);
	}		
	
	public void setProgress(Object arg) {
		publishProgress(arg); 
	}
	
}

class LuaThreadImpl extends Thread {
	LuaThread t;
	Object mod, arg;
	Handler handler = new Handler();
	
	public LuaThreadImpl(LuaThread t) {
		super();
		this.t = t;
	}
	
	public void execute(Object... args) {
		mod = args[0];
		arg = args[1];
		start();
	}
	
	public void run() {
		final Object res = t.loadAndRun(mod, arg);
		handler.post(new Runnable() {
			public void run() {
				t.callPost(res);				
			}			
		});
	}
	
	public void setProgress(final Object arg) {
		handler.post(new Runnable() {
			public void run() {
				t.callProgress(arg);
			}
		});
	}
}

public class LuaThread {
	String err = null;
	LuaObject progress,post;	
	boolean wasNew;	
	LuaTask task = null;
	LuaThreadImpl thread = null;
	
	public LuaThread(LuaObject progress, LuaObject post, boolean threading) {
		super();
		this.progress = progress;
		this.post = post;
		if (threading) {
			thread = new LuaThreadImpl(this);
		} else {
			task = new LuaTask(this);
		}
	}
	
	public void execute(Object...args) {
		if (task != null)
			task.execute(args);
		else
			thread.execute(args);
	}
	
	public void setProgress(Object arg) {
		if (task != null)
			task.setProgress(arg);
		else
			thread.setProgress(arg);
	}	
	
	protected void callProgress(Object... args) {
		if (progress != null) try {
			progress.call(args);
		} catch (LuaException e) {
			Lua.log(e.getMessage());
		}	
	}
	
	protected void callPost(Object result) {
		if (post != null){
			try {		
				post.call(new Object[]{result,err});
			} catch (LuaException e) {
				Lua.log(e.getMessage());
			}
		} else if (err != null) {
			Lua.log(err);
		}
	}
	
	protected Object loadAndRun(Object mod, Object arg) {
		Object res;
		LuaState Lnew = Lua.newState(false);
		try {			
		    Lnew.getGlobal("require");
		    Lnew.pushString((String)mod);
		    if (Lnew.pcall(1, 1, 0) != 0) {
		    	err = Lnew.toString(-1);
		    	return null;
		    }
		    LuaObject run = Lnew.getLuaObject(-1);		    
		    if (! run.isFunction()) {
		    	err = "thread module must return function";
		    	return null;	    	
		    }
		    res = run.call(new Object[]{this,arg});
	    } catch (Exception e) {
	    	err = e.getMessage();
	    	return null;	    	
	    } finally {
	    	Lnew.close();
	    }		
	    return res;
		
	}
	




}
