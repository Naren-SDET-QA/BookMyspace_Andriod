package com.bookmyspace.bookmyspace

import android.content.Context
import android.graphics.Bitmap
import android.graphics.Color
import com.bookmyspace.bookmyspace.util.ImageOptimizationPreset
import com.bookmyspace.bookmyspace.util.WebPImageOptimizer
import kotlinx.coroutines.runBlocking
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.annotation.Config
import java.io.File
import java.io.FileOutputStream

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [33])
class WebPImageOptimizerTest {

    private val context: Context = RuntimeEnvironment.getApplication()

    @Test
    fun testCompressBitmapToWebPBytes() {
        val testBitmap = Bitmap.createBitmap(200, 200, Bitmap.Config.ARGB_8888).apply {
            eraseColor(Color.RED)
        }

        val bytes = WebPImageOptimizer.compressBitmapToWebPBytes(testBitmap, quality = 80)
        assertNotNull(bytes)
        assertTrue(bytes.isNotEmpty())
    }

    @Test
    fun testOptimizeUriToWebP() = runBlocking {
        // Create sample test image file
        val tempInput = File(context.cacheDir, "sample_test_input.png")
        val sampleBitmap = Bitmap.createBitmap(800, 600, Bitmap.Config.ARGB_8888).apply {
            eraseColor(Color.BLUE)
        }
        FileOutputStream(tempInput).use { out ->
            sampleBitmap.compress(Bitmap.CompressFormat.PNG, 100, out)
        }

        val result = WebPImageOptimizer.optimizeUriToWebP(
            context = context,
            sourceUri = android.net.Uri.fromFile(tempInput),
            preset = ImageOptimizationPreset.THUMBNAIL_CARD
        )

        assertTrue(result.isSuccess)
        val opt = result.getOrNull()
        assertNotNull(opt)
        assertTrue(opt!!.file.exists())
        assertTrue(opt.file.name.endsWith(".webp"))
        assertTrue(opt.width <= ImageOptimizationPreset.THUMBNAIL_CARD.maxDimension)
        assertTrue(opt.height <= ImageOptimizationPreset.THUMBNAIL_CARD.maxDimension)
        assertEquals("image/webp", opt.format)
    }

    @Test
    fun testFormatBytes() {
        assertEquals("500 B", WebPImageOptimizer.formatBytes(500L))
        assertEquals("150 KB", WebPImageOptimizer.formatBytes(150 * 1024L))
        assertTrue(WebPImageOptimizer.formatBytes(2 * 1024 * 1024L).contains("2.0 MB") || WebPImageOptimizer.formatBytes(2 * 1024 * 1024L).contains("2 MB"))
    }

    @Test
    fun testPresets() {
        assertEquals(1920, ImageOptimizationPreset.HERO_COVER.maxDimension)
        assertEquals(85, ImageOptimizationPreset.HERO_COVER.webpQuality)

        assertEquals(1440, ImageOptimizationPreset.GALLERY_DETAIL.maxDimension)
        assertEquals(80, ImageOptimizationPreset.GALLERY_DETAIL.webpQuality)

        assertEquals(640, ImageOptimizationPreset.THUMBNAIL_CARD.maxDimension)
        assertEquals(75, ImageOptimizationPreset.THUMBNAIL_CARD.webpQuality)
    }
}
