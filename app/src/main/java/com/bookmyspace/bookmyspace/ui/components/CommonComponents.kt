package com.bookmyspace.bookmyspace.ui.components

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.AnimatedVisibilityScope
import androidx.compose.animation.ExperimentalSharedTransitionApi
import androidx.compose.animation.SharedTransitionScope
import androidx.compose.animation.core.animateDpAsState
import androidx.compose.animation.core.tween
import androidx.compose.animation.expandVertically
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.shrinkVertically
import androidx.compose.foundation.gestures.detectDragGestures
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.material.icons.filled.ExpandLess
import androidx.compose.material.icons.filled.ExpandMore
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.pager.HorizontalPager
import androidx.compose.foundation.pager.rememberPagerState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Bookmark
import androidx.compose.material.icons.filled.BookmarkBorder
import androidx.compose.material.icons.filled.Call
import androidx.compose.material.icons.filled.ChevronLeft
import androidx.compose.material.icons.filled.ChevronRight
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.DragIndicator
import androidx.compose.material.icons.filled.Fullscreen
import androidx.compose.material.icons.filled.LocationOn
import androidx.compose.material.icons.filled.Navigation
import androidx.compose.material.icons.filled.NearMe
import androidx.compose.material.icons.filled.SmartToy
import androidx.compose.material.icons.filled.Star
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.font.FontStyle
import androidx.compose.ui.unit.IntOffset
import androidx.compose.ui.window.Dialog
import androidx.compose.ui.window.DialogProperties
import kotlin.math.roundToInt
import kotlinx.coroutines.launch
import com.bookmyspace.bookmyspace.data.repository.BookMySpaceRepository
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import android.content.Intent
import android.net.Uri
import androidx.compose.ui.platform.LocalContext
import androidx.compose.material.icons.filled.Call
import androidx.compose.material.icons.filled.Chat
import coil.compose.AsyncImage
import androidx.compose.material.icons.filled.Apartment
import com.bookmyspace.bookmyspace.data.model.Course
import com.bookmyspace.bookmyspace.data.model.Event
import com.bookmyspace.bookmyspace.data.model.Venue
import com.bookmyspace.bookmyspace.util.PgRentCalculator
import com.bookmyspace.bookmyspace.util.VenueImageResolver
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.rememberScrollState
import androidx.compose.material.icons.filled.AcUnit
import androidx.compose.material.icons.filled.AccessTime
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.DirectionsCar
import androidx.compose.material.icons.filled.EventAvailable
import androidx.compose.material.icons.filled.FlashOn
import androidx.compose.material.icons.filled.Payments
import androidx.compose.material.icons.filled.PhotoCamera
import androidx.compose.material.icons.filled.Restaurant
import androidx.compose.material.icons.filled.Verified
import androidx.compose.material.icons.filled.VolumeUp
import androidx.compose.material.icons.filled.Wifi
import com.bookmyspace.bookmyspace.data.model.TimeSlot
import coil.request.ImageRequest
import coil.compose.AsyncImage

import androidx.compose.foundation.Canvas
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.onClick
import androidx.compose.ui.semantics.role
import androidx.compose.ui.semantics.semantics
import com.bookmyspace.bookmyspace.ui.theme.MidnightNavy
import com.bookmyspace.bookmyspace.ui.theme.RoyalBlue
import com.bookmyspace.bookmyspace.ui.theme.SaffronGold

@Composable
fun BookMySpaceBrandSymbol(
    modifier: Modifier = Modifier,
    isDarkBackground: Boolean = false
) {
    BMSLogoIconBadge(
        size = 38.dp,
        modifier = modifier
    )
}

@Composable
fun BookMySpaceLogo(
    modifier: Modifier = Modifier,
    showSubtext: Boolean = true,
    isDarkBackground: Boolean = false,
    symbolSize: androidx.compose.ui.unit.Dp = 38.dp
) {
    BMSBrandLogo(
        size = symbolSize,
        showText = true,
        subtitle = if (showSubtext) "Turfs • Halls • PGs • Studios" else null,
        modifier = modifier.testTag("bookmyspace_logo")
    )
}

