package com.ikemenmobile

import android.os.Bundle
import android.util.Log
import android.view.View
import android.widget.FrameLayout
import androidx.activity.ComponentActivity

class MainActivity : ComponentActivity() {

    companion object {
        private const val TAG = "IkemenMainActivity"
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        Log.d(TAG, "onCreate() called")

        // Simple blank container so the Activity is valid.
        val root = FrameLayout(this).apply {
            id = View.generateViewId()
        }
        setContentView(root)
        Log.d(TAG, "Root FrameLayout set as content view")

        // Decide where Ikemen should use as its "base" path.
        val basePath = getExternalFilesDir(null)?.absolutePath
            ?: filesDir.absolutePath
        Log.d(TAG, "Computed basePath: $basePath")

        // Start Ikemen on a background thread so we don't block the UI thread.
        Thread {
            Log.d(TAG, "Ikemen thread started, calling IkemenNative.runIkemen()")
            try {
                Log.d("IkemenNative", "Launching Ikemen with basePath=$basePath")
                IkemenNative.runIkemen(basePath)
                Log.d(TAG, "IkemenNative.runIkemen() returned normally")
            } catch (t: Throwable) {
                Log.e(TAG, "IkemenNative.runIkemen() threw", t)
                t.printStackTrace()
            }
            Log.d(TAG, "Ikemen thread exiting")
        }.start()
    }
}