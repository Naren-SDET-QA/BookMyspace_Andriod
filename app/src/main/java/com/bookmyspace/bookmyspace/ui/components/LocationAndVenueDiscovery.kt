package com.bookmyspace.bookmyspace.ui.components

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
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
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
import com.bookmyspace.bookmyspace.data.healing.ModuleHealthStatus
import com.bookmyspace.bookmyspace.data.healing.SelfHealingManager
import com.bookmyspace.bookmyspace.data.location.IndiaLocationMasterData
import com.bookmyspace.bookmyspace.data.model.*
import com.bookmyspace.bookmyspace.data.repository.BookMySpaceRepository
import com.bookmyspace.bookmyspace.ui.screens.DiscoveryMode
import kotlinx.coroutines.Job
import kotlinx.coroutines.flow.collectLatest
import kotlinx.coroutines.launch

/**
 * Reusable LocationAndVenueDiscovery Compose Component.
 * Supports:
 * 1. Modular ON / OFF runtime toggle with graceful degradation & fallback
 * 2. Independent & Self-Healing fault recovery (India Post API -> Room DB -> Master Data Heuristics)
 * 3. Deep India Hierarchical Selection: Country -> State -> District -> Mandal/Tehsil -> Town/City/Village
 * 4. 6-Digit PIN Code input with automatic resolver (India Post API + fallback + offline cache)
 * 5. Automatic Discovery Engine with spatial radius slider and category filters
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun LocationAndVenueDiscovery(
    modifier: Modifier = Modifier,
    initialMode: DiscoveryMode = DiscoveryMode.HIERARCHICAL,
    showVenueList: Boolean = true,
    showModularControls: Boolean = true,
    onLocationConfirmed: ((LocationHierarchy, Double, Double, Double) -> Unit)? = null,
    onVenueClick: ((String) -> Unit)? = null,
    onClaimVenue: ((PlaceDiscoveryModel) -> Unit)? = null
) {
    val context = LocalContext.current
    val scope = rememberCoroutineScope()

    // --- Modular Feature Flag & Self Healing State ---
    val featureConfigs by BookMySpaceRepository.featureConfigs.collectAsState()
    val isFeatureEnabled = remember(featureConfigs) {
        featureConfigs.firstOrNull { it.key == AppFeatureKey.INDIA_PLACE_DISCOVERY }?.isEnabled
            ?: AppFeatureKey.INDIA_PLACE_DISCOVERY.defaultEnabled
    }
    val healthReports by SelfHealingManager.moduleHealthReports.collectAsState()
    val discoveryHealth = healthReports[AppFeatureKey.INDIA_PLACE_DISCOVERY]
    val isDiagnosticRunning by SelfHealingManager.isDiagnosticRunning.collectAsState()

    var showDiagnosticDialog by remember { mutableStateOf(false) }
    var diagnosticMessage by remember { mutableStateOf<String?>(null) }
    var isRepairingSubsystem by remember { mutableStateOf(false) }

    var selectedMode by remember { mutableStateOf(initialMode) }

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

    var discoveryJob by remember { mutableStateOf<Job?>(null) }

    fun triggerDiscoverySearch() {
        if (!showVenueList) return
        discoveryJob?.cancel()
        discoveryJob = scope.launch {
            isSearchingPlaces = true
            try {
                val categories = if (selectedCategorySlug == "all") emptyList() else listOf(selectedCategorySlug)
                PlaceDiscoveryEngine.discoverPlaces(
                    latitude = activeLatitude,
                    longitude = activeLongitude,
                    radiusKm = selectedRadiusKm,
                    categories = categories,
                    context = context
                ).collectLatest { places ->
                    discoveredPlaces = places
                    isSearchingPlaces = false
                }
            } catch (_: Exception) {
                isSearchingPlaces = false
            }
        }
    }

    // Resolve PIN code function
    fun performPinResolution(pin: String) {
        if (pin.length != 6 || !pin.all { it.isDigit() }) return
        scope.launch {
            isResolvingPin = true
            val result = IndianPinCodeResolver.resolvePinCode(pin, context)
            pinResolutionResult = result
            isResolvingPin = false

            if (result.isResolved) {
                activeLatitude = result.latitude
                activeLongitude = result.longitude
                selectedLocalityName = result.localities.firstOrNull()?.name ?: result.primaryLocality.ifBlank { result.district }
                activeLocationTitle = "${selectedLocalityName}, ${result.district}, ${result.state} ($pin)"
                triggerDiscoverySearch()
            }
        }
    }

    // Initial search launch
    LaunchedEffect(Unit) {
        triggerDiscoverySearch()
    }

    Column(
        modifier = modifier
            .fillMaxWidth()
            .testTag("location_and_venue_discovery_component")
    ) {
        // --- Modular ON/OFF & Self-Healing Status Bar ---
        if (showModularControls) {
            Card(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 16.dp, vertical = 6.dp)
                    .testTag("card_modular_discovery_header"),
                shape = RoundedCornerShape(16.dp),
                colors = CardDefaults.cardColors(
                    containerColor = if (isFeatureEnabled) {
                        MaterialTheme.colorScheme.primaryContainer.copy(alpha = 0.35f)
                    } else {
                        MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.5f)
                    }
                ),
                border = BorderStroke(
                    1.dp,
                    if (isFeatureEnabled) MaterialTheme.colorScheme.primary.copy(alpha = 0.4f)
                    else MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.4f)
                )
            ) {
                Column(modifier = Modifier.padding(12.dp)) {
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.SpaceBetween,
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Row(
                            verticalAlignment = Alignment.CenterVertically,
                            modifier = Modifier.weight(1f)
                        ) {
                            Text("🇮🇳", fontSize = 20.sp)
                            Spacer(modifier = Modifier.width(8.dp))
                            Column {
                                Text(
                                    text = "India Place Discovery Engine",
                                    fontWeight = FontWeight.Bold,
                                    fontSize = 14.sp,
                                    color = MaterialTheme.colorScheme.onSurface
                                )
                                Text(
                                    text = if (isFeatureEnabled) "Modular • Self-Healing Active" else "Module Switched OFF • Standby",
                                    fontSize = 11.sp,
                                    color = if (isFeatureEnabled) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.onSurfaceVariant
                                )
                            }
                        }

                        Row(verticalAlignment = Alignment.CenterVertically) {
                            // Health Status Pill
                            Surface(
                                shape = RoundedCornerShape(20.dp),
                                color = if (!isFeatureEnabled) Color(0xFF757575).copy(alpha = 0.15f)
                                else when (discoveryHealth?.status) {
                                    ModuleHealthStatus.HEALTHY -> Color(0xFF2E7D32).copy(alpha = 0.15f)
                                    ModuleHealthStatus.AUTO_RECOVERED -> Color(0xFF1976D2).copy(alpha = 0.15f)
                                    else -> Color(0xFFF57C00).copy(alpha = 0.15f)
                                },
                                modifier = Modifier
                                    .clickable { showDiagnosticDialog = true }
                                    .testTag("discovery_health_pill")
                            ) {
                                Row(
                                    modifier = Modifier.padding(horizontal = 8.dp, vertical = 4.dp),
                                    verticalAlignment = Alignment.CenterVertically
                                ) {
                                    Text(
                                        text = if (!isFeatureEnabled) "⚪ OFF"
                                        else when (discoveryHealth?.status) {
                                            ModuleHealthStatus.HEALTHY -> "🟢 Healthy"
                                            ModuleHealthStatus.AUTO_RECOVERED -> "🛡️ Healed"
                                            else -> "🟡 Active"
                                        },
                                        fontSize = 11.sp,
                                        fontWeight = FontWeight.SemiBold,
                                        color = if (!isFeatureEnabled) Color(0xFF616161)
                                        else when (discoveryHealth?.status) {
                                            ModuleHealthStatus.HEALTHY -> Color(0xFF1B5E20)
                                            ModuleHealthStatus.AUTO_RECOVERED -> Color(0xFF0D47A1)
                                            else -> Color(0xFFE65100)
                                        }
                                    )
                                }
                            }

                            Spacer(modifier = Modifier.width(8.dp))

                            // ON/OFF Switch
                            Switch(
                                checked = isFeatureEnabled,
                                onCheckedChange = { isEnabled ->
                                    BookMySpaceRepository.toggleFeature(AppFeatureKey.INDIA_PLACE_DISCOVERY, isEnabled)
                                    if (isEnabled) {
                                        triggerDiscoverySearch()
                                    }
                                },
                                modifier = Modifier.testTag("switch_discovery_module")
                            )
                        }
                    }

                    if (isFeatureEnabled) {
                        Spacer(modifier = Modifier.height(6.dp))
                        Row(
                            modifier = Modifier.fillMaxWidth(),
                            horizontalArrangement = Arrangement.SpaceBetween,
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            Text(
                                text = "Multi-tier: Postal API → Room DB → Master Data Cache",
                                fontSize = 10.5.sp,
                                color = MaterialTheme.colorScheme.onSurfaceVariant
                            )
                            TextButton(
                                onClick = { showDiagnosticDialog = true },
                                contentPadding = PaddingValues(horizontal = 4.dp, vertical = 0.dp),
                                modifier = Modifier.height(26.dp)
                            ) {
                                Text("🩺 Diagnostics", fontSize = 11.sp)
                            }
                        }
                    }
                }
            }
        }

        // Modular Standby Banner if OFF
        if (!isFeatureEnabled) {
            Card(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 16.dp, vertical = 8.dp)
                    .testTag("card_discovery_standby_banner"),
                shape = RoundedCornerShape(16.dp),
                colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.35f)),
                border = BorderStroke(1.dp, MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.5f))
            ) {
                Column(
                    modifier = Modifier.padding(16.dp),
                    horizontalAlignment = Alignment.CenterHorizontally
                ) {
                    Icon(
                        Icons.Default.PowerSettingsNew,
                        contentDescription = null,
                        modifier = Modifier.size(32.dp),
                        tint = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                    Spacer(modifier = Modifier.height(8.dp))
                    Text(
                        "Discovery Module is in Standby Mode",
                        fontWeight = FontWeight.Bold,
                        fontSize = 15.sp,
                        color = MaterialTheme.colorScheme.onSurface
                    )
                    Spacer(modifier = Modifier.height(4.dp))
                    Text(
                        "The India Place & Venue Discovery subsystem is independently isolated and switched OFF. Toggle it ON to enable dynamic multi-tier postal lookups and spatial Overpass mapping.",
                        fontSize = 12.sp,
                        textAlign = TextAlign.Center,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                    Spacer(modifier = Modifier.height(12.dp))
                    Button(
                        onClick = {
                            BookMySpaceRepository.toggleFeature(AppFeatureKey.INDIA_PLACE_DISCOVERY, true)
                            triggerDiscoverySearch()
                        },
                        shape = RoundedCornerShape(12.dp),
                        modifier = Modifier.testTag("btn_turn_on_discovery")
                    ) {
                        Icon(Icons.Default.Check, contentDescription = null, modifier = Modifier.size(16.dp))
                        Spacer(modifier = Modifier.width(6.dp))
                        Text("Turn ON Discovery Module", fontSize = 13.sp)
                    }
                }
            }
        }

        // Tab / Mode Switcher
        Card(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 16.dp, vertical = 6.dp)
                .testTag("card_discovery_mode_toggle"),
            shape = RoundedCornerShape(16.dp),
            colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.5f))
        ) {
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(4.dp),
                horizontalArrangement = Arrangement.spacedBy(4.dp)
            ) {
                DiscoveryMode.entries.forEach { mode ->
                    val isSelected = selectedMode == mode
                    Button(
                        onClick = {
                            selectedMode = mode
                            if (mode == DiscoveryMode.PIN_CODE && pinCodeInput.length == 6) {
                                performPinResolution(pinCodeInput)
                            }
                        },
                        modifier = Modifier
                            .weight(1f)
                            .testTag("btn_mode_${mode.name}"),
                        shape = RoundedCornerShape(12.dp),
                        colors = ButtonDefaults.buttonColors(
                            containerColor = if (isSelected) MaterialTheme.colorScheme.primary else Color.Transparent,
                            contentColor = if (isSelected) MaterialTheme.colorScheme.onPrimary else MaterialTheme.colorScheme.onSurfaceVariant
                        ),
                        elevation = ButtonDefaults.buttonElevation(defaultElevation = if (isSelected) 2.dp else 0.dp),
                        contentPadding = PaddingValues(vertical = 10.dp, horizontal = 8.dp)
                    ) {
                        Icon(mode.icon, contentDescription = null, modifier = Modifier.size(16.dp))
                        Spacer(modifier = Modifier.width(6.dp))
                        Text(
                            mode.title,
                            fontSize = 13.sp,
                            fontWeight = if (isSelected) FontWeight.Bold else FontWeight.Medium
                        )
                    }
                }
            }
        }

        // Section A: Hierarchical Selection Mode
        AnimatedVisibility(
            visible = selectedMode == DiscoveryMode.HIERARCHICAL,
            enter = fadeIn() + expandVertically(),
            exit = fadeOut() + shrinkVertically()
        ) {
            Card(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 16.dp, vertical = 6.dp)
                    .testTag("card_hierarchical_picker"),
                shape = RoundedCornerShape(16.dp),
                border = BorderStroke(1.dp, MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.6f)),
                colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface)
            ) {
                Column(modifier = Modifier.padding(16.dp)) {
                    Text(
                        "Hierarchical India Discovery",
                        style = MaterialTheme.typography.titleMedium,
                        fontWeight = FontWeight.Bold,
                        color = MaterialTheme.colorScheme.primary
                    )
                    Text(
                        "Select down to Mandal and Town/Village level for exact neighborhood matching",
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )

                    Spacer(modifier = Modifier.height(12.dp))

                    // 1. State Selector
                    val currentState = availableStates.find { it.id == selectedStateId }
                    ExposedDropdownMenuBox(
                        expanded = showStateMenu,
                        onExpandedChange = { showStateMenu = it },
                        modifier = Modifier.fillMaxWidth()
                    ) {
                        OutlinedTextField(
                            value = currentState?.name ?: "Select State",
                            onValueChange = {},
                            readOnly = true,
                            label = { Text("1. State") },
                            leadingIcon = { Icon(Icons.Default.Map, contentDescription = null, tint = MaterialTheme.colorScheme.primary) },
                            trailingIcon = { ExposedDropdownMenuDefaults.TrailingIcon(expanded = showStateMenu) },
                            modifier = Modifier
                                .menuAnchor()
                                .fillMaxWidth()
                                .testTag("field_select_state"),
                            shape = RoundedCornerShape(12.dp)
                        )
                        ExposedDropdownMenu(
                            expanded = showStateMenu,
                            onDismissRequest = { showStateMenu = false }
                        ) {
                            availableStates.forEach { state ->
                                DropdownMenuItem(
                                    text = { Text(state.name) },
                                    onClick = {
                                        selectedStateId = state.id
                                        showStateMenu = false
                                        val districts = IndiaLocationMasterData.getDistrictsForState(state.id)
                                        selectedDistrictId = districts.firstOrNull()?.id ?: ""
                                        val mandals = IndiaLocationMasterData.getMandalsForDistrict(selectedDistrictId)
                                        selectedMandalId = mandals.firstOrNull()?.id ?: ""
                                        val cities = IndiaLocationMasterData.getCitiesForMandal(selectedMandalId)
                                        val chosenCity = cities.firstOrNull()
                                        selectedCityId = chosenCity?.id ?: ""
                                        if (chosenCity != null) {
                                            activeLatitude = chosenCity.latitude
                                            activeLongitude = chosenCity.longitude
                                            activeLocationTitle = "${chosenCity.name}, ${state.name}"
                                        }
                                        triggerDiscoverySearch()
                                    }
                                )
                            }
                        }
                    }

                    Spacer(modifier = Modifier.height(8.dp))

                    // 2. District Selector
                    val currentDistrict = availableDistricts.find { it.id == selectedDistrictId }
                    ExposedDropdownMenuBox(
                        expanded = showDistrictMenu,
                        onExpandedChange = { showDistrictMenu = it },
                        modifier = Modifier.fillMaxWidth()
                    ) {
                        OutlinedTextField(
                            value = currentDistrict?.name ?: "Select District",
                            onValueChange = {},
                            readOnly = true,
                            label = { Text("2. District") },
                            leadingIcon = { Icon(Icons.Default.LocationCity, contentDescription = null, tint = MaterialTheme.colorScheme.primary) },
                            trailingIcon = { ExposedDropdownMenuDefaults.TrailingIcon(expanded = showDistrictMenu) },
                            modifier = Modifier
                                .menuAnchor()
                                .fillMaxWidth()
                                .testTag("field_select_district"),
                            shape = RoundedCornerShape(12.dp)
                        )
                        ExposedDropdownMenu(
                            expanded = showDistrictMenu,
                            onDismissRequest = { showDistrictMenu = false }
                        ) {
                            availableDistricts.forEach { dist ->
                                DropdownMenuItem(
                                    text = { Text(dist.name) },
                                    onClick = {
                                        selectedDistrictId = dist.id
                                        showDistrictMenu = false
                                        val mandals = IndiaLocationMasterData.getMandalsForDistrict(dist.id)
                                        selectedMandalId = mandals.firstOrNull()?.id ?: ""
                                        val cities = IndiaLocationMasterData.getCitiesForMandal(selectedMandalId)
                                        val chosenCity = cities.firstOrNull()
                                        selectedCityId = chosenCity?.id ?: ""
                                        if (chosenCity != null) {
                                            activeLatitude = chosenCity.latitude
                                            activeLongitude = chosenCity.longitude
                                            activeLocationTitle = "${chosenCity.name}, ${dist.name}"
                                        }
                                        triggerDiscoverySearch()
                                    }
                                )
                            }
                        }
                    }

                    Spacer(modifier = Modifier.height(8.dp))

                    // 3. Mandal / Taluk / Tehsil Selector
                    val currentMandal = availableMandals.find { it.id == selectedMandalId }
                    ExposedDropdownMenuBox(
                        expanded = showMandalMenu,
                        onExpandedChange = { showMandalMenu = it },
                        modifier = Modifier.fillMaxWidth()
                    ) {
                        OutlinedTextField(
                            value = currentMandal?.name ?: "Select Mandal / Taluk",
                            onValueChange = {},
                            readOnly = true,
                            label = { Text("3. Mandal / Taluk / Tehsil") },
                            leadingIcon = { Icon(Icons.Default.Explore, contentDescription = null, tint = MaterialTheme.colorScheme.secondary) },
                            trailingIcon = { ExposedDropdownMenuDefaults.TrailingIcon(expanded = showMandalMenu) },
                            modifier = Modifier
                                .menuAnchor()
                                .fillMaxWidth()
                                .testTag("field_select_mandal"),
                            shape = RoundedCornerShape(12.dp)
                        )
                        ExposedDropdownMenu(
                            expanded = showMandalMenu,
                            onDismissRequest = { showMandalMenu = false }
                        ) {
                            availableMandals.forEach { mandal ->
                                DropdownMenuItem(
                                    text = { Text(mandal.name) },
                                    onClick = {
                                        selectedMandalId = mandal.id
                                        showMandalMenu = false
                                        val cities = IndiaLocationMasterData.getCitiesForMandal(mandal.id)
                                        val chosenCity = cities.firstOrNull()
                                        selectedCityId = chosenCity?.id ?: ""
                                        if (chosenCity != null) {
                                            activeLatitude = chosenCity.latitude
                                            activeLongitude = chosenCity.longitude
                                            activeLocationTitle = "${chosenCity.name}, ${mandal.name}"
                                        }
                                        triggerDiscoverySearch()
                                    }
                                )
                            }
                        }
                    }

                    Spacer(modifier = Modifier.height(8.dp))

                    // 4. Town / City / Village Selector
                    val currentCity = availableCities.find { it.id == selectedCityId }
                    ExposedDropdownMenuBox(
                        expanded = showCityMenu,
                        onExpandedChange = { showCityMenu = it },
                        modifier = Modifier.fillMaxWidth()
                    ) {
                        OutlinedTextField(
                            value = currentCity?.name ?: "Select Town / City / Village",
                            onValueChange = {},
                            readOnly = true,
                            label = { Text("4. Town / Village") },
                            leadingIcon = { Icon(Icons.Default.HomeWork, contentDescription = null, tint = MaterialTheme.colorScheme.tertiary) },
                            trailingIcon = { ExposedDropdownMenuDefaults.TrailingIcon(expanded = showCityMenu) },
                            modifier = Modifier
                                .menuAnchor()
                                .fillMaxWidth()
                                .testTag("field_select_city"),
                            shape = RoundedCornerShape(12.dp)
                        )
                        ExposedDropdownMenu(
                            expanded = showCityMenu,
                            onDismissRequest = { showCityMenu = false }
                        ) {
                            availableCities.forEach { city ->
                                DropdownMenuItem(
                                    text = {
                                        Column {
                                            Text(city.name, fontWeight = FontWeight.Bold)
                                            if (city.postalCode.isNotBlank()) {
                                                Text("PIN: ${city.postalCode}", fontSize = 11.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                                            }
                                        }
                                    },
                                    onClick = {
                                        selectedCityId = city.id
                                        showCityMenu = false
                                        activeLatitude = city.latitude
                                        activeLongitude = city.longitude
                                        activeLocationTitle = "${city.name} (${currentMandal?.name ?: ""})"
                                        triggerDiscoverySearch()
                                    }
                                )
                            }
                        }
                    }

                    Spacer(modifier = Modifier.height(12.dp))

                    // Apply / Set as Current Location Button
                    Button(
                        onClick = {
                            val state = availableStates.find { it.id == selectedStateId }
                            val district = availableDistricts.find { it.id == selectedDistrictId }
                            val mandal = availableMandals.find { it.id == selectedMandalId }
                            val city = availableCities.find { it.id == selectedCityId }

                            val hierarchy = LocationHierarchy(
                                countryId = "IN",
                                countryName = "India",
                                stateId = selectedStateId,
                                stateName = state?.name ?: "Andhra Pradesh",
                                districtId = selectedDistrictId,
                                districtName = district?.name ?: "",
                                mandalId = selectedMandalId,
                                mandalName = mandal?.name ?: "",
                                cityTownId = selectedCityId,
                                cityName = city?.name ?: "",
                                postalCode = city?.postalCode ?: "",
                                latitude = activeLatitude,
                                longitude = activeLongitude
                            )
                            val radiusEnum = LocationSearchRadius.fromKm(selectedRadiusKm)
                            BookMySpaceRepository.setUserLocationHierarchy(hierarchy, radiusEnum)
                            onLocationConfirmed?.invoke(hierarchy, activeLatitude, activeLongitude, selectedRadiusKm)
                        },
                        modifier = Modifier
                            .fillMaxWidth()
                            .testTag("btn_confirm_hierarchy_location"),
                        shape = RoundedCornerShape(12.dp)
                    ) {
                        Icon(Icons.Default.CheckCircle, contentDescription = null)
                        Spacer(modifier = Modifier.width(8.dp))
                        Text("Apply Location (${activeLocationTitle})", fontWeight = FontWeight.Bold)
                    }
                }
            }
        }

        // Section B: 6-Digit PIN Code Mode
        AnimatedVisibility(
            visible = selectedMode == DiscoveryMode.PIN_CODE,
            enter = fadeIn() + expandVertically(),
            exit = fadeOut() + shrinkVertically()
        ) {
            Card(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 16.dp, vertical = 6.dp)
                    .testTag("card_pin_code_resolver"),
                shape = RoundedCornerShape(16.dp),
                border = BorderStroke(1.dp, MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.6f)),
                colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface)
            ) {
                Column(modifier = Modifier.padding(16.dp)) {
                    Text(
                        "6-Digit Indian PIN Code Resolver",
                        style = MaterialTheme.typography.titleMedium,
                        fontWeight = FontWeight.Bold,
                        color = MaterialTheme.colorScheme.primary
                    )
                    Text(
                        "Enter any Indian 6-digit postal PIN code for automatic district, mandal & locality geocoding",
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )

                    Spacer(modifier = Modifier.height(12.dp))

                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        OutlinedTextField(
                            value = pinCodeInput,
                            onValueChange = { input ->
                                val cleaned = input.filter { it.isDigit() }.take(6)
                                pinCodeInput = cleaned
                                if (cleaned.length == 6) {
                                    performPinResolution(cleaned)
                                }
                            },
                            label = { Text("PIN Code (e.g. 516227, 560001)") },
                            leadingIcon = { Icon(Icons.Default.PinDrop, contentDescription = null, tint = MaterialTheme.colorScheme.primary) },
                            trailingIcon = {
                                if (isResolvingPin) {
                                    CircularProgressIndicator(modifier = Modifier.size(20.dp), strokeWidth = 2.dp)
                                } else if (pinCodeInput.length == 6 && pinResolutionResult?.isResolved == true) {
                                    Icon(Icons.Default.CheckCircle, contentDescription = "Valid", tint = Color(0xFF2E7D32))
                                }
                            },
                            keyboardOptions = KeyboardOptions(
                                keyboardType = KeyboardType.Number,
                                imeAction = ImeAction.Search
                            ),
                            keyboardActions = KeyboardActions(onSearch = { performPinResolution(pinCodeInput) }),
                            modifier = Modifier
                                .weight(1f)
                                .testTag("input_pin_code"),
                            shape = RoundedCornerShape(12.dp),
                            singleLine = true
                        )

                        Spacer(modifier = Modifier.width(8.dp))

                        Button(
                            onClick = { performPinResolution(pinCodeInput) },
                            enabled = pinCodeInput.length == 6 && !isResolvingPin,
                            shape = RoundedCornerShape(12.dp),
                            modifier = Modifier
                                .height(56.dp)
                                .testTag("btn_lookup_pin")
                        ) {
                            Text("Resolve")
                        }
                    }

                    // Resolution Info Card
                    pinResolutionResult?.let { res ->
                        Spacer(modifier = Modifier.height(10.dp))
                        if (res.isResolved) {
                            Surface(
                                modifier = Modifier.fillMaxWidth(),
                                shape = RoundedCornerShape(12.dp),
                                color = MaterialTheme.colorScheme.primaryContainer.copy(alpha = 0.4f),
                                border = BorderStroke(1.dp, MaterialTheme.colorScheme.primary.copy(alpha = 0.3f))
                            ) {
                                Column(modifier = Modifier.padding(12.dp)) {
                                    Row(verticalAlignment = Alignment.CenterVertically) {
                                        Icon(Icons.Default.Verified, contentDescription = null, tint = MaterialTheme.colorScheme.primary, modifier = Modifier.size(18.dp))
                                        Spacer(modifier = Modifier.width(6.dp))
                                        Text(
                                            "${res.district}, ${res.state}",
                                            fontWeight = FontWeight.Bold,
                                            color = MaterialTheme.colorScheme.onPrimaryContainer
                                        )
                                        Spacer(modifier = Modifier.weight(1f))
                                        Text("Source: ${res.source}", fontSize = 10.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                                    }

                                    if (res.localities.isNotEmpty()) {
                                        Spacer(modifier = Modifier.height(6.dp))
                                        Text("Localities / Post Offices in this PIN:", fontSize = 11.sp, fontWeight = FontWeight.SemiBold)
                                        Spacer(modifier = Modifier.height(4.dp))
                                        LazyRow(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                                            items(res.localities) { locality ->
                                                val isLocalitySelected = selectedLocalityName == locality.name
                                                FilterChip(
                                                    selected = isLocalitySelected,
                                                    onClick = {
                                                        selectedLocalityName = locality.name
                                                        activeLocationTitle = "${locality.name}, ${res.district} (${res.pincode})"
                                                        triggerDiscoverySearch()
                                                    },
                                                    label = { Text(locality.name, fontSize = 11.sp) },
                                                    leadingIcon = if (isLocalitySelected) {
                                                        { Icon(Icons.Default.Check, contentDescription = null, modifier = Modifier.size(14.dp)) }
                                                    } else null
                                                )
                                            }
                                        }
                                    }

                                    Spacer(modifier = Modifier.height(8.dp))
                                    Button(
                                        onClick = {
                                            val hierarchy = LocationHierarchy(
                                                countryId = "IN",
                                                countryName = "India",
                                                stateName = res.state,
                                                districtName = res.district,
                                                cityName = selectedLocalityName.ifBlank { res.primaryLocality.ifBlank { res.district } },
                                                postalCode = res.pincode,
                                                latitude = res.latitude,
                                                longitude = res.longitude
                                            )
                                            val radiusEnum = LocationSearchRadius.fromKm(selectedRadiusKm)
                                            BookMySpaceRepository.setUserLocationHierarchy(hierarchy, radiusEnum)
                                            onLocationConfirmed?.invoke(hierarchy, res.latitude, res.longitude, selectedRadiusKm)
                                        },
                                        modifier = Modifier
                                            .fillMaxWidth()
                                            .testTag("btn_confirm_pin_location"),
                                        shape = RoundedCornerShape(10.dp)
                                    ) {
                                        Text("Set ${res.pincode} as Active App Location", fontSize = 12.sp, fontWeight = FontWeight.Bold)
                                    }
                                }
                            }
                        } else {
                            Surface(
                                modifier = Modifier.fillMaxWidth(),
                                shape = RoundedCornerShape(12.dp),
                                color = MaterialTheme.colorScheme.errorContainer.copy(alpha = 0.4f)
                            ) {
                                Row(
                                    modifier = Modifier.padding(12.dp),
                                    verticalAlignment = Alignment.CenterVertically
                                ) {
                                    Icon(Icons.Default.ErrorOutline, contentDescription = null, tint = MaterialTheme.colorScheme.error)
                                    Spacer(modifier = Modifier.width(8.dp))
                                    Text(res.errorMessage ?: "PIN code not recognized.", color = MaterialTheme.colorScheme.onErrorContainer, fontSize = 12.sp)
                                }
                            }
                        }
                    }
                }
            }
        }

        // Section C: Radius & Category Discovery Bar
        if (showVenueList) {
            Card(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 16.dp, vertical = 6.dp)
                    .testTag("card_discovery_controls"),
                shape = RoundedCornerShape(16.dp),
                colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.35f))
            ) {
                Column(modifier = Modifier.padding(14.dp)) {
                    // Radius Slider
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.SpaceBetween,
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Text(
                            "Discovery Radius: ${selectedRadiusKm.toInt()} km",
                            style = MaterialTheme.typography.bodyMedium,
                            fontWeight = FontWeight.Bold
                        )
                        Text(
                            "Center: ${activeLocationTitle.take(24)}...",
                            style = MaterialTheme.typography.bodySmall,
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                    }

                    Slider(
                        value = selectedRadiusKm.toFloat(),
                        onValueChange = { selectedRadiusKm = it.toDouble() },
                        onValueChangeFinished = { triggerDiscoverySearch() },
                        valueRange = 1f..50f,
                        steps = 9,
                        modifier = Modifier
                            .fillMaxWidth()
                            .testTag("slider_discovery_radius")
                    )

                    // Categories Strip
                    val categories = listOf(
                        "all" to "All Venues",
                        "marriage_hall" to "Function Halls",
                        "banquet_hall" to "Banquets",
                        "hotel" to "Hotels & Lodges",
                        "hostel_pg" to "PG & Hostels",
                        "coaching" to "Institutes",
                        "sports" to "Sports"
                    )

                    LazyRow(
                        horizontalArrangement = Arrangement.spacedBy(8.dp),
                        modifier = Modifier.fillMaxWidth()
                    ) {
                        items(categories) { (slug, label) ->
                            val isCatSelected = selectedCategorySlug == slug
                            FilterChip(
                                selected = isCatSelected,
                                onClick = {
                                    selectedCategorySlug = slug
                                    triggerDiscoverySearch()
                                },
                                label = { Text(label, fontSize = 12.sp, fontWeight = if (isCatSelected) FontWeight.Bold else FontWeight.Normal) },
                                shape = RoundedCornerShape(20.dp),
                                modifier = Modifier.testTag("chip_cat_$slug")
                            )
                        }
                    }
                }
            }

            // Section D: Discovered Places List
            val filteredPlaces = remember(discoveredPlaces, placeSearchQuery, selectedSortBy) {
                val list = if (placeSearchQuery.isBlank()) discoveredPlaces else {
                    discoveredPlaces.filter {
                        it.name.contains(placeSearchQuery, ignoreCase = true) ||
                                it.address.contains(placeSearchQuery, ignoreCase = true) ||
                                it.category.contains(placeSearchQuery, ignoreCase = true)
                    }
                }
                when (selectedSortBy) {
                    DiscoverySortBy.NEAREST -> list.sortedBy { it.distanceKm }
                    DiscoverySortBy.HIGHEST_RATED -> list.sortedByDescending { it.rating }
                    DiscoverySortBy.NAME_AZ -> list.sortedBy { it.name }
                    DiscoverySortBy.CATEGORY -> list.sortedBy { it.category }
                }
            }

            // Header Row with Results Count, Layout Mode Toggles (Google Map, List, Split), and Refresh
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 16.dp, vertical = 6.dp),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Column {
                    Text(
                        "Discovered Spaces (${filteredPlaces.size})",
                        style = MaterialTheme.typography.titleMedium,
                        fontWeight = FontWeight.Bold
                    )
                    Text(
                        "Showing venues on Google Maps SDK",
                        fontSize = 10.5.sp,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                }

                Row(verticalAlignment = Alignment.CenterVertically) {
                    // Map / List / Split View Mode Switcher
                    Surface(
                        shape = RoundedCornerShape(20.dp),
                        color = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.6f),
                        modifier = Modifier.padding(end = 4.dp)
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
                                    .testTag("btn_toggle_map_view")
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
                                    .testTag("btn_toggle_split_view")
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
                                    .testTag("btn_toggle_list_view")
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

                    IconButton(
                        onClick = { triggerDiscoverySearch() },
                        modifier = Modifier.size(32.dp)
                    ) {
                        Icon(Icons.Default.Refresh, contentDescription = "Refresh search", modifier = Modifier.size(18.dp))
                    }
                }
            }

            if (isSearchingPlaces) {
                Box(
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(180.dp),
                    contentAlignment = Alignment.Center
                ) {
                    Column(horizontalAlignment = Alignment.CenterHorizontally) {
                        CircularProgressIndicator(modifier = Modifier.size(36.dp))
                        Spacer(modifier = Modifier.height(12.dp))
                        Text("Discovering bookable spaces across India master records...", style = MaterialTheme.typography.bodySmall)
                    }
                }
            } else if (filteredPlaces.isEmpty()) {
                Card(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(horizontal = 16.dp, vertical = 8.dp),
                    colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.3f)),
                    shape = RoundedCornerShape(16.dp)
                ) {
                    Column(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(24.dp),
                        horizontalAlignment = Alignment.CenterHorizontally
                    ) {
                        Icon(Icons.Default.LocationOff, contentDescription = null, modifier = Modifier.size(48.dp), tint = MaterialTheme.colorScheme.onSurfaceVariant)
                        Spacer(modifier = Modifier.height(8.dp))
                        Text("No venues found in this immediate radius", fontWeight = FontWeight.Bold)
                        Spacer(modifier = Modifier.height(4.dp))
                        Text(
                            "Try expanding the discovery radius slider up to 50 km or selecting a different Mandal/City.",
                            fontSize = 12.sp,
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                            textAlign = TextAlign.Center
                        )
                    }
                }
            } else {
                // Layout rendering based on activeViewLayout
                Column(
                    modifier = Modifier.fillMaxWidth(),
                    verticalArrangement = Arrangement.spacedBy(10.dp)
                ) {
                    // Google Maps View (In MAP or SPLIT modes)
                    if (activeViewLayout == "MAP" || activeViewLayout == "SPLIT") {
                        DiscoveredPlacesGoogleMapView(
                            places = filteredPlaces,
                            centerLatitude = activeLatitude,
                            centerLongitude = activeLongitude,
                            radiusKm = selectedRadiusKm,
                            locationTitle = activeLocationTitle,
                            selectedPlaceId = selectedMapPlaceId,
                            onPlaceSelected = { place -> selectedMapPlaceId = place.id },
                            onNavigateToVenueDetails = { venueId -> onVenueClick?.invoke(venueId) },
                            onClaimVenue = { place ->
                                placeToClaim = place
                                showClaimSheet = true
                            },
                            onRadiusChanged = { newRad ->
                                selectedRadiusKm = newRad
                                triggerDiscoverySearch()
                            },
                            modifier = Modifier
                                .fillMaxWidth()
                                .padding(horizontal = 16.dp)
                        )
                    }

                    // List of Cards (In LIST or SPLIT modes)
                    if (activeViewLayout == "LIST" || activeViewLayout == "SPLIT") {
                        LazyColumn(
                            modifier = Modifier
                                .fillMaxWidth()
                                .heightIn(max = if (activeViewLayout == "SPLIT") 400.dp else 600.dp)
                                .padding(horizontal = 16.dp),
                            verticalArrangement = Arrangement.spacedBy(10.dp)
                        ) {
                            items(filteredPlaces, key = { it.id }) { place ->
                                PlaceDiscoveryCard(
                                    place = place,
                                    onVenueClick = {
                                        if (place.isRegisteredInBookMySpace && !place.bookMySpaceVenueId.isNullOrBlank()) {
                                            onVenueClick?.invoke(place.bookMySpaceVenueId)
                                        } else {
                                            placeToClaim = place
                                            showClaimSheet = true
                                        }
                                    },
                                    onClaimClick = {
                                        placeToClaim = place
                                        showClaimSheet = true
                                    },
                                    onCallClick = { phone ->
                                        try {
                                            val intent = Intent(Intent.ACTION_DIAL, Uri.parse("tel:$phone"))
                                            context.startActivity(intent)
                                        } catch (_: Exception) { }
                                    },
                                    onMapClick = { lat, lon, name ->
                                        // Highlight marker on map & switch to map view
                                        selectedMapPlaceId = place.id
                                        activeViewLayout = "MAP"
                                    }
                                )
                            }
                        }
                    }
                }
            }
        }
    }

    // Claim Venue Modal Sheet
    if (showClaimSheet && placeToClaim != null) {
        val place = placeToClaim!!
        ModalBottomSheet(
            onDismissRequest = {
                showClaimSheet = false
                claimSubmitted = false
            }
        ) {
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 24.dp, vertical = 16.dp)
                    .testTag("sheet_claim_venue")
            ) {
                if (!claimSubmitted) {
                    Text("Claim & Register Venue", style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.Bold)
                    Text("Are you the owner or manager of ${place.name}?", style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)

                    Spacer(modifier = Modifier.height(16.dp))

                    OutlinedTextField(
                        value = claimOwnerName,
                        onValueChange = { claimOwnerName = it },
                        label = { Text("Your Full Name") },
                        leadingIcon = { Icon(Icons.Default.Person, contentDescription = null) },
                        modifier = Modifier.fillMaxWidth(),
                        shape = RoundedCornerShape(12.dp)
                    )

                    Spacer(modifier = Modifier.height(10.dp))

                    OutlinedTextField(
                        value = claimOwnerPhone,
                        onValueChange = { claimOwnerPhone = it },
                        label = { Text("Mobile Phone Number") },
                        leadingIcon = { Icon(Icons.Default.Phone, contentDescription = null) },
                        keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Phone),
                        modifier = Modifier.fillMaxWidth(),
                        shape = RoundedCornerShape(12.dp)
                    )

                    Spacer(modifier = Modifier.height(16.dp))

                    Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                        OutlinedButton(
                            onClick = { showClaimSheet = false },
                            modifier = Modifier.weight(1f),
                            shape = RoundedCornerShape(12.dp)
                        ) {
                            Text("Cancel")
                        }

                        Button(
                            onClick = {
                                claimSubmitted = true
                                onClaimVenue?.invoke(place)
                            },
                            enabled = claimOwnerName.isNotBlank() && claimOwnerPhone.isNotBlank(),
                            modifier = Modifier.weight(1f),
                            shape = RoundedCornerShape(12.dp)
                        ) {
                            Text("Submit Claim")
                        }
                    }
                } else {
                    Column(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(vertical = 20.dp),
                        horizontalAlignment = Alignment.CenterHorizontally
                    ) {
                        Icon(Icons.Default.CheckCircle, contentDescription = null, tint = Color(0xFF2E7D32), modifier = Modifier.size(56.dp))
                        Spacer(modifier = Modifier.height(12.dp))
                        Text("Claim Request Received!", style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.Bold)
                        Spacer(modifier = Modifier.height(6.dp))
                        Text("Our onboarding team will contact you at $claimOwnerPhone to verify ownership of ${place.name}.", textAlign = TextAlign.Center, color = MaterialTheme.colorScheme.onSurfaceVariant)
                        Spacer(modifier = Modifier.height(16.dp))
                        Button(
                            onClick = {
                                showClaimSheet = false
                                claimSubmitted = false
                            },
                            shape = RoundedCornerShape(12.dp)
                        ) {
                            Text("Done")
                        }
                    }
                }
                Spacer(modifier = Modifier.height(24.dp))
            }
        }
    }

    // --- Self-Healing Diagnostics & Subsystem Health Dialog ---
    if (showDiagnosticDialog) {
        AlertDialog(
            onDismissRequest = { showDiagnosticDialog = false },
            title = {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Text("🩺", fontSize = 22.sp)
                    Spacer(modifier = Modifier.width(8.dp))
                    Text("Subsystem Health & Self-Healing", fontWeight = FontWeight.Bold, fontSize = 17.sp)
                }
            },
            text = {
                Column(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(vertical = 4.dp),
                    verticalArrangement = Arrangement.spacedBy(10.dp)
                ) {
                    // Status summary card
                    Card(
                        shape = RoundedCornerShape(12.dp),
                        colors = CardDefaults.cardColors(
                            containerColor = if (!isFeatureEnabled) Color(0xFF757575).copy(alpha = 0.12f)
                            else when (discoveryHealth?.status) {
                                ModuleHealthStatus.HEALTHY -> Color(0xFF2E7D32).copy(alpha = 0.12f)
                                ModuleHealthStatus.AUTO_RECOVERED -> Color(0xFF1976D2).copy(alpha = 0.12f)
                                else -> Color(0xFFF57C00).copy(alpha = 0.12f)
                            }
                        )
                    ) {
                        Row(
                            modifier = Modifier
                                .fillMaxWidth()
                                .padding(12.dp),
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            Icon(
                                if (!isFeatureEnabled) Icons.Default.PowerSettingsNew
                                else when (discoveryHealth?.status) {
                                    ModuleHealthStatus.HEALTHY -> Icons.Default.CheckCircle
                                    ModuleHealthStatus.AUTO_RECOVERED -> Icons.Default.Shield
                                    else -> Icons.Default.Warning
                                },
                                contentDescription = null,
                                tint = if (!isFeatureEnabled) Color(0xFF616161)
                                else when (discoveryHealth?.status) {
                                    ModuleHealthStatus.HEALTHY -> Color(0xFF2E7D32)
                                    ModuleHealthStatus.AUTO_RECOVERED -> Color(0xFF1976D2)
                                    else -> Color(0xFFF57C00)
                                },
                                modifier = Modifier.size(24.dp)
                            )
                            Spacer(modifier = Modifier.width(10.dp))
                            Column {
                                Text(
                                    text = if (!isFeatureEnabled) "Module Disabled (Standby)"
                                    else "Status: ${discoveryHealth?.status?.name ?: "ACTIVE"}",
                                    fontWeight = FontWeight.Bold,
                                    fontSize = 13.sp
                                )
                                Text(
                                    text = discoveryHealth?.lastHealingAction ?: "Resilient multi-tier architecture active",
                                    fontSize = 11.sp,
                                    color = MaterialTheme.colorScheme.onSurfaceVariant
                                )
                            }
                        }
                    }

                    // Diagnostic info lines
                    Text(
                        "Resilience Multi-Tier Strategy:",
                        fontWeight = FontWeight.SemiBold,
                        fontSize = 12.sp
                    )

                    Column(
                        modifier = Modifier
                            .fillMaxWidth()
                            .clip(RoundedCornerShape(8.dp))
                            .background(MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.4f))
                            .padding(8.dp),
                        verticalArrangement = Arrangement.spacedBy(4.dp)
                    ) {
                        Text("1. India Post Postal API (Live Network)", fontSize = 11.sp, color = MaterialTheme.colorScheme.onSurface)
                        Text("2. Room Database SQLite Cache (Offline Persistent)", fontSize = 11.sp, color = MaterialTheme.colorScheme.onSurface)
                        Text("3. India Location Master Data (Embedded Presets)", fontSize = 11.sp, color = MaterialTheme.colorScheme.onSurface)
                        Text("4. Heuristic Regional Postal Zone Geocoding", fontSize = 11.sp, color = MaterialTheme.colorScheme.onSurface)
                    }

                    if (diagnosticMessage != null) {
                        Surface(
                            shape = RoundedCornerShape(8.dp),
                            color = Color(0xFF2E7D32).copy(alpha = 0.15f),
                            modifier = Modifier.fillMaxWidth()
                        ) {
                            Text(
                                text = diagnosticMessage ?: "",
                                fontSize = 11.5.sp,
                                color = Color(0xFF1B5E20),
                                modifier = Modifier.padding(8.dp)
                            )
                        }
                    }

                    // Action buttons
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.spacedBy(8.dp)
                    ) {
                        OutlinedButton(
                            onClick = {
                                scope.launch {
                                    isRepairingSubsystem = true
                                    diagnosticMessage = "Sanitizing cache and verifying integrity..."
                                    SelfHealingManager.repairLocationAndDiscoverySubsystem(context)
                                    diagnosticMessage = "✓ Diagnostic & Auto-Repair Complete. Subsystem is healthy."
                                    isRepairingSubsystem = false
                                    triggerDiscoverySearch()
                                }
                            },
                            modifier = Modifier
                                .weight(1f)
                                .testTag("btn_repair_subsystem"),
                            shape = RoundedCornerShape(10.dp),
                            enabled = !isRepairingSubsystem && !isDiagnosticRunning
                        ) {
                            if (isRepairingSubsystem) {
                                CircularProgressIndicator(modifier = Modifier.size(14.dp), strokeWidth = 2.dp)
                            } else {
                                Icon(Icons.Default.Healing, contentDescription = null, modifier = Modifier.size(14.dp))
                            }
                            Spacer(modifier = Modifier.width(4.dp))
                            Text("Auto-Repair", fontSize = 12.sp)
                        }

                        Button(
                            onClick = {
                                scope.launch {
                                    SelfHealingManager.runFullSystemDiagnostic(context)
                                    diagnosticMessage = "✓ Full system diagnostic verified."
                                }
                            },
                            modifier = Modifier
                                .weight(1f)
                                .testTag("btn_run_diagnostic"),
                            shape = RoundedCornerShape(10.dp),
                            enabled = !isDiagnosticRunning
                        ) {
                            Icon(Icons.Default.PlayArrow, contentDescription = null, modifier = Modifier.size(14.dp))
                            Spacer(modifier = Modifier.width(4.dp))
                            Text("Full Scan", fontSize = 12.sp)
                        }
                    }
                }
            },
            confirmButton = {
                TextButton(onClick = { showDiagnosticDialog = false }) {
                    Text("Close")
                }
            }
        )
    }
}

/**
 * Visual Card representing an automatically discovered place or verified BookMySpace venue
 */
