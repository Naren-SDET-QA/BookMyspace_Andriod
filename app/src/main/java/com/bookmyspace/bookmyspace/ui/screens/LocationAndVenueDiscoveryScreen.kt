package com.bookmyspace.bookmyspace.ui.screens

import android.content.Intent
import android.net.Uri
import androidx.compose.animation.*
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.*
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
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import coil.compose.AsyncImage
import com.bookmyspace.bookmyspace.data.discovery.IndianPinCodeResolver
import com.bookmyspace.bookmyspace.data.discovery.PlaceDiscoveryEngine
import com.bookmyspace.bookmyspace.data.location.IndiaLocationMasterData
import com.bookmyspace.bookmyspace.data.model.*
import com.bookmyspace.bookmyspace.data.repository.BookMySpaceRepository
import com.bookmyspace.bookmyspace.ui.components.DiscoveredPlacesGoogleMapView
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

enum class DiscoveryMode(val title: String, val icon: androidx.compose.ui.graphics.vector.ImageVector) {
    HIERARCHICAL("State & District Picker", Icons.Default.AccountTree),
    PIN_CODE("6-Digit PIN Code", Icons.Default.PinDrop)
}

/**
 * Unified India Location Picker and Automatic Place Discovery Screen
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun LocationAndVenueDiscoveryScreen(
    onNavigateBack: () -> Unit,
    onNavigateToVenueDetails: (String) -> Unit,
    onNavigateToClaimVenue: (PlaceDiscoveryModel) -> Unit = {}
) {
    val context = LocalContext.current
    val scope = rememberCoroutineScope()

    var selectedMode by remember { mutableStateOf(DiscoveryMode.HIERARCHICAL) }

    // --- 1. Hierarchical State ---
    val availableCountries = IndiaLocationMasterData.COUNTRIES
    var selectedCountryId by remember { mutableStateOf("IN") }
    var selectedStateId by remember { mutableStateOf("IN-AP") }
    var selectedDistrictId by remember { mutableStateOf("DIST_AP_KADAPA") }
    var selectedMandalId by remember { mutableStateOf("MANDAL_AP_BADVEL") }
    var selectedCityId by remember { mutableStateOf("CITY_AP_BADVEL") }

    val availableStates = remember(selectedCountryId) {
        IndiaLocationMasterData.getStatesForCountry(selectedCountryId).ifEmpty { IndiaLocationMasterData.STATES }
    }
    val availableDistricts = remember(selectedStateId) {
        IndiaLocationMasterData.getDistrictsForState(selectedStateId)
    }
    val availableMandals = remember(selectedDistrictId) {
        IndiaLocationMasterData.getMandalsForDistrict(selectedDistrictId)
    }
    val availableCities = remember(selectedMandalId, selectedDistrictId) {
        IndiaLocationMasterData.getCitiesForMandal(selectedMandalId).ifEmpty {
            IndiaLocationMasterData.getCitiesForDistrict(selectedDistrictId)
        }
    }

    // Dropdown expanded states
    var showStateMenu by remember { mutableStateOf(false) }
    var showDistrictMenu by remember { mutableStateOf(false) }
    var showMandalMenu by remember { mutableStateOf(false) }
    var showCityMenu by remember { mutableStateOf(false) }

    // --- 2. PIN Code Search State ---
    var pinCodeInput by remember { mutableStateOf("516227") }
    var pinResolutionResult by remember { mutableStateOf<PinCodeResolutionResult?>(null) }
    var isResolvingPin by remember { mutableStateOf(false) }
    var selectedLocalityName by remember { mutableStateOf("") }

    // --- 3. Active Search Location Coordinates & Radius ---
    var activeLatitude by remember { mutableDoubleStateOf(14.7431) }
    var activeLongitude by remember { mutableDoubleStateOf(79.0578) }
    var activeLocationTitle by remember { mutableStateOf("Badvel, YSR Kadapa (AP)") }
    var selectedRadiusKm by remember { mutableDoubleStateOf(10.0) }

    // --- 4. Discovered Places State ---
    var discoveredPlaces by remember { mutableStateOf<List<PlaceDiscoveryModel>>(emptyList()) }
    var isSearchingPlaces by remember { mutableStateOf(false) }
    var selectedCategorySlug by remember { mutableStateOf("all") }
    var selectedSortBy by remember { mutableStateOf(DiscoverySortBy.NEAREST) }
    var placeSearchQuery by remember { mutableStateOf("") }
    var activeViewLayout by remember { mutableStateOf("MAP") } // "MAP", "LIST", "SPLIT"
    var selectedMapPlaceId by remember { mutableStateOf<String?>(null) }

    // Claim venue bottom sheet
    var placeToClaim by remember { mutableStateOf<PlaceDiscoveryModel?>(null) }
    var showClaimSheet by remember { mutableStateOf(false) }
    var claimOwnerName by remember { mutableStateOf("") }
    var claimOwnerPhone by remember { mutableStateOf("") }
    var claimSubmitted by remember { mutableStateOf(false) }

    // Function to trigger discovery search
    val triggerDiscovery: (Double, Double, Double, String) -> Unit = { lat, lng, rad, title ->
        activeLatitude = lat
        activeLongitude = lng
        activeLocationTitle = title
        isSearchingPlaces = true
        scope.launch {
            PlaceDiscoveryEngine.discoverPlaces(
                latitude = lat,
                longitude = lng,
                radiusKm = rad,
                categories = if (selectedCategorySlug == "all") emptyList() else listOf(selectedCategorySlug),
                context = context
            ).collect { places ->
                discoveredPlaces = places
                isSearchingPlaces = false
            }
        }
    }

    // Initial load on first launch
    LaunchedEffect(Unit) {
        triggerDiscovery(activeLatitude, activeLongitude, selectedRadiusKm, activeLocationTitle)
    }

    // Filter & Sort Discovered Places
    val filteredPlaces = remember(discoveredPlaces, selectedCategorySlug, selectedSortBy, placeSearchQuery) {
        var list = discoveredPlaces

        // Category filter
        if (selectedCategorySlug != "all") {
            list = list.filter {
                it.categorySlug.equals(selectedCategorySlug, ignoreCase = true) ||
                it.category.contains(selectedCategorySlug, ignoreCase = true)
            }
        }

        // Text search
        if (placeSearchQuery.isNotBlank()) {
            val q = placeSearchQuery.trim().lowercase()
            list = list.filter {
                it.name.lowercase().contains(q) ||
                it.address.lowercase().contains(q) ||
                it.category.lowercase().contains(q) ||
                it.town.lowercase().contains(q)
            }
        }

        // Sorting
        when (selectedSortBy) {
            DiscoverySortBy.NEAREST -> list.sortedBy { it.distanceKm }
            DiscoverySortBy.HIGHEST_RATED -> list.sortedByDescending { it.rating }
            DiscoverySortBy.NAME_AZ -> list.sortedBy { it.name.lowercase() }
            DiscoverySortBy.CATEGORY -> list.sortedBy { it.category }
        }
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = {
                    Column {
                        Text(
                            text = "India Place Discovery",
                            fontWeight = FontWeight.Bold,
                            fontSize = 18.sp
                        )
                        Text(
                            text = "Hierarchical & PIN Code Explorer",
                            fontSize = 12.sp,
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                    }
                },
                navigationIcon = {
                    IconButton(onClick = onNavigateBack) {
                        Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "Back")
                    }
                },
                actions = {
                    IconButton(
                        onClick = {
                            triggerDiscovery(activeLatitude, activeLongitude, selectedRadiusKm, activeLocationTitle)
                        }
                    ) {
                        Icon(Icons.Default.Refresh, contentDescription = "Refresh Discovery")
                    }
                },
                colors = TopAppBarDefaults.topAppBarColors(
                    containerColor = MaterialTheme.colorScheme.surface
                )
            )
        }
    ) { innerPadding ->
        LazyColumn(
            modifier = Modifier
                .fillMaxSize()
                .padding(innerPadding),
            contentPadding = PaddingValues(bottom = 32.dp)
        ) {
            // Mode Selector Tabs (Hierarchical vs PIN Code)
            item {
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(horizontal = 16.dp, vertical = 8.dp)
                        .clip(RoundedCornerShape(12.dp))
                        .background(MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.5f))
                        .padding(4.dp)
                ) {
                    DiscoveryMode.entries.forEach { mode ->
                        val isSelected = selectedMode == mode
                        Surface(
                            modifier = Modifier
                                .weight(1f)
                                .clip(RoundedCornerShape(10.dp))
                                .clickable { selectedMode = mode },
                            color = if (isSelected) MaterialTheme.colorScheme.primary else Color.Transparent,
                            contentColor = if (isSelected) MaterialTheme.colorScheme.onPrimary else MaterialTheme.colorScheme.onSurfaceVariant
                        ) {
                            Row(
                                modifier = Modifier.padding(vertical = 10.dp),
                                horizontalArrangement = Arrangement.Center,
                                verticalAlignment = Alignment.CenterVertically
                            ) {
                                Icon(
                                    imageVector = mode.icon,
                                    contentDescription = null,
                                    modifier = Modifier.size(16.dp)
                                )
                                Spacer(modifier = Modifier.width(6.dp))
                                Text(
                                    text = mode.title,
                                    fontSize = 13.sp,
                                    fontWeight = if (isSelected) FontWeight.Bold else FontWeight.Medium
                                )
                            }
                        }
                    }
                }
            }

            // Location Input Panel based on Selected Mode
            item {
                Card(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(horizontal = 16.dp, vertical = 4.dp),
                    shape = RoundedCornerShape(16.dp),
                    colors = CardDefaults.cardColors(
                        containerColor = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.35f)
                    ),
                    border = BorderStroke(1.dp, MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.5f))
                ) {
                    Column(modifier = Modifier.padding(16.dp)) {
                        if (selectedMode == DiscoveryMode.HIERARCHICAL) {
                            // ================= HIERARCHICAL MODE =================
                            Text(
                                text = "1. India Hierarchical Selection",
                                fontSize = 14.sp,
                                fontWeight = FontWeight.Bold,
                                color = MaterialTheme.colorScheme.primary
                            )
                            Text(
                                text = "India → State → District → Mandal/Taluk → Town/Village",
                                fontSize = 11.sp,
                                color = MaterialTheme.colorScheme.onSurfaceVariant
                            )

                            Spacer(modifier = Modifier.height(12.dp))

                            // Step 1: Country & State Row
                            Row(
                                modifier = Modifier.fillMaxWidth(),
                                horizontalArrangement = Arrangement.spacedBy(8.dp)
                            ) {
                                // Country (India Fixed)
                                OutlinedTextField(
                                    value = "🇮🇳 India",
                                    onValueChange = {},
                                    readOnly = true,
                                    label = { Text("Country", fontSize = 11.sp) },
                                    modifier = Modifier.weight(0.38f),
                                    shape = RoundedCornerShape(10.dp)
                                )

                                // State Dropdown
                                Box(modifier = Modifier.weight(0.62f)) {
                                    val currentState = availableStates.firstOrNull { it.id == selectedStateId }
                                    OutlinedTextField(
                                        value = currentState?.name ?: "Select State",
                                        onValueChange = {},
                                        readOnly = true,
                                        label = { Text("State / UT", fontSize = 11.sp) },
                                        trailingIcon = {
                                            IconButton(onClick = { showStateMenu = true }) {
                                                Icon(Icons.Default.ArrowDropDown, contentDescription = null)
                                            }
                                        },
                                        modifier = Modifier
                                            .fillMaxWidth()
                                            .clickable { showStateMenu = true },
                                        shape = RoundedCornerShape(10.dp)
                                    )
                                    DropdownMenu(
                                        expanded = showStateMenu,
                                        onDismissRequest = { showStateMenu = false }
                                    ) {
                                        availableStates.forEach { state ->
                                            DropdownMenuItem(
                                                text = { Text(state.name, fontSize = 13.sp) },
                                                onClick = {
                                                    selectedStateId = state.id
                                                    val firstDist = IndiaLocationMasterData.getDistrictsForState(state.id).firstOrNull()
                                                    selectedDistrictId = firstDist?.id ?: ""
                                                    val firstMandal = if (firstDist != null) IndiaLocationMasterData.getMandalsForDistrict(firstDist.id).firstOrNull() else null
                                                    selectedMandalId = firstMandal?.id ?: ""
                                                    val firstCity = if (firstMandal != null) IndiaLocationMasterData.getCitiesForMandal(firstMandal.id).firstOrNull() else null
                                                    selectedCityId = firstCity?.id ?: ""
                                                    showStateMenu = false
                                                }
                                            )
                                        }
                                    }
                                }
                            }

                            Spacer(modifier = Modifier.height(8.dp))

                            // Step 2: District & Mandal Row
                            Row(
                                modifier = Modifier.fillMaxWidth(),
                                horizontalArrangement = Arrangement.spacedBy(8.dp)
                            ) {
                                // District Dropdown
                                Box(modifier = Modifier.weight(1f)) {
                                    val currentDist = availableDistricts.firstOrNull { it.id == selectedDistrictId }
                                    OutlinedTextField(
                                        value = currentDist?.name ?: "District",
                                        onValueChange = {},
                                        readOnly = true,
                                        label = { Text("District", fontSize = 11.sp) },
                                        trailingIcon = {
                                            IconButton(onClick = { showDistrictMenu = true }) {
                                                Icon(Icons.Default.ArrowDropDown, contentDescription = null)
                                            }
                                        },
                                        modifier = Modifier
                                            .fillMaxWidth()
                                            .clickable { showDistrictMenu = true },
                                        shape = RoundedCornerShape(10.dp)
                                    )
                                    DropdownMenu(
                                        expanded = showDistrictMenu,
                                        onDismissRequest = { showDistrictMenu = false }
                                    ) {
                                        availableDistricts.forEach { dist ->
                                            DropdownMenuItem(
                                                text = { Text(dist.name, fontSize = 13.sp) },
                                                onClick = {
                                                    selectedDistrictId = dist.id
                                                    val mandals = IndiaLocationMasterData.getMandalsForDistrict(dist.id)
                                                    selectedMandalId = mandals.firstOrNull()?.id ?: ""
                                                    val cities = IndiaLocationMasterData.getCitiesForDistrict(dist.id)
                                                    selectedCityId = cities.firstOrNull()?.id ?: ""
                                                    showDistrictMenu = false
                                                }
                                            )
                                        }
                                    }
                                }

                                // Mandal / Taluk Dropdown
                                Box(modifier = Modifier.weight(1f)) {
                                    val currentMandal = availableMandals.firstOrNull { it.id == selectedMandalId }
                                    OutlinedTextField(
                                        value = currentMandal?.name ?: "Mandal / Taluk",
                                        onValueChange = {},
                                        readOnly = true,
                                        label = { Text("Mandal / Taluk", fontSize = 11.sp) },
                                        trailingIcon = {
                                            IconButton(onClick = { showMandalMenu = true }) {
                                                Icon(Icons.Default.ArrowDropDown, contentDescription = null)
                                            }
                                        },
                                        modifier = Modifier
                                            .fillMaxWidth()
                                            .clickable { showMandalMenu = true },
                                        shape = RoundedCornerShape(10.dp)
                                    )
                                    DropdownMenu(
                                        expanded = showMandalMenu,
                                        onDismissRequest = { showMandalMenu = false }
                                    ) {
                                        availableMandals.forEach { mandal ->
                                            DropdownMenuItem(
                                                text = { Text(mandal.name, fontSize = 13.sp) },
                                                onClick = {
                                                    selectedMandalId = mandal.id
                                                    val cities = IndiaLocationMasterData.getCitiesForMandal(mandal.id)
                                                    selectedCityId = cities.firstOrNull()?.id ?: ""
                                                    showMandalMenu = false
                                                }
                                            )
                                        }
                                    }
                                }
                            }

                            Spacer(modifier = Modifier.height(8.dp))

                            // Step 3: Town / City / Village Dropdown
                            Box(modifier = Modifier.fillMaxWidth()) {
                                val currentCity = availableCities.firstOrNull { it.id == selectedCityId }
                                OutlinedTextField(
                                    value = currentCity?.name ?: "Town / City / Village",
                                    onValueChange = {},
                                    readOnly = true,
                                    label = { Text("Town / City / Village", fontSize = 11.sp) },
                                    trailingIcon = {
                                        IconButton(onClick = { showCityMenu = true }) {
                                            Icon(Icons.Default.ArrowDropDown, contentDescription = null)
                                        }
                                    },
                                    modifier = Modifier
                                        .fillMaxWidth()
                                        .clickable { showCityMenu = true },
                                    shape = RoundedCornerShape(10.dp)
                                )
                                DropdownMenu(
                                    expanded = showCityMenu,
                                    onDismissRequest = { showCityMenu = false }
                                ) {
                                    availableCities.forEach { city ->
                                        DropdownMenuItem(
                                            text = { Text("${city.name} (${city.postalCode})", fontSize = 13.sp) },
                                            onClick = {
                                                selectedCityId = city.id
                                                showCityMenu = false
                                            }
                                        )
                                    }
                                }
                            }

                            Spacer(modifier = Modifier.height(12.dp))

                            // Search Trigger Button for Hierarchical selection
                            Button(
                                onClick = {
                                    val city = availableCities.firstOrNull { it.id == selectedCityId }
                                    val mandal = availableMandals.firstOrNull { it.id == selectedMandalId }
                                    val dist = availableDistricts.firstOrNull { it.id == selectedDistrictId }
                                    val state = availableStates.firstOrNull { it.id == selectedStateId }

                                    val lat = city?.latitude ?: mandal?.latitude ?: dist?.latitude ?: state?.latitude ?: 14.7431
                                    val lng = city?.longitude ?: mandal?.longitude ?: dist?.longitude ?: state?.longitude ?: 79.0578
                                    val title = listOfNotNull(city?.name, mandal?.name, dist?.name, state?.name).distinct().joinToString(", ")

                                    triggerDiscovery(lat, lng, selectedRadiusKm, title)
                                },
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .testTag("btn_discover_hierarchical"),
                                shape = RoundedCornerShape(10.dp)
                            ) {
                                Icon(Icons.Default.Search, contentDescription = null, modifier = Modifier.size(18.dp))
                                Spacer(modifier = Modifier.width(8.dp))
                                Text("Discover Places in this Location", fontWeight = FontWeight.Bold)
                            }

                        } else {
                            // ================= PIN CODE MODE =================
                            Text(
                                text = "2. Indian Postal PIN Code Search",
                                fontSize = 14.sp,
                                fontWeight = FontWeight.Bold,
                                color = MaterialTheme.colorScheme.primary
                            )
                            Text(
                                text = "Enter 6-digit Indian PIN code to resolve location and nearby venues",
                                fontSize = 11.sp,
                                color = MaterialTheme.colorScheme.onSurfaceVariant
                            )

                            Spacer(modifier = Modifier.height(12.dp))

                            Row(
                                modifier = Modifier.fillMaxWidth(),
                                verticalAlignment = Alignment.CenterVertically,
                                horizontalArrangement = Arrangement.spacedBy(8.dp)
                            ) {
                                OutlinedTextField(
                                    value = pinCodeInput,
                                    onValueChange = { input ->
                                        if (input.length <= 6 && input.all { it.isDigit() }) {
                                            pinCodeInput = input
                                            if (input.length == 6) {
                                                isResolvingPin = true
                                                scope.launch {
                                                    val res = IndianPinCodeResolver.resolvePinCode(input, context)
                                                    pinResolutionResult = res
                                                    isResolvingPin = false
                                                    if (res.isResolved) {
                                                        selectedLocalityName = res.primaryLocality
                                                        val title = "${res.primaryLocality.ifBlank { "PIN $input" }}, ${res.district} (${res.state})"
                                                        triggerDiscovery(res.latitude, res.longitude, selectedRadiusKm, title)
                                                    }
                                                }
                                            }
                                        }
                                    },
                                    label = { Text("Enter 6-Digit PIN", fontSize = 11.sp) },
                                    placeholder = { Text("e.g. 516227") },
                                    leadingIcon = {
                                        Icon(Icons.Default.PinDrop, contentDescription = null, tint = MaterialTheme.colorScheme.primary)
                                    },
                                    keyboardOptions = KeyboardOptions(
                                        keyboardType = KeyboardType.Number,
                                        imeAction = ImeAction.Search
                                    ),
                                    keyboardActions = KeyboardActions(
                                        onSearch = {
                                            if (pinCodeInput.length == 6) {
                                                isResolvingPin = true
                                                scope.launch {
                                                    val res = IndianPinCodeResolver.resolvePinCode(pinCodeInput, context)
                                                    pinResolutionResult = res
                                                    isResolvingPin = false
                                                    if (res.isResolved) {
                                                        selectedLocalityName = res.primaryLocality
                                                        val title = "${res.primaryLocality.ifBlank { "PIN $pinCodeInput" }}, ${res.district} (${res.state})"
                                                        triggerDiscovery(res.latitude, res.longitude, selectedRadiusKm, title)
                                                    }
                                                }
                                            }
                                        }
                                    ),
                                    modifier = Modifier
                                        .weight(1f)
                                        .testTag("input_pincode"),
                                    shape = RoundedCornerShape(10.dp),
                                    singleLine = true
                                )

                                Button(
                                    onClick = {
                                        if (pinCodeInput.length == 6) {
                                            isResolvingPin = true
                                            scope.launch {
                                                val res = IndianPinCodeResolver.resolvePinCode(pinCodeInput, context)
                                                pinResolutionResult = res
                                                isResolvingPin = false
                                                if (res.isResolved) {
                                                    selectedLocalityName = res.primaryLocality
                                                    val title = "${res.primaryLocality.ifBlank { "PIN $pinCodeInput" }}, ${res.district} (${res.state})"
                                                    triggerDiscovery(res.latitude, res.longitude, selectedRadiusKm, title)
                                                }
                                            }
                                        }
                                    },
                                    modifier = Modifier.height(56.dp),
                                    shape = RoundedCornerShape(10.dp),
                                    enabled = pinCodeInput.length == 6 && !isResolvingPin
                                ) {
                                    if (isResolvingPin) {
                                        CircularProgressIndicator(modifier = Modifier.size(16.dp), color = MaterialTheme.colorScheme.onPrimary, strokeWidth = 2.dp)
                                    } else {
                                        Text("Resolve", fontWeight = FontWeight.Bold)
                                    }
                                }
                            }

                            // Resolved PIN details & multiple locality picker
                            pinResolutionResult?.let { res ->
                                Spacer(modifier = Modifier.height(10.dp))
                                if (res.isResolved) {
                                    Surface(
                                        shape = RoundedCornerShape(10.dp),
                                        color = MaterialTheme.colorScheme.primaryContainer.copy(alpha = 0.35f),
                                        border = BorderStroke(1.dp, MaterialTheme.colorScheme.primary.copy(alpha = 0.3f)),
                                        modifier = Modifier.fillMaxWidth()
                                    ) {
                                        Column(modifier = Modifier.padding(12.dp)) {
                                            Row(
                                                modifier = Modifier.fillMaxWidth(),
                                                horizontalArrangement = Arrangement.SpaceBetween,
                                                verticalAlignment = Alignment.CenterVertically
                                            ) {
                                                Text(
                                                    text = "📍 ${res.district}, ${res.state}",
                                                    fontWeight = FontWeight.Bold,
                                                    fontSize = 13.sp
                                                )
                                                Text(
                                                    text = "GPS: %.4f, %.4f".format(res.latitude, res.longitude),
                                                    fontSize = 10.sp,
                                                    color = MaterialTheme.colorScheme.onSurfaceVariant
                                                )
                                            }

                                            if (res.localities.size > 1) {
                                                Spacer(modifier = Modifier.height(8.dp))
                                                Text(
                                                    text = "Multiple Post Offices found in PIN ${res.pincode}. Select your locality:",
                                                    fontSize = 11.sp,
                                                    color = MaterialTheme.colorScheme.onSurfaceVariant
                                                )
                                                Spacer(modifier = Modifier.height(4.dp))
                                                LazyRow(
                                                    horizontalArrangement = Arrangement.spacedBy(6.dp)
                                                ) {
                                                    items(res.localities) { loc ->
                                                        val isSelected = selectedLocalityName == loc.name
                                                        FilterChip(
                                                            selected = isSelected,
                                                            onClick = {
                                                                selectedLocalityName = loc.name
                                                                val title = "${loc.name}, ${res.district} (${res.state})"
                                                                triggerDiscovery(res.latitude, res.longitude, selectedRadiusKm, title)
                                                            },
                                                            label = { Text(loc.name, fontSize = 11.sp) }
                                                        )
                                                    }
                                                }
                                            }
                                        }
                                    }
                                } else {
                                    Text(
                                        text = res.errorMessage ?: "Invalid PIN Code",
                                        color = MaterialTheme.colorScheme.error,
                                        fontSize = 12.sp,
                                        modifier = Modifier.padding(top = 4.dp)
                                    )
                                }
                            }
                        }

                        // Quick Location Presets Row
                        Spacer(modifier = Modifier.height(10.dp))
                        Text(
                            text = "Popular Locations in India:",
                            fontSize = 11.sp,
                            fontWeight = FontWeight.SemiBold,
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                        Spacer(modifier = Modifier.height(4.dp))
                        LazyRow(
                            horizontalArrangement = Arrangement.spacedBy(6.dp)
                        ) {
                            items(IndiaLocationMasterData.POPULAR_LOCATION_PRESETS.take(5)) { preset ->
                                Surface(
                                    shape = RoundedCornerShape(8.dp),
                                    color = MaterialTheme.colorScheme.surfaceVariant,
                                    modifier = Modifier.clickable {
                                        selectedStateId = preset.stateId
                                        selectedDistrictId = preset.districtId
                                        selectedMandalId = preset.mandalId
                                        selectedCityId = preset.cityTownId
                                        pinCodeInput = preset.postalCode
                                        triggerDiscovery(preset.latitude, preset.longitude, selectedRadiusKm, "${preset.cityName}, ${preset.districtName} (${preset.stateName})")
                                    }
                                ) {
                                    Text(
                                        text = "${preset.cityName} (${preset.postalCode})",
                                        fontSize = 11.sp,
                                        fontWeight = FontWeight.Medium,
                                        modifier = Modifier.padding(horizontal = 8.dp, vertical = 4.dp)
                                    )
                                }
                            }
                        }
                    }
                }
            }

            // Radius Selector & Current Search Location Header
            item {
                Column(modifier = Modifier.padding(horizontal = 16.dp, vertical = 8.dp)) {
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.SpaceBetween,
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Column {
                            Text(
                                text = "Searching Near: $activeLocationTitle",
                                fontSize = 13.sp,
                                fontWeight = FontWeight.Bold,
                                maxLines = 1,
                                overflow = TextOverflow.Ellipsis
                            )
                            Text(
                                text = "Radius: ${selectedRadiusKm.toInt()} km • ${filteredPlaces.size} places found",
                                fontSize = 11.sp,
                                color = MaterialTheme.colorScheme.primary
                            )
                        }

                        // Radius options
                        Row(horizontalArrangement = Arrangement.spacedBy(4.dp)) {
                            listOf(5.0, 10.0, 25.0, 50.0, 100.0).forEach { r ->
                                val isSelected = selectedRadiusKm == r
                                FilterChip(
                                    selected = isSelected,
                                    onClick = {
                                        selectedRadiusKm = r
                                        triggerDiscovery(activeLatitude, activeLongitude, r, activeLocationTitle)
                                    },
                                    label = { Text("${r.toInt()}km", fontSize = 10.sp) },
                                    modifier = Modifier.height(30.dp)
                                )
                            }
                        }
                    }

                    Spacer(modifier = Modifier.height(8.dp))

                    // Text search bar for places
                    OutlinedTextField(
                        value = placeSearchQuery,
                        onValueChange = { placeSearchQuery = it },
                        placeholder = { Text("Filter places by name or address...", fontSize = 12.sp) },
                        leadingIcon = {
                            Icon(Icons.Default.Search, contentDescription = null, modifier = Modifier.size(16.dp))
                        },
                        trailingIcon = {
                            if (placeSearchQuery.isNotBlank()) {
                                IconButton(onClick = { placeSearchQuery = "" }) {
                                    Icon(Icons.Default.Clear, contentDescription = "Clear", modifier = Modifier.size(16.dp))
                                }
                            }
                        },
                        modifier = Modifier.fillMaxWidth(),
                        shape = RoundedCornerShape(10.dp),
                        singleLine = true
                    )
                }
            }

            // Category Filter Pills
            item {
                LazyRow(
                    contentPadding = PaddingValues(horizontal = 16.dp),
                    horizontalArrangement = Arrangement.spacedBy(6.dp),
                    modifier = Modifier.padding(vertical = 4.dp)
                ) {
                    items(DiscoveryCategory.entries) { cat ->
                        val isSelected = selectedCategorySlug == cat.slug
                        FilterChip(
                            selected = isSelected,
                            onClick = { selectedCategorySlug = cat.slug },
                            label = {
                                Text("${cat.iconEmoji} ${cat.displayName}", fontSize = 12.sp)
                            }
                        )
                    }
                }
            }

            // Sorting & View Mode Bar
            item {
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(horizontal = 16.dp, vertical = 6.dp),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    // View Mode Switcher: Map, Split, List
                    Surface(
                        shape = RoundedCornerShape(20.dp),
                        color = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.6f)
                    ) {
                        Row(
                            modifier = Modifier.padding(2.dp),
                            horizontalArrangement = Arrangement.spacedBy(2.dp)
                        ) {
                            Surface(
                                shape = RoundedCornerShape(16.dp),
                                color = if (activeViewLayout == "MAP") MaterialTheme.colorScheme.primary else Color.Transparent,
                                modifier = Modifier
                                    .clickable { activeViewLayout = "MAP" }
                                    .testTag("screen_btn_map_view")
                            ) {
                                Row(
                                    modifier = Modifier.padding(horizontal = 8.dp, vertical = 4.dp),
                                    verticalAlignment = Alignment.CenterVertically
                                ) {
                                    Icon(
                                        Icons.Default.Map,
                                        contentDescription = "Map View",
                                        modifier = Modifier.size(13.dp),
                                        tint = if (activeViewLayout == "MAP") MaterialTheme.colorScheme.onPrimary else MaterialTheme.colorScheme.onSurfaceVariant
                                    )
                                    Spacer(modifier = Modifier.width(3.dp))
                                    Text(
                                        "Map",
                                        fontSize = 11.sp,
                                        fontWeight = FontWeight.Bold,
                                        color = if (activeViewLayout == "MAP") MaterialTheme.colorScheme.onPrimary else MaterialTheme.colorScheme.onSurfaceVariant
                                    )
                                }
                            }

                            Surface(
                                shape = RoundedCornerShape(16.dp),
                                color = if (activeViewLayout == "SPLIT") MaterialTheme.colorScheme.primary else Color.Transparent,
                                modifier = Modifier
                                    .clickable { activeViewLayout = "SPLIT" }
                                    .testTag("screen_btn_split_view")
                            ) {
                                Row(
                                    modifier = Modifier.padding(horizontal = 8.dp, vertical = 4.dp),
                                    verticalAlignment = Alignment.CenterVertically
                                ) {
                                    Icon(
                                        Icons.Default.Dashboard,
                                        contentDescription = "Split View",
                                        modifier = Modifier.size(13.dp),
                                        tint = if (activeViewLayout == "SPLIT") MaterialTheme.colorScheme.onPrimary else MaterialTheme.colorScheme.onSurfaceVariant
                                    )
                                    Spacer(modifier = Modifier.width(3.dp))
                                    Text(
                                        "Split",
                                        fontSize = 11.sp,
                                        fontWeight = FontWeight.Bold,
                                        color = if (activeViewLayout == "SPLIT") MaterialTheme.colorScheme.onPrimary else MaterialTheme.colorScheme.onSurfaceVariant
                                    )
                                }
                            }

                            Surface(
                                shape = RoundedCornerShape(16.dp),
                                color = if (activeViewLayout == "LIST") MaterialTheme.colorScheme.primary else Color.Transparent,
                                modifier = Modifier
                                    .clickable { activeViewLayout = "LIST" }
                                    .testTag("screen_btn_list_view")
                            ) {
                                Row(
                                    modifier = Modifier.padding(horizontal = 8.dp, vertical = 4.dp),
                                    verticalAlignment = Alignment.CenterVertically
                                ) {
                                    Icon(
                                        Icons.Default.ViewList,
                                        contentDescription = "List View",
                                        modifier = Modifier.size(13.dp),
                                        tint = if (activeViewLayout == "LIST") MaterialTheme.colorScheme.onPrimary else MaterialTheme.colorScheme.onSurfaceVariant
                                    )
                                    Spacer(modifier = Modifier.width(3.dp))
                                    Text(
                                        "List",
                                        fontSize = 11.sp,
                                        fontWeight = FontWeight.Bold,
                                        color = if (activeViewLayout == "LIST") MaterialTheme.colorScheme.onPrimary else MaterialTheme.colorScheme.onSurfaceVariant
                                    )
                                }
                            }
                        }
                    }

                    // Sort Chips
                    Row(horizontalArrangement = Arrangement.spacedBy(4.dp)) {
                        DiscoverySortBy.entries.take(2).forEach { sort ->
                            val isSelected = selectedSortBy == sort
                            Surface(
                                shape = RoundedCornerShape(6.dp),
                                color = if (isSelected) MaterialTheme.colorScheme.primaryContainer else MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.5f),
                                modifier = Modifier.clickable { selectedSortBy = sort }
                            ) {
                                Text(
                                    text = sort.label,
                                    fontSize = 10.sp,
                                    fontWeight = if (isSelected) FontWeight.Bold else FontWeight.Normal,
                                    color = if (isSelected) MaterialTheme.colorScheme.onPrimaryContainer else MaterialTheme.colorScheme.onSurfaceVariant,
                                    modifier = Modifier.padding(horizontal = 6.dp, vertical = 4.dp)
                                )
                            }
                        }
                    }
                }
            }

            // Discovered Places Map & List
            if (isSearchingPlaces && discoveredPlaces.isEmpty()) {
                item {
                    Column(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(40.dp),
                        horizontalAlignment = Alignment.CenterHorizontally
                    ) {
                        CircularProgressIndicator(modifier = Modifier.size(32.dp))
                        Spacer(modifier = Modifier.height(12.dp))
                        Text("Discovering places around $activeLocationTitle...", fontSize = 13.sp)
                    }
                }
            } else if (filteredPlaces.isEmpty()) {
                item {
                    Card(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(24.dp),
                        colors = CardDefaults.cardColors(
                            containerColor = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.4f)
                        )
                    ) {
                        Column(
                            modifier = Modifier.padding(24.dp),
                            horizontalAlignment = Alignment.CenterHorizontally
                        ) {
                            Icon(Icons.Default.LocationOff, contentDescription = null, modifier = Modifier.size(40.dp), tint = MaterialTheme.colorScheme.outline)
                            Spacer(modifier = Modifier.height(8.dp))
                            Text(
                                text = "No places found within ${selectedRadiusKm.toInt()} km",
                                fontWeight = FontWeight.Bold,
                                fontSize = 14.sp
                            )
                            Text(
                                text = "Try expanding your search radius to 25 km or 50 km to find more venues.",
                                fontSize = 12.sp,
                                textAlign = TextAlign.Center,
                                color = MaterialTheme.colorScheme.onSurfaceVariant
                            )
                            Spacer(modifier = Modifier.height(12.dp))
                            Button(
                                onClick = {
                                    selectedRadiusKm = 50.0
                                    triggerDiscovery(activeLatitude, activeLongitude, 50.0, activeLocationTitle)
                                }
                            ) {
                                Text("Expand Radius to 50 km")
                            }
                        }
                    }
                }
            } else {
                // Interactive Google Map View in MAP and SPLIT layout modes
                if (activeViewLayout == "MAP" || activeViewLayout == "SPLIT") {
                    item {
                        DiscoveredPlacesGoogleMapView(
                            places = filteredPlaces,
                            centerLatitude = activeLatitude,
                            centerLongitude = activeLongitude,
                            radiusKm = selectedRadiusKm,
                            locationTitle = activeLocationTitle,
                            selectedPlaceId = selectedMapPlaceId,
                            onPlaceSelected = { place -> selectedMapPlaceId = place.id },
                            onNavigateToVenueDetails = { venueId -> onNavigateToVenueDetails(venueId) },
                            onClaimVenue = { place ->
                                placeToClaim = place
                                showClaimSheet = true
                                claimSubmitted = false
                            },
                            onRadiusChanged = { newRad ->
                                selectedRadiusKm = newRad
                                triggerDiscovery(activeLatitude, activeLongitude, newRad, activeLocationTitle)
                            },
                            modifier = Modifier
                                .fillMaxWidth()
                                .padding(horizontal = 16.dp, vertical = 6.dp)
                        )
                    }
                }

                // Place Cards List in LIST and SPLIT layout modes
                if (activeViewLayout == "LIST" || activeViewLayout == "SPLIT") {
                    items(filteredPlaces, key = { it.id }) { place ->
                        DiscoveredPlaceCard(
                            place = place,
                            onViewListing = {
                                place.bookMySpaceVenueId?.let { venueId ->
                                    onNavigateToVenueDetails(venueId)
                                }
                            },
                            onClaimVenue = {
                                placeToClaim = place
                                showClaimSheet = true
                                claimSubmitted = false
                            }
                        )
                    }
                }
            }
        }
    }

    // Claim / Add Venue Modal Sheet
    if (showClaimSheet && placeToClaim != null) {
        val place = placeToClaim!!
        ModalBottomSheet(
            onDismissRequest = { showClaimSheet = false }
        ) {
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(24.dp)
            ) {
                if (claimSubmitted) {
                    Column(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalAlignment = Alignment.CenterHorizontally
                    ) {
                        Icon(Icons.Default.CheckCircle, contentDescription = null, tint = Color(0xFF2E7D32), modifier = Modifier.size(48.dp))
                        Spacer(modifier = Modifier.height(8.dp))
                        Text("Claim Request Initiated!", fontWeight = FontWeight.Bold, fontSize = 16.sp)
                        Text(
                            text = "We have recorded your ownership claim for '${place.name}'. Our verification team will verify property documents via WhatsApp / Call.",
                            fontSize = 12.sp,
                            textAlign = TextAlign.Center,
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                        Spacer(modifier = Modifier.height(16.dp))
                        Button(
                            onClick = {
                                showClaimSheet = false
                                onNavigateToClaimVenue(place)
                            },
                            modifier = Modifier.fillMaxWidth()
                        ) {
                            Text("Continue to Complete Listing Onboarding")
                        }
                    }
                } else {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Icon(Icons.Default.VerifiedUser, contentDescription = null, tint = MaterialTheme.colorScheme.primary)
                        Spacer(modifier = Modifier.width(8.dp))
                        Text(
                            text = "Claim / List '${place.name}'",
                            fontWeight = FontWeight.Bold,
                            fontSize = 16.sp
                        )
                    }

                    Spacer(modifier = Modifier.height(4.dp))
                    Text(
                        text = "Are you the owner or manager of this venue? Claim this listing to manage bookings, set pricing, and verify your space on BookMySpace.",
                        fontSize = 12.sp,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )

                    Spacer(modifier = Modifier.height(12.dp))

                    Surface(
                        shape = RoundedCornerShape(8.dp),
                        color = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.5f),
                        modifier = Modifier.fillMaxWidth()
                    ) {
                        Column(modifier = Modifier.padding(10.dp)) {
                            Text("Category: ${place.category}", fontSize = 12.sp, fontWeight = FontWeight.Medium)
                            Text("Address: ${place.displayAddress}", fontSize = 11.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                            Text("Source: ${place.source}", fontSize = 10.sp, color = MaterialTheme.colorScheme.primary)
                        }
                    }

                    Spacer(modifier = Modifier.height(12.dp))

                    OutlinedTextField(
                        value = claimOwnerName,
                        onValueChange = { claimOwnerName = it },
                        label = { Text("Your Full Name") },
                        modifier = Modifier.fillMaxWidth(),
                        singleLine = true
                    )

                    Spacer(modifier = Modifier.height(8.dp))

                    OutlinedTextField(
                        value = claimOwnerPhone,
                        onValueChange = { claimOwnerPhone = it },
                        label = { Text("Manager / Owner Phone Number") },
                        placeholder = { Text("e.g. 9876543210") },
                        keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Phone),
                        modifier = Modifier.fillMaxWidth(),
                        singleLine = true
                    )

                    Spacer(modifier = Modifier.height(16.dp))

                    Button(
                        onClick = {
                            claimSubmitted = true
                        },
                        modifier = Modifier.fillMaxWidth(),
                        enabled = claimOwnerName.isNotBlank() && claimOwnerPhone.length >= 10
                    ) {
                        Text("Submit Verification Claim")
                    }
                }
            }
        }
    }
}

/**
 * Individual Discovered Place Card
 */
