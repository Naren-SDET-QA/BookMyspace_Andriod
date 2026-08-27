package com.bookmyspace.bookmyspace.ui.screens

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.widget.Toast
import androidx.compose.animation.*
import androidx.compose.foundation.*
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.*
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.*
import androidx.compose.material.icons.outlined.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import coil.compose.AsyncImage
import com.bookmyspace.bookmyspace.data.model.*
import com.bookmyspace.bookmyspace.data.repository.BookMySpaceRepository
import com.bookmyspace.bookmyspace.ui.components.LocationHierarchyHeaderBar
import com.bookmyspace.bookmyspace.ui.components.LocationHierarchySelectorDialog
import kotlinx.coroutines.launch
import java.util.UUID

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun InstitutesAndClassesScreen(
    onNavigateBack: () -> Unit,
    onNavigateToOwnerDashboard: () -> Unit = {}
) {
    val context = LocalContext.current
    val coroutineScope = rememberCoroutineScope()
    val snackbarHostState = remember { SnackbarHostState() }

    val classes by BookMySpaceRepository.instituteClasses.collectAsState()
    val authUser by BookMySpaceRepository.authUser.collectAsState()
    val userLocationHierarchy by BookMySpaceRepository.userLocationHierarchy.collectAsState()
    val userLocationRadius by BookMySpaceRepository.userLocationRadius.collectAsState()

    var showLocationDialog by remember { mutableStateOf(false) }
    var searchQuery by remember { mutableStateOf("") }
    var selectedCategory by remember { mutableStateOf("All") }
    var selectedCategories by remember { mutableStateOf<Set<String>>(emptySet()) }
    var selectedMode by remember { mutableStateOf<ClassDeliveryMode?>(null) }
    var showOnlyOngoingToday by remember { mutableStateOf(false) }
    var showFullBatchesOnly by remember { mutableStateOf(false) }
    var showRightCategoryFilterDrawer by remember { mutableStateOf(false) }

    // Single Tab Booking Modal State
    var bookingClassTarget by remember { mutableStateOf<InstituteClass?>(null) }
    var confirmedBookingInfo by remember { mutableStateOf<ConfirmedClassBooking?>(null) }
    var selectedClassForDetail by remember { mutableStateOf<InstituteClass?>(null) }
    var selectedFacultyForModal by remember { mutableStateOf<FacultyMember?>(null) }

    val batchAlerts by BookMySpaceRepository.batchAlerts.collectAsState()
    val featureConfigs by BookMySpaceRepository.featureConfigs.collectAsState()

    val isCategoryFilterModuleEnabled = remember(featureConfigs) { BookMySpaceRepository.isFeatureEnabled(AppFeatureKey.CATEGORY_CHECKBOX_FILTER) }
    val isWaitlistAlertsModuleEnabled = remember(featureConfigs) { BookMySpaceRepository.isFeatureEnabled(AppFeatureKey.BATCH_WAITLIST_ALERTS) }
    val isTodayOngoingModuleEnabled = remember(featureConfigs) { BookMySpaceRepository.isFeatureEnabled(AppFeatureKey.TODAY_ONGOING_CLASSES) }
    val isOneTapBookingModuleEnabled = remember(featureConfigs) { BookMySpaceRepository.isFeatureEnabled(AppFeatureKey.ONE_TAP_INSTANT_BOOKING) }
    val isFacultyModalModuleEnabled = remember(featureConfigs) { BookMySpaceRepository.isFeatureEnabled(AppFeatureKey.FACULTY_CREDENTIALS_MODAL) }

    val categories = listOf("All", "Sports & Fitness", "Academics", "Tech & Coding", "Dance", "Music & Arts")

    // Filtered Classes with Location, Category Checkboxes and Criteria Matching
    val filteredClasses = remember(classes, searchQuery, selectedCategory, selectedCategories, selectedMode, showOnlyOngoingToday, showFullBatchesOnly, userLocationHierarchy) {
        val list = BookMySpaceRepository.searchClasses(
            query = searchQuery,
            category = if (selectedCategories.isEmpty()) selectedCategory else null,
            categories = if (selectedCategories.isNotEmpty()) selectedCategories else null,
            deliveryMode = selectedMode
        )
        val ongoingFiltered = if (showOnlyOngoingToday) list.filter { it.isTodayOngoing } else list
        val batchFullFiltered = if (showFullBatchesOnly) ongoingFiltered.filter { it.availableSeats <= 0 || it.isUpcomingBatch || !it.enrollmentOpen } else ongoingFiltered

        batchFullFiltered.sortedWith(
            compareBy<InstituteClass> { c ->
                val matchesLocation = c.location.contains(userLocationHierarchy.cityTownName, ignoreCase = true) ||
                        c.location.contains(userLocationHierarchy.districtName, ignoreCase = true) ||
                        c.location.contains(userLocationHierarchy.stateName, ignoreCase = true)
                if (matchesLocation) 0 else 1
            }.thenByDescending { it.isTodayOngoing }
        )
    }

    // Classes ongoing today for the horizontal live ticker / scroller
    val todayOngoingClasses = remember(classes) {
        classes.filter { it.isTodayOngoing || it.todayLiveStatus.contains("LIVE", ignoreCase = true) || it.todayLiveStatus.contains("TODAY", ignoreCase = true) }
    }

    Scaffold(
        snackbarHost = { SnackbarHost(snackbarHostState) },
        topBar = {
            TopAppBar(
                title = {
                    Column {
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            Text("Institutes & Classes", fontWeight = FontWeight.Bold, fontSize = 18.sp)
                            Spacer(modifier = Modifier.width(6.dp))
                            Surface(
                                color = MaterialTheme.colorScheme.primaryContainer,
                                shape = RoundedCornerShape(6.dp)
                            ) {
                                Text(
                                    text = "LIVE BATCHES",
                                    fontSize = 9.sp,
                                    fontWeight = FontWeight.ExtraBold,
                                    color = MaterialTheme.colorScheme.primary,
                                    modifier = Modifier.padding(horizontal = 5.dp, vertical = 2.dp)
                                )
                            }
                        }
                        Text("Search faculty, timings, modes & instant booking", fontSize = 11.5.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                    }
                },
                navigationIcon = {
                    IconButton(
                        onClick = onNavigateBack,
                        modifier = Modifier.testTag("institutes_back_btn")
                    ) {
                        Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "Back")
                    }
                },
                actions = {
                    FilledTonalButton(
                        onClick = onNavigateToOwnerDashboard,
                        modifier = Modifier
                            .padding(end = 8.dp)
                            .testTag("institute_owner_portal_top_btn"),
                        contentPadding = PaddingValues(horizontal = 10.dp, vertical = 4.dp)
                    ) {
                        Icon(Icons.Default.Storefront, contentDescription = null, modifier = Modifier.size(15.dp))
                        Spacer(modifier = Modifier.width(4.dp))
                        Text("Host Academy", fontSize = 11.5.sp, fontWeight = FontWeight.SemiBold)
                    }
                }
            )
        }
    ) { innerPadding ->
        LazyColumn(
            modifier = Modifier
                .fillMaxSize()
                .padding(innerPadding)
                .testTag("institutes_and_classes_main_list"),
            contentPadding = PaddingValues(bottom = 80.dp)
        ) {
            // 1. Location Bar
            item {
                LocationHierarchyHeaderBar(
                    currentLocation = userLocationHierarchy,
                    selectedRadius = userLocationRadius,
                    onClick = { showLocationDialog = true },
                    modifier = Modifier.padding(horizontal = 16.dp, vertical = 4.dp)
                )
            }

            // 2. Search Box + Right-Side Category Checkbox Filter Button
            item {
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(horizontal = 16.dp, vertical = 6.dp),
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(8.dp)
                ) {
                    OutlinedTextField(
                        value = searchQuery,
                        onValueChange = { searchQuery = it },
                        modifier = Modifier
                            .weight(1f)
                            .testTag("institute_classes_search_input"),
                        placeholder = { Text("Search subject, faculty, academy...", maxLines = 1, overflow = TextOverflow.Ellipsis, fontSize = 13.sp) },
                        leadingIcon = { Icon(Icons.Default.Search, contentDescription = null, tint = MaterialTheme.colorScheme.primary) },
                        trailingIcon = {
                            if (searchQuery.isNotEmpty()) {
                                IconButton(onClick = { searchQuery = "" }) {
                                    Icon(Icons.Default.Close, contentDescription = "Clear search")
                                }
                            }
                        },
                        singleLine = true,
                        shape = RoundedCornerShape(14.dp)
                    )

                    // 🎯 RIGHT-SIDE CATEGORY CHECKBOX FILTER BUTTON (Simple & Easy Checkbox Selector)
                    if (isCategoryFilterModuleEnabled) {
                        Surface(
                            onClick = { showRightCategoryFilterDrawer = true },
                            shape = RoundedCornerShape(14.dp),
                            color = if (selectedCategories.isNotEmpty() || showFullBatchesOnly) MaterialTheme.colorScheme.primaryContainer else MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.7f),
                            border = BorderStroke(
                                width = 1.dp,
                                color = if (selectedCategories.isNotEmpty() || showFullBatchesOnly) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.outlineVariant
                            ),
                            modifier = Modifier
                                .height(56.dp)
                                .testTag("right_side_category_filter_btn")
                        ) {
                            Row(
                                modifier = Modifier.padding(horizontal = 12.dp),
                                verticalAlignment = Alignment.CenterVertically,
                                horizontalArrangement = Arrangement.spacedBy(6.dp)
                            ) {
                                BadgedBox(
                                    badge = {
                                        if (selectedCategories.isNotEmpty()) {
                                            Badge(containerColor = MaterialTheme.colorScheme.primary) {
                                                Text("${selectedCategories.size}")
                                            }
                                        }
                                    }
                                ) {
                                    Icon(
                                        imageVector = Icons.Default.Tune,
                                        contentDescription = "Category Filter Checkbox Drawer",
                                        tint = if (selectedCategories.isNotEmpty()) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.onSurfaceVariant,
                                        modifier = Modifier.size(20.dp)
                                    )
                                }
                                Text(
                                    text = if (selectedCategories.isNotEmpty()) "${selectedCategories.size} Selected" else "Filter",
                                    fontSize = 12.sp,
                                    fontWeight = FontWeight.Bold,
                                    color = if (selectedCategories.isNotEmpty()) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.onSurface
                                )
                            }
                        }
                    }
                }
            }

            // 3. Mode Selection Chips (Online, Offline, Hybrid)
            item {
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(horizontal = 16.dp, vertical = 4.dp)
                        .horizontalScroll(rememberScrollState()),
                    horizontalArrangement = Arrangement.spacedBy(8.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    FilterChip(
                        selected = selectedMode == null,
                        onClick = { selectedMode = null },
                        label = { Text("All Modes", fontSize = 11.5.sp, fontWeight = FontWeight.SemiBold) },
                        modifier = Modifier.testTag("mode_chip_all")
                    )

                    ClassDeliveryMode.entries.forEach { mode ->
                        val isSelected = selectedMode == mode
                        FilterChip(
                            selected = isSelected,
                            onClick = { selectedMode = if (isSelected) null else mode },
                            label = { Text(mode.shortBadge, fontSize = 11.5.sp, fontWeight = FontWeight.Bold) },
                            leadingIcon = {
                                Icon(
                                    when (mode) {
                                        ClassDeliveryMode.OFFLINE -> Icons.Default.LocationOn
                                        ClassDeliveryMode.ONLINE -> Icons.Default.Laptop
                                        ClassDeliveryMode.HYBRID -> Icons.Default.Devices
                                    },
                                    contentDescription = null,
                                    modifier = Modifier.size(14.dp),
                                    tint = if (isSelected) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.onSurfaceVariant
                                )
                            },
                            modifier = Modifier.testTag("mode_chip_${mode.name.lowercase()}")
                        )
                    }

                    FilterChip(
                        selected = showOnlyOngoingToday,
                        onClick = { showOnlyOngoingToday = !showOnlyOngoingToday },
                        label = { Text("⚡ Ongoing Today", fontSize = 11.5.sp, fontWeight = FontWeight.Bold) },
                        colors = FilterChipDefaults.filterChipColors(
                            selectedContainerColor = Color(0xFF2E7D32).copy(alpha = 0.15f),
                            selectedLabelColor = Color(0xFF1B5E20)
                        ),
                        modifier = Modifier.testTag("filter_ongoing_today")
                    )
                }
            }

            // 4. Category Filter Chips
            item {
                LazyRow(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(vertical = 4.dp),
                    contentPadding = PaddingValues(horizontal = 16.dp),
                    horizontalArrangement = Arrangement.spacedBy(8.dp)
                ) {
                    items(categories) { category ->
                        val isSelected = selectedCategory == category
                        FilterChip(
                            selected = isSelected,
                            onClick = { selectedCategory = category },
                            label = { Text(category, fontSize = 11.5.sp) },
                            leadingIcon = if (isSelected) {
                                { Icon(Icons.Default.Check, contentDescription = null, modifier = Modifier.size(13.dp)) }
                            } else null,
                            modifier = Modifier.testTag("category_chip_${category.lowercase().replace(" ", "_").replace("&", "and")}")
                        )
                    }
                }
            }

            // 5. 🔴 TODAY'S ONGOING CLASSES HORIZONTAL SCROLLER
            if (isTodayOngoingModuleEnabled && todayOngoingClasses.isNotEmpty() && !showOnlyOngoingToday) {
                item {
                    Spacer(modifier = Modifier.height(10.dp))
                    TodayOngoingClassesScroller(
                        ongoingClasses = todayOngoingClasses,
                        onClassClick = { selectedClassForDetail = it },
                        onQuickBook = { bookingClassTarget = it },
                        onFacultyClick = { facultyName ->
                            selectedFacultyForModal = BookMySpaceRepository.getFacultyMember(facultyName)
                        }
                    )
                }
            }

            // 6. Section Header for Class Feed
            item {
                Spacer(modifier = Modifier.height(14.dp))
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(horizontal = 16.dp, vertical = 4.dp),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Column {
                        Text(
                            text = if (showOnlyOngoingToday) "Today's Ongoing Classes" else "Available Classes & Coaching",
                            fontSize = 16.sp,
                            fontWeight = FontWeight.Bold
                        )
                        Text(
                            text = "${filteredClasses.size} certified institute batches found",
                            fontSize = 11.sp,
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                    }

                    if (selectedMode != null || selectedCategory != "All" || selectedCategories.isNotEmpty() || showOnlyOngoingToday || showFullBatchesOnly || searchQuery.isNotBlank()) {
                        TextButton(
                            onClick = {
                                searchQuery = ""
                                selectedCategory = "All"
                                selectedCategories = emptySet()
                                selectedMode = null
                                showOnlyOngoingToday = false
                                showFullBatchesOnly = false
                            },
                            contentPadding = PaddingValues(horizontal = 8.dp, vertical = 2.dp),
                            modifier = Modifier.height(28.dp).testTag("reset_filters_btn")
                        ) {
                            Text("Reset All", fontSize = 11.sp)
                        }
                    }
                }
                Spacer(modifier = Modifier.height(6.dp))
            }

            // 7. Pure Class Information Cards List
            if (filteredClasses.isEmpty()) {
                item {
                    Box(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(32.dp),
                        contentAlignment = Alignment.Center
                    ) {
                        Column(horizontalAlignment = Alignment.CenterHorizontally) {
                            Icon(
                                imageVector = Icons.Default.School,
                                contentDescription = null,
                                modifier = Modifier.size(48.dp),
                                tint = MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.5f)
                            )
                            Spacer(modifier = Modifier.height(10.dp))
                            Text("No classes found matching criteria", fontWeight = FontWeight.Bold, fontSize = 15.sp)
                            Text(
                                "Try switching modes or searching for different subjects.",
                                fontSize = 12.sp,
                                color = MaterialTheme.colorScheme.onSurfaceVariant
                            )
                        }
                    }
                }
            } else {
                items(filteredClasses, key = { it.id }) { classItem ->
                    Box(modifier = Modifier.padding(horizontal = 16.dp, vertical = 6.dp)) {
                        DedicatedClassItemCard(
                            classItem = classItem,
                            onCardClick = { selectedClassForDetail = classItem },
                            onBookNow = { bookingClassTarget = classItem },
                            onFacultyClick = { facultyName ->
                                selectedFacultyForModal = BookMySpaceRepository.getFacultyMember(facultyName)
                            },
                            onCall = { initiatePhoneCall(context, classItem.contactPhone) },
                            onWhatsApp = {
                                initiateWhatsApp(
                                    context = context,
                                    phone = classItem.contactWhatsapp,
                                    message = "Hi! I am interested in joining '${classItem.title}' by ${classItem.facultyName} (${classItem.facultyExperienceYears}+ yrs exp) at ${classItem.instituteName}. Please share admission details."
                                )
                            },
                            onDirections = { openMaps(context, classItem.location) }
                        )
                    }
                }
            }
        }
    }

    // -------------------------------------------------------------
    // Single Tab Booking BottomSheet / Modal
    // -------------------------------------------------------------
    bookingClassTarget?.let { targetClass ->
        SingleTabClassBookingSheet(
            classItem = targetClass,
            authUser = authUser,
            onDismiss = { bookingClassTarget = null },
            onConfirmBooking = { bookingInfo ->
                bookingClassTarget = null
                confirmedBookingInfo = bookingInfo
                coroutineScope.launch {
                    snackbarHostState.showSnackbar("Class booking confirmed! Seat reserved at ${targetClass.instituteName}")
                }
            }
        )
    }

    // -------------------------------------------------------------
    // Class Detail Modal Dialog
    // -------------------------------------------------------------
    selectedClassForDetail?.let { classItem ->
        ClassDetailModalSheet(
            classItem = classItem,
            onDismiss = { selectedClassForDetail = null },
            onBookNow = {
                selectedClassForDetail = null
                bookingClassTarget = classItem
            },
            onFacultyClick = { facultyName ->
                selectedClassForDetail = null
                selectedFacultyForModal = BookMySpaceRepository.getFacultyMember(facultyName)
            },
            onCall = { initiatePhoneCall(context, classItem.contactPhone) },
            onWhatsApp = {
                initiateWhatsApp(
                    context = context,
                    phone = classItem.contactWhatsapp,
                    message = "Hi ${classItem.instituteName}! Inquiring about ${classItem.title} with faculty ${classItem.facultyName}."
                )
            },
            onDirections = { openMaps(context, classItem.location) }
        )
    }

    // -------------------------------------------------------------
    // Faculty Profile Interactive Modal Sheet
    // -------------------------------------------------------------
    if (isFacultyModalModuleEnabled) {
        selectedFacultyForModal?.let { faculty ->
            FacultyProfileDetailModalSheet(
                faculty = faculty,
                onDismiss = { selectedFacultyForModal = null },
                onBookClass = { cls ->
                    selectedFacultyForModal = null
                    bookingClassTarget = cls
                },
                onClassDetail = { cls ->
                    selectedFacultyForModal = null
                    selectedClassForDetail = cls
                },
                onCall = { phone ->
                    initiatePhoneCall(context, phone.ifBlank { "+91 98765 11223" })
                },
                onWhatsApp = { phone, name ->
                    initiateWhatsApp(
                        context = context,
                        phone = phone.ifBlank { "+91 98765 11223" },
                        message = "Hi! I would like to inquire about coaching batches conducted by faculty $name."
                    )
                }
            )
        }
    }

    // -------------------------------------------------------------
    // Confirmed Booking Success Modal
    // -------------------------------------------------------------
    confirmedBookingInfo?.let { booking ->
        ClassBookingConfirmationDialog(
            booking = booking,
            onDismiss = { confirmedBookingInfo = null },
            onWhatsApp = {
                initiateWhatsApp(
                    context = context,
                    phone = booking.classItem.contactWhatsapp,
                    message = "Hi ${booking.classItem.instituteName}! I booked a seat for '${booking.classItem.title}' (Booking Ref: ${booking.bookingRef}, Student: ${booking.studentName})."
                )
            }
        )
    }

    // Location Picker Dialog
    if (showLocationDialog) {
        LocationHierarchySelectorDialog(
            currentLocation = userLocationHierarchy,
            currentRadius = userLocationRadius,
            onLocationSelected = { loc, rad ->
                BookMySpaceRepository.setUserLocationHierarchy(loc, rad)
                showLocationDialog = false
            },
            onDismiss = { showLocationDialog = false }
        )
    }

    // 🎯 RIGHT-SIDE CATEGORY CHECKBOX FILTER SHEET
    if (isCategoryFilterModuleEnabled && showRightCategoryFilterDrawer) {
        CategoryCheckboxFilterSheet(
            selectedCategories = selectedCategories,
            onCategoryToggle = { cat ->
                selectedCategories = if (selectedCategories.contains(cat)) {
                    selectedCategories - cat
                } else {
                    selectedCategories + cat
                }
            },
            onSelectAll = {
                selectedCategories = setOf("Sports & Fitness", "Academics", "Tech & Coding", "Dance", "Music & Arts", "Martial Arts & Self Defense", "Yoga & Wellness")
            },
            onClearAll = {
                selectedCategories = emptySet()
            },
            selectedMode = selectedMode,
            onModeToggle = { mode ->
                selectedMode = if (selectedMode == mode) null else mode
            },
            showFullBatchesOnly = showFullBatchesOnly,
            onToggleFullBatchesOnly = {
                showFullBatchesOnly = !showFullBatchesOnly
            },
            classes = classes,
            onDismiss = { showRightCategoryFilterDrawer = false }
        )
    }
}

