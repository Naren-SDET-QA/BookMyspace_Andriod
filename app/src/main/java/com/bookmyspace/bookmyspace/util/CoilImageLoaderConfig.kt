package com.bookmyspace.bookmyspace.util

import android.content.Context
import android.graphics.Bitmap
import coil.ImageLoader
import coil.ImageLoaderFactory
import coil.disk.DiskCache
import coil.memory.MemoryCache
import coil.request.CachePolicy
import coil.request.ImageRequest
import coil.size.Precision
import coil.size.Scale
import coil.size.Size
import java.io.File

/**
 * Global Coil ImageLoader configuration with robust Memory & Disk Caching,
 * crossfade transitions, RGB_565/ARGB_8888 bitmap optimization, and helper functions
 * to downsample / resize remote venue images before list display.
 */
object CoilImageLoaderConfig {

    private const val MEMORY_CACHE_PERCENT = 0.25 // 25% of available app memory
    private const val DISK_CACHE_MAX_SIZE_BYTES = 100L * 1024 * 1024 // 100 MB disk cache
    private const val DISK_CACHE_DIR_NAME = "venue_image_cache"

    @Volatile
    private var instance: ImageLoader? = null

    /**
     * Builds and returns a singleton ImageLoader with explicit memory and disk caching policies.
     */
    fun getOrCreate(context: Context): ImageLoader {
        return instance ?: synchronized(this) {
            instance ?: buildImageLoader(context.applicationContext).also { instance = it }
        }
    }

    /**
     * Builds the configured ImageLoader.
     */
    fun buildImageLoader(context: Context): ImageLoader {
        return ImageLoader.Builder(context)
            // Memory Cache: 25% of max app heap memory, with strong references
            .memoryCache {
                MemoryCache.Builder(context)
                    .maxSizePercent(MEMORY_CACHE_PERCENT)
                    .strongReferencesEnabled(true)
                    .build()
            }
            // Disk Cache: 100MB in app cache directory
            .diskCache {
                DiskCache.Builder()
                    .directory(File(context.cacheDir, DISK_CACHE_DIR_NAME))
                    .maxSizeBytes(DISK_CACHE_MAX_SIZE_BYTES)
                    .build()
            }
            // Enable hardware bitmaps on modern devices for GPU rendering efficiency
            .allowHardware(true)
            .allowRgb565(true)
            // Crossfade animations default to 250ms for smooth image popping
            .crossfade(250)
            .respectCacheHeaders(false) // Cache images reliably even if remote header is short
            .memoryCachePolicy(CachePolicy.ENABLED)
            .diskCachePolicy(CachePolicy.ENABLED)
            .networkCachePolicy(CachePolicy.ENABLED)
            .build()
    }

    /**
     * Create an optimized ImageRequest configured with downsampling/resizing
     * based on target destination size to avoid loading full multi-megabyte bitmaps
     * into memory during LazyColumn/LazyRow scrolling.
     *
     * @param context Android Context
     * @param data Image URL, File, or Uri
     * @param targetWidthPx Target width in pixels (or dp approximation). If null, defaults to list thumbnail size (600px).
     * @param targetHeightPx Target height in pixels (or dp approximation). If null, defaults to list thumbnail size (400px).
     */
    fun buildResizedRequest(
        context: Context,
        data: Any?,
        targetWidthPx: Int = 600,
        targetHeightPx: Int = 400,
        placeholderRes: Int? = null,
        errorRes: Int? = null,
        scale: Scale = Scale.FILL
    ): ImageRequest {
        return ImageRequest.Builder(context)
            .data(data)
            .size(Size(targetWidthPx, targetHeightPx))
            .precision(Precision.INEXACT) // Inexact allows efficient downsampling with inSampleSize
            .scale(scale)
            .crossfade(true)
            .memoryCachePolicy(CachePolicy.ENABLED)
            .diskCachePolicy(CachePolicy.ENABLED)
            .apply {
                if (placeholderRes != null) placeholder(placeholderRes)
                if (errorRes != null) error(errorRes)
            }
            .build()
    }

    /**
     * Helper for small thumbnail lists (e.g. 60-80dp cards in bookings / owner / discovery lists).
     */
    fun buildThumbnailRequest(
        context: Context,
        data: Any?,
        sizePx: Int = 200
    ): ImageRequest {
        return buildResizedRequest(
            context = context,
            data = data,
            targetWidthPx = sizePx,
            targetHeightPx = sizePx,
            scale = Scale.FILL
        )
    }

    /**
     * Helper for medium/card venue banners (e.g. 140-180dp height cards in Home / Search lists).
     */
    fun buildCardBannerRequest(
        context: Context,
        data: Any?,
        widthPx: Int = 720,
        heightPx: Int = 450
    ): ImageRequest {
        return buildResizedRequest(
            context = context,
            data = data,
            targetWidthPx = widthPx,
            targetHeightPx = heightPx,
            scale = Scale.FILL
        )
    }
}
