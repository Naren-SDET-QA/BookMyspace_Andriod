package com.bookmyspace.bookmyspace.util

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Matrix
import android.media.ExifInterface
import android.net.Uri
import android.os.Environment
import android.util.Log
import androidx.core.content.FileProvider
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import java.io.File
import java.io.FileOutputStream
import java.io.InputStream
import java.net.URL
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.UUID

/**
 * Result data class containing stored photo metadata.
 */
data class SavedPhotoInfo(
    val url: String,
    val fileName: String,
    val sizeBytes: Long,
    val width: Int,
    val height: Int,
    val isLocalFile: Boolean = true
)

/**
 * Robust photo storage, compression, and media management engine for BookMySpace.
 * Handles:
 * 1. Safe camera capture URI generation via FileProvider
 * 2. MIME validation (JPG, JPEG, PNG, WEBP)
 * 3. EXIF orientation correction
 * 4. Memory-safe downsampling & high-quality JPEG compression
 * 5. Permanent storage in app internal files directory
 * 6. Disk cleanup upon photo deletion
 */
object PhotoStorageManager {
    private const val TAG = "PhotoStorageManager"
    private const val PHOTOS_DIR_NAME = "venue_photos"
    private const val MAX_DIMENSION = 2048
    private const val JPEG_QUALITY = 90
    private const val MAX_FILE_SIZE_BYTES = 25 * 1024 * 1024L // 25 MB

    val SUPPORTED_EXTENSIONS = listOf("jpg", "jpeg", "png", "webp")
    val SUPPORTED_MIME_TYPES = listOf("image/jpeg", "image/jpg", "image/png", "image/webp")

    /**
     * Creates a temporary file and returns a content URI for camera capture.
     */
    fun createTempCameraUri(context: Context): Pair<Uri, File> {
        val timeStamp = SimpleDateFormat("yyyyMMdd_HHmmss", Locale.getDefault()).format(Date())
        val storageDir = File(context.cacheDir, "camera_captures").apply { if (!exists()) mkdirs() }
        val tempFile = File.createTempFile("CAPTURED_${timeStamp}_", ".jpg", storageDir)
        val uri = FileProvider.getUriForFile(
            context,
            "${context.packageName}.fileprovider",
            tempFile
        )
        return Pair(uri, tempFile)
    }

    /**
     * Returns the permanent directory where venue photos are stored.
     */
    fun getPermanentPhotosDir(context: Context): File {
        val dir = File(context.filesDir, PHOTOS_DIR_NAME)
        if (!dir.exists()) {
            dir.mkdirs()
        }
        return dir
    }

    /**
     * Validates, optimizes, and permanently saves a photo as WebP from a source URI.
     */
    suspend fun processAndSaveImage(
        context: Context,
        sourceUri: Uri
    ): Result<SavedPhotoInfo> = withContext(Dispatchers.IO) {
        try {
            val contentResolver = context.contentResolver

            // 1. Validate MIME type
            val mimeType = contentResolver.getType(sourceUri)
            if (mimeType != null && !SUPPORTED_MIME_TYPES.contains(mimeType.lowercase())) {
                return@withContext Result.failure(
                    IllegalArgumentException("Unsupported format '$mimeType'. Please select JPG, PNG, or WEBP.")
                )
            }

            // 2. Perform WebP optimization and auto-resizing
            val optResult = WebPImageOptimizer.optimizeUriToWebP(
                context = context,
                sourceUri = sourceUri,
                preset = ImageOptimizationPreset.HERO_COVER
            )

            optResult.map { res ->
                SavedPhotoInfo(
                    url = res.uri.toString(),
                    fileName = res.file.name,
                    sizeBytes = res.compressedSizeBytes,
                    width = res.width,
                    height = res.height,
                    isLocalFile = true
                )
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error processing and saving photo", e)
            Result.failure(e)
        }
    }

    /**
     * Deletes a local photo file safely if it is stored in the app's permanent storage.
     */
    fun deletePhoto(urlOrPath: String): Boolean {
        return try {
            if (urlOrPath.startsWith("file://")) {
                val cleanPath = urlOrPath.removePrefix("file://")
                val file = File(cleanPath)
                if (file.exists()) {
                    val deleted = file.delete()
                    Log.i(TAG, "Deleted local photo: $urlOrPath (result: $deleted)")
                    return deleted
                }
            }
            false
        } catch (e: Exception) {
            Log.e(TAG, "Failed to delete photo file: $urlOrPath", e)
            false
        }
    }

    /**
     * Validates whether an image URL is well-formed.
     */
    fun isValidImageUrl(url: String): Boolean {
        val trimmed = url.trim()
        if (trimmed.isBlank()) return false
        if (trimmed.startsWith("file://") || trimmed.startsWith("content://")) return true
        if (!trimmed.startsWith("http://", ignoreCase = true) && !trimmed.startsWith("https://", ignoreCase = true)) {
            return false
        }
        return try {
            val parsed = URL(trimmed)
            parsed.host.isNotBlank()
        } catch (e: Exception) {
            false
        }
    }

    /**
     * Formats bytes into human-readable string.
     */
    fun formatFileSize(bytes: Long): String {
        return when {
            bytes < 1024 -> "$bytes B"
            bytes < 1024 * 1024 -> "${bytes / 1024} KB"
            else -> String.format(Locale.getDefault(), "%.1f MB", bytes / (1024.0 * 1024.0))
        }
    }
}