@Composable
fun RatingBadge(rating: Double, count: Int = 0) {
    Surface(
        color = MaterialTheme.colorScheme.primaryContainer,
        shape = RoundedCornerShape(8.dp)
    ) {
        Row(
            modifier = Modifier.padding(horizontal = 6.dp, vertical = 2.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Icon(
                imageVector = Icons.Default.Star,
                contentDescription = null,
                tint = Color(0xFFFFB800),
                modifier = Modifier.size(14.dp)
            )
            Spacer(modifier = Modifier.width(2.dp))
            Text(
                text = "$rating",
                fontSize = 12.sp,
                fontWeight = FontWeight.Bold,
                color = MaterialTheme.colorScheme.onPrimaryContainer
            )
            if (count > 0) {
                Text(
                    text = " ($count)",
                    fontSize = 10.sp,
                    color = MaterialTheme.colorScheme.onPrimaryContainer.copy(alpha = 0.7f)
                )
            }
        }
    }
}

@Composable
fun VenueImageCarousel(
    venue: Venue,
    height: androidx.compose.ui.unit.Dp = 220.dp,
    showCaptions: Boolean = true,
    showFullscreenButton: Boolean = false,
    showNavButtons: Boolean = false,
    targetPage: Int = 0,
    onImageClick: () -> Unit = {}
) {
    val images = remember(venue) {
        val gallery = VenueImageResolver.resolveGalleryImages(venue)
        if (gallery.isEmpty()) listOf(venue.coverImageUrl.ifBlank { "https://images.unsplash.com/photo-1519167758481-83f550bb49b3?w=800" }) else gallery
    }

    val pagerState = rememberPagerState(initialPage = 0, pageCount = { images.size })
    val scope = rememberCoroutineScope()
    var showFullscreenDialog by remember { mutableStateOf(false) }

    LaunchedEffect(targetPage) {
        if (targetPage in 0 until images.size && targetPage != pagerState.currentPage) {
            pagerState.animateScrollToPage(targetPage)
        }
    }

    Box(
        modifier = Modifier
            .fillMaxWidth()
            .height(height)
    ) {
        HorizontalPager(
            state = pagerState,
            modifier = Modifier
                .fillMaxSize()
                .clickable { onImageClick() }
        ) { page ->
            val imageUrl = images[page]
            AsyncImage(
                model = ImageRequest.Builder(LocalContext.current)
                    .data(imageUrl)
                    .crossfade(true)
                    .build(),
                contentDescription = "${venue.name} photo ${page + 1}",
                contentScale = ContentScale.Crop,
                modifier = Modifier.fillMaxSize()
            )
        }

        // Gradient scrim at bottom for text readability
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .height(60.dp)
                .align(Alignment.BottomCenter)
                .background(
                    androidx.compose.ui.graphics.Brush.verticalGradient(
                        colors = listOf(Color.Transparent, Color.Black.copy(alpha = 0.6f))
                    )
                )
        )

        // Navigation Chevron Buttons
        if (showNavButtons && images.size > 1) {
            if (pagerState.currentPage > 0) {
                IconButton(
                    onClick = {
                        scope.launch {
                            pagerState.animateScrollToPage(pagerState.currentPage - 1)
                        }
                    },
                    modifier = Modifier
                        .align(Alignment.CenterStart)
                        .padding(start = 6.dp)
                        .size(32.dp)
                        .background(Color.Black.copy(alpha = 0.5f), CircleShape)
                ) {
                    Icon(
                        imageVector = Icons.Default.ChevronLeft,
                        contentDescription = "Previous Image",
                        tint = Color.White,
                        modifier = Modifier.size(18.dp)
                    )
                }
            }

            if (pagerState.currentPage < images.size - 1) {
                IconButton(
                    onClick = {
                        scope.launch {
                            pagerState.animateScrollToPage(pagerState.currentPage + 1)
                        }
                    },
                    modifier = Modifier
                        .align(Alignment.CenterEnd)
                        .padding(end = 6.dp)
                        .size(32.dp)
                        .background(Color.Black.copy(alpha = 0.5f), CircleShape)
                ) {
                    Icon(
                        imageVector = Icons.Default.ChevronRight,
                        contentDescription = "Next Image",
                        tint = Color.White,
                        modifier = Modifier.size(18.dp)
                    )
                }
            }
        }

        // Fullscreen expand button
        if (showFullscreenButton) {
            IconButton(
                onClick = { showFullscreenDialog = true },
                modifier = Modifier
                    .align(Alignment.BottomEnd)
                    .padding(8.dp)
                    .size(28.dp)
                    .background(Color.Black.copy(alpha = 0.5f), CircleShape)
            ) {
                Icon(
                    imageVector = Icons.Default.Fullscreen,
                    contentDescription = "Fullscreen Gallery",
                    tint = Color.White,
                    modifier = Modifier.size(16.dp)
                )
            }
        }

        // Page Indicator Dots / Pill
        if (images.size > 1) {
            Surface(
                color = Color.Black.copy(alpha = 0.6f),
                shape = RoundedCornerShape(12.dp),
                modifier = Modifier
                    .align(Alignment.BottomCenter)
                    .padding(bottom = 8.dp)
            ) {
                Text(
                    text = "${pagerState.currentPage + 1} / ${images.size}",
                    color = Color.White,
                    fontSize = 11.sp,
                    fontWeight = FontWeight.Bold,
                    modifier = Modifier.padding(horizontal = 8.dp, vertical = 2.dp)
                )
            }
        }
    }

    // Fullscreen Image Viewer Dialog
    if (showFullscreenDialog) {
        Dialog(
            onDismissRequest = { showFullscreenDialog = false },
            properties = DialogProperties(usePlatformDefaultWidth = false)
        ) {
            val fullscreenPagerState = rememberPagerState(
                initialPage = pagerState.currentPage,
                pageCount = { images.size }
            )
            Box(
                modifier = Modifier
                    .fillMaxSize()
                    .background(Color.Black)
            ) {
                HorizontalPager(
                    state = fullscreenPagerState,
                    modifier = Modifier.fillMaxSize()
                ) { page ->
                    Box(
                        modifier = Modifier.fillMaxSize(),
                        contentAlignment = Alignment.Center
                    ) {
                        AsyncImage(
                            model = images[page],
                            contentDescription = "${venue.name} full photo ${page + 1}",
                            contentScale = ContentScale.Fit,
                            modifier = Modifier.fillMaxSize()
                        )
                    }
                }

                // Close Button
                IconButton(
                    onClick = { showFullscreenDialog = false },
                    modifier = Modifier
                        .align(Alignment.TopEnd)
                        .padding(16.dp)
                        .background(Color.Black.copy(alpha = 0.6f), CircleShape)
                ) {
                    Icon(Icons.Default.Close, contentDescription = "Close", tint = Color.White)
                }

                // Image counter
                Surface(
                    color = Color.Black.copy(alpha = 0.7f),
                    shape = RoundedCornerShape(12.dp),
                    modifier = Modifier
                        .align(Alignment.BottomCenter)
                        .padding(bottom = 24.dp)
                ) {
                    Text(
                        text = "${fullscreenPagerState.currentPage + 1} / ${images.size}",
                        color = Color.White,
                        fontSize = 13.sp,
                        fontWeight = FontWeight.Bold,
                        modifier = Modifier.padding(horizontal = 12.dp, vertical = 4.dp)
                    )
                }
            }
        }
    }
}

