package com.bookmyspace.bookmyspace.ui.screens

import android.Manifest
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.provider.Settings
import android.widget.Toast
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.PickVisualMediaRequest
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.animation.*
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material.icons.outlined.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.window.Dialog
import androidx.compose.ui.window.DialogProperties
import androidx.core.content.ContextCompat
import coil.compose.AsyncImage
import coil.request.ImageRequest
import com.bookmyspace.bookmyspace.data.model.*
import com.bookmyspace.bookmyspace.data.repository.BookMySpaceRepository
import com.bookmyspace.bookmyspace.util.PhotoStorageManager
import com.bookmyspace.bookmyspace.ui.components.BatchUploadProgressBarCard
import com.bookmyspace.bookmyspace.ui.components.BatchUploadState
import kotlinx.coroutines.Job
import kotlinx.coroutines.async
import kotlinx.coroutines.awaitAll
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.coroutines.sync.Semaphore
import kotlinx.coroutines.sync.withPermit
import java.io.File
import java.util.UUID

/**
 * Representation of a photo item in the gallery builder with granular upload tracking.
 */
data class GalleryPhotoItem(
    val id: String = UUID.randomUUID().toString(),
    val url: String,
    val isUploading: Boolean = false,
    val uploadProgress: Float = 1f,
    val isLocalFile: Boolean = false,
    val fileName: String = "",
    val fileSizeFormatted: String? = null,
    val savedBytes: Long = 0L,
    val statusStage: String = "",
    val errorMessage: String? = null
)

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun CreateVenueScreen(
    onVenueCreated: () -> Unit,
    onBack: () -> Unit,
    modifier: Modifier = Modifier
) {
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    val categories by BookMySpaceRepository.categories.collectAsState()

    var venueName by remember { mutableStateOf("") }
    var description by remember { mutableStateOf("") }
    var address by remember { mutableStateOf("") }
    var city by remember { mutableStateOf("Hyderabad") }
    var priceStr by remember { mutableStateOf("45000") }
    var capacityStr by remember { mutableStateOf("500") }
    var selectedCategory by remember { mutableStateOf(categories.firstOrNull { it.slug != "all" } ?: categories.firstOrNull()) }
    var isSaving by remember { mutableStateOf(false) }

    // Media Manager State
    var photos by remember {
        mutableStateOf(
            listOf(
                GalleryPhotoItem(url = "https://images.unsplash.com/photo-1519167758481-83f550bb49b3", fileName = "Grand Banquet"),
                GalleryPhotoItem(url = "https://images.unsplash.com/photo-1511795409834-ef04bbd61622", fileName = "Floral Stage"),
                GalleryPhotoItem(url = "https://images.unsplash.com/photo-1464366400600-7168b8af9bc3", fileName = "Reception Lawn")
            )
        )
    }

    // Concurrent Batch Upload State
    var batchUploadState by remember { mutableStateOf(BatchUploadState()) }
    var batchUploadJob by remember { mutableStateOf<Job?>(null) }
    var showBatchSummary by remember { mutableStateOf(false) }

    // Modal Sheet & Dialog States
    var showAddPhotoSheet by remember { mutableStateOf(false) }
    var showUrlInputDialog by remember { mutableStateOf(false) }
    var showPermissionRationaleDialog by remember { mutableStateOf(false) }
    var pendingCameraUri by remember { mutableStateOf<Uri?>(null) }
    var pendingCameraFile by remember { mutableStateOf<File?>(null) }
    var showCameraPreviewDialog by remember { mutableStateOf(false) }
    var selectedFullscreenPhotoUrl by remember { mutableStateOf<String?>(null) }

    // URL Dialog state
    var urlInputText by remember { mutableStateOf("") }
    var urlInputError by remember { mutableStateOf<String?>(null) }

    // Video & 3D walkthrough state
    var videoWalkthroughUrl by remember { mutableStateOf("https://example.com/walkthrough.mp4") }
    var videoTitle by remember { mutableStateOf("Space Highlights 4K Walkthrough") }
    var tour3dUrl by remember { mutableStateOf("https://matterport.com/discover/space/sample") }
    var tour3dHotspots by remember { mutableStateOf("Grand Stage, Dining Area, VIP Suites, Lawn") }

    val presetImageIdeas = listOf(
        "https://images.unsplash.com/photo-1519167758481-83f550bb49b3" to "Grand Banquet",
        "https://images.unsplash.com/photo-1511795409834-ef04bbd61622" to "Floral Stage",
        "https://images.unsplash.com/photo-1545232979-fbf6a8c3d9b0" to "Open Lawn",
        "https://images.unsplash.com/photo-1566073771259-6a8506099945" to "Luxury Resort",
        "https://images.unsplash.com/photo-1555854877-bab0e564b8d5" to "Co-Living Room",
        "https://images.unsplash.com/photo-1529900748604-07564a03e7a6" to "Sports Turf",
        "https://images.unsplash.com/photo-1508700115892-45ecd05ae2ad" to "Dance Studio"
    )

    // Concurrent Multi-Image Upload & WebP Optimization Processor
    fun startConcurrentBatchUpload(uris: List<Uri>, maxConcurrency: Int = 3) {
        if (uris.isEmpty()) return

        // 1. Immediately create gallery placeholders for instant feedback
        val newItems = uris.map { uri ->
            GalleryPhotoItem(
                id = UUID.randomUUID().toString(),
                url = uri.toString(),
                isUploading = true,
                uploadProgress = 0.05f,
                statusStage = "Queued"
            )
        }
        photos = photos + newItems
        showBatchSummary = false

        batchUploadState = BatchUploadState(
            isUploading = true,
            totalCount = uris.size,
            completedCount = 0,
            failedCount = 0,
            inFlightCount = uris.size,
            overallProgress = 0.05f,
            totalSavedBytes = 0L,
            statusMessage = "Starting concurrent upload of ${uris.size} photos...",
            activeConcurrency = maxConcurrency
        )

        batchUploadJob?.cancel()
        batchUploadJob = scope.launch {
            val semaphore = Semaphore(maxConcurrency)
            var completed = 0
            var failed = 0
            var totalSaved = 0L

            val jobs = newItems.mapIndexed { index, item ->
                val uri = uris[index]
                async {
                    semaphore.withPermit {
                        try {
                            // Step 1: Queued -> Reading & Downsampling
                            photos = photos.map {
                                if (it.id == item.id) it.copy(uploadProgress = 0.25f, statusStage = "Downsampling...") else it
                            }

                            delay(100)
                            // Step 2: Optimizing & WebP Encoding
                            photos = photos.map {
                                if (it.id == item.id) it.copy(uploadProgress = 0.65f, statusStage = "Encoding WebP...") else it
                            }

                            val result = PhotoStorageManager.processAndSaveImage(context, uri)
                            result.onSuccess { savedInfo ->
                                completed++
                                // Estimated bandwidth / disk savings from WebP vs raw JPEG/PNG
                                val estimatedSavings = (savedInfo.sizeBytes * 1.4).toLong()
                                totalSaved += estimatedSavings

                                photos = photos.map {
                                    if (it.id == item.id) {
                                        it.copy(
                                            url = savedInfo.url,
                                            isUploading = false,
                                            uploadProgress = 1f,
                                            isLocalFile = true,
                                            fileName = savedInfo.fileName,
                                            fileSizeFormatted = PhotoStorageManager.formatFileSize(savedInfo.sizeBytes),
                                            savedBytes = savedInfo.sizeBytes,
                                            statusStage = "Complete"
                                        )
                                    } else it
                                }
                            }.onFailure { error ->
                                failed++
                                photos = photos.map {
                                    if (it.id == item.id) {
                                        it.copy(
                                            isUploading = false,
                                            statusStage = "Failed",
                                            errorMessage = error.localizedMessage ?: "Failed to process photo"
                                        )
                                    } else it
                                }
                            }
                        } catch (e: Exception) {
                            failed++
                            photos = photos.map {
                                if (it.id == item.id) {
                                    it.copy(
                                        isUploading = false,
                                        statusStage = "Cancelled",
                                        errorMessage = e.localizedMessage ?: "Cancelled"
                                    )
                                } else it
                            }
                        } finally {
                            val inFlight = (uris.size - completed - failed).coerceAtLeast(0)
                            val currentBatchPhotos = photos.filter { p -> newItems.any { it.id == p.id } }
                            val totalProg = if (currentBatchPhotos.isNotEmpty()) {
                                currentBatchPhotos.map { it.uploadProgress }.average().toFloat()
                            } else 1f

                            batchUploadState = batchUploadState.copy(
                                completedCount = completed,
                                failedCount = failed,
                                inFlightCount = inFlight,
                                overallProgress = totalProg,
                                totalSavedBytes = totalSaved,
                                statusMessage = if (inFlight > 0) "Uploading $inFlight remaining ($completed done)..." else "Upload complete!"
                            )
                        }
                    }
                }
            }

            jobs.awaitAll()

            batchUploadState = batchUploadState.copy(
                isUploading = false,
                overallProgress = 1f,
                statusMessage = if (failed == 0) {
                    "All ${uris.size} photos successfully converted to WebP & saved!"
                } else {
                    "$completed uploaded successfully, $failed failed."
                }
            )
            showBatchSummary = true
            Toast.makeText(
                context,
                "🎉 Batch upload completed ($completed/${uris.size} photos saved)",
                Toast.LENGTH_SHORT
            ).show()
        }
    }

    // Helper functions for image processing
    fun addOptimizedPhotoFromUri(uri: Uri) {
        startConcurrentBatchUpload(listOf(uri), maxConcurrency = 1)
    }

    // Camera Capture Launcher
    val takePictureLauncher = rememberLauncherForActivityResult(
        contract = ActivityResultContracts.TakePicture()
    ) { success ->
        if (success && pendingCameraUri != null) {
            showCameraPreviewDialog = true
        } else {
            pendingCameraFile?.delete()
            pendingCameraFile = null
            pendingCameraUri = null
        }
    }

    // Camera Permission Launcher
    val cameraPermissionLauncher = rememberLauncherForActivityResult(
        contract = ActivityResultContracts.RequestPermission()
    ) { isGranted ->
        if (isGranted) {
            try {
                val (uri, file) = PhotoStorageManager.createTempCameraUri(context)
                pendingCameraUri = uri
                pendingCameraFile = file
                takePictureLauncher.launch(uri)
            } catch (e: Exception) {
                Toast.makeText(context, "Camera launch failed: ${e.message}", Toast.LENGTH_SHORT).show()
            }
        } else {
            showPermissionRationaleDialog = true
        }
    }

    fun startCameraCapture() {
        val permissionCheck = ContextCompat.checkSelfPermission(context, Manifest.permission.CAMERA)
        if (permissionCheck == PackageManager.PERMISSION_GRANTED) {
            try {
                val (uri, file) = PhotoStorageManager.createTempCameraUri(context)
                pendingCameraUri = uri
                pendingCameraFile = file
                takePictureLauncher.launch(uri)
            } catch (e: Exception) {
                Toast.makeText(context, "Camera launch failed: ${e.message}", Toast.LENGTH_SHORT).show()
            }
        } else {
            cameraPermissionLauncher.launch(Manifest.permission.CAMERA)
        }
    }

    // Android PhotoPicker Launcher (Multiple Selection)
    val pickMultipleMediaLauncher = rememberLauncherForActivityResult(
        contract = ActivityResultContracts.PickMultipleVisualMedia(maxItems = 10)
    ) { uris ->
        if (uris.isNotEmpty()) {
            startConcurrentBatchUpload(uris, maxConcurrency = 3)
        }
    }

    // Reorder Photo Helpers
    fun movePhotoLeft(index: Int) {
        if (index > 0) {
            val list = photos.toMutableList()
            val item = list.removeAt(index)
            list.add(index - 1, item)
            photos = list
        }
    }

    fun movePhotoRight(index: Int) {
        if (index < photos.size - 1) {
            val list = photos.toMutableList()
            val item = list.removeAt(index)
            list.add(index + 1, item)
            photos = list
        }
    }

    fun removePhoto(item: GalleryPhotoItem) {
        if (item.isLocalFile) {
            PhotoStorageManager.deletePhoto(item.url)
        }
        photos = photos.filter { it.id != item.id }
        Toast.makeText(context, "Photo removed", Toast.LENGTH_SHORT).show()
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("List Space & Media 🏛️", fontWeight = FontWeight.Bold, fontSize = 18.sp) },
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(Icons.Default.ArrowBack, contentDescription = "Back")
                    }
                },
                colors = TopAppBarDefaults.topAppBarColors(containerColor = MaterialTheme.colorScheme.surface)
            )
        },
        bottomBar = {
            Surface(shadowElevation = 8.dp, color = MaterialTheme.colorScheme.surface) {
                Button(
                    onClick = {
                        if (venueName.isNotBlank()) {
                            isSaving = true
                            val finalImages = photos.mapIndexed { idx, item ->
                                VenueImage(
                                    id = "img_${idx + 1}",
                                    url = item.url,
                                    altText = "Venue Photo ${idx + 1}",
                                    isCover = idx == 0,
                                    tag = when (idx) {
                                        0 -> "Cover"
                                        1 -> "Main Space"
                                        2 -> "Dining"
                                        else -> "Facility"
                                    }
                                )
                            }
                            val finalVideos = if (videoWalkthroughUrl.isNotBlank()) {
                                listOf(
                                    VenueVideo(
                                        id = "vid_1",
                                        title = videoTitle.ifBlank { "Short Walkthrough" },
                                        videoUrl = videoWalkthroughUrl,
                                        thumbnailUrl = photos.firstOrNull()?.url ?: "",
                                        durationSeconds = 45
                                    )
                                )
                            } else emptyList()

                            val final3dTour = if (tour3dUrl.isNotBlank()) {
                                Venue3dWalkthrough(
                                    id = "tour_1",
                                    title = "360° Virtual Tour",
                                    tourUrl = tour3dUrl,
                                    previewImageUrl = photos.firstOrNull()?.url ?: "",
                                    tourType = "360_PANORAMA",
                                    hotspots = tour3dHotspots.split(",").map { it.trim() }.filter { it.isNotBlank() }
                                )
                            } else null

                            val newVenue = Venue(
                                id = "v_${UUID.randomUUID().toString().take(6)}",
                                name = venueName.trim(),
                                description = description.trim(),
                                addressLine1 = address.trim(),
                                city = city.trim(),
                                pricingBaseAmount = priceStr.toDoubleOrNull() ?: 25000.0,
                                capacity = capacityStr.toIntOrNull() ?: 500,
                                category = selectedCategory,
                                images = finalImages,
                                videos = finalVideos,
                                virtual3dTour = final3dTour,
                                timeSlots = listOf(
                                    TimeSlot("sl_1", "Morning Session (08:00 AM - 02:00 PM)", "08:00", "14:00", priceStr.toDoubleOrNull() ?: 25000.0),
                                    TimeSlot("sl_2", "Evening Reception (04:00 PM - 11:00 PM)", "16:00", "23:00", (priceStr.toDoubleOrNull() ?: 25000.0) * 1.2),
                                    TimeSlot("sl_3", "Full Day Exclusive (24 Hours)", "00:00", "23:59", (priceStr.toDoubleOrNull() ?: 25000.0) * 2.0)
                                )
                            )
                            BookMySpaceRepository.saveVenue(newVenue)
                            onVenueCreated()
                        }
                    },
                    enabled = venueName.isNotBlank() && !isSaving,
                    shape = RoundedCornerShape(12.dp),
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(16.dp)
                        .testTag("publish_space_listing_button")
                ) {
                    Text(
                        text = if (isSaving) "Optimizing & Publishing Media..." else "Publish Space Listing & Media 🚀",
                        fontWeight = FontWeight.Bold
                    )
                }
            }
        },
        modifier = modifier.testTag("create_venue_screen")
    ) { paddingValues ->
        LazyColumn(
            modifier = Modifier
                .fillMaxSize()
                .padding(paddingValues)
                .padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(16.dp)
        ) {
            // Section 1: Basic Info
            item {
                Card(
                    colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface),
                    shape = RoundedCornerShape(16.dp),
                    border = BorderStroke(1.dp, MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.5f))
                ) {
                    Column(modifier = Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
                        Text("1. Basic Space Information", fontWeight = FontWeight.Bold, fontSize = 15.sp, color = MaterialTheme.colorScheme.primary)

                        OutlinedTextField(
                            value = venueName,
                            onValueChange = { venueName = it },
                            label = { Text("Venue / Property Name *") },
                            placeholder = { Text("e.g. Imperial Crystal Banquet & Lawns") },
                            modifier = Modifier.fillMaxWidth().testTag("input_venue_name"),
                            singleLine = true
                        )

                        OutlinedTextField(
                            value = description,
                            onValueChange = { description = it },
                            label = { Text("Description & Unique Highlights") },
                            modifier = Modifier.fillMaxWidth().height(80.dp),
                            maxLines = 3
                        )

                        // Data-Driven Category Selector
                        Text("Category (Data-Driven)", fontSize = 12.sp, fontWeight = FontWeight.SemiBold)
                        LazyRow(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                            items(categories.filter { it.slug != "all" }) { cat ->
                                val isSelected = selectedCategory?.id == cat.id
                                FilterChip(
                                    selected = isSelected,
                                    onClick = { selectedCategory = cat },
                                    label = { Text(cat.name, fontSize = 11.5.sp) },
                                    shape = RoundedCornerShape(10.dp)
                                )
                            }
                        }

                        Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                            OutlinedTextField(
                                value = priceStr,
                                onValueChange = { priceStr = it },
                                label = { Text("Base Price (₹) *") },
                                modifier = Modifier.weight(1f).testTag("input_venue_price"),
                                singleLine = true
                            )
                            OutlinedTextField(
                                value = capacityStr,
                                onValueChange = { capacityStr = it },
                                label = { Text("Max Guests") },
                                modifier = Modifier.weight(1f),
                                singleLine = true
                            )
                        }

                        OutlinedTextField(
                            value = address,
                            onValueChange = { address = it },
                            label = { Text("Street Address / Landmark") },
                            modifier = Modifier.fillMaxWidth(),
                            singleLine = true
                        )
                    }
                }
            }

            // Section 2: High-Quality Photo Gallery (Enhanced)
            item {
                Card(
                    colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface),
                    shape = RoundedCornerShape(16.dp),
                    border = BorderStroke(1.dp, MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.5f))
                ) {
                    Column(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(16.dp),
                        verticalArrangement = Arrangement.spacedBy(12.dp)
                    ) {
                        // Section Header with Photo Count
                        Row(
                            modifier = Modifier.fillMaxWidth(),
                            horizontalArrangement = Arrangement.SpaceBetween,
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            Text(
                                text = "2. High-Quality Photo Gallery",
                                fontWeight = FontWeight.Bold,
                                fontSize = 15.sp,
                                color = MaterialTheme.colorScheme.primary
                            )
                            Surface(
                                shape = RoundedCornerShape(8.dp),
                                color = MaterialTheme.colorScheme.primaryContainer
                            ) {
                                Text(
                                    text = "${photos.size} Photos",
                                    fontSize = 12.sp,
                                    fontWeight = FontWeight.Bold,
                                    color = MaterialTheme.colorScheme.onPrimaryContainer,
                                    modifier = Modifier.padding(horizontal = 8.dp, vertical = 4.dp)
                                )
                            }
                        }

                        Text(
                            text = "Add high-resolution photos. The first image is the main Cover Photo. Tap to view fullscreen or use arrows to reorder.",
                            fontSize = 11.5.sp,
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )

                        // Multi-image Concurrent Batch Upload Progress Bar Card
                        AnimatedVisibility(
                            visible = batchUploadState.isUploading || (showBatchSummary && batchUploadState.totalCount > 0),
                            enter = fadeIn() + expandVertically(),
                            exit = fadeOut() + shrinkVertically()
                        ) {
                            BatchUploadProgressBarCard(
                                state = batchUploadState,
                                onCancel = {
                                    batchUploadJob?.cancel()
                                    batchUploadJob = null
                                    batchUploadState = batchUploadState.copy(
                                        isUploading = false,
                                        statusMessage = "Upload cancelled"
                                    )
                                    photos = photos.map {
                                        if (it.isUploading) it.copy(isUploading = false, errorMessage = "Cancelled") else it
                                    }
                                    Toast.makeText(context, "Batch upload cancelled", Toast.LENGTH_SHORT).show()
                                },
                                onDismiss = {
                                    showBatchSummary = false
                                    batchUploadState = BatchUploadState()
                                },
                                modifier = Modifier.padding(bottom = 6.dp)
                            )
                        }

                        // Empty State if no photos
                        if (photos.isEmpty()) {
                            Box(
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .height(110.dp)
                                    .clip(RoundedCornerShape(12.dp))
                                    .border(
                                        width = 1.5.dp,
                                        color = MaterialTheme.colorScheme.outlineVariant,
                                        shape = RoundedCornerShape(12.dp)
                                    )
                                    .background(MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.3f))
                                    .clickable { showAddPhotoSheet = true },
                                contentAlignment = Alignment.Center
                            ) {
                                Column(
                                    horizontalAlignment = Alignment.CenterHorizontally,
                                    verticalArrangement = Arrangement.spacedBy(4.dp)
                                ) {
                                    Icon(
                                        Icons.Outlined.AddPhotoAlternate,
                                        contentDescription = null,
                                        tint = MaterialTheme.colorScheme.primary,
                                        modifier = Modifier.size(32.dp)
                                    )
                                    Text(
                                        "No photos added yet",
                                        fontWeight = FontWeight.SemiBold,
                                        fontSize = 13.sp
                                    )
                                    Text(
                                        "Tap '+ Add Photos' to capture or select images",
                                        fontSize = 11.sp,
                                        color = MaterialTheme.colorScheme.onSurfaceVariant
                                    )
                                }
                            }
                        } else {
                            // Photos Horizontal List with Reordering and Actions
                            LazyRow(
                                horizontalArrangement = Arrangement.spacedBy(10.dp),
                                modifier = Modifier.fillMaxWidth()
                            ) {
                                itemsIndexed(photos, key = { _, item -> item.id }) { index, item ->
                                    val isCover = index == 0

                                    Card(
                                        shape = RoundedCornerShape(14.dp),
                                        border = BorderStroke(
                                            width = if (isCover) 2.dp else 1.dp,
                                            color = if (isCover) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.outlineVariant
                                        ),
                                        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.4f)),
                                        modifier = Modifier
                                            .width(135.dp)
                                            .wrapContentHeight()
                                    ) {
                                        Column {
                                            // Image Thumbnail Container
                                            Box(
                                                modifier = Modifier
                                                    .fillMaxWidth()
                                                    .height(110.dp)
                                                    .clip(RoundedCornerShape(topStart = 14.dp, topEnd = 14.dp))
                                                    .clickable { selectedFullscreenPhotoUrl = item.url }
                                            ) {
                                                AsyncImage(
                                                    model = ImageRequest.Builder(context)
                                                        .data(item.url)
                                                        .crossfade(true)
                                                        .build(),
                                                    contentDescription = "Photo ${index + 1}",
                                                    contentScale = ContentScale.Crop,
                                                    modifier = Modifier.fillMaxSize()
                                                )

                                                // Cover Badge
                                                if (isCover) {
                                                    Surface(
                                                        shape = RoundedCornerShape(bottomEnd = 8.dp),
                                                        color = MaterialTheme.colorScheme.primary,
                                                        modifier = Modifier.align(Alignment.TopStart)
                                                    ) {
                                                        Row(
                                                            verticalAlignment = Alignment.CenterVertically,
                                                            modifier = Modifier.padding(horizontal = 6.dp, vertical = 2.dp)
                                                        ) {
                                                            Icon(
                                                                Icons.Default.Star,
                                                                contentDescription = null,
                                                                tint = MaterialTheme.colorScheme.onPrimary,
                                                                modifier = Modifier.size(10.dp)
                                                            )
                                                            Spacer(Modifier.width(2.dp))
                                                            Text(
                                                                "COVER",
                                                                fontSize = 9.sp,
                                                                fontWeight = FontWeight.Bold,
                                                                color = MaterialTheme.colorScheme.onPrimary
                                                            )
                                                        }
                                                    }
                                                }

                                                // Delete / Remove Button
                                                IconButton(
                                                    onClick = { removePhoto(item) },
                                                    modifier = Modifier
                                                        .align(Alignment.TopEnd)
                                                        .padding(4.dp)
                                                        .size(26.dp)
                                                        .background(Color.Black.copy(alpha = 0.65f), CircleShape)
                                                ) {
                                                    Icon(
                                                        Icons.Default.Close,
                                                        contentDescription = "Remove photo",
                                                        tint = Color.White,
                                                        modifier = Modifier.size(14.dp)
                                                    )
                                                }

                                                // Granular Upload Progress Overlay
                                                if (item.isUploading) {
                                                    Box(
                                                        modifier = Modifier
                                                            .fillMaxSize()
                                                            .background(Color.Black.copy(alpha = 0.65f)),
                                                        contentAlignment = Alignment.Center
                                                    ) {
                                                        Column(
                                                            horizontalAlignment = Alignment.CenterHorizontally,
                                                            verticalArrangement = Arrangement.spacedBy(4.dp)
                                                        ) {
                                                            CircularProgressIndicator(
                                                                progress = { item.uploadProgress },
                                                                modifier = Modifier.size(28.dp),
                                                                color = MaterialTheme.colorScheme.primary,
                                                                strokeWidth = 3.dp
                                                            )
                                                            Text(
                                                                text = "${(item.uploadProgress * 100).toInt()}%",
                                                                color = Color.White,
                                                                fontSize = 10.sp,
                                                                fontWeight = FontWeight.Bold
                                                            )
                                                            if (item.statusStage.isNotBlank()) {
                                                                Text(
                                                                    text = item.statusStage,
                                                                    color = Color.White.copy(alpha = 0.85f),
                                                                    fontSize = 8.sp,
                                                                    maxLines = 1
                                                                )
                                                            }
                                                        }
                                                    }
                                                }

                                                // Error state overlay
                                                if (item.errorMessage != null) {
                                                    Box(
                                                        modifier = Modifier
                                                            .fillMaxSize()
                                                            .background(Color.Red.copy(alpha = 0.6f)),
                                                        contentAlignment = Alignment.Center
                                                    ) {
                                                        Icon(
                                                            Icons.Default.Warning,
                                                            contentDescription = "Error",
                                                            tint = Color.White,
                                                            modifier = Modifier.size(24.dp)
                                                        )
                                                    }
                                                }
                                            }

                                            // Reorder & Info Controls Row
                                            Row(
                                                modifier = Modifier
                                                    .fillMaxWidth()
                                                    .padding(horizontal = 4.dp, vertical = 2.dp),
                                                horizontalArrangement = Arrangement.SpaceBetween,
                                                verticalAlignment = Alignment.CenterVertically
                                            ) {
                                                // Move Left
                                                IconButton(
                                                    onClick = { movePhotoLeft(index) },
                                                    enabled = index > 0,
                                                    modifier = Modifier.size(26.dp)
                                                ) {
                                                    Icon(
                                                        Icons.Default.KeyboardArrowLeft,
                                                        contentDescription = "Move Left",
                                                        tint = if (index > 0) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.onSurface.copy(alpha = 0.3f),
                                                        modifier = Modifier.size(18.dp)
                                                    )
                                                }

                                                Text(
                                                    text = "#${index + 1}",
                                                    fontSize = 11.sp,
                                                    fontWeight = FontWeight.Bold,
                                                    color = MaterialTheme.colorScheme.onSurfaceVariant
                                                )

                                                // Move Right
                                                IconButton(
                                                    onClick = { movePhotoRight(index) },
                                                    enabled = index < photos.size - 1,
                                                    modifier = Modifier.size(26.dp)
                                                ) {
                                                    Icon(
                                                        Icons.Default.KeyboardArrowRight,
                                                        contentDescription = "Move Right",
                                                        tint = if (index < photos.size - 1) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.onSurface.copy(alpha = 0.3f),
                                                        modifier = Modifier.size(18.dp)
                                                    )
                                                }
                                            }

                                            // Subtitle / File size or WEBP badge
                                            if (item.isLocalFile && item.fileSizeFormatted != null) {
                                                Surface(
                                                    shape = RoundedCornerShape(4.dp),
                                                    color = MaterialTheme.colorScheme.primaryContainer.copy(alpha = 0.7f),
                                                    modifier = Modifier
                                                        .padding(horizontal = 6.dp)
                                                        .padding(bottom = 6.dp)
                                                ) {
                                                    Text(
                                                        text = "WEBP • ${item.fileSizeFormatted}",
                                                        fontSize = 8.5.sp,
                                                        fontWeight = FontWeight.Medium,
                                                        color = MaterialTheme.colorScheme.onPrimaryContainer,
                                                        modifier = Modifier.padding(horizontal = 4.dp, vertical = 2.dp)
                                                    )
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        // Primary "+ Add Photos" Button
                        FilledTonalButton(
                            onClick = { showAddPhotoSheet = true },
                            modifier = Modifier
                                .fillMaxWidth()
                                .height(46.dp)
                                .testTag("btn_add_photos_gallery"),
                            shape = RoundedCornerShape(12.dp)
                        ) {
                            Icon(Icons.Outlined.AddPhotoAlternate, contentDescription = null, modifier = Modifier.size(18.dp))
                            Spacer(Modifier.width(8.dp))
                            Text("+ Add Photos (Camera, Gallery, URL)", fontWeight = FontWeight.Bold, fontSize = 13.5.sp)
                        }

                        // Quick HD Venue Shots Presets
                        Text("Or tap to add preset HD venue shots:", fontSize = 11.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                        LazyRow(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                            items(presetImageIdeas) { (presetUrl, title) ->
                                AssistChip(
                                    onClick = {
                                        if (photos.none { it.url == presetUrl }) {
                                            photos = photos + GalleryPhotoItem(url = presetUrl, fileName = title)
                                            Toast.makeText(context, "Added $title shot", Toast.LENGTH_SHORT).show()
                                        }
                                    },
                                    label = { Text("+ $title", fontSize = 10.5.sp) },
                                    shape = RoundedCornerShape(8.dp)
                                )
                            }
                        }
                    }
                }
            }

            // Section 3: Short Video & 3D Walkthrough Management
            item {
                Card(
                    colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface),
                    shape = RoundedCornerShape(16.dp),
                    border = BorderStroke(1.dp, MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.5f))
                ) {
                    Column(modifier = Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
                        Text("3. Short Video & 3D / 360° Walkthrough", fontWeight = FontWeight.Bold, fontSize = 15.sp, color = MaterialTheme.colorScheme.primary)
                        Text("Showcase dynamic short video walkthroughs and 3D Matterport / 360° tours before users book.", fontSize = 11.5.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)

                        OutlinedTextField(
                            value = videoTitle,
                            onValueChange = { videoTitle = it },
                            label = { Text("Video Tour Title") },
                            modifier = Modifier.fillMaxWidth(),
                            singleLine = true
                        )

                        OutlinedTextField(
                            value = videoWalkthroughUrl,
                            onValueChange = { videoWalkthroughUrl = it },
                            label = { Text("Video File URL (MP4 / Web)") },
                            placeholder = { Text("https://storage.googleapis.com/venues/tour.mp4") },
                            modifier = Modifier.fillMaxWidth(),
                            singleLine = true
                        )

                        OutlinedTextField(
                            value = tour3dUrl,
                            onValueChange = { tour3dUrl = it },
                            label = { Text("3D / 360° Virtual Tour Link") },
                            placeholder = { Text("https://matterport.com/discover/space/...") },
                            modifier = Modifier.fillMaxWidth(),
                            singleLine = true
                        )

                        OutlinedTextField(
                            value = tour3dHotspots,
                            onValueChange = { tour3dHotspots = it },
                            label = { Text("3D Tour Room Hotspots (Comma-separated)") },
                            modifier = Modifier.fillMaxWidth(),
                            singleLine = true
                        )
                    }
                }
            }
        }
    }

    // ==========================================
    // 1. ADD PHOTOS MODAL BOTTOM SHEET
    // ==========================================
    if (showAddPhotoSheet) {
        ModalBottomSheet(
            onDismissRequest = { showAddPhotoSheet = false },
            containerColor = MaterialTheme.colorScheme.surface,
            shape = RoundedCornerShape(topStart = 24.dp, topEnd = 24.dp),
            dragHandle = { BottomSheetDefaults.DragHandle() }
        ) {
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 20.dp, vertical = 8.dp)
                    .padding(bottom = 24.dp),
                verticalArrangement = Arrangement.spacedBy(16.dp)
            ) {
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Column {
                        Text(
                            text = "Add Photos",
                            fontSize = 18.sp,
                            fontWeight = FontWeight.Bold,
                            color = MaterialTheme.colorScheme.onSurface
                        )
                        Text(
                            text = "Upload high-quality images of your space",
                            fontSize = 12.sp,
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                    }
                    IconButton(onClick = { showAddPhotoSheet = false }) {
                        Icon(Icons.Default.Close, contentDescription = "Close")
                    }
                }

                Divider(color = MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.5f))

                // Option 1: Take Photo
                Card(
                    onClick = {
                        showAddPhotoSheet = false
                        startCameraCapture()
                    },
                    colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.5f)),
                    shape = RoundedCornerShape(16.dp),
                    border = BorderStroke(1.dp, MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.4f)),
                    modifier = Modifier.fillMaxWidth()
                ) {
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(16.dp),
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Box(
                            modifier = Modifier
                                .size(48.dp)
                                .background(MaterialTheme.colorScheme.primary.copy(alpha = 0.15f), CircleShape),
                            contentAlignment = Alignment.Center
                        ) {
                            Icon(
                                Icons.Default.CameraAlt,
                                contentDescription = "Take Photo",
                                tint = MaterialTheme.colorScheme.primary,
                                modifier = Modifier.size(24.dp)
                            )
                        }
                        Spacer(Modifier.width(16.dp))
                        Column(modifier = Modifier.weight(1f)) {
                            Text(
                                text = "📷 Take Photo",
                                fontWeight = FontWeight.Bold,
                                fontSize = 15.sp,
                                color = MaterialTheme.colorScheme.onSurface
                            )
                            Text(
                                text = "Capture directly using device camera",
                                fontSize = 12.sp,
                                color = MaterialTheme.colorScheme.onSurfaceVariant
                            )
                        }
                        Icon(
                            Icons.Default.ChevronRight,
                            contentDescription = null,
                            tint = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                    }
                }

                // Option 2: Choose from Gallery
                Card(
                    onClick = {
                        showAddPhotoSheet = false
                        pickMultipleMediaLauncher.launch(
                            PickVisualMediaRequest(ActivityResultContracts.PickVisualMedia.ImageOnly)
                        )
                    },
                    colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.5f)),
                    shape = RoundedCornerShape(16.dp),
                    border = BorderStroke(1.dp, MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.4f)),
                    modifier = Modifier.fillMaxWidth()
                ) {
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(16.dp),
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Box(
                            modifier = Modifier
                                .size(48.dp)
                                .background(MaterialTheme.colorScheme.secondary.copy(alpha = 0.15f), CircleShape),
                            contentAlignment = Alignment.Center
                        ) {
                            Icon(
                                Icons.Default.PhotoLibrary,
                                contentDescription = "Choose from Gallery",
                                tint = MaterialTheme.colorScheme.secondary,
                                modifier = Modifier.size(24.dp)
                            )
                        }
                        Spacer(Modifier.width(16.dp))
                        Column(modifier = Modifier.weight(1f)) {
                            Text(
                                text = "🖼️ Choose from Gallery",
                                fontWeight = FontWeight.Bold,
                                fontSize = 15.sp,
                                color = MaterialTheme.colorScheme.onSurface
                            )
                            Text(
                                text = "Select one or more photos (JPG, PNG, WEBP)",
                                fontSize = 12.sp,
                                color = MaterialTheme.colorScheme.onSurfaceVariant
                            )
                        }
                        Icon(
                            Icons.Default.ChevronRight,
                            contentDescription = null,
                            tint = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                    }
                }

                // Option 3: Add Image URL
                Card(
                    onClick = {
                        showAddPhotoSheet = false
                        urlInputText = ""
                        urlInputError = null
                        showUrlInputDialog = true
                    },
                    colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.5f)),
                    shape = RoundedCornerShape(16.dp),
                    border = BorderStroke(1.dp, MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.4f)),
                    modifier = Modifier.fillMaxWidth()
                ) {
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(16.dp),
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Box(
                            modifier = Modifier
                                .size(48.dp)
                                .background(MaterialTheme.colorScheme.tertiary.copy(alpha = 0.15f), CircleShape),
                            contentAlignment = Alignment.Center
                        ) {
                            Icon(
                                Icons.Default.Link,
                                contentDescription = "Add by URL",
                                tint = MaterialTheme.colorScheme.tertiary,
                                modifier = Modifier.size(24.dp)
                            )
                        }
                        Spacer(Modifier.width(16.dp))
                        Column(modifier = Modifier.weight(1f)) {
                            Text(
                                text = "🔗 Add Image URL",
                                fontWeight = FontWeight.Bold,
                                fontSize = 15.sp,
                                color = MaterialTheme.colorScheme.onSurface
                            )
                            Text(
                                text = "Paste a direct web link to an image",
                                fontSize = 12.sp,
                                color = MaterialTheme.colorScheme.onSurfaceVariant
                            )
                        }
                        Icon(
                            Icons.Default.ChevronRight,
                            contentDescription = null,
                            tint = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                    }
                }

                // Cancel Button
                OutlinedButton(
                    onClick = { showAddPhotoSheet = false },
                    shape = RoundedCornerShape(12.dp),
                    modifier = Modifier.fillMaxWidth()
                ) {
                    Text("Cancel")
                }
            }
        }
    }

    // ==========================================
    // 2. CAMERA CAPTURE PREVIEW & CONFIRM DIALOG
    // ==========================================
    if (showCameraPreviewDialog && pendingCameraUri != null) {
        Dialog(
            onDismissRequest = {
                showCameraPreviewDialog = false
                pendingCameraFile?.delete()
                pendingCameraFile = null
                pendingCameraUri = null
            },
            properties = DialogProperties(usePlatformDefaultWidth = false)
        ) {
            Surface(
                shape = RoundedCornerShape(20.dp),
                color = MaterialTheme.colorScheme.surface,
                modifier = Modifier
                    .fillMaxWidth(0.92f)
                    .wrapContentHeight()
            ) {
                Column(
                    modifier = Modifier.padding(20.dp),
                    verticalArrangement = Arrangement.spacedBy(14.dp),
                    horizontalAlignment = Alignment.CenterHorizontally
                ) {
                    Text(
                        text = "Photo Preview 📸",
                        fontWeight = FontWeight.Bold,
                        fontSize = 17.sp,
                        color = MaterialTheme.colorScheme.onSurface
                    )

                    // Preview Image Box
                    Box(
                        modifier = Modifier
                            .fillMaxWidth()
                            .height(260.dp)
                            .clip(RoundedCornerShape(16.dp))
                            .border(1.dp, MaterialTheme.colorScheme.outlineVariant, RoundedCornerShape(16.dp))
                    ) {
                        AsyncImage(
                            model = ImageRequest.Builder(context)
                                .data(pendingCameraUri)
                                .crossfade(true)
                                .build(),
                            contentDescription = "Captured Photo",
                            contentScale = ContentScale.Crop,
                            modifier = Modifier.fillMaxSize()
                        )
                    }

                    Text(
                        text = "Review your venue photo before adding it to the listing gallery.",
                        fontSize = 12.sp,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                        textAlign = TextAlign.Center
                    )

                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.spacedBy(10.dp)
                    ) {
                        // Retake
                        OutlinedButton(
                            onClick = {
                                showCameraPreviewDialog = false
                                pendingCameraFile?.delete()
                                pendingCameraFile = null
                                pendingCameraUri = null
                                startCameraCapture()
                            },
                            shape = RoundedCornerShape(10.dp),
                            modifier = Modifier.weight(1f)
                        ) {
                            Icon(Icons.Default.Refresh, contentDescription = null, modifier = Modifier.size(16.dp))
                            Spacer(Modifier.width(4.dp))
                            Text("Retake")
                        }

                        // Confirm & Add
                        Button(
                            onClick = {
                                val uriToSave = pendingCameraUri
                                showCameraPreviewDialog = false
                                pendingCameraFile = null
                                pendingCameraUri = null
                                if (uriToSave != null) {
                                    addOptimizedPhotoFromUri(uriToSave)
                                }
                            },
                            shape = RoundedCornerShape(10.dp),
                            modifier = Modifier.weight(1.5f)
                        ) {
                            Icon(Icons.Default.Check, contentDescription = null, modifier = Modifier.size(16.dp))
                            Spacer(Modifier.width(4.dp))
                            Text("Confirm & Add")
                        }
                    }
                }
            }
        }
    }

    // ==========================================
    // 3. ADD IMAGE BY URL DIALOG
    // ==========================================
    if (showUrlInputDialog) {
        val isValidUrl = remember(urlInputText) {
            PhotoStorageManager.isValidImageUrl(urlInputText)
        }

        AlertDialog(
            onDismissRequest = { showUrlInputDialog = false },
            title = {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Icon(Icons.Default.Link, contentDescription = null, tint = MaterialTheme.colorScheme.primary)
                    Spacer(Modifier.width(8.dp))
                    Text("Add Image by URL", fontWeight = FontWeight.Bold, fontSize = 16.sp)
                }
            },
            text = {
                Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                    Text(
                        "Enter or paste the direct link to a high-resolution space photo (JPG, PNG, WEBP):",
                        fontSize = 12.sp,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )

                    OutlinedTextField(
                        value = urlInputText,
                        onValueChange = {
                            urlInputText = it
                            urlInputError = null
                        },
                        label = { Text("Image URL") },
                        placeholder = { Text("https://images.unsplash.com/...") },
                        isError = urlInputError != null,
                        supportingText = {
                            if (urlInputError != null) {
                                Text(urlInputError!!, color = MaterialTheme.colorScheme.error)
                            } else if (isValidUrl) {
                                Text("✓ Valid URL format", color = MaterialTheme.colorScheme.primary, fontSize = 11.sp)
                            }
                        },
                        trailingIcon = {
                            if (urlInputText.isNotBlank()) {
                                IconButton(onClick = { urlInputText = "" }) {
                                    Icon(Icons.Default.Clear, contentDescription = "Clear")
                                }
                            }
                        },
                        modifier = Modifier.fillMaxWidth(),
                        singleLine = true
                    )

                    // Live URL Preview if valid
                    if (isValidUrl) {
                        Box(
                            modifier = Modifier
                                .fillMaxWidth()
                                .height(120.dp)
                                .clip(RoundedCornerShape(10.dp))
                                .border(1.dp, MaterialTheme.colorScheme.outlineVariant, RoundedCornerShape(10.dp))
                        ) {
                            AsyncImage(
                                model = ImageRequest.Builder(context)
                                    .data(urlInputText.trim())
                                    .crossfade(true)
                                    .build(),
                                contentDescription = "URL Preview",
                                contentScale = ContentScale.Crop,
                                modifier = Modifier.fillMaxSize()
                            )
                        }
                    }
                }
            },
            confirmButton = {
                Button(
                    onClick = {
                        val trimmed = urlInputText.trim()
                        if (PhotoStorageManager.isValidImageUrl(trimmed)) {
                            photos = photos + GalleryPhotoItem(url = trimmed, fileName = "Web Photo")
                            showUrlInputDialog = false
                            urlInputText = ""
                            Toast.makeText(context, "Image added from URL!", Toast.LENGTH_SHORT).show()
                        } else {
                            urlInputError = "Please enter a valid HTTP/HTTPS image URL."
                        }
                    },
                    enabled = urlInputText.isNotBlank()
                ) {
                    Text("Add Image")
                }
            },
            dismissButton = {
                TextButton(onClick = { showUrlInputDialog = false }) {
                    Text("Cancel")
                }
            }
        )
    }

    // ==========================================
    // 4. PERMISSION RATIONALE & SETTINGS DIALOG
    // ==========================================
    if (showPermissionRationaleDialog) {
        AlertDialog(
            onDismissRequest = { showPermissionRationaleDialog = false },
            icon = { Icon(Icons.Default.CameraAlt, contentDescription = null, tint = MaterialTheme.colorScheme.primary) },
            title = { Text("Camera Permission Needed", fontWeight = FontWeight.Bold) },
            text = {
                Text(
                    "To capture high-quality live photos of your venue, BookMySpace requires camera access. You can grant camera permission in App Settings, or choose photos directly from your device gallery.",
                    fontSize = 13.sp
                )
            },
            confirmButton = {
                Button(
                    onClick = {
                        showPermissionRationaleDialog = false
                        val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                            data = Uri.fromParts("package", context.packageName, null)
                        }
                        context.startActivity(intent)
                    }
                ) {
                    Text("Open Settings")
                }
            },
            dismissButton = {
                TextButton(onClick = { showPermissionRationaleDialog = false }) {
                    Text("Not Now")
                }
            }
        )
    }

    // ==========================================
    // 5. FULL-SCREEN LIGHTBOX IMAGE VIEWER
    // ==========================================
    selectedFullscreenPhotoUrl?.let { fullUrl ->
        val currentIndex = photos.indexOfFirst { it.url == fullUrl }

        Dialog(
            onDismissRequest = { selectedFullscreenPhotoUrl = null },
            properties = DialogProperties(usePlatformDefaultWidth = false)
        ) {
            Box(
                modifier = Modifier
                    .fillMaxSize()
                    .background(Color.Black.copy(alpha = 0.95f))
            ) {
                // Image Fullscreen
                AsyncImage(
                    model = ImageRequest.Builder(context)
                        .data(fullUrl)
                        .crossfade(true)
                        .build(),
                    contentDescription = "Full Image View",
                    contentScale = ContentScale.Fit,
                    modifier = Modifier.fillMaxSize()
                )

                // Top Bar
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .statusBarsPadding()
                        .padding(16.dp),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Text(
                        text = if (currentIndex >= 0) "Photo ${currentIndex + 1} of ${photos.size}" else "Photo Preview",
                        color = Color.White,
                        fontWeight = FontWeight.Bold,
                        fontSize = 15.sp
                    )

                    Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                        // Set as Cover shortcut
                        if (currentIndex > 0) {
                            FilledTonalButton(
                                onClick = {
                                    val list = photos.toMutableList()
                                    val item = list.removeAt(currentIndex)
                                    list.add(0, item)
                                    photos = list
                                    Toast.makeText(context, "Set as #1 Cover Photo", Toast.LENGTH_SHORT).show()
                                },
                                colors = ButtonDefaults.filledTonalButtonColors(
                                    containerColor = MaterialTheme.colorScheme.primary,
                                    contentColor = MaterialTheme.colorScheme.onPrimary
                                )
                            ) {
                                Icon(Icons.Default.Star, contentDescription = null, modifier = Modifier.size(16.dp))
                                Spacer(Modifier.width(4.dp))
                                Text("Make Cover", fontSize = 12.sp)
                            }
                        }

                        // Close button
                        IconButton(
                            onClick = { selectedFullscreenPhotoUrl = null },
                            modifier = Modifier
                                .size(36.dp)
                                .background(Color.White.copy(alpha = 0.2f), CircleShape)
                        ) {
                            Icon(Icons.Default.Close, contentDescription = "Close", tint = Color.White)
                        }
                    }
                }
            }
        }
    }
}