/**
 * 🔴 TODAY'S ONGOING CLASSES HORIZONTAL SCROLLER
 * Highly attractive ticker displaying ongoing batches with live status, institute, faculty, timings, exp & 1-tap book.
 */
@Composable
fun TodayOngoingClassesScroller(
    ongoingClasses: List<InstituteClass>,
    onClassClick: (InstituteClass) -> Unit,
    onQuickBook: (InstituteClass) -> Unit,
    onFacultyClick: (String) -> Unit = {}
) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .testTag("today_ongoing_classes_section")
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 16.dp, vertical = 2.dp),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically
        ) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Surface(
                    color = Color(0xFFD32F2F),
                    shape = CircleShape,
                    modifier = Modifier.size(8.dp)
                ) {}
                Spacer(modifier = Modifier.width(6.dp))
                Text(
                    text = "Today's Ongoing & Live Batches",
                    fontWeight = FontWeight.Bold,
                    fontSize = 14.5.sp,
                    color = MaterialTheme.colorScheme.onSurface
                )
            }

            Surface(
                color = MaterialTheme.colorScheme.errorContainer.copy(alpha = 0.6f),
                shape = RoundedCornerShape(8.dp)
            ) {
                Text(
                    text = "${ongoingClasses.size} Active Today",
                    fontSize = 10.sp,
                    fontWeight = FontWeight.Bold,
                    color = MaterialTheme.colorScheme.error,
                    modifier = Modifier.padding(horizontal = 6.dp, vertical = 2.dp)
                )
            }
        }

        Spacer(modifier = Modifier.height(6.dp))

        LazyRow(
            modifier = Modifier.fillMaxWidth(),
            contentPadding = PaddingValues(horizontal = 16.dp),
            horizontalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            items(ongoingClasses, key = { "ongoing_${it.id}" }) { cls ->
                TodayOngoingClassCard(
                    classItem = cls,
                    onClick = { onClassClick(cls) },
                    onQuickBook = { onQuickBook(cls) },
                    onFacultyClick = { onFacultyClick(cls.facultyName) }
                )
            }
        }
    }
}

/**
 * Single Card for the Today's Ongoing Classes Horizontal Scroller.
 */
@Composable
fun TodayOngoingClassCard(
    classItem: InstituteClass,
    onClick: () -> Unit,
    onQuickBook: () -> Unit,
    onFacultyClick: () -> Unit = {}
) {
    Card(
        modifier = Modifier
            .width(290.dp)
            .clickable { onClick() }
            .testTag("ongoing_card_${classItem.id}"),
        shape = RoundedCornerShape(16.dp),
        colors = CardDefaults.cardColors(
            containerColor = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.45f)
        ),
        border = BorderStroke(1.dp, MaterialTheme.colorScheme.primary.copy(alpha = 0.25f))
    ) {
        Column(modifier = Modifier.padding(12.dp)) {
            // Live Status & Mode Badge Row
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Surface(
                    color = if (classItem.todayLiveStatus.contains("LIVE", ignoreCase = true)) Color(0xFF2E7D32) else MaterialTheme.colorScheme.primary,
                    shape = RoundedCornerShape(6.dp)
                ) {
                    Row(
                        modifier = Modifier.padding(horizontal = 6.dp, vertical = 2.dp),
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Text(
                            text = classItem.todayLiveStatus,
                            color = Color.White,
                            fontSize = 9.5.sp,
                            fontWeight = FontWeight.ExtraBold
                        )
                    }
                }

                Surface(
                    color = when (classItem.deliveryMode) {
                        ClassDeliveryMode.ONLINE -> MaterialTheme.colorScheme.tertiaryContainer
                        ClassDeliveryMode.OFFLINE -> MaterialTheme.colorScheme.secondaryContainer
                        ClassDeliveryMode.HYBRID -> MaterialTheme.colorScheme.primaryContainer
                    },
                    shape = RoundedCornerShape(6.dp)
                ) {
                    Text(
                        text = classItem.deliveryMode.shortBadge,
                        fontSize = 9.5.sp,
                        fontWeight = FontWeight.Bold,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                        modifier = Modifier.padding(horizontal = 6.dp, vertical = 2.dp)
                    )
                }
            }

            Spacer(modifier = Modifier.height(6.dp))

            // Class Title
            Text(
                text = classItem.title,
                fontWeight = FontWeight.Bold,
                fontSize = 13.5.sp,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis
            )

            // Institute Name
            Text(
                text = "🏛️ ${classItem.instituteName}",
                fontSize = 11.5.sp,
                fontWeight = FontWeight.SemiBold,
                color = MaterialTheme.colorScheme.primary,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis
            )

            Spacer(modifier = Modifier.height(4.dp))

            // Faculty Details with Photo & Exp (Clickable to open Faculty Profile Modal)
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(6.dp))
                    .clickable { onFacultyClick() }
                    .padding(vertical = 2.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                if (classItem.facultyPhotoUrl.isNotBlank()) {
                    AsyncImage(
                        model = classItem.facultyPhotoUrl,
                        contentDescription = classItem.facultyName,
                        modifier = Modifier
                            .size(28.dp)
                            .clip(CircleShape)
                            .border(1.dp, MaterialTheme.colorScheme.primary, CircleShape),
                        contentScale = ContentScale.Crop
                    )
                    Spacer(modifier = Modifier.width(6.dp))
                }
                Text(
                    text = classItem.facultyName,
                    fontSize = 11.sp,
                    color = MaterialTheme.colorScheme.primary,
                    fontWeight = FontWeight.Bold,
                    modifier = Modifier.weight(1f),
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis
                )
                Spacer(modifier = Modifier.width(4.dp))
                Surface(
                    color = MaterialTheme.colorScheme.primary.copy(alpha = 0.12f),
                    shape = RoundedCornerShape(4.dp)
                ) {
                    Text(
                        text = "⭐ ${classItem.facultyExperienceYears}+ Yrs",
                        fontSize = 9.5.sp,
                        fontWeight = FontWeight.Bold,
                        color = MaterialTheme.colorScheme.primary,
                        modifier = Modifier.padding(horizontal = 4.dp, vertical = 1.dp)
                    )
                }
            }

            Spacer(modifier = Modifier.height(4.dp))

            // Class Timings & Duration
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Icon(Icons.Default.Schedule, contentDescription = null, modifier = Modifier.size(12.dp), tint = MaterialTheme.colorScheme.primary)
                    Spacer(modifier = Modifier.width(3.dp))
                    Text(
                        text = "${classItem.startTime} - ${classItem.endTime}",
                        fontSize = 10.5.sp,
                        fontWeight = FontWeight.Bold
                    )
                }

                Row(verticalAlignment = Alignment.CenterVertically) {
                    Icon(Icons.Default.HourglassEmpty, contentDescription = null, modifier = Modifier.size(11.dp), tint = MaterialTheme.colorScheme.onSurfaceVariant)
                    Spacer(modifier = Modifier.width(2.dp))
                    Text(
                        text = classItem.durationText,
                        fontSize = 10.5.sp,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                }
            }

            Spacer(modifier = Modifier.height(8.dp))
            HorizontalDivider(color = MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.4f))
            Spacer(modifier = Modifier.height(6.dp))

            // Fee & 1-Tap Book / Notify Me Button
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Text(
                    text = "₹${classItem.feeAmount.toInt()} / ${classItem.feeBillingCycle}",
                    fontWeight = FontWeight.ExtraBold,
                    fontSize = 12.5.sp,
                    color = MaterialTheme.colorScheme.primary
                )

                val isFullOrUpcoming = classItem.availableSeats <= 0 || !classItem.enrollmentOpen || classItem.isUpcomingBatch || classItem.batchType.contains("FULL", ignoreCase = true)
                val isSubscribed = BookMySpaceRepository.isBatchAlertActive(classItem.id)
                val context = LocalContext.current
                val coroutineScope = rememberCoroutineScope()

                if (isFullOrUpcoming) {
                    if (isSubscribed) {
                        FilledTonalButton(
                            onClick = {
                                coroutineScope.launch {
                                    BookMySpaceRepository.triggerSpotAvailablePush(context, classItem.id, 2)
                                    Toast.makeText(context, "🔔 Push Alert sent: Spot opened for ${classItem.title}!", Toast.LENGTH_SHORT).show()
                                }
                            },
                            contentPadding = PaddingValues(horizontal = 8.dp, vertical = 2.dp),
                            modifier = Modifier
                                .height(28.dp)
                                .testTag("notify_active_ongoing_${classItem.id}"),
                            colors = ButtonDefaults.filledTonalButtonColors(
                                containerColor = Color(0xFF2E7D32).copy(alpha = 0.15f),
                                contentColor = Color(0xFF1B5E20)
                            )
                        ) {
                            Icon(Icons.Default.NotificationsActive, contentDescription = null, modifier = Modifier.size(11.dp))
                            Spacer(modifier = Modifier.width(3.dp))
                            Text("Alert Set", fontSize = 10.sp, fontWeight = FontWeight.Bold)
                        }
                    } else {
                        Button(
                            onClick = {
                                coroutineScope.launch {
                                    BookMySpaceRepository.subscribeBatchAlert(context, classItem)
                                    Toast.makeText(context, "🔔 Subscribed! You will receive push notifications when spots open.", Toast.LENGTH_SHORT).show()
                                }
                            },
                            contentPadding = PaddingValues(horizontal = 8.dp, vertical = 2.dp),
                            modifier = Modifier
                                .height(28.dp)
                                .testTag("notify_me_ongoing_${classItem.id}"),
                            colors = ButtonDefaults.buttonColors(
                                containerColor = MaterialTheme.colorScheme.tertiary,
                                contentColor = MaterialTheme.colorScheme.onTertiary
                            )
                        ) {
                            Icon(Icons.Default.NotificationsNone, contentDescription = null, modifier = Modifier.size(11.dp))
                            Spacer(modifier = Modifier.width(3.dp))
                            Text("Notify Me", fontSize = 10.sp, fontWeight = FontWeight.Bold)
                        }
                    }
                } else {
                    Button(
                        onClick = onQuickBook,
                        contentPadding = PaddingValues(horizontal = 10.dp, vertical = 2.dp),
                        modifier = Modifier
                            .height(28.dp)
                            .testTag("quick_book_ongoing_${classItem.id}")
                    ) {
                        Icon(Icons.Default.FlashOn, contentDescription = null, modifier = Modifier.size(12.dp))
                        Spacer(modifier = Modifier.width(3.dp))
                        Text("1-Tap Book", fontSize = 10.5.sp, fontWeight = FontWeight.Bold)
                    }
                }
            }
        }
    }
}