@OptIn(ExperimentalSharedTransitionApi::class)
@Composable
fun VenueCard(
    venue: Venue,
    onClick: () -> Unit,
    onFavoriteToggle: () -> Unit,
    modifier: Modifier = Modifier,
    sharedTransitionScope: SharedTransitionScope? = null,
    animatedVisibilityScope: AnimatedVisibilityScope? = null
) {
    val cardContext = LocalContext.current
    val coverUrl = remember(venue) { VenueImageResolver.resolveCoverImage(venue) }

    val displayPrice = remember(venue) {
        if (venue.pgDetails != null || venue.category?.slug == "pg_hostel") {
            val breakdown = PgRentCalculator.calculate(venue)
            "₹%,d".format(breakdown.monthlyBaseRent.toInt()) to "/mo"
        } else {
            "₹%,d".format(venue.pricingBaseAmount.toInt()) to if (venue.category?.slug in listOf("sports", "sports_turf", "dance_academy", "music_class")) "/hr" else " starts"
        }
    }

    val displayAmenities = remember(venue) {
        val list = mutableListOf<String>()
        if (venue.pgDetails != null || venue.category?.slug == "pg_hostel") {
            list.add(venue.pgDetails?.pgType ?: "Co-living")
            if (venue.pgDetails?.mealPlan?.isNotBlank() == true) list.add("Meals Included")
        } else {
            if (venue.capacity > 0) list.add("${venue.capacity} Guests")
            if (venue.parkingCapacity > 0) list.add("${venue.parkingCapacity}+ Parking")
        }
        venue.facilities.take(2).forEach { list.add(it.facility) }
        list.take(3)
    }

    Card(
        onClick = onClick,
        modifier = modifier
            .fillMaxWidth()
            .testTag("venue_card_${venue.id}"),
        shape = RoundedCornerShape(16.dp),
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface),
        elevation = CardDefaults.cardElevation(defaultElevation = 2.dp)
    ) {
        Column(modifier = Modifier.fillMaxWidth()) {
            // 1. Compact Fixed-Height Media Banner with Compact Overlays
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .height(145.dp)
            ) {
                AsyncImage(
                    model = coverUrl,
                    contentDescription = venue.name,
                    contentScale = ContentScale.Crop,
                    modifier = Modifier
                        .fillMaxSize()
                        .background(MaterialTheme.colorScheme.surfaceVariant)
                )

                // Top Gradient Scrim for Contrast
                Box(
                    modifier = Modifier
                        .fillMaxSize()
                        .background(
                            Brush.verticalGradient(
                                colors = listOf(
                                    Color.Black.copy(alpha = 0.55f),
                                    Color.Transparent,
                                    Color.Black.copy(alpha = 0.65f)
                                )
                            )
                        )
                )

                // Category & Verified Badge Overlay (Top Start)
                Row(
                    modifier = Modifier
                        .align(Alignment.TopStart)
                        .padding(8.dp),
                    horizontalArrangement = Arrangement.spacedBy(5.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    val categoryName = venue.category?.name ?: "Space"
                    Surface(
                        color = MaterialTheme.colorScheme.primaryContainer.copy(alpha = 0.92f),
                        shape = RoundedCornerShape(6.dp)
                    ) {
                        Text(
                            text = categoryName,
                            fontSize = 10.sp,
                            fontWeight = FontWeight.Bold,
                            color = MaterialTheme.colorScheme.onPrimaryContainer,
                            modifier = Modifier.padding(horizontal = 7.dp, vertical = 3.dp)
                        )
                    }

                    if (venue.isVerified) {
                        Surface(
                            color = Color(0xFF2E7D32).copy(alpha = 0.90f),
                            shape = RoundedCornerShape(6.dp)
                        ) {
                            Row(
                                modifier = Modifier.padding(horizontal = 6.dp, vertical = 3.dp),
                                verticalAlignment = Alignment.CenterVertically,
                                horizontalArrangement = Arrangement.spacedBy(2.dp)
                            ) {
                                Icon(
                                    imageVector = Icons.Default.Verified,
                                    contentDescription = "Verified Venue",
                                    tint = Color.White,
                                    modifier = Modifier.size(10.dp)
                                )
                                Text(
                                    text = "VERIFIED",
                                    fontSize = 9.sp,
                                    fontWeight = FontWeight.ExtraBold,
                                    color = Color.White
                                )
                            }
                        }
                    }
                }

                // Favorite Icon (Top End)
                IconButton(
                    onClick = onFavoriteToggle,
                    modifier = Modifier
                        .align(Alignment.TopEnd)
                        .padding(6.dp)
                        .size(32.dp)
                        .background(Color.Black.copy(alpha = 0.45f), CircleShape)
                ) {
                    Icon(
                        imageVector = if (venue.isSaved) Icons.Default.Bookmark else Icons.Default.BookmarkBorder,
                        contentDescription = "Save Venue",
                        tint = if (venue.isSaved) MaterialTheme.colorScheme.tertiary else Color.White,
                        modifier = Modifier.size(18.dp)
                    )
                }

                // Rating Badge (Bottom Start)
                Surface(
                    color = Color.Black.copy(alpha = 0.72f),
                    shape = RoundedCornerShape(6.dp),
                    modifier = Modifier
                        .align(Alignment.BottomStart)
                        .padding(8.dp)
                ) {
                    Row(
                        modifier = Modifier.padding(horizontal = 7.dp, vertical = 3.dp),
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.spacedBy(3.dp)
                    ) {
                        Text("⭐", fontSize = 10.sp)
                        Text(
                            text = "${venue.avgRating}",
                            fontSize = 11.sp,
                            fontWeight = FontWeight.Bold,
                            color = Color.White
                        )
                        Text(
                            text = "(${venue.ratingCount})",
                            fontSize = 9.5.sp,
                            color = Color.White.copy(alpha = 0.8f)
                        )
                    }
                }

                // Distance Badge (Bottom End)
                Surface(
                    color = Color.Black.copy(alpha = 0.72f),
                    shape = RoundedCornerShape(6.dp),
                    modifier = Modifier
                        .align(Alignment.BottomEnd)
                        .padding(8.dp)
                ) {
                    Row(
                        modifier = Modifier.padding(horizontal = 7.dp, vertical = 3.dp),
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.spacedBy(3.dp)
                    ) {
                        Icon(
                            imageVector = Icons.Default.NearMe,
                            contentDescription = null,
                            tint = Color.White,
                            modifier = Modifier.size(10.dp)
                        )
                        Text(
                            text = "${venue.distanceKm} km",
                            fontSize = 10.5.sp,
                            fontWeight = FontWeight.SemiBold,
                            color = Color.White
                        )
                    }
                }
            }

            // 2. Compact Body Details
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(12.dp)
            ) {
                // Row 1: Name and Price
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Text(
                        text = venue.name,
                        fontSize = 15.sp,
                        fontWeight = FontWeight.Bold,
                        color = MaterialTheme.colorScheme.onSurface,
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis,
                        modifier = Modifier.weight(1f)
                    )
                    Spacer(modifier = Modifier.width(8.dp))
                    Row(verticalAlignment = Alignment.Bottom) {
                        Text(
                            text = displayPrice.first,
                            fontSize = 16.sp,
                            fontWeight = FontWeight.ExtraBold,
                            color = MaterialTheme.colorScheme.primary
                        )
                        Text(
                            text = displayPrice.second,
                            fontSize = 10.sp,
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                            modifier = Modifier.padding(bottom = 1.dp)
                        )
                    }
                }

                Spacer(modifier = Modifier.height(3.dp))

                // Row 2: Location
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    modifier = Modifier.fillMaxWidth()
                ) {
                    Icon(
                        imageVector = Icons.Default.LocationOn,
                        contentDescription = null,
                        modifier = Modifier.size(13.dp),
                        tint = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                    Spacer(modifier = Modifier.width(3.dp))
                    Text(
                        text = venue.fullAddress,
                        fontSize = 11.5.sp,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis
                    )
                }

                Spacer(modifier = Modifier.height(6.dp))

                // Row 3: 2-3 Key Details Chips
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.spacedBy(5.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    displayAmenities.forEach { amenity ->
                        Surface(
                            shape = RoundedCornerShape(6.dp),
                            color = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.55f)
                        ) {
                            Text(
                                text = amenity,
                                fontSize = 10.sp,
                                fontWeight = FontWeight.Medium,
                                color = MaterialTheme.colorScheme.onSurfaceVariant,
                                modifier = Modifier.padding(horizontal = 6.dp, vertical = 2.dp),
                                maxLines = 1
                            )
                        }
                    }
                }

                Spacer(modifier = Modifier.height(10.dp))
                HorizontalDivider(color = MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.35f))
                Spacer(modifier = Modifier.height(8.dp))

                // Row 4: Compact Action Strip (Book, Call, Directions)
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.spacedBy(6.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Button(
                        onClick = onClick,
                        shape = RoundedCornerShape(10.dp),
                        modifier = Modifier
                            .weight(1f)
                            .height(38.dp)
                            .testTag("venue_card_cta_${venue.id}"),
                        contentPadding = PaddingValues(horizontal = 10.dp, vertical = 4.dp)
                    ) {
                        Text(
                            text = if (venue.pgDetails != null || venue.category?.slug == "pg_hostel") "View Rooms" else "⚡ Book Slot",
                            fontSize = 12.sp,
                            fontWeight = FontWeight.Bold
                        )
                    }

                    OutlinedIconButton(
                        onClick = {
                            val intent = Intent(Intent.ACTION_DIAL, Uri.parse("tel:${venue.contactPhone}"))
                            cardContext.startActivity(intent)
                        },
                        modifier = Modifier.size(38.dp),
                        shape = RoundedCornerShape(10.dp)
                    ) {
                        Icon(
                            Icons.Default.Call,
                            contentDescription = "Call ${venue.name}",
                            modifier = Modifier.size(16.dp),
                            tint = MaterialTheme.colorScheme.primary
                        )
                    }

                    FilledTonalIconButton(
                        onClick = {
                            launchGoogleMapsDirections(cardContext, venue.latitude, venue.longitude, venue.name)
                        },
                        modifier = Modifier.size(38.dp),
                        shape = RoundedCornerShape(10.dp)
                    ) {
                        Icon(
                            Icons.Default.Navigation,
                            contentDescription = "Directions to ${venue.name}",
                            modifier = Modifier.size(16.dp),
                            tint = Color(0xFFD84315)
                        )
                    }
                }
            }
        }
    }
}

