package com.ikemenmobile

import android.content.Context
import android.util.Log
import java.io.File
import java.io.FileOutputStream
import java.io.IOException
import java.util.zip.ZipInputStream

object AssetsExtractor {
    private const val TAG = "AssetsExtractor"
    private const val ASSETS_ZIP_NAME = "assets.zip"
    // Bump this when you change what's inside the zip layout
    private const val VERSION = "1"
    private const val VERSION_FILE = ".ikemen_assets_version"

    fun ensureAssetsExtracted(context: Context) {
        // Same basePath as we pass into SDL/Go
        val baseDir = context.getExternalFilesDir(null) ?: context.filesDir
        val versionFile = File(baseDir, VERSION_FILE)

        try {
            if (versionFile.exists()) {
                val current = versionFile.readText().trim()
                if (current == VERSION) {
                    Log.d(TAG, "Assets already extracted (version=$current), skipping")
                    return
                } else {
                    Log.d(TAG, "Assets version mismatch (have=$current, want=$VERSION), re-extracting")
                }
            } else {
                Log.d(TAG, "No assets version file, extracting for the first time")
            }
        } catch (e: IOException) {
            Log.w(TAG, "Failed to read version file, will re-extract", e)
        }

        // Extract assets.zip into baseDir
        try {
            extractZipFromAssets(context, ASSETS_ZIP_NAME, baseDir)
            // Write / update version marker
            versionFile.writeText(VERSION)
            Log.d(TAG, "Assets extracted successfully to ${baseDir.absolutePath}")
        } catch (e: Exception) {
            Log.e(TAG, "FAILED to extract assets", e)
            // We don't throw here because SDL/Go will still start and give a useful error.
        }
    }

    private fun extractZipFromAssets(context: Context, assetName: String, destDir: File) {
        destDir.mkdirs()
        context.assets.open(assetName).use { input ->
            ZipInputStream(input).use { zis ->
                var entry = zis.nextEntry
                val buffer = ByteArray(16 * 1024)

                while (entry != null) {
                    val outFile = File(destDir, entry.name)
                    if (entry.isDirectory) {
                        if (!outFile.isDirectory && !outFile.mkdirs()) {
                            Log.w(TAG, "Could not create directory: ${outFile.absolutePath}")
                        }
                    } else {
                        outFile.parentFile?.let { parent ->
                            if (!parent.isDirectory && !parent.mkdirs()) {
                                Log.w(TAG, "Could not create parent dir: ${parent.absolutePath}")
                            }
                        }
                        FileOutputStream(outFile).use { fos ->
                            while (true) {
                                val read = zis.read(buffer)
                                if (read <= 0) break
                                fos.write(buffer, 0, read)
                            }
                        }
                    }
                    zis.closeEntry()
                    entry = zis.nextEntry
                }
            }
        }
    }
}