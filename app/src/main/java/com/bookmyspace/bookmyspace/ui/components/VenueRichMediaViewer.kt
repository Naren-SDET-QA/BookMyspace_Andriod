package com.bookmyspace.bookmyspace.ui.components

import androidx.compose.animation.*
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.gestures.detectDragGestures
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.pager.HorizontalPager
import androidx.compose.foundation.pager.rememberPagerState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import coil.compose.AsyncImage
import coil.request.ImageRequest
import com.bookmyspace.bookmyspace.data.model.Venue
import com.bookmyspace.bookmyspace.data.model.Venue3dWalkthrough
import com.bookmyspace.bookmyspace.data.model.VenueVideo
import com.bookmyspace.bookmyspace.util.VenueImageResolver
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

enum class VenueMediaTab(val label: String, val icon: androidx.compose.ui.graphics.vector.ImageVector) {
    PHOTOS("Photos", Icons.Default.PhotoLibrary),
    VIDEO("Short Video", Icons.Default.Videocam),
    VIRTUAL_3D("3D / 360° Tour", Icons.Default.ViewInAr)
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun VenueRichMediaViewer(
    venue: Venue,
    modifier: Modifier = Modifier,
    onBookSlot: () -> Unit = {}
) {
    var selectedTab by remember { mutableStateOf(VenueMediaTab.PHOTOS) }
    var showFullscreenViewer by remember { mutableStateOf(false) }
    var activePhotoTagFilter by remember { mutableStateOf("All") }

    val allImages = remember(venue) {
        val gallery = VenueImageResolver.resolveGalleryImages(venue)
        if (gallery.isEmpty()) listOf(venue.coverImageUrl.ifBlank { "https://images.unsplash.com/photo-1519167758481-83f550bb49b3?w=800" }) else gallery
    }

    val availableTags = remember(venue) {
        listOf("All", "Main Space", "Dining", "Rooms & Suites", "Lawn", "Exterior")
    }

    Card(
        modifier = modifier
            .fillMaxWidth()
            .testTag("venue_rich_media_viewer"),
        shape = RoundedCornerShape(20.dp),
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface),
        border = BorderStroke(1.dp, MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.5f))
    ) {
        Column {
            // Media Type Tabs Row
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .background(MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.35f))
                    .padding(horizontal = 12.dp, vertical = 8.dp),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    VenueMediaTab.entries.forEach { tab ->
                        val isSelected = selectedTab == tab
                        Surface(
                            modifier = Modifier
                                .clip(RoundedCornerShape(20.dp))
                                .clickable { selectedTab = tab }
                                .testTag("media_tab_${tab.name.lowercase()}"),
                            color = if (isSelected) MaterialTheme.colorScheme.primary else Color.Transparent,
                            shape = RoundedCornerShape(20.dp),
                            border = if (!isSelected) BorderStroke(1.dp, MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.4f)) else null
                        ) {
                            Row(
                                modifier = Modifier.padding(horizontal = 12.dp, vertical = 6.dp),
                                verticalAlignment = Alignment.CenterVertically
                            ) {
                                Icon(
                                    imageVector = tab.icon,
                                    contentDescription = null,
                                    tint = if (isSelected) MaterialTheme.colorScheme.onPrimary else MaterialTheme.colorScheme.onSurfaceVariant,
                                    modifier = Modifier.size(15.dp)
                                )
                                Spacer(modifier = Modifier.width(6.dp))
                                Text(
                                    text = tab.label,
                                    fontSize = 11.5.sp,
                                    fontWeight = if (isSelected) FontWeight.Bold else FontWeight.Medium,
                                    color = if (isSelected) MaterialTheme.colorScheme.onPrimary else MaterialTheme.colorScheme.onSurfaceVariant
                                )
                            }
                        }
                    }
                }

                // HD Badge
                Surface(
                    color = MaterialTheme.colorScheme.primaryContainer.copy(alpha = 0.4f),
                    shape = RoundedCornerShape(8.dp)
                ) {
                    Text(
                        text = "4K ULTRA HD",
                        fontSize = 9.sp,
                        fontWeight = FontWeight.ExtraBold,
                        color = MaterialTheme.colorScheme.primary,
                        modifier = Modifier.padding(horizontal = 6.dp, vertical = 3.dp)
                    )
                }
            }

            // Media Content Area
            AnimatedContent(
                targetState = selectedTab,
                label = "VenueMediaContentCrossfade"
            ) { tab ->
                when (tab) {
                    VenueMediaTab.PHOTOS -> {
                        Column {
                            // Filter tags
                            LazyRow(
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .padding(horizontal = 14.dp, vertical = 8.dp),
                                horizontalArrangement = Arrangement.spacedBy(6.dp)
                            ) {
                                items(availableTags) { tag ->
                                    val isSelected = activePhotoTagFilter == tag
                                    FilterChip(
                                        selected = isSelected,
                                        onClick = { activePhotoTagFilter = tag },
                                        label = { Text(tag, fontSize = 11.sp, fontWeight = if (isSelected) FontWeight.Bold else FontWeight.Normal) },
                                        shape = RoundedCornerShape(12.dp),
                                        colors = FilterChipDefaults.filterChipColors(
                                            selectedContainerColor = MaterialTheme.colorScheme.primaryContainer,
                                            selectedLabelColor = MaterialTheme.colorScheme.onPrimaryContainer
                                        )
                                    )
                                }
                            }

                            // Carousel
                            VenueImageCarousel(
                                venue = venue,
                                height = 240.dp,
                                showCaptions = true,
                                showFullscreenButton = true,
                                showNavButtons = true
                            )
                        }
                    }

                    VenueMediaTab.VIDEO -> {
                        VenueVideoWalkthroughPlayer(
                            venue = venue,
                            modifier = Modifier
                                .fillMaxWidth()
                                .height(280.dp)
                        )
                    }

                    VenueMediaTab.VIRTUAL_3D -> {
                        Venue3dInteractiveWalkthrough(
                            venue = venue,
                            modifier = Modifier
                                .fillMaxWidth()
                                .height(280.dp)
                        )
                    }
                }
            }
        }
    }
}

