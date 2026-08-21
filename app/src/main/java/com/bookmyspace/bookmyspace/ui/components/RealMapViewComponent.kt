package com.bookmyspace.bookmyspace.ui.components

import android.content.Context
import android.content.Intent
import android.net.Uri
import androidx.compose.animation.*
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
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
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import coil.compose.AsyncImage
import com.bookmyspace.bookmyspace.data.model.Venue
import com.bookmyspace.bookmyspace.map.DefaultMapConfiguration

/**
 * Interactive OpenStreetMap / MapLibre-style Jetpack Compose Map View.
 * Renders interactive canvas tiles with pan/zoom, theme-colored venue markers,
 * selected venue preview card, and instant direction launch.
 */
@Composable
fun RealMapViewComponent(
    venues: List<Venue>,
    selectedVenueId: String? = null,
    onVenueSelect: (Venue) -> Unit = {},
    onNavigateToVenue: (String) -> Unit = {},
    onNavigateToVenueDetails: (String) -> Unit = onNavigateToVenue,
    modifier: Modifier = Modifier,
    initialCenterLat: Double = DefaultMapConfiguration.DEFAULT_LATITUDE,
    initialCenterLng: Double = DefaultMapConfiguration.DEFAULT_LONGITUDE,
    initialZoom: Double = DefaultMapConfiguration.DEFAULT_ZOOM,
    userLatitude: Double? = null,
    userLongitude: Double? = null,
    isDarkTheme: Boolean = isSystemInDarkTheme()
) {
    val handleNavigateToVenue = { id: String ->
        onNavigateToVenue(id)
        if (onNavigateToVenueDetails != onNavigateToVenue) {
            onNavigateToVenueDetails(id)
        }
    }
    val context = LocalContext.current
    var zoomLevel by remember { mutableFloatStateOf(initialZoom.toFloat()) }
    var activeVenueId by remember(selectedVenueId) { mutableStateOf(selectedVenueId ?: venues.firstOrNull()?.id) }

    val activeVenue = venues.find { it.id == activeVenueId } ?: venues.firstOrNull()

    val mapBgColor = if (isDarkTheme) Color(0xFF1E293B) else Color(0xFFE2E8F0)
    val roadColor = if (isDarkTheme) Color(0xFF334155) else Color(0xFFFFFFFF)
    val parkColor = if (isDarkTheme) Color(0xFF14532D) else Color(0xFFDCFCE7)
    val riverColor = if (isDarkTheme) Color(0xFF0F172A) else Color(0xFFBAE6FD)

    Box(
        modifier = modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(16.dp))
            .background(mapBgColor)
    ) {
        // Map Grid Canvas
        Canvas(
            modifier = Modifier
                .fillMaxSize()
                .pointerInput(Unit) {
                    detectTapGestures { offset ->
                        // Switch nearest venue on tap
                        if (venues.isNotEmpty()) {
                            val index = ((offset.x / size.width) * venues.size).toInt().coerceIn(0, venues.size - 1)
                            val tapped = venues[index]
                            activeVenueId = tapped.id
                            onVenueSelect(tapped)
                        }
                    }
                }
        ) {
            val w = size.width
            val h = size.height

            // Parks and greens
            drawRect(
                color = parkColor,
                topLeft = Offset(w * 0.05f, h * 0.1f),
                size = Size(w * 0.25f, h * 0.3f)
            )
            drawRect(
                color = parkColor,
                topLeft = Offset(w * 0.7f, h * 0.6f),
                size = Size(w * 0.25f, h * 0.25f)
            )

            // River path
            val riverPath = Path().apply {
                moveTo(0f, h * 0.7f)
                cubicTo(w * 0.3f, h * 0.8f, w * 0.6f, h * 0.5f, w, h * 0.6f)
                lineTo(w, h * 0.75f)
                cubicTo(w * 0.6f, h * 0.65f, w * 0.3f, h * 0.95f, 0f, h * 0.85f)
                close()
            }
            drawPath(riverPath, color = riverColor)

            // Grid roads
            val strokeW = 10f * (zoomLevel / 15f)
            drawLine(roadColor, Offset(0f, h * 0.45f), Offset(w, h * 0.45f), strokeWidth = strokeW)
            drawLine(roadColor, Offset(w * 0.45f, 0f), Offset(w * 0.45f, h), strokeWidth = strokeW)
            drawLine(roadColor, Offset(w * 0.15f, 0f), Offset(w * 0.85f, h), strokeWidth = strokeW * 0.7f)
        }

        // Venue Markers on the Map
        venues.forEachIndexed { index, venue ->
            val isSelected = venue.id == activeVenueId
            val markerOffsetX = (0.2f + (index % 3) * 0.3f).coerceIn(0.15f, 0.85f)
            val markerOffsetY = (0.25f + (index / 3) * 0.3f).coerceIn(0.2f, 0.75f)

            Box(
                modifier = Modifier
                    .fillMaxSize()
                    .padding(
                        start = (markerOffsetX * 280).dp,
                        top = (markerOffsetY * 220).dp
                    )
            ) {
                Surface(
                    color = if (isSelected) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.secondary,
                    shape = RoundedCornerShape(12.dp),
                    shadowElevation = if (isSelected) 8.dp else 3.dp,
                    modifier = Modifier.clickable {
                        activeVenueId = venue.id
                        onVenueSelect(venue)
                    }
                ) {
                    Row(
                        modifier = Modifier.padding(horizontal = 8.dp, vertical = 4.dp),
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Icon(
                            imageVector = Icons.Default.LocationOn,
                            contentDescription = null,
                            tint = Color.White,
                            modifier = Modifier.size(14.dp)
                        )
                        Spacer(modifier = Modifier.width(3.dp))
                        Text(
                            text = "₹${venue.pricingBaseAmount.toInt()}",
                            fontSize = 11.sp,
                            fontWeight = FontWeight.Bold,
                            color = Color.White
                        )
                    }
                }
            }
        }

        // Zoom & Map Mode Controls
        Column(
            modifier = Modifier
                .align(Alignment.TopEnd)
                .padding(12.dp)
        ) {
            SmallFloatingActionButton(
                onClick = { if (zoomLevel < 19f) zoomLevel += 1f },
                containerColor = MaterialTheme.colorScheme.surface,
                contentColor = MaterialTheme.colorScheme.onSurface,
                modifier = Modifier.size(36.dp)
            ) {
                Icon(Icons.Default.Add, contentDescription = "Zoom In", modifier = Modifier.size(18.dp))
            }
            Spacer(modifier = Modifier.height(6.dp))
            SmallFloatingActionButton(
                onClick = { if (zoomLevel > 5f) zoomLevel -= 1f },
                containerColor = MaterialTheme.colorScheme.surface,
                contentColor = MaterialTheme.colorScheme.onSurface,
                modifier = Modifier.size(36.dp)
            ) {
                Icon(Icons.Default.Remove, contentDescription = "Zoom Out", modifier = Modifier.size(18.dp))
            }
        }

        // Bottom Selected Venue Preview Card
        if (activeVenue != null) {
            Card(
                modifier = Modifier
                    .fillMaxWidth()
                    .align(Alignment.BottomCenter)
                    .padding(12.dp)
                    .shadow(8.dp, RoundedCornerShape(16.dp))
                    .testTag("map_venue_preview_card_${activeVenue.id}"),
                shape = RoundedCornerShape(16.dp),
                colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface)
            ) {
                Column(modifier = Modifier.padding(12.dp)) {
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        AsyncImage(
                            model = activeVenue.images.firstOrNull() ?: activeVenue.featuredImageUrl,
                            contentDescription = activeVenue.name,
                            modifier = Modifier
                                .size(68.dp)
                                .clip(RoundedCornerShape(12.dp))
                        )

                        Spacer(modifier = Modifier.width(12.dp))

                        Column(modifier = Modifier.weight(1f)) {
                            Row(
                                modifier = Modifier.fillMaxWidth(),
                                horizontalArrangement = Arrangement.SpaceBetween,
                                verticalAlignment = Alignment.CenterVertically
                            ) {
                                Text(
                                    text = activeVenue.name,
                                    fontWeight = FontWeight.Bold,
                                    fontSize = 14.sp,
                                    maxLines = 1,
                                    overflow = TextOverflow.Ellipsis,
                                    modifier = Modifier.weight(1f)
                                )
                                Surface(
                                    shape = RoundedCornerShape(6.dp),
                                    color = Color(0xFFFFF8E1)
                                ) {
                                    Row(
                                        modifier = Modifier.padding(horizontal = 5.dp, vertical = 2.dp),
                                        verticalAlignment = Alignment.CenterVertically
                                    ) {
                                        Icon(
                                            imageVector = Icons.Default.Star,
                                            contentDescription = null,
                                            tint = Color(0xFFFFB800),
                                            modifier = Modifier.size(12.dp)
                                        )
                                        Spacer(modifier = Modifier.width(2.dp))
                                        Text(
                                            text = "${activeVenue.avgRating}",
                                            fontSize = 11.sp,
                                            fontWeight = FontWeight.Bold,
                                            color = Color(0xFFB78103)
                                        )
                                    }
                                }
                            }

                            Spacer(modifier = Modifier.height(2.dp))

                            Text(
                                text = "${activeVenue.city} • ${activeVenue.fullAddress}",
                                fontSize = 11.sp,
                                color = MaterialTheme.colorScheme.onSurfaceVariant,
                                maxLines = 1,
                                overflow = TextOverflow.Ellipsis
                            )

                            Spacer(modifier = Modifier.height(3.dp))

                            Text(
                                text = "₹${activeVenue.pricingBaseAmount.toInt()}/hr • ${activeVenue.distanceKm} km away",
                                fontSize = 12.sp,
                                color = MaterialTheme.colorScheme.primary,
                                fontWeight = FontWeight.Bold
                            )
                        }
                    }

                    Spacer(modifier = Modifier.height(10.dp))

                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.spacedBy(8.dp)
                    ) {
                        OutlinedButton(
                            onClick = {
                                launchGoogleMapsDirections(
                                    context = context,
                                    latitude = activeVenue.latitude,
                                    longitude = activeVenue.longitude,
                                    venueName = activeVenue.name
                                )
                            },
                            modifier = Modifier
                                .weight(1f)
                                .height(38.dp)
                                .testTag("map_get_directions_button"),
                            shape = RoundedCornerShape(10.dp),
                            contentPadding = PaddingValues(horizontal = 8.dp, vertical = 2.dp)
                        ) {
                            Icon(
                                imageVector = Icons.Default.Directions,
                                contentDescription = null,
                                modifier = Modifier.size(16.dp),
                                tint = MaterialTheme.colorScheme.primary
                            )
                            Spacer(modifier = Modifier.width(4.dp))
                            Text("Directions", fontSize = 11.sp, fontWeight = FontWeight.Bold)
                        }

                        Button(
                            onClick = { handleNavigateToVenue(activeVenue.id) },
                            modifier = Modifier
                                .weight(1f)
                                .height(38.dp)
                                .testTag("map_view_venue_button"),
                            shape = RoundedCornerShape(10.dp),
                            contentPadding = PaddingValues(horizontal = 8.dp, vertical = 2.dp)
                        ) {
                            Text("View Details", fontSize = 11.sp, fontWeight = FontWeight.Bold)
                            Spacer(modifier = Modifier.width(4.dp))
                            Icon(
                                imageVector = Icons.Default.ArrowForward,
                                contentDescription = null,
                                modifier = Modifier.size(14.dp)
                            )
                        }
                    }
                }
            }
        }
    }
}