@Composable
fun PlaceDiscoveryCard(
    place: PlaceDiscoveryModel,
    onVenueClick: () -> Unit,
    onClaimClick: () -> Unit,
    onCallClick: (String) -> Unit,
    onMapClick: (Double, Double, String) -> Unit,
    modifier: Modifier = Modifier
) {
    Card(
        modifier = modifier
            .fillMaxWidth()
            .clickable(onClick = onVenueClick)
            .testTag("card_place_${place.id}"),
        shape = RoundedCornerShape(16.dp),
        border = BorderStroke(
            1.dp,
            if (place.isRegisteredInBookMySpace) MaterialTheme.colorScheme.primary.copy(alpha = 0.5f)
            else MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.4f)
        ),
        colors = CardDefaults.cardColors(
            containerColor = if (place.isRegisteredInBookMySpace) MaterialTheme.colorScheme.primaryContainer.copy(alpha = 0.15f)
            else MaterialTheme.colorScheme.surface
        )
    ) {
        Column(modifier = Modifier.padding(14.dp)) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                verticalAlignment = Alignment.Top
            ) {
                if (place.photoUrl.isNotBlank()) {
                    AsyncImage(
                        model = place.photoUrl,
                        contentDescription = place.name,
                        contentScale = ContentScale.Crop,
                        modifier = Modifier
                            .size(72.dp)
                            .clip(RoundedCornerShape(12.dp))
                    )
                    Spacer(modifier = Modifier.width(12.dp))
                }

                Column(modifier = Modifier.weight(1f)) {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Text(
                            place.name,
                            style = MaterialTheme.typography.titleMedium,
                            fontWeight = FontWeight.Bold,
                            maxLines = 1,
                            overflow = TextOverflow.Ellipsis,
                            modifier = Modifier.weight(1f)
                        )
                        if (place.isRegisteredInBookMySpace) {
                            Surface(
                                shape = RoundedCornerShape(6.dp),
                                color = MaterialTheme.colorScheme.primary,
                                modifier = Modifier.padding(start = 4.dp)
                            ) {
                                Row(
                                    modifier = Modifier.padding(horizontal = 6.dp, vertical = 2.dp),
                                    verticalAlignment = Alignment.CenterVertically
                                ) {
                                    Icon(Icons.Default.Verified, contentDescription = null, tint = Color.White, modifier = Modifier.size(12.dp))
                                    Spacer(modifier = Modifier.width(2.dp))
                                    Text("BMS Verified", fontSize = 10.sp, color = Color.White, fontWeight = FontWeight.Bold)
                                }
                            }
                        }
                    }

                    Spacer(modifier = Modifier.height(2.dp))

                    Text(
                        "${place.category} • ${place.displayAddress}",
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis
                    )

                    Spacer(modifier = Modifier.height(4.dp))

                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.SpaceBetween,
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            Icon(Icons.Default.NearMe, contentDescription = null, tint = MaterialTheme.colorScheme.primary, modifier = Modifier.size(14.dp))
                            Spacer(modifier = Modifier.width(2.dp))
                            Text(
                                place.formattedDistance,
                                fontSize = 12.sp,
                                fontWeight = FontWeight.SemiBold,
                                color = MaterialTheme.colorScheme.primary
                            )
                        }

                        if (place.rating > 0.0) {
                            Row(verticalAlignment = Alignment.CenterVertically) {
                                Icon(Icons.Default.Star, contentDescription = null, tint = Color(0xFFFFB300), modifier = Modifier.size(14.dp))
                                Spacer(modifier = Modifier.width(2.dp))
                                Text("%.1f (%d)".format(place.rating, place.reviewCount), fontSize = 12.sp, fontWeight = FontWeight.Bold)
                            }
                        }
                    }
                }
            }

            Spacer(modifier = Modifier.height(10.dp))

            // Action Buttons Row
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(8.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                if (place.isRegisteredInBookMySpace) {
                    Button(
                        onClick = onVenueClick,
                        modifier = Modifier.weight(1f),
                        shape = RoundedCornerShape(10.dp)
                    ) {
                        Text("Book Now", fontWeight = FontWeight.Bold, fontSize = 12.sp)
                    }
                } else {
                    OutlinedButton(
                        onClick = onClaimClick,
                        modifier = Modifier.weight(1f),
                        shape = RoundedCornerShape(10.dp)
                    ) {
                        Icon(Icons.Default.AppRegistration, contentDescription = null, modifier = Modifier.size(14.dp))
                        Spacer(modifier = Modifier.width(4.dp))
                        Text("Claim Listing", fontSize = 12.sp, fontWeight = FontWeight.SemiBold)
                    }
                }

                if (place.phone.isNotBlank()) {
                    FilledTonalIconButton(
                        onClick = { onCallClick(place.phone) },
                        modifier = Modifier.size(36.dp)
                    ) {
                        Icon(Icons.Default.Phone, contentDescription = "Call venue", modifier = Modifier.size(18.dp))
                    }
                }

                FilledTonalIconButton(
                    onClick = { onMapClick(place.latitude, place.longitude, place.name) },
                    modifier = Modifier.size(36.dp)
                ) {
                    Icon(Icons.Default.Directions, contentDescription = "Directions", modifier = Modifier.size(18.dp))
                }
            }
        }
    }
}
