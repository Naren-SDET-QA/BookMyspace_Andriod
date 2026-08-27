package com.bookmyspace.bookmyspace

import com.bookmyspace.bookmyspace.util.PhotoStorageManager
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [33])
class PhotoStorageManagerTest {

    @Test
    fun testValidImageUrls() {
        assertTrue(PhotoStorageManager.isValidImageUrl("https://images.unsplash.com/photo-1519167758481-83f550bb49b3"))
        assertTrue(PhotoStorageManager.isValidImageUrl("http://example.com/venue.jpg"))
        assertTrue(PhotoStorageManager.isValidImageUrl("file:///data/user/0/com.bookmyspace.bookmyspace/files/venue_photos/sample.jpg"))
        assertTrue(PhotoStorageManager.isValidImageUrl("content://media/external/images/media/123"))

        assertFalse(PhotoStorageManager.isValidImageUrl(""))
        assertFalse(PhotoStorageManager.isValidImageUrl("   "))
        assertFalse(PhotoStorageManager.isValidImageUrl("invalid-url-without-scheme"))
        assertFalse(PhotoStorageManager.isValidImageUrl("ftp://not-supported-schema.com"))
    }

    @Test
    fun testFormatFileSize() {
        assertEquals("500 B", PhotoStorageManager.formatFileSize(500L))
        assertEquals("50 KB", PhotoStorageManager.formatFileSize(50 * 1024L))
        assertTrue(PhotoStorageManager.formatFileSize(2 * 1024 * 1024L).contains("2.0 MB") || PhotoStorageManager.formatFileSize(2 * 1024 * 1024L).contains("2 MB"))
    }

    @Test
    fun testSupportedFormats() {
        assertTrue(PhotoStorageManager.SUPPORTED_EXTENSIONS.contains("jpg"))
        assertTrue(PhotoStorageManager.SUPPORTED_EXTENSIONS.contains("jpeg"))
        assertTrue(PhotoStorageManager.SUPPORTED_EXTENSIONS.contains("png"))
        assertTrue(PhotoStorageManager.SUPPORTED_EXTENSIONS.contains("webp"))

        assertTrue(PhotoStorageManager.SUPPORTED_MIME_TYPES.contains("image/jpeg"))
        assertTrue(PhotoStorageManager.SUPPORTED_MIME_TYPES.contains("image/png"))
        assertTrue(PhotoStorageManager.SUPPORTED_MIME_TYPES.contains("image/webp"))
    }

    @Test
    fun testNonExistentFileDeletionReturnsFalseSafely() {
        assertFalse(PhotoStorageManager.deletePhoto("https://images.unsplash.com/photo-1519167758481-83f550bb49b3"))
        assertFalse(PhotoStorageManager.deletePhoto("file:///non_existent_folder/non_existent_file.jpg"))
    }
}