@Composable
fun VenueCarouselCard(
    venue: Venue,
    onClick: () -> Unit,
    onFavoriteToggle: () -> Unit,
    modifier: Modifier = Modifier
) {
    var isSaved by remember { mutableStateOf(false) }
    val imageUrl = remember(venue) {
        venue.images.firstOrNull()?.url ?: "https://images.unsplash.com/photo-1519167758481-83f550bb49b3?w=800"
    }

    Card(
        modifier = modifier
            .width(265.dp)
            .clickable { onClick() }
            .testTag("venue_carousel_card_${venue.id}"),
        shape = RoundedCornerShape(16.dp),
        colors = CardDefaults.cardColors(containerColor = Color.White),
        border = BorderStroke(1.dp, Color(0xFFE2E8F0)),
        elevation = CardDefaults.cardElevation(defaultElevation = 2.dp)
    ) {
        Column {
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .height(130.dp)
            ) {
                AsyncImage(
                    model = imageUrl,
                    contentDescription = venue.name,
                    contentScale = ContentScale.Crop,
                    modifier = Modifier.fillMaxSize()
                )

                // Top Left '✔ Verified' Badge
                Surface(
                    color = Color(0xFF16A34A),
                    shape = RoundedCornerShape(6.dp),
                    modifier = Modifier
                        .align(Alignment.TopStart)
                        .padding(8.dp)
                ) {
                    Row(
                        modifier = Modifier.padding(horizontal = 6.dp, vertical = 2.dp),
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.spacedBy(3.dp)
                    ) {
                        Text(
                            text = "✔ Verified",
                            fontSize = 10.sp,
                            fontWeight = FontWeight.Bold,
                            color = Color.White
                        )
                    }
                }

                // Top Right Heart Button
                Surface(
                    onClick = {
                        isSaved = !isSaved
                        onFavoriteToggle()
                    },
                    color = Color.Black.copy(alpha = 0.35f),
                    shape = CircleShape,
                    modifier = Modifier
                        .align(Alignment.TopEnd)
                        .padding(8.dp)
                        .size(28.dp)
                ) {
                    Box(contentAlignment = Alignment.Center) {
                        Icon(
                            imageVector = if (isSaved) Icons.Default.Bookmark else Icons.Default.BookmarkBorder,
                            contentDescription = "Save Venue",
                            tint = Color.White,
                            modifier = Modifier.size(16.dp)
                        )
                    }
                }
            }

            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 12.dp, vertical = 10.dp)
            ) {
                Text(
                    text = venue.name,
                    fontSize = 14.sp,
                    fontWeight = FontWeight.Bold,
                    color = Color(0xFF0F172A),
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis
                )

                Spacer(modifier = Modifier.height(3.dp))

                Row(verticalAlignment = Alignment.CenterVertically) {
                    Icon(
                        imageVector = Icons.Default.LocationOn,
                        contentDescription = null,
                        tint = Color(0xFF64748B),
                        modifier = Modifier.size(13.dp)
                    )
                    Spacer(modifier = Modifier.width(3.dp))
                    val locationLabel = venue.addressLine1.ifBlank { venue.city }
                    Text(
                        text = "$locationLabel, ${venue.city}",
                        fontSize = 11.sp,
                        color = Color(0xFF64748B),
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis
                    )
                }

                Spacer(modifier = Modifier.height(6.dp))

                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Text(
                            text = "★",
                            color = Color(0xFFF59E0B),
                            fontSize = 13.sp,
                            fontWeight = FontWeight.Bold
                        )
                        Spacer(modifier = Modifier.width(3.dp))
                        Text(
                            text = "${venue.avgRating}",
                            fontSize = 11.5.sp,
                            fontWeight = FontWeight.Bold,
                            color = Color(0xFF0F172A)
                        )
                        Text(
                            text = " (${venue.ratingCount})",
                            fontSize = 11.sp,
                            color = Color(0xFF64748B)
                        )
                    }

                    Text(
                        text = "₹%,d onwards".format(venue.pricingBaseAmount.toInt()),
                        fontSize = 12.sp,
                        fontWeight = FontWeight.Bold,
                        color = Color(0xFF4F46E5)
                    )
                }
            }
        }
    }
}