@Composable
fun DiscoveredPlaceCard(
    place: PlaceDiscoveryModel,
    onViewListing: () -> Unit,
    onClaimVenue: () -> Unit,
    modifier: Modifier = Modifier
) {
    val context = LocalContext.current

    Card(
        modifier = modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp, vertical = 6.dp),
        shape = RoundedCornerShape(14.dp),
        elevation = CardDefaults.cardElevation(defaultElevation = 1.dp),
        colors = CardDefaults.cardColors(
            containerColor = MaterialTheme.colorScheme.surface
        ),
        border = BorderStroke(
            width = 1.dp,
            color = if (place.isRegisteredInBookMySpace)
                Color(0xFF2E7D32).copy(alpha = 0.4f)
            else
                MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.5f)
        )
    ) {
        Column(modifier = Modifier.padding(14.dp)) {
            // Header Row: Category Badge, Distance, and Verification Status
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                // Category Chip
                Surface(
                    shape = RoundedCornerShape(6.dp),
                    color = MaterialTheme.colorScheme.primaryContainer.copy(alpha = 0.6f)
                ) {
                    Text(
                        text = place.category,
                        fontSize = 11.sp,
                        fontWeight = FontWeight.Bold,
                        color = MaterialTheme.colorScheme.onPrimaryContainer,
                        modifier = Modifier.padding(horizontal = 8.dp, vertical = 3.dp)
                    )
                }

                // Registration / Discovery Badge
                if (place.isRegisteredInBookMySpace) {
                    Surface(
                        shape = RoundedCornerShape(6.dp),
                        color = Color(0xFFE8F5E9)
                    ) {
                        Row(
                            verticalAlignment = Alignment.CenterVertically,
                            modifier = Modifier.padding(horizontal = 6.dp, vertical = 3.dp)
                        ) {
                            Icon(
                                Icons.Default.CheckCircle,
                                contentDescription = null,
                                tint = Color(0xFF2E7D32),
                                modifier = Modifier.size(12.dp)
                            )
                            Spacer(modifier = Modifier.width(4.dp))
                            Text(
                                text = "BookMySpace Verified",
                                fontSize = 10.sp,
                                fontWeight = FontWeight.Bold,
                                color = Color(0xFF2E7D32)
                            )
                        }
                    }
                } else {
                    Surface(
                        shape = RoundedCornerShape(6.dp),
                        color = Color(0xFFFFF3E0)
                    ) {
                        Text(
                            text = "Discovered (${place.source})",
                            fontSize = 10.sp,
                            fontWeight = FontWeight.Medium,
                            color = Color(0xFFE65100),
                            modifier = Modifier.padding(horizontal = 6.dp, vertical = 3.dp)
                        )
                    }
                }
            }

            Spacer(modifier = Modifier.height(8.dp))

            // Place Name & Rating
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.Top
            ) {
                Text(
                    text = place.name,
                    fontWeight = FontWeight.Bold,
                    fontSize = 15.sp,
                    color = MaterialTheme.colorScheme.onSurface,
                    modifier = Modifier.weight(1f),
                    maxLines = 2,
                    overflow = TextOverflow.Ellipsis
                )

                if (place.rating > 0.0) {
                    Row(
                        verticalAlignment = Alignment.CenterVertically,
                        modifier = Modifier
                            .clip(RoundedCornerShape(6.dp))
                            .background(Color(0xFFFFF8E1))
                            .padding(horizontal = 6.dp, vertical = 2.dp)
                    ) {
                        Icon(Icons.Default.Star, contentDescription = null, tint = Color(0xFFFFA000), modifier = Modifier.size(12.dp))
                        Spacer(modifier = Modifier.width(2.dp))
                        Text(
                            text = "%.1f".format(place.rating),
                            fontSize = 11.sp,
                            fontWeight = FontWeight.Bold,
                            color = Color(0xFF5D4037)
                        )
                    }
                }
            }

            Spacer(modifier = Modifier.height(4.dp))

            // Address & Distance
            Row(verticalAlignment = Alignment.CenterVertically) {
                Icon(
                    Icons.Default.NearMe,
                    contentDescription = null,
                    tint = MaterialTheme.colorScheme.primary,
                    modifier = Modifier.size(13.dp)
                )
                Spacer(modifier = Modifier.width(4.dp))
                Text(
                    text = "${place.formattedDistance} • ${place.displayAddress}",
                    fontSize = 12.sp,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis
                )
            }

            if (place.openingHours.isNotBlank()) {
                Spacer(modifier = Modifier.height(2.dp))
                Text(
                    text = "⏰ Hours: ${place.openingHours}",
                    fontSize = 11.sp,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
            }

            Spacer(modifier = Modifier.height(10.dp))

            // Bottom Action Row
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                // Call / Contact icon if phone available
                if (place.phone.isNotBlank()) {
                    OutlinedButton(
                        onClick = {
                            val intent = Intent(Intent.ACTION_DIAL, Uri.parse("tel:${place.phone}"))
                            context.startActivity(intent)
                        },
                        shape = RoundedCornerShape(8.dp),
                        contentPadding = PaddingValues(horizontal = 10.dp, vertical = 4.dp),
                        modifier = Modifier.height(34.dp)
                    ) {
                        Icon(Icons.Default.Call, contentDescription = null, modifier = Modifier.size(14.dp))
                        Spacer(modifier = Modifier.width(4.dp))
                        Text("Call", fontSize = 11.sp)
                    }
                } else {
                    Spacer(modifier = Modifier.width(1.dp))
                }

                // Primary Action Button: Book Slot if registered, or Claim if unlisted
                if (place.isRegisteredInBookMySpace) {
                    Button(
                        onClick = onViewListing,
                        shape = RoundedCornerShape(8.dp),
                        contentPadding = PaddingValues(horizontal = 14.dp, vertical = 6.dp),
                        modifier = Modifier.height(34.dp)
                    ) {
                        Icon(Icons.Default.EventAvailable, contentDescription = null, modifier = Modifier.size(14.dp))
                        Spacer(modifier = Modifier.width(4.dp))
                        Text("Book Slot Now", fontSize = 12.sp, fontWeight = FontWeight.Bold)
                    }
                } else {
                    OutlinedButton(
                        onClick = onClaimVenue,
                        shape = RoundedCornerShape(8.dp),
                        contentPadding = PaddingValues(horizontal = 12.dp, vertical = 6.dp),
                        colors = ButtonDefaults.outlinedButtonColors(
                            contentColor = MaterialTheme.colorScheme.primary
                        ),
                        modifier = Modifier.height(34.dp)
                    ) {
                        Icon(Icons.Default.Storefront, contentDescription = null, modifier = Modifier.size(14.dp))
                        Spacer(modifier = Modifier.width(4.dp))
                        Text("Claim / Add Venue", fontSize = 11.sp, fontWeight = FontWeight.SemiBold)
                    }
                }
            }
        }
    }
}
