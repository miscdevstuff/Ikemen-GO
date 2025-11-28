package com.ikemenmobile

import android.os.Bundle
import android.view.View
import android.widget.FrameLayout
import androidx.activity.ComponentActivity

class MainActivity : ComponentActivity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // Simple blank container so the Activity is valid.
        val root = FrameLayout(this).apply {
            id = View.generateViewId()
        }
        setContentView(root)

        // Decide where Ikemen should use as its "base" path.
        // For now, something under app's private storage:
        val basePath = getExternalFilesDir(null)?.absolutePath
            ?: filesDir.absolutePath

        // Start Ikemen on a background thread so we don't block the UI thread.
        Thread {
            try {
                IkemenNative.runIkemen(basePath)
            } catch (t: Throwable) {
                t.printStackTrace()
                // You can also log to Logcat if you want:
                // Log.e("IkemenNative", "Ikemen crashed", t)
            }
        }.start()
    }
}