@Composable
private fun AmenityChip(amenity: String) {
    val icon = when {
        amenity.contains("AC", true) || amenity.contains("Air", true) -> Icons.Default.AcUnit
        amenity.contains("WiFi", true) || amenity.contains("Internet", true) -> Icons.Default.Wifi
        amenity.contains("Parking", true) -> Icons.Default.DirectionsCar
        amenity.contains("Meal", true) || amenity.contains("Catering", true) || amenity.contains("Food", true) -> Icons.Default.Restaurant
        amenity.contains("Power", true) || amenity.contains("Backup", true) -> Icons.Default.FlashOn
        amenity.contains("Sound", true) || amenity.contains("Audio", true) -> Icons.Default.VolumeUp
        else -> Icons.Default.CheckCircle
    }

    Surface(
        color = MaterialTheme.colorScheme.secondaryContainer.copy(alpha = 0.5f),
        shape = RoundedCornerShape(8.dp),
        border = androidx.compose.foundation.BorderStroke(0.5.dp, MaterialTheme.colorScheme.outline.copy(alpha = 0.2f))
    ) {
        Row(
            modifier = Modifier.padding(horizontal = 8.dp, vertical = 4.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(4.dp)
        ) {
            Icon(
                imageVector = icon,
                contentDescription = null,
                tint = MaterialTheme.colorScheme.primary,
                modifier = Modifier.size(12.dp)
            )
            Text(
                text = amenity,
                fontSize = 10.5.sp,
                fontWeight = FontWeight.Medium,
                color = MaterialTheme.colorScheme.onSecondaryContainer
            )
        }
    }
}

@Composable
private fun TimeSlotChip(slot: TimeSlot, onClick: () -> Unit) {
    val statusBg = if (slot.isAvailable) Color(0xFFE8F5E9) else Color(0xFFFFEBEE)
    val statusBorder = if (slot.isAvailable) Color(0xFF81C784) else Color(0xFFE57373)
    val textPrimary = if (slot.isAvailable) Color(0xFF1B5E20) else Color(0xFFC62828)

    Surface(
        onClick = onClick,
        color = statusBg,
        shape = RoundedCornerShape(10.dp),
        border = androidx.compose.foundation.BorderStroke(1.dp, statusBorder)
    ) {
        Column(
            modifier = Modifier.padding(horizontal = 10.dp, vertical = 6.dp)
        ) {
            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(4.dp)
            ) {
                Icon(
                    imageVector = Icons.Default.AccessTime,
                    contentDescription = null,
                    tint = textPrimary,
                    modifier = Modifier.size(11.dp)
                )
                Text(
                    text = slot.label,
                    fontSize = 10.sp,
                    fontWeight = FontWeight.Bold,
                    color = textPrimary
                )
            }
            Text(
                text = "${slot.startTime} - ${slot.endTime}",
                fontSize = 9.5.sp,
                fontWeight = FontWeight.Medium,
                color = textPrimary.copy(alpha = 0.85f)
            )
            Text(
                text = "₹%,d".format(slot.priceAmount.toInt()),
                fontSize = 11.sp,
                fontWeight = FontWeight.ExtraBold,
                color = textPrimary
            )
        }
    }
}