@Composable
fun VenueVideoWalkthroughPlayer(
    venue: Venue,
    modifier: Modifier = Modifier
) {
    var isPlaying by remember { mutableStateOf(false) }
    var currentProgress by remember { mutableFloatStateOf(0.25f) }
    var isMuted by remember { mutableStateOf(true) }

    val video = remember(venue) {
        venue.videos.firstOrNull() ?: VenueVideo(
            id = "vid_${venue.id}",
            title = "${venue.name} - 4K High Speed Tour",
            videoUrl = "https://example.com/video_${venue.id}.mp4",
            thumbnailUrl = venue.coverImageUrl,
            durationSeconds = 45
        )
    }

    LaunchedEffect(isPlaying) {
        if (isPlaying) {
            while (isPlaying) {
                delay(300)
                currentProgress = (currentProgress + 0.02f).let { if (it > 1f) 0f else it }
            }
        }
    }

    Box(
        modifier = modifier
            .background(Color.Black)
            .testTag("venue_video_player")
    ) {
        AsyncImage(
            model = ImageRequest.Builder(LocalContext.current)
                .data(video.thumbnailUrl.ifBlank { venue.coverImageUrl })
                .crossfade(true)
                .build(),
            contentDescription = video.title,
            contentScale = ContentScale.Crop,
            modifier = Modifier.fillMaxSize()
        )

        // Dark overlay
        Box(
            modifier = Modifier
                .fillMaxSize()
                .background(
                    Brush.verticalGradient(
                        colors = listOf(
                            Color.Black.copy(alpha = 0.4f),
                            Color.Transparent,
                            Color.Black.copy(alpha = 0.75f)
                        )
                    )
                )
        )

        // Top Info Bar
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .align(Alignment.TopStart)
                .padding(12.dp),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically
        ) {
            Surface(
                color = Color.Black.copy(alpha = 0.6f),
                shape = RoundedCornerShape(8.dp)
            ) {
                Row(
                    modifier = Modifier.padding(horizontal = 8.dp, vertical = 4.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Box(
                        modifier = Modifier
                            .size(8.dp)
                            .clip(CircleShape)
                            .background(if (isPlaying) Color(0xFFEF4444) else Color(0xFF10B981))
                    )
                    Spacer(modifier = Modifier.width(6.dp))
                    Text(
                        text = if (isPlaying) "PLAYING SHORT TOUR" else "VERIFIED OWNER VIDEO",
                        color = Color.White,
                        fontSize = 9.sp,
                        fontWeight = FontWeight.Bold
                    )
                }
            }

            IconButton(
                onClick = { isMuted = !isMuted },
                modifier = Modifier
                    .size(32.dp)
                    .background(Color.Black.copy(alpha = 0.6f), CircleShape)
            ) {
                Icon(
                    imageVector = if (isMuted) Icons.Default.VolumeOff else Icons.Default.VolumeUp,
                    contentDescription = "Mute Toggle",
                    tint = Color.White,
                    modifier = Modifier.size(16.dp)
                )
            }
        }

        // Center Play/Pause Floating Action
        IconButton(
            onClick = { isPlaying = !isPlaying },
            modifier = Modifier
                .align(Alignment.Center)
                .size(60.dp)
                .background(MaterialTheme.colorScheme.primary.copy(alpha = 0.9f), CircleShape)
                .testTag("video_play_pause_button")
        ) {
            Icon(
                imageVector = if (isPlaying) Icons.Default.Pause else Icons.Default.PlayArrow,
                contentDescription = if (isPlaying) "Pause" else "Play",
                tint = Color.White,
                modifier = Modifier.size(32.dp)
            )
        }

        // Bottom Controls Bar
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .align(Alignment.BottomCenter)
                .padding(12.dp)
        ) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Text(
                    text = video.title,
                    color = Color.White,
                    fontSize = 12.sp,
                    fontWeight = FontWeight.Bold
                )
                Text(
                    text = "${(currentProgress * video.durationSeconds).toInt()}s / ${video.durationSeconds}s",
                    color = Color.White.copy(alpha = 0.8f),
                    fontSize = 11.sp
                )
            }

            Spacer(modifier = Modifier.height(6.dp))

            // Progress Slider
            Slider(
                value = currentProgress,
                onValueChange = { currentProgress = it },
                modifier = Modifier
                    .fillMaxWidth()
                    .height(20.dp),
                colors = SliderDefaults.colors(
                    thumbColor = MaterialTheme.colorScheme.primary,
                    activeTrackColor = MaterialTheme.colorScheme.primary,
                    inactiveTrackColor = Color.White.copy(alpha = 0.3f)
                )
            )
        }
    }
}

