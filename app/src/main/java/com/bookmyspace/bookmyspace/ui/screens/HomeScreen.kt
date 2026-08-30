package com.bookmyspace.bookmyspace.ui.screens

import android.content.Intent
import android.net.Uri
import androidx.compose.animation.AnimatedVisibilityScope
import androidx.compose.animation.ExperimentalSharedTransitionApi
import androidx.compose.animation.SharedTransitionScope
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.gestures.snapping.rememberSnapFlingBehavior
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.automirrored.filled.ArrowForward
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.material3.pulltorefresh.PullToRefreshBox
import androidx.compose.material3.pulltorefresh.rememberPullToRefreshState
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
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import coil.compose.AsyncImage
import com.bookmyspace.bookmyspace.data.model.LocationHierarchy
import com.bookmyspace.bookmyspace.data.model.LocationSearchRadius
import com.bookmyspace.bookmyspace.data.location.IndiaLocationMasterData
import com.bookmyspace.bookmyspace.ui.components.LocationHierarchyHeaderBar
import com.bookmyspace.bookmyspace.ui.components.LocationHierarchySelectorDialog
import com.bookmyspace.bookmyspace.data.model.Venue
import com.bookmyspace.bookmyspace.data.repository.BookMySpaceRepository
import com.bookmyspace.bookmyspace.ui.components.AmenityFilterOption
import com.bookmyspace.bookmyspace.ui.components.BookMySpaceLogo
import com.bookmyspace.bookmyspace.ui.components.EasyVoiceBookingBanner
import com.bookmyspace.bookmyspace.ui.components.EasyVoiceBookingDialog
import com.bookmyspace.bookmyspace.ui.components.LanguageSelectorChip
import com.bookmyspace.bookmyspace.ui.components.LanguageSelectorDialog
import com.bookmyspace.bookmyspace.ui.components.QuickBookCard
import com.bookmyspace.bookmyspace.ui.components.ResponsiveLayout
import com.bookmyspace.bookmyspace.ui.components.ResponsiveDimensions
import com.bookmyspace.bookmyspace.ui.components.responsiveGridItems
import com.bookmyspace.bookmyspace.ui.components.VenueFilterBottomSheet
import com.bookmyspace.bookmyspace.ui.components.VenueImageCarousel
import com.bookmyspace.bookmyspace.ui.components.HotDealsCarouselWidget
import com.bookmyspace.bookmyspace.ui.components.SmartSpaceRadarWidget
import com.bookmyspace.bookmyspace.ui.components.DailyLuckyRewardWidget
import com.bookmyspace.bookmyspace.ui.components.LiveActivityPulseTicker
import com.bookmyspace.bookmyspace.ui.components.SmoothAutoMovingCategoryStrip
import com.bookmyspace.bookmyspace.ui.components.AvailableSectionsSlowMarqueeStrip
import com.bookmyspace.bookmyspace.ui.components.AddCustomCategoryDialog
import com.bookmyspace.bookmyspace.ui.components.PulsePopCategoryPill
import com.bookmyspace.bookmyspace.ui.components.SmartWeatherSpaceInsightsWidget
import com.bookmyspace.bookmyspace.ui.components.EyeCatchingFullHomeSkeleton
import com.bookmyspace.bookmyspace.ui.components.EyeCatchingVenueCardSkeleton
import com.bookmyspace.bookmyspace.ui.components.EyeCatchingCategoryChipsSkeleton
import com.bookmyspace.bookmyspace.ui.components.shimmerLoading
import com.bookmyspace.bookmyspace.ui.components.pulsingGlow
import com.bookmyspace.bookmyspace.ui.components.CompactAdaptiveSearchHeader
import com.bookmyspace.bookmyspace.ui.components.GuestAndRoomPickerDialog
import com.bookmyspace.bookmyspace.ui.components.SimpleQuickDateDialog
import com.bookmyspace.bookmyspace.data.network.NetworkRetryManager
import com.bookmyspace.bookmyspace.data.network.NetworkSyncState
import com.bookmyspace.bookmyspace.ui.components.NetworkErrorRetryCard
import com.bookmyspace.bookmyspace.ui.components.NetworkSyncStatusBanner
import com.bookmyspace.bookmyspace.util.LocalizedStrings
import com.bookmyspace.bookmyspace.util.PerformanceTracer
import com.bookmyspace.bookmyspace.util.TraceCategory
import com.bookmyspace.bookmyspace.util.VenueImageResolver
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

data class QuickFilterChip(
    val id: String,
    val label: String,
    val emoji: String
)

enum class HomeScreenSortOption(val displayName: String, val icon: String) {
    DISTANCE("Distance: Nearest", "📍"),
    RECOMMENDED("Recommended", "✨"),
    PRICE_LOW("Price: Low to High", "💰"),
    PRICE_HIGH("Price: High to Low", "💎"),
    RATING("Rating: Highest", "⭐")
}

/**
 * 4 Primary Main Sections of BookMySpace Customer Experience
 */
enum class MainHomeSection(
    val id: String,
    val title: String,
    val subtitle: String,
    val emoji: String,
    val imageUrl: String,
    val adminSectionKey: String,
    val categoryOptions: List<MainSectionCategoryOption>
) {
    FUNCTION_HALLS(
        id = "function_halls",
        title = "Function Halls",
        subtitle = "Marriage, Convention, Party, Community & Govt Halls",
        emoji = "🏛️",
        imageUrl = "https://images.unsplash.com/photo-1519167758481-83f550bb49b3?w=800&auto=format&fit=crop&q=80",
        adminSectionKey = "venues_function_halls",
        categoryOptions = listOf(
            MainSectionCategoryOption("all", "All Halls", "✨"),
            MainSectionCategoryOption("marriage_hall", "Marriage Hall", "💒", "Weddings & Receptions"),
            MainSectionCategoryOption("convention_center", "Convention Hall", "🏛️", "Summits & Conferences"),
            MainSectionCategoryOption("banquet_hall", "Party Hall / Banquet", "🍸", "Birthdays & Dinners"),
            MainSectionCategoryOption("community_hall", "Community Hall", "🤝", "Family & Society Meets"),
            MainSectionCategoryOption("govt_hall", "Government Hall", "🏢", "Official & Public Town Halls"),
            MainSectionCategoryOption("party_lawn", "Open Lawn Ground", "🌳", "Outdoor Weddings & Lawns"),
            MainSectionCategoryOption("other_hall", "Other Event Spaces", "🎪", "Exhibitions, Open Lawns, Theatres & Custom Grounds")
        )
    ),
    LODGE_ROOMS(
        id = "lodge_rooms",
        title = "Lodge / Rooms",
        subtitle = "Hotels, Lodges, Guest Houses & Day Rooms",
        emoji = "🏨",
        imageUrl = "https://images.unsplash.com/photo-1566073771259-6a8506099945?w=800&auto=format&fit=crop&q=80",
        adminSectionKey = "hotels_rooms",
        categoryOptions = listOf(
            MainSectionCategoryOption("all", "All Stays", "✨"),
            MainSectionCategoryOption("hotel", "Hotel", "🏨", "Luxury & Star Stays"),
            MainSectionCategoryOption("lodge", "Lodge", "🛏️", "Budget & Short-stay Lodges"),
            MainSectionCategoryOption("guest_house", "Guest House", "🏡", "Quiet & Homely Guest Rooms"),
            MainSectionCategoryOption("hourly_room", "Hourly / Day Room", "⏱️", "Short Stay & Day Use"),
            MainSectionCategoryOption("resort", "Resort / Homestay", "🌴", "Getaways & Nature Stays"),
            MainSectionCategoryOption("other_stay", "Other Accommodations", "🏕️", "Farmhouses, Cottages, Tents & Custom Stays")
        )
    ),
    PG_HOSTELS(
        id = "pg_hostels",
        title = "PG / Hostels",
        subtitle = "Gents PG, Ladies PG, Hostels & Co-living",
        emoji = "🏠",
        imageUrl = "https://images.unsplash.com/photo-1522708323590-d24dbb6b0267?w=800&auto=format&fit=crop&q=80",
        adminSectionKey = "pg_hostels",
        categoryOptions = listOf(
            MainSectionCategoryOption("all", "All PG & Hostels", "✨"),
            MainSectionCategoryOption("gents_pg", "Gents PG", "👨", "Men's Stays with Food & WiFi"),
            MainSectionCategoryOption("ladies_pg", "Ladies PG", "👩", "Women's Safe Secure Stays"),
            MainSectionCategoryOption("student_hostel", "Student Hostel", "🎒", "College & Academy Hostels"),
            MainSectionCategoryOption("co_living", "Co-living Spaces", "🤝", "Modern Shared Living"),
            MainSectionCategoryOption("single_room", "Single Sharing Room", "🔑", "Private & Shared Rooms"),
            MainSectionCategoryOption("other_pg", "Other Hostels & PGs", "🏡", "Executive PGs, Studio Stays & Custom Living")
        )
    ),
    INSTITUTES_CLASSES(
        id = "institutes_classes",
        title = "Institutes / Classes",
        subtitle = "Coaching, Tuition, Computer, Dance, Music & Sports",
        emoji = "🎓",
        imageUrl = "https://images.unsplash.com/photo-1524178232363-1fb2b075b655?w=800&auto=format&fit=crop&q=80",
        adminSectionKey = "institutes_classes",
        categoryOptions = listOf(
            MainSectionCategoryOption("all", "All Classes", "✨"),
            MainSectionCategoryOption("coaching", "Coaching & Tuition", "📚", "School, College & Prep"),
            MainSectionCategoryOption("computer_it", "Computer & IT Classes", "💻", "Coding, AI & Digital Skills"),
            MainSectionCategoryOption("dance_academy", "Dance Academy", "💃", "Classical, Western & Zumba"),
            MainSectionCategoryOption("music_class", "Music & Singing", "🎵", "Guitar, Keyboard & Vocals"),
            MainSectionCategoryOption("sports_academy", "Sports Academy & Turfs", "🏸", "Badminton, Cricket & Fitness"),
            MainSectionCategoryOption("other_class", "Other Classes & Studios", "🎨", "Art, Yoga, Martial Arts, Cooking & Workshops")
        )
    )
}

data class MainSectionCategoryOption(
    val id: String,
    val label: String,
    val emoji: String,
    val description: String = ""
)