/**
 * PURE DEDICATED CLASS ITEM CARD
 * Displaying:
 * 1. Institute Name
 * 2. Faculty Details (Name, Designation, Qualification)
 * 3. Exp (Years of experience)
 * 4. Duration (e.g. 3 Months, 45 Days)
 * 5. Class Timings (e.g. 06:00 AM - 07:30 AM)
 * 6. Location (Physical address / Campus)
 * 7. Mode (Online, Offline, Hybrid)
 * 8. Friendly 1-Tap Single Tab Booking Action
 */
@Composable
fun DedicatedClassItemCard(
    classItem: InstituteClass,
    onCardClick: () -> Unit,
    onBookNow: () -> Unit,
    onCall: () -> Unit,
    onWhatsApp: () -> Unit,
    onDirections: () -> Unit,
    onFacultyClick: (String) -> Unit = {}
) {
    Card(
        modifier = Modifier
            .fillMaxWidth()
            .clickable { onCardClick() }
            .testTag("class_card_${classItem.id}"),
        shape = RoundedCornerShape(18.dp),
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface),
        elevation = CardDefaults.cardElevation(defaultElevation = 3.dp),
        border = BorderStroke(1.dp, MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.4f))
    ) {
        Column {
            // Optional Cover Image Header with Badges
            if (classItem.coverImageUrl.isNotBlank() || classItem.imageUrls.isNotEmpty()) {
                val img = classItem.coverImageUrl.ifBlank { classItem.imageUrls.firstOrNull() ?: "" }
                Box(
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(138.dp)
                ) {
                    AsyncImage(
                        model = img,
                        contentDescription = classItem.title,
                        modifier = Modifier.fillMaxSize(),
                        contentScale = ContentScale.Crop
                    )
                    // Gradient overlay
                    Box(
                        modifier = Modifier
                            .fillMaxSize()
                            .background(
                                Brush.verticalGradient(
                                    colors = listOf(
                                        Color.Black.copy(alpha = 0.4f),
                                        Color.Transparent,
                                        Color.Black.copy(alpha = 0.6f)
                                    )
                                )
                            )
                    )

                    // Top row badges: Category, New/Upcoming batch, Delivery Mode
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(8.dp),
                        horizontalArrangement = Arrangement.SpaceBetween,
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                            Surface(
                                color = MaterialTheme.colorScheme.surface.copy(alpha = 0.92f),
                                shape = RoundedCornerShape(8.dp)
                            ) {
                                Text(
                                    text = classItem.category,
                                    fontSize = 10.sp,
                                    fontWeight = FontWeight.Bold,
                                    color = MaterialTheme.colorScheme.primary,
                                    modifier = Modifier.padding(horizontal = 8.dp, vertical = 3.dp)
                                )
                            }
                            if (classItem.isNewBatch) {
                                Surface(
                                    color = MaterialTheme.colorScheme.error,
                                    shape = RoundedCornerShape(8.dp)
                                ) {
                                    Text(
                                        text = "🔥 NEW BATCH",
                                        color = Color.White,
                                        fontSize = 10.sp,
                                        fontWeight = FontWeight.ExtraBold,
                                        modifier = Modifier.padding(horizontal = 7.dp, vertical = 3.dp)
                                    )
                                }
                            } else if (classItem.isUpcomingBatch) {
                                Surface(
                                    color = MaterialTheme.colorScheme.tertiary,
                                    shape = RoundedCornerShape(8.dp)
                                ) {
                                    Text(
                                        text = "🚀 UPCOMING BATCH",
                                        color = MaterialTheme.colorScheme.onTertiary,
                                        fontSize = 10.sp,
                                        fontWeight = FontWeight.ExtraBold,
                                        modifier = Modifier.padding(horizontal = 7.dp, vertical = 3.dp)
                                    )
                                }
                            }
                        }

                        // Delivery Mode Badge
                        DeliveryModeBadge(mode = classItem.deliveryMode)
                    }

                    // Live Status or Batch Start Date Pill
                    if (classItem.isTodayOngoing) {
                        Surface(
                            color = Color(0xFF2E7D32),
                            shape = RoundedCornerShape(topStart = 10.dp),
                            modifier = Modifier.align(Alignment.BottomEnd)
                        ) {
                            Text(
                                text = "⚡ ${classItem.todayLiveStatus}",
                                color = Color.White,
                                fontSize = 10.sp,
                                fontWeight = FontWeight.ExtraBold,
                                modifier = Modifier.padding(horizontal = 9.dp, vertical = 4.dp)
                            )
                        }
                    } else if (classItem.batchStartDate.isNotBlank()) {
                        Surface(
                            color = Color.Black.copy(alpha = 0.75f),
                            shape = RoundedCornerShape(topStart = 10.dp),
                            modifier = Modifier.align(Alignment.BottomEnd)
                        ) {
                            Text(
                                text = "📅 ${classItem.batchStartDate}",
                                color = Color.White,
                                fontSize = 10.sp,
                                fontWeight = FontWeight.SemiBold,
                                modifier = Modifier.padding(horizontal = 9.dp, vertical = 4.dp)
                            )
                        }
                    }
                }
            }

            Column(modifier = Modifier.padding(14.dp)) {
                // If no cover image, display category, tags and mode
                if (classItem.coverImageUrl.isBlank() && classItem.imageUrls.isEmpty()) {
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.SpaceBetween,
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                            Surface(
                                color = MaterialTheme.colorScheme.primaryContainer,
                                shape = RoundedCornerShape(6.dp)
                            ) {
                                Text(
                                    text = classItem.category,
                                    fontSize = 10.5.sp,
                                    fontWeight = FontWeight.SemiBold,
                                    color = MaterialTheme.colorScheme.onPrimaryContainer,
                                    modifier = Modifier.padding(horizontal = 8.dp, vertical = 3.dp)
                                )
                            }
                            if (classItem.isNewBatch) {
                                Surface(
                                    color = MaterialTheme.colorScheme.error,
                                    shape = RoundedCornerShape(6.dp)
                                ) {
                                    Text(
                                        text = "🔥 NEW BATCH",
                                        color = Color.White,
                                        fontSize = 10.sp,
                                        fontWeight = FontWeight.ExtraBold,
                                        modifier = Modifier.padding(horizontal = 6.dp, vertical = 3.dp)
                                    )
                                }
                            }
                        }

                        DeliveryModeBadge(mode = classItem.deliveryMode)
                    }
                    Spacer(modifier = Modifier.height(6.dp))
                }

                // 1. CLASS TITLE
                Text(
                    text = classItem.title,
                    fontWeight = FontWeight.Bold,
                    fontSize = 16.sp,
                    lineHeight = 21.sp,
                    maxLines = 2,
                    overflow = TextOverflow.Ellipsis
                )

                // 2. HIGHLIGHT THE INSTITUTE
                Spacer(modifier = Modifier.height(5.dp))
                Surface(
                    color = MaterialTheme.colorScheme.primaryContainer.copy(alpha = 0.35f),
                    shape = RoundedCornerShape(8.dp),
                    modifier = Modifier.fillMaxWidth()
                ) {
                    Row(
                        modifier = Modifier.padding(horizontal = 8.dp, vertical = 5.dp),
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Icon(
                            imageVector = Icons.Default.Apartment,
                            contentDescription = null,
                            tint = MaterialTheme.colorScheme.primary,
                            modifier = Modifier.size(16.dp)
                        )
                        Spacer(modifier = Modifier.width(6.dp))
                        Text(
                            text = classItem.instituteName,
                            fontSize = 12.5.sp,
                            fontWeight = FontWeight.Bold,
                            color = MaterialTheme.colorScheme.primary,
                            maxLines = 1,
                            overflow = TextOverflow.Ellipsis,
                            modifier = Modifier.weight(1f)
                        )
                        Icon(
                            imageVector = Icons.Default.Verified,
                            contentDescription = "Verified Institute",
                            tint = MaterialTheme.colorScheme.primary,
                            modifier = Modifier.size(14.dp)
                        )
                    }
                }

                // 3. HIGHLIGHT THE TIMINGS & DURATION (World Best Looking Timings Box)
                Spacer(modifier = Modifier.height(8.dp))
                Surface(
                    color = MaterialTheme.colorScheme.secondaryContainer.copy(alpha = 0.35f),
                    shape = RoundedCornerShape(10.dp),
                    border = BorderStroke(1.dp, MaterialTheme.colorScheme.secondary.copy(alpha = 0.3f)),
                    modifier = Modifier.fillMaxWidth()
                ) {
                    Row(
                        modifier = Modifier.padding(horizontal = 10.dp, vertical = 7.dp),
                        horizontalArrangement = Arrangement.SpaceBetween,
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            Icon(
                                imageVector = Icons.Default.Schedule,
                                contentDescription = "Class Timings",
                                tint = MaterialTheme.colorScheme.secondary,
                                modifier = Modifier.size(16.dp)
                            )
                            Spacer(modifier = Modifier.width(6.dp))
                            Column {
                                Text(
                                    text = "TIMING",
                                    fontSize = 9.sp,
                                    fontWeight = FontWeight.Black,
                                    color = MaterialTheme.colorScheme.secondary
                                )
                                Text(
                                    text = "${classItem.startTime} - ${classItem.endTime}",
                                    fontSize = 12.5.sp,
                                    fontWeight = FontWeight.ExtraBold,
                                    color = MaterialTheme.colorScheme.onSurface
                                )
                            }
                        }

                        // Duration Badge
                        Surface(
                            color = MaterialTheme.colorScheme.surface,
                            shape = RoundedCornerShape(6.dp),
                            border = BorderStroke(0.5.dp, MaterialTheme.colorScheme.outlineVariant)
                        ) {
                            Row(
                                modifier = Modifier.padding(horizontal = 8.dp, vertical = 4.dp),
                                verticalAlignment = Alignment.CenterVertically
                            ) {
                                Icon(
                                    Icons.Default.HourglassBottom,
                                    contentDescription = null,
                                    tint = MaterialTheme.colorScheme.primary,
                                    modifier = Modifier.size(12.dp)
                                )
                                Spacer(modifier = Modifier.width(3.dp))
                                Text(
                                    text = classItem.durationText,
                                    fontSize = 11.sp,
                                    fontWeight = FontWeight.Bold,
                                    color = MaterialTheme.colorScheme.onSurface
                                )
                            }
                        }
                    }
                }

                // 4. HIGHLIGHT FACULTY WITH PHOTO, EXPERIENCE & CREDENTIALS (Interactive Profile Trigger)
                Spacer(modifier = Modifier.height(8.dp))
                Surface(
                    color = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.5f),
                    shape = RoundedCornerShape(12.dp),
                    border = BorderStroke(1.dp, MaterialTheme.colorScheme.primary.copy(alpha = 0.15f)),
                    modifier = Modifier
                        .fillMaxWidth()
                        .clip(RoundedCornerShape(12.dp))
                        .clickable { onFacultyClick(classItem.facultyName) }
                ) {
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(10.dp),
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        // Faculty Photo
                        if (classItem.facultyPhotoUrl.isNotBlank()) {
                            AsyncImage(
                                model = classItem.facultyPhotoUrl,
                                contentDescription = classItem.facultyName,
                                modifier = Modifier
                                    .size(46.dp)
                                    .clip(CircleShape)
                                    .border(1.5.dp, MaterialTheme.colorScheme.primary, CircleShape),
                                contentScale = ContentScale.Crop
                            )
                        } else {
                            Box(
                                modifier = Modifier
                                    .size(46.dp)
                                    .clip(CircleShape)
                                    .background(MaterialTheme.colorScheme.primaryContainer),
                                contentAlignment = Alignment.Center
                            ) {
                                Icon(
                                    imageVector = Icons.Default.Person,
                                    contentDescription = null,
                                    tint = MaterialTheme.colorScheme.primary,
                                    modifier = Modifier.size(24.dp)
                                )
                            }
                        }

                        Spacer(modifier = Modifier.width(10.dp))

                        Column(modifier = Modifier.weight(1f)) {
                            Row(
                                modifier = Modifier.fillMaxWidth(),
                                horizontalArrangement = Arrangement.SpaceBetween,
                                verticalAlignment = Alignment.CenterVertically
                            ) {
                                Text(
                                    text = classItem.facultyName,
                                    fontWeight = FontWeight.Bold,
                                    fontSize = 13.sp,
                                    maxLines = 1,
                                    overflow = TextOverflow.Ellipsis
                                )
                                // Experience Badge
                                Surface(
                                    color = MaterialTheme.colorScheme.primaryContainer,
                                    shape = RoundedCornerShape(6.dp)
                                ) {
                                    Text(
                                        text = "⭐ ${classItem.facultyExperienceYears}+ Yrs Exp",
                                        fontSize = 10.sp,
                                        fontWeight = FontWeight.ExtraBold,
                                        color = MaterialTheme.colorScheme.primary,
                                        modifier = Modifier.padding(horizontal = 6.dp, vertical = 2.dp)
                                    )
                                }
                            }
                            if (classItem.facultyDesignation.isNotBlank() || classItem.facultyQualification.isNotBlank()) {
                                Text(
                                    text = "${classItem.facultyDesignation} • ${classItem.facultyQualification}",
                                    fontSize = 10.5.sp,
                                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                                    maxLines = 1,
                                    overflow = TextOverflow.Ellipsis
                                )
                            }
                            // Visual cue to tap for full faculty portfolio
                            Spacer(modifier = Modifier.height(2.dp))
                            Text(
                                text = "View Biography, Certifications & All Batches →",
                                fontSize = 10.sp,
                                fontWeight = FontWeight.Bold,
                                color = MaterialTheme.colorScheme.primary
                            )
                        }
                    }
                }

                // 5. LOCATION
                if (classItem.location.isNotBlank()) {
                    Spacer(modifier = Modifier.height(6.dp))
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .clickable { onDirections() },
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Icon(
                            imageVector = Icons.Default.LocationOn,
                            contentDescription = null,
                            tint = MaterialTheme.colorScheme.onSurfaceVariant,
                            modifier = Modifier.size(13.dp)
                        )
                        Spacer(modifier = Modifier.width(4.dp))
                        Text(
                            text = classItem.location,
                            fontSize = 11.sp,
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                            maxLines = 1,
                            overflow = TextOverflow.Ellipsis,
                            modifier = Modifier.weight(1f)
                        )
                        Icon(
                            imageVector = Icons.Default.Directions,
                            contentDescription = "Map Directions",
                            tint = MaterialTheme.colorScheme.primary,
                            modifier = Modifier.size(14.dp)
                        )
                    }
                }

                // 6. HIGHLIGHT COST & ACTIONS (Single Tab 1-Tap Booking UI)
                Spacer(modifier = Modifier.height(10.dp))
                HorizontalDivider(color = MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.4f))
                Spacer(modifier = Modifier.height(8.dp))

                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Column {
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            Text(
                                text = "₹${classItem.feeAmount.toInt()}",
                                fontSize = 17.sp,
                                fontWeight = FontWeight.Black,
                                color = MaterialTheme.colorScheme.primary
                            )
                            Text(
                                text = "/${classItem.feeBillingCycle}",
                                fontSize = 11.sp,
                                color = MaterialTheme.colorScheme.onSurfaceVariant
                            )
                            if (classItem.discountPercent > 0) {
                                Spacer(modifier = Modifier.width(6.dp))
                                Surface(
                                    color = MaterialTheme.colorScheme.errorContainer,
                                    shape = RoundedCornerShape(4.dp)
                                ) {
                                    Text(
                                        text = "${classItem.discountPercent}% OFF",
                                        fontSize = 9.sp,
                                        fontWeight = FontWeight.ExtraBold,
                                        color = MaterialTheme.colorScheme.error,
                                        modifier = Modifier.padding(horizontal = 4.dp, vertical = 1.dp)
                                    )
                                }
                            }
                        }
                        if (classItem.courseFee > 0 && classItem.feeBillingCycle == "month") {
                            Text(
                                text = "Full Course: ₹${classItem.courseFee.toInt()}",
                                fontSize = 10.sp,
                                color = MaterialTheme.colorScheme.onSurfaceVariant
                            )
                        }
                    }

                    // Contact Shortcuts + Single Tab 1-Tap Book Button / Notify Me Button
                    Row(
                        horizontalArrangement = Arrangement.spacedBy(6.dp),
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        // Phone Call shortcut
                        if (classItem.contactPhone.isNotBlank()) {
                            FilledTonalIconButton(
                                onClick = onCall,
                                modifier = Modifier
                                    .size(36.dp)
                                    .testTag("class_call_btn_${classItem.id}")
                            ) {
                                Icon(Icons.Default.Phone, contentDescription = "Call Institute", modifier = Modifier.size(15.dp))
                            }
                        }

                        // WhatsApp shortcut
                        if (classItem.contactWhatsapp.isNotBlank()) {
                            FilledTonalIconButton(
                                onClick = onWhatsApp,
                                modifier = Modifier
                                    .size(36.dp)
                                    .testTag("class_whatsapp_btn_${classItem.id}"),
                                colors = IconButtonDefaults.filledTonalIconButtonColors(
                                    containerColor = Color(0xFF25D366).copy(alpha = 0.15f),
                                    contentColor = Color(0xFF1B5E20)
                                )
                            ) {
                                Icon(Icons.Default.Chat, contentDescription = "WhatsApp", modifier = Modifier.size(15.dp))
                            }
                        }

                        val isFullOrUpcoming = classItem.availableSeats <= 0 || !classItem.enrollmentOpen || classItem.isUpcomingBatch || classItem.batchType.contains("FULL", ignoreCase = true)
                        val isAlertActive = BookMySpaceRepository.isBatchAlertActive(classItem.id)
                        val context = LocalContext.current
                        val coroutineScope = rememberCoroutineScope()

                        if (isFullOrUpcoming) {
                            if (isAlertActive) {
                                FilledTonalButton(
                                    onClick = {
                                        coroutineScope.launch {
                                            com.bookmyspace.bookmyspace.data.healing.SelfHealingManager.safeExecute(
                                                featureKey = com.bookmyspace.bookmyspace.data.model.AppFeatureKey.BATCH_WAITLIST_ALERTS,
                                                fallback = {
                                                    Toast.makeText(context, "🔔 Local alert scheduled for ${classItem.title}", Toast.LENGTH_SHORT).show()
                                                }
                                            ) {
                                                BookMySpaceRepository.triggerSpotAvailablePush(context, classItem.id, 2)
                                                Toast.makeText(context, "🔔 Push Alert sent: Spot opened for ${classItem.title}!", Toast.LENGTH_SHORT).show()
                                            }
                                        }
                                    },
                                    contentPadding = PaddingValues(horizontal = 10.dp, vertical = 6.dp),
                                    shape = RoundedCornerShape(10.dp),
                                    colors = ButtonDefaults.filledTonalButtonColors(
                                        containerColor = Color(0xFF2E7D32).copy(alpha = 0.15f),
                                        contentColor = Color(0xFF1B5E20)
                                    ),
                                    modifier = Modifier
                                        .height(38.dp)
                                        .testTag("notify_active_btn_${classItem.id}")
                                 ) {
                                    Icon(Icons.Default.NotificationsActive, contentDescription = null, modifier = Modifier.size(14.dp))
                                    Spacer(modifier = Modifier.width(4.dp))
                                    Text("Alert Active • Test Push", fontSize = 11.5.sp, fontWeight = FontWeight.Bold)
                                }
                            } else {
                                Button(
                                    onClick = {
                                        coroutineScope.launch {
                                            com.bookmyspace.bookmyspace.data.healing.SelfHealingManager.safeExecute(
                                                featureKey = com.bookmyspace.bookmyspace.data.model.AppFeatureKey.BATCH_WAITLIST_ALERTS,
                                                fallback = {
                                                    Toast.makeText(context, "🔔 Waitlist registered locally for ${classItem.title}", Toast.LENGTH_SHORT).show()
                                                }
                                            ) {
                                                BookMySpaceRepository.subscribeBatchAlert(context, classItem)
                                                Toast.makeText(context, "🔔 Alert set! You'll receive push notification when spots open for ${classItem.title}", Toast.LENGTH_SHORT).show()
                                            }
                                        }
                                    },
                                    colors = ButtonDefaults.buttonColors(
                                        containerColor = MaterialTheme.colorScheme.tertiary,
                                        contentColor = MaterialTheme.colorScheme.onTertiary
                                    ),
                                    contentPadding = PaddingValues(horizontal = 12.dp, vertical = 6.dp),
                                    shape = RoundedCornerShape(10.dp),
                                    modifier = Modifier
                                        .height(38.dp)
                                        .testTag("notify_me_btn_${classItem.id}")
                                ) {
                                    Icon(Icons.Default.NotificationsNone, contentDescription = null, modifier = Modifier.size(14.dp))
                                    Spacer(modifier = Modifier.width(4.dp))
                                    Text("Notify Me", fontSize = 12.sp, fontWeight = FontWeight.Bold)
                                }
                            }
                        } else {
                            // ⚡ 1-Tap Book Class Button (Single Tab Booking Flow)
                            Button(
                                onClick = onBookNow,
                                contentPadding = PaddingValues(horizontal = 14.dp, vertical = 6.dp),
                                shape = RoundedCornerShape(10.dp),
                                modifier = Modifier
                                    .height(38.dp)
                                    .testTag("book_class_btn_${classItem.id}")
                            ) {
                                Icon(Icons.Default.EventSeat, contentDescription = null, modifier = Modifier.size(14.dp))
                                Spacer(modifier = Modifier.width(4.dp))
                                Text("1-Tap Book", fontSize = 12.sp, fontWeight = FontWeight.Bold)
                            }
                        }
                    }
                }
            }
        }
    }
}