@Composable
fun Venue3dInteractiveWalkthrough(
    venue: Venue,
    modifier: Modifier = Modifier
) {
    var panOffsetAngle by remember { mutableFloatStateOf(0f) }
    var selectedHotspot by remember { mutableStateOf("Grand Stage") }
    var zoomLevel by remember { mutableFloatStateOf(1.0f) }

    val walkthrough = remember(venue) {
        venue.virtual3dTour ?: Venue3dWalkthrough(
            id = "tour_${venue.id}",
            title = "360° VR & 3D Walkthrough Tour",
            tourUrl = "https://matterport.com/discover/space/${venue.id}",
            previewImageUrl = venue.coverImageUrl,
            tourType = "360_PANORAMA",
            hotspots = listOf("Grand Stage", "Dining Arena", "VIP Suites", "Lawn Grounds", "Entrance Foyer")
        )
    }

    Box(
        modifier = modifier
            .background(Color(0xFF030712))
            .pointerInput(Unit) {
                detectDragGestures { change, dragAmount ->
                    change.consume()
                    panOffsetAngle = (panOffsetAngle + dragAmount.x * 0.4f) % 360f
                }
            }
            .testTag("venue_3d_walkthrough_viewer")
    ) {
        // Simulated 360 View layer with interactive horizontal pan
        AsyncImage(
            model = ImageRequest.Builder(LocalContext.current)
                .data(walkthrough.previewImageUrl.ifBlank { venue.coverImageUrl })
                .crossfade(true)
                .build(),
            contentDescription = "360 Tour Panoramic View",
            contentScale = ContentScale.Crop,
            modifier = Modifier
                .fillMaxSize()
                .graphicsLayer {
                    translationX = panOffsetAngle
                    scaleX = zoomLevel
                    scaleY = zoomLevel
                }
        )

        // Glass Depth & Vignette Grid Overlay
        Box(
            modifier = Modifier
                .fillMaxSize()
                .background(
                    Brush.radialGradient(
                        colors = listOf(Color.Transparent, Color.Black.copy(alpha = 0.65f))
                    )
                )
        )

        // Top Status Header
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .align(Alignment.TopStart)
                .padding(12.dp),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically
        ) {
            Surface(
                color = Color(0xFF0F172A).copy(alpha = 0.85f),
                border = BorderStroke(1.dp, Color(0xFF38BDF8)),
                shape = RoundedCornerShape(8.dp)
            ) {
                Row(
                    modifier = Modifier.padding(horizontal = 8.dp, vertical = 4.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Icon(
                        imageVector = Icons.Default.ViewInAr,
                        contentDescription = null,
                        tint = Color(0xFF38BDF8),
                        modifier = Modifier.size(14.dp)
                    )
                    Spacer(modifier = Modifier.width(6.dp))
                    Text(
                        text = "360° INTERACTIVE VIRTUAL TOUR",
                        color = Color(0xFF38BDF8),
                        fontSize = 9.sp,
                        fontWeight = FontWeight.ExtraBold
                    )
                }
            }

            // Pan hint chip
            Surface(
                color = Color.Black.copy(alpha = 0.6f),
                shape = RoundedCornerShape(20.dp)
            ) {
                Row(
                    modifier = Modifier.padding(horizontal = 8.dp, vertical = 4.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Icon(Icons.Default.TouchApp, contentDescription = null, tint = Color.White, modifier = Modifier.size(13.dp))
                    Spacer(modifier = Modifier.width(4.dp))
                    Text("Drag to rotate 360°", color = Color.White, fontSize = 9.5.sp)
                }
            }
        }

        // Center Compass Reticle
        Box(
            modifier = Modifier
                .align(Alignment.Center)
                .size(44.dp)
                .border(1.5.dp, Color.White.copy(alpha = 0.4f), CircleShape),
            contentAlignment = Alignment.Center
        ) {
            Box(
                modifier = Modifier
                    .size(6.dp)
                    .clip(CircleShape)
                    .background(Color(0xFF38BDF8))
            )
        }

        // Bottom Hotspot Navigation Selector
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .align(Alignment.BottomCenter)
                .padding(12.dp)
        ) {
            Text(
                text = "ROOM / ANGLE HOTSPOTS",
                fontSize = 9.5.sp,
                fontWeight = FontWeight.Bold,
                color = Color.White.copy(alpha = 0.8f),
                letterSpacing = 0.5.sp
            )
            Spacer(modifier = Modifier.height(4.dp))

            LazyRow(
                horizontalArrangement = Arrangement.spacedBy(6.dp),
                modifier = Modifier.fillMaxWidth()
            ) {
                items(walkthrough.hotspots) { hotspot ->
                    val isSelected = selectedHotspot == hotspot
                    Surface(
                        modifier = Modifier
                            .clip(RoundedCornerShape(10.dp))
                            .clickable {
                                selectedHotspot = hotspot
                                panOffsetAngle += 90f
                            },
                        color = if (isSelected) Color(0xFF38BDF8) else Color.Black.copy(alpha = 0.65f),
                        border = if (!isSelected) BorderStroke(1.dp, Color.White.copy(alpha = 0.3f)) else null,
                        shape = RoundedCornerShape(10.dp)
                    ) {
                        Text(
                            text = "📍 $hotspot",
                            fontSize = 11.sp,
                            fontWeight = if (isSelected) FontWeight.Bold else FontWeight.Normal,
                            color = if (isSelected) Color.Black else Color.White,
                            modifier = Modifier.padding(horizontal = 10.dp, vertical = 5.dp)
                        )
                    }
                }
            }
        }
    }
}