@OptIn(ExperimentalSharedTransitionApi::class, ExperimentalMaterial3Api::class)
@Composable
fun HomeScreen(
    onNavigateToVenue: (String) -> Unit,
    onNavigateToSearch: (String?) -> Unit,
    onNavigateToEvents: () -> Unit,
    onNavigateToCourses: () -> Unit,
    onNavigateToNotifications: () -> Unit,
    onNavigateToInstitutes: () -> Unit = {},
    onNavigateToQrScanner: () -> Unit = {},
    onNavigateToLogin: () -> Unit = {},
    onNavigateToProfile: () -> Unit = {},
    onNavigateToMap: () -> Unit = {},
    onNavigateToSaved: (() -> Unit)? = null,
    onNavigateToPlaceDiscovery: () -> Unit = {},
    initialSelectedSection: MainHomeSection? = null,
    sharedTransitionScope: SharedTransitionScope? = null,
    animatedVisibilityScope: AnimatedVisibilityScope? = null
) {
    val context = LocalContext.current
    val venues by BookMySpaceRepository.venues.collectAsState()
    val favoriteVenueIds by BookMySpaceRepository.favoriteVenueIds.collectAsState()
    val savedCount = remember(venues, favoriteVenueIds) {
        venues.count { it.isSaved || favoriteVenueIds.contains(it.id) }
    }
    val institutes by BookMySpaceRepository.institutes.collectAsState()
    val instituteClasses by BookMySpaceRepository.instituteClasses.collectAsState()
    val user by BookMySpaceRepository.authUser.collectAsState()
    val notifications by BookMySpaceRepository.notifications.collectAsState()
    val unreadNotifs by remember(notifications) {
        derivedStateOf { notifications.count { !it.isRead } }
    }

    val userLocationHierarchy by BookMySpaceRepository.userLocationHierarchy.collectAsState()
    val userLocationRadius by BookMySpaceRepository.userLocationRadius.collectAsState()
    val appSections by BookMySpaceRepository.appSections.collectAsState()
    val syncState by NetworkRetryManager.syncState.collectAsState()

    // Display ONLY the enabled 4 main section cards (governed by Admin feature toggles)
    val availableSections = remember(appSections) {
        MainHomeSection.values().filter { section ->
            BookMySpaceRepository.isSectionEnabled(section.adminSectionKey)
        }
    }

    // Main section navigation state (null = All Spaces)
    var selectedMainSection by remember { mutableStateOf<MainHomeSection?>(initialSelectedSection) }
    var selectedCategorySlug by remember { mutableStateOf("all") }
    var isRefreshing by remember { mutableStateOf(false) }

    var searchQuery by remember { mutableStateOf("") }
    var checkInDate by remember { mutableStateOf("Today") }
    var checkOutDate by remember { mutableStateOf<String?>("Tomorrow") }
    var guestCount by remember { mutableIntStateOf(2) }
    var roomCount by remember { mutableIntStateOf(1) }
    var childrenCount by remember { mutableIntStateOf(0) }
    var showDatePickerDialog by remember { mutableStateOf(false) }
    var datePickerTarget by remember { mutableStateOf("checkIn") }
    var showGuestPickerDialog by remember { mutableStateOf(false) }
    var selectedSortOption by remember { mutableStateOf(HomeScreenSortOption.DISTANCE) }
    var showSortDropdown by remember { mutableStateOf(false) }

    val categoryType = remember(selectedMainSection) {
        when (selectedMainSection) {
            MainHomeSection.LODGE_ROOMS -> "HOTEL"
            MainHomeSection.FUNCTION_HALLS -> "VENUE"
            MainHomeSection.PG_HOSTELS -> "PG"
            MainHomeSection.INSTITUTES_CLASSES -> "CLASS"
            null -> "ALL"
        }
    }

    val guestInfoText = remember(categoryType, guestCount, childrenCount, roomCount) {
        when (categoryType) {
            "HOTEL" -> "$guestCount Guests, $roomCount Room"
            "VENUE" -> "$guestCount Guests"
            "PG" -> if (guestCount == 1) "Single Share" else "$guestCount-Sharing"
            "CLASS" -> "$guestCount Attendees"
            else -> "$guestCount Guests"
        }
    }

    var isSimulatingLoading by remember { mutableStateOf(false) }
    val coroutineScope = rememberCoroutineScope()

    var showLocationDialog by remember { mutableStateOf(false) }
    var showEasyVoiceBookingDialog by remember { mutableStateOf(false) }
    var showLanguageDialog by remember { mutableStateOf(false) }
    var showAddCustomCategoryDialog by remember { mutableStateOf(false) }
    var customCategoryTargetSection by remember { mutableStateOf<String?>("general") }

    // Subcategory Horizontal Strip Scroll & Snap State
    val subcategoryRowState = rememberLazyListState()
    val subcategorySnapFlingBehavior = rememberSnapFlingBehavior(lazyListState = subcategoryRowState)

    // Smoothly snap active category into focus when selection changes
    LaunchedEffect(selectedCategorySlug, selectedMainSection) {
        try {
            if (selectedCategorySlug == "all") {
                subcategoryRowState.animateScrollToItem(0)
            } else if (selectedMainSection != null) {
                val baseCats = selectedMainSection!!.categoryOptions.filter { cat ->
                    cat.id == "all" || BookMySpaceRepository.isCategoryEnabled(cat.id)
                }
                val baseIdx = baseCats.indexOfFirst { it.id == selectedCategorySlug }
                if (baseIdx >= 0) {
                    subcategoryRowState.animateScrollToItem(1 + baseIdx)
                } else {
                    val customCats = BookMySpaceRepository.getCustomCategoriesForSection(selectedMainSection?.id ?: "")
                    val customIdx = customCats.indexOfFirst { it.slug == selectedCategorySlug }
                    if (customIdx >= 0) {
                        subcategoryRowState.animateScrollToItem(1 + baseCats.size + customIdx)
                    }
                }
            }
        } catch (_: Exception) {
            // safely ignore
        }
    }

    // Amenity and Advanced Filters State
    var selectedAmenityFilters by remember { mutableStateOf(setOf<String>()) }
    var showVenueFilterSheet by remember { mutableStateOf(false) }
    var filterMinPrice by remember { mutableFloatStateOf(0f) }
    var filterMaxPrice by remember { mutableFloatStateOf(500000f) }
    var filterMinRating by remember { mutableFloatStateOf(0f) }

    val homeAmenityFilterOptions = remember {
        listOf(
            AmenityFilterOption("parking", "Parking", "🅿️", listOf("parking", "valet", "car")),
            AmenityFilterOption("wifi", "Wi-Fi", "📶", listOf("wifi", "wi-fi", "internet", "fiber")),
            AmenityFilterOption("changing_rooms", "Changing Rooms", "🚿", listOf("changing", "shower", "washroom", "restroom", "dressing", "locker", "bath")),
            AmenityFilterOption("ac", "Air Conditioned", "❄️", listOf("ac", "air condition", "centralized ac", "cooling")),
            AmenityFilterOption("power_backup", "Power Backup", "⚡", listOf("power backup", "generator", "power", "electricity")),
            AmenityFilterOption("catering", "In-House Food", "🍽️", listOf("cater", "kitchen", "food", "dining", "meal", "buffet", "snack")),
            AmenityFilterOption("stage_sound", "Stage / Sound", "🎤", listOf("stage", "sound", "led", "audio", "mic", "dj")),
            AmenityFilterOption("rooms", "Guest Rooms", "🛏️", listOf("room", "suite", "bridal", "bedroom", "stay")),
            AmenityFilterOption("pool", "Swimming Pool", "🏊", listOf("pool", "swimming")),
            AmenityFilterOption("lockers", "Lockers", "🔒", listOf("locker")),
            AmenityFilterOption("lights", "Floodlights", "💡", listOf("light", "floodlight"))
        )
    }

    // Filter venues for currently selected main section and category
    val filteredVenues = remember(
        venues,
        selectedMainSection,
        selectedCategorySlug,
        searchQuery,
        selectedAmenityFilters,
        filterMinPrice,
        filterMaxPrice,
        filterMinRating,
        userLocationHierarchy
    ) {
        PerformanceTracer.traceSection("FilterHomeScreenVenues", TraceCategory.DATA_FETCH) {
            val list = venues.map { v ->
                val vLat = v.locationHierarchy?.latitude ?: v.latitude
                val vLng = v.locationHierarchy?.longitude ?: v.longitude
                val calculatedDist = if (vLat != 0.0 && vLng != 0.0 && userLocationHierarchy.latitude != 0.0) {
                    IndiaLocationMasterData.calculateDistanceKm(userLocationHierarchy.latitude, userLocationHierarchy.longitude, vLat, vLng)
                } else v.distanceKm

                v.copy(distanceKm = calculatedDist)
            }.filter { v ->
                val slug = v.category?.slug?.lowercase() ?: "venue"
                val name = v.name.lowercase()
                val desc = v.description.lowercase()
                val fac = v.facilities.joinToString(" ") { it.facility.lowercase() }
                val query = searchQuery.trim().lowercase()

                // 0. Matches Search Query
                val matchesQuery = if (query.isBlank()) true else {
                    name.contains(query) || desc.contains(query) || fac.contains(query) ||
                            v.city.lowercase().contains(query) || v.addressLine1.lowercase().contains(query)
                }
                if (!matchesQuery) return@filter false

                // 1. Matches Main Section (if selected)
                val matchesMainSection = when (selectedMainSection) {
                    MainHomeSection.FUNCTION_HALLS -> {
                        slug.contains("function") || slug.contains("banquet") || slug.contains("marriage") ||
                                slug.contains("lawn") || slug.contains("convention") || slug.contains("community") ||
                                slug.contains("hall") || slug.contains("venue") || name.contains("hall") ||
                                name.contains("palace") || name.contains("lawn") || name.contains("convention") ||
                                name.contains("marriage") || name.contains("banquet")
                    }
                    MainHomeSection.LODGE_ROOMS -> {
                        slug.contains("hotel") || slug.contains("room") || slug.contains("lodge") ||
                                slug.contains("stay") || slug.contains("resort") || name.contains("hotel") ||
                                name.contains("lodge") || name.contains("room") || name.contains("stay") ||
                                name.contains("resort") || v.hotelDetails != null
                    }
                    MainHomeSection.PG_HOSTELS -> {
                        slug.contains("pg") || slug.contains("hostel") || slug.contains("co_living") ||
                                name.contains("pg") || name.contains("hostel") || desc.contains("pg") ||
                                desc.contains("hostel") || desc.contains("co-living")
                    }
                    MainHomeSection.INSTITUTES_CLASSES -> {
                        slug.contains("institute") || slug.contains("class") || slug.contains("coaching") ||
                                slug.contains("academy") || slug.contains("dance") || slug.contains("music") ||
                                slug.contains("sports") || slug.contains("badminton") || slug.contains("turf") ||
                                name.contains("academy") || name.contains("institute") || name.contains("coaching") ||
                                name.contains("class") || desc.contains("academy") || desc.contains("classes")
                    }
                    null -> true
                }

                if (!matchesMainSection) return@filter false

                // 2. Matches Sub-category
                val matchesCategory = if (selectedCategorySlug == "all") {
                    true
                } else {
                    when (selectedCategorySlug) {
                        "marriage_hall" -> slug.contains("marriage") || slug == "marriage_hall" || name.contains("marriage") || name.contains("kalyana") || desc.contains("marriage")
                        "convention_center" -> slug.contains("convention") || slug == "convention_center" || name.contains("convention") || desc.contains("convention")
                        "banquet_hall" -> slug.contains("banquet") || slug == "banquet_hall" || name.contains("banquet") || name.contains("party") || desc.contains("banquet")
                        "community_hall" -> slug.contains("community") || slug == "community_hall" || name.contains("community") || desc.contains("community")
                        "govt_hall" -> slug.contains("govt") || slug == "govt_hall" || name.contains("government") || name.contains("town hall") || desc.contains("government")
                        "party_lawn" -> slug.contains("lawn") || slug == "party_lawn" || name.contains("lawn") || desc.contains("lawn") || desc.contains("ground")
                        "hotel", "hotel_stay" -> slug.contains("hotel") || slug == "hotel_stay" || name.contains("hotel") || v.hotelDetails != null
                        "lodge" -> slug.contains("lodge") || slug == "lodge" || name.contains("lodge")
                        "guest_house" -> slug.contains("guest") || slug == "guest_house" || name.contains("guest house") || desc.contains("guest house")
                        "hourly_room" -> slug.contains("room") || slug == "hourly_room" || name.contains("room") || desc.contains("hourly") || desc.contains("day stay")
                        "resort" -> slug.contains("resort") || slug == "resort" || name.contains("resort") || desc.contains("resort")
                        "gents_pg" -> slug.contains("gents") || slug == "gents_pg" || name.contains("gent") || name.contains("men") || desc.contains("gents")
                        "ladies_pg" -> slug.contains("ladies") || slug == "ladies_pg" || name.contains("lad") || name.contains("women") || desc.contains("ladies") || desc.contains("women")
                        "student_hostel" -> slug.contains("student") || slug == "student_hostel" || name.contains("hostel") || desc.contains("student")
                        "co_living" -> slug.contains("co_living") || slug == "co_living" || desc.contains("co-living") || name.contains("living")
                        "single_room" -> slug.contains("single") || slug == "single_room" || desc.contains("single") || desc.contains("sharing")
                        "coaching" -> slug.contains("coaching") || slug == "coaching" || name.contains("coaching") || name.contains("tuition") || desc.contains("coaching") || desc.contains("tuition")
                        "computer_it" -> slug.contains("computer") || slug == "computer_it" || name.contains("computer") || name.contains("code") || name.contains("stem") || desc.contains("python") || desc.contains("coding")
                        "dance_academy" -> slug.contains("dance") || slug == "dance_academy" || name.contains("dance") || desc.contains("dance")
                        "music_class" -> slug.contains("music") || slug == "music_class" || name.contains("music") || desc.contains("music") || name.contains("symphony")
                        "sports_academy" -> slug.contains("sports") || slug == "sports_academy" || name.contains("sports") || name.contains("academy") || name.contains("badminton") || name.contains("turf")
                        "other_hall" -> slug.contains("other_hall") || slug.contains("other") || name.contains("amphitheatre") || name.contains("expo") || name.contains("ground") || desc.contains("open-air") || desc.contains("exhibition") || (!slug.contains("marriage") && !slug.contains("convention") && !slug.contains("banquet"))
                        "other_stay" -> slug.contains("other_stay") || slug.contains("other") || name.contains("glamping") || name.contains("farmhouse") || name.contains("cottage") || desc.contains("glamping") || desc.contains("farmhouse") || desc.contains("chalet")
                        "other_pg" -> slug.contains("other_pg") || slug.contains("other") || name.contains("nomad") || name.contains("cohousing") || name.contains("loft") || desc.contains("cohousing") || desc.contains("loft")
                        "other_class" -> slug.contains("other_class") || slug.contains("other") || name.contains("pottery") || name.contains("yoga") || name.contains("art") || desc.contains("pottery") || desc.contains("mindfulness")
                        else -> slug.contains(selectedCategorySlug) || name.contains(selectedCategorySlug) || desc.contains(selectedCategorySlug)
                    }
                }

                // 3. Matches Amenities
                val matchesAmenities = if (selectedAmenityFilters.isEmpty()) {
                    true
                } else {
                    selectedAmenityFilters.all { amenityId ->
                        val option = homeAmenityFilterOptions.find { it.id == amenityId }
                        if (option == null) true
                        else {
                            val facList = v.facilities.map { it.facility.lowercase() }
                            val food = v.foodOptions.lowercase()
                            val rules = v.rules.lowercase()
                            val combinedFacilitiesText = "$desc $food $rules $name " + facList.joinToString(" ")
                            val hasParking = (amenityId == "parking" && (v.parkingCapacity > 0 || combinedFacilitiesText.contains("parking") || combinedFacilitiesText.contains("valet")))
                            val hasRooms = (amenityId == "rooms" && (v.hotelDetails != null || v.facilities.any { it.facility.contains("Room", ignoreCase = true) || it.facility.contains("Suite", ignoreCase = true) }))

                            hasParking || hasRooms || option.keywords.any { kw ->
                                v.facilities.any { f -> f.facility.contains(kw, ignoreCase = true) && f.isAvailable } ||
                                combinedFacilitiesText.contains(kw)
                            }
                        }
                    }
                }

                // 4. Matches Price and Rating
                val matchesPrice = v.pricingBaseAmount in filterMinPrice..filterMaxPrice
                val matchesRating = filterMinRating == 0f || v.avgRating >= filterMinRating

                matchesCategory && matchesAmenities && matchesPrice && matchesRating
            }

            list
        }
    }

    // Sorted Venues based on user selected sorting
    val sortedVenues = remember(filteredVenues, selectedSortOption, userLocationHierarchy) {
        when (selectedSortOption) {
            HomeScreenSortOption.DISTANCE -> {
                filteredVenues.sortedWith(
                    compareBy<Venue> { v ->
                        val isExactArea = userLocationHierarchy.areaId != null && v.locationHierarchy?.areaId == userLocationHierarchy.areaId
                        val isSameCity = v.locationHierarchy?.cityTownId == userLocationHierarchy.cityTownId || v.city.equals(userLocationHierarchy.cityTownName, ignoreCase = true)
                        val isSameDistrict = v.locationHierarchy?.districtId == userLocationHierarchy.districtId
                        val isSameState = v.locationHierarchy?.stateId == userLocationHierarchy.stateId

                        when {
                            isExactArea -> 0
                            isSameCity -> 1
                            isSameDistrict -> 2
                            isSameState -> 3
                            else -> 4
                        }
                    }.thenBy { it.distanceKm }
                )
            }
            HomeScreenSortOption.RECOMMENDED -> {
                filteredVenues.sortedWith(
                    compareByDescending<Venue> { it.avgRating * (it.ratingCount + 1) }.thenBy { it.distanceKm }
                )
            }
            HomeScreenSortOption.PRICE_LOW -> filteredVenues.sortedBy { it.pricingBaseAmount }
            HomeScreenSortOption.PRICE_HIGH -> filteredVenues.sortedByDescending { it.pricingBaseAmount }
            HomeScreenSortOption.RATING -> filteredVenues.sortedByDescending { it.avgRating }
        }
    }

    // Seamless Recommendations to Eliminate Dead Space
    val remainingOtherStays = remember(sortedVenues, venues, selectedMainSection) {
        val currentIds = sortedVenues.map { it.id }.toSet()
        venues.filter { v ->
            !currentIds.contains(v.id) && (
                selectedMainSection == null ||
                when (selectedMainSection) {
                    MainHomeSection.LODGE_ROOMS -> v.hotelDetails != null || v.category?.slug in listOf("hotel", "hotel_stay", "lodge", "guest_house", "hourly_room", "resort", "other_stay")
                    MainHomeSection.FUNCTION_HALLS -> v.capacity >= 100 || v.category?.slug in listOf("marriage_hall", "convention_center", "banquet_hall", "party_lawn", "community_hall")
                    MainHomeSection.PG_HOSTELS -> v.pgDetails != null || v.category?.slug in listOf("gents_pg", "ladies_pg", "student_hostel", "co_living", "single_room")
                    MainHomeSection.INSTITUTES_CLASSES -> v.category?.slug in listOf("coaching", "computer_it", "dance_academy", "music_class", "sports_academy")
                    else -> true
                }
            )
        }.take(4)
    }

    if (showDatePickerDialog) {
        SimpleQuickDateDialog(
            title = if (datePickerTarget == "checkIn") "Select Start / Check-in Date" else "Select Check-out Date",
            currentDate = if (datePickerTarget == "checkIn") checkInDate else (checkOutDate ?: "Add Date"),
            onDismiss = { showDatePickerDialog = false },
            onDateSelected = { picked ->
                if (datePickerTarget == "checkIn") {
                    checkInDate = picked
                } else {
                    checkOutDate = picked
                }
                showDatePickerDialog = false
            }
        )
    }

    if (showGuestPickerDialog) {
        GuestAndRoomPickerDialog(
            adults = guestCount,
            children = childrenCount,
            rooms = roomCount,
            categoryType = categoryType,
            onDismiss = { showGuestPickerDialog = false },
            onApply = { a, c, r ->
                guestCount = a
                childrenCount = c
                roomCount = r
                showGuestPickerDialog = false
            }
        )
    }

    if (showLocationDialog) {
        LocationHierarchySelectorDialog(
            currentLocation = userLocationHierarchy,
            currentRadius = userLocationRadius,
            onLocationSelected = { loc, radius ->
                BookMySpaceRepository.setUserLocationHierarchy(loc, radius)
                showLocationDialog = false
            },
            onDismiss = { showLocationDialog = false },
            onOpenPlaceDiscovery = onNavigateToPlaceDiscovery
        )
    }

    if (showEasyVoiceBookingDialog) {
        EasyVoiceBookingDialog(
            onDismiss = { showEasyVoiceBookingDialog = false },
            onNavigateToVenue = onNavigateToVenue
        )
    }

    if (showLanguageDialog) {
        LanguageSelectorDialog(
            onDismiss = { showLanguageDialog = false }
        )
    }

    if (showAddCustomCategoryDialog) {
        AddCustomCategoryDialog(
            initialSectionId = customCategoryTargetSection,
            onDismiss = { showAddCustomCategoryDialog = false },
            onCategoryCreated = { newCategory ->
                if (selectedMainSection != null) {
                    selectedCategorySlug = newCategory.slug
                } else {
                    val matchingSection = availableSections.find { it.id == newCategory.parentSection }
                    if (matchingSection != null) {
                        selectedMainSection = matchingSection
                        selectedCategorySlug = newCategory.slug
                    } else {
                        selectedCategorySlug = newCategory.slug
                    }
                }
            }
        )
    }

    if (showVenueFilterSheet) {
        VenueFilterBottomSheet(
            initialMinPrice = filterMinPrice,
            initialMaxPrice = filterMaxPrice,
            initialMinRating = filterMinRating,
            initialSelectedAmenities = selectedAmenityFilters,
            maxPriceLimit = 250000f,
            matchingVenuesCount = filteredVenues.size,
            onDismissRequest = { showVenueFilterSheet = false },
            onApplyFilters = { minP, maxP, minR, amenities ->
                filterMinPrice = minP
                filterMaxPrice = maxP
                filterMinRating = minR
                selectedAmenityFilters = amenities
                showVenueFilterSheet = false
            },
            onResetFilters = {
                filterMinPrice = 0f
                filterMaxPrice = 500000f
                filterMinRating = 0f
                selectedAmenityFilters = emptySet()
                showVenueFilterSheet = false
            }
        )
    }

    ResponsiveLayout(
        modifier = Modifier.testTag("home_responsive_container")
    ) { responsiveInfo ->
        PullToRefreshBox(
            isRefreshing = isRefreshing,
            onRefresh = {
                coroutineScope.launch {
                    isRefreshing = true
                    try {
                        // 1. Reset horizontal category state
                        selectedCategorySlug = "all"
                        selectedAmenityFilters = emptySet()
                        filterMinPrice = 0f
                        filterMaxPrice = 500000f
                        filterMinRating = 0f
                        searchQuery = ""
                        try {
                            subcategoryRowState.scrollToItem(0)
                        } catch (_: Exception) {}

                        // 2. Fetch fresh data & availability from repository & cloud Firestore
                        BookMySpaceRepository.refreshAllData()
                        delay(650L)
                    } catch (_: Exception) {
                    } finally {
                        isRefreshing = false
                    }
                }
            },
            modifier = Modifier
                .fillMaxSize()
                .testTag("home_pull_to_refresh")
        ) {
            LazyColumn(
                modifier = Modifier
                    .fillMaxSize()
                    .testTag("home_screen"),
                contentPadding = PaddingValues(bottom = 32.dp)
            ) {
            // =====================================================================
            // TOP APP BAR (Shared across First Screen & Section Views)
            // =====================================================================
            item {
                Column(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(horizontal = responsiveInfo.horizontalPadding, vertical = 12.dp)
                ) {
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.SpaceBetween,
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        BookMySpaceLogo()

                        Row(
                            verticalAlignment = Alignment.CenterVertically,
                            horizontalArrangement = Arrangement.spacedBy(8.dp)
                        ) {
                            LanguageSelectorChip(onClick = { showLanguageDialog = true })

                            if (user == null) {
                                FilledTonalButton(
                                    onClick = onNavigateToLogin,
                                    contentPadding = PaddingValues(horizontal = 12.dp, vertical = 6.dp),
                                    shape = RoundedCornerShape(20.dp),
                                    modifier = Modifier
                                        .defaultMinSize(minHeight = 48.dp)
                                        .testTag("header_login_button")
                                ) {
                                    Icon(Icons.Default.Login, contentDescription = null, modifier = Modifier.size(16.dp))
                                    Spacer(modifier = Modifier.width(6.dp))
                                    Text("Sign In", fontSize = 13.sp, fontWeight = FontWeight.Bold)
                                }
                            } else {
                                Surface(
                                    onClick = onNavigateToProfile,
                                    shape = CircleShape,
                                    color = MaterialTheme.colorScheme.primaryContainer,
                                    modifier = Modifier
                                        .size(48.dp)
                                        .testTag("header_user_avatar")
                                ) {
                                    Box(contentAlignment = Alignment.Center) {
                                        Text(
                                            text = user?.fullName?.take(1)?.uppercase() ?: "U",
                                            fontWeight = FontWeight.Bold,
                                            color = MaterialTheme.colorScheme.onPrimaryContainer,
                                            fontSize = 16.sp
                                        )
                                    }
                                }
                            }

                            IconButton(
                                onClick = {
                                    coroutineScope.launch {
                                        isSimulatingLoading = true
                                        delay(1200)
                                        isSimulatingLoading = false
                                    }
                                },
                                modifier = Modifier
                                    .size(48.dp)
                                    .clip(CircleShape)
                                    .background(MaterialTheme.colorScheme.surfaceVariant)
                                    .testTag("home_topbar_refresh_widgets_btn")
                            ) {
                                Icon(
                                    imageVector = Icons.Default.AutoAwesome,
                                    contentDescription = "Refresh Live Widgets",
                                    tint = MaterialTheme.colorScheme.primary,
                                    modifier = Modifier.size(20.dp)
                                )
                            }

                            IconButton(
                                onClick = onNavigateToQrScanner,
                                modifier = Modifier
                                    .size(48.dp)
                                    .clip(CircleShape)
                                    .background(MaterialTheme.colorScheme.surfaceVariant)
                                    .testTag("home_topbar_qr_scanner_btn")
                            ) {
                                Icon(
                                    imageVector = Icons.Default.QrCodeScanner,
                                    contentDescription = "QR Check-In",
                                    tint = MaterialTheme.colorScheme.primary,
                                    modifier = Modifier.size(22.dp)
                                )
                            }

                            if (onNavigateToSaved != null) {
                                BadgedBox(
                                    badge = {
                                        if (savedCount > 0) {
                                            Badge { Text("$savedCount") }
                                        }
                                    }
                                ) {
                                    IconButton(
                                        onClick = onNavigateToSaved,
                                        modifier = Modifier
                                            .size(48.dp)
                                            .clip(CircleShape)
                                            .background(MaterialTheme.colorScheme.surfaceVariant)
                                            .testTag("home_topbar_favorites_btn")
                                    ) {
                                        Icon(
                                            imageVector = Icons.Default.Bookmark,
                                            contentDescription = "Favorites",
                                            tint = MaterialTheme.colorScheme.primary,
                                            modifier = Modifier.size(22.dp)
                                        )
                                    }
                                }
                            }

                            BadgedBox(
                                badge = {
                                    if (unreadNotifs > 0) {
                                        Badge { Text("$unreadNotifs") }
                                    }
                                }
                            ) {
                                IconButton(
                                    onClick = onNavigateToNotifications,
                                    modifier = Modifier
                                        .size(48.dp)
                                        .clip(CircleShape)
                                        .background(MaterialTheme.colorScheme.surfaceVariant)
                                        .testTag("home_topbar_notifications_btn")
                                ) {
                                    Icon(
                                        imageVector = Icons.Default.Notifications,
                                        contentDescription = "Notifications",
                                        tint = MaterialTheme.colorScheme.onSurfaceVariant,
                                        modifier = Modifier.size(22.dp)
                                    )
                                }
                            }
                        }
                    }

                    // Network Sync Status Banner (Active sync, error, or retry alert)
                    NetworkSyncStatusBanner(
                        syncState = syncState,
                        onRetry = {
                            coroutineScope.launch {
                                NetworkRetryManager.triggerRetry()
                            }
                        },
                        modifier = Modifier.padding(top = 4.dp)
                    )
                }
            }

            // =====================================================================
            // 🌟 FIRST SCREEN: 4 MAIN SECTIONS + ENGAGING WIDGETS
            // =====================================================================
            if (selectedMainSection == null) {
                // 1. Location Bar
                item {
                    LocationHierarchyHeaderBar(
                        currentLocation = userLocationHierarchy,
                        selectedRadius = userLocationRadius,
                        onClick = { showLocationDialog = true },
                        modifier = Modifier.padding(horizontal = responsiveInfo.horizontalPadding)
                    )
                }

                // 2. Voice Booking Banner
                item {
                    Spacer(modifier = Modifier.height(10.dp))
                    EasyVoiceBookingBanner(
                        onClick = { showEasyVoiceBookingDialog = true },
                        modifier = Modifier.padding(horizontal = responsiveInfo.horizontalPadding)
                    )
                }

                // 3. Live Activity Pulse Ticker
                item {
                    Spacer(modifier = Modifier.height(10.dp))
                    LiveActivityPulseTicker(
                        modifier = Modifier.padding(horizontal = responsiveInfo.horizontalPadding)
                    )
                }

                // 4. Hot Deals Carousel Widget
                item {
                    Spacer(modifier = Modifier.height(12.dp))
                    HotDealsCarouselWidget(
                        onSelectDeal = { deal ->
                            val matchingSection = availableSections.find { it.id == deal.targetSection }
                            if (matchingSection != null) {
                                selectedMainSection = matchingSection
                                selectedCategorySlug = "all"
                            }
                        },
                        modifier = Modifier.padding(horizontal = responsiveInfo.horizontalPadding)
                    )
                }

                // 5. Smart Space Radar
                item {
                    Spacer(modifier = Modifier.height(12.dp))
                    SmartSpaceRadarWidget(
                        location = userLocationHierarchy,
                        availableSpacesCount = venues.size,
                        onQuickSearchCategory = { catSlug ->
                            val matchingSection = availableSections.find { s ->
                                s.categoryOptions.any { it.id == catSlug }
                            }
                            if (matchingSection != null) {
                                selectedMainSection = matchingSection
                                selectedCategorySlug = catSlug
                            }
                        },
                        modifier = Modifier.padding(horizontal = responsiveInfo.horizontalPadding)
                    )
                }

                // 6. Section Header & Slow Continuous Right-to-Left Sections Marquee
                item {
                    Spacer(modifier = Modifier.height(16.dp))
                    Column(modifier = Modifier.padding(horizontal = responsiveInfo.horizontalPadding)) {
                        Row(
                            modifier = Modifier.fillMaxWidth(),
                            horizontalArrangement = Arrangement.SpaceBetween,
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            Column {
                                Text(
                                    text = "Available Sections & Categories",
                                    fontSize = 18.sp,
                                    fontWeight = FontWeight.Black,
                                    color = MaterialTheme.colorScheme.onBackground,
                                    letterSpacing = (-0.3).sp
                                )
                                Text(
                                    text = "Explore verified spaces or easily add any custom category",
                                    fontSize = 12.5.sp,
                                    color = MaterialTheme.colorScheme.onSurfaceVariant
                                )
                            }
                        }
                    }
                    Spacer(modifier = Modifier.height(10.dp))

                    // Slow smooth right-to-left scrolling available sections marquee
                    AvailableSectionsSlowMarqueeStrip(
                        onSelectSection = { sectionId ->
                            if (sectionId == "institutes_classes" || sectionId == "institutes") {
                                onNavigateToInstitutes()
                            } else {
                                val matchingSection = availableSections.find { it.id == sectionId }
                                if (matchingSection != null) {
                                    if (matchingSection == MainHomeSection.INSTITUTES_CLASSES) {
                                        onNavigateToInstitutes()
                                    } else {
                                        selectedMainSection = matchingSection
                                        selectedCategorySlug = "all"
                                    }
                                }
                            }
                        },
                        onAddOtherCategory = {
                            customCategoryTargetSection = "general"
                            showAddCustomCategoryDialog = true
                        }
                    )
                }

                // 7. 4 Main Section Big Hero Cards
                if (isSimulatingLoading) {
                    item {
                        EyeCatchingCategoryChipsSkeleton(
                            modifier = Modifier.padding(horizontal = responsiveInfo.horizontalPadding)
                        )
                    }
                } else {
                    responsiveGridItems(
                        items = availableSections,
                        columns = responsiveInfo.categoryGridColumns,
                        key = { it.id },
                        horizontalSpacing = responsiveInfo.gridSpacing,
                        verticalSpacing = 12.dp,
                        contentPadding = PaddingValues(horizontal = responsiveInfo.horizontalPadding)
                    ) { section, _ ->
                        MainSectionBigHeroCard(
                            section = section,
                            onClick = {
                                if (section == MainHomeSection.INSTITUTES_CLASSES) {
                                    onNavigateToInstitutes()
                                } else {
                                    selectedMainSection = section
                                    selectedCategorySlug = "all"
                                }
                            },
                            isTabletOrWide = responsiveInfo.isTabletOrWide,
                            modifier = Modifier.fillMaxWidth()
                        )
                    }
                }

                // 8. Auto-Moving Category Strip (Silky smooth right-to-left ticker)
                item {
                    Spacer(modifier = Modifier.height(18.dp))
                    SmoothAutoMovingCategoryStrip(
                        onSelectCategory = { targetSection, categorySlug ->
                            if (targetSection == "institutes_classes" || targetSection == "institutes") {
                                onNavigateToInstitutes()
                            } else {
                                val matchingSection = availableSections.find { it.id == targetSection }
                                if (matchingSection != null) {
                                    if (matchingSection == MainHomeSection.INSTITUTES_CLASSES) {
                                        onNavigateToInstitutes()
                                    } else {
                                        selectedMainSection = matchingSection
                                        selectedCategorySlug = categorySlug
                                    }
                                } else {
                                    selectedMainSection = availableSections.firstOrNull()
                                    selectedCategorySlug = categorySlug
                                }
                            }
                        },
                        onAddOtherCategory = {
                            customCategoryTargetSection = "general"
                            showAddCustomCategoryDialog = true
                        }
                    )
                }

                // 9. Daily Lucky Reward Widget
                item {
                    Spacer(modifier = Modifier.height(14.dp))
                    DailyLuckyRewardWidget(
                        modifier = Modifier.padding(horizontal = responsiveInfo.horizontalPadding)
                    )
                }

                // 10. Smart Weather Insights Widget
                item {
                    Spacer(modifier = Modifier.height(14.dp))
                    SmartWeatherSpaceInsightsWidget(
                        location = userLocationHierarchy,
                        modifier = Modifier.padding(horizontal = responsiveInfo.horizontalPadding)
                    )
                }
            } else {
                // =====================================================================
                // 🌟 SECTION VIEW: HIGH-CONVERTING DISCOVERY & BOOKING UI
                // =====================================================================
                // 1. Section Title & Quick Navigation Header
                item {
                    Surface(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(horizontal = responsiveInfo.horizontalPadding, vertical = 6.dp),
                        shape = RoundedCornerShape(20.dp),
                        color = MaterialTheme.colorScheme.primaryContainer.copy(alpha = 0.45f),
                        border = BorderStroke(1.dp, MaterialTheme.colorScheme.primary.copy(alpha = 0.2f))
                    ) {
                        Row(
                            modifier = Modifier
                                .fillMaxWidth()
                                .padding(horizontal = 14.dp, vertical = 12.dp),
                            verticalAlignment = Alignment.CenterVertically,
                            horizontalArrangement = Arrangement.SpaceBetween
                        ) {
                            Row(
                                verticalAlignment = Alignment.CenterVertically,
                                modifier = Modifier.weight(1f)
                            ) {
                                IconButton(
                                    onClick = {
                                        selectedMainSection = null
                                        selectedCategorySlug = "all"
                                        searchQuery = ""
                                    },
                                    modifier = Modifier
                                        .size(40.dp)
                                        .clip(CircleShape)
                                        .background(MaterialTheme.colorScheme.surface)
                                        .testTag("section_back_button")
                                ) {
                                    Icon(
                                        imageVector = Icons.AutoMirrored.Filled.ArrowBack,
                                        contentDescription = "Back to all sections",
                                        tint = MaterialTheme.colorScheme.primary,
                                        modifier = Modifier.size(20.dp)
                                    )
                                }

                                Spacer(modifier = Modifier.width(12.dp))

                                Column {
                                    Row(verticalAlignment = Alignment.CenterVertically) {
                                        Text(selectedMainSection?.emoji ?: "🏨", fontSize = 18.sp)
                                        Spacer(modifier = Modifier.width(6.dp))
                                        Text(
                                            text = selectedMainSection?.title ?: "Hotels & Stays",
                                            fontWeight = FontWeight.Black,
                                            fontSize = 17.sp,
                                            color = MaterialTheme.colorScheme.onSurface
                                        )
                                    }
                                    Text(
                                        text = selectedMainSection?.subtitle ?: "Verified stays with instant slot confirmation",
                                        fontSize = 11.5.sp,
                                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                                        maxLines = 1,
                                        overflow = TextOverflow.Ellipsis
                                    )
                                }
                            }

                            FilledTonalButton(
                                onClick = {
                                    selectedMainSection = null
                                    selectedCategorySlug = "all"
                                    searchQuery = ""
                                },
                                shape = RoundedCornerShape(12.dp),
                                contentPadding = PaddingValues(horizontal = 10.dp, vertical = 4.dp),
                                modifier = Modifier.defaultMinSize(minHeight = 36.dp)
                            ) {
                                Text("All Categories", fontSize = 12.sp, fontWeight = FontWeight.Bold)
                            }
                        }
                    }
                }

                // 2. Compact Adaptive Search Header (Automatically adapts to Hotels / Function Halls / PGs / Classes)
                item {
                    Spacer(modifier = Modifier.height(4.dp))
                    val sectionCategoryType = when (selectedMainSection?.id) {
                        "hotels" -> "HOTEL"
                        "venues" -> "VENUE"
                        "pg" -> "PG"
                        "institutes" -> "CLASS"
                        else -> "HOTEL"
                    }
                    Box(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(horizontal = responsiveInfo.horizontalPadding)
                    ) {
                        CompactAdaptiveSearchHeader(
                            searchQuery = searchQuery,
                            onSearchQueryChange = { searchQuery = it },
                            categoryType = sectionCategoryType,
                            locationText = userLocationHierarchy.shortLabel,
                            onLocationClick = { showLocationDialog = true },
                            checkInDate = checkInDate,
                            checkOutDate = checkOutDate,
                            onPickCheckInDate = {
                                datePickerTarget = "checkIn"
                                showDatePickerDialog = true
                            },
                            onPickCheckOutDate = {
                                datePickerTarget = "checkOut"
                                showDatePickerDialog = true
                            },
                            guestInfoText = guestInfoText,
                            onPickGuestInfo = { showGuestPickerDialog = true },
                            onSearchClick = { /* Instant search query is reactive */ },
                            onVoiceClick = { showEasyVoiceBookingDialog = true }
                        )
                    }
                }

                // 3. Category Strip (Horizontal selector pills for instant switching with scroll-snap and tactile pulse/pop)
                item {
                    Spacer(modifier = Modifier.height(8.dp))
                    LazyRow(
                        state = subcategoryRowState,
                        flingBehavior = subcategorySnapFlingBehavior,
                        contentPadding = PaddingValues(horizontal = responsiveInfo.horizontalPadding),
                        horizontalArrangement = Arrangement.spacedBy(8.dp),
                        modifier = Modifier
                            .fillMaxWidth()
                            .testTag("section_subcategories_row")
                    ) {
                        // "All" pill for this section
                        item {
                            PulsePopCategoryPill(
                                selected = selectedCategorySlug == "all",
                                onClick = { selectedCategorySlug = "all" },
                                emoji = "✨",
                                label = "All ${selectedMainSection?.title ?: "Spaces"}",
                                testTag = "category_pill_all"
                            )
                        }

                        // Sub-categories for this section (filtered by independent modular ON/OFF status)
                        if (selectedMainSection != null && selectedMainSection!!.categoryOptions.isNotEmpty()) {
                            val activeCategoryOptions = selectedMainSection!!.categoryOptions.filter { cat ->
                                cat.id == "all" || BookMySpaceRepository.isCategoryEnabled(cat.id)
                            }
                            items(activeCategoryOptions, key = { it.id }) { cat ->
                                val isSelected = selectedCategorySlug == cat.id
                                PulsePopCategoryPill(
                                    selected = isSelected,
                                    onClick = { selectedCategorySlug = cat.id },
                                    emoji = cat.emoji,
                                    label = cat.label,
                                    testTag = "category_pill_${cat.id}"
                                )
                            }
                        }

                        // Dynamically added custom categories for this section
                        val customCategories = BookMySpaceRepository.getCustomCategoriesForSection(selectedMainSection?.id ?: "")
                        items(customCategories, key = { "custom_${it.id}" }) { customCat ->
                            val isSelected = selectedCategorySlug == customCat.slug
                            PulsePopCategoryPill(
                                selected = isSelected,
                                onClick = { selectedCategorySlug = customCat.slug },
                                emoji = customCat.customEmoji ?: customCat.icon,
                                label = customCat.name,
                                badge = "NEW",
                                testTag = "category_pill_custom_${customCat.id}"
                            )
                        }

                        // "+ Other Category / Add Category" chip for adding custom category easily
                        item {
                            PulsePopCategoryPill(
                                selected = false,
                                onClick = {
                                    customCategoryTargetSection = selectedMainSection?.id ?: "general"
                                    showAddCustomCategoryDialog = true
                                },
                                iconVector = Icons.Default.Add,
                                label = "+ Other Category",
                                isSpecialAddPill = true,
                                testTag = "section_add_other_category_chip"
                            )
                        }

                        // Other main sections for quick 1-tap switching
                        items(availableSections.filter { it.id != selectedMainSection?.id }, key = { "other_${it.id}" }) { otherSec ->
                            PulsePopCategoryPill(
                                selected = false,
                                onClick = {
                                    selectedMainSection = otherSec
                                    selectedCategorySlug = "all"
                                },
                                emoji = otherSec.emoji,
                                label = otherSec.title,
                                testTag = "category_pill_switch_${otherSec.id}"
                            )
                        }
                    }
                }

                // 4. Quick Filter Bar (Active Filters Count, Price Cap, Rating 4.0+, Popular Amenities)
                item {
                    Spacer(modifier = Modifier.height(8.dp))
                    LazyRow(
                        contentPadding = PaddingValues(horizontal = responsiveInfo.horizontalPadding),
                        horizontalArrangement = Arrangement.spacedBy(8.dp),
                        modifier = Modifier
                            .fillMaxWidth()
                            .testTag("section_quick_filter_bar")
                    ) {
                        // Filters Sheet Trigger Chip with Badge
                        item {
                            val activeFilterCount = selectedAmenityFilters.size + (if (filterMinRating > 0f) 1 else 0) + (if (filterMaxPrice < 500000f) 1 else 0)
                            FilterChip(
                                selected = activeFilterCount > 0,
                                onClick = { showVenueFilterSheet = true },
                                label = {
                                    Row(verticalAlignment = Alignment.CenterVertically) {
                                        Icon(
                                            imageVector = Icons.Default.Tune,
                                            contentDescription = "Filters",
                                            modifier = Modifier.size(15.dp)
                                        )
                                        Spacer(modifier = Modifier.width(5.dp))
                                        Text(
                                            text = if (activeFilterCount > 0) "Filters ($activeFilterCount)" else "Filters",
                                            fontSize = 12.5.sp,
                                            fontWeight = FontWeight.SemiBold
                                        )
                                    }
                                },
                                shape = RoundedCornerShape(14.dp),
                                modifier = Modifier.defaultMinSize(minHeight = 36.dp)
                            )
                        }

                        // Price Filter Chip (e.g. ≤ ₹50,000)
                        item {
                            val isPriceFiltered = filterMaxPrice < 500000f
                            FilterChip(
                                selected = isPriceFiltered,
                                onClick = {
                                    filterMaxPrice = if (isPriceFiltered) 500000f else 50000f
                                },
                                label = {
                                    Text(
                                        text = if (isPriceFiltered) "≤ ₹${filterMaxPrice.toInt()}" else "💰 ≤ ₹50,000",
                                        fontSize = 12.5.sp
                                    )
                                },
                                shape = RoundedCornerShape(14.dp),
                                modifier = Modifier.defaultMinSize(minHeight = 36.dp)
                            )
                        }

                        // 4.0+ Rating Chip
                        item {
                            val isRating4 = filterMinRating >= 4.0f
                            FilterChip(
                                selected = isRating4,
                                onClick = {
                                    filterMinRating = if (isRating4) 0f else 4.0f
                                },
                                label = {
                                    Row(verticalAlignment = Alignment.CenterVertically) {
                                        Text("⭐", fontSize = 12.sp)
                                        Spacer(modifier = Modifier.width(4.dp))
                                        Text("4.0+", fontSize = 12.5.sp)
                                    }
                                },
                                shape = RoundedCornerShape(14.dp),
                                modifier = Modifier.defaultMinSize(minHeight = 36.dp)
                            )
                        }

                        // Popular Amenities Chips (Wi-Fi, AC, Parking, Swimming Pool, Power Backup)
                        items(homeAmenityFilterOptions.take(4), key = { it.id }) { option ->
                            val isSelected = selectedAmenityFilters.contains(option.id)
                            FilterChip(
                                selected = isSelected,
                                onClick = {
                                    selectedAmenityFilters = if (isSelected) {
                                        selectedAmenityFilters - option.id
                                    } else {
                                        selectedAmenityFilters + option.id
                                    }
                                },
                                label = {
                                    Row(verticalAlignment = Alignment.CenterVertically) {
                                        Text(option.iconEmoji, fontSize = 12.sp)
                                        Spacer(modifier = Modifier.width(4.dp))
                                        Text(option.label, fontSize = 12.5.sp)
                                    }
                                },
                                shape = RoundedCornerShape(14.dp),
                                modifier = Modifier.defaultMinSize(minHeight = 36.dp)
                            )
                        }
                    }
                }

                // 5. Interactive Sort Bar & Results Count
                item {
                    Spacer(modifier = Modifier.height(10.dp))
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(horizontal = responsiveInfo.horizontalPadding),
                        horizontalArrangement = Arrangement.SpaceBetween,
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Text(
                            text = "${selectedMainSection?.title ?: "Spaces"} (${sortedVenues.size})",
                            fontSize = 14.5.sp,
                            fontWeight = FontWeight.Bold,
                            color = MaterialTheme.colorScheme.onBackground
                        )

                        Box {
                            Surface(
                                onClick = { showSortDropdown = true },
                                shape = RoundedCornerShape(10.dp),
                                color = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.6f),
                                border = BorderStroke(1.dp, MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.4f)),
                                modifier = Modifier.testTag("home_sort_dropdown_btn")
                            ) {
                                Row(
                                    verticalAlignment = Alignment.CenterVertically,
                                    modifier = Modifier.padding(horizontal = 10.dp, vertical = 6.dp)
                                ) {
                                    Text(selectedSortOption.icon, fontSize = 12.sp)
                                    Spacer(modifier = Modifier.width(4.dp))
                                    Text(
                                        text = selectedSortOption.displayName,
                                        fontSize = 12.sp,
                                        fontWeight = FontWeight.SemiBold,
                                        color = MaterialTheme.colorScheme.onSurface
                                    )
                                    Spacer(modifier = Modifier.width(4.dp))
                                    Icon(
                                        imageVector = Icons.Default.ArrowDropDown,
                                        contentDescription = "Sort options",
                                        tint = MaterialTheme.colorScheme.onSurfaceVariant,
                                        modifier = Modifier.size(16.dp)
                                    )
                                }
                            }

                            DropdownMenu(
                                expanded = showSortDropdown,
                                onDismissRequest = { showSortDropdown = false }
                            ) {
                                HomeScreenSortOption.values().forEach { option ->
                                    DropdownMenuItem(
                                        text = {
                                            Row(verticalAlignment = Alignment.CenterVertically) {
                                                Text(option.icon, fontSize = 14.sp)
                                                Spacer(modifier = Modifier.width(8.dp))
                                                Text(
                                                    text = option.displayName,
                                                    fontWeight = if (selectedSortOption == option) FontWeight.Bold else FontWeight.Normal
                                                )
                                            }
                                        },
                                        onClick = {
                                            selectedSortOption = option
                                            showSortDropdown = false
                                        }
                                    )
                                }
                            }
                        }
                    }
                    Spacer(modifier = Modifier.height(8.dp))
                }

                // Venue Results in Selected Section
                if (isSimulatingLoading) {
                    items(3) {
                        EyeCatchingVenueCardSkeleton(
                            modifier = Modifier
                                .fillMaxWidth()
                                .padding(horizontal = responsiveInfo.horizontalPadding, vertical = 6.dp)
                        )
                    }
                } else if (sortedVenues.isEmpty()) {
                    item {
                        if (syncState is NetworkSyncState.Error) {
                            NetworkErrorRetryCard(
                                syncState = syncState as NetworkSyncState.Error,
                                onRetry = {
                                    coroutineScope.launch {
                                        NetworkRetryManager.triggerRetry()
                                    }
                                },
                                onUseOfflineMode = {
                                    searchQuery = ""
                                    selectedCategorySlug = "all"
                                    selectedAmenityFilters = emptySet()
                                    filterMinRating = 0f
                                    filterMinPrice = 0f
                                    filterMaxPrice = 500000f
                                    NetworkRetryManager.setSyncState(NetworkSyncState.Idle)
                                },
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .padding(horizontal = responsiveInfo.horizontalPadding, vertical = 16.dp)
                            )
                        } else {
                            Surface(
                                shape = RoundedCornerShape(16.dp),
                                color = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.5f),
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .padding(horizontal = responsiveInfo.horizontalPadding, vertical = 16.dp)
                            ) {
                                Column(
                                    modifier = Modifier.padding(24.dp),
                                    horizontalAlignment = Alignment.CenterHorizontally
                                ) {
                                    Text("🔍", fontSize = 32.sp)
                                    Spacer(modifier = Modifier.height(8.dp))
                                    Text(
                                        text = "No spaces found matching your search",
                                        fontWeight = FontWeight.Bold,
                                        fontSize = 14.sp
                                    )
                                    Spacer(modifier = Modifier.height(4.dp))
                                    Text(
                                        text = "Try clearing search filters or changing the sub-category.",
                                        fontSize = 12.sp,
                                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                                        textAlign = TextAlign.Center
                                    )
                                    Spacer(modifier = Modifier.height(12.dp))
                                    Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                                        Button(
                                            onClick = {
                                                searchQuery = ""
                                                selectedCategorySlug = "all"
                                                selectedAmenityFilters = emptySet()
                                                filterMinRating = 0f
                                                filterMinPrice = 0f
                                                filterMaxPrice = 500000f
                                            },
                                            shape = RoundedCornerShape(12.dp)
                                        ) {
                                            Text("Reset Filters")
                                        }
                                        OutlinedButton(
                                            onClick = {
                                                coroutineScope.launch {
                                                    BookMySpaceRepository.refreshAllData()
                                                }
                                            },
                                            shape = RoundedCornerShape(12.dp)
                                        ) {
                                            Icon(Icons.Default.Refresh, contentDescription = null, modifier = Modifier.size(16.dp))
                                            Spacer(modifier = Modifier.width(4.dp))
                                            Text("Refresh Data")
                                        }
                                    }
                                }
                            }
                        }
                    }
                } else {
                    // Primary results list
                    responsiveGridItems(
                        items = sortedVenues,
                        columns = responsiveInfo.resultsGridColumns,
                        key = { it.id },
                        horizontalSpacing = responsiveInfo.gridSpacing,
                        verticalSpacing = 16.dp,
                        contentPadding = PaddingValues(horizontal = responsiveInfo.horizontalPadding)
                    ) { venue, _ ->
                        SectionVenueResultCard(
                            venue = venue,
                            onClick = { onNavigateToVenue(venue.id) },
                            onCallClick = {
                                val phone = venue.contactPhone.ifBlank { "+919876543210" }
                                val intent = Intent(Intent.ACTION_DIAL, Uri.parse("tel:$phone"))
                                try { context.startActivity(intent) } catch (e: Exception) { e.printStackTrace() }
                            },
                            onWhatsAppClick = {
                                val phone = venue.contactPhone.filter { it.isDigit() }.ifBlank { "919876543210" }
                                val url = "https://wa.me/$phone?text=Hi, I want to book ${venue.name} on BookMySpace. Please confirm room availability."
                                val intent = Intent(Intent.ACTION_VIEW, Uri.parse(url))
                                try { context.startActivity(intent) } catch (e: Exception) { e.printStackTrace() }
                            },
                            modifier = Modifier.fillMaxWidth()
                        )
                    }

                    // 6. Seamless Recommendations to Eliminate Dead Space
                    if (remainingOtherStays.isNotEmpty()) {
                        item {
                            Spacer(modifier = Modifier.height(16.dp))
                            Surface(
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .padding(horizontal = responsiveInfo.horizontalPadding),
                                shape = RoundedCornerShape(16.dp),
                                color = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.45f)
                            ) {
                                Row(
                                    modifier = Modifier.padding(horizontal = 14.dp, vertical = 10.dp),
                                    verticalAlignment = Alignment.CenterVertically
                                ) {
                                    Text("🔥", fontSize = 18.sp)
                                    Spacer(modifier = Modifier.width(8.dp))
                                    Column {
                                        Text(
                                            text = "More Recommended ${selectedMainSection?.title ?: "Spaces"}",
                                            fontSize = 14.5.sp,
                                            fontWeight = FontWeight.Bold,
                                            color = MaterialTheme.colorScheme.onSurface
                                        )
                                        Text(
                                            text = "Top-rated verified properties in nearby areas with instant booking",
                                            fontSize = 11.sp,
                                            color = MaterialTheme.colorScheme.onSurfaceVariant
                                        )
                                    }
                                }
                            }
                        }

                        responsiveGridItems(
                            items = remainingOtherStays,
                            columns = responsiveInfo.resultsGridColumns,
                            key = { "rec_${it.id}" },
                            horizontalSpacing = responsiveInfo.gridSpacing,
                            verticalSpacing = 16.dp,
                            contentPadding = PaddingValues(horizontal = responsiveInfo.horizontalPadding)
                        ) { venue, _ ->
                            SectionVenueResultCard(
                                venue = venue,
                                onClick = { onNavigateToVenue(venue.id) },
                                onCallClick = {
                                    val phone = venue.contactPhone.ifBlank { "+919876543210" }
                                    val intent = Intent(Intent.ACTION_DIAL, Uri.parse("tel:$phone"))
                                    try { context.startActivity(intent) } catch (e: Exception) { e.printStackTrace() }
                                },
                                onWhatsAppClick = {
                                    val phone = venue.contactPhone.filter { it.isDigit() }.ifBlank { "919876543210" }
                                    val url = "https://wa.me/$phone?text=Hi, I want to book ${venue.name} on BookMySpace. Please confirm room availability."
                                    val intent = Intent(Intent.ACTION_VIEW, Uri.parse(url))
                                    try { context.startActivity(intent) } catch (e: Exception) { e.printStackTrace() }
                                },
                                modifier = Modifier.fillMaxWidth()
                            )
                        }
                    }

                    // 7. World-Class Trust & Booking Guarantee Banner (OYO & Booking.com standard)
                    item {
                        Spacer(modifier = Modifier.height(16.dp))
                        Card(
                            shape = RoundedCornerShape(20.dp),
                            colors = CardDefaults.cardColors(
                                containerColor = MaterialTheme.colorScheme.surface
                            ),
                            border = BorderStroke(
                                1.dp,
                                Brush.linearGradient(
                                    listOf(
                                        Color(0xFF2E7D32).copy(alpha = 0.5f),
                                        MaterialTheme.colorScheme.primary.copy(alpha = 0.3f)
                                    )
                                )
                            ),
                            modifier = Modifier
                                .fillMaxWidth()
                                .padding(horizontal = responsiveInfo.horizontalPadding)
                        ) {
                            Column(modifier = Modifier.padding(18.dp)) {
                                Row(verticalAlignment = Alignment.CenterVertically) {
                                    Surface(
                                        shape = CircleShape,
                                        color = Color(0xFF2E7D32).copy(alpha = 0.15f),
                                        modifier = Modifier.size(36.dp)
                                    ) {
                                        Box(contentAlignment = Alignment.Center) {
                                            Icon(
                                                imageVector = Icons.Default.VerifiedUser,
                                                contentDescription = null,
                                                tint = Color(0xFF2E7D32),
                                                modifier = Modifier.size(20.dp)
                                            )
                                        }
                                    }
                                    Spacer(modifier = Modifier.width(10.dp))
                                    Column {
                                        Text(
                                            text = "Book with 100% Peace of Mind",
                                            fontWeight = FontWeight.Bold,
                                            fontSize = 15.sp,
                                            color = MaterialTheme.colorScheme.onSurface
                                        )
                                        Text(
                                            text = "Official BookMySpace Assured Guarantee",
                                            fontSize = 11.sp,
                                            color = MaterialTheme.colorScheme.onSurfaceVariant
                                        )
                                    }
                                }

                                Spacer(modifier = Modifier.height(14.dp))

                                Row(
                                    modifier = Modifier.fillMaxWidth(),
                                    horizontalArrangement = Arrangement.SpaceBetween
                                ) {
                                    Column(
                                        modifier = Modifier.weight(1f),
                                        horizontalAlignment = Alignment.CenterHorizontally
                                    ) {
                                        Text("🛡️", fontSize = 20.sp)
                                        Spacer(modifier = Modifier.height(4.dp))
                                        Text(
                                            text = "100% Verified",
                                            fontWeight = FontWeight.Bold,
                                            fontSize = 11.5.sp,
                                            textAlign = TextAlign.Center
                                        )
                                        Text(
                                            text = "Real photos & audit",
                                            fontSize = 10.sp,
                                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                                            textAlign = TextAlign.Center
                                        )
                                    }

                                    Column(
                                        modifier = Modifier.weight(1f),
                                        horizontalAlignment = Alignment.CenterHorizontally
                                    ) {
                                        Text("💵", fontSize = 20.sp)
                                        Spacer(modifier = Modifier.height(4.dp))
                                        Text(
                                            text = "Pay at Check-in",
                                            fontWeight = FontWeight.Bold,
                                            fontSize = 11.5.sp,
                                            textAlign = TextAlign.Center
                                        )
                                        Text(
                                            text = "Zero advance pressure",
                                            fontSize = 10.sp,
                                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                                            textAlign = TextAlign.Center
                                        )
                                    }

                                    Column(
                                        modifier = Modifier.weight(1f),
                                        horizontalAlignment = Alignment.CenterHorizontally
                                    ) {
                                        Text("⚡", fontSize = 20.sp)
                                        Spacer(modifier = Modifier.height(4.dp))
                                        Text(
                                            text = "Instant Pass",
                                            fontWeight = FontWeight.Bold,
                                            fontSize = 11.5.sp,
                                            textAlign = TextAlign.Center
                                        )
                                        Text(
                                            text = "Zero paperwork wait",
                                            fontSize = 10.sp,
                                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                                            textAlign = TextAlign.Center
                                        )
                                    }

                                    Column(
                                        modifier = Modifier.weight(1f),
                                        horizontalAlignment = Alignment.CenterHorizontally
                                    ) {
                                        Text("📞", fontSize = 20.sp)
                                        Spacer(modifier = Modifier.height(4.dp))
                                        Text(
                                            text = "24/7 Helpline",
                                            fontWeight = FontWeight.Bold,
                                            fontSize = 11.5.sp,
                                            textAlign = TextAlign.Center
                                        )
                                        Text(
                                            text = "Telugu / Hindi / Eng",
                                            fontSize = 10.sp,
                                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                                            textAlign = TextAlign.Center
                                        )
                                    }
                                }

                                Spacer(modifier = Modifier.height(14.dp))
                                HorizontalDivider(color = MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.3f))
                                Spacer(modifier = Modifier.height(12.dp))

                                // Direct Help Hotline button for uneducated or first-time callers
                                Row(
                                    modifier = Modifier.fillMaxWidth(),
                                    horizontalArrangement = Arrangement.SpaceBetween,
                                    verticalAlignment = Alignment.CenterVertically
                                ) {
                                    Row(verticalAlignment = Alignment.CenterVertically) {
                                        Text("💬", fontSize = 16.sp)
                                        Spacer(modifier = Modifier.width(6.dp))
                                        Text(
                                            text = "Need help choosing or booking?",
                                            fontSize = 12.sp,
                                            color = MaterialTheme.colorScheme.onSurfaceVariant
                                        )
                                    }

                                    FilledTonalButton(
                                        onClick = {
                                            val intent = Intent(Intent.ACTION_DIAL, Uri.parse("tel:18001234567"))
                                            try { context.startActivity(intent) } catch (e: Exception) { e.printStackTrace() }
                                        },
                                        shape = RoundedCornerShape(10.dp),
                                        contentPadding = PaddingValues(horizontal = 12.dp, vertical = 6.dp)
                                    ) {
                                        Icon(Icons.Default.Phone, contentDescription = null, modifier = Modifier.size(14.dp))
                                        Spacer(modifier = Modifier.width(4.dp))
                                        Text("Call Support", fontSize = 11.5.sp, fontWeight = FontWeight.Bold)
                                    }
                                }
                            }
                        }
                    }

                    item {
                        Spacer(modifier = Modifier.height(30.dp))
                    }
                }
            }
        }
    }
}
}