/**
 * Distinctive Delivery Mode Badge (Online, Offline, Hybrid).
 */
@Composable
fun DeliveryModeBadge(mode: ClassDeliveryMode) {
    Surface(
        color = when (mode) {
            ClassDeliveryMode.ONLINE -> MaterialTheme.colorScheme.tertiaryContainer
            ClassDeliveryMode.OFFLINE -> MaterialTheme.colorScheme.secondaryContainer
            ClassDeliveryMode.HYBRID -> MaterialTheme.colorScheme.primaryContainer
        },
        shape = RoundedCornerShape(6.dp)
    ) {
        Row(
            modifier = Modifier.padding(horizontal = 7.dp, vertical = 3.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Icon(
                when (mode) {
                    ClassDeliveryMode.OFFLINE -> Icons.Default.LocationOn
                    ClassDeliveryMode.ONLINE -> Icons.Default.Laptop
                    ClassDeliveryMode.HYBRID -> Icons.Default.Devices
                },
                contentDescription = null,
                modifier = Modifier.size(12.dp),
                tint = when (mode) {
                    ClassDeliveryMode.ONLINE -> MaterialTheme.colorScheme.onTertiaryContainer
                    ClassDeliveryMode.OFFLINE -> MaterialTheme.colorScheme.onSecondaryContainer
                    ClassDeliveryMode.HYBRID -> MaterialTheme.colorScheme.onPrimaryContainer
                }
            )
            Spacer(modifier = Modifier.width(3.dp))
            Text(
                text = mode.shortBadge,
                fontSize = 10.sp,
                fontWeight = FontWeight.Bold,
                color = when (mode) {
                    ClassDeliveryMode.ONLINE -> MaterialTheme.colorScheme.onTertiaryContainer
                    ClassDeliveryMode.OFFLINE -> MaterialTheme.colorScheme.onSecondaryContainer
                    ClassDeliveryMode.HYBRID -> MaterialTheme.colorScheme.onPrimaryContainer
                }
            )
        }
    }
}

/**
 * ⚡ SINGLE TAB / 1-TAP CLASS BOOKING BOTTOMSHEET
 * Frictionless single-screen booking modal for reserving a seat in a class or coaching batch.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun SingleTabClassBookingSheet(
    classItem: InstituteClass,
    authUser: AuthUser?,
    onDismiss: () -> Unit,
    onConfirmBooking: (ConfirmedClassBooking) -> Unit
) {
    var studentName by remember { mutableStateOf(authUser?.fullName ?: "Narendra Reddy") }
    var studentPhone by remember { mutableStateOf(authUser?.phone?.ifBlank { "+91 98765 43210" } ?: "+91 98765 43210") }
    var studentEmail by remember { mutableStateOf(authUser?.email ?: "narenqe2@gmail.com") }
    var selectedBatchSlot by remember { mutableStateOf(classItem.classTimings.ifBlank { "${classItem.startTime} - ${classItem.endTime}" }) }
    var selectedDeliveryPreference by remember { mutableStateOf(classItem.deliveryMode) }
    var agreedTerms by remember { mutableStateOf(true) }
    var errorMessage by remember { mutableStateOf<String?>(null) }
    var isBookingInProgress by remember { mutableStateOf(false) }

    ModalBottomSheet(
        onDismissRequest = onDismiss,
        sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true),
        containerColor = MaterialTheme.colorScheme.surface
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 20.dp, vertical = 8.dp)
                .verticalScroll(rememberScrollState())
                .testTag("single_tab_booking_sheet")
        ) {
            // Header Bar
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Column {
                    Text(
                        text = "1-Tap Class Reservation",
                        fontSize = 18.sp,
                        fontWeight = FontWeight.ExtraBold
                    )
                    Text(
                        text = "Instant seat reservation at ${classItem.instituteName}",
                        fontSize = 11.5.sp,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                }

                DeliveryModeBadge(mode = classItem.deliveryMode)
            }

            Spacer(modifier = Modifier.height(14.dp))

            // Class Summary Card
            Card(
                modifier = Modifier.fillMaxWidth(),
                shape = RoundedCornerShape(14.dp),
                colors = CardDefaults.cardColors(
                    containerColor = MaterialTheme.colorScheme.primaryContainer.copy(alpha = 0.35f)
                ),
                border = BorderStroke(1.dp, MaterialTheme.colorScheme.primary.copy(alpha = 0.2f))
            ) {
                Column(modifier = Modifier.padding(14.dp)) {
                    Text(
                        text = classItem.title,
                        fontWeight = FontWeight.Bold,
                        fontSize = 15.sp,
                        color = MaterialTheme.colorScheme.onPrimaryContainer
                    )
                    Text(
                        text = "🏛️ ${classItem.instituteName}",
                        fontSize = 12.5.sp,
                        fontWeight = FontWeight.SemiBold,
                        color = MaterialTheme.colorScheme.primary
                    )

                    Spacer(modifier = Modifier.height(8.dp))
                    HorizontalDivider(color = MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.4f))
                    Spacer(modifier = Modifier.height(8.dp))

                    // 4 Key parameters grid
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.SpaceBetween
                    ) {
                        Column {
                            Text("FACULTY & EXP", fontSize = 9.sp, fontWeight = FontWeight.Bold, color = MaterialTheme.colorScheme.onSurfaceVariant)
                            Text(
                                "${classItem.facultyName} (${classItem.facultyExperienceYears}+ Yrs)",
                                fontSize = 11.sp,
                                fontWeight = FontWeight.Bold
                            )
                        }

                        Column {
                            Text("DURATION", fontSize = 9.sp, fontWeight = FontWeight.Bold, color = MaterialTheme.colorScheme.onSurfaceVariant)
                            Text(
                                classItem.durationText,
                                fontSize = 11.sp,
                                fontWeight = FontWeight.Bold
                            )
                        }
                    }

                    Spacer(modifier = Modifier.height(6.dp))

                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.SpaceBetween
                    ) {
                        Column {
                            Text("TIMINGS", fontSize = 9.sp, fontWeight = FontWeight.Bold, color = MaterialTheme.colorScheme.onSurfaceVariant)
                            Text(
                                "${classItem.startTime} - ${classItem.endTime}",
                                fontSize = 11.sp,
                                fontWeight = FontWeight.Bold,
                                color = MaterialTheme.colorScheme.primary
                            )
                        }

                        Column {
                            Text("LOCATION", fontSize = 9.sp, fontWeight = FontWeight.Bold, color = MaterialTheme.colorScheme.onSurfaceVariant)
                            Text(
                                classItem.city.ifBlank { "Hyderabad" },
                                fontSize = 11.sp,
                                fontWeight = FontWeight.Bold
                            )
                        }
                    }
                }
            }

            Spacer(modifier = Modifier.height(14.dp))

            // Student Information Form
            Text("STUDENT DETAILS", fontSize = 10.sp, fontWeight = FontWeight.ExtraBold, color = MaterialTheme.colorScheme.primary)
            Spacer(modifier = Modifier.height(6.dp))

            OutlinedTextField(
                value = studentName,
                onValueChange = { studentName = it },
                label = { Text("Student Full Name") },
                leadingIcon = { Icon(Icons.Default.Person, contentDescription = null) },
                modifier = Modifier
                    .fillMaxWidth()
                    .testTag("booking_student_name_input"),
                singleLine = true,
                shape = RoundedCornerShape(12.dp)
            )

            Spacer(modifier = Modifier.height(8.dp))

            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                OutlinedTextField(
                    value = studentPhone,
                    onValueChange = { studentPhone = it },
                    label = { Text("Mobile Number") },
                    leadingIcon = { Icon(Icons.Default.Phone, contentDescription = null) },
                    modifier = Modifier
                        .weight(1f)
                        .testTag("booking_student_phone_input"),
                    singleLine = true,
                    shape = RoundedCornerShape(12.dp)
                )

                OutlinedTextField(
                    value = studentEmail,
                    onValueChange = { studentEmail = it },
                    label = { Text("Email Address") },
                    leadingIcon = { Icon(Icons.Default.Email, contentDescription = null) },
                    modifier = Modifier
                        .weight(1f)
                        .testTag("booking_student_email_input"),
                    singleLine = true,
                    shape = RoundedCornerShape(12.dp)
                )
            }

            // If Hybrid: choose In-Person or Online batch preference
            if (classItem.deliveryMode == ClassDeliveryMode.HYBRID) {
                Spacer(modifier = Modifier.height(12.dp))
                Text("HYBRID ATTENDANCE PREFERENCE", fontSize = 10.sp, fontWeight = FontWeight.ExtraBold, color = MaterialTheme.colorScheme.primary)
                Spacer(modifier = Modifier.height(4.dp))
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.spacedBy(8.dp)
                ) {
                    FilterChip(
                        selected = selectedDeliveryPreference == ClassDeliveryMode.OFFLINE,
                        onClick = { selectedDeliveryPreference = ClassDeliveryMode.OFFLINE },
                        label = { Text("In-Person Classroom", fontSize = 11.sp) },
                        leadingIcon = { Icon(Icons.Default.LocationOn, contentDescription = null, modifier = Modifier.size(13.dp)) },
                        modifier = Modifier.weight(1f)
                    )
                    FilterChip(
                        selected = selectedDeliveryPreference == ClassDeliveryMode.ONLINE,
                        onClick = { selectedDeliveryPreference = ClassDeliveryMode.ONLINE },
                        label = { Text("Online Live Stream", fontSize = 11.sp) },
                        leadingIcon = { Icon(Icons.Default.Laptop, contentDescription = null, modifier = Modifier.size(13.dp)) },
                        modifier = Modifier.weight(1f)
                    )
                }
            }

            // Fee Summary Bar
            Spacer(modifier = Modifier.height(14.dp))
            Surface(
                color = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.5f),
                shape = RoundedCornerShape(12.dp),
                modifier = Modifier.fillMaxWidth()
            ) {
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(14.dp),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Column {
                        Text("Total Amount to Pay", fontSize = 11.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                        Text(
                            "₹${classItem.feeAmount.toInt()} (${classItem.feeBillingCycle})",
                            fontSize = 17.sp,
                            fontWeight = FontWeight.ExtraBold,
                            color = MaterialTheme.colorScheme.primary
                        )
                    }

                    Surface(
                        color = Color(0xFF2E7D32).copy(alpha = 0.15f),
                        shape = RoundedCornerShape(8.dp)
                    ) {
                        Text(
                            text = "0% Convenience Fee",
                            fontSize = 10.sp,
                            fontWeight = FontWeight.Bold,
                            color = Color(0xFF1B5E20),
                            modifier = Modifier.padding(horizontal = 8.dp, vertical = 4.dp)
                        )
                    }
                }
            }

            if (errorMessage != null) {
                Spacer(modifier = Modifier.height(8.dp))
                Text(
                    text = errorMessage ?: "",
                    color = MaterialTheme.colorScheme.error,
                    fontSize = 12.sp,
                    fontWeight = FontWeight.Bold
                )
            }

            // Confirm 1-Tap Booking Button
            Spacer(modifier = Modifier.height(16.dp))
            Button(
                onClick = {
                    if (studentName.isBlank()) {
                        errorMessage = "Please enter student name."
                        return@Button
                    }
                    if (studentPhone.isBlank()) {
                        errorMessage = "Please enter mobile number."
                        return@Button
                    }

                    isBookingInProgress = true
                    val bookingRef = "CLS-${UUID.randomUUID().toString().take(6).uppercase()}"
                    val confirmed = ConfirmedClassBooking(
                        bookingRef = bookingRef,
                        classItem = classItem,
                        studentName = studentName.trim(),
                        studentPhone = studentPhone.trim(),
                        studentEmail = studentEmail.trim(),
                        amountPaid = classItem.feeAmount,
                        selectedMode = selectedDeliveryPreference,
                        bookingTimestamp = System.currentTimeMillis()
                    )

                    // Store booking inside repository
                    val repoBooking = Booking(
                        id = "bk_${UUID.randomUUID().toString().take(8)}",
                        venueId = classItem.instituteId,
                        venueName = "${classItem.instituteName} - ${classItem.title}",
                        venueImageUrl = classItem.coverImageUrl,
                        date = "Today",
                        bookingDate = "Today",
                        startTime = classItem.startTime,
                        endTime = classItem.endTime,
                        slotLabel = "${classItem.startTime} - ${classItem.endTime}",
                        totalAmount = classItem.feeAmount,
                        totalPrice = classItem.feeAmount,
                        userName = studentName,
                        userPhone = studentPhone,
                        userEmail = studentEmail,
                        bookingRef = bookingRef,
                        status = BookingStatus.CONFIRMED,
                        paymentStatus = "PAID"
                    )
                    BookMySpaceRepository.addBooking(repoBooking)

                    onConfirmBooking(confirmed)
                },
                modifier = Modifier
                    .fillMaxWidth()
                    .height(48.dp)
                    .testTag("confirm_single_tab_booking_btn"),
                shape = RoundedCornerShape(12.dp)
            ) {
                if (isBookingInProgress) {
                    CircularProgressIndicator(color = MaterialTheme.colorScheme.onPrimary, modifier = Modifier.size(20.dp))
                } else {
                    Icon(Icons.Default.CheckCircle, contentDescription = null, modifier = Modifier.size(18.dp))
                    Spacer(modifier = Modifier.width(6.dp))
                    Text("Confirm & Reserve Seat (₹${classItem.feeAmount.toInt()})", fontSize = 14.sp, fontWeight = FontWeight.Bold)
                }
            }

            Spacer(modifier = Modifier.height(20.dp))
        }
    }
}

/**
 * Class Detail Modal Bottom Sheet
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ClassDetailModalSheet(
    classItem: InstituteClass,
    onDismiss: () -> Unit,
    onBookNow: () -> Unit,
    onCall: () -> Unit,
    onWhatsApp: () -> Unit,
    onDirections: () -> Unit,
    onFacultyClick: (String) -> Unit = {}
) {
    val context = LocalContext.current
    ModalBottomSheet(
        onDismissRequest = onDismiss,
        sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 20.dp, vertical = 8.dp)
                .verticalScroll(rememberScrollState())
                .testTag("class_detail_sheet")
        ) {
            // Header Image if available
            if (classItem.coverImageUrl.isNotBlank()) {
                AsyncImage(
                    model = classItem.coverImageUrl,
                    contentDescription = classItem.title,
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(160.dp)
                        .clip(RoundedCornerShape(14.dp)),
                    contentScale = ContentScale.Crop
                )
                Spacer(modifier = Modifier.height(12.dp))
            }

            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                DeliveryModeBadge(mode = classItem.deliveryMode)
                Surface(
                    color = MaterialTheme.colorScheme.primaryContainer,
                    shape = RoundedCornerShape(6.dp)
                ) {
                    Text(
                        text = classItem.category,
                        fontSize = 11.sp,
                        fontWeight = FontWeight.Bold,
                        color = MaterialTheme.colorScheme.primary,
                        modifier = Modifier.padding(horizontal = 8.dp, vertical = 3.dp)
                    )
                }
            }

            Spacer(modifier = Modifier.height(8.dp))

            Text(
                text = classItem.title,
                fontWeight = FontWeight.ExtraBold,
                fontSize = 18.sp,
                lineHeight = 24.sp
            )

            Text(
                text = "🏛️ ${classItem.instituteName}",
                fontSize = 14.sp,
                fontWeight = FontWeight.SemiBold,
                color = MaterialTheme.colorScheme.primary
            )

            Spacer(modifier = Modifier.height(10.dp))
            Text(
                text = classItem.description,
                fontSize = 13.sp,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                lineHeight = 18.sp
            )

            Spacer(modifier = Modifier.height(14.dp))

            // Comprehensive Faculty & Class Attributes Matrix
            Surface(
                color = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.5f),
                shape = RoundedCornerShape(14.dp),
                modifier = Modifier.fillMaxWidth()
            ) {
                Column(modifier = Modifier.padding(14.dp)) {
                    Text("FACULTY & BATCH SPECIFICATIONS", fontSize = 10.sp, fontWeight = FontWeight.ExtraBold, color = MaterialTheme.colorScheme.primary)
                    Spacer(modifier = Modifier.height(10.dp))

                    DetailAttributeRow(
                        icon = Icons.Default.Person,
                        label = "Faculty Name",
                        value = "${classItem.facultyName} (${classItem.facultyDesignation})"
                    )
                    DetailAttributeRow(
                        icon = Icons.Default.Verified,
                        label = "Qualification & Exp",
                        value = "${classItem.facultyQualification} • ${classItem.facultyExperienceYears}+ Years Exp"
                    )
                    DetailAttributeRow(
                        icon = Icons.Default.Schedule,
                        label = "Class Timings",
                        value = "${classItem.startTime} - ${classItem.endTime} (${classItem.daysOfWeek.joinToString(", ")})"
                    )
                    DetailAttributeRow(
                        icon = Icons.Default.HourglassEmpty,
                        label = "Course Duration",
                        value = classItem.durationText
                    )
                    DetailAttributeRow(
                        icon = Icons.Default.LocationOn,
                        label = "Campus Location",
                        value = classItem.location.ifBlank { "Hyderabad Campus" }
                    )
                    DetailAttributeRow(
                        icon = Icons.Default.Group,
                        label = "Batch Seats Available",
                        value = "${classItem.availableSeats} seats left (Total: ${classItem.totalSeats})"
                    )
                }
            }

            // Interactive Faculty Profile Callout Card
            Spacer(modifier = Modifier.height(10.dp))
            Surface(
                color = MaterialTheme.colorScheme.primaryContainer.copy(alpha = 0.45f),
                shape = RoundedCornerShape(12.dp),
                border = BorderStroke(1.dp, MaterialTheme.colorScheme.primary.copy(alpha = 0.3f)),
                modifier = Modifier
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(12.dp))
                    .clickable { onFacultyClick(classItem.facultyName) }
            ) {
                Row(
                    modifier = Modifier.padding(12.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    if (classItem.facultyPhotoUrl.isNotBlank()) {
                        AsyncImage(
                            model = classItem.facultyPhotoUrl,
                            contentDescription = classItem.facultyName,
                            modifier = Modifier
                                .size(40.dp)
                                .clip(CircleShape)
                                .border(1.5.dp, MaterialTheme.colorScheme.primary, CircleShape),
                            contentScale = ContentScale.Crop
                        )
                    } else {
                        Icon(Icons.Default.School, contentDescription = null, tint = MaterialTheme.colorScheme.primary, modifier = Modifier.size(28.dp))
                    }
                    Spacer(modifier = Modifier.width(10.dp))
                    Column(modifier = Modifier.weight(1f)) {
                        Text("Instructor Portfolio & Bio", fontSize = 10.5.sp, fontWeight = FontWeight.Bold, color = MaterialTheme.colorScheme.primary)
                        Text("View ${classItem.facultyName}'s Certifications, Bio & All Batches →", fontSize = 12.sp, fontWeight = FontWeight.Bold)
                    }
                }
            }

            // CTAs
            Spacer(modifier = Modifier.height(16.dp))

            val isFullOrUpcoming = classItem.availableSeats <= 0 || !classItem.enrollmentOpen || classItem.isUpcomingBatch || classItem.batchType.contains("FULL", ignoreCase = true)
            val isAlertActive = BookMySpaceRepository.isBatchAlertActive(classItem.id)
            val coroutineScope = rememberCoroutineScope()

            // 🔔 PUSH NOTIFICATION ALERT / NOTIFY ME CARD
            if (isFullOrUpcoming || isAlertActive) {
                Surface(
                    color = if (isAlertActive) Color(0xFF2E7D32).copy(alpha = 0.12f) else MaterialTheme.colorScheme.tertiaryContainer.copy(alpha = 0.5f),
                    shape = RoundedCornerShape(12.dp),
                    border = BorderStroke(1.dp, if (isAlertActive) Color(0xFF2E7D32).copy(alpha = 0.4f) else MaterialTheme.colorScheme.tertiary.copy(alpha = 0.3f)),
                    modifier = Modifier.fillMaxWidth()
                ) {
                    Column(modifier = Modifier.padding(12.dp)) {
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            Icon(
                                imageVector = if (isAlertActive) Icons.Default.NotificationsActive else Icons.Default.NotificationsNone,
                                contentDescription = null,
                                tint = if (isAlertActive) Color(0xFF1B5E20) else MaterialTheme.colorScheme.tertiary,
                                modifier = Modifier.size(20.dp)
                            )
                            Spacer(modifier = Modifier.width(8.dp))
                            Column(modifier = Modifier.weight(1f)) {
                                Text(
                                    text = if (isAlertActive) "Spot Push Alert Active" else "Batch Full / Upcoming - Waitlist",
                                    fontSize = 12.sp,
                                    fontWeight = FontWeight.Bold,
                                    color = if (isAlertActive) Color(0xFF1B5E20) else MaterialTheme.colorScheme.tertiary
                                )
                                Text(
                                    text = if (isAlertActive) "You'll be instantly alerted via push notification as soon as a student cancels or a new seat opens." else "Subscribe to get alerted via push notification when seats become available.",
                                    fontSize = 10.5.sp,
                                    color = MaterialTheme.colorScheme.onSurfaceVariant
                                )
                            }
                        }

                        Spacer(modifier = Modifier.height(8.dp))

                        if (isAlertActive) {
                            OutlinedButton(
                                onClick = {
                                    coroutineScope.launch {
                                        BookMySpaceRepository.triggerSpotAvailablePush(context, classItem.id, 2)
                                        Toast.makeText(context, "🔔 Push Alert Triggered: Spot opened for ${classItem.title}!", Toast.LENGTH_SHORT).show()
                                    }
                                },
                                modifier = Modifier.fillMaxWidth().height(36.dp),
                                shape = RoundedCornerShape(8.dp)
                            ) {
                                Icon(Icons.Default.NotificationsActive, contentDescription = null, modifier = Modifier.size(14.dp))
                                Spacer(modifier = Modifier.width(6.dp))
                                Text("Simulate Push Notification Alert", fontSize = 11.5.sp, fontWeight = FontWeight.Bold)
                            }
                        } else {
                            Button(
                                onClick = {
                                    coroutineScope.launch {
                                        BookMySpaceRepository.subscribeBatchAlert(context, classItem)
                                        Toast.makeText(context, "🔔 Subscribed to push notifications for ${classItem.title}!", Toast.LENGTH_SHORT).show()
                                    }
                                },
                                colors = ButtonDefaults.buttonColors(
                                    containerColor = MaterialTheme.colorScheme.tertiary,
                                    contentColor = MaterialTheme.colorScheme.onTertiary
                                ),
                                modifier = Modifier.fillMaxWidth().height(36.dp),
                                shape = RoundedCornerShape(8.dp)
                            ) {
                                Icon(Icons.Default.NotificationsNone, contentDescription = null, modifier = Modifier.size(14.dp))
                                Spacer(modifier = Modifier.width(6.dp))
                                Text("Notify Me When Spots Open (Push Alert)", fontSize = 11.5.sp, fontWeight = FontWeight.Bold)
                            }
                        }
                    }
                }
                Spacer(modifier = Modifier.height(10.dp))
            }

            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                FilledTonalButton(
                    onClick = onCall,
                    modifier = Modifier.weight(1f),
                    shape = RoundedCornerShape(10.dp)
                ) {
                    Icon(Icons.Default.Phone, contentDescription = null, modifier = Modifier.size(15.dp))
                    Spacer(modifier = Modifier.width(4.dp))
                    Text("Call Faculty")
                }

                FilledTonalButton(
                    onClick = onWhatsApp,
                    modifier = Modifier.weight(1f),
                    shape = RoundedCornerShape(10.dp),
                    colors = ButtonDefaults.filledTonalButtonColors(
                        containerColor = Color(0xFF25D366).copy(alpha = 0.15f),
                        contentColor = Color(0xFF1B5E20)
                    )
                ) {
                    Icon(Icons.Default.Chat, contentDescription = null, modifier = Modifier.size(15.dp))
                    Spacer(modifier = Modifier.width(4.dp))
                    Text("WhatsApp")
                }
            }

            Spacer(modifier = Modifier.height(8.dp))

            if (isFullOrUpcoming) {
                Button(
                    onClick = {
                        coroutineScope.launch {
                            BookMySpaceRepository.subscribeBatchAlert(context, classItem)
                            Toast.makeText(context, "🔔 You are on the waitlist! Push notification alert enabled.", Toast.LENGTH_SHORT).show()
                        }
                    },
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(48.dp)
                        .testTag("modal_notify_me_btn"),
                    colors = ButtonDefaults.buttonColors(
                        containerColor = MaterialTheme.colorScheme.tertiary,
                        contentColor = MaterialTheme.colorScheme.onTertiary
                    ),
                    shape = RoundedCornerShape(12.dp)
                ) {
                    Icon(Icons.Default.NotificationsActive, contentDescription = null, modifier = Modifier.size(16.dp))
                    Spacer(modifier = Modifier.width(6.dp))
                    Text(if (isAlertActive) "Alert Active • On Waitlist" else "Notify Me When Spot Opens (Push Alert)", fontSize = 13.sp, fontWeight = FontWeight.Bold)
                }
            } else {
                Button(
                    onClick = onBookNow,
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(48.dp)
                        .testTag("modal_book_now_btn"),
                    shape = RoundedCornerShape(12.dp)
                ) {
                    Icon(Icons.Default.EventSeat, contentDescription = null, modifier = Modifier.size(16.dp))
                    Spacer(modifier = Modifier.width(6.dp))
                    Text("1-Tap Book Class (₹${classItem.feeAmount.toInt()})", fontSize = 14.sp, fontWeight = FontWeight.Bold)
                }
            }

            Spacer(modifier = Modifier.height(20.dp))
        }
    }
}

@Composable
private fun DetailAttributeRow(
    icon: androidx.compose.ui.graphics.vector.ImageVector,
    label: String,
    value: String
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(vertical = 4.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Icon(icon, contentDescription = null, modifier = Modifier.size(15.dp), tint = MaterialTheme.colorScheme.primary)
        Spacer(modifier = Modifier.width(8.dp))
        Column {
            Text(label, fontSize = 9.5.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
            Text(value, fontSize = 11.5.sp, fontWeight = FontWeight.SemiBold)
        }
    }
}

/**
 * Confirmed Class Booking Dialog
 */
@Composable
fun ClassBookingConfirmationDialog(
    booking: ConfirmedClassBooking,
    onDismiss: () -> Unit,
    onWhatsApp: () -> Unit
) {
    AlertDialog(
        onDismissRequest = onDismiss,
        icon = {
            Surface(
                color = Color(0xFF2E7D32).copy(alpha = 0.15f),
                shape = CircleShape,
                modifier = Modifier.size(54.dp)
            ) {
                Box(contentAlignment = Alignment.Center) {
                    Icon(Icons.Default.CheckCircle, contentDescription = null, tint = Color(0xFF2E7D32), modifier = Modifier.size(32.dp))
                }
            }
        },
        title = {
            Text("Class Seat Reserved!", fontWeight = FontWeight.Bold, fontSize = 18.sp, modifier = Modifier.testTag("booking_success_title"))
        },
        text = {
            Column(modifier = Modifier.fillMaxWidth()) {
                Text(
                    text = "Your booking for '${booking.classItem.title}' is confirmed.",
                    fontSize = 12.5.sp,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
                Spacer(modifier = Modifier.height(10.dp))

                Surface(
                    color = MaterialTheme.colorScheme.primaryContainer.copy(alpha = 0.4f),
                    shape = RoundedCornerShape(10.dp),
                    modifier = Modifier.fillMaxWidth()
                ) {
                    Column(modifier = Modifier.padding(10.dp)) {
                        Text("BOOKING REFERENCE", fontSize = 9.sp, fontWeight = FontWeight.Bold, color = MaterialTheme.colorScheme.primary)
                        Text(booking.bookingRef, fontSize = 15.sp, fontWeight = FontWeight.ExtraBold)
                        Spacer(modifier = Modifier.height(4.dp))
                        Text("Student: ${booking.studentName} • ${booking.studentPhone}", fontSize = 11.sp)
                        Text("Institute: ${booking.classItem.instituteName}", fontSize = 11.sp, fontWeight = FontWeight.SemiBold)
                        Text("Faculty: ${booking.classItem.facultyName}", fontSize = 11.sp)
                        Text("Timings: ${booking.classItem.startTime} - ${booking.classItem.endTime}", fontSize = 11.sp, color = MaterialTheme.colorScheme.primary, fontWeight = FontWeight.Bold)
                    }
                }
            }
        },
        confirmButton = {
            Button(
                onClick = onWhatsApp,
                colors = ButtonDefaults.buttonColors(containerColor = Color(0xFF25D366))
            ) {
                Icon(Icons.Default.Chat, contentDescription = null, modifier = Modifier.size(15.dp), tint = Color.White)
                Spacer(modifier = Modifier.width(4.dp))
                Text("WhatsApp Institute", color = Color.White, fontSize = 12.sp, fontWeight = FontWeight.Bold)
            }
        },
        dismissButton = {
            TextButton(onClick = onDismiss) {
                Text("Done")
            }
        }
    )
}

/**
 * 👨‍🏫 INTERACTIVE FACULTY PROFILE MODAL
 * Displays expanded biographies, certifications, teaching philosophy, honors/achievements,
 * key stats (students trained, rating, exp), and a live list of all courses taught by this instructor
 * with 1-tap direct booking.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun FacultyProfileDetailModalSheet(
    faculty: FacultyMember,
    onDismiss: () -> Unit,
    onBookClass: (InstituteClass) -> Unit,
    onClassDetail: (InstituteClass) -> Unit = {},
    onCall: (String) -> Unit = {},
    onWhatsApp: (String, String) -> Unit = { _, _ -> }
) {
    val coursesTaught = remember(faculty.name) {
        BookMySpaceRepository.getClassesForFaculty(faculty.name)
    }

    ModalBottomSheet(
        onDismissRequest = onDismiss,
        sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true),
        containerColor = MaterialTheme.colorScheme.surface
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 20.dp, vertical = 8.dp)
                .verticalScroll(rememberScrollState())
                .testTag("faculty_profile_modal_sheet")
        ) {
            // Header Bar with Close Button
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Surface(
                        color = MaterialTheme.colorScheme.primaryContainer,
                        shape = CircleShape,
                        modifier = Modifier.size(36.dp)
                    ) {
                        Box(contentAlignment = Alignment.Center) {
                            Icon(
                                imageVector = Icons.Default.School,
                                contentDescription = null,
                                tint = MaterialTheme.colorScheme.primary,
                                modifier = Modifier.size(20.dp)
                            )
                        }
                    }
                    Spacer(modifier = Modifier.width(10.dp))
                    Column {
                        Text(
                            text = "Faculty Profile & Portfolio",
                            fontSize = 17.sp,
                            fontWeight = FontWeight.ExtraBold
                        )
                        Text(
                            text = "Verified Instructor Credentials",
                            fontSize = 11.5.sp,
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                    }
                }

                IconButton(onClick = onDismiss) {
                    Icon(Icons.Default.Close, contentDescription = "Close")
                }
            }

            Spacer(modifier = Modifier.height(14.dp))

            // 1. HERO FACULTY CARD
            Card(
                modifier = Modifier.fillMaxWidth(),
                shape = RoundedCornerShape(18.dp),
                colors = CardDefaults.cardColors(
                    containerColor = MaterialTheme.colorScheme.primaryContainer.copy(alpha = 0.3f)
                ),
                border = BorderStroke(1.dp, MaterialTheme.colorScheme.primary.copy(alpha = 0.25f))
            ) {
                Column(modifier = Modifier.padding(16.dp)) {
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        // Large Avatar
                        Box {
                            if (faculty.photoUrl.isNotBlank()) {
                                AsyncImage(
                                    model = faculty.photoUrl,
                                    contentDescription = faculty.name,
                                    modifier = Modifier
                                        .size(72.dp)
                                        .clip(CircleShape)
                                        .border(2.dp, MaterialTheme.colorScheme.primary, CircleShape),
                                    contentScale = ContentScale.Crop
                                )
                            } else {
                                Box(
                                    modifier = Modifier
                                        .size(72.dp)
                                        .clip(CircleShape)
                                        .background(MaterialTheme.colorScheme.primaryContainer),
                                    contentAlignment = Alignment.Center
                                ) {
                                    Icon(
                                        imageVector = Icons.Default.Person,
                                        contentDescription = null,
                                        tint = MaterialTheme.colorScheme.primary,
                                        modifier = Modifier.size(36.dp)
                                    )
                                }
                            }
                            // Verified icon badge
                            Surface(
                                color = MaterialTheme.colorScheme.primary,
                                shape = CircleShape,
                                modifier = Modifier
                                    .size(22.dp)
                                    .align(Alignment.BottomEnd)
                            ) {
                                Box(contentAlignment = Alignment.Center) {
                                    Icon(
                                        imageVector = Icons.Default.Check,
                                        contentDescription = "Verified",
                                        tint = Color.White,
                                        modifier = Modifier.size(13.dp)
                                    )
                                }
                            }
                        }

                        Spacer(modifier = Modifier.width(14.dp))

                        Column(modifier = Modifier.weight(1f)) {
                            Text(
                                text = faculty.name,
                                fontSize = 18.sp,
                                fontWeight = FontWeight.ExtraBold,
                                color = MaterialTheme.colorScheme.onSurface
                            )
                            if (faculty.designation.isNotBlank()) {
                                Text(
                                    text = faculty.designation,
                                    fontSize = 12.5.sp,
                                    fontWeight = FontWeight.SemiBold,
                                    color = MaterialTheme.colorScheme.primary
                                )
                            }
                            if (faculty.education.isNotBlank() || faculty.qualification.isNotBlank()) {
                                Text(
                                    text = faculty.education.ifBlank { faculty.qualification },
                                    fontSize = 11.sp,
                                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                                    maxLines = 2,
                                    overflow = TextOverflow.Ellipsis
                                )
                            }
                        }
                    }

                    // 4 Key Stats Metrics Grid
                    Spacer(modifier = Modifier.height(14.dp))
                    HorizontalDivider(color = MaterialTheme.colorScheme.primary.copy(alpha = 0.15f))
                    Spacer(modifier = Modifier.height(12.dp))

                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.SpaceBetween
                    ) {
                        FacultyStatPill(
                            title = "EXPERIENCE",
                            value = "${faculty.experienceYears}+ Yrs",
                            icon = Icons.Default.WorkspacePremium
                        )
                        FacultyStatPill(
                            title = "STUDENTS",
                            value = "${faculty.studentsTrainedCount}+",
                            icon = Icons.Default.Groups
                        )
                        FacultyStatPill(
                            title = "RATING",
                            value = "⭐ ${faculty.rating}",
                            icon = Icons.Default.Star
                        )
                        FacultyStatPill(
                            title = "COURSES",
                            value = "${coursesTaught.size} Batches",
                            icon = Icons.Default.MenuBook
                        )
                    }
                }
            }

            // Quick Actions: Contact & Inquire
            Spacer(modifier = Modifier.height(12.dp))
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                FilledTonalButton(
                    onClick = { onCall(coursesTaught.firstOrNull()?.contactPhone ?: "+91 98765 11223") },
                    modifier = Modifier.weight(1f),
                    shape = RoundedCornerShape(10.dp)
                ) {
                    Icon(Icons.Default.Phone, contentDescription = null, modifier = Modifier.size(15.dp))
                    Spacer(modifier = Modifier.width(4.dp))
                    Text("Call Desk", fontSize = 12.sp)
                }

                FilledTonalButton(
                    onClick = { onWhatsApp(coursesTaught.firstOrNull()?.contactWhatsapp ?: "+91 98765 11223", faculty.name) },
                    modifier = Modifier.weight(1f),
                    shape = RoundedCornerShape(10.dp),
                    colors = ButtonDefaults.filledTonalButtonColors(
                        containerColor = Color(0xFF25D366).copy(alpha = 0.15f),
                        contentColor = Color(0xFF1B5E20)
                    )
                ) {
                    Icon(Icons.Default.Chat, contentDescription = null, modifier = Modifier.size(15.dp))
                    Spacer(modifier = Modifier.width(4.dp))
                    Text("WhatsApp", fontSize = 12.sp)
                }
            }

            // 2. EXPANDED BIOGRAPHY
            Spacer(modifier = Modifier.height(16.dp))
            Text(
                text = "Biography & Background",
                fontSize = 14.sp,
                fontWeight = FontWeight.Bold,
                color = MaterialTheme.colorScheme.primary
            )
            Spacer(modifier = Modifier.height(6.dp))
            Surface(
                color = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.45f),
                shape = RoundedCornerShape(12.dp),
                modifier = Modifier.fillMaxWidth()
            ) {
                Column(modifier = Modifier.padding(14.dp)) {
                    Text(
                        text = faculty.bio.ifBlank {
                            "${faculty.name} is a seasoned educator and mentor with over ${faculty.experienceYears} years of experience shaping student careers and fostering mastery in their discipline."
                        },
                        fontSize = 13.sp,
                        lineHeight = 19.sp,
                        color = MaterialTheme.colorScheme.onSurface
                    )

                    // Teaching Philosophy Card
                    if (faculty.teachingPhilosophy.isNotBlank()) {
                        Spacer(modifier = Modifier.height(10.dp))
                        Surface(
                            color = MaterialTheme.colorScheme.secondaryContainer.copy(alpha = 0.35f),
                            shape = RoundedCornerShape(8.dp),
                            border = BorderStroke(1.dp, MaterialTheme.colorScheme.secondary.copy(alpha = 0.25f)),
                            modifier = Modifier.fillMaxWidth()
                        ) {
                            Row(
                                modifier = Modifier.padding(10.dp),
                                verticalAlignment = Alignment.Top
                            ) {
                                Icon(
                                    imageVector = Icons.Default.FormatQuote,
                                    contentDescription = null,
                                    tint = MaterialTheme.colorScheme.secondary,
                                    modifier = Modifier.size(20.dp)
                                )
                                Spacer(modifier = Modifier.width(6.dp))
                                Column {
                                    Text(
                                        text = "TEACHING PHILOSOPHY",
                                        fontSize = 9.5.sp,
                                        fontWeight = FontWeight.ExtraBold,
                                        color = MaterialTheme.colorScheme.secondary
                                    )
                                    Text(
                                        text = "\"${faculty.teachingPhilosophy}\"",
                                        fontSize = 12.sp,
                                        fontWeight = FontWeight.Medium,
                                        fontStyle = androidx.compose.ui.text.font.FontStyle.Italic,
                                        color = MaterialTheme.colorScheme.onSecondaryContainer
                                    )
                                }
                            }
                        }
                    }
                }
            }

            // 3. CERTIFICATIONS & ACCREDITATIONS
            if (faculty.certifications.isNotEmpty()) {
                Spacer(modifier = Modifier.height(16.dp))
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Text(
                        text = "Official Certifications & Credentials",
                        fontSize = 14.sp,
                        fontWeight = FontWeight.Bold,
                        color = MaterialTheme.colorScheme.primary
                    )
                    Surface(
                        color = MaterialTheme.colorScheme.primaryContainer,
                        shape = RoundedCornerShape(6.dp)
                    ) {
                        Text(
                            text = "${faculty.certifications.size} Verified",
                            fontSize = 10.sp,
                            fontWeight = FontWeight.Bold,
                            color = MaterialTheme.colorScheme.primary,
                            modifier = Modifier.padding(horizontal = 6.dp, vertical = 2.dp)
                        )
                    }
                }
                Spacer(modifier = Modifier.height(8.dp))

                Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
                    faculty.certifications.forEach { cert ->
                        Surface(
                            color = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.45f),
                            shape = RoundedCornerShape(10.dp),
                            border = BorderStroke(1.dp, MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.4f)),
                            modifier = Modifier.fillMaxWidth()
                        ) {
                            Row(
                                modifier = Modifier.padding(horizontal = 12.dp, vertical = 8.dp),
                                verticalAlignment = Alignment.CenterVertically
                            ) {
                                Surface(
                                    color = Color(0xFFFFA000).copy(alpha = 0.15f),
                                    shape = CircleShape,
                                    modifier = Modifier.size(28.dp)
                                ) {
                                    Box(contentAlignment = Alignment.Center) {
                                        Icon(
                                            imageVector = Icons.Default.VerifiedUser,
                                            contentDescription = null,
                                            tint = Color(0xFFF57C00),
                                            modifier = Modifier.size(16.dp)
                                        )
                                    }
                                }
                                Spacer(modifier = Modifier.width(10.dp))
                                Text(
                                    text = cert,
                                    fontSize = 12.sp,
                                    fontWeight = FontWeight.SemiBold,
                                    color = MaterialTheme.colorScheme.onSurface,
                                    modifier = Modifier.weight(1f)
                                )
                                Icon(
                                    imageVector = Icons.Default.CheckCircle,
                                    contentDescription = "Verified",
                                    tint = Color(0xFF2E7D32),
                                    modifier = Modifier.size(14.dp)
                                )
                            }
                        }
                    }
                }
            }

            // 4. HONORS & ACHIEVEMENTS
            if (faculty.achievements.isNotEmpty()) {
                Spacer(modifier = Modifier.height(16.dp))
                Text(
                    text = "Honors & Key Achievements",
                    fontSize = 14.sp,
                    fontWeight = FontWeight.Bold,
                    color = MaterialTheme.colorScheme.primary
                )
                Spacer(modifier = Modifier.height(8.dp))
                Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
                    faculty.achievements.forEach { achievement ->
                        Surface(
                            color = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.35f),
                            shape = RoundedCornerShape(10.dp),
                            modifier = Modifier.fillMaxWidth()
                        ) {
                            Row(
                                modifier = Modifier.padding(horizontal = 12.dp, vertical = 8.dp),
                                verticalAlignment = Alignment.Top
                            ) {
                                Icon(
                                    imageVector = Icons.Default.EmojiEvents,
                                    contentDescription = null,
                                    tint = Color(0xFFE65100),
                                    modifier = Modifier.size(18.dp)
                                )
                                Spacer(modifier = Modifier.width(8.dp))
                                Text(
                                    text = achievement,
                                    fontSize = 12.sp,
                                    lineHeight = 17.sp,
                                    color = MaterialTheme.colorScheme.onSurface
                                )
                            }
                        }
                    }
                }
            }

            // 5. SPECIALTIES & COMPETENCIES
            if (faculty.specialties.isNotEmpty()) {
                Spacer(modifier = Modifier.height(16.dp))
                Text(
                    text = "Specialties & Domain Focus",
                    fontSize = 14.sp,
                    fontWeight = FontWeight.Bold,
                    color = MaterialTheme.colorScheme.primary
                )
                Spacer(modifier = Modifier.height(8.dp))
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.spacedBy(6.dp)
                ) {
                    faculty.specialties.forEach { spec ->
                        Surface(
                            color = MaterialTheme.colorScheme.tertiaryContainer.copy(alpha = 0.4f),
                            shape = RoundedCornerShape(8.dp),
                            border = BorderStroke(1.dp, MaterialTheme.colorScheme.tertiary.copy(alpha = 0.2f))
                        ) {
                            Text(
                                text = "🎯 $spec",
                                fontSize = 11.5.sp,
                                fontWeight = FontWeight.SemiBold,
                                color = MaterialTheme.colorScheme.onTertiaryContainer,
                                modifier = Modifier.padding(horizontal = 10.dp, vertical = 5.dp)
                            )
                        }
                    }
                }
            }

            // 6. ALL COURSES TAUGHT BY THIS INSTRUCTOR (CRITICAL REQUIREMENT)
            Spacer(modifier = Modifier.height(20.dp))
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Column {
                    Text(
                        text = "Courses & Batches Taught",
                        fontSize = 15.sp,
                        fontWeight = FontWeight.ExtraBold,
                        color = MaterialTheme.colorScheme.onSurface
                    )
                    Text(
                        text = "${coursesTaught.size} courses available by ${faculty.name}",
                        fontSize = 11.sp,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                }

                Surface(
                    color = MaterialTheme.colorScheme.primary,
                    shape = RoundedCornerShape(8.dp)
                ) {
                    Text(
                        text = "${coursesTaught.size} Active",
                        fontSize = 11.sp,
                        fontWeight = FontWeight.Bold,
                        color = MaterialTheme.colorScheme.onPrimary,
                        modifier = Modifier.padding(horizontal = 8.dp, vertical = 3.dp)
                    )
                }
            }
            Spacer(modifier = Modifier.height(10.dp))

            if (coursesTaught.isEmpty()) {
                Surface(
                    color = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.35f),
                    shape = RoundedCornerShape(12.dp),
                    modifier = Modifier.fillMaxWidth()
                ) {
                    Column(
                        modifier = Modifier.padding(16.dp),
                        horizontalAlignment = Alignment.CenterHorizontally
                    ) {
                        Icon(Icons.Default.School, contentDescription = null, tint = MaterialTheme.colorScheme.onSurfaceVariant, modifier = Modifier.size(32.dp))
                        Spacer(modifier = Modifier.height(6.dp))
                        Text("No active open batches at this moment.", fontSize = 12.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                    }
                }
            } else {
                Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                    coursesTaught.forEach { course ->
                        Card(
                            modifier = Modifier
                                .fillMaxWidth()
                                .clickable { onClassDetail(course) },
                            shape = RoundedCornerShape(14.dp),
                            colors = CardDefaults.cardColors(
                                containerColor = MaterialTheme.colorScheme.surface
                            ),
                            elevation = CardDefaults.cardElevation(defaultElevation = 2.dp),
                            border = BorderStroke(1.dp, MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.5f))
                        ) {
                            Column(modifier = Modifier.padding(12.dp)) {
                                Row(
                                    modifier = Modifier.fillMaxWidth(),
                                    horizontalArrangement = Arrangement.SpaceBetween,
                                    verticalAlignment = Alignment.CenterVertically
                                ) {
                                    Surface(
                                        color = MaterialTheme.colorScheme.primaryContainer,
                                        shape = RoundedCornerShape(6.dp)
                                    ) {
                                        Text(
                                            text = course.category,
                                            fontSize = 10.sp,
                                            fontWeight = FontWeight.Bold,
                                            color = MaterialTheme.colorScheme.primary,
                                            modifier = Modifier.padding(horizontal = 6.dp, vertical = 2.dp)
                                        )
                                    }
                                    DeliveryModeBadge(mode = course.deliveryMode)
                                }

                                Spacer(modifier = Modifier.height(6.dp))
                                Text(
                                    text = course.title,
                                    fontSize = 14.sp,
                                    fontWeight = FontWeight.Bold,
                                    maxLines = 2,
                                    overflow = TextOverflow.Ellipsis
                                )

                                Text(
                                    text = "🏛️ ${course.instituteName}",
                                    fontSize = 11.5.sp,
                                    color = MaterialTheme.colorScheme.primary,
                                    fontWeight = FontWeight.Medium
                                )

                                Spacer(modifier = Modifier.height(6.dp))
                                Surface(
                                    color = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.5f),
                                    shape = RoundedCornerShape(8.dp),
                                    modifier = Modifier.fillMaxWidth()
                                ) {
                                    Row(
                                        modifier = Modifier.padding(horizontal = 8.dp, vertical = 6.dp),
                                        horizontalArrangement = Arrangement.SpaceBetween,
                                        verticalAlignment = Alignment.CenterVertically
                                    ) {
                                        Row(verticalAlignment = Alignment.CenterVertically) {
                                            Icon(Icons.Default.Schedule, contentDescription = null, modifier = Modifier.size(13.dp), tint = MaterialTheme.colorScheme.primary)
                                            Spacer(modifier = Modifier.width(4.dp))
                                            Text(
                                                text = "${course.startTime} - ${course.endTime}",
                                                fontSize = 11.sp,
                                                fontWeight = FontWeight.Bold
                                            )
                                        }

                                        Row(verticalAlignment = Alignment.CenterVertically) {
                                            Icon(Icons.Default.HourglassEmpty, contentDescription = null, modifier = Modifier.size(12.dp), tint = MaterialTheme.colorScheme.onSurfaceVariant)
                                            Spacer(modifier = Modifier.width(3.dp))
                                            Text(
                                                text = course.durationText,
                                                fontSize = 11.sp,
                                                color = MaterialTheme.colorScheme.onSurfaceVariant
                                            )
                                        }
                                    }
                                }

                                Spacer(modifier = Modifier.height(8.dp))
                                Row(
                                    modifier = Modifier.fillMaxWidth(),
                                    horizontalArrangement = Arrangement.SpaceBetween,
                                    verticalAlignment = Alignment.CenterVertically
                                ) {
                                    Column {
                                        Text(
                                            text = "₹${course.feeAmount.toInt()}",
                                            fontSize = 15.sp,
                                            fontWeight = FontWeight.ExtraBold,
                                            color = MaterialTheme.colorScheme.primary
                                        )
                                        Text(
                                            text = "per ${course.feeBillingCycle}",
                                            fontSize = 9.5.sp,
                                            color = MaterialTheme.colorScheme.onSurfaceVariant
                                        )
                                    }

                                    // 1-Tap Single Tab Booking Action for this course
                                    Button(
                                        onClick = { onBookClass(course) },
                                        shape = RoundedCornerShape(10.dp),
                                        contentPadding = PaddingValues(horizontal = 14.dp, vertical = 6.dp),
                                        modifier = Modifier.height(36.dp)
                                    ) {
                                        Icon(Icons.Default.CheckCircle, contentDescription = null, modifier = Modifier.size(14.dp))
                                        Spacer(modifier = Modifier.width(4.dp))
                                        Text("Book Seat", fontSize = 12.sp, fontWeight = FontWeight.Bold)
                                    }
                                }
                            }
                        }
                    }
                }
            }

            Spacer(modifier = Modifier.height(24.dp))
        }
    }
}

@Composable
private fun FacultyStatPill(
    title: String,
    value: String,
    icon: androidx.compose.ui.graphics.vector.ImageVector
) {
    Column(
        horizontalAlignment = Alignment.CenterHorizontally,
        modifier = Modifier.padding(horizontal = 4.dp)
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Icon(icon, contentDescription = null, modifier = Modifier.size(13.dp), tint = MaterialTheme.colorScheme.primary)
            Spacer(modifier = Modifier.width(3.dp))
            Text(value, fontSize = 12.sp, fontWeight = FontWeight.ExtraBold, color = MaterialTheme.colorScheme.onSurface)
        }
        Text(title, fontSize = 9.sp, fontWeight = FontWeight.Bold, color = MaterialTheme.colorScheme.onSurfaceVariant)
    }
}

data class ConfirmedClassBooking(
    val bookingRef: String,
    val classItem: InstituteClass,
    val studentName: String,
    val studentPhone: String,
    val studentEmail: String,
    val amountPaid: Double,
    val selectedMode: ClassDeliveryMode,
    val bookingTimestamp: Long
)

// Helper navigation & communication functions
private fun initiatePhoneCall(context: Context, phone: String) {
    if (phone.isBlank()) {
        Toast.makeText(context, "Contact phone number not available", Toast.LENGTH_SHORT).show()
        return
    }
    try {
        val intent = Intent(Intent.ACTION_DIAL, Uri.parse("tel:$phone"))
        context.startActivity(intent)
    } catch (e: Exception) {
        Toast.makeText(context, "Calling $phone", Toast.LENGTH_SHORT).show()
    }
}

private fun initiateWhatsApp(context: Context, phone: String, message: String) {
    try {
        val cleanNumber = phone.replace("+", "").replace(" ", "").replace("-", "")
        val uri = Uri.parse("https://api.whatsapp.com/send?phone=$cleanNumber&text=${Uri.encode(message)}")
        val intent = Intent(Intent.ACTION_VIEW, uri)
        context.startActivity(intent)
    } catch (e: Exception) {
        Toast.makeText(context, "Opening WhatsApp for $phone", Toast.LENGTH_SHORT).show()
    }
}

private fun openMaps(context: Context, location: String) {
    try {
        val uri = Uri.parse("geo:0,0?q=${Uri.encode(location)}")
        val intent = Intent(Intent.ACTION_VIEW, uri)
        context.startActivity(intent)
    } catch (e: Exception) {
        Toast.makeText(context, "Opening Map for $location", Toast.LENGTH_SHORT).show()
    }
}

/**
 * 🎯 CATEGORY CHECKBOX FILTER SHEET
 * Simple & easy checkbook style multi-category filter modal with batch counts, delivery modes, and waitlist alert toggles.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun CategoryCheckboxFilterSheet(
    selectedCategories: Set<String>,
    onCategoryToggle: (String) -> Unit,
    onSelectAll: () -> Unit,
    onClearAll: () -> Unit,
    selectedMode: ClassDeliveryMode?,
    onModeToggle: (ClassDeliveryMode) -> Unit,
    showFullBatchesOnly: Boolean,
    onToggleFullBatchesOnly: () -> Unit,
    classes: List<InstituteClass>,
    onDismiss: () -> Unit
) {
    val filterCategories = listOf(
        FilterCategoryItem("Sports & Fitness", Icons.Default.SportsBasketball, "Badminton, Swimming, Cricket, Tennis"),
        FilterCategoryItem("Academics", Icons.Default.School, "Maths, Physics, NEET, JEE, Foundation"),
        FilterCategoryItem("Tech & Coding", Icons.Default.Code, "Python, AI, Full Stack, Robotics"),
        FilterCategoryItem("Dance", Icons.Default.MusicNote, "Classical, Contemporary, Hip Hop, Zumba"),
        FilterCategoryItem("Music & Arts", Icons.Default.Brush, "Vocal, Guitar, Keyboard, Painting, Sketching"),
        FilterCategoryItem("Martial Arts & Self Defense", Icons.Default.SportsKabaddi, "Karate, Taekwondo, Kung Fu, MMA"),
        FilterCategoryItem("Yoga & Wellness", Icons.Default.SelfImprovement, "Hatha Yoga, Meditation, Pranayama")
    )

    ModalBottomSheet(
        onDismissRequest = onDismiss,
        sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true),
        containerColor = MaterialTheme.colorScheme.surface,
        dragHandle = { BottomSheetDefaults.DragHandle() }
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 20.dp)
                .verticalScroll(rememberScrollState())
        ) {
            // Header
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Column {
                    Text(
                        text = "Category Checkbook Filter",
                        style = MaterialTheme.typography.titleLarge,
                        fontWeight = FontWeight.Bold
                    )
                    Text(
                        text = "Select multiple categories to refine coaching batches",
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                }

                IconButton(
                    onClick = onDismiss,
                    modifier = Modifier.testTag("close_category_filter_btn")
                ) {
                    Icon(Icons.Default.Close, contentDescription = "Close")
                }
            }

            Spacer(modifier = Modifier.height(12.dp))

            // Quick Actions: Select All / Clear All
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Text(
                    text = "${selectedCategories.size} of ${filterCategories.size} categories selected",
                    fontSize = 12.sp,
                    fontWeight = FontWeight.SemiBold,
                    color = MaterialTheme.colorScheme.primary
                )

                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    TextButton(
                        onClick = onSelectAll,
                        contentPadding = PaddingValues(horizontal = 8.dp, vertical = 2.dp),
                        modifier = Modifier.height(28.dp).testTag("filter_select_all_btn")
                    ) {
                        Text("Select All", fontSize = 11.5.sp)
                    }

                    TextButton(
                        onClick = onClearAll,
                        contentPadding = PaddingValues(horizontal = 8.dp, vertical = 2.dp),
                        modifier = Modifier.height(28.dp).testTag("filter_clear_all_btn")
                    ) {
                        Text("Clear All", fontSize = 11.5.sp)
                    }
                }
            }

            Spacer(modifier = Modifier.height(8.dp))
            HorizontalDivider(color = MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.5f))
            Spacer(modifier = Modifier.height(10.dp))

            // CATEGORY CHECKBOX LIST (Checkbook Style)
            Text(
                text = "CHOOSE CATEGORIES",
                fontSize = 11.sp,
                fontWeight = FontWeight.ExtraBold,
                color = MaterialTheme.colorScheme.primary,
                letterSpacing = 0.5.sp
            )
            Spacer(modifier = Modifier.height(6.dp))

            filterCategories.forEach { item ->
                val isChecked = selectedCategories.contains(item.name)
                val batchCount = remember(classes, item.name) {
                    classes.count { it.category.contains(item.name, ignoreCase = true) || item.name.contains(it.category, ignoreCase = true) }
                }

                Surface(
                    onClick = { onCategoryToggle(item.name) },
                    shape = RoundedCornerShape(10.dp),
                    color = if (isChecked) MaterialTheme.colorScheme.primaryContainer.copy(alpha = 0.35f) else MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.3f),
                    border = BorderStroke(
                        width = if (isChecked) 1.5.dp else 1.dp,
                        color = if (isChecked) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.5f)
                    ),
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(vertical = 4.dp)
                        .testTag("category_checkbox_row_${item.name.lowercase().replace(" ", "_")}")
                ) {
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(horizontal = 10.dp, vertical = 8.dp),
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Checkbox(
                            checked = isChecked,
                            onCheckedChange = { onCategoryToggle(item.name) },
                            colors = CheckboxDefaults.colors(checkedColor = MaterialTheme.colorScheme.primary),
                            modifier = Modifier.testTag("checkbox_${item.name.lowercase().replace(" ", "_")}")
                        )

                        Spacer(modifier = Modifier.width(6.dp))

                        Surface(
                            shape = CircleShape,
                            color = if (isChecked) MaterialTheme.colorScheme.primary.copy(alpha = 0.15f) else MaterialTheme.colorScheme.surfaceVariant,
                            modifier = Modifier.size(32.dp)
                        ) {
                            Box(contentAlignment = Alignment.Center) {
                                Icon(
                                    imageVector = item.icon,
                                    contentDescription = null,
                                    tint = if (isChecked) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.onSurfaceVariant,
                                    modifier = Modifier.size(17.dp)
                                )
                            }
                        }

                        Spacer(modifier = Modifier.width(10.dp))

                        Column(modifier = Modifier.weight(1f)) {
                            Row(verticalAlignment = Alignment.CenterVertically) {
                                Text(
                                    text = item.name,
                                    fontSize = 13.5.sp,
                                    fontWeight = if (isChecked) FontWeight.Bold else FontWeight.Medium
                                )
                                Spacer(modifier = Modifier.width(6.dp))
                                Surface(
                                    color = MaterialTheme.colorScheme.surfaceVariant,
                                    shape = RoundedCornerShape(4.dp)
                                ) {
                                    Text(
                                        text = "$batchCount batches",
                                        fontSize = 9.5.sp,
                                        fontWeight = FontWeight.SemiBold,
                                        modifier = Modifier.padding(horizontal = 4.dp, vertical = 1.dp)
                                    )
                                }
                            }
                            Text(
                                text = item.description,
                                fontSize = 10.5.sp,
                                color = MaterialTheme.colorScheme.onSurfaceVariant,
                                maxLines = 1,
                                overflow = TextOverflow.Ellipsis
                            )
                        }
                    }
                }
            }

            Spacer(modifier = Modifier.height(14.dp))
            HorizontalDivider(color = MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.5f))
            Spacer(modifier = Modifier.height(10.dp))

            // DELIVERY MODE FILTER
            Text(
                text = "DELIVERY MODE",
                fontSize = 11.sp,
                fontWeight = FontWeight.ExtraBold,
                color = MaterialTheme.colorScheme.primary,
                letterSpacing = 0.5.sp
            )
            Spacer(modifier = Modifier.height(6.dp))

            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                ClassDeliveryMode.entries.forEach { mode ->
                    val isModeSelected = selectedMode == mode
                    FilterChip(
                        selected = isModeSelected,
                        onClick = { onModeToggle(mode) },
                        label = { Text(mode.shortBadge, fontSize = 11.5.sp, fontWeight = FontWeight.Bold) },
                        leadingIcon = {
                            Icon(
                                when (mode) {
                                    ClassDeliveryMode.OFFLINE -> Icons.Default.LocationOn
                                    ClassDeliveryMode.ONLINE -> Icons.Default.Laptop
                                    ClassDeliveryMode.HYBRID -> Icons.Default.Devices
                                },
                                contentDescription = null,
                                modifier = Modifier.size(13.dp)
                            )
                        },
                        modifier = Modifier.weight(1f).testTag("filter_mode_${mode.name.lowercase()}")
                    )
                }
            }

            Spacer(modifier = Modifier.height(14.dp))

            // NOTIFY ME / FULL BATCHES FILTER TOGGLE
            Surface(
                color = if (showFullBatchesOnly) MaterialTheme.colorScheme.tertiaryContainer.copy(alpha = 0.4f) else MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.4f),
                shape = RoundedCornerShape(12.dp),
                border = BorderStroke(1.dp, if (showFullBatchesOnly) MaterialTheme.colorScheme.tertiary.copy(alpha = 0.4f) else MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.4f)),
                modifier = Modifier.fillMaxWidth()
            ) {
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(12.dp),
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.SpaceBetween
                ) {
                    Row(
                        modifier = Modifier.weight(1f),
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Icon(
                            imageVector = Icons.Default.NotificationsActive,
                            contentDescription = null,
                            tint = MaterialTheme.colorScheme.tertiary,
                            modifier = Modifier.size(20.dp)
                        )
                        Spacer(modifier = Modifier.width(10.dp))
                        Column {
                            Text("Full & Upcoming Batches (Waitlist)", fontSize = 12.5.sp, fontWeight = FontWeight.Bold)
                            Text("Show batches needing spot alerts & push notifications", fontSize = 10.5.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                        }
                    }

                    Switch(
                        checked = showFullBatchesOnly,
                        onCheckedChange = { onToggleFullBatchesOnly() },
                        modifier = Modifier.testTag("toggle_full_batches_filter")
                    )
                }
            }

            Spacer(modifier = Modifier.height(16.dp))

            // APPLY FILTERS BUTTON
            Button(
                onClick = onDismiss,
                modifier = Modifier
                    .fillMaxWidth()
                    .height(48.dp)
                    .testTag("apply_category_filter_btn"),
                shape = RoundedCornerShape(12.dp)
            ) {
                Icon(Icons.Default.Done, contentDescription = null, modifier = Modifier.size(16.dp))
                Spacer(modifier = Modifier.width(6.dp))
                Text(
                    text = if (selectedCategories.isEmpty()) "Apply Filters (All Categories)" else "Apply Filters (${selectedCategories.size} Selected)",
                    fontWeight = FontWeight.Bold,
                    fontSize = 14.sp
                )
            }

            Spacer(modifier = Modifier.height(24.dp))
        }
    }
}

private data class FilterCategoryItem(
    val name: String,
    val icon: androidx.compose.ui.graphics.vector.ImageVector,
    val description: String
)
