package sk.kottman.androlua;

import org.keplerproject.luajava.*;

import android.view.View;
import android.view.ViewGroup;
import android.widget.BaseAdapter;

public class LuaListAdapter extends BaseAdapter {

	Lua lua;
	Object impl, mod;
	LuaState L;
	
	public LuaListAdapter(Lua l, Object mod, Object impl) {
		lua = l;
		L = Lua.L;
		this.impl = impl;
		this.mod = mod;
	}
	
	public void setTable(Object mod) {
		this.mod = mod;
		notifyDataSetChanged();
	}
	
	public Object getTable(Object mod) {
		return mod;
	}	

	public int getCount() {
		try {
			L.pushObjectValue(mod);
			int len = L.objLen(-1);
			L.pop(1);
			return len;
		} catch (LuaException e) {
			return 0;
		}		
	}

	public Object getItem(int position) {
		try {
			L.pushObjectValue(mod);
			L.pushInteger(position+1);
			L.getTable(-2);
			Object res = L.toJavaObject(-1);
			L.pop(1);  //2?
			return res;
		} catch (LuaException e) {
			return null;
		}	
	}

	public long getItemId(int position) {
		Object res = lua.invokeMethod(impl, "getItemId");
		return res != null ? (Long)res : position;		
	}

	public View getView(int position, View convertView, ViewGroup parent) {
		View v = (View)lua.invokeMethod(impl, "getView",impl,position,convertView,parent);
		if (v == null) { // oops an error in getView!
			v = parent;
			L.newTable();
			try {
				mod = L.toJavaObject(-1);
			} catch (LuaException e) {
				// TODO Auto-generated catch block
				e.printStackTrace();
			}
			L.pop(1);
			notifyDataSetChanged();
		}
		return v;
	}

}
