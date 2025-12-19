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
    private const val VERSION = "1"
    private const val VERSION_FILE = ".ikemen_assets_version"

    // Copies the raw assets.zip to a destination file
    fun copyAssetsZip(context: Context, destFile: File) {
        try {
            context.assets.open(ASSETS_ZIP_NAME).use { input ->
                FileOutputStream(destFile).use { output ->
                    input.copyTo(output)
                }
            }
            Log.d(TAG, "Copied assets.zip backup to ${destFile.absolutePath}")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to copy assets.zip backup", e)
        }
    }

    fun ensureAssetsExtracted(context: Context, destDir: File) {
        val versionFile = File(destDir, VERSION_FILE)

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

        try {
            extractZipFromAssets(context, ASSETS_ZIP_NAME, destDir)
            versionFile.writeText(VERSION)
            Log.d(TAG, "Assets extracted successfully to ${destDir.absolutePath}")
        } catch (e: Exception) {
            Log.e(TAG, "FAILED to extract assets", e)
        }
    }

    private fun extractZipFromAssets(context: Context, assetName: String, destDir: File) {
        if (!destDir.exists()) destDir.mkdirs()
        
        try {
            context.assets.open(assetName).use { input ->
                ZipInputStream(input).use { zis ->
                    var entry = zis.nextEntry
                    val buffer = ByteArray(16 * 1024)

                    while (entry != null) {
                        val outFile = File(destDir, entry.name)
                        
                        // Zip Slip protection
                        if (!outFile.canonicalPath.startsWith(destDir.canonicalPath)) {
                            Log.e(TAG, "Security check failed for: ${entry.name}")
                            entry = zis.nextEntry
                            continue
                        }

                        if (entry.isDirectory) {
                            if (!outFile.isDirectory && !outFile.mkdirs()) {
                                Log.w(TAG, "Could not create directory: ${outFile.absolutePath}")
                            }
                        } else {
                            outFile.parentFile?.mkdirs()
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
        } catch (e: IOException) {
            throw e
        }
    }
}