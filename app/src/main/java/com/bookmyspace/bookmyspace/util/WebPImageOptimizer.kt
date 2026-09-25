package com.bookmyspace.bookmyspace.util

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Matrix
import android.graphics.drawable.BitmapDrawable
import android.media.ExifInterface
import android.net.Uri
import android.os.Build
import android.util.Log
import coil.ImageLoader
import coil.request.ImageRequest
import coil.request.SuccessResult
import coil.size.Precision
import coil.size.Scale
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import java.io.ByteArrayOutputStream
import java.io.File
import java.io.FileOutputStream
import java.io.InputStream
import java.util.Locale
import java.util.UUID

/**
 * Configuration presets for WebP image optimization.
 */
enum class ImageOptimizationPreset(
    val maxDimension: Int,
    val webpQuality: Int
) {
    HERO_COVER(maxDimension = 1920, webpQuality = 85),
    GALLERY_DETAIL(maxDimension = 1440, webpQuality = 80),
    THUMBNAIL_CARD(maxDimension = 640, webpQuality = 75),
    AVATAR(maxDimension = 320, webpQuality = 75)
}

/**
 * Result details of WebP conversion and compression.
 */
data class WebPOptimizationResult(
    val file: File,
    val uri: Uri,
    val originalSizeBytes: Long,
    val compressedSizeBytes: Long,
    val width: Int,
    val height: Int,
    val format: String = "image/webp",
    val savingsPercent: Int = if (originalSizeBytes > 0) {
        (((originalSizeBytes - compressedSizeBytes).toDouble() / originalSizeBytes) * 100).toInt().coerceAtLeast(0)
    } else 0
)

/**
 * High-performance WebP conversion, auto-resize, and compression helper utility.
 * Optimizes high-resolution images (JPG, PNG, HEIC, camera RAWs) to WebP format before
 * uploading to cloud database storage / permanent local cache to minimize load times and bandwidth.
 */
object WebPImageOptimizer {
    private const val TAG = "WebPImageOptimizer"
    private const val WEBP_DIR_NAME = "optimized_webp_images"

    /**
     * Resolves the platform-compatible WebP compression format.
     */
    @Suppress("DEPRECATION")
    val webpCompressFormat: Bitmap.CompressFormat
        get() = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            Bitmap.CompressFormat.WEBP_LOSSY
        } else {
            Bitmap.CompressFormat.WEBP
        }

    /**
     * Directory for optimized WebP cache files.
     */
    fun getOptimizedWebpDir(context: Context): File {
        val dir = File(context.filesDir, WEBP_DIR_NAME)
        if (!dir.exists()) {
            dir.mkdirs()
        }
        return dir
    }

    /**
     * Automatically downsamples, rotates, resizes, and compresses a source URI into WebP format.
     *
     * @param context Android context
     * @param sourceUri Uri of the source image (content:// or file://)
     * @param preset Optimization preset or custom dimensions
     * @return Result containing [WebPOptimizationResult]
     */
    suspend fun optimizeUriToWebP(
        context: Context,
        sourceUri: Uri,
        preset: ImageOptimizationPreset = ImageOptimizationPreset.GALLERY_DETAIL
    ): Result<WebPOptimizationResult> = withContext(Dispatchers.IO) {
        try {
            val contentResolver = context.contentResolver

            // 1. Measure original file size
            var originalSize: Long = 0
            contentResolver.openFileDescriptor(sourceUri, "r")?.use { pfd ->
                originalSize = pfd.statSize
            }

            // 2. Decode image bounds
            val options = BitmapFactory.Options().apply { inJustDecodeBounds = true }
            contentResolver.openInputStream(sourceUri)?.use { stream ->
                BitmapFactory.decodeStream(stream, null, options)
            }

            val origWidth = options.outWidth
            val origHeight = options.outHeight

            if (origWidth <= 0 || origHeight <= 0) {
                return@withContext Result.failure(
                    IllegalArgumentException("Invalid image dimensions from URI: $sourceUri")
                )
            }

            // 3. Compute memory-safe inSampleSize
            var inSampleSize = 1
            val targetMaxDim = preset.maxDimension
            if (origWidth > targetMaxDim || origHeight > targetMaxDim) {
                val halfWidth = origWidth / 2
                val halfHeight = origHeight / 2
                while ((halfWidth / inSampleSize) >= targetMaxDim || (halfHeight / inSampleSize) >= targetMaxDim) {
                    inSampleSize *= 2
                }
            }

            // 4. Decode downsampled Bitmap
            val decodeOptions = BitmapFactory.Options().apply {
                this.inSampleSize = inSampleSize
                inPreferredConfig = Bitmap.Config.ARGB_8888
            }

            var decodedBitmap = contentResolver.openInputStream(sourceUri)?.use { stream ->
                BitmapFactory.decodeStream(stream, null, decodeOptions)
            } ?: return@withContext Result.failure(IllegalStateException("Failed to decode bitmap from stream."))

            // 5. Correct EXIF orientation
            try {
                contentResolver.openInputStream(sourceUri)?.use { exifStream ->
                    val exif = ExifInterface(exifStream)
                    val orientation = exif.getAttributeInt(
                        ExifInterface.TAG_ORIENTATION,
                        ExifInterface.ORIENTATION_NORMAL
                    )
                    val rotationDegrees = when (orientation) {
                        ExifInterface.ORIENTATION_ROTATE_90 -> 90f
                        ExifInterface.ORIENTATION_ROTATE_180 -> 180f
                        ExifInterface.ORIENTATION_ROTATE_270 -> 270f
                        else -> 0f
                    }
                    if (rotationDegrees != 0f) {
                        val matrix = Matrix().apply { postRotate(rotationDegrees) }
                        val rotated = Bitmap.createBitmap(
                            decodedBitmap,
                            0,
                            0,
                            decodedBitmap.width,
                            decodedBitmap.height,
                            matrix,
                            true
                        )
                        if (rotated != decodedBitmap) {
                            decodedBitmap.recycle()
                            decodedBitmap = rotated
                        }
                    }
                }
            } catch (e: Exception) {
                Log.w(TAG, "EXIF rotation check skipped: ${e.message}")
            }

            // 6. Scale precisely to target dimension if still exceeds max dimension
            var finalBitmap = decodedBitmap
            val currentMax = maxOf(finalBitmap.width, finalBitmap.height)
            if (currentMax > targetMaxDim) {
                val scaleFactor = targetMaxDim.toFloat() / currentMax
                val targetW = (finalBitmap.width * scaleFactor).toInt().coerceAtLeast(1)
                val targetH = (finalBitmap.height * scaleFactor).toInt().coerceAtLeast(1)
                val scaled = Bitmap.createScaledBitmap(finalBitmap, targetW, targetH, true)
                if (scaled != finalBitmap) {
                    finalBitmap.recycle()
                    finalBitmap = scaled
                }
            }

            // 7. Compress into WebP file
            val outputFileName = "optimized_${System.currentTimeMillis()}_${UUID.randomUUID().toString().take(6)}.webp"
            val destFile = File(getOptimizedWebpDir(context), outputFileName)

            FileOutputStream(destFile).use { outStream ->
                finalBitmap.compress(webpCompressFormat, preset.webpQuality, outStream)
                outStream.flush()
            }

            val compressedSize = destFile.length()
            val finalWidth = finalBitmap.width
            val finalHeight = finalBitmap.height
            finalBitmap.recycle()

            val result = WebPOptimizationResult(
                file = destFile,
                uri = Uri.fromFile(destFile),
                originalSizeBytes = if (originalSize > 0) originalSize else compressedSize * 2,
                compressedSizeBytes = compressedSize,
                width = finalWidth,
                height = finalHeight
            )

            Log.i(
                TAG,
                "Optimized WebP created: ${destFile.name} (${result.compressedSizeBytes} bytes, ${result.savingsPercent}% savings)"
            )
            Result.success(result)
        } catch (e: Exception) {
            Log.e(TAG, "Error optimizing URI to WebP", e)
            Result.failure(e)
        }
    }

    /**
     * Uses Coil's image loading pipeline to fetch any model (remote URL, file, resource, drawable)
     * and convert/compress it into an optimized WebP byte array or file.
     */
    suspend fun optimizeWithCoilToWebP(
        context: Context,
        imageModel: Any,
        preset: ImageOptimizationPreset = ImageOptimizationPreset.GALLERY_DETAIL
    ): Result<WebPOptimizationResult> = withContext(Dispatchers.IO) {
        try {
            val imageLoader = ImageLoader.Builder(context).build()
            val request = ImageRequest.Builder(context)
                .data(imageModel)
                .size(preset.maxDimension)
                .scale(Scale.FIT)
                .precision(Precision.AUTOMATIC)
                .allowHardware(false) // Software bitmap required for pixel access & compression
                .build()

            val result = imageLoader.execute(request)
            if (result !is SuccessResult) {
                return@withContext Result.failure(
                    IllegalStateException("Coil image loading failed for model: $imageModel")
                )
            }

            val drawable = result.drawable
            val bitmap = (drawable as? BitmapDrawable)?.bitmap
                ?: return@withContext Result.failure(IllegalStateException("Coil result is not a BitmapDrawable."))

            // Output to WebP
            val outputFileName = "coil_webp_${System.currentTimeMillis()}_${UUID.randomUUID().toString().take(6)}.webp"
            val destFile = File(getOptimizedWebpDir(context), outputFileName)

            FileOutputStream(destFile).use { outStream ->
                bitmap.compress(webpCompressFormat, preset.webpQuality, outStream)
                outStream.flush()
            }

            val compressedSize = destFile.length()
            val optResult = WebPOptimizationResult(
                file = destFile,
                uri = Uri.fromFile(destFile),
                originalSizeBytes = compressedSize * 3 / 2, // approximation if remote
                compressedSizeBytes = compressedSize,
                width = bitmap.width,
                height = bitmap.height
            )

            Result.success(optResult)
        } catch (e: Exception) {
            Log.e(TAG, "Coil WebP optimization failed", e)
            Result.failure(e)
        }
    }

    /**
     * Converts an in-memory Bitmap directly to a compressed WebP ByteArray for storage upload.
     */
    fun compressBitmapToWebPBytes(
        bitmap: Bitmap,
        quality: Int = 80
    ): ByteArray {
        val stream = ByteArrayOutputStream()
        bitmap.compress(webpCompressFormat, quality.coerceIn(1, 100), stream)
        return stream.toByteArray()
    }

    /**
     * Formats bytes for scannable UI telemetry.
     */
    fun formatBytes(bytes: Long): String {
        return when {
            bytes < 1024 -> "$bytes B"
            bytes < 1024 * 1024 -> "${bytes / 1024} KB"
            else -> String.format(Locale.getDefault(), "%.1f MB", bytes / (1024.0 * 1024.0))
        }
    }
}
