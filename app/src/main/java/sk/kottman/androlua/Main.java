package sk.kottman.androlua;

import android.os.Bundle;

public class Main extends LuaActivity  {

	@Override
	public void onCreate(Bundle savedInstanceState) {
		setLuaModule("main");
		super.onCreate(savedInstanceState);
	}
	
}