/**
 * Large, eye-catching, extremely simple Hero Card for the 4 Main Sections on the first screen.
 * Adapts responsively on phone single-column vs tablet grid layouts.
 */
@Composable
fun MainSectionBigHeroCard(
    section: MainHomeSection,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    isTabletOrWide: Boolean = false
) {
    Card(
        onClick = onClick,
        shape = RoundedCornerShape(if (isTabletOrWide) 24.dp else 22.dp),
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface),
        elevation = CardDefaults.cardElevation(defaultElevation = 2.dp),
        border = BorderStroke(1.dp, MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.4f)),
        modifier = modifier
            .fillMaxWidth()
            .defaultMinSize(minHeight = if (isTabletOrWide) 130.dp else 115.dp)
            .testTag("main_section_card_${section.id}")
    ) {
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .height(if (isTabletOrWide) 140.dp else 125.dp)
        ) {
            // Background Image
            AsyncImage(
                model = section.imageUrl,
                contentDescription = section.title,
                contentScale = ContentScale.Crop,
                modifier = Modifier.fillMaxSize()
            )

            // High-contrast gradient overlay to ensure text readability in any lighting
            Box(
                modifier = Modifier
                    .fillMaxSize()
                    .background(
                        Brush.horizontalGradient(
                            colors = listOf(
                                Color.Black.copy(alpha = 0.90f),
                                Color.Black.copy(alpha = 0.74f),
                                Color.Black.copy(alpha = 0.35f)
                            )
                        )
                    )
            )

            // Card Content
            Row(
                modifier = Modifier
                    .fillMaxSize()
                    .padding(horizontal = if (isTabletOrWide) 20.dp else 18.dp, vertical = 14.dp),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.SpaceBetween
            ) {
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    modifier = Modifier.weight(1f)
                ) {
                    // Prominent Emoji Badge
                    Surface(
                        shape = RoundedCornerShape(16.dp),
                        color = Color.White.copy(alpha = 0.22f),
                        modifier = Modifier.size(if (isTabletOrWide) 60.dp else 56.dp)
                    ) {
                        Box(contentAlignment = Alignment.Center) {
                            Text(
                                text = section.emoji,
                                fontSize = if (isTabletOrWide) 30.sp else 28.sp
                            )
                        }
                    }

                    Spacer(modifier = Modifier.width(if (isTabletOrWide) 18.dp else 16.dp))

                    Column {
                        Text(
                            text = section.title,
                            fontSize = if (isTabletOrWide) 20.sp else 19.sp,
                            fontWeight = FontWeight.Black,
                            color = Color.White,
                            letterSpacing = (-0.3).sp
                        )
                        Spacer(modifier = Modifier.height(3.dp))
                        Text(
                            text = section.subtitle,
                            fontSize = if (isTabletOrWide) 13.sp else 12.sp,
                            color = Color.White.copy(alpha = 0.85f),
                            maxLines = 2,
                            overflow = TextOverflow.Ellipsis,
                            lineHeight = 16.sp
                        )
                    }
                }

                Spacer(modifier = Modifier.width(10.dp))

                // Large Touch Target Circular Arrow Button
                Surface(
                    shape = CircleShape,
                    color = MaterialTheme.colorScheme.primary,
                    modifier = Modifier.size(if (isTabletOrWide) 48.dp else 44.dp)
                ) {
                    Box(contentAlignment = Alignment.Center) {
                        Icon(
                            imageVector = Icons.AutoMirrored.Filled.ArrowForward,
                            contentDescription = "Explore ${section.title}",
                            tint = MaterialTheme.colorScheme.onPrimary,
                            modifier = Modifier.size(if (isTabletOrWide) 22.dp else 20.dp)
                        )
                    }
                }
            }
        }
    }
}