private fun getVenueDisplayAmenitiesList(venue: Venue): List<String> {
    val existing = venue.facilities.map { it.facility }.filter { it.isNotBlank() }
    if (existing.isNotEmpty()) return existing.take(6)

    val categorySlug = venue.category?.slug ?: ""
    return when {
        categorySlug.contains("pg") || venue.pgDetails != null -> listOf("High-speed WiFi", "3 Meals Daily", "Air Conditioned", "24/7 Security", "Washing Machine", "Power Backup")
        categorySlug.contains("turf") || categorySlug.contains("sports") -> listOf("Floodlights", "Changing Rooms", "Free Parking", "Water Station", "Equipment Rental", "Pro Turf")
        categorySlug.contains("hotel") || venue.hotelDetails != null -> listOf("Luxury Rooms", "Swimming Pool", "Complimentary Breakfast", "24h Room Service", "Valet Parking", "Spa & Gym")
        else -> listOf("Air Conditioned", "${venue.parkingCapacity}+ Parking", "In-house Catering", "Power Backup", "Stage & Lighting", "Sound System")
    }
}

private fun getVenueDisplayTimeSlotsList(venue: Venue): List<TimeSlot> {
    if (venue.timeSlots.isNotEmpty()) return venue.timeSlots
    return listOf(
        TimeSlot(
            id = "slot_morn_${venue.id}",
            venueId = venue.id,
            label = "Morning Slot",
            startTime = "08:00 AM",
            endTime = "12:00 PM",
            priceAmount = (venue.pricingBaseAmount * 0.35).coerceAtLeast(1500.0),
            isAvailable = true
        ),
        TimeSlot(
            id = "slot_aft_${venue.id}",
            venueId = venue.id,
            label = "Afternoon Slot",
            startTime = "12:30 PM",
            endTime = "04:30 PM",
            priceAmount = (venue.pricingBaseAmount * 0.40).coerceAtLeast(2000.0),
            isAvailable = true
        ),
        TimeSlot(
            id = "slot_eve_${venue.id}",
            venueId = venue.id,
            label = "Evening Prime",
            startTime = "05:00 PM",
            endTime = "11:00 PM",
            priceAmount = (venue.pricingBaseAmount * 0.70).coerceAtLeast(3500.0),
            isAvailable = true
        )
    )
}


