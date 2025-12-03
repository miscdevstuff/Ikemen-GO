package org.libsdl.app;

import android.app.Activity;
import android.content.Context;
import android.os.Environment;
import android.util.Log;

import java.io.File;
import java.io.FileWriter;
import java.io.IOException;
import java.io.PrintWriter;

public class SDLActivityDebug extends SDLActivity {

    private static final String TAG = "Ikemen_Debug";

    @Override
    protected void onStart() {
        super.onStart();
        Log.i(TAG, "SDLActivityDebug: onStart()");
    }

    @Override
    protected void onResume() {
        super.onResume();
        Log.i(TAG, "SDLActivityDebug: onResume()");
    }

    @Override
    public void onNativeSurfaceCreated() {
        Log.i(TAG, "NativeSurfaceCreated");
        super.onNativeSurfaceCreated();
    }

    @Override
    public void onNativeSurfaceChanged() {
        Log.i(TAG, "NativeSurfaceChanged");
        super.onNativeSurfaceChanged();
    }

    @Override
    public void onNativeSurfaceDestroyed() {
        Log.w(TAG, "NativeSurfaceDestroyed");
        super.onNativeSurfaceDestroyed();
    }

    @Override
    public void onBackPressed() {
        Log.i(TAG, "onBackPressed()");
        super.onBackPressed();
    }

    // Write crash logs to /sdcard/IkemenMobile/debug/log.txt
    public static void writeCrashLog(String msg) {
        try {
            File dir = new File("/sdcard/IkemenMobile/debug");
            if (!dir.exists()) dir.mkdirs();

            File logfile = new File(dir, "log.txt");
            FileWriter fw = new FileWriter(logfile, true);
            fw.write("=== Crash ===\n" + msg + "\n\n");
            fw.close();

            Log.e(TAG, "Crash logged to: " + logfile.getAbsolutePath());
        } catch (IOException e) {
            Log.e(TAG, "Failed writing crash log", e);
        }
    }

    public static void logException(Throwable t) {
        StringBuilder sb = new StringBuilder();
        sb.append(t.toString()).append("\n");
        for (StackTraceElement el : t.getStackTrace()) {
            sb.append("  at ").append(el.toString()).append("\n");
        }
        writeCrashLog(sb.toString());
    }
}