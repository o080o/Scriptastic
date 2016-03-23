package sk.kottman.androlua;

import android.content.Context;
import android.view.MotionEvent;
import android.view.View;
import android.view.View.OnClickListener;
import android.graphics.Canvas;

public class LuaView extends View { 
	Lua service;
	Object modTable;	
	
	public LuaView(Context c, Lua lc, Object mod) {
		super(c);
		service = lc;
		modTable = mod;
	}
	
	@Override
	public void onDraw(Canvas canvas) {
		service.invokeMethod(modTable, "onDraw", canvas);
	}
	
	@Override
	public boolean onTouchEvent(MotionEvent ev) {
		Object res = service.invokeMethod(modTable, "onTouchEvent", ev);
		return res != null ? (Boolean)res : super.onTouchEvent(ev);
	}	
		
	@Override
	public void onSizeChanged(int w, int h, int oldw, int oldh) {
		service.invokeMethod(modTable, "onSizeChanged", w,h,oldw,oldh);
	}
	
	@Override
	public void onMeasure(int wspec, int hspec) {
		Object res = service.invokeMethod(modTable, "onMeasure", wspec,hspec);
		if (res == null)
			super.onMeasure(wspec, hspec);
			
	}
	
	public void measuredDimension(int w, int h) {
		setMeasuredDimension(w,h);
	}
	 

}