@Composable
fun EventCard(
    event: Event,
    onClick: () -> Unit,
    modifier: Modifier = Modifier
) {
    Card(
        modifier = modifier
            .width(280.dp)
            .clickable { onClick() },
        shape = RoundedCornerShape(16.dp),
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant)
    ) {
        Column(modifier = Modifier.padding(12.dp)) {
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .height(110.dp)
                    .clip(RoundedCornerShape(12.dp))
                    .background(MaterialTheme.colorScheme.primary.copy(alpha = 0.2f)),
                contentAlignment = Alignment.Center
            ) {
                Text(event.category, fontWeight = FontWeight.Bold, color = MaterialTheme.colorScheme.primary)
            }
            Spacer(modifier = Modifier.height(8.dp))
            Text(
                text = event.title,
                fontWeight = FontWeight.Bold,
                fontSize = 14.sp,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis
            )
            Spacer(modifier = Modifier.height(4.dp))
            Text(text = "📅 ${event.eventDate} • ${event.timeSlot}", fontSize = 11.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
            Spacer(modifier = Modifier.height(8.dp))
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Text(text = "₹${event.ticketPrice.toInt()}", fontWeight = FontWeight.ExtraBold, color = MaterialTheme.colorScheme.primary)
                Text(
                    text = if (event.isRegistered) "Registered ✓" else "${event.seatsBooked}/${event.totalSeats} seats",
                    fontSize = 11.sp,
                    color = if (event.isRegistered) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.onSurfaceVariant
                )
            }
        }
    }
}

