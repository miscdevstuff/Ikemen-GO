package com.ikemenmobile

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.Environment
import android.provider.Settings
import android.system.Os
import android.util.Log
import android.view.ViewGroup
import android.widget.Toast
import org.libsdl.app.SDLActivity
import java.io.File
import android.content.Context

// UI Imports
import android.view.ContextThemeWrapper
import android.view.Gravity
import android.view.View
import android.widget.FrameLayout
import android.widget.PopupMenu
import androidx.appcompat.widget.AppCompatButton

class MainActivity : SDLActivity() {

    private lateinit var virtualPad: VirtualGamepadLayout
    private val TAG = "IkemenMainActivity"

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState) // SDL init

        // 1. Check Permissions
        if (!hasStoragePermission()) {
            requestStoragePermission()
            Toast.makeText(this, "Please grant Storage Access to run the game.", Toast.LENGTH_LONG).show()
            return
        }

        // 2. Setup Base Path
        setupEnvironment()
    }

    private fun hasStoragePermission(): Boolean {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            return Environment.isExternalStorageManager()
        }
        return true
    }

    private fun requestStoragePermission() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            try {
                val intent = Intent(Settings.ACTION_MANAGE_APP_ALL_FILES_ACCESS_PERMISSION)
                intent.data = Uri.parse("package:$packageName")
                startActivity(intent)
            } catch (e: Exception) {
                val intent = Intent(Settings.ACTION_MANAGE_ALL_FILES_ACCESS_PERMISSION)
                startActivity(intent)
            }
        }
    }

    private fun setupEnvironment() {
        try {
            // Define Base Path: /storage/emulated/0/IkemenMobile
            val rootDir = File(Environment.getExternalStorageDirectory(), "IkemenMobile")
            if (!rootDir.exists()) {
                rootDir.mkdirs()
            }

            // Define Tmp Path
            val tmpDir = File(rootDir, "tmp")
            if (!tmpDir.exists()) {
                tmpDir.mkdirs()
            }

            // --- Backup Logic (Install / Update / Missing) ---
            val backupZip = File(rootDir, "assets.zip")

            // Get current app version code
            val pInfo = packageManager.getPackageInfo(packageName, 0)
            val currentVersion = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                pInfo.longVersionCode
            } else {
                @Suppress("DEPRECATION")
                pInfo.versionCode.toLong()
            }

            // Get last saved version code
            val prefs = getSharedPreferences("IkemenPrefs", Context.MODE_PRIVATE)
            val lastVersion = prefs.getLong("assets_zip_version", -1)

            // Condition: File missing OR App Updated (Version mismatch)
            if (!backupZip.exists() || currentVersion != lastVersion) {
                Log.i(TAG, "New version detected ($currentVersion) or zip missing. Updating assets.zip...")

                // Run in background to prevent ANR/Freeze
                Thread {
                    try {
                        AssetsExtractor.copyAssetsZip(this, backupZip)
                        // Save the new version so we don't do this next time
                        prefs.edit().putLong("assets_zip_version", currentVersion).apply()
                        Log.i(TAG, "assets.zip updated successfully.")
                    } catch (e: Exception) {
                        Log.e(TAG, "Failed to update assets.zip", e)
                    }
                }.start()
            } else {
                Log.i(TAG, "assets.zip is up to date. Skipping copy.")
            }

            // --- Extraction Logic (First Run/Game missing (Check system.def)) ---
            // Extract if game missing
            val systemDef = File(rootDir, "data/system.def")
            if (!systemDef.exists()) {
                Log.i(TAG, "No game found. Extracting initial assets...")
                // This runs on main thread because we need it to play
                AssetsExtractor.ensureAssetsExtracted(this, rootDir)
            }

            // Export Environment Variables for Go
            Os.setenv("IKEMEN_PATH", rootDir.absolutePath, true)
            Os.setenv("TMPDIR", tmpDir.absolutePath, true)
            
            // Performance tuning
            Os.setenv("GOGC", "200", true)

            Log.v(TAG, "Env Init: ROOT=${rootDir.absolutePath} TMP=${tmpDir.absolutePath}")

            // UI Setup
            setupUI()

        } catch (e: Exception) {
            Log.e(TAG, "Failed to setup environment", e)
        }
    }

    private fun setupUI() {
        requestedOrientation = android.content.pm.ActivityInfo.SCREEN_ORIENTATION_SENSOR_LANDSCAPE
        val root = window.decorView.findViewById<ViewGroup>(android.R.id.content)
        
        virtualPad = VirtualGamepadLayout(this)
        root.addView(virtualPad, ViewGroup.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT))
        
        setupMenuButton(root)
    }

    private fun setupMenuButton(root: ViewGroup) {
        val themedCtx = ContextThemeWrapper(this, R.style.VirtualPadMenuButton)
        val menuButton = AppCompatButton(themedCtx, null, 0).apply {
            text = "≡"
            textSize = 16f
            alpha = 0.9f
            val density = resources.displayMetrics.density
            val size = (40f * density).toInt()
            val margin = (16f * density).toInt()
            layoutParams = FrameLayout.LayoutParams(size, size, Gravity.TOP or Gravity.START).apply {
                setMargins(margin, margin, margin, margin)
            }
            setOnClickListener { showGamepadMenu(this) }
        }
        root.addView(menuButton)
    }

    private fun showGamepadMenu(anchor: View) {
        val popup = PopupMenu(this, anchor)
        popup.menu.add(0, 1, 0, "Toggle gamepad")
        popup.menu.add(0, 2, 1, "Import gamepad layout (stub)")
        popup.setOnMenuItemClickListener { item ->
            when (item.itemId) {
                1 -> {
                    virtualPad.visibility = if (virtualPad.visibility == View.VISIBLE) View.GONE else View.VISIBLE
                    true
                }
                2 -> {
                    Log.d(TAG, "Import gamepad layout – not implemented yet")
                    true
                }
                else -> false
            }
        }
        popup.show()
    }

    override fun onResume() {
        super.onResume()
        if (hasStoragePermission() && System.getenv("IKEMEN_PATH") == null) {
             setupEnvironment()
        }
    }
    
    override fun onConfigurationChanged(newConfig: android.content.res.Configuration) {
        super.onConfigurationChanged(newConfig)
        requestedOrientation = android.content.pm.ActivityInfo.SCREEN_ORIENTATION_SENSOR_LANDSCAPE
    }

    override fun getLibraries(): Array<String> {
        return arrayOf("ikemen")
    }
}