/**
 * World-Class Result Card for Section Detail list following OYO, Booking.com & Airbnb UI/UX.
 * Provides high-contrast, zero-clutter, accessible 1-tap booking, instant Call & WhatsApp actions.
 */
@Composable
fun SectionVenueResultCard(
    venue: Venue,
    onClick: () -> Unit,
    onCallClick: () -> Unit,
    onWhatsAppClick: () -> Unit,
    modifier: Modifier = Modifier
) {
    var currentImageIndex by remember(venue.id) { mutableIntStateOf(0) }
    val images = remember(venue) {
        if (venue.images.isNotEmpty()) venue.images.map { it.url }
        else listOf(VenueImageResolver.resolveCoverImage(venue))
    }
    val currentImageUrl = images.getOrElse(currentImageIndex) { images.firstOrNull() ?: "" }

    val originalPrice = remember(venue.pricingBaseAmount) {
        (venue.pricingBaseAmount * 1.8).toInt()
    }
    val discountPercent = remember(venue.pricingBaseAmount, originalPrice) {
        if (originalPrice > 0) {
            (((originalPrice - venue.pricingBaseAmount) / originalPrice) * 100).toInt().coerceAtLeast(35)
        } else 40
    }

    Card(
        onClick = onClick,
        shape = RoundedCornerShape(20.dp),
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface),
        elevation = CardDefaults.cardElevation(defaultElevation = 4.dp),
        border = BorderStroke(
            1.dp,
            Brush.linearGradient(
                colors = listOf(
                    MaterialTheme.colorScheme.primary.copy(alpha = 0.25f),
                    MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.35f),
                    Color.White.copy(alpha = 0.15f)
                )
            )
        ),
        modifier = modifier
            .fillMaxWidth()
            .testTag("section_venue_card_${venue.id}")
    ) {
        Column {
            // 1. High-Quality Photo Gallery with Overlays
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .height(180.dp)
            ) {
                AsyncImage(
                    model = currentImageUrl,
                    contentDescription = venue.name,
                    contentScale = ContentScale.Crop,
                    modifier = Modifier.fillMaxSize()
                )

                // Scrim Gradient
                Box(
                    modifier = Modifier
                        .fillMaxSize()
                        .background(
                            Brush.verticalGradient(
                                colors = listOf(
                                    Color.Black.copy(alpha = 0.45f),
                                    Color.Transparent,
                                    Color.Black.copy(alpha = 0.75f)
                                )
                            )
                        )
                )

                // Top Left: Category & Discount Badge
                Row(
                    modifier = Modifier
                        .align(Alignment.TopStart)
                        .padding(10.dp),
                    horizontalArrangement = Arrangement.spacedBy(6.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    venue.category?.let { cat ->
                        Surface(
                            color = MaterialTheme.colorScheme.primary,
                            shape = RoundedCornerShape(8.dp)
                        ) {
                            Text(
                                text = cat.name,
                                fontSize = 11.sp,
                                fontWeight = FontWeight.Bold,
                                color = MaterialTheme.colorScheme.onPrimary,
                                modifier = Modifier.padding(horizontal = 8.dp, vertical = 3.5.dp)
                            )
                        }
                    }

                    Surface(
                        color = Color(0xFFE53935),
                        shape = RoundedCornerShape(8.dp)
                    ) {
                        Text(
                            text = "🔥 $discountPercent% OFF",
                            fontSize = 11.sp,
                            fontWeight = FontWeight.Black,
                            color = Color.White,
                            modifier = Modifier.padding(horizontal = 7.dp, vertical = 3.5.dp)
                        )
                    }
                }

                // Top Right: Photo Counter & Quick Switcher
                if (images.size > 1) {
                    Surface(
                        color = Color.Black.copy(alpha = 0.65f),
                        shape = RoundedCornerShape(12.dp),
                        modifier = Modifier
                            .align(Alignment.TopEnd)
                            .padding(10.dp)
                            .clickable {
                                currentImageIndex = (currentImageIndex + 1) % images.size
                            }
                    ) {
                        Row(
                            verticalAlignment = Alignment.CenterVertically,
                            modifier = Modifier.padding(horizontal = 8.dp, vertical = 4.dp)
                        ) {
                            Icon(
                                imageVector = Icons.Default.PhotoCamera,
                                contentDescription = null,
                                tint = Color.White,
                                modifier = Modifier.size(13.dp)
                            )
                            Spacer(modifier = Modifier.width(4.dp))
                            Text(
                                text = "${currentImageIndex + 1}/${images.size}",
                                color = Color.White,
                                fontSize = 11.sp,
                                fontWeight = FontWeight.Bold
                            )
                        }
                    }
                }

                // Bottom Left: Rating Badge (Gold Star + Excellent)
                Surface(
                    color = Color.Black.copy(alpha = 0.75f),
                    shape = RoundedCornerShape(8.dp),
                    modifier = Modifier
                        .align(Alignment.BottomStart)
                        .padding(10.dp)
                ) {
                    Row(
                        verticalAlignment = Alignment.CenterVertically,
                        modifier = Modifier.padding(horizontal = 8.dp, vertical = 4.dp)
                    ) {
                        Icon(
                            imageVector = Icons.Default.Star,
                            contentDescription = null,
                            tint = Color(0xFFFFC107),
                            modifier = Modifier.size(14.dp)
                        )
                        Spacer(modifier = Modifier.width(4.dp))
                        Text(
                            text = String.format(java.util.Locale.US, "%.1f", venue.avgRating),
                            color = Color.White,
                            fontSize = 12.sp,
                            fontWeight = FontWeight.Black
                        )
                        Spacer(modifier = Modifier.width(4.dp))
                        Text(
                            text = "(${venue.ratingCount}) • ${if (venue.avgRating >= 4.5) "Excellent" else "Very Good"}",
                            color = Color(0xFFE0E0E0),
                            fontSize = 11.sp,
                            fontWeight = FontWeight.Medium
                        )
                    }
                }

                // Bottom Right: Distance
                Surface(
                    color = Color.Black.copy(alpha = 0.75f),
                    shape = RoundedCornerShape(8.dp),
                    modifier = Modifier
                        .align(Alignment.BottomEnd)
                        .padding(10.dp)
                ) {
                    Row(
                        verticalAlignment = Alignment.CenterVertically,
                        modifier = Modifier.padding(horizontal = 7.dp, vertical = 4.dp)
                    ) {
                        Icon(
                            imageVector = Icons.Default.NearMe,
                            contentDescription = null,
                            tint = Color(0xFF64B5F6),
                            modifier = Modifier.size(12.dp)
                        )
                        Spacer(modifier = Modifier.width(3.dp))
                        Text(
                            text = "${String.format(java.util.Locale.US, "%.1f", venue.distanceKm)} km away",
                            color = Color.White,
                            fontSize = 11.sp,
                            fontWeight = FontWeight.SemiBold
                        )
                    }
                }
            }

            // 2. Body Details (Dense, Clean, Clear hierarchy)
            Column(modifier = Modifier.padding(14.dp)) {
                // Title + Star class
                Text(
                    text = venue.name,
                    fontSize = 16.5.sp,
                    fontWeight = FontWeight.Bold,
                    color = MaterialTheme.colorScheme.onSurface,
                    maxLines = 2,
                    overflow = TextOverflow.Ellipsis
                )

                Spacer(modifier = Modifier.height(3.dp))

                // Location Subtitle
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Icon(
                        imageVector = Icons.Default.LocationOn,
                        contentDescription = null,
                        tint = MaterialTheme.colorScheme.primary,
                        modifier = Modifier.size(14.dp)
                    )
                    Spacer(modifier = Modifier.width(3.dp))
                    Text(
                        text = "${venue.addressLine1}, ${venue.city}",
                        fontSize = 12.sp,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis
                    )
                }

                // Room / Stay details highlight
                venue.hotelDetails?.let { hd ->
                    Spacer(modifier = Modifier.height(6.dp))
                    Surface(
                        shape = RoundedCornerShape(6.dp),
                        color = MaterialTheme.colorScheme.primaryContainer.copy(alpha = 0.35f)
                    ) {
                        Row(
                            verticalAlignment = Alignment.CenterVertically,
                            modifier = Modifier.padding(horizontal = 8.dp, vertical = 3.dp)
                        ) {
                            Text(
                                text = "🛏️ ${hd.propertyType} • ${hd.roomTypes.firstOrNull() ?: "Deluxe Room"}",
                                fontSize = 11.sp,
                                fontWeight = FontWeight.SemiBold,
                                color = MaterialTheme.colorScheme.primary,
                                maxLines = 1,
                                overflow = TextOverflow.Ellipsis
                            )
                        }
                    }
                }

                // Key Facilities pills with universal icons
                if (venue.facilities.isNotEmpty()) {
                    Spacer(modifier = Modifier.height(8.dp))
                    Row(
                        horizontalArrangement = Arrangement.spacedBy(6.dp),
                        modifier = Modifier.fillMaxWidth()
                    ) {
                        venue.facilities.take(3).forEach { fac ->
                            Surface(
                                shape = RoundedCornerShape(6.dp),
                                color = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.7f)
                            ) {
                                Text(
                                    text = "✓ ${fac.facility}",
                                    fontSize = 10.5.sp,
                                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                                    modifier = Modifier.padding(horizontal = 7.dp, vertical = 2.5.dp),
                                    maxLines = 1
                                )
                            }
                        }
                    }
                }

                // Booking.com style Trust & Cancellation Chip
                Spacer(modifier = Modifier.height(8.dp))
                Row(
                    horizontalArrangement = Arrangement.spacedBy(6.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Surface(
                        shape = RoundedCornerShape(6.dp),
                        color = Color(0xFF2E7D32).copy(alpha = 0.12f)
                    ) {
                        Text(
                            text = "🟢 FREE Cancellation • Pay at Hotel",
                            fontSize = 11.sp,
                            fontWeight = FontWeight.Bold,
                            color = Color(0xFF2E7D32),
                            modifier = Modifier.padding(horizontal = 7.dp, vertical = 2.5.dp)
                        )
                    }
                }

                Spacer(modifier = Modifier.height(10.dp))
                HorizontalDivider(color = MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.4f))
                Spacer(modifier = Modifier.height(10.dp))

                // Price Section + 1-Tap Action Row
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Column {
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            Text(
                                text = "₹$originalPrice",
                                fontSize = 13.sp,
                                color = MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.7f),
                                style = androidx.compose.ui.text.TextStyle(
                                    textDecoration = androidx.compose.ui.text.style.TextDecoration.LineThrough
                                )
                            )
                            Spacer(modifier = Modifier.width(6.dp))
                            Text(
                                text = "₹${venue.pricingBaseAmount.toInt()}",
                                fontSize = 21.sp,
                                fontWeight = FontWeight.Black,
                                color = MaterialTheme.colorScheme.primary
                            )
                        }
                        Text(
                            text = "+ ₹0 booking fee / night",
                            fontSize = 10.5.sp,
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                    }

                    // Action buttons (Instant Book, Direct Call, Direct WhatsApp)
                    Row(
                        horizontalArrangement = Arrangement.spacedBy(6.dp),
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        OutlinedIconButton(
                            onClick = onCallClick,
                            shape = RoundedCornerShape(12.dp),
                            border = BorderStroke(1.dp, Color(0xFF2E7D32).copy(alpha = 0.5f)),
                            modifier = Modifier
                                .size(44.dp)
                                .testTag("call_space_btn_${venue.id}")
                        ) {
                            Icon(
                                imageVector = Icons.Default.Phone,
                                contentDescription = "Call Hotel",
                                tint = Color(0xFF2E7D32),
                                modifier = Modifier.size(20.dp)
                            )
                        }

                        FilledTonalIconButton(
                            onClick = onWhatsAppClick,
                            shape = RoundedCornerShape(12.dp),
                            colors = IconButtonDefaults.filledTonalIconButtonColors(
                                containerColor = Color(0xFF25D366).copy(alpha = 0.15f)
                            ),
                            modifier = Modifier
                                .size(44.dp)
                                .testTag("whatsapp_space_btn_${venue.id}")
                        ) {
                            Text("💬", fontSize = 18.sp)
                        }

                        Button(
                            onClick = onClick,
                            shape = RoundedCornerShape(12.dp),
                            colors = ButtonDefaults.buttonColors(
                                containerColor = MaterialTheme.colorScheme.primary
                            ),
                            contentPadding = PaddingValues(horizontal = 14.dp, vertical = 0.dp),
                            modifier = Modifier
                                .height(44.dp)
                                .testTag("book_space_btn_${venue.id}")
                        ) {
                            Text("⚡ BOOK NOW", fontWeight = FontWeight.Black, fontSize = 12.5.sp)
                        }
                    }
                }
            }
        }
    }
}


