package com.o080o.scriptastic;

import android.app.Activity;
import android.content.Intent;
import android.nfc.NfcAdapter;
import android.nfc.Tag;
import android.util.Log;

import org.keplerproject.luajava.LuaObject;

import java.util.ArrayList;

/**
 * Created by o080o on 12/29/16.
 * TODO use <activity-alias> to dynamically disable this activity using PackageManager when there are no subscribers
 * ( which would allow other apps to have free access to nfc otherwise)
 */
public class NfcReceiver extends Activity {
    public static ArrayList<LuaObject> subscribers = new ArrayList<LuaObject>();
    @Override
    public void onResume() {
        super.onResume();
        Intent intent = getIntent();
        Tag tag = intent.getParcelableExtra(NfcAdapter.EXTRA_TAG);
        //fire off some lua function to deal with this....
        for(LuaObject func : subscribers){
            try {
                func.call(new Object[]{this, tag, intent});
            }catch(Exception e){
                Log.d("scriptastic", e.toString() + e.getMessage());
            }
        }
        finish();
    }
}