@Composable
fun CourseCard(
    course: Course,
    onClick: () -> Unit,
    modifier: Modifier = Modifier
) {
    Card(
        modifier = modifier
            .fillMaxWidth()
            .clickable { onClick() },
        shape = RoundedCornerShape(16.dp),
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface)
    ) {
        Row(
            modifier = Modifier.padding(12.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Box(
                modifier = Modifier
                    .size(80.dp)
                    .clip(RoundedCornerShape(12.dp))
                    .background(MaterialTheme.colorScheme.secondary.copy(alpha = 0.2f)),
                contentAlignment = Alignment.Center
            ) {
                Text(course.level, fontSize = 10.sp, fontWeight = FontWeight.Bold, color = MaterialTheme.colorScheme.secondary)
            }
            Spacer(modifier = Modifier.width(12.dp))
            Column(modifier = Modifier.weight(1f)) {
                Text(text = course.title, fontWeight = FontWeight.Bold, fontSize = 15.sp, maxLines = 1)
                Text(text = course.academyName, fontSize = 12.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                Spacer(modifier = Modifier.height(4.dp))
                Text(text = "${course.durationWeeks} Weeks • ${course.schedule}", fontSize = 11.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                Spacer(modifier = Modifier.height(6.dp))
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Text(text = "₹${course.price.toInt()}", fontWeight = FontWeight.ExtraBold, color = MaterialTheme.colorScheme.primary)
                    if (course.isEnrolled) {
                        Surface(color = MaterialTheme.colorScheme.primaryContainer, shape = RoundedCornerShape(8.dp)) {
                            Text("Enrolled", modifier = Modifier.padding(horizontal = 8.dp, vertical = 2.dp), fontSize = 11.sp, fontWeight = FontWeight.Bold)
                        }
                    }
                }
            }
        }
    }
}

@Composable
fun ContextAwareHelpFab(
    currentRoute: String?,
    onNavigateToRoute: (String) -> Unit,
    modifier: Modifier = Modifier
) {
    var isChatbotOpen by remember { mutableStateOf(false) }
    var isChatbotMinimized by remember { mutableStateOf(false) }
    
    // Drag offsets for the floating helper
    var fabOffsetX by remember { mutableStateOf(0f) }
    var fabOffsetY by remember { mutableStateOf(0f) }

    if (isChatbotMinimized) {
        // Minimized Draggable Floating ChatBot Bubble
        DraggableFloatingChatBot(
            currentRoute = currentRoute,
            onNavigateToRoute = onNavigateToRoute,
            initialState = ChatBotDisplayState.MINIMIZED,
            onClose = {
                isChatbotMinimized = false
                isChatbotOpen = false
            },
            modifier = modifier
        )
    } else {
        // Draggable FAB that can be positioned anywhere on screen
        Surface(
            onClick = { isChatbotOpen = true },
            shape = RoundedCornerShape(24.dp),
            color = MaterialTheme.colorScheme.primaryContainer,
            shadowElevation = 6.dp,
            border = BorderStroke(1.dp, MaterialTheme.colorScheme.primary.copy(alpha = 0.4f)),
            modifier = modifier
                .offset { IntOffset(fabOffsetX.roundToInt(), fabOffsetY.roundToInt()) }
                .pointerInput(Unit) {
                    detectDragGestures { change, dragAmount ->
                        change.consume()
                        fabOffsetX += dragAmount.x
                        fabOffsetY += dragAmount.y
                    }
                }
                .testTag("help_fab")
        ) {
            Row(
                modifier = Modifier.padding(horizontal = 12.dp, vertical = 10.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                Icon(
                    Icons.Default.DragIndicator,
                    contentDescription = "Drag to reposition",
                    tint = MaterialTheme.colorScheme.onPrimaryContainer.copy(alpha = 0.5f),
                    modifier = Modifier.size(14.dp)
                )
                Spacer(modifier = Modifier.width(4.dp))
                Icon(
                    Icons.Default.SmartToy,
                    contentDescription = "Help Chatbot",
                    tint = MaterialTheme.colorScheme.primary,
                    modifier = Modifier.size(20.dp)
                )
                Spacer(modifier = Modifier.width(6.dp))
                Text(
                    "AI Help",
                    fontSize = 13.sp,
                    fontWeight = FontWeight.Bold,
                    color = MaterialTheme.colorScheme.onPrimaryContainer
                )
                Spacer(modifier = Modifier.width(4.dp))
                Box(
                    modifier = Modifier
                        .size(6.dp)
                        .clip(CircleShape)
                        .background(Color(0xFF2E7D32))
                )
            }
        }
    }

    if (isChatbotOpen) {
        HelpChatbotBottomSheet(
            currentRoute = currentRoute,
            onDismiss = {
                isChatbotOpen = false
            },
            onMinimize = {
                isChatbotOpen = false
                isChatbotMinimized = true
            },
            onNavigateToRoute = onNavigateToRoute
        )
    }
}

@Composable
fun QuickBookCard(
    onNavigateToVenue: (String) -> Unit,
    onAiHelpClick: () -> Unit = {},
    modifier: Modifier = Modifier
) {
    val venues by BookMySpaceRepository.venues.collectAsState()
    val topVenue = venues.firstOrNull() ?: return

    Card(
        modifier = modifier
            .fillMaxWidth()
            .clickable { onNavigateToVenue(topVenue.id) },
        shape = RoundedCornerShape(16.dp),
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.secondaryContainer.copy(alpha = 0.4f))
    ) {
        Row(
            modifier = Modifier.padding(14.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Box(
                modifier = Modifier
                    .size(44.dp)
                    .clip(CircleShape)
                    .background(MaterialTheme.colorScheme.primary),
                contentAlignment = Alignment.Center
            ) {
                Icon(Icons.Default.FlashOn, contentDescription = null, tint = Color.White, modifier = Modifier.size(24.dp))
            }
            Spacer(modifier = Modifier.width(12.dp))
            Column(modifier = Modifier.weight(1f)) {
                Text("⚡ 1-Tap Quick Book", fontWeight = FontWeight.Bold, fontSize = 13.sp)
                Text(topVenue.name, fontSize = 12.sp, color = MaterialTheme.colorScheme.onSurfaceVariant, maxLines = 1)
            }
            Button(
                onClick = { onNavigateToVenue(topVenue.id) },
                shape = RoundedCornerShape(8.dp),
                contentPadding = PaddingValues(horizontal = 12.dp, vertical = 6.dp)
            ) {
                Text("Book Now", fontSize = 11.sp, fontWeight = FontWeight.Bold)
            }
        }
    }
}

@Composable
fun VenueListSkeleton(count: Int = 3, modifier: Modifier = Modifier) {
    Column(
        modifier = modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp, vertical = 8.dp),
        verticalArrangement = Arrangement.spacedBy(14.dp)
    ) {
        repeat(count) {
            EyeCatchingVenueCardSkeleton()
        }
    }
}

@Composable
fun VenueMapSkeleton(modifier: Modifier = Modifier) {
    EyeCatchingVenueMapSkeleton(modifier = modifier)
}

/**
 * High-performance 3D Glassmorphic Surface with hardware-accelerated depth,
 * specular highlight border, and subtle frosted reflection gradient.
 */
@Composable
fun GlassmorphicCard(
    modifier: Modifier = Modifier,
    shape: androidx.compose.ui.graphics.Shape = RoundedCornerShape(20.dp),
    backgroundColor: Color = MaterialTheme.colorScheme.surface.copy(alpha = 0.85f),
    borderColor: Color = MaterialTheme.colorScheme.primary.copy(alpha = 0.25f),
    elevation: androidx.compose.ui.unit.Dp = 4.dp,
    onClick: (() -> Unit)? = null,
    content: @Composable ColumnScope.() -> Unit
) {
    val cardModifier = if (onClick != null) {
        modifier.clickable(onClick = onClick)
    } else {
        modifier
    }

    Surface(
        shape = shape,
        color = backgroundColor,
        shadowElevation = elevation,
        tonalElevation = 2.dp,
        border = BorderStroke(
            1.2.dp,
            androidx.compose.ui.graphics.Brush.linearGradient(
                colors = listOf(
                    borderColor.copy(alpha = 0.6f),
                    Color.White.copy(alpha = 0.15f),
                    borderColor.copy(alpha = 0.2f)
                )
            )
        ),
        modifier = cardModifier
    ) {
        Box(
            modifier = Modifier.background(
                androidx.compose.ui.graphics.Brush.verticalGradient(
                    colors = listOf(
                        Color.White.copy(alpha = 0.08f),
                        Color.Transparent,
                        Color.Black.copy(alpha = 0.03f)
                    )
                )
            )
        ) {
            Column(content = content)
        }
    }
}

