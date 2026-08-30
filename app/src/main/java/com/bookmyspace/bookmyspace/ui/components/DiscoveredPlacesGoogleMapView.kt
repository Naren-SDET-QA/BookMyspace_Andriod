package com.bookmyspace.bookmyspace.ui.components

import android.content.Context
import android.content.Intent
import android.net.Uri
import androidx.compose.animation.*
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.gestures.detectDragGestures
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.drawscope.DrawScope
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import coil.compose.AsyncImage
import com.bookmyspace.bookmyspace.data.model.PlaceDiscoveryModel
import kotlin.math.*

enum class DiscoveredMapType {
    NORMAL,
    SATELLITE,
    TERRAIN
}

/**
 * High-performance, fast-rendering Map View for Discovered Places & Venues.
 * Provides interactive panning, smooth zooming, category-colored markers, radius overlay,
 * venue details preview card, and instant Google Maps directions intent.
 */
@Composable
fun DiscoveredPlacesGoogleMapView(
    places: List<PlaceDiscoveryModel>,
    centerLatitude: Double,
    centerLongitude: Double,
    radiusKm: Double,
    locationTitle: String,
    selectedPlaceId: String? = null,
    onPlaceSelected: (PlaceDiscoveryModel) -> Unit = {},
    onNavigateToVenueDetails: (String) -> Unit = {},
    onClaimVenue: (PlaceDiscoveryModel) -> Unit = {},
    onRadiusChanged: (Double) -> Unit = {},
    modifier: Modifier = Modifier,
    isDarkTheme: Boolean = isSystemInDarkTheme()
) {
    val context = LocalContext.current

    var mapType by remember { mutableStateOf(DiscoveredMapType.NORMAL) }
    var currentZoom by remember { mutableFloatStateOf(13.5f) }
    var panOffsetX by remember { mutableFloatStateOf(0f) }
    var panOffsetY by remember { mutableFloatStateOf(0f) }

    // Reset pan offset when location changes
    LaunchedEffect(centerLatitude, centerLongitude) {
        panOffsetX = 0f
        panOffsetY = 0f
    }

    val selectedPlace = remember(selectedPlaceId, places) {
        places.find { it.id == selectedPlaceId } ?: places.firstOrNull()
    }

    val activeCenterLat = centerLatitude
    val activeCenterLng = centerLongitude

    Box(
        modifier = modifier
            .fillMaxWidth()
            .height(420.dp)
            .clip(RoundedCornerShape(18.dp))
            .border(1.dp, MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.5f), RoundedCornerShape(18.dp))
    ) {
        // Interactive Canvas rendering map grid, roads, radius ring, and markers
        Canvas(
            modifier = Modifier
                .fillMaxSize()
                .testTag("discovered_places_map_canvas")
                .pointerInput(Unit) {
                    detectDragGestures { change, dragAmount ->
                        change.consume()
                        panOffsetX += dragAmount.x
                        panOffsetY += dragAmount.y
                    }
                }
                .pointerInput(places, currentZoom, panOffsetX, panOffsetY) {
                    detectTapGestures { tapOffset ->
                        val w = size.width.toFloat()
                        val h = size.height.toFloat()
                        val cx = w / 2f + panOffsetX
                        val cy = h / 2f + panOffsetY
                        val scale = 2.0.pow(currentZoom.toDouble()).toFloat() * 180f

                        // Find closest place to tap
                        var closestPlace: PlaceDiscoveryModel? = null
                        var minDistanceSq = 1400f // tap threshold ~38dp squared

                        for (place in places) {
                            val px = cx + ((place.longitude - activeCenterLng) * scale).toFloat()
                            val py = cy - ((place.latitude - activeCenterLat) * scale).toFloat()
                            val distSq = (tapOffset.x - px).pow(2) + (tapOffset.y - py).pow(2)
                            if (distSq < minDistanceSq) {
                                minDistanceSq = distSq
                                closestPlace = place
                            }
                        }

                        if (closestPlace != null) {
                            onPlaceSelected(closestPlace)
                        }
                    }
                }
        ) {
            val w = size.width
            val h = size.height
            val cx = w / 2f + panOffsetX
            val cy = h / 2f + panOffsetY
            val scale = 2.0.pow(currentZoom.toDouble()).toFloat() * 180f

            // 1. Background based on map type
            when (mapType) {
                DiscoveredMapType.NORMAL -> {
                    drawRect(if (isDarkTheme) Color(0xFF1E242B) else Color(0xFFE8ECEF))
                }
                DiscoveredMapType.SATELLITE -> {
                    drawRect(Color(0xFF102A18))
                }
                DiscoveredMapType.TERRAIN -> {
                    drawRect(if (isDarkTheme) Color(0xFF232D25) else Color(0xFFDCE7DA))
                }
            }

            // 2. Synthetic Road & Block Grid Lines
            val gridSize = 64f * (currentZoom / 13f)
            val gridColor = when (mapType) {
                DiscoveredMapType.NORMAL -> if (isDarkTheme) Color(0xFF2C353F) else Color(0xFFFFFFFF)
                DiscoveredMapType.SATELLITE -> Color(0xFF1F4428).copy(alpha = 0.5f)
                DiscoveredMapType.TERRAIN -> if (isDarkTheme) Color(0xFF314334) else Color(0xFFC7DBC5)
            }

            val startX = (cx % gridSize)
            var x = startX - gridSize
            while (x < w + gridSize) {
                drawLine(
                    color = gridColor,
                    start = Offset(x, 0f),
                    end = Offset(x, h),
                    strokeWidth = 3f
                )
                x += gridSize
            }

            val startY = (cy % gridSize)
            var y = startY - gridSize
            while (y < h + gridSize) {
                drawLine(
                    color = gridColor,
                    start = Offset(0f, y),
                    end = Offset(w, y),
                    strokeWidth = 3f
                )
                y += gridSize
            }

            // 3. Search Radius Ring
            val radiusDegrees = radiusKm / 111.0
            val radiusPixels = (radiusDegrees * scale).toFloat()

            // Outer shaded circle
            drawCircle(
                color = Color(0xFF1976D2).copy(alpha = 0.12f),
                radius = radiusPixels,
                center = Offset(cx, cy)
            )
            // Border stroke
            drawCircle(
                color = Color(0xFF1976D2).copy(alpha = 0.65f),
                radius = radiusPixels,
                center = Offset(cx, cy),
                style = Stroke(width = 2.5f)
            )

            // Center Location Target Pin
            drawCircle(
                color = Color(0xFF1976D2),
                radius = 8f,
                center = Offset(cx, cy)
            )
            drawCircle(
                color = Color.White,
                radius = 4f,
                center = Offset(cx, cy)
            )

            // 4. Draw Venue Markers on Canvas
            for (place in places) {
                val px = cx + ((place.longitude - activeCenterLng) * scale).toFloat()
                val py = cy - ((place.latitude - activeCenterLat) * scale).toFloat()

                // Skip if way off screen
                if (px < -50 || px > w + 50 || py < -50 || py > h + 50) continue

                val isSelected = place.id == selectedPlace?.id
                val markerColor = when {
                    place.isRegisteredInBookMySpace -> Color(0xFF2E7D32) // Green for registered BookMySpace venues
                    place.categorySlug == "banquet" -> Color(0xFFE91E63)
                    place.categorySlug == "meeting" -> Color(0xFF3F51B5)
                    place.categorySlug == "sports" -> Color(0xFFFF9800)
                    else -> Color(0xFF00897B)
                }

                // Marker Drop Shadow & Pin Body
                val pinRadius = if (isSelected) 18f else 13f

                // Outer selection pulse ring
                if (isSelected) {
                    drawCircle(
                        color = markerColor.copy(alpha = 0.35f),
                        radius = pinRadius + 8f,
                        center = Offset(px, py)
                    )
                }

                // Pin Base
                drawCircle(
                    color = Color.Black.copy(alpha = 0.3f),
                    radius = pinRadius * 0.8f,
                    center = Offset(px, py + pinRadius * 0.7f)
                )

                // Pin Circle
                drawCircle(
                    color = markerColor,
                    radius = pinRadius,
                    center = Offset(px, py)
                )
                drawCircle(
                    color = Color.White,
                    radius = pinRadius * 0.4f,
                    center = Offset(px, py)
                )
            }
        }

        // Top Control Bar: Search center indicator, Map Style Chip, Radius Filter
        Surface(
            modifier = Modifier
                .align(Alignment.TopCenter)
                .fillMaxWidth()
                .padding(10.dp),
            shape = RoundedCornerShape(12.dp),
            color = MaterialTheme.colorScheme.surface.copy(alpha = 0.92f),
            shadowElevation = 3.dp
        ) {
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 12.dp, vertical = 8.dp),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    modifier = Modifier.weight(1f)
                ) {
                    Icon(
                        Icons.Default.LocationOn,
                        contentDescription = null,
                        tint = MaterialTheme.colorScheme.primary,
                        modifier = Modifier.size(16.dp)
                    )
                    Spacer(modifier = Modifier.width(4.dp))
                    Text(
                        text = locationTitle,
                        fontSize = 12.sp,
                        fontWeight = FontWeight.Bold,
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis
                    )
                }

                // Radius Chips
                Row(
                    horizontalArrangement = Arrangement.spacedBy(4.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    listOf(5.0, 10.0, 25.0).forEach { r ->
                        val isSel = radiusKm.toInt() == r.toInt()
                        Surface(
                            shape = RoundedCornerShape(8.dp),
                            color = if (isSel) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.surfaceVariant,
                            modifier = Modifier.clickable { onRadiusChanged(r) }
                        ) {
                            Text(
                                text = "${r.toInt()}km",
                                fontSize = 10.sp,
                                fontWeight = if (isSel) FontWeight.Bold else FontWeight.Normal,
                                color = if (isSel) MaterialTheme.colorScheme.onPrimary else MaterialTheme.colorScheme.onSurfaceVariant,
                                modifier = Modifier.padding(horizontal = 6.dp, vertical = 3.dp)
                            )
                        }
                    }
                }
            }
        }

        // Floating Action Buttons on Right: Zoom In, Zoom Out, Re-center, Map Type Toggle
        Column(
            modifier = Modifier
                .align(Alignment.CenterEnd)
                .padding(end = 12.dp),
            verticalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            // Map Type Toggle
            FloatingActionButton(
                onClick = {
                    mapType = when (mapType) {
                        DiscoveredMapType.NORMAL -> DiscoveredMapType.SATELLITE
                        DiscoveredMapType.SATELLITE -> DiscoveredMapType.TERRAIN
                        DiscoveredMapType.TERRAIN -> DiscoveredMapType.NORMAL
                    }
                },
                modifier = Modifier.size(36.dp),
                shape = CircleShape,
                containerColor = MaterialTheme.colorScheme.surface,
                contentColor = MaterialTheme.colorScheme.onSurface
            ) {
                Icon(Icons.Default.Layers, contentDescription = "Map Style", modifier = Modifier.size(18.dp))
            }

            // Zoom In
            FloatingActionButton(
                onClick = { if (currentZoom < 18f) currentZoom += 0.75f },
                modifier = Modifier.size(36.dp),
                shape = CircleShape,
                containerColor = MaterialTheme.colorScheme.surface,
                contentColor = MaterialTheme.colorScheme.onSurface
            ) {
                Icon(Icons.Default.Add, contentDescription = "Zoom in", modifier = Modifier.size(18.dp))
            }

            // Zoom Out
            FloatingActionButton(
                onClick = { if (currentZoom > 9f) currentZoom -= 0.75f },
                modifier = Modifier.size(36.dp),
                shape = CircleShape,
                containerColor = MaterialTheme.colorScheme.surface,
                contentColor = MaterialTheme.colorScheme.onSurface
            ) {
                Icon(Icons.Default.Remove, contentDescription = "Zoom out", modifier = Modifier.size(18.dp))
            }

            // Re-center
            FloatingActionButton(
                onClick = {
                    panOffsetX = 0f
                    panOffsetY = 0f
                    currentZoom = 13.5f
                },
                modifier = Modifier.size(36.dp),
                shape = CircleShape,
                containerColor = MaterialTheme.colorScheme.primary,
                contentColor = MaterialTheme.colorScheme.onPrimary
            ) {
                Icon(Icons.Default.MyLocation, contentDescription = "Re-center", modifier = Modifier.size(18.dp))
            }
        }

        // Bottom Selected Place Preview Card
        if (selectedPlace != null) {
            Surface(
                modifier = Modifier
                    .align(Alignment.BottomCenter)
                    .fillMaxWidth()
                    .padding(10.dp)
                    .shadow(6.dp, RoundedCornerShape(14.dp)),
                shape = RoundedCornerShape(14.dp),
                color = MaterialTheme.colorScheme.surface
            ) {
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(10.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    // Venue Image / Icon
                    if (!selectedPlace.photoUrl.isNullOrBlank()) {
                        AsyncImage(
                            model = selectedPlace.photoUrl,
                            contentDescription = selectedPlace.name,
                            modifier = Modifier
                                .size(56.dp)
                                .clip(RoundedCornerShape(10.dp)),
                            contentScale = androidx.compose.ui.layout.ContentScale.Crop
                        )
                    } else {
                        Box(
                            modifier = Modifier
                                .size(56.dp)
                                .clip(RoundedCornerShape(10.dp))
                                .background(MaterialTheme.colorScheme.primaryContainer),
                            contentAlignment = Alignment.Center
                        ) {
                            Icon(
                                Icons.Default.Place,
                                contentDescription = null,
                                tint = MaterialTheme.colorScheme.primary,
                                modifier = Modifier.size(28.dp)
                            )
                        }
                    }

                    Spacer(modifier = Modifier.width(10.dp))

                    Column(modifier = Modifier.weight(1f)) {
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            Text(
                                text = selectedPlace.name,
                                style = MaterialTheme.typography.titleSmall,
                                fontWeight = FontWeight.Bold,
                                maxLines = 1,
                                overflow = TextOverflow.Ellipsis,
                                modifier = Modifier.weight(1f)
                            )
                            if (selectedPlace.isRegisteredInBookMySpace) {
                                Surface(
                                    shape = RoundedCornerShape(4.dp),
                                    color = Color(0xFFE8F5E9)
                                ) {
                                    Text(
                                        "✓ BookMySpace",
                                        fontSize = 9.sp,
                                        fontWeight = FontWeight.Bold,
                                        color = Color(0xFF2E7D32),
                                        modifier = Modifier.padding(horizontal = 4.dp, vertical = 2.dp)
                                    )
                                }
                            }
                        }

                        Text(
                            text = "${selectedPlace.category} • ${selectedPlace.address.take(28)}",
                            fontSize = 11.sp,
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                            maxLines = 1,
                            overflow = TextOverflow.Ellipsis
                        )

                        Row(
                            modifier = Modifier.padding(top = 2.dp),
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            Icon(
                                Icons.Default.Star,
                                contentDescription = null,
                                tint = Color(0xFFFFB300),
                                modifier = Modifier.size(13.dp)
                            )
                            Spacer(modifier = Modifier.width(2.dp))
                            Text(
                                text = "%.1f (%d)".format(selectedPlace.rating, selectedPlace.reviewCount),
                                fontSize = 11.sp,
                                fontWeight = FontWeight.SemiBold
                            )
                            if (selectedPlace.pricingEstimate.isNotBlank()) {
                                Spacer(modifier = Modifier.width(8.dp))
                                Text(
                                    text = selectedPlace.pricingEstimate,
                                    fontSize = 11.sp,
                                    fontWeight = FontWeight.Bold,
                                    color = MaterialTheme.colorScheme.primary
                                )
                            }
                        }
                    }

                    Spacer(modifier = Modifier.width(6.dp))

                    // Action Buttons: Directions & Details/Claim
                    Column(
                        horizontalAlignment = Alignment.End,
                        verticalArrangement = Arrangement.spacedBy(4.dp)
                    ) {
                        IconButton(
                            onClick = {
                                try {
                                    val uri = Uri.parse("geo:${selectedPlace.latitude},${selectedPlace.longitude}?q=${selectedPlace.latitude},${selectedPlace.longitude}(${Uri.encode(selectedPlace.name)})")
                                    val intent = Intent(Intent.ACTION_VIEW, uri)
                                    context.startActivity(intent)
                                } catch (_: Exception) {
                                    val webUri = Uri.parse("https://www.google.com/maps/dir/?api=1&destination=${selectedPlace.latitude},${selectedPlace.longitude}")
                                    context.startActivity(Intent(Intent.ACTION_VIEW, webUri))
                                }
                            },
                            modifier = Modifier.size(30.dp)
                        ) {
                            Icon(Icons.Default.Directions, contentDescription = "Directions", tint = MaterialTheme.colorScheme.primary)
                        }

                        if (selectedPlace.isRegisteredInBookMySpace && !selectedPlace.bookMySpaceVenueId.isNullOrBlank()) {
                            Button(
                                onClick = { onNavigateToVenueDetails(selectedPlace.bookMySpaceVenueId) },
                                contentPadding = PaddingValues(horizontal = 8.dp, vertical = 2.dp),
                                modifier = Modifier.height(28.dp)
                            ) {
                                Text("Book", fontSize = 11.sp, fontWeight = FontWeight.Bold)
                            }
                        } else {
                            OutlinedButton(
                                onClick = { onClaimVenue(selectedPlace) },
                                contentPadding = PaddingValues(horizontal = 6.dp, vertical = 2.dp),
                                modifier = Modifier.height(28.dp)
                            ) {
                                Text("Claim", fontSize = 10.sp)
                            }
                        }
                    }
                }
            }
        }
    }
}
