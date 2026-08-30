package com.bookmyspace.bookmyspace.ui.screens

import androidx.compose.animation.*
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.bookmyspace.bookmyspace.data.model.PlaceDiscoveryModel
import com.bookmyspace.bookmyspace.data.model.Venue
import com.bookmyspace.bookmyspace.data.repository.BookMySpaceRepository
import com.bookmyspace.bookmyspace.ui.components.DiscoveredPlacesGoogleMapView
import com.bookmyspace.bookmyspace.ui.components.VoiceSearchFilterBottomSheet

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun VenueMapScreen(
    onNavigateToVenue: (String) -> Unit,
    modifier: Modifier = Modifier
) {
    val venues by BookMySpaceRepository.venues.collectAsState()
    val categories by BookMySpaceRepository.categories.collectAsState()
    val userLocation by BookMySpaceRepository.userLocationHierarchy.collectAsState()

    var selectedCategorySlug by remember { mutableStateOf<String?>(null) }
    var selectedVenueId by remember { mutableStateOf<String?>(null) }
    var searchQuery by remember { mutableStateOf("") }
    var showVoiceSearchSheet by remember { mutableStateOf(false) }

    val filteredVenues = remember(venues, selectedCategorySlug, searchQuery) {
        venues.filter { venue ->
            val matchesCategory = selectedCategorySlug == null || venue.category?.slug.equals(selectedCategorySlug, ignoreCase = true)
            val matchesQuery = searchQuery.isBlank() ||
                    venue.name.contains(searchQuery, ignoreCase = true) ||
                    venue.city.contains(searchQuery, ignoreCase = true) ||
                    venue.addressLine1.contains(searchQuery, ignoreCase = true)
            matchesCategory && matchesQuery
        }
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = {
                    Column {
                        Text(
                            text = "Explore on Map 📍",
                            fontWeight = FontWeight.Bold,
                            fontSize = 18.sp
                        )
                        Text(
                            text = "${filteredVenues.size} spaces near ${userLocation.cityTownName.ifBlank { "your area" }}",
                            fontSize = 11.sp,
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                    }
                },
                colors = TopAppBarDefaults.topAppBarColors(
                    containerColor = MaterialTheme.colorScheme.surface
                ),
                actions = {
                    IconButton(onClick = { /* Reset center */ }) {
                        Icon(Icons.Default.MyLocation, contentDescription = "My Location")
                    }
                }
            )
        },
        modifier = modifier.testTag("venue_map_screen")
    ) { paddingValues ->
        Box(
            modifier = Modifier
                .fillMaxSize()
                .padding(paddingValues)
        ) {
            if (venues.isEmpty()) {
                com.bookmyspace.bookmyspace.ui.components.EyeCatchingVenueMapSkeleton(modifier = Modifier.fillMaxSize())
            } else {
                val discoveryPlaces = remember(filteredVenues) {
                    filteredVenues.map { venue ->
                        PlaceDiscoveryModel(
                            id = venue.id,
                            name = venue.name,
                            category = venue.category?.name ?: "Venue",
                            categorySlug = venue.category?.slug ?: "all",
                            address = venue.addressLine1.ifBlank { venue.city },
                            state = venue.state,
                            district = venue.city,
                            mandal = venue.city,
                            town = venue.city,
                            pincode = venue.locationHierarchy?.postalCode ?: "",
                            latitude = venue.latitude,
                            longitude = venue.longitude,
                            phone = venue.contactPhone,
                            rating = venue.avgRating,
                            reviewCount = venue.ratingCount,
                            photoUrl = venue.coverImageUrl,
                            isRegisteredInBookMySpace = true,
                            bookMySpaceVenueId = venue.id,
                            claimStatus = "REGISTERED",
                            pricingEstimate = "₹${venue.pricingBaseAmount.toInt()}/day"
                        )
                    }
                }

                // Official Google Maps SDK Map View
                DiscoveredPlacesGoogleMapView(
                    places = discoveryPlaces,
                    centerLatitude = userLocation.latitude,
                    centerLongitude = userLocation.longitude,
                    radiusKm = 15.0,
                    locationTitle = userLocation.shortLabel,
                    selectedPlaceId = selectedVenueId,
                    onPlaceSelected = { place -> selectedVenueId = place.id },
                    onNavigateToVenueDetails = onNavigateToVenue,
                    modifier = Modifier.fillMaxSize()
                )
            }

            // Floating Filter Overlay
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .align(Alignment.TopCenter)
                    .padding(16.dp)
            ) {
                Surface(
                    shape = RoundedCornerShape(16.dp),
                    color = MaterialTheme.colorScheme.surface.copy(alpha = 0.95f),
                    shadowElevation = 6.dp,
                    modifier = Modifier.fillMaxWidth()
                ) {
                    Row(
                        modifier = Modifier.padding(horizontal = 12.dp, vertical = 6.dp),
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Icon(Icons.Default.Search, contentDescription = null, tint = MaterialTheme.colorScheme.primary)
                        Spacer(modifier = Modifier.width(8.dp))
                        TextField(
                            value = searchQuery,
                            onValueChange = { searchQuery = it },
                            placeholder = { Text("Filter venues, arenas, halls...", fontSize = 13.sp) },
                            singleLine = true,
                            colors = TextFieldDefaults.colors(
                                focusedContainerColor = Color.Transparent,
                                unfocusedContainerColor = Color.Transparent,
                                focusedIndicatorColor = Color.Transparent,
                                unfocusedIndicatorColor = Color.Transparent
                            ),
                            modifier = Modifier.weight(1f)
                        )
                        if (searchQuery.isNotBlank()) {
                            IconButton(onClick = { searchQuery = "" }) {
                                Icon(Icons.Default.Close, contentDescription = "Clear search", modifier = Modifier.size(16.dp))
                            }
                        }

                        IconButton(
                            onClick = { showVoiceSearchSheet = true },
                            modifier = Modifier.testTag("map_voice_search_btn")
                        ) {
                            Icon(
                                imageVector = Icons.Default.Mic,
                                contentDescription = "Voice Search",
                                tint = MaterialTheme.colorScheme.primary,
                                modifier = Modifier.size(20.dp)
                            )
                        }
                    }
                }

                Spacer(modifier = Modifier.height(8.dp))

                // Category chips row
                LazyRow(
                    horizontalArrangement = Arrangement.spacedBy(8.dp),
                    modifier = Modifier.fillMaxWidth()
                ) {
                    item {
                        FilterChip(
                            selected = selectedCategorySlug == null,
                            onClick = { selectedCategorySlug = null },
                            label = { Text("All Spaces (${venues.size})", fontSize = 12.sp) },
                            shape = RoundedCornerShape(12.dp)
                        )
                    }
                    items(categories) { cat ->
                        FilterChip(
                            selected = selectedCategorySlug == cat.slug,
                            onClick = {
                                selectedCategorySlug = if (selectedCategorySlug == cat.slug) null else cat.slug
                            },
                            label = { Text("${cat.icon} ${cat.name}", fontSize = 12.sp) },
                            shape = RoundedCornerShape(12.dp)
                        )
                    }
                }
            }
        }

        if (showVoiceSearchSheet) {
            VoiceSearchFilterBottomSheet(
                onDismiss = { showVoiceSearchSheet = false },
                onApplyVoiceFilter = { result ->
                    if (result.isClearCommand) {
                        searchQuery = ""
                        selectedCategorySlug = null
                    } else {
                        searchQuery = result.cleanedSearchQuery
                        if (result.categorySlug != null) {
                            selectedCategorySlug = result.categorySlug
                        }
                    }
                }
            )
        }
    }
}
