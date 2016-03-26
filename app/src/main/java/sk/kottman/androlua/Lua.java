package sk.kottman.androlua;

import android.app.Activity;
import android.app.Notification;
import android.app.Service;
import android.content.Context;
import android.content.Intent;
import android.content.ServiceConnection;
import android.content.res.AssetManager;
import android.graphics.BitmapFactory;
import android.os.Binder;
import android.os.Handler;
import android.os.IBinder;
import android.os.StrictMode;
import android.support.v4.app.NotificationCompat;
import android.util.Log;
import android.widget.Toast;

import java.io.*;
import java.net.*;

import org.keplerproject.luajava.*;

public class Lua extends Service {
	private final static int LISTEN_PORT = 3333, PRINT_PORT = 3334;
	private final static char REPLACE = '\001';
	public static LuaState L = null;
	static boolean printToString = true;
	static PrintWriter printer = null;
	static Lua main_instance = null;
	
	static final StringBuilder output = new StringBuilder();

	Handler handler;
	static ServerThread serverThread;
	
	// the binder just returns this service...
	public class LocalBinder extends Binder {
		public Lua getService() {
			return Lua.this;
		}
	}
	
	private final IBinder binder = new LocalBinder();	

	public static LuaState newState(boolean startServer) {
		LuaState L = LuaStateFactory.newLuaState();
		L.openLibs();
		try {
			JavaFunction print = new JavaFunction(L) {
				@Override
				public int execute() throws LuaException {
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
					
					synchronized (L) {
						String out = output.toString();
						if (! printToString && printer != null) {
							printer.println(out + REPLACE);
							printer.flush();
							output.setLength(0);						
						}
					}					
					return 0;
				}
			};
			
			final AssetManager am = main_instance.getAssets();
			
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
						byte[] bytes = readAll(is);
						L.LloadBuffer(bytes, name);
						return 1;
					} catch (Exception e) {
						ByteArrayOutputStream os = new ByteArrayOutputStream();
						e.printStackTrace(new PrintStream(os));
						L.pushString("Cannot load module "+name+":\n"+os.toString());
						return 1;
					}
				}
			};
			
			print.register("print");

			L.getGlobal("package");            // package
			L.getField(-1, "loaders");         // package loaders
			int nLoaders = L.objLen(-1);       // package loaders
			
			L.pushJavaFunction(assetLoader);   // package loaders loader
			L.rawSetI(-2, nLoaders + 1);       // package loaders
			L.pop(1);                          // package
						
			L.getField(-1, "path");            // package path
			String filesDir = main_instance.getFilesDir().toString();
			String customPath = filesDir+"/?.lua;"+filesDir+"/?/init.lua";
			L.pushString(";" + customPath);    // package path custom
			L.concat(2);                       // package pathCustom
			L.setField(-2, "path");            // package
			L.pop(1);
		} catch (Exception e) {
			Log.d("lua","Cannot override print "+e.getMessage());
		}			
		
		if (startServer) {
			serverThread = main_instance.new ServerThread();
			serverThread.start();
		}
		
		return L;
	}

	
	@Override
	public int onStartCommand (Intent intent, int flags, int startid) {
		handler = new Handler();
		StrictMode.setThreadPolicy(StrictMode.ThreadPolicy.LAX);
		log("starting Lua service");
		boolean start_tcpserver = intent.getBooleanExtra("LUA_START_TCP", false);
		if (L == null) {
			main_instance = this;
			L = newState(start_tcpserver);
			setGlobal("service", this);

			String src = intent.getStringExtra("LUA_INITCODE");
			if (src != null) {
				safeEvalLua(src, "init");
			}
		}

		String title = intent.getStringExtra("LUA_SERVICE_TITLE");
		if (title==null) {
			title=getPackageName();
		}

		int icon = intent.getIntExtra("LUA_SERVICE_ICON", 0);
		int largeIcon = intent.getIntExtra("LUA_SERVICE_LARGE_ICON", 0);
		String content;
		if (serverThread==null){
			content = "lua service running";
		}else{
			content = "lua service running (port "+LISTEN_PORT+")";
		}

		NotificationCompat.Builder builder = new NotificationCompat.Builder(this);
		builder.setContentTitle(title);
		builder.setContentText(content);
		builder.setSmallIcon(icon);
		builder.setLargeIcon(BitmapFactory.decodeResource(getResources(), largeIcon, new BitmapFactory.Options()));


		Notification notification = new NotificationCompat.Builder(this)
				.setContentTitle(title)
				.setContentText(content)
				.setSmallIcon(icon)
				.build();
		startForeground(5, notification);
		
		return START_REDELIVER_INTENT;
	}

	// currently this is just so that the main activity knows when the service is up...
	// will support a remote script running option
	@Override
	public IBinder onBind(Intent intent) {
		return binder; 
	}

	public void restartLuaState(){
		L = newState(false);
		setGlobal("service",this);
	}
	public void launchLuaActivity(Context context, String mod, Object arg) {
		boolean fromActivity = context != null;
		if (! fromActivity) {
			context = this;
		}		
		Intent intent = new Intent(context, LuaActivity.class);
		
		if (! fromActivity) {
			intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
			intent.addFlags(Intent.FLAG_ACTIVITY_MULTIPLE_TASK);
		}
		
		intent.putExtra("LUA_MODULE", mod);
		if (arg != null) {
			try {
				L.pushObjectValue(arg);
			} catch (LuaException e) {
				log("cannot pass this value to activity");
				return;
			}
			LuaObject lobj = new LuaObject(L,-1);
			intent.putExtra("LUA_MODULE_ARG", lobj.getRef());
		}
		context.startActivity(intent);
	}
	
	public Object launchLuaView(Context context, Object o) {
		return new LuaView(context,this,o);
	}
	
	public Object createLuaListAdapter(Object me, Object o) {
		return new LuaListAdapter(this,me,o);
	}
	
	public boolean createLuaThread(String mod, Object arg, Object progress, Object post) {
		if (progress != null && ! (progress instanceof LuaObject))
			return false;
		if (post != null && ! (post instanceof LuaObject))
			return false;
		new LuaThread((LuaObject)progress,(LuaObject)post,false).execute(mod,arg);
		return true;
	}	
	
	@Override
	public void onDestroy() {
		super.onDestroy();
		log("destroying Lua service");
		serverThread.close(); 
		L.close();
		L = null;
	}
	
	public static void log(String msg) {
		if (printer != null) {
			printer.println(msg + REPLACE);
			printer.flush();
			Log.d("lua",msg);
		} else {
			Log.d("lua",msg);
		}
	}
	
	public String evalLua(String src, String chunkName) throws LuaException {
		L.setTop(0);
		int ok = L.LloadBuffer(src.getBytes(),chunkName);
		if (ok == 0) {
			L.getGlobal("debug");
			L.getField(-1,"traceback");
			// stack is now -3 chunk -2 debug -1 traceback
			L.remove(-2);
			L.pushValue(-2);			
			printToString = true;
			ok = L.pcall(0, 0, -2);
			printToString = false;
			if (ok == 0) {
				String res = output.toString();
				output.setLength(0);
				return res;
			}
		}		
		throw new LuaException(LuaObject.errorReason(ok) + ": " + L.toString(-1));
	}	
	
	public void setGlobal(String name, Object value) {
		L.pushJavaObject(value);
		L.setGlobal(name); 
	}
	
	public LuaObject require(String mod) {
	    L.getGlobal("require");
	    L.pushString(mod);
	    if (L.pcall(1, 1, 0) != 0) {
	    	log("require "+L.toString(-1));
	    	return null;
	    }
	    return L.getLuaObject(-1);		
	}
	
	public static void bind(Activity a, ServiceConnection sc) {
		Intent luaIntent = new Intent(a,Lua.class);
		//ComponentName name = a.startService(luaIntent);
		//if (name == null) {
		//	Log.d("lua","unable to start Lua service!");
		//} else {
		//	Log.d("lua","started service " + name.toString());
			a.bindService(luaIntent,sc,BIND_AUTO_CREATE);
		//}
		
	}
	
	public static void unbind(Activity a, ServiceConnection sc) {
		//Intent luaIntent = new Intent(a,Lua.class);
		//a.stopService(luaIntent);
		a.unbindService(sc);		
	}
	
	public Object invokeMethod(Object modTable, String name, Object... args) {
		if (modTable == null)
			return null;
		Object res = null;
	    try {
			LuaObject f = ((LuaObject)modTable).getField(name);
			if (f.isNil())
				return null;
			res = f.call(args);
		} catch (Exception e) {
			log("method "+name+": "+e.getMessage());
		}		
		return res;
	}	
	
	public String safeEvalLua(String src,String chunkName) {
		String res = null;	
		try {
			res = evalLua(src,chunkName);
		} catch(LuaException e) {
			res = e.getMessage()+"\n";
		}
		return res;		
	}
	
	private class ServerThread extends Thread {
		public boolean stopped;
		public Socket client, writer;
		public ServerSocket server, writeServer;

		@Override
		public void run() {
			stopped = false;
			try {
				server = new ServerSocket(LISTEN_PORT);
				writeServer = new ServerSocket(PRINT_PORT);
				log("Server started on port " + LISTEN_PORT);
				while (!stopped) {
					client = server.accept();					
					Log.d("client", "client accepted");

					handler.post(new Runnable() {
						public void run() {

							Toast.makeText(main_instance, main_instance.getPackageName() + ":\n\tclient connected",
									Toast.LENGTH_LONG).show();
							/*
							String res = safeEvalLua(s, chunkName);
							res = res.replace('\n', REPLACE);
							out.println(res);
							out.flush();
							*/
						}
					});


					BufferedReader in = new BufferedReader(
							new InputStreamReader(client.getInputStream()));
					final PrintWriter out = new PrintWriter(client.getOutputStream());
					String line = in.readLine();
					if (line.equals("yes")) { // async output goes to 3334						
						out.println("waiting ");
						out.flush();						
						writer = writeServer.accept();
						printer = new PrintWriter(writer.getOutputStream());
					} else if (line.equals("combine")) { // _all_ output goes to 3333!
						printer = out;
						writer = null;
					} else {
						writer = null;
						printer = null;
					}
					while (!stopped && (line = in.readLine()) != null) {						
						final String s = line.replace(REPLACE, '\n');
						if (s.startsWith("--mod:")) {
							String mod = extractLuaFilename(s); 
							String file = getFilesDir()+"/"+mod.replace('.', '/')+".lua";
							File path = new File(file).getParentFile();
							path.mkdirs();
							if (mod.endsWith(".init")) {
								mod = mod.substring(0,mod.indexOf(".init"));
							}
							FileWriter fw = new FileWriter(file);
							fw.write(s);
							fw.close();	 
							// package.loaded[mod] = nil
							L.getGlobal("package");
							L.getField(-1, "loaded");
							L.pushNil();
							L.setField(-2, mod);
							out.println("wrote " + file + REPLACE);
							out.flush();
						} else {
							String name = "tmp";
							if (s.startsWith("--run:")){
								name = extractLuaFilename(s);
							}
							final String chunkName = name;
							handler.post(new Runnable() {
								public void run() {
									String res = safeEvalLua(s,chunkName);
									res = res.replace('\n', REPLACE);
									out.println(res);
									out.flush();
								}
							});
						}
					}
					client.close();
					if (writer != null)
						writer.close();
				}
				server.close();
				writeServer.close();
				server = null;
				writeServer = null;
			} catch (Exception e) {
				Log.d("client","server "+e.toString());
				log(e.toString());
			}
		}
		
		private String extractLuaFilename(String s) {
			int i1 = s.indexOf(':'), i2 = s.indexOf('\n'); 
			return s.substring(i1+1,i2); 
		}

		public void close() {
			try {
				if (client != null)
					client.close();
				if (writer != null)
					writer.close();
				server.close();
				writeServer.close();
			} catch(Exception e) {
				log("problem closing sockets " + e);
			}
		}
	}
	
	private static byte[] readAll(InputStream input) throws Exception {
		ByteArrayOutputStream output = new ByteArrayOutputStream(4096);
		byte[] buffer = new byte[4096]; 
		int n = 0;
		while (-1 != (n = input.read(buffer))) {
			output.write(buffer, 0, n);
		}
		return output.toByteArray();
	}	
	

}
