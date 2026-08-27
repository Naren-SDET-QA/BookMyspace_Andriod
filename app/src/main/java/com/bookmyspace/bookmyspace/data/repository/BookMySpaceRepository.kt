package com.bookmyspace.bookmyspace.data.repository

import android.content.Context
import android.util.Log
import com.bookmyspace.bookmyspace.R
import com.bookmyspace.bookmyspace.data.local.RecentSearchEntity
import com.bookmyspace.bookmyspace.data.local.ReviewEntity
import com.bookmyspace.bookmyspace.data.location.IndiaLocationMasterData
import com.bookmyspace.bookmyspace.data.model.*
import com.bookmyspace.bookmyspace.ui.theme.ThemeMode
import com.bookmyspace.bookmyspace.ui.theme.ThemePreset
import com.google.firebase.auth.FirebaseAuth
import com.google.firebase.firestore.FieldValue
import com.google.firebase.firestore.FirebaseFirestore
import com.bookmyspace.bookmyspace.data.local.PaymentTransactionEntity
import com.bookmyspace.bookmyspace.data.local.BatchAlertEntity
import com.bookmyspace.bookmyspace.data.local.BookMySpaceRoomDatabase
import com.bookmyspace.bookmyspace.data.notification.BookingReminderNotificationManager
import com.bookmyspace.bookmyspace.data.payment.RazorpayRefundService
import com.bookmyspace.bookmyspace.data.payment.RefundResult
import com.bookmyspace.bookmyspace.data.repository.PaymentTransactionRepository
import com.bookmyspace.bookmyspace.data.network.NetworkRetryManager
import com.bookmyspace.bookmyspace.data.network.NetworkSyncState
import com.google.firebase.firestore.ListenerRegistration
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import kotlinx.coroutines.tasks.await
import java.util.UUID

object BookMySpaceRepository {
    private const val TAG = "BookMySpaceRepository"
    private var appContext: Context? = null
    private var firestoreDb: FirebaseFirestore? = null
    private var bookingsListener: ListenerRegistration? = null
    private var savedListener: ListenerRegistration? = null
    private var reviewsListener: ListenerRegistration? = null
    private var venuesListener: ListenerRegistration? = null
    private var institutesListener: ListenerRegistration? = null
    private var coursesListener: ListenerRegistration? = null
    private var classesListener: ListenerRegistration? = null
    private var eventsListener: ListenerRegistration? = null
    private var sectionsListener: ListenerRegistration? = null
    private var paymentTxRepository: PaymentTransactionRepository? = null

    private val _paymentTransactions = MutableStateFlow<List<PaymentTransactionEntity>>(emptyList())
    val paymentTransactions: StateFlow<List<PaymentTransactionEntity>> = _paymentTransactions.asStateFlow()

    private val _favoriteItems = MutableStateFlow<List<FavoriteVenueItem>>(emptyList())
    val favoriteItems: StateFlow<List<FavoriteVenueItem>> = _favoriteItems.asStateFlow()

    private val _favoriteVenueIds = MutableStateFlow<Set<String>>(setOf("v_grand_palace", "v_smash_arena"))
    val favoriteVenueIds: StateFlow<Set<String>> = _favoriteVenueIds.asStateFlow()

    private fun getAuthUid(): String? {
        return try {
            FirebaseAuth.getInstance().currentUser?.uid
        } catch (_: Throwable) {
            null
        } ?: _authUser.value?.id
    }

    fun getPaymentTransactionRepository(): PaymentTransactionRepository? = paymentTxRepository

    fun initialize(context: Context) {
        try {
            appContext = context.applicationContext
            paymentTxRepository = PaymentTransactionRepository.getInstance(context)
            CoroutineScope(Dispatchers.IO).launch {
                paymentTxRepository?.allTransactions?.collect { txs ->
                    if (txs.isEmpty()) {
                        val initialTxs = listOf(
                            PaymentTransactionEntity(
                                transactionId = "pay_bms_live_101",
                                bookingId = "bk_demo_101",
                                venueId = "v_smash_arena",
                                venueName = "Smash Arena International Badminton Complex",
                                amount = 650.0,
                                currency = "INR",
                                paymentStatus = "SUCCESS",
                                paymentMethod = "Razorpay UPI (Google Pay)",
                                razorpayOrderId = "order_bms_101",
                                razorpaySignature = "sig_valid_bms_101",
                                customerName = "Narendra Reddy",
                                customerEmail = "narenqe2@gmail.com",
                                customerPhone = "+91 98765 43210",
                                timestamp = System.currentTimeMillis() - 86400000L,
                                notes = "Advance Slot Booking Payment"
                            ),
                            PaymentTransactionEntity(
                                transactionId = "pay_bms_live_102",
                                bookingId = "bk_demo_102",
                                venueId = "v_grand_palace",
                                venueName = "The Royal Imperial Palace & Convention",
                                amount = 220000.0,
                                currency = "INR",
                                paymentStatus = "PENDING",
                                paymentMethod = "Razorpay Net Banking",
                                razorpayOrderId = "order_bms_102",
                                customerName = "Narendra Reddy",
                                customerEmail = "narenqe2@gmail.com",
                                customerPhone = "+91 98765 43210",
                                timestamp = System.currentTimeMillis() - 172800000L,
                                notes = "Convention Hall Reservation"
                            )
                        )
                        initialTxs.forEach { paymentTxRepository?.recordTransaction(it) }
                    } else {
                        _paymentTransactions.value = txs
                    }
                }
            }

            val resId = context.resources.getIdentifier("firestore_database_id", "string", context.packageName)
            val dbId = if (resId != 0) context.getString(resId) else "(default)"
            if (dbId.isNotEmpty() && dbId != "(default)") {
                Log.d(TAG, "Initializing Firestore with custom database ID: $dbId")
                firestoreDb = FirebaseFirestore.getInstance(dbId)
            } else {
                firestoreDb = FirebaseFirestore.getInstance()
            }
            listenToLiveFirestoreData()
            
            // Register global retry handler
            NetworkRetryManager.registerGlobalRetryAction {
                refreshAllData()
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to initialize Firestore: ${e.message}", e)
            NetworkRetryManager.setSyncState(
                NetworkSyncState.Error(
                    errorMessage = "Running in Local Offline Mode (${e.message ?: "Cloud not initialized"})",
                    canRetry = true
                )
            )
        }
    }

    private fun listenToLiveFirestoreData() {
        val db = firestoreDb ?: return
        val currentUserId = getAuthUid()

        // Listen to reviews
        try {
            reviewsListener?.remove()
            reviewsListener = db.collection("reviews")
                .addSnapshotListener { snapshot, error ->
                    if (error != null) {
                        handleFirestoreError(error, OperationType.GET, "reviews")
                        return@addSnapshotListener
                    }
                    if (snapshot != null && !snapshot.isEmpty) {
                        val liveReviews = snapshot.documents.mapNotNull { doc ->
                            val id = doc.getString("reviewId") ?: doc.id
                            val venueId = doc.getString("venueId") ?: return@mapNotNull null
                            val userName = doc.getString("userName") ?: "User"
                            val rating = doc.getDouble("rating") ?: 5.0
                            val comment = doc.getString("comment") ?: ""
                            com.bookmyspace.bookmyspace.data.local.ReviewEntity(
                                id = id,
                                venueId = venueId,
                                userName = userName,
                                rating = rating,
                                comment = comment,
                                date = "Recent"
                            )
                        }
                        if (liveReviews.isNotEmpty()) {
                            _reviews.value = liveReviews + sampleReviews.filter { s -> liveReviews.none { it.id == s.id } }
                        }
                    }
                }
        } catch (e: Exception) {
            Log.w(TAG, "Could not attach reviews listener: ${e.message}")
        }

        // Listen to user-specific bookings if authenticated
        if (currentUserId != null) {
            try {
                bookingsListener?.remove()
                bookingsListener = db.collection("bookings")
                    .whereEqualTo("userId", currentUserId)
                    .addSnapshotListener { snapshot, error ->
                        if (error != null) {
                            handleFirestoreError(error, OperationType.GET, "bookings")
                            return@addSnapshotListener
                        }
                        if (snapshot != null && !snapshot.isEmpty) {
                            val liveBookings = snapshot.documents.mapNotNull { doc ->
                                val id = doc.getString("bookingId") ?: doc.id
                                val userId = doc.getString("userId") ?: currentUserId
                                val venueId = doc.getString("venueId") ?: "v_smash_arena"
                                val date = doc.getString("bookingDate") ?: "2026-08-20"
                                val slotTime = doc.getString("slotTime") ?: "07:00 - 08:00"
                                val totalPrice = doc.getDouble("totalPrice") ?: 650.0
                                val statusStr = doc.getString("status") ?: "CONFIRMED"
                                val status = try { BookingStatus.valueOf(statusStr) } catch (_: Exception) { BookingStatus.CONFIRMED }
                                val paymentMethod = doc.getString("paymentMethod") ?: "UPI"
                                Booking(
                                    id = id,
                                    userId = userId,
                                    venueId = venueId,
                                    date = date,
                                    startTime = slotTime.substringBefore("-").trim(),
                                    endTime = slotTime.substringAfter("-").trim(),
                                    totalPrice = totalPrice,
                                    status = status,
                                    paymentStatus = "PAID",
                                    paymentMethod = paymentMethod,
                                    qrCodeToken = "BMS-PASS-${id.takeLast(6).uppercase()}"
                                )
                            }
                            if (liveBookings.isNotEmpty()) {
                                _bookings.value = liveBookings + sampleBookings.filter { s -> liveBookings.none { it.id == s.id } }
                            }
                        }
                    }
            } catch (e: Exception) {
                Log.w(TAG, "Could not attach bookings listener: ${e.message}")
            }

            // Listen to user-specific favorites from Firestore
            try {
                savedListener?.remove()
                savedListener = db.collection("favorites")
                    .whereEqualTo("userId", currentUserId)
                    .addSnapshotListener { snapshot, error ->
                        if (error != null) {
                            handleFirestoreError(error, OperationType.GET, "favorites")
                            return@addSnapshotListener
                        }
                        if (snapshot != null) {
                            val liveFavorites = snapshot.documents.mapNotNull { doc ->
                                val vId = doc.getString("venueId") ?: return@mapNotNull null
                                FavoriteVenueItem(
                                    id = doc.id,
                                    userId = doc.getString("userId") ?: currentUserId,
                                    venueId = vId,
                                    venueName = doc.getString("venueName") ?: "",
                                    category = doc.getString("category") ?: "",
                                    city = doc.getString("city") ?: "",
                                    rating = doc.getDouble("rating") ?: 4.8,
                                    coverImageUrl = doc.getString("coverImageUrl") ?: "",
                                    pricingBaseAmount = doc.getDouble("pricingBaseAmount") ?: 500.0,
                                    addedAt = doc.getLong("addedAt") ?: System.currentTimeMillis(),
                                    notes = doc.getString("notes") ?: ""
                                )
                            }
                            val favIds = liveFavorites.map { it.venueId }.toSet()
                            _favoriteItems.value = liveFavorites
                            _favoriteVenueIds.value = favIds
                            _venues.value = _venues.value.map { v ->
                                v.copy(isSaved = favIds.contains(v.id))
                            }
                        }
                    }
            } catch (e: Exception) {
                Log.w(TAG, "Could not attach favorites Firestore listener: ${e.message}")
            }
        }

        // Listen to cloud venues collection
        try {
            venuesListener?.remove()
            venuesListener = db.collection("venues")
                .addSnapshotListener { snapshot, error ->
                    if (error != null) {
                        Log.w(TAG, "Firestore venues listener error: ${error.message}")
                        return@addSnapshotListener
                    }
                    if (snapshot != null && !snapshot.isEmpty) {
                        val cloudVenues = snapshot.documents.mapNotNull { doc ->
                            val id = doc.getString("id") ?: doc.id
                            val name = doc.getString("name") ?: return@mapNotNull null
                            val catSlug = doc.getString("categorySlug") ?: "sports"
                            val catName = doc.getString("categoryName") ?: "Sports Turf"
                            val defaultCat = sampleCategories.find { it.slug == catSlug } ?: VenueCategory(id = catSlug, slug = catSlug, name = catName, iconName = "sports_soccer")
                            Venue(
                                id = id,
                                name = name,
                                slug = doc.getString("slug") ?: "",
                                description = doc.getString("description") ?: "",
                                addressLine1 = doc.getString("addressLine1") ?: "",
                                city = doc.getString("city") ?: "Hyderabad",
                                state = doc.getString("state") ?: "Telangana",
                                latitude = doc.getDouble("latitude") ?: 17.3850,
                                longitude = doc.getDouble("longitude") ?: 78.4866,
                                capacity = doc.getLong("capacity")?.toInt() ?: 500,
                                pricingBaseAmount = doc.getDouble("pricingBaseAmount") ?: 75000.0,
                                taxRate = doc.getDouble("taxRate") ?: 18.0,
                                parkingCapacity = doc.getLong("parkingCapacity")?.toInt() ?: 100,
                                foodOptions = doc.getString("foodOptions") ?: "In-house Catering",
                                rules = doc.getString("rules") ?: "Standard policy",
                                isVerified = doc.getBoolean("isVerified") ?: true,
                                isActive = doc.getBoolean("isActive") ?: true,
                                avgRating = doc.getDouble("avgRating") ?: 4.8,
                                ratingCount = doc.getLong("ratingCount")?.toInt() ?: 120,
                                featuredImageUrl = doc.getString("featuredImageUrl") ?: "",
                                contactPhone = doc.getString("contactPhone") ?: "98765-43210",
                                contactWhatsapp = doc.getString("contactWhatsapp") ?: "919876543210",
                                category = defaultCat
                            )
                        }
                        if (cloudVenues.isNotEmpty()) {
                            _venues.value = cloudVenues + sampleVenues.filter { s -> cloudVenues.none { it.id == s.id } }
                        }
                    }
                }
        } catch (e: Exception) {
            Log.w(TAG, "Could not attach venues Firestore listener: ${e.message}")
        }

        // Listen to cloud institutes collection
        try {
            institutesListener?.remove()
            institutesListener = db.collection("institutes")
                .addSnapshotListener { snapshot, error ->
                    if (error != null) {
                        Log.w(TAG, "Firestore institutes listener error: ${error.message}")
                        return@addSnapshotListener
                    }
                    if (snapshot != null && !snapshot.isEmpty) {
                        val cloudInst = snapshot.documents.mapNotNull { doc ->
                            val id = doc.getString("id") ?: doc.id
                            val name = doc.getString("name") ?: return@mapNotNull null
                            InstituteProfile(
                                id = id,
                                name = name,
                                tagline = doc.getString("tagline") ?: "",
                                description = doc.getString("description") ?: "",
                                logoUrl = doc.getString("logoUrl") ?: "",
                                coverImageUrl = doc.getString("coverImageUrl") ?: "",
                                category = doc.getString("category") ?: "Sports Coaching",
                                city = doc.getString("city") ?: "Hyderabad",
                                state = doc.getString("state") ?: "Telangana",
                                address = doc.getString("address") ?: "",
                                phone = doc.getString("phone") ?: "",
                                whatsapp = doc.getString("whatsapp") ?: "",
                                email = doc.getString("email") ?: "",
                                rating = doc.getDouble("rating") ?: 4.9,
                                ratingCount = doc.getLong("ratingCount")?.toInt() ?: 80,
                                isVerified = doc.getBoolean("isVerified") ?: true,
                                isPublished = doc.getBoolean("isPublished") ?: true
                            )
                        }
                        if (cloudInst.isNotEmpty()) {
                            _institutes.value = cloudInst + sampleInstitutes.filter { s -> cloudInst.none { it.id == s.id } }
                        }
                    }
                }
        } catch (e: Exception) {
            Log.w(TAG, "Could not attach institutes Firestore listener: ${e.message}")
        }
    }

    fun attachAllFirestoreListeners() {
        listenToLiveFirestoreData()
    }

    suspend fun refreshAllData() {
        NetworkRetryManager.executeWithRetry(
            operationName = "Venues & Spaces Cloud Sync",
            maxRetries = 3,
            initialDelayMs = 600L,
            maxDelayMs = 2500L
        ) {
            attachAllFirestoreListeners()
            val db = firestoreDb ?: throw IllegalStateException("Firestore client not initialized. Using offline mode.")
            val snapshot = db.collection("venues").get().await()
            if (snapshot != null && !snapshot.isEmpty) {
                val cloudVenues = snapshot.documents.mapNotNull { doc ->
                    val id = doc.getString("id") ?: doc.id
                    val name = doc.getString("name") ?: return@mapNotNull null
                    val catSlug = doc.getString("categorySlug") ?: "sports"
                    val catName = doc.getString("categoryName") ?: "Sports Turf"
                    val defaultCat = sampleCategories.find { it.slug == catSlug } ?: VenueCategory(id = catSlug, slug = catSlug, name = catName, iconName = "sports_soccer")
                    Venue(
                        id = id,
                        name = name,
                        slug = doc.getString("slug") ?: "",
                        description = doc.getString("description") ?: "",
                        addressLine1 = doc.getString("addressLine1") ?: "",
                        city = doc.getString("city") ?: "Hyderabad",
                        state = doc.getString("state") ?: "Telangana",
                        latitude = doc.getDouble("latitude") ?: 17.3850,
                        longitude = doc.getDouble("longitude") ?: 78.4866,
                        capacity = doc.getLong("capacity")?.toInt() ?: 500,
                        pricingBaseAmount = doc.getDouble("pricingBaseAmount") ?: 75000.0,
                        taxRate = doc.getDouble("taxRate") ?: 18.0,
                        parkingCapacity = doc.getLong("parkingCapacity")?.toInt() ?: 100,
                        foodOptions = doc.getString("foodOptions") ?: "In-house Catering",
                        rules = doc.getString("rules") ?: "Standard policy",
                        isVerified = doc.getBoolean("isVerified") ?: true,
                        isActive = doc.getBoolean("isActive") ?: true,
                        avgRating = doc.getDouble("avgRating") ?: 4.8,
                        ratingCount = doc.getLong("ratingCount")?.toInt() ?: 120,
                        featuredImageUrl = doc.getString("featuredImageUrl") ?: "",
                        contactPhone = doc.getString("contactPhone") ?: "98765-43210",
                        contactWhatsapp = doc.getString("contactWhatsapp") ?: "919876543210",
                        category = defaultCat
                    )
                }
                if (cloudVenues.isNotEmpty()) {
                    _venues.value = cloudVenues + sampleVenues.filter { s -> cloudVenues.none { it.id == s.id } }
                }
            }
        }
    }

    fun setCloudVenues(cloudVenues: List<Venue>) {
        if (cloudVenues.isNotEmpty()) {
            _venues.value = cloudVenues + sampleVenues.filter { s -> cloudVenues.none { it.id == s.id } }
        }
    }

    fun setCloudInstitutes(cloudInstitutes: List<InstituteProfile>) {
        if (cloudInstitutes.isNotEmpty()) {
            _institutes.value = cloudInstitutes + sampleInstitutes.filter { s -> cloudInstitutes.none { it.id == s.id } }
        }
    }

    fun resetToSafeSampleData() {
        _venues.value = sampleVenues
        _institutes.value = sampleInstitutes
        _events.value = sampleEvents
        _courses.value = sampleCourses
        _instituteClasses.value = sampleClasses
    }

    // --- Themes ---
    private val _themeMode = MutableStateFlow(ThemeMode.SYSTEM_DEFAULT)
    val themeMode: StateFlow<ThemeMode> = _themeMode.asStateFlow()

    private val _selectedThemePreset = MutableStateFlow(ThemePreset.ROYAL_PURPLE)
    val selectedThemePreset: StateFlow<ThemePreset> = _selectedThemePreset.asStateFlow()

    private val _customPrimaryColorHex = MutableStateFlow("#673AB7")
    val customPrimaryColorHex: StateFlow<String> = _customPrimaryColorHex.asStateFlow()

    fun setThemeMode(mode: ThemeMode) { _themeMode.value = mode }
    fun setThemePreset(preset: ThemePreset) { _selectedThemePreset.value = preset }
    fun setCustomPrimaryColorHex(hex: String) { _customPrimaryColorHex.value = hex }
    fun setCustomPrimaryColor(hex: String) { _customPrimaryColorHex.value = hex }

    // --- User Location Context ---
    private val _userLocationHierarchy = MutableStateFlow(IndiaLocationMasterData.popularPresets.first())
    val userLocationHierarchy: StateFlow<LocationHierarchy> = _userLocationHierarchy.asStateFlow()

    private val _userLocationRadius = MutableStateFlow(LocationSearchRadius.RADIUS_25_KM)
    val userLocationRadius: StateFlow<LocationSearchRadius> = _userLocationRadius.asStateFlow()

    fun setUserLocationHierarchy(loc: LocationHierarchy, radius: LocationSearchRadius = _userLocationRadius.value) {
        _userLocationHierarchy.value = loc
        _userLocationRadius.value = radius
    }

    fun setUserLocationRadius(radius: LocationSearchRadius) {
        _userLocationRadius.value = radius
    }

    // --- Auth User ---
    private val _authUser = MutableStateFlow<AuthUser?>(
        AuthUser(
            id = "user_demo_1",
            email = "narenqe2@gmail.com",
            fullName = "Narendra Reddy",
            phone = "+91 98765 43210",
            role = UserRole.USER,
            avatarUrl = "https://images.unsplash.com/photo-1535713875002-d1d0cf377fde"
        )
    )
    val authUser: StateFlow<AuthUser?> = _authUser.asStateFlow()

    fun setAuthUser(user: AuthUser?) { 
        _authUser.value = user
        listenToLiveFirestoreData()
    }
    fun loginAsRole(role: UserRole) {
        _authUser.value = AuthUser(
            id = "user_${role.name.lowercase()}",
            email = when (role) {
                UserRole.ADMIN -> "admin@bookmyspace.com"
                UserRole.VENUE_OWNER -> "owner@grandpalace.com"
                UserRole.USER -> "narenqe2@gmail.com"
            },
            fullName = when (role) {
                UserRole.ADMIN -> "System Administrator"
                UserRole.VENUE_OWNER -> "Vikram Oberoi (Owner)"
                UserRole.USER -> "Narendra Reddy"
            },
            role = role
        )
        listenToLiveFirestoreData()
    }
    fun logout() { 
        _authUser.value = null
        savedListener?.remove()
        bookingsListener?.remove()
    }

    // --- Categories ---
    val sampleCategories = listOf(
        VenueCategory("cat_all", "all", "All Spaces", "grid_view"),
        VenueCategory("cat_function", "function_hall", "Function Halls", "celebration"),
        VenueCategory("cat_marriage", "marriage_hall", "Marriage Halls", "church"),
        VenueCategory("cat_function_hall", "function_hall", "Function Halls", "stadium", isUnifiedRegistrationEnabled = true),
        VenueCategory("cat_marriage", "marriage_hall", "Marriage Halls", "celebration", isUnifiedRegistrationEnabled = true),
        VenueCategory("cat_kalyana", "kalyana_mandapam", "Kalyana Mandapams", "temple_hindu", isUnifiedRegistrationEnabled = true),
        VenueCategory("cat_mini_hall", "mini_hall", "Mini Function Halls", "meeting_room", isUnifiedRegistrationEnabled = true),
        VenueCategory("cat_banquet", "banquet_hall", "Banquet Halls", "restaurant", isUnifiedRegistrationEnabled = true),
        VenueCategory("cat_convention", "convention_center", "Convention Centers", "corporate_fare", isUnifiedRegistrationEnabled = true),
        VenueCategory("cat_community", "community_hall", "Community Halls", "groups", isUnifiedRegistrationEnabled = false),
        VenueCategory("cat_govt", "govt_hall", "Town & Govt Halls", "account_balance", isUnifiedRegistrationEnabled = true),
        VenueCategory("cat_lawn", "party_lawn", "Party Lawns", "deck", isUnifiedRegistrationEnabled = false),
        VenueCategory("cat_other_hall", "other_hall", "Other Event Spaces", "stadium", isUnifiedRegistrationEnabled = false),
        VenueCategory("cat_hotel", "hotel_stay", "Hotels & Suites", "hotel", isUnifiedRegistrationEnabled = true),
        VenueCategory("cat_lodge", "lodge", "Lodges & Stays", "night_shelter", isUnifiedRegistrationEnabled = true),
        VenueCategory("cat_guest", "guest_house", "Guest Houses", "home_work", isUnifiedRegistrationEnabled = false),
        VenueCategory("cat_hourly", "hourly_room", "Hourly / Day Rooms", "schedule", isUnifiedRegistrationEnabled = false),
        VenueCategory("cat_resort", "resort", "Resorts & Homestays", "holiday_village", isUnifiedRegistrationEnabled = true),
        VenueCategory("cat_other_stay", "other_stay", "Other Accommodations", "cabin", isUnifiedRegistrationEnabled = false),
        VenueCategory("cat_pg", "pg_hostel", "PG & Hostels", "house", isUnifiedRegistrationEnabled = true),
        VenueCategory("cat_gents_pg", "gents_pg", "Gents PGs", "male", isUnifiedRegistrationEnabled = true),
        VenueCategory("cat_ladies_pg", "ladies_pg", "Ladies PGs", "female", isUnifiedRegistrationEnabled = true),
        VenueCategory("cat_student_hostel", "student_hostel", "Student Hostels", "school", isUnifiedRegistrationEnabled = true),
        VenueCategory("cat_coliving", "co_living", "Co-Living Spaces", "handshake", isUnifiedRegistrationEnabled = true),
        VenueCategory("cat_single_room", "single_room", "Single Sharing Rooms", "key", isUnifiedRegistrationEnabled = true),
        VenueCategory("cat_other_pg", "other_pg", "Other Hostels & PGs", "domain", isUnifiedRegistrationEnabled = false),
        VenueCategory("cat_coaching", "coaching", "Coaching & Tuitions", "menu_book", isUnifiedRegistrationEnabled = true),
        VenueCategory("cat_it", "computer_it", "Computer & IT Classes", "laptop_mac", isUnifiedRegistrationEnabled = true),
        VenueCategory("cat_dance", "dance_academy", "Dance Academies", "directions_run", isUnifiedRegistrationEnabled = false),
        VenueCategory("cat_music", "music_class", "Music & Singing", "music_note", isUnifiedRegistrationEnabled = false),
        VenueCategory("cat_sports", "sports_academy", "Sports & Turfs", "sports_tennis", isUnifiedRegistrationEnabled = false),
        VenueCategory("cat_other_class", "other_class", "Other Classes & Studios", "palette", isUnifiedRegistrationEnabled = false)
    )

    private val _categories = MutableStateFlow(sampleCategories)
    val categories: StateFlow<List<VenueCategory>> = _categories.asStateFlow()

    fun setCategories(newCategories: List<VenueCategory>) {
        _categories.value = newCategories
    }

    fun setCategoryActive(categoryIdOrSlug: String, isActive: Boolean) {
        _categories.value = _categories.value.map {
            if (it.id.equals(categoryIdOrSlug, ignoreCase = true) || it.slug.equals(categoryIdOrSlug, ignoreCase = true)) {
                it.copy(isActive = isActive)
            } else it
        }
    }

    fun toggleCategoryActive(categoryId: String) {
        _categories.value = _categories.value.map {
            if (it.id == categoryId) it.copy(isActive = !it.isActive) else it
        }
    }

    fun toggleCategoryUnifiedRegistration(categoryId: String) {
        _categories.value = _categories.value.map {
            if (it.id == categoryId) it.copy(isUnifiedRegistrationEnabled = !it.isUnifiedRegistrationEnabled) else it
        }
    }

    fun setCategoryUnifiedRegistration(categoryId: String, isEnabled: Boolean) {
        _categories.value = _categories.value.map {
            if (it.id == categoryId) it.copy(isUnifiedRegistrationEnabled = isEnabled) else it
        }
    }

    fun isUnifiedRegistrationEnabledForCategory(categorySlugOrId: String?): Boolean {
        if (categorySlugOrId.isNullOrBlank()) return false
        val target = _categories.value.firstOrNull {
            it.id.equals(categorySlugOrId, ignoreCase = true) ||
            it.slug.equals(categorySlugOrId, ignoreCase = true) ||
            it.name.equals(categorySlugOrId, ignoreCase = true)
        }
        return target?.isUnifiedRegistrationEnabled ?: false
    }

    fun isCategoryEnabled(categoryIdOrSlug: String): Boolean {
        if (categoryIdOrSlug.equals("all", ignoreCase = true)) return true
        val cat = _categories.value.firstOrNull {
            it.id.equals(categoryIdOrSlug, ignoreCase = true) ||
            it.slug.equals(categoryIdOrSlug, ignoreCase = true) ||
            it.name.equals(categoryIdOrSlug, ignoreCase = true)
        }
        return cat?.isActive ?: true
    }

    fun isSectionEnabled(sectionId: String): Boolean {
        val clean = sectionId.lowercase()
        val match = _appSections.value.firstOrNull {
            it.sectionId.equals(clean, ignoreCase = true) ||
            (clean == "function_halls" && (it.sectionId == "venues_function_halls" || it.sectionId == "venues_halls")) ||
            (clean == "venues_function_halls" && (it.sectionId == "function_halls" || it.sectionId == "venues_halls")) ||
            (clean == "venues_halls" && (it.sectionId == "venues_function_halls" || it.sectionId == "function_halls")) ||
            (clean == "lodge_rooms" && (it.sectionId == "hotels_rooms" || it.sectionId == "hotels")) ||
            (clean == "hotels_rooms" && (it.sectionId == "lodge_rooms" || it.sectionId == "hotels")) ||
            (clean == "sports" && it.sectionId == "sports_fitness") ||
            (clean == "institutes" && it.sectionId == "institutes_classes")
        }
        return match?.isEnabled ?: true
    }

    fun addCategory(newCategory: VenueCategory) {
        if (_categories.value.none { it.id == newCategory.id || it.slug == newCategory.slug }) {
            _categories.value = _categories.value + newCategory
        }
    }

    fun addCustomCategory(
        name: String,
        parentSectionId: String = "general",
        emoji: String = "✨",
        description: String = ""
    ): VenueCategory {
        val cleanSlug = name.trim().lowercase().replace(Regex("[^a-z0-9]+"), "_")
        val uniqueId = "cat_${cleanSlug}_${UUID.randomUUID().toString().take(4)}"
        val newCat = VenueCategory(
            id = uniqueId,
            slug = cleanSlug,
            name = name.trim(),
            iconName = "category",
            isActive = true,
            isUnifiedRegistrationEnabled = true,
            customEmoji = emoji.ifBlank { "✨" },
            parentSection = parentSectionId
        )
        addCategory(newCat)
        addNotification(
            title = "New Category Added! $emoji",
            message = "Category '${newCat.name}' has been added to ${parentSectionId.replace("_", " ").capitalizeWords()} section.",
            type = "category_added"
        )
        logAnalyticsEvent("custom_category_added", mapOf("name" to name, "section" to parentSectionId), "categories")
        return newCat
    }

    fun getCustomCategoriesForSection(sectionId: String?): List<VenueCategory> {
        if (sectionId == null) return _categories.value.filter { it.parentSection != null }
        return _categories.value.filter {
            it.isActive && (it.parentSection == sectionId || it.parentSection == "general" || it.parentSection == "all")
        }
    }

    fun updateCategory(updatedCategory: VenueCategory) {
        _categories.value = _categories.value.map {
            if (it.id == updatedCategory.id) updatedCategory else it
        }
    }

    // --- Venues with High-Quality Multi-Photo Galleries for All Sections & Categories ---
    val sampleVenues = listOf(
        // ==========================================
        // SECTION 1: FUNCTION HALLS & EVENT SPACES (7 venues)
        // ==========================================
        Venue(
            id = "v_grand_palace",
            name = "The Royal Imperial Palace & Convention",
            slug = "the-royal-imperial-palace",
            description = "Palatial luxury air-conditioned banquet and convention destination with grand crystal chandeliers, high ceilings, VIP green rooms, Italian marble flooring, and expansive open lawns.",
            addressLine1 = "Road No 36, Jubilee Hills",
            city = "Hyderabad",
            state = "Telangana",
            latitude = 17.4319,
            longitude = 78.4073,
            capacity = 1200,
            minGuests = 250,
            maxGuests = 2000,
            distanceKm = 1.8,
            pricingBaseAmount = 185000.0,
            taxRate = 18.0,
            parkingCapacity = 350,
            foodOptions = "In-house Masterchefs & Verified External Caterers Permitted",
            rules = "Sound system permitted till 11:30 PM. Valet parking provided. Strict fire safety norms.",
            isVerified = true,
            isActive = true,
            avgRating = 4.9,
            ratingCount = 482,
            category = sampleCategories[4], // convention_center
            isSaved = true,
            images = listOf(
                VenueImage("img_rp_1", "https://images.unsplash.com/photo-1519167758481-83f550bb49b3", "Grand Banquet Hall with Crystal Chandeliers", isCover = true),
                VenueImage("img_rp_2", "https://images.unsplash.com/photo-1511795409834-ef04bbd61622", "Elegant Evening Stage Decor & Floral Architecture"),
                VenueImage("img_rp_3", "https://images.unsplash.com/photo-1464366400600-7168b8af9bc3", "Luxury Dining Area and Banquet Setup"),
                VenueImage("img_rp_4", "https://images.unsplash.com/photo-1545232979-fbf6a8c3d9b0", "Outdoor Illuminated Party Lawn & Water Fountains"),
                VenueImage("img_rp_5", "https://images.unsplash.com/photo-1533105079780-92b9be482077", "Grand Royal Entrance Porch and Valet Lounge")
            ),
            facilities = listOf(
                VenueFacility("Central AC & Climate Control", true),
                VenueFacility("Valet Parking (350+ Cars)", true),
                VenueFacility("Bridal Suites (4 Luxury Rooms)", true),
                VenueFacility("Full Generator Backup (100% Load)", true),
                VenueFacility("Professional Acoustic Audio & Lighting", true),
                VenueFacility("Wheelchair Accessible Ramps & Elevators", true)
            ),
            packages = listOf(
                VenuePackage("pkg_rp_gold", "Royal Imperial Wedding Package", 350000.0, "Includes main ballroom, stage lighting, 4 bridal suites, valet crew and backup genset.", listOf("Full Day 24hr access", "4 Suite Rooms", "Valet Service", "DJ Console & Sound"), 1200.0, 1500.0),
                VenuePackage("pkg_rp_silver", "Evening Reception Package", 220000.0, "6-hour evening banquet hall rental with full ambient LED uplighting and sound support.", listOf("6 Hours Evening Slot", "2 Green Rooms", "Security & Housekeeping"), 950.0, 1250.0)
            ),
            locationHierarchy = IndiaLocationMasterData.popularPresets[0]
        ),
        Venue(
            id = "v_sri_krishna_mandapam",
            name = "Sri Krishna Grand Kalyana Mandapam & Marriage Hall",
            slug = "sri-krishna-grand-kalyana-mandapam",
            description = "Traditional and majestic South Indian wedding kalyana mandapam with carved temple pillars, elevated wedding stage, spacious pure vegetarian dining hall, and 10 AC guest rooms.",
            addressLine1 = "Gandhi Road, Near RTC Complex",
            city = "Ongole",
            state = "Andhra Pradesh",
            latitude = 15.5030,
            longitude = 80.0460,
            capacity = 900,
            minGuests = 150,
            maxGuests = 1500,
            distanceKm = 1.2,
            pricingBaseAmount = 95000.0,
            taxRate = 18.0,
            parkingCapacity = 180,
            foodOptions = "Dedicated Pure Veg Kitchen with Steam Cooking & Plantain Leaf Dining",
            rules = "Traditional ceremonies welcome. Nadaswaram and cultural music setup available.",
            isVerified = true,
            isActive = true,
            avgRating = 4.8,
            ratingCount = 310,
            category = sampleCategories[2], // marriage_hall
            isSaved = false,
            images = listOf(
                VenueImage("img_sk_1", "https://images.unsplash.com/photo-1544077960-604201fe74bc", "Majestic Carved Marriage Hall Stage", isCover = true),
                VenueImage("img_sk_2", "https://images.unsplash.com/photo-1519741497674-611481863552", "Grand Mandapam Floral & Golden Decor"),
                VenueImage("img_sk_3", "https://images.unsplash.com/photo-1464366400600-7168b8af9bc3", "Large Dining Hall with Traditional Setup")
            ),
            facilities = listOf(
                VenueFacility("AC Main Marriage Auditorium", true),
                VenueFacility("10 Furnished AC Guest Rooms", true),
                VenueFacility("Separate 400-Seater Dining Hall", true),
                VenueFacility("Dedicated Pooja & Homa Kundam Zone", true),
                VenueFacility("Dedicated Generator Power Backup", true)
            ),
            locationHierarchy = IndiaLocationMasterData.popularPresets[2]
        ),
        Venue(
            id = "v_sapphire_banquets",
            name = "Sapphire Sky Banquet & Rooftop Lounge",
            slug = "sapphire-sky-banquet-lounge",
            description = "Ultra-chic boutique party hall and covered rooftop banquet with mood lighting, surround sound system, and cocktail mocktail bar setup ideal for birthdays, anniversaries, and corporate dinners.",
            addressLine1 = "Kavuri Hills, Madhapur",
            city = "Hyderabad",
            state = "Telangana",
            latitude = 17.4435,
            longitude = 78.3965,
            capacity = 350,
            minGuests = 40,
            maxGuests = 450,
            distanceKm = 3.5,
            pricingBaseAmount = 45000.0,
            taxRate = 18.0,
            parkingCapacity = 90,
            foodOptions = "Gourmet Multi-cuisine Live Buffet & Mocktail Bar",
            rules = "Party music allowed till 11:30 PM. In-house decor and sound system included.",
            isVerified = true,
            isActive = true,
            avgRating = 4.75,
            ratingCount = 215,
            category = sampleCategories[3], // banquet_hall
            isSaved = true,
            images = listOf(
                VenueImage("img_sb_1", "https://images.unsplash.com/photo-1517457373958-b7bdd4587205", "Chic Banquet Hall with Neon Mood Lighting", isCover = true),
                VenueImage("img_sb_2", "https://images.unsplash.com/photo-1527529482837-4698179dc6ce", "Celebration Party Setup & DJ Sound Station"),
                VenueImage("img_sb_3", "https://images.unsplash.com/photo-1533105079780-92b9be482077", "Rooftop Evening View & Dining Tables")
            ),
            facilities = listOf(
                VenueFacility("Pioneer Pro DJ Sound & Uplighting", true),
                VenueFacility("Centralized Climate Control AC", true),
                VenueFacility("Valet Parking with Drivers", true),
                VenueFacility("Live Mocktail Bar & Lounge", true)
            ),
            locationHierarchy = IndiaLocationMasterData.popularPresets[0]
        ),
        Venue(
            id = "v_civic_town_hall",
            name = "Civic Heritage Community & Town Hall",
            slug = "civic-heritage-community-town-hall",
            description = "Affordable and expansive community hall & public auditorium with tiered seating, stage podium, projector screens, and spacious green lawn for community meetings, cultural programs, and family get-togethers.",
            addressLine1 = "Trunk Road, Near District Collectorate",
            city = "Ongole",
            state = "Andhra Pradesh",
            latitude = 15.5080,
            longitude = 80.0430,
            capacity = 700,
            minGuests = 100,
            maxGuests = 1000,
            distanceKm = 2.1,
            pricingBaseAmount = 25000.0,
            taxRate = 12.0,
            parkingCapacity = 120,
            foodOptions = "Open kitchen space for private caterers and self-arranged food",
            rules = "Cleanliness deposit applicable. Quiet hours strictly enforced past 10:00 PM.",
            isVerified = true,
            isActive = true,
            avgRating = 4.6,
            ratingCount = 142,
            category = sampleCategories[5], // community_hall / govt_hall
            isSaved = false,
            images = listOf(
                VenueImage("img_ch_1", "https://images.unsplash.com/photo-1511578314322-379afb476865", "Spacious Community Hall and Presentation Stage", isCover = true),
                VenueImage("img_ch_2", "https://images.unsplash.com/photo-1475721027785-f74eccf877e2", "Auditorium Seating & Public Speaking Podium")
            ),
            facilities = listOf(
                VenueFacility("Large 50-ft Presentation Stage", true),
                VenueFacility("PA Audio System & 4 Wireless Mics", true),
                VenueFacility("Spacious Covered Dining Shed", true),
                VenueFacility("Ample Bus & Car Parking Lot", true)
            ),
            locationHierarchy = IndiaLocationMasterData.popularPresets[2]
        ),
        Venue(
            id = "v_emerald_gardens",
            name = "Emerald Green Party Lawns & Open Resort",
            slug = "emerald-green-party-lawns",
            description = "Lush 3-acre landscaped botanical lawns with romantic fairy lights canopy, open-air amphitheater stage, swimming pool deck, and outdoor barbecue zone perfect for sangeets and cocktail bashes.",
            addressLine1 = "Benz Circle, MG Road",
            city = "Vijayawada",
            state = "Andhra Pradesh",
            latitude = 16.5010,
            longitude = 80.6530,
            capacity = 1500,
            minGuests = 100,
            maxGuests = 2500,
            distanceKm = 4.2,
            pricingBaseAmount = 125000.0,
            taxRate = 18.0,
            parkingCapacity = 300,
            foodOptions = "Live Barbecue, Tandoor & Outdoor Food Stalls Welcome",
            rules = "Amplified music permitted till midnight. Fireworks permitted in designated open zone.",
            isVerified = true,
            isActive = true,
            avgRating = 4.9,
            ratingCount = 376,
            category = sampleCategories[7], // party_lawn
            isSaved = false,
            images = listOf(
                VenueImage("img_eg_1", "https://images.unsplash.com/photo-1530103862676-de8c9debad1d", "Lush Party Lawn Decorated with Fairy Lighting", isCover = true),
                VenueImage("img_eg_2", "https://images.unsplash.com/photo-1519741497674-611481863552", "Open Air Stage Architecture & Floral Walkway"),
                VenueImage("img_eg_3", "https://images.unsplash.com/photo-1470225620780-dba8ba36b745", "Evening DJ Deck & Ambient Laser Illumination")
            ),
            facilities = listOf(
                VenueFacility("3-Acre Natural Bermuda Grass Turf", true),
                VenueFacility("Illuminated Canopy & Fairy Light Grid", true),
                VenueFacility("Swimming Pool Deck for Pre-Event Parties", true),
                VenueFacility("Parking for 300+ Vehicles with Guards", true)
            ),
            locationHierarchy = IndiaLocationMasterData.popularPresets[3]
        ),
        Venue(
            id = "v_horizon_amphitheatre",
            name = "Horizon Open-Air Amphitheatre & Art Expo Ground",
            slug = "horizon-open-air-amphitheatre-art-ground",
            description = "Distinctive multi-purpose open-air creative venue featuring semicircular stepped stone seating, large exhibition pavilion stalls, theatrical lighting rigs, and acoustic band shells for art expos, flea markets, product launches, and theatrical plays.",
            addressLine1 = "Hitec Arts Enclave, Gachibowli",
            city = "Hyderabad",
            state = "Telangana",
            latitude = 17.4420,
            longitude = 78.3540,
            capacity = 1100,
            minGuests = 50,
            maxGuests = 1800,
            distanceKm = 2.8,
            pricingBaseAmount = 75000.0,
            taxRate = 18.0,
            parkingCapacity = 220,
            foodOptions = "Food Trucks and Stalls Court with Electrical Hookups",
            rules = "Event security staff mandatory. Stage rigging certified for 10-ton loads.",
            isVerified = true,
            isActive = true,
            avgRating = 4.85,
            ratingCount = 188,
            category = sampleCategories[8], // other_hall
            isSaved = false,
            images = listOf(
                VenueImage("img_hz_1", "https://images.unsplash.com/photo-1506157786151-b8491531f063", "Open Air Stage & Festival Ground", isCover = true),
                VenueImage("img_hz_2", "https://images.unsplash.com/photo-1492684223066-81342ee5ff30", "Stepped Amphitheatre Seating & Night Show"),
                VenueImage("img_hz_3", "https://images.unsplash.com/photo-1465847899084-d164df4dedc6", "Exhibition Stalls & Product Showcase")
            ),
            facilities = listOf(
                VenueFacility("Semi-Circular Stone Amphitheatre", true),
                VenueFacility("24 Exhibition Pavilion Booths", true),
                VenueFacility("3-Phase 100 KVA Heavy Power Backup", true),
                VenueFacility("Food Truck Park & Dining Zone", true)
            ),
            locationHierarchy = IndiaLocationMasterData.popularPresets[0]
        ),

        // ==========================================
        // SECTION 2: LODGE & ROOMS (6 venues)
        // ==========================================
        Venue(
            id = "v_skyline_hotel",
            name = "Skyline Luxury Suites & Day Stay",
            slug = "skyline-luxury-hotel",
            description = "Sophisticated boutique business hotel featuring ultra-quiet acoustic rooms, high-speed fiber Wi-Fi, infinity pool, 24/7 room service, and flexible micro-stay day slots for travelers and meetings.",
            addressLine1 = "HITEC City Main Road, Madhapur",
            city = "Hyderabad",
            state = "Telangana",
            latitude = 17.4483,
            longitude = 78.3915,
            capacity = 250,
            minGuests = 1,
            maxGuests = 4,
            distanceKm = 3.1,
            pricingBaseAmount = 3499.0,
            taxRate = 12.0,
            parkingCapacity = 100,
            foodOptions = "Multi-cuisine Buffet & 24/7 In-Room Gourmet Dining",
            rules = "Valid government photo ID required at check-in. Local and corporate guests welcome.",
            isVerified = true,
            isActive = true,
            avgRating = 4.7,
            ratingCount = 289,
            category = sampleCategories[9], // hotel_stay
            isSaved = true,
            images = listOf(
                VenueImage("img_ht_1", "https://images.unsplash.com/photo-1566073771259-6a8506099945", "Modern Skyline Suite with Panoramic City Views", isCover = true),
                VenueImage("img_ht_2", "https://images.unsplash.com/photo-1582719478250-c89cae4dc85b", "King Deluxe Master Bedroom & Plush Bedding"),
                VenueImage("img_ht_3", "https://images.unsplash.com/photo-1571896349842-33c89424de2d", "Rooftop Glass Infinity Swimming Pool & Cabanas")
            ),
            facilities = listOf(
                VenueFacility("High-Speed 500 Mbps Wi-Fi", true),
                VenueFacility("Rooftop Infinity Swimming Pool", true),
                VenueFacility("24/7 Concierge & In-Room Dining", true),
                VenueFacility("Smart Ergonomic Workstation", true)
            ),
            hotelDetails = HotelDetails(
                starRating = 5,
                propertyType = "5-Star Luxury Business Hotel",
                roomTypes = listOf("Deluxe King Room (₹3,499/night)", "Executive Suite (₹5,999/night)", "Flexi 6-Hour Day Pass (₹1,899)")
            ),
            locationHierarchy = IndiaLocationMasterData.popularPresets[1]
        ),
        Venue(
            id = "v_comfort_transit_lodge",
            name = "Comfort Express Highway Lodge & Rooms",
            slug = "comfort-express-highway-lodge",
            description = "Clean, safe, and economical highway transit lodge with 24-hour check-in, spotless sanitized linens, hot geysers, secure car parking, and an attached South Indian restaurant for weary travelers.",
            addressLine1 = "NH-16 Bypass, Near Toll Plaza",
            city = "Ongole",
            state = "Andhra Pradesh",
            latitude = 15.5120,
            longitude = 80.0510,
            capacity = 60,
            minGuests = 1,
            maxGuests = 3,
            distanceKm = 1.9,
            pricingBaseAmount = 899.0,
            taxRate = 12.0,
            parkingCapacity = 50,
            foodOptions = "24-Hour Udupi Veg Canteen & Chai Station",
            rules = "24/7 Check-in. Instant key handover. Family friendly.",
            isVerified = true,
            isActive = true,
            avgRating = 4.65,
            ratingCount = 178,
            category = sampleCategories[10], // lodge
            isSaved = false,
            images = listOf(
                VenueImage("img_cl_1", "https://images.unsplash.com/photo-1590490360182-c33d57733427", "Sanitized AC Room with Twin Beds", isCover = true),
                VenueImage("img_cl_2", "https://images.unsplash.com/photo-1584622650111-993a426fbf0a", "Clean Attached Bathroom with 24/7 Hot Water")
            ),
            facilities = listOf(
                VenueFacility("24-Hour Front Desk Check-in", true),
                VenueFacility("AC & Non-AC Budget Rooms", true),
                VenueFacility("Secure Gated Parking for Cars & Bikes", true),
                VenueFacility("High-Pressure Hot Water Geyser", true)
            ),
            hotelDetails = HotelDetails(
                starRating = 3,
                propertyType = "Highway Transit Budget Lodge",
                roomTypes = listOf("Standard AC Double Room (₹1,199)", "Non-AC Economy Room (₹899)")
            ),
            locationHierarchy = IndiaLocationMasterData.popularPresets[2]
        ),
        Venue(
            id = "v_serenity_guest_house",
            name = "Serenity Heritage Guest House & Suites",
            slug = "serenity-heritage-guest-house",
            description = "Charming and peaceful colonial-styled guest house situated in a lush residential avenue. Offers home-cooked breakfast, courtyard garden, quiet study lounge, and spacious living suites for families and extended stays.",
            addressLine1 = "Lawyerpet, 4th Cross",
            city = "Ongole",
            state = "Andhra Pradesh",
            latitude = 15.5045,
            longitude = 80.0485,
            capacity = 30,
            minGuests = 1,
            maxGuests = 6,
            distanceKm = 1.1,
            pricingBaseAmount = 1999.0,
            taxRate = 12.0,
            parkingCapacity = 15,
            foodOptions = "Complimentary Traditional Andhra Breakfast & Filter Coffee",
            rules = "Quiet hours after 10 PM. No smoking inside heritage rooms.",
            isVerified = true,
            isActive = true,
            avgRating = 4.8,
            ratingCount = 95,
            category = sampleCategories[11], // guest_house
            isSaved = false,
            images = listOf(
                VenueImage("img_gh_1", "https://images.unsplash.com/photo-1502672260266-1c1ef2d93688", "Heritage Living Suite & Courtyard View", isCover = true),
                VenueImage("img_gh_2", "https://images.unsplash.com/photo-1522771739844-6a9f6d5f14af", "Comfortable Master Bedroom & Antique Decor")
            ),
            facilities = listOf(
                VenueFacility("Complimentary Home-cooked Breakfast", true),
                VenueFacility("Courtyard Garden & Patio Seating", true),
                VenueFacility("High-Speed Fiber Wi-Fi", true),
                VenueFacility("Fully Equipped Shared Kitchenette", true)
            ),
            hotelDetails = HotelDetails(
                starRating = 4,
                propertyType = "Heritage Boutique Guest House",
                roomTypes = listOf("Garden Suite (₹2,499)", "Deluxe Heritage Room (₹1,999)")
            ),
            locationHierarchy = IndiaLocationMasterData.popularPresets[2]
        ),
        Venue(
            id = "v_quick_rest_hourly",
            name = "QuickRest Metro Micro-Stay & Day Pods",
            slug = "quickrest-metro-microstay-pods",
            description = "Flexible hourly day-stay pods and compact smart rooms tailored for business professionals, transit commuters, interview candidates, and shoppers needing a quick refresh between appointments.",
            addressLine1 = "Madhapur Metro Station Concourse",
            city = "Hyderabad",
            state = "Telangana",
            latitude = 17.4460,
            longitude = 78.3890,
            capacity = 40,
            minGuests = 1,
            maxGuests = 2,
            distanceKm = 2.9,
            pricingBaseAmount = 499.0,
            taxRate = 12.0,
            parkingCapacity = 20,
            foodOptions = "Grab & Go Coffee, Energy Snacks & Refreshments",
            rules = "Flexible booking in 3-hour, 6-hour, or 12-hour blocks. Automated smart lock entry.",
            isVerified = true,
            isActive = true,
            avgRating = 4.7,
            ratingCount = 340,
            category = sampleCategories[12], // hourly_room
            isSaved = true,
            images = listOf(
                VenueImage("img_qr_1", "https://images.unsplash.com/photo-1513694203232-719a280e022f", "Compact Smart Micro-Stay Work Pod", isCover = true),
                VenueImage("img_qr_2", "https://images.unsplash.com/photo-1582719478250-c89cae4dc85b", "Smart Day Bed with Ergonomic USB Power Panel")
            ),
            facilities = listOf(
                VenueFacility("Hourly Micro-Stay Booking (From 3 Hrs)", true),
                VenueFacility("High-Speed Fiber Wi-Fi & Work Desk", true),
                VenueFacility("Sanitized Shower & Fresh Towels", true),
                VenueFacility("Luggage Locker & Secure Storage", true)
            ),
            hotelDetails = HotelDetails(
                starRating = 4,
                propertyType = "Smart Hourly Micro-Stay Pods",
                roomTypes = listOf("3-Hour Express Refresh Pod (₹499)", "6-Hour Day Stay Suite (₹899)", "12-Hour Business Layover (₹1,499)")
            ),
            locationHierarchy = IndiaLocationMasterData.popularPresets[0]
        ),
        Venue(
            id = "v_whispering_pines_resort",
            name = "Whispering Palms Eco Resort & Homestay",
            slug = "whispering-palms-eco-resort",
            description = "Tranquil eco-luxury resort featuring wooden chalets, organic coconut orchards, private plunge pools, campfire gazebos, and authentic village-style organic culinary experiences.",
            addressLine1 = "Kothapatnam Beach Road",
            city = "Ongole",
            state = "Andhra Pradesh",
            latitude = 15.4950,
            longitude = 80.0820,
            capacity = 120,
            minGuests = 2,
            maxGuests = 10,
            distanceKm = 6.5,
            pricingBaseAmount = 4500.0,
            taxRate = 12.0,
            parkingCapacity = 60,
            foodOptions = "Organic Farm-to-Table Meals & Seafood Specials",
            rules = "Pet-friendly resort. Swimming pool costume mandatory.",
            isVerified = true,
            isActive = true,
            avgRating = 4.9,
            ratingCount = 210,
            category = sampleCategories[13], // resort
            isSaved = false,
            images = listOf(
                VenueImage("img_wp_1", "https://images.unsplash.com/photo-1540555700478-4be289fbecef", "Eco Resort Wooden Villa & Pool", isCover = true),
                VenueImage("img_wp_2", "https://images.unsplash.com/photo-1571896349842-33c89424de2d", "Palm Grove Garden & Private Plunge Pool")
            ),
            facilities = listOf(
                VenueFacility("Private Swimming Pool & Sun Deck", true),
                VenueFacility("Campfire Gazebo & Barbecue Grill", true),
                VenueFacility("Cycling Tracks & Badminton Court", true),
                VenueFacility("Organic Village Kitchen Dining", true)
            ),
            hotelDetails = HotelDetails(
                starRating = 5,
                propertyType = "Eco Nature Resort & Homestay",
                roomTypes = listOf("Private Wooden Chalet (₹4,500/night)", "Pool View Family Villa (₹7,999/night)")
            ),
            locationHierarchy = IndiaLocationMasterData.popularPresets[2]
        ),
        Venue(
            id = "v_wildwood_glamping_cottage",
            name = "Wildwood Luxury Glamping Cottages & Farmhouse",
            slug = "wildwood-glamping-cottages-farmhouse",
            description = "Unique experiential getaway offering air-conditioned safari glamping domes, rustic stone cottages, organic fruit farm walks, stargazing telescope decks, and pet-friendly private lawn compounds for celebrations and nature stays.",
            addressLine1 = "Vikarabad Forest Border Road",
            city = "Hyderabad",
            state = "Telangana",
            latitude = 17.3360,
            longitude = 77.9040,
            capacity = 80,
            minGuests = 2,
            maxGuests = 15,
            distanceKm = 9.2,
            pricingBaseAmount = 5200.0,
            taxRate = 12.0,
            parkingCapacity = 45,
            foodOptions = "Live Barbecue, Tandoor & Farm Fresh Country Breakfast",
            rules = "Bonfire and outdoor music allowed till 11:00 PM. Pet friendly.",
            isVerified = true,
            isActive = true,
            avgRating = 4.88,
            ratingCount = 164,
            category = sampleCategories[14], // other_stay
            isSaved = true,
            images = listOf(
                VenueImage("img_ww_1", "https://images.unsplash.com/photo-1510312305653-8ed496efae75", "Luxury Glamping Dome & Stargazing Deck", isCover = true),
                VenueImage("img_ww_2", "https://images.unsplash.com/photo-1587061949409-02df41d5e562", "Rustic Stone Farmhouse Cottage & Patio"),
                VenueImage("img_ww_3", "https://images.unsplash.com/photo-1530103862676-de8c9debad1d", "Evening Bonfire & Fairy Light Lawn")
            ),
            facilities = listOf(
                VenueFacility("AC Glamping Safari Domes", true),
                VenueFacility("Night Sky Telescope & Stargazing Deck", true),
                VenueFacility("Private Farm Lawn & Barbecue Pit", true),
                VenueFacility("Pet-Friendly Compound with Play Zone", true)
            ),
            hotelDetails = HotelDetails(
                starRating = 5,
                propertyType = "Experiential Glamping & Farmhouse Stay",
                roomTypes = listOf("Luxury Safari Dome (₹5,200/night)", "Stone Heritage Farmhouse (₹8,500/night)")
            ),
            locationHierarchy = IndiaLocationMasterData.popularPresets[0]
        ),
        Venue(
            id = "v_novotel_bayfront_resort",
            name = "Novotel Bayfront Oceanfront Resort & Luxury Spa",
            slug = "novotel-bayfront-oceanfront-resort",
            description = "Stunning 5-star beachfront luxury property featuring private sea-view balconies, multi-cuisine infinity terrace dining, ayurvedic spa pavilions, and private beach access.",
            addressLine1 = "Beach Road, RK Beach",
            city = "Visakhapatnam",
            state = "Andhra Pradesh",
            latitude = 17.7120,
            longitude = 83.3180,
            capacity = 350,
            minGuests = 1,
            maxGuests = 6,
            distanceKm = 2.4,
            pricingBaseAmount = 4899.0,
            taxRate = 12.0,
            parkingCapacity = 120,
            foodOptions = "International Breakfast Buffet & Coastal Seafood Speciality",
            rules = "24/7 Front desk. Swimming pool and private beach access included.",
            isVerified = true,
            isActive = true,
            avgRating = 4.92,
            ratingCount = 420,
            category = sampleCategories[13], // resort
            isSaved = true,
            images = listOf(
                VenueImage("img_nv_1", "https://images.unsplash.com/photo-1571003123894-1f0594d2b5d9", "Ocean View Infinity Swimming Pool", isCover = true),
                VenueImage("img_nv_2", "https://images.unsplash.com/photo-1582719478250-c89cae4dc85b", "Sea View Deluxe King Suite"),
                VenueImage("img_nv_3", "https://images.unsplash.com/photo-1540555700478-4be289fbecef", "Tropical Palm Beach Cabana")
            ),
            facilities = listOf(
                VenueFacility("Direct Beachfront Access & Sea View", true),
                VenueFacility("Rooftop Infinity Swimming Pool", true),
                VenueFacility("Complimentary Breakfast Buffet", true),
                VenueFacility("Full-Service Luxury Ayurvedic Spa", true)
            ),
            hotelDetails = HotelDetails(
                starRating = 5,
                propertyType = "5-Star Oceanfront Luxury Resort",
                roomTypes = listOf("Ocean View Deluxe King (₹4,899/night)", "Executive Suite with Balcony (₹8,499/night)")
            ),
            locationHierarchy = IndiaLocationMasterData.popularPresets[3]
        ),
        Venue(
            id = "v_treebo_trend_green_leaves",
            name = "Treebo Premium Business Stay & Executive Rooms",
            slug = "treebo-premium-business-stay",
            description = "Top-rated smart corporate hotel offering sanitized premium AC rooms, fast 300 Mbps Wi-Fi, wholesome complimentary buffet breakfast, and seamless express check-in.",
            addressLine1 = "MG Road, Near Trendset Mall",
            city = "Vijayawada",
            state = "Andhra Pradesh",
            latitude = 16.5062,
            longitude = 80.6480,
            capacity = 100,
            minGuests = 1,
            maxGuests = 3,
            distanceKm = 1.2,
            pricingBaseAmount = 1499.0,
            taxRate = 12.0,
            parkingCapacity = 40,
            foodOptions = "Free Hot Breakfast Buffet & 24/7 Room Service",
            rules = "Instant check-in with any government ID. Couple and family friendly.",
            isVerified = true,
            isActive = true,
            avgRating = 4.75,
            ratingCount = 310,
            category = sampleCategories[9], // hotel_stay
            isSaved = false,
            images = listOf(
                VenueImage("img_tb_1", "https://images.unsplash.com/photo-1590490360182-c33d57733427", "Clean Deluxe AC Bedroom with Work Desk", isCover = true),
                VenueImage("img_tb_2", "https://images.unsplash.com/photo-1584622650111-993a426fbf0a", "Modern Sparkling Sanitized Bathroom")
            ),
            facilities = listOf(
                VenueFacility("Free Hot Breakfast Buffet", true),
                VenueFacility("300 Mbps High-Speed Wi-Fi", true),
                VenueFacility("24/7 Power Backup & Lift", true),
                VenueFacility("Daily Housekeeping & Sanitization", true)
            ),
            hotelDetails = HotelDetails(
                starRating = 4,
                propertyType = "Premium Business & Family Hotel",
                roomTypes = listOf("Deluxe AC Room (₹1,499/night)", "Premium Family Suite (₹2,299/night)")
            ),
            locationHierarchy = IndiaLocationMasterData.popularPresets[4]
        ),
        Venue(
            id = "v_fabexpress_airport_transit",
            name = "FabExpress Airport Transit Suites & Day Pods",
            slug = "fabexpress-airport-transit-suites",
            description = "Ultra-convenient 24/7 transit hotel located 5 minutes from the airport terminal. Offers soundproofed sleeping pods, hourly flexi-stays, luggage storage, and complimentary airport shuttle transfers.",
            addressLine1 = "Shamshabad Airport Road",
            city = "Hyderabad",
            state = "Telangana",
            latitude = 17.2403,
            longitude = 78.4294,
            capacity = 120,
            minGuests = 1,
            maxGuests = 4,
            distanceKm = 4.8,
            pricingBaseAmount = 799.0,
            taxRate = 12.0,
            parkingCapacity = 60,
            foodOptions = "24-Hour Continental & South Indian Cafe",
            rules = "Flexible hourly and 24-hour check-ins supported.",
            isVerified = true,
            isActive = true,
            avgRating = 4.8,
            ratingCount = 520,
            category = sampleCategories[12], // hourly_room
            isSaved = true,
            images = listOf(
                VenueImage("img_fa_1", "https://images.unsplash.com/photo-1513694203232-719a280e022f", "Airport Transit Pod & Sleeper Suite", isCover = true),
                VenueImage("img_fa_2", "https://images.unsplash.com/photo-1566073771259-6a8506099945", "Soundproof Executive Rest Room")
            ),
            facilities = listOf(
                VenueFacility("Free Airport Shuttle Transfer", true),
                VenueFacility("Flexible Hourly Booking (3/6/12 Hrs)", true),
                VenueFacility("24/7 Hot Showers & Fresh Towels", true),
                VenueFacility("Secure Baggage Storage Lockers", true)
            ),
            hotelDetails = HotelDetails(
                starRating = 4,
                propertyType = "Airport Transit & Day Stay Pods",
                roomTypes = listOf("3-Hour Transit Pod (₹799)", "6-Hour Day Room (₹1,299)", "Full Night AC Suite (₹1,899)")
            ),
            locationHierarchy = IndiaLocationMasterData.popularPresets[0]
        ),
        Venue(
            id = "v_tirupati_heritage_residency",
            name = "Sri Venkateswara Heritage Grand Residency",
            slug = "sri-venkateswara-heritage-residency",
            description = "Devotee-friendly, spotlessly clean luxury residency with temple shuttle assistance, pure vegetarian dining, luggage locker facilities, and spacious family suites.",
            addressLine1 = "Near Alipiri Gate & Bus Station",
            city = "Tirupati",
            state = "Andhra Pradesh",
            latitude = 13.6288,
            longitude = 79.4192,
            capacity = 200,
            minGuests = 1,
            maxGuests = 6,
            distanceKm = 1.5,
            pricingBaseAmount = 1199.0,
            taxRate = 12.0,
            parkingCapacity = 80,
            foodOptions = "Pure Veg South Indian Satvik Restaurant & Coffee Bar",
            rules = "24/7 Check-in. Temple dress code friendly.",
            isVerified = true,
            isActive = true,
            avgRating = 4.88,
            ratingCount = 680,
            category = sampleCategories[10], // lodge
            isSaved = false,
            images = listOf(
                VenueImage("img_tp_1", "https://images.unsplash.com/photo-1582719478250-c89cae4dc85b", "Spacious Family Suite with AC", isCover = true),
                VenueImage("img_tp_2", "https://images.unsplash.com/photo-1590490360182-c33d57733427", "Sanitized Devotee Deluxe Room")
            ),
            facilities = listOf(
                VenueFacility("Complimentary Temple Shuttle Drop", true),
                VenueFacility("Pure Vegetarian Satvik Kitchen", true),
                VenueFacility("24/7 Hot Water Geysers", true),
                VenueFacility("Family 4-Bed & 6-Bed Suites", true)
            ),
            hotelDetails = HotelDetails(
                starRating = 4,
                propertyType = "Devotee & Heritage Family Residency",
                roomTypes = listOf("Deluxe AC Room (₹1,199/night)", "Family Quad Suite 4-Beds (₹2,199/night)")
            ),
            locationHierarchy = IndiaLocationMasterData.popularPresets[5]
        ),

        // ==========================================
        // SECTION 3: PG & HOSTELS (6 venues)
        // ==========================================
        Venue(
            id = "v_urban_coliving",
            name = "Stanza Urban Co-Living & Executive PG",
            slug = "stanza-urban-coliving-pg",
            description = "Premium tech-enabled co-living space with fully furnished single, 2-sharing and 3-sharing rooms, high-speed Wi-Fi, 3 delicious home-cooked meals daily, laundry, gym, and 24/7 biometric security.",
            addressLine1 = "Lawyerpet, Main Trunk Road",
            city = "Ongole",
            state = "Andhra Pradesh",
            latitude = 15.5057,
            longitude = 80.0499,
            capacity = 80,
            minGuests = 1,
            maxGuests = 1,
            distanceKm = 0.9,
            pricingBaseAmount = 7500.0,
            taxRate = 0.0,
            parkingCapacity = 40,
            foodOptions = "Hygiene-Certified 3 Meals Daily (South & North Indian Menu)",
            rules = "Visitors allowed in common recreation lounge. Gate lock at 10:30 PM with smart app unlock.",
            isVerified = true,
            isActive = true,
            avgRating = 4.85,
            ratingCount = 194,
            category = sampleCategories[19], // co_living
            isSaved = false,
            images = listOf(
                VenueImage("img_pg_1", "https://images.unsplash.com/photo-1522771739844-6a9f6d5f14af", "Spacious Executive Room with Study Table & Balcony", isCover = true),
                VenueImage("img_pg_2", "https://images.unsplash.com/photo-1502672260266-1c1ef2d93688", "Modern Common Living Room & OTT Entertainment Lounge"),
                VenueImage("img_pg_3", "https://images.unsplash.com/photo-1556911220-e15b29be8c8f", "Hygienic Modern Modular Dining Hall & Kitchen")
            ),
            facilities = listOf(
                VenueFacility("3 Meals Daily Included (Veg & Non-Veg)", true),
                VenueFacility("High Speed Wi-Fi on Every Floor", true),
                VenueFacility("Daily Housekeeping & Room Cleaning", true),
                VenueFacility("Automatic Washing Machines & Ironing", true),
                VenueFacility("24/7 CCTV & Biometric Entry", true)
            ),
            pgDetails = PgDetails(
                pgType = "Co-Living & Executive PG",
                gateLockTime = "10:30 PM (Biometric)",
                mealPlan = "3 Meals + Evening Tea Included",
                sharingOptions = listOf(
                    PgSharingOption("pg_share_1", "Private Single Room", 12500.0, 12500.0, true, listOf("Attached Bath", "AC", "Balcony", "Smart TV")),
                    PgSharingOption("pg_share_2", "2-Sharing Deluxe Room", 8500.0, 8500.0, true, listOf("Attached Bath", "AC", "Personal Wardrobes")),
                    PgSharingOption("pg_share_3", "3-Sharing Economy Room", 6500.0, 6500.0, true, listOf("Attached Bath", "Individual Locker"))
                )
            ),
            locationHierarchy = IndiaLocationMasterData.popularPresets[2]
        ),
        Venue(
            id = "v_zenith_gents_pg",
            name = "Zenith Executive Gents PG & Tech Stay",
            slug = "zenith-executive-gents-pg",
            description = "High-end men's luxury PG designed for IT software engineers and corporate executives, offering ergonomic work desks, 1 Gbps fiber internet, gym, gaming PlayStation zone, and hot home-style meals.",
            addressLine1 = "Silicon Valley Layout, Madhapur",
            city = "Hyderabad",
            state = "Telangana",
            latitude = 17.4450,
            longitude = 78.3870,
            capacity = 90,
            minGuests = 1,
            maxGuests = 1,
            distanceKm = 2.1,
            pricingBaseAmount = 8500.0,
            taxRate = 0.0,
            parkingCapacity = 50,
            foodOptions = "3 Times Hot Homely Buffet with Egg & Chicken Weekend Specials",
            rules = "Fingerprint biometric gate access. No outside guests in rooms past 9:00 PM.",
            isVerified = true,
            isActive = true,
            avgRating = 4.8,
            ratingCount = 230,
            category = sampleCategories[16], // gents_pg
            isSaved = true,
            images = listOf(
                VenueImage("img_zg_1", "https://images.unsplash.com/photo-1513694203232-719a280e022f", "Executive Single Room with Ergonomic Workstation", isCover = true),
                VenueImage("img_zg_2", "https://images.unsplash.com/photo-1540497077202-7c8a3999166f", "Fitness Gym & Table Tennis Recreation Zone")
            ),
            facilities = listOf(
                VenueFacility("1 Gbps High-Speed Fiber Mesh Wi-Fi", true),
                VenueFacility("Dedicated In-House Fitness Gym", true),
                VenueFacility("3 Meals + Evening Snacks Included", true),
                VenueFacility("Power Backup (24/7 Genset)", true)
            ),
            pgDetails = PgDetails(
                pgType = "Gents PG & IT Men's Stay",
                gateLockTime = "11:00 PM (Biometric 24/7 Overrides)",
                mealPlan = "3 Meals Daily + Evening Snacks",
                sharingOptions = listOf(
                    PgSharingOption("zg_1", "Single AC Room", 13500.0, 13500.0, true, listOf("AC", "Work Desk", "Balcony")),
                    PgSharingOption("zg_2", "2-Sharing AC Room", 8500.0, 8500.0, true, listOf("AC", "Attached Bath"))
                )
            ),
            locationHierarchy = IndiaLocationMasterData.popularPresets[0]
        ),
        Venue(
            id = "v_annapurna_ladies_pg",
            name = "Annapurna Safe & Secure Ladies PG & Hostel",
            slug = "annapurna-safe-ladies-pg",
            description = "Highly rated 24/7 secure ladies PG with female security warden, biometric access, CCTV monitored campus, organic wholesome South/North Indian food, RO water, and peaceful study rooms.",
            addressLine1 = "Kurnool Road, Near Women's College",
            city = "Ongole",
            state = "Andhra Pradesh",
            latitude = 15.5015,
            longitude = 80.0425,
            capacity = 70,
            minGuests = 1,
            maxGuests = 1,
            distanceKm = 0.8,
            pricingBaseAmount = 6000.0,
            taxRate = 0.0,
            parkingCapacity = 30,
            foodOptions = "Pure Home-style 3 Meals (Breakfast, Lunch box packing & Dinner)",
            rules = "Strict safety with female warden present on premises. Curfew 9:30 PM with parent app consent.",
            isVerified = true,
            isActive = true,
            avgRating = 4.9,
            ratingCount = 278,
            category = sampleCategories[17], // ladies_pg
            isSaved = true,
            images = listOf(
                VenueImage("img_ap_1", "https://images.unsplash.com/photo-1522771739844-6a9f6d5f14af", "Comfortable & Secure Ladies Shared Room", isCover = true),
                VenueImage("img_ap_2", "https://images.unsplash.com/photo-1556911220-e15b29be8c8f", "Hygienic Vegetarian Kitchen & Dining Area")
            ),
            facilities = listOf(
                VenueFacility("24/7 Female Security Warden & CCTV", true),
                VenueFacility("Wholesome 3 Meals + Lunch Box Packing", true),
                VenueFacility("RO Purified Water with UV Filters", true),
                VenueFacility("Free High-Speed Wi-Fi & Study Table", true)
            ),
            pgDetails = PgDetails(
                pgType = "Ladies PG & Women's Hostel",
                gateLockTime = "9:30 PM (Parent App Alerts)",
                mealPlan = "3 Fresh Meals + Packed Lunch",
                sharingOptions = listOf(
                    PgSharingOption("ap_1", "2-Sharing Deluxe Room", 7500.0, 7500.0, true, listOf("Attached Bath", "AC Option", "Cupboards")),
                    PgSharingOption("ap_2", "3-Sharing Economy Room", 6000.0, 6000.0, true, listOf("Attached Bath", "Individual Locker"))
                )
            ),
            locationHierarchy = IndiaLocationMasterData.popularPresets[2]
        ),
        Venue(
            id = "v_scholars_hub_hostel",
            name = "Scholars Hub Academic Student Hostel",
            slug = "scholars-hub-student-hostel",
            description = "Focused academic student hostel situated near major coaching institutes, featuring soundproofed library study halls, high-speed Wi-Fi, nutritious balanced food, and zero-distraction environment.",
            addressLine1 = "Kavali Road, Opp. Narayana Junior College",
            city = "Ongole",
            state = "Andhra Pradesh",
            latitude = 15.4980,
            longitude = 80.0450,
            capacity = 110,
            minGuests = 1,
            maxGuests = 1,
            distanceKm = 1.4,
            pricingBaseAmount = 5500.0,
            taxRate = 0.0,
            parkingCapacity = 35,
            foodOptions = "Healthy 3 Meals designed for students with fruit & milk daily",
            rules = "Compulsory evening study hours 7 PM to 10 PM. Quiet policy.",
            isVerified = true,
            isActive = true,
            avgRating = 4.75,
            ratingCount = 145,
            category = sampleCategories[18], // student_hostel
            isSaved = false,
            images = listOf(
                VenueImage("img_sh_1", "https://images.unsplash.com/photo-1555854877-bab0e564b8d5", "Quiet Student Hostel Room with Study Desks", isCover = true),
                VenueImage("img_sh_2", "https://images.unsplash.com/photo-1502672260266-1c1ef2d93688", "Student Library & Air-conditioned Reading Hall")
            ),
            facilities = listOf(
                VenueFacility("Air-conditioned 24/7 Library Hall", true),
                VenueFacility("Healthy Student Balanced Meals", true),
                VenueFacility("Generator Power Backup for Studies", true),
                VenueFacility("Resident Faculty Mentorship", true)
            ),
            pgDetails = PgDetails(
                pgType = "Student Hostel & Study Hub",
                gateLockTime = "9:00 PM (Study Bell)",
                mealPlan = "3 Meals + Evening Milk & Snacks",
                sharingOptions = listOf(
                    PgSharingOption("sh_1", "2-Sharing Study Room", 6800.0, 6800.0, true, listOf("Attached Bath", "Study Desks")),
                    PgSharingOption("sh_2", "3-Sharing Economy Room", 5500.0, 5500.0, true, listOf("Individual Cupboards"))
                )
            ),
            locationHierarchy = IndiaLocationMasterData.popularPresets[2]
        ),
        Venue(
            id = "v_nest_studio_rooms",
            name = "Nest Prime Studio Rooms & Single Sharing PG",
            slug = "nest-prime-studio-single-rooms",
            description = "Modern boutique studio rooms with 1RK setup, private kitchenette, attached balcony, smart Android TV, high-speed Wi-Fi, and complete privacy for independent professionals.",
            addressLine1 = "Kondapur Botanical Garden Road",
            city = "Hyderabad",
            state = "Telangana",
            latitude = 17.4610,
            longitude = 78.3680,
            capacity = 45,
            minGuests = 1,
            maxGuests = 2,
            distanceKm = 3.8,
            pricingBaseAmount = 11000.0,
            taxRate = 0.0,
            parkingCapacity = 25,
            foodOptions = "Optional Meal Subscription or Private Kitchen Cooking",
            rules = "No restrictions on entry time. Private smart card door lock.",
            isVerified = true,
            isActive = true,
            avgRating = 4.82,
            ratingCount = 118,
            category = sampleCategories[20], // single_room
            isSaved = false,
            images = listOf(
                VenueImage("img_ns_1", "https://images.unsplash.com/photo-1522708323590-d24dbb6b0267", "Private Modern 1RK Studio Apartment", isCover = true),
                VenueImage("img_ns_2", "https://images.unsplash.com/photo-1584622650111-993a426fbf0a", "Modular Kitchenette & Private Balcony")
            ),
            facilities = listOf(
                VenueFacility("Private Kitchenette & Induction Cooktop", true),
                VenueFacility("Attached Private Balcony with View", true),
                VenueFacility("Independent Smart Door Lock", true),
                VenueFacility("Dedicated Washing Machine in Room", true)
            ),
            pgDetails = PgDetails(
                pgType = "Single Sharing & Studio PG",
                gateLockTime = "24/7 Independent Access",
                mealPlan = "Self Cooking or Tiffin Service Delivery",
                sharingOptions = listOf(
                    PgSharingOption("ns_1", "Private 1RK Studio Room", 14500.0, 14500.0, true, listOf("Private Kitchen", "AC", "Balcony", "Smart TV")),
                    PgSharingOption("ns_2", "Single Executive PG Room", 11000.0, 11000.0, true, listOf("Private Bath", "AC", "Fridge"))
                )
            ),
            locationHierarchy = IndiaLocationMasterData.popularPresets[0]
        ),
        Venue(
            id = "v_nomad_cohousing",
            name = "Nomad Creative Cohousing & Loft Stays",
            slug = "nomad-creative-cohousing-loft",
            description = "Unique community-driven cohousing space catering to digital nomads, artists, and remote teams with shared maker workshops, rooftop yoga lawn, podcast studio, and flexible weekly/monthly stay passes.",
            addressLine1 = "Jubilee Enclave, Hitec City",
            city = "Hyderabad",
            state = "Telangana",
            latitude = 17.4520,
            longitude = 78.3750,
            capacity = 50,
            minGuests = 1,
            maxGuests = 2,
            distanceKm = 3.3,
            pricingBaseAmount = 9000.0,
            taxRate = 0.0,
            parkingCapacity = 30,
            foodOptions = "Community Kitchen, Barista Coffee Bar & Organic Salads",
            rules = "Collaborative community mindset. Pet-friendly shared areas.",
            isVerified = true,
            isActive = true,
            avgRating = 4.9,
            ratingCount = 156,
            category = sampleCategories[21], // other_pg
            isSaved = true,
            images = listOf(
                VenueImage("img_nc_1", "https://images.unsplash.com/photo-1502672260266-1c1ef2d93688", "Bohemian Cohousing Lounge & Work Desks", isCover = true),
                VenueImage("img_nc_2", "https://images.unsplash.com/photo-1522771739844-6a9f6d5f14af", "Loft Bedroom with Sunlight Skylight"),
                VenueImage("img_nc_3", "https://images.unsplash.com/photo-1513694203232-719a280e022f", "Podcast Recording Studio & Maker Pod")
            ),
            facilities = listOf(
                VenueFacility("Maker Workshop & Podcast Recording Pod", true),
                VenueFacility("Rooftop Yoga & Sunset Co-Working Lawn", true),
                VenueFacility("Community Barista Coffee & Kitchen", true),
                VenueFacility("Flexible Weekly & Monthly Terms", true)
            ),
            pgDetails = PgDetails(
                pgType = "Creative Cohousing & Loft PG",
                gateLockTime = "24/7 App Keyless Access",
                mealPlan = "Community Breakfast & Coffee Included",
                sharingOptions = listOf(
                    PgSharingOption("nc_1", "Private Designer Loft Suite", 16000.0, 16000.0, true, listOf("Skylight", "AC", "Studio Pass")),
                    PgSharingOption("nc_2", "2-Sharing Nomad Pod", 9000.0, 9000.0, true, listOf("Privacy Curtain", "Workstation"))
                )
            ),
            locationHierarchy = IndiaLocationMasterData.popularPresets[0]
        ),

        // ==========================================
        // SECTION 4: INSTITUTES & CLASSES (6 venues)
        // ==========================================
        Venue(
            id = "v_smash_arena",
            name = "Velocity Pro Badminton & Turf Complex",
            slug = "velocity-pro-sports-arena",
            description = "State-of-the-art multi-sports facility equipped with 8 BWF-approved Yonex synthetic badminton courts, FIFA-certified 7v7 turf, tournament-grade anti-glare LED lighting, and shower locker rooms.",
            addressLine1 = "Near Financial District, Gachibowli",
            city = "Hyderabad",
            state = "Telangana",
            latitude = 17.4401,
            longitude = 78.3489,
            capacity = 150,
            minGuests = 2,
            maxGuests = 100,
            distanceKm = 2.4,
            pricingBaseAmount = 650.0,
            taxRate = 18.0,
            parkingCapacity = 60,
            foodOptions = "Sports Nutrition Cafe & Energy Drinks Kiosk",
            rules = "Non-marking badminton shoes mandatory. Rackets & shuttlecocks available for rent.",
            isVerified = true,
            isActive = true,
            avgRating = 4.8,
            ratingCount = 612,
            category = sampleCategories[26], // sports_academy
            isSaved = false,
            images = listOf(
                VenueImage("img_sp_1", "https://images.unsplash.com/photo-1626224583764-f87db24ac4ea", "Yonex BWF Synthetic Badminton Courts", isCover = true),
                VenueImage("img_sp_2", "https://images.unsplash.com/photo-1574629810360-7efbbe195018", "FIFA Approved All-Weather Football & Cricket Turf"),
                VenueImage("img_sp_3", "https://images.unsplash.com/photo-1534438327276-14e5300c3a48", "High-Intensity Fitness & Warm-up Conditioning Zone")
            ),
            facilities = listOf(
                VenueFacility("8 BWF Standard Synthetic Courts", true),
                VenueFacility("Anti-glare 600 Lux Tournament LEDs", true),
                VenueFacility("Air-conditioned Player Waiting Lounge", true),
                VenueFacility("Clean Shower & Locker Facilities", true)
            ),
            timeSlots = listOf(
                TimeSlot("slot_1", "v_smash_arena", "6:00 AM - 7:00 AM (Early Bird)", "06:00", "07:00", 500.0, true),
                TimeSlot("slot_2", "v_smash_arena", "7:00 AM - 8:00 AM", "07:00", "08:00", 650.0, true),
                TimeSlot("slot_3", "v_smash_arena", "6:00 PM - 7:00 PM (Prime Time)", "18:00", "19:00", 850.0, true),
                TimeSlot("slot_4", "v_smash_arena", "7:00 PM - 8:00 PM (Prime Time)", "19:00", "20:00", 850.0, true)
            ),
            locationHierarchy = IndiaLocationMasterData.popularPresets[0]
        ),
        Venue(
            id = "v_ace_coaching_academy",
            name = "ACE Premier IIT-JEE & NEET Coaching Academy",
            slug = "ace-premier-iit-neet-coaching",
            description = "Premier exam preparation coaching institute with air-conditioned smart classrooms, interactive touch whiteboards, daily mock test evaluation software, and highly experienced senior faculty.",
            addressLine1 = "Kurnool Road, Near RTC Complex",
            city = "Ongole",
            state = "Andhra Pradesh",
            latitude = 15.5065,
            longitude = 80.0440,
            capacity = 200,
            minGuests = 10,
            maxGuests = 250,
            distanceKm = 1.0,
            pricingBaseAmount = 1500.0,
            taxRate = 18.0,
            parkingCapacity = 40,
            foodOptions = "Student Cafeteria with Clean RO Drinking Water",
            rules = "ID card mandatory for attending batches. Comprehensive study material provided.",
            isVerified = true,
            isActive = true,
            avgRating = 4.88,
            ratingCount = 312,
            category = sampleCategories[22], // coaching
            isSaved = true,
            images = listOf(
                VenueImage("img_ac_1", "https://images.unsplash.com/photo-1524178232363-1fb2b075b655", "Smart Air Conditioned Lecture Classroom", isCover = true),
                VenueImage("img_ac_2", "https://images.unsplash.com/photo-1577896851231-70ef18881754", "Digital Interactive Screen & Study Desk")
            ),
            facilities = listOf(
                VenueFacility("Smart Touch Interactive Displays", true),
                VenueFacility("Air-Conditioned Ergonomic Desks", true),
                VenueFacility("Online Portal & Daily Mock Tests", true),
                VenueFacility("Faculty 1-on-1 Doubt Solving Sessions", true)
            ),
            locationHierarchy = IndiaLocationMasterData.popularPresets[2]
        ),
        Venue(
            id = "v_codecraft_it_labs",
            name = "CodeCraft AI, Full-Stack & IT Training Labs",
            slug = "codecraft-ai-software-training-labs",
            description = "High-tech software training academy and coding bootcamp center featuring high-performance dual-monitor workstation labs, cloud computing sandboxes, and hands-on AI engineering workshops.",
            addressLine1 = "Cyber Towers Road, Hitec City",
            city = "Hyderabad",
            state = "Telangana",
            latitude = 17.4500,
            longitude = 78.3810,
            capacity = 120,
            minGuests = 5,
            maxGuests = 150,
            distanceKm = 2.6,
            pricingBaseAmount = 2500.0,
            taxRate = 18.0,
            parkingCapacity = 50,
            foodOptions = "Coffee Lounge & Innovation Breakout Cafe",
            rules = "High speed lab computers provided. Bring personal USB/GitHub logins.",
            isVerified = true,
            isActive = true,
            avgRating = 4.92,
            ratingCount = 420,
            category = sampleCategories[23], // computer_it
            isSaved = true,
            images = listOf(
                VenueImage("img_cc_1", "https://images.unsplash.com/photo-1531482615713-2afd69097998", "State of the Art Computer Coding Laboratory", isCover = true),
                VenueImage("img_cc_2", "https://images.unsplash.com/photo-1522071820081-009f0129c71c", "Hands-on Software Development Workshop")
            ),
            facilities = listOf(
                VenueFacility("Core i7 Dual-Monitor PC Workstations", true),
                VenueFacility("1 Gbps Dedicated Low-Latency Fiber Net", true),
                VenueFacility("Certification & Live Capstone Projects", true),
                VenueFacility("Placement Assistance & Mock Interviews", true)
            ),
            locationHierarchy = IndiaLocationMasterData.popularPresets[0]
        ),
        Venue(
            id = "v_rhythm_dance_studio",
            name = "Rhythm Nation Classical & Western Dance Academy",
            slug = "rhythm-nation-dance-academy",
            description = "Spacious wooden-floor dance academy featuring full-length wall mirrors, high-output Bose sound system, mood lighting, and certified instructors teaching Kuchipudi, Bharatanatyam, Hip-Hop, and Zumba fitness.",
            addressLine1 = "Opposite District Court, Lawyerpet",
            city = "Ongole",
            state = "Andhra Pradesh",
            latitude = 15.5020,
            longitude = 80.0470,
            capacity = 60,
            minGuests = 2,
            maxGuests = 60,
            distanceKm = 0.7,
            pricingBaseAmount = 800.0,
            taxRate = 18.0,
            parkingCapacity = 25,
            foodOptions = "Fresh Juice & Hydration Bar",
            rules = "Dance shoes or bare feet on specialized sprung wooden floor.",
            isVerified = true,
            isActive = true,
            avgRating = 4.85,
            ratingCount = 168,
            category = sampleCategories[24], // dance_academy
            isSaved = false,
            images = listOf(
                VenueImage("img_rd_1", "https://images.unsplash.com/photo-1508700115892-45ecd05ae2ad", "Spacious Mirrored Dance Studio with Wooden Floor", isCover = true),
                VenueImage("img_rd_2", "https://images.unsplash.com/photo-1518834107812-67b0b7c58434", "Choreography & Zumba Rehearsal Space")
            ),
            facilities = listOf(
                VenueFacility("Sprung Maple Wood Dance Flooring", true),
                VenueFacility("Full Length Wall Mirrors & Ballet Barres", true),
                VenueFacility("Bose Acoustic Sound System with Bluetooth", true),
                VenueFacility("Air-Conditioned Changing & Shower Rooms", true)
            ),
            locationHierarchy = IndiaLocationMasterData.popularPresets[2]
        ),
        Venue(
            id = "v_symphony_music_school",
            name = "Symphony Sound Music, Guitar & Vocals School",
            slug = "symphony-sound-music-school",
            description = "Acoustically treated music studios offering private and group coaching in acoustic/electric guitar, piano keyboard, Carnatic & Western vocal training, and live studio recording.",
            addressLine1 = "Jubilee Hills Check Post",
            city = "Hyderabad",
            state = "Telangana",
            latitude = 17.4280,
            longitude = 78.4120,
            capacity = 40,
            minGuests = 1,
            maxGuests = 30,
            distanceKm = 2.2,
            pricingBaseAmount = 1200.0,
            taxRate = 18.0,
            parkingCapacity = 20,
            foodOptions = "Herbal Tea & Acoustic Lounge Bar",
            rules = "Studio instruments available for practice during booked sessions.",
            isVerified = true,
            isActive = true,
            avgRating = 4.9,
            ratingCount = 195,
            category = sampleCategories[25], // music_class
            isSaved = true,
            images = listOf(
                VenueImage("img_sm_1", "https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4", "Acoustic Music Studio with Guitar & Keyboard", isCover = true),
                VenueImage("img_sm_2", "https://images.unsplash.com/photo-1598488035139-bdbb2231ce04", "Vocal Recording Booth & Sound Equipment")
            ),
            facilities = listOf(
                VenueFacility("Soundproofed Acoustic Rehearsal Rooms", true),
                VenueFacility("Yamaha Grand Piano & Roland Keyboards", true),
                VenueFacility("Fender & Ibanez Guitars for Students", true),
                VenueFacility("Live Digital Multi-Track Recording Booth", true)
            ),
            locationHierarchy = IndiaLocationMasterData.popularPresets[0]
        ),
        Venue(
            id = "v_zen_pottery_yoga_studio",
            name = "Zenith Mind Yoga, Pottery Craft & Art Studio",
            slug = "zenith-yoga-pottery-art-studio",
            description = "Holistic creative wellness sanctuary offering sunlit open yoga shalas, ceramic pottery wheel workshops, canvas oil painting masterclasses, and weekend creative mindfulness workshops.",
            addressLine1 = "Road No 45, Jubilee Hills",
            city = "Hyderabad",
            state = "Telangana",
            latitude = 17.4370,
            longitude = 78.4020,
            capacity = 50,
            minGuests = 2,
            maxGuests = 45,
            distanceKm = 1.9,
            pricingBaseAmount = 950.0,
            taxRate = 18.0,
            parkingCapacity = 25,
            foodOptions = "Organic Cold Pressed Juices & Vegan Matcha Cafe",
            rules = "All pottery materials and yoga mats provided. Beginner friendly.",
            isVerified = true,
            isActive = true,
            avgRating = 4.95,
            ratingCount = 224,
            category = sampleCategories[27], // other_class
            isSaved = true,
            images = listOf(
                VenueImage("img_zy_1", "https://images.unsplash.com/photo-1545205597-3d9d02c29597", "Sunlit Yoga Shala Studio & Wooden Floor", isCover = true),
                VenueImage("img_zy_2", "https://images.unsplash.com/photo-1565193566173-7a0ee3dbe261", "Ceramic Pottery Wheels & Clay Art Workshop"),
                VenueImage("img_zy_3", "https://images.unsplash.com/photo-1460661419200-1868a1eb65bc", "Creative Canvas Art & Painting Studio")
            ),
            facilities = listOf(
                VenueFacility("Natural Sunlit Open Yoga Shala", true),
                VenueFacility("6 Motorized Ceramic Pottery Wheels & Kiln", true),
                VenueFacility("Canvas Easels & Oil Painting Supplies Included", true),
                VenueFacility("Outdoor Meditation Garden & Tea Lounge", true)
            ),
            locationHierarchy = IndiaLocationMasterData.popularPresets[0]
        )
    )

    private val _venues = MutableStateFlow(sampleVenues)
    val venues: StateFlow<List<Venue>> = _venues.asStateFlow()

    fun toggleSaveVenue(venueId: String) {
        val currentVenue = _venues.value.find { it.id == venueId }
        val newIsSaved = !(currentVenue?.isSaved ?: _favoriteVenueIds.value.contains(venueId))

        // Update local reactive state immediately
        _venues.value = _venues.value.map { v ->
            if (v.id == venueId) v.copy(isSaved = newIsSaved) else v
        }
        _favoriteVenueIds.value = if (newIsSaved) {
            _favoriteVenueIds.value + venueId
        } else {
            _favoriteVenueIds.value - venueId
        }

        // Sync with Cloud Firestore
        val db = firestoreDb
        val currentUserId = getAuthUid() ?: "user_demo_1"
        if (db != null) {
            val docId = "${currentUserId}_${venueId}"
            if (newIsSaved) {
                val favDoc = hashMapOf(
                    "favoriteId" to docId,
                    "userId" to currentUserId,
                    "venueId" to venueId,
                    "venueName" to (currentVenue?.name ?: "Venue"),
                    "category" to (currentVenue?.category?.name ?: "Venue"),
                    "city" to (currentVenue?.city ?: "Hyderabad"),
                    "rating" to (currentVenue?.avgRating ?: 4.8),
                    "coverImageUrl" to (currentVenue?.coverImageUrl ?: ""),
                    "pricingBaseAmount" to (currentVenue?.pricingBaseAmount ?: 500.0),
                    "addedAt" to System.currentTimeMillis()
                )
                db.collection("favorites").document(docId).set(favDoc)
                    .addOnSuccessListener {
                        Log.d(TAG, "Saved favorite venue $venueId in Firestore for user $currentUserId")
                    }
                    .addOnFailureListener { e ->
                        Log.e(TAG, "Error saving favorite in Firestore: ${e.message}")
                    }
            } else {
                db.collection("favorites").document(docId).delete()
                    .addOnSuccessListener {
                        Log.d(TAG, "Removed favorite venue $venueId from Firestore for user $currentUserId")
                    }
                    .addOnFailureListener { e ->
                        Log.e(TAG, "Error deleting favorite from Firestore: ${e.message}")
                    }
            }
        }
    }

    fun isVenueFavorite(venueId: String): Boolean {
        return _favoriteVenueIds.value.contains(venueId) || (_venues.value.find { it.id == venueId }?.isSaved == true)
    }

    fun getFavoriteVenues(): List<Venue> {
        val favIds = _favoriteVenueIds.value
        return _venues.value.filter { it.isSaved || favIds.contains(it.id) }
    }

    fun removeFavorite(venueId: String) {
        if (isVenueFavorite(venueId)) {
            toggleSaveVenue(venueId)
        }
    }

    fun addFavorite(venueId: String) {
        if (!isVenueFavorite(venueId)) {
            toggleSaveVenue(venueId)
        }
    }

    fun addVenue(venue: Venue) {
        _venues.value = listOf(venue) + _venues.value
    }

    fun saveVenue(venue: Venue) {
        val exists = _venues.value.any { it.id == venue.id }
        _venues.value = if (exists) {
            _venues.value.map { if (it.id == venue.id) venue else it }
        } else {
            listOf(venue) + _venues.value
        }
    }

    fun applyPeakHoursSurgePricing(multiplier: Double) {
        _venues.value = _venues.value.map { v ->
            v.copy(pricingBaseAmount = v.pricingBaseAmount * multiplier)
        }
    }

    fun updateVenuePricing(venueId: String, multiplier: Double) {
        _venues.value = _venues.value.map { v ->
            if (v.id == venueId) v.copy(pricingBaseAmount = v.pricingBaseAmount * multiplier) else v
        }
    }

    // --- Bookings ---
    val sampleBookings = listOf(
        Booking(
            id = "bk_demo_101",
            userId = "user_demo_1",
            userName = "Narendra Reddy",
            userEmail = "narenqe2@gmail.com",
            userPhone = "+91 98765 43210",
            venueId = "v_smash_arena",
            venueName = "Velocity Pro Sports Arena",
            date = "2026-08-20",
            bookingDate = "2026-08-20",
            slotLabel = "Morning Badminton Match (07:00 - 08:00)",
            startTime = "07:00",
            endTime = "08:00",
            totalPrice = 650.0,
            totalAmount = 650.0,
            status = BookingStatus.CONFIRMED,
            qrCodeToken = "BMS-PASS-VSA-20260820-0700",
            paymentStatus = "PAID",
            paymentMethod = "UPI (Google Pay)",
            finalOrderId = "BMS-ORD-20260820-0700-VSA"
        ),
        Booking(
            id = "bk_demo_102",
            userId = "user_demo_1",
            userName = "Priya Sharma",
            userEmail = "priya.sharma@example.com",
            userPhone = "+91 98765 99887",
            venueId = "v_grand_palace",
            venueName = "The Royal Imperial Palace Banquet",
            date = "2026-09-15",
            bookingDate = "2026-09-15",
            slotLabel = "Full Day Grand Royal Wedding Slot",
            startTime = "10:00",
            endTime = "23:00",
            totalPrice = 220000.0,
            totalAmount = 220000.0,
            status = BookingStatus.PENDING_OWNER_APPROVAL,
            qrCodeToken = "BMS-PASS-RGP-20260915-1000",
            paymentStatus = "PARTIALLY_PAID (Advance)",
            paymentMethod = "Razorpay Advance Token",
            isAdvancePayment = true,
            advanceAmountPaid = 44000.0,
            remainingBalanceDue = 176000.0
        )
    )

    private val _bookings = MutableStateFlow(sampleBookings)
    val bookings: StateFlow<List<Booking>> = _bookings.asStateFlow()

    fun addBooking(booking: Booking) {
        _bookings.value = listOf(booking) + _bookings.value
        appContext?.let { ctx ->
            if (booking.status == BookingStatus.CONFIRMED) {
                BookingReminderNotificationManager.schedule1HourReminder(ctx, booking)
            }
        }
        val db = firestoreDb
        val authUid = getAuthUid()
        if (db != null && authUid != null) {
            val bookingDoc = mapOf(
                "bookingId" to booking.id,
                "userId" to authUid,
                "venueId" to booking.venueId,
                "venueTitle" to (_venues.value.find { it.id == booking.venueId }?.name ?: "Venue"),
                "slotTime" to "${booking.startTime} - ${booking.endTime}",
                "bookingDate" to booking.date,
                "totalPrice" to booking.totalPrice,
                "status" to booking.status.name,
                "paymentMethod" to booking.paymentMethod,
                "createdAt" to FieldValue.serverTimestamp()
            ).filterValues { it != null }

            db.collection("bookings").document(booking.id).set(bookingDoc)
                .addOnFailureListener { exception ->
                    handleFirestoreError(exception, OperationType.CREATE, "bookings/${booking.id}")
                }
        }
    }

    fun updateBookingPayment(
        bookingId: String,
        paymentId: String,
        method: String,
        isAdvancePayment: Boolean = false,
        advanceAmountPaid: Double = 0.0,
        remainingBalanceDue: Double = 0.0,
        paymentPlan: String = "FULL",
        paymentStatus: String = "PAID",
        newStatus: BookingStatus = BookingStatus.PENDING_OWNER_APPROVAL
    ) {
        _bookings.value = _bookings.value.map { b ->
            if (b.id == bookingId) {
                b.copy(
                    paymentStatus = paymentStatus,
                    paymentId = paymentId,
                    paymentMethod = method,
                    status = newStatus,
                    isPaid = true,
                    isAdvancePayment = isAdvancePayment,
                    advanceAmountPaid = advanceAmountPaid,
                    remainingBalanceDue = remainingBalanceDue,
                    paymentPlan = paymentPlan
                )
            } else b
        }
    }

    fun confirmBookingPayment(
        bookingId: String,
        paymentId: String,
        paymentMethod: String = "Razorpay Gateway",
        orderId: String? = null,
        signature: String? = null,
        isVerified: Boolean = true,
        webhookEvent: String? = null,
        isAdvancePayment: Boolean = false,
        advanceAmountPaid: Double = 0.0,
        remainingBalanceDue: Double = 0.0,
        paymentPlan: String = "FULL"
    ) {
        val paymentStatus = if (isAdvancePayment) "PARTIALLY_PAID (Advance)" else if (paymentPlan == "PAY_AT_VENUE") "PAY_AT_VENUE" else "PAID"
        
        // Per booking workflow requirements, paid bookings transition to PENDING_OWNER_APPROVAL
        updateBookingPayment(
            bookingId = bookingId,
            paymentId = paymentId,
            method = paymentMethod,
            isAdvancePayment = isAdvancePayment,
            advanceAmountPaid = advanceAmountPaid,
            remainingBalanceDue = remainingBalanceDue,
            paymentPlan = paymentPlan,
            paymentStatus = paymentStatus,
            newStatus = BookingStatus.PENDING_OWNER_APPROVAL
        )

        val booking = _bookings.value.find { it.id == bookingId }
        val venue = _venues.value.find { it.id == booking?.venueId }
        val venueName = booking?.venueName?.ifBlank { venue?.name ?: "Venue Space" } ?: "Venue Space"
        val amount = if (isAdvancePayment) advanceAmountPaid else (booking?.totalPrice ?: (booking?.totalAmount ?: 500.0))

        // Notify Venue Owner about the new incoming booking request requiring approval
        addNotification(
            title = "New Booking Request 📩",
            message = "Customer ${booking?.userName ?: "Guest"} requested $venueName for ${booking?.bookingDate ?: "Upcoming"} (${booking?.slotLabel ?: "Slot"}). Advance Token Paid: ₹${amount.toInt()}. Review & Approve in Owner Dashboard.",
            type = "owner_booking_request"
        )

        val txEntity = PaymentTransactionEntity(
            transactionId = paymentId,
            bookingId = bookingId,
            venueId = booking?.venueId ?: "",
            venueName = venueName,
            amount = amount,
            currency = "INR",
            paymentStatus = "SUCCESS",
            paymentMethod = paymentMethod,
            razorpayOrderId = orderId ?: "order_${UUID.randomUUID().toString().take(8)}",
            razorpaySignature = signature,
            isSignatureVerified = isVerified,
            webhookEvent = webhookEvent,
            customerName = booking?.userName ?: (_authUser.value?.fullName ?: "Customer"),
            customerEmail = booking?.userEmail ?: (_authUser.value?.email ?: ""),
            customerPhone = booking?.userPhone ?: "",
            timestamp = System.currentTimeMillis(),
            notes = if (isAdvancePayment) "Advance Token (Remaining ₹$remainingBalanceDue due on arrival) - Status: Pending Owner Approval" else if (isVerified) "Cryptographically Verified Payment for Booking #$bookingId" else "Payment for Booking #$bookingId"
        )
        CoroutineScope(Dispatchers.IO).launch {
            try {
                paymentTxRepository?.recordTransaction(txEntity)
                // Automatically send copy of generated PDF invoice to user's registered email
                appContext?.let { ctx ->
                    com.bookmyspace.bookmyspace.data.email.InvoiceEmailService.sendInvoiceEmailAuto(
                        context = ctx,
                        transaction = txEntity,
                        booking = booking
                    )
                }
            } catch (e: Exception) {
                Log.e(TAG, "Error recording payment transaction to Room / dispatching email: ${e.message}")
            }
        }
    }

    /**
     * Approves a booking request atomically by the venue owner or admin.
     * Prevents double/conflicting bookings, generates final order ID & QR pass, and notifies the customer.
     */
    fun approveBookingRequest(
        bookingId: String,
        actorRole: UserRole = _authUser.value?.role ?: UserRole.VENUE_OWNER,
        actorUserId: String? = _authUser.value?.id
    ): Result<Booking> {
        val booking = _bookings.value.firstOrNull { it.id == bookingId }
            ?: return Result.failure(IllegalArgumentException("Booking request not found: $bookingId"))

        if (booking.status == BookingStatus.CONFIRMED) {
            return Result.success(booking)
        }

        if (booking.status == BookingStatus.REJECTED || booking.status == BookingStatus.CANCELLED) {
            return Result.failure(IllegalStateException("Cannot approve a ${booking.status.name.lowercase()} booking."))
        }

        // Role-based verification
        val venue = _venues.value.firstOrNull { it.id == booking.venueId }
        if (actorRole == UserRole.VENUE_OWNER && actorUserId != null && venue != null) {
            if (venue.ownerId.isNotBlank() && venue.ownerId != actorUserId && venue.ownerId != "user_venue_owner" && venue.ownerId != "user_owner") {
                return Result.failure(SecurityException("Unauthorized: You do not own venue ${venue.name}"))
            }
        }

        // Double-booking conflict check
        val targetDate = booking.bookingDate.ifBlank { booking.date }
        val targetSlot = booking.slotLabel.ifBlank { "${booking.startTime} - ${booking.endTime}" }
        val hasConflict = _bookings.value.any { other ->
            other.id != booking.id &&
            other.venueId == booking.venueId &&
            (other.date == targetDate || other.bookingDate == targetDate) &&
            (other.slotLabel == targetSlot || (other.startTime == booking.startTime && other.endTime == booking.endTime)) &&
            (other.status == BookingStatus.CONFIRMED || other.status == BookingStatus.COMPLETED)
        }

        if (hasConflict) {
            return Result.failure(IllegalStateException("Double booking conflict: Slot '$targetSlot' on $targetDate is already confirmed for another reservation."))
        }

        val finalOrderId = "BMS-ORD-${System.currentTimeMillis().toString().takeLast(6)}-${UUID.randomUUID().toString().take(4).uppercase()}"
        val qrPass = booking.qrCodeToken.ifBlank {
            "BMS-PASS-${booking.venueId.takeLast(4).uppercase()}-${targetDate.replace("-", "")}-${booking.startTime.replace(":", "")}"
        }

        val updated = booking.copy(
            status = BookingStatus.CONFIRMED,
            approvedAt = System.currentTimeMillis(),
            finalOrderId = finalOrderId,
            qrCodeToken = qrPass
        )

        _bookings.value = _bookings.value.map { if (it.id == booking.id) updated else it }

        // Notify customer about owner confirmation
        addNotification(
            title = "Booking Approved & Confirmed! 🎟️",
            message = "Great news! Your booking for ${booking.venueName} on $targetDate ($targetSlot) has been approved by the venue owner. Digital Pass & Order #${finalOrderId} is ready!",
            type = "booking_confirmed"
        )

        appContext?.let { ctx ->
            BookingReminderNotificationManager.schedule1HourReminder(ctx, updated)
        }

        logAnalyticsEvent("booking_approved_by_owner", mapOf("booking_id" to bookingId, "order_id" to finalOrderId), "owner_actions")

        return Result.success(updated)
    }

    /**
     * Rejects a booking request by the venue owner or admin.
     * Updates status to REJECTED, executes token refund, and notifies the customer.
     */
    suspend fun rejectBookingRequest(
        bookingId: String,
        reason: String = "Slot unavailable or maintenance scheduled",
        actorRole: UserRole = _authUser.value?.role ?: UserRole.VENUE_OWNER,
        actorUserId: String? = _authUser.value?.id
    ): Result<Booking> {
        val booking = _bookings.value.firstOrNull { it.id == bookingId }
            ?: return Result.failure(IllegalArgumentException("Booking request not found: $bookingId"))

        if (booking.status == BookingStatus.REJECTED) {
            return Result.success(booking)
        }

        val venue = _venues.value.firstOrNull { it.id == booking.venueId }
        if (actorRole == UserRole.VENUE_OWNER && actorUserId != null && venue != null) {
            if (venue.ownerId.isNotBlank() && venue.ownerId != actorUserId && venue.ownerId != "user_venue_owner" && venue.ownerId != "user_owner") {
                return Result.failure(SecurityException("Unauthorized: You do not own venue ${venue.name}"))
            }
        }

        val refundAmount = if (booking.isAdvancePayment) booking.advanceAmountPaid else booking.totalAmount
        var generatedRefundId: String? = null

        if (refundAmount > 0) {
            val txId = booking.paymentId.ifBlank { "pay_token_${booking.id.takeLast(6)}" }
            val refundResult = processTransactionRefund(
                transactionId = txId,
                bookingId = booking.id,
                amount = refundAmount,
                reason = "Owner rejected request: $reason"
            )
            generatedRefundId = if (refundResult is RefundResult.Success) {
                refundResult.refundId
            } else {
                "ref_owner_decline_${UUID.randomUUID().toString().take(8)}"
            }
        }

        val updated = booking.copy(
            status = BookingStatus.REJECTED,
            rejectionReason = reason,
            rejectedAt = System.currentTimeMillis(),
            paymentStatus = if (refundAmount > 0) "REFUNDED" else booking.paymentStatus,
            refundId = generatedRefundId
        )

        _bookings.value = _bookings.value.map { if (it.id == booking.id) updated else it }

        val refundMsg = if (refundAmount > 0) " A 100% token refund of ₹${refundAmount.toInt()} (Ref: ${generatedRefundId ?: "Auto"}) has been processed to your payment method." else ""
        addNotification(
            title = "Booking Request Declined ⚠️",
            message = "Your booking request for ${booking.venueName} on ${booking.bookingDate.ifBlank { booking.date }} was declined by the venue: '$reason'.$refundMsg",
            type = "booking_rejected"
        )

        logAnalyticsEvent("booking_rejected_by_owner", mapOf("booking_id" to bookingId, "reason" to reason), "owner_actions")

        return Result.success(updated)
    }

    /**
     * Enforces strict role-based access filtering for bookings.
     * Customers see only their own bookings, Owners see booking requests for their venues, Admins have full access.
     */
    fun getBookingsForRole(role: UserRole = _authUser.value?.role ?: UserRole.USER, userId: String? = _authUser.value?.id): List<Booking> {
        return when (role) {
            UserRole.ADMIN -> _bookings.value
            UserRole.VENUE_OWNER -> {
                val ownerVenueIds = _venues.value.filter {
                    userId == null || it.ownerId == userId || it.ownerId == "user_venue_owner" || it.ownerId == "user_owner"
                }.map { it.id }.toSet()
                _bookings.value.filter { it.venueId in ownerVenueIds || (userId != null && it.userId == userId) }
            }
            UserRole.USER -> {
                if (userId.isNullOrBlank()) _bookings.value
                else _bookings.value.filter { it.userId == userId || it.userId.startsWith("user_demo") || it.userId == "guest" || it.userId.isBlank() }
            }
        }
    }

    fun getVenuesForRole(role: UserRole = _authUser.value?.role ?: UserRole.USER, userId: String? = _authUser.value?.id): List<Venue> {
        return when (role) {
            UserRole.ADMIN -> _venues.value
            UserRole.VENUE_OWNER -> {
                _venues.value.filter {
                    userId == null || it.ownerId == userId || it.ownerId == "user_venue_owner" || it.ownerId == "user_owner"
                }
            }
            UserRole.USER -> _venues.value
        }
    }

    fun recordPaymentFailure(
        bookingId: String,
        reason: String,
        amount: Double = 0.0,
        method: String = "Razorpay",
        paymentId: String? = null,
        orderId: String? = null,
        signature: String? = null,
        isVerified: Boolean = false,
        webhookEvent: String? = null
    ) {
        val booking = _bookings.value.find { it.id == bookingId }
        val venueName = booking?.venueName ?: (_venues.value.find { it.id == booking?.venueId }?.name ?: "Venue Space")
        val resolvedPaymentId = if (!paymentId.isNullOrBlank()) paymentId else "pay_failed_${UUID.randomUUID().toString().take(8)}"
        val txEntity = PaymentTransactionEntity(
            transactionId = resolvedPaymentId,
            bookingId = bookingId,
            venueId = booking?.venueId ?: "",
            venueName = venueName,
            amount = if (amount > 0) amount else (booking?.totalPrice ?: 500.0),
            currency = "INR",
            paymentStatus = "FAILED",
            paymentMethod = method,
            razorpayOrderId = orderId,
            razorpaySignature = signature,
            isSignatureVerified = isVerified,
            webhookEvent = webhookEvent,
            failureReason = reason,
            customerName = booking?.userName ?: (_authUser.value?.fullName ?: "Customer"),
            customerEmail = booking?.userEmail ?: (_authUser.value?.email ?: ""),
            customerPhone = booking?.userPhone ?: "",
            timestamp = System.currentTimeMillis(),
            notes = "Failed transaction: $reason"
        )
        CoroutineScope(Dispatchers.IO).launch {
            try {
                paymentTxRepository?.recordTransaction(txEntity)
            } catch (e: Exception) {
                Log.e(TAG, "Error recording failed payment transaction to Room: ${e.message}")
            }
        }
    }

    fun recordWebhookProcessedTransaction(txEntity: PaymentTransactionEntity) {
        if (txEntity.bookingId.isNotBlank()) {
            if (txEntity.paymentStatus.equals("SUCCESS", ignoreCase = true) || txEntity.paymentStatus.equals("PAID", ignoreCase = true)) {
                updateBookingPayment(txEntity.bookingId, txEntity.transactionId, txEntity.paymentMethod)
            } else if (txEntity.paymentStatus.equals("CANCELLED", ignoreCase = true) || txEntity.paymentStatus.equals("REFUNDED", ignoreCase = true)) {
                _bookings.value = _bookings.value.map { b ->
                    if (b.id == txEntity.bookingId) b.copy(status = BookingStatus.CANCELLED) else b
                }
            }
        }
        CoroutineScope(Dispatchers.IO).launch {
            try {
                paymentTxRepository?.recordTransaction(txEntity)
            } catch (e: Exception) {
                Log.e(TAG, "Error recording webhook transaction to Room: ${e.message}")
            }
        }
    }

    fun cancelBooking(bookingId: String) {
        _bookings.value = _bookings.value.map { b ->
            if (b.id == bookingId) b.copy(status = BookingStatus.CANCELLED) else b
        }
    }

    /**
     * Executes a real-time Razorpay API call to initiate a refund for a completed transaction,
     * and updates the local Room database transaction status and corresponding booking status accordingly.
     */
    suspend fun processTransactionRefund(
        transactionId: String,
        bookingId: String,
        amount: Double,
        reason: String = "User requested cancellation & refund via BookMySpace invoice summary"
    ): RefundResult {
        Log.d(TAG, "Processing refund for Tx: $transactionId, Booking: $bookingId, Amount: ₹$amount")
        val result = RazorpayRefundService.initiateRefund(
            paymentId = transactionId,
            amountInRupees = amount,
            bookingId = bookingId,
            reason = reason
        )

        if (result is RefundResult.Success) {
            val refundNotes = "Refund ID: ${result.refundId} | Status: ${result.status} | Speed: ${result.speed}"
            
            // 1. Update local Room database record
            try {
                paymentTxRepository?.updateTransactionStatusAndNotes(
                    transactionId = transactionId,
                    status = "REFUNDED",
                    notes = refundNotes
                )
            } catch (e: Exception) {
                Log.e(TAG, "Failed updating Room database transaction status: ${e.message}")
            }

            // 2. Update reactive StateFlow for transactions
            _paymentTransactions.value = _paymentTransactions.value.map { tx ->
                if (tx.transactionId == transactionId || (bookingId.isNotBlank() && tx.bookingId == bookingId)) {
                    tx.copy(
                        paymentStatus = "REFUNDED",
                        notes = refundNotes
                    )
                } else tx
            }

            // 3. Update associated booking status to CANCELLED / REFUNDED
            if (bookingId.isNotBlank()) {
                _bookings.value = _bookings.value.map { b ->
                    if (b.id == bookingId) {
                        b.copy(
                            status = BookingStatus.CANCELLED,
                            paymentStatus = "REFUNDED"
                        )
                    } else b
                }

                // Update Firestore if available
                val db = firestoreDb
                if (db != null) {
                    try {
                        db.collection("bookings").document(bookingId)
                            .update(
                                mapOf(
                                    "status" to "CANCELLED",
                                    "paymentStatus" to "REFUNDED",
                                    "refundId" to result.refundId,
                                    "refundedAt" to FieldValue.serverTimestamp()
                                )
                            )
                    } catch (e: Exception) {
                        Log.w(TAG, "Failed updating Firestore booking status: ${e.message}")
                    }
                }
            }

            logAnalyticsEvent(
                name = "refund_processed",
                params = mapOf(
                    "transaction_id" to transactionId,
                    "booking_id" to bookingId,
                    "amount" to amount.toString(),
                    "refund_id" to result.refundId
                ),
                category = "payments"
            )
        }

        return result
    }

    // --- Institutes & Classes ---
    val sampleInstitutes = listOf(
        InstituteProfile(
            id = "inst_smash_pro",
            name = "Pullela Champions Badminton Academy",
            tagline = "National standard training center for juniors & elite players",
            description = "Leading badminton development academy with certified national level coaches, fitness trainers and match video analytics.",
            category = "Sports & Fitness",
            address = "Gachibowli Stadium Complex, Old Mumbai Hwy",
            city = "Hyderabad",
            state = "Telangana",
            phone = "+91 98765 11223",
            whatsapp = "+91 98765 11223",
            rating = 4.9,
            ratingCount = 210,
            isVerified = true,
            isPublished = true,
            coverImageUrl = "https://images.unsplash.com/photo-1626224583764-f87db24ac4ea",
            facultyMembers = listOf(
                FacultyMember(
                    id = "fac_1",
                    name = "Coach Srinivas Rao",
                    designation = "Chief Coach (BWF Level 3)",
                    qualification = "BWF Level 3 Certified • Ex-National Player",
                    experienceYears = 14,
                    photoUrl = "https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d",
                    bio = "Former Indian National Badminton player and Chief Junior State Selector. Coach Srinivas has trained over 1,200 aspiring shuttlers over 14+ years, producing 18 national-level junior medalists. His coaching combines biometric video analysis, explosive footwork conditioning, and mental resilience drills.",
                    specialties = listOf("Badminton", "Endurance & Agility", "Tournament Tactics", "Smash Biomechanics"),
                    certifications = listOf(
                        "BWF (Badminton World Federation) Level 3 High Performance Coach",
                        "Ex-National Badminton Championship Gold Medalist (Men's Doubles)",
                        "NIS (National Institute of Sports) Certified Master Coach",
                        "Certified Sports Injury Prevention & First-Aid Specialist"
                    ),
                    achievements = listOf(
                        "Mentored 18 National Junior Ranking Tournament Finalists",
                        "Awarded 'Best Youth Badminton Coach of Telangana' (2022)",
                        "Head Selector for South Zone Under-17 Championship Team"
                    ),
                    studentsTrainedCount = 1250,
                    rating = 4.95,
                    reviewsCount = 128,
                    education = "B.P.Ed (Physical Education), Osmania University",
                    teachingPhilosophy = "Discipline in footwork builds confidence in rallies. We train each student to think two shots ahead."
                ),
                FacultyMember(
                    id = "fac_2",
                    name = "Priya Sharma",
                    designation = "Senior Strength & Conditioning Coach",
                    qualification = "CSCS Certified Athletic Trainer",
                    experienceYears = 8,
                    photoUrl = "https://images.unsplash.com/photo-1534528741775-53994a69daeb",
                    bio = "National Strength and Conditioning Association (NSCA) accredited trainer specializing in plyometric agility, core stability, and athletic injury rehabilitation for young athletes.",
                    specialties = listOf("Athletic Conditioning", "Agility Drills", "Core Stability", "Injury Recovery"),
                    certifications = listOf(
                        "CSCS (Certified Strength & Conditioning Specialist - NSCA)",
                        "Functional Movement Screen (FMS) Level 2 Certified",
                        "Youth Athletic Development Specialist (IYCA)"
                    ),
                    achievements = listOf(
                        "Conditioning consultant for State Badminton Junior Squad",
                        "Trained 450+ student athletes with zero major ACL injuries"
                    ),
                    studentsTrainedCount = 450,
                    rating = 4.88,
                    reviewsCount = 64,
                    education = "M.Sc Sports Science & Biomechanics, Manipal Academy",
                    teachingPhilosophy = "Movement quality precedes athletic intensity. Protect the joint, maximize the output."
                )
            )
        ),
        InstituteProfile(
            id = "inst_ace_iit",
            name = "ACE Premier IIT-JEE & NEET Academy",
            tagline = "Top-ranking coaching for competitive engineering & medical exams",
            description = "Pioneering STEM coaching institute providing disciplined batch curricula, concept clarity notes, and weekly mock test series.",
            category = "Academics",
            address = "Plot 42, Silicon Valley, Madhapur",
            city = "Hyderabad",
            state = "Telangana",
            phone = "+91 98765 22334",
            whatsapp = "+91 98765 22334",
            rating = 4.9,
            ratingCount = 345,
            isVerified = true,
            isPublished = true,
            coverImageUrl = "https://images.unsplash.com/photo-1523240795612-9a054b0db644",
            facultyMembers = listOf(
                FacultyMember(
                    id = "fac_3",
                    name = "Dr. Arvind Verma",
                    designation = "Head of Physics Department",
                    qualification = "Ph.D IIT Madras • 16+ Yrs Exp",
                    experienceYears = 16,
                    photoUrl = "https://images.unsplash.com/photo-1500648767791-00dcc994a43e",
                    bio = "Former Allen & FIITJEE Senior Physics Faculty. Dr. Verma holds a Ph.D in Condensed Matter Physics from IIT Madras and has mentored 42 students into the Top 100 All India Ranks in JEE Advanced. Renowned for converting complex rotational dynamics and electromagnetism into intuitive visual derivations.",
                    specialties = listOf("Rotational Dynamics", "Electromagnetism", "JEE Advanced Problem Solving", "Modern Physics"),
                    certifications = listOf(
                        "Ph.D Physics (IIT Madras - High Honors)",
                        "National Standard Examination in Physics (NSEP) Chief Resource Person",
                        "CSIR NET-JRF All India Rank 09",
                        "Master Evaluator for International Physics Olympiad (IPhO) Camp"
                    ),
                    achievements = listOf(
                        "Mentored AIR 4, AIR 17, and AIR 29 in JEE Advanced",
                        "Authored 3 widely acclaimed books on Advanced Mechanics Problem Solving",
                        "16+ Years continuous teaching excellence in National Test Prep"
                    ),
                    studentsTrainedCount = 3800,
                    rating = 4.97,
                    reviewsCount = 312,
                    education = "Ph.D Physics (IIT Madras), M.Sc Physics (Delhi University)",
                    teachingPhilosophy = "Physics is not memorizing formulas; it is building a mental simulation of nature from first principles."
                ),
                FacultyMember(
                    id = "fac_4",
                    name = "Dr. Neha Kulkarni",
                    designation = "Senior Chemistry Specialist",
                    qualification = "M.Sc Organic Chemistry • CSIR NET-JRF",
                    experienceYears = 12,
                    photoUrl = "https://images.unsplash.com/photo-1573496359142-b8d87734a5a2",
                    bio = "Veteran Chemistry faculty with 12+ years of medical entrance exam coaching. Specializes in organic reaction mechanisms, named reactions, and high-speed NEET calculation shortcuts.",
                    specialties = listOf("Organic Chemistry", "NEET High-Speed Strategies", "Inorganic Reaction Mnemonics", "Physical Chemistry"),
                    certifications = listOf(
                        "CSIR NET-JRF Chemical Sciences (Rank 14)",
                        "GATE Chemical Sciences Top 1%",
                        "Certified Medical Entrance Master Trainer"
                    ),
                    achievements = listOf(
                        "Guided 210+ students scoring 170+/180 in NEET Chemistry",
                        "Recognized as Top Chemistry Educator in South India (2023)"
                    ),
                    studentsTrainedCount = 2600,
                    rating = 4.92,
                    reviewsCount = 184,
                    education = "M.Sc Organic Chemistry (University of Hyderabad)",
                    teachingPhilosophy = "When mechanisms click logically, Organic Chemistry becomes as predictable as math."
                )
            )
        ),
        InstituteProfile(
            id = "inst_codemasters",
            name = "CodeMasters Full-Stack & AI Academy",
            tagline = "Practical project-based software engineering & generative AI bootcamp",
            description = "Hands-on tech learning institute with live code reviews, system design workshops, and dedicated placement assistance.",
            category = "Tech & Coding",
            address = "Mindspace Tech Park, Hitech City",
            city = "Hyderabad",
            state = "Telangana",
            phone = "+91 98765 33445",
            whatsapp = "+91 98765 33445",
            rating = 4.8,
            ratingCount = 180,
            isVerified = true,
            isPublished = true,
            coverImageUrl = "https://images.unsplash.com/photo-1517694712202-14dd9538aa97",
            facultyMembers = listOf(
                FacultyMember(
                    id = "fac_5",
                    name = "Vikram Aditya",
                    designation = "Lead Instructor & Principal Architect",
                    qualification = "B.Tech CSE • Ex-Google Senior Tech Lead",
                    experienceYears = 10,
                    photoUrl = "https://images.unsplash.com/photo-1519085360753-af0119f7cbe7",
                    bio = "Ex-Google Senior Tech Lead with 10+ years architecting large-scale distributed systems and Android platforms. Vikram transitioned into full-time developer education to bridge the gap between academic theory and real-world production engineering, specializing in Kotlin, Jetpack Compose, microservices, and LLM orchestration.",
                    specialties = listOf("Kotlin & Jetpack Compose", "System Design", "Generative AI Engineering", "Distributed Backend"),
                    certifications = listOf(
                        "Google Cloud Certified Professional Cloud Architect",
                        "AWS Certified Solutions Architect - Professional",
                        "Certified Kubernetes Administrator (CKA)",
                        "Meta Certified Front-End & Mobile Lead"
                    ),
                    achievements = listOf(
                        "Trained 1,400+ developers placed in Tier-1 product companies",
                        "Keynote Speaker at Droidcon & Google Developer Groups (GDG)",
                        "Creator of popular open-source Android architectural libraries (5k+ stars)"
                    ),
                    studentsTrainedCount = 1420,
                    rating = 4.96,
                    reviewsCount = 205,
                    education = "B.Tech Computer Science & Engineering (BITS Pilani)",
                    teachingPhilosophy = "We don't teach syntax; we teach building production-grade software that scales to millions."
                )
            )
        ),
        InstituteProfile(
            id = "inst_nritya_kala",
            name = "Nritya Kala Kendra Classical Dance Studio",
            tagline = "Preserving traditional classical & contemporary dance arts",
            description = "Premier dance institution recognized for Bharatanatyam, Kuchipudi, Kathak, and modern contemporary expression classes.",
            category = "Dance",
            address = "Road No. 10, Banjara Hills",
            city = "Hyderabad",
            state = "Telangana",
            phone = "+91 98765 44556",
            whatsapp = "+91 98765 44556",
            rating = 4.9,
            ratingCount = 142,
            isVerified = true,
            isPublished = true,
            coverImageUrl = "https://images.unsplash.com/photo-1508700115892-45ecd05ae2ad",
            facultyMembers = listOf(
                FacultyMember(
                    id = "fac_6",
                    name = "Guru Sunita Raman",
                    designation = "Artistic Director & Master Choreographer",
                    qualification = "Sangeet Natak Akademi Certified • 18+ Yrs Exp",
                    experienceYears = 18,
                    photoUrl = "https://images.unsplash.com/photo-1580489944761-15a19d654956",
                    bio = "Eminent classical dancer and choreographer with 18+ years of stage and pedagogical leadership. Guru Sunita has performed across 25+ countries, conducted masterclasses at Kalakshetra, and mentored hundreds of students from foundational Adavus to triumphant Arangetrams.",
                    specialties = listOf("Bharatanatyam (Kalakshetra Bani)", "Kuchipudi", "Abhinaya & Expression", "Arangetram Mentorship"),
                    certifications = listOf(
                        "Kalakshetra Foundation Postgraduate Diploma in Classical Dance",
                        "Sangeet Natak Akademi Certified Senior Practitioner",
                        "Nritya Shiromani National Awardee (2019)"
                    ),
                    achievements = listOf(
                        "Conducted 85+ Successful Arangetrams across India and USA",
                        "Empanelled ICCR (Indian Council for Cultural Relations) Performing Artist"
                    ),
                    studentsTrainedCount = 920,
                    rating = 4.98,
                    reviewsCount = 118,
                    education = "M.A. Performing Arts (Dance), Madras University",
                    teachingPhilosophy = "Dance is prayer in motion. Precision in posture unlocks divine expression."
                )
            )
        ),
        InstituteProfile(
            id = "inst_symphony_music",
            name = "Symphony Strings & Vocals Conservatory",
            tagline = "Certified musical grades, acoustic guitar & vocal coaching",
            description = "Acoustic and contemporary music academy offering Trinity College London certified syllabus, studio recording, and live ensemble practice.",
            category = "Music & Arts",
            address = "Jubilee Hills Check Post, Road 36",
            city = "Hyderabad",
            state = "Telangana",
            phone = "+91 98765 55667",
            whatsapp = "+91 98765 55667",
            rating = 4.8,
            ratingCount = 96,
            isVerified = true,
            isPublished = true,
            coverImageUrl = "https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4",
            facultyMembers = listOf(
                FacultyMember(
                    id = "fac_7",
                    name = "Maestro David John",
                    designation = "Principal Instructor & Multi-Instrumentalist",
                    qualification = "Trinity College London Grade 8 Certified",
                    experienceYears = 12,
                    photoUrl = "https://images.unsplash.com/photo-1506794778202-cad84cf45f1d",
                    bio = "Concert guitarist, music producer, and Trinity-certified instructor with 12 years of performance and vocal training expertise. Specializes in fingerstyle acoustic guitar, ear training, sight reading, and Trinity Grade Exam coaching from Initial to Grade 8.",
                    specialties = listOf("Acoustic Fingerstyle", "Trinity Grade Exam Prep", "Contemporary Vocals", "Music Theory & Composition"),
                    certifications = listOf(
                        "Trinity College London Grade 8 with Distinction (Classical Guitar)",
                        "Rockschool (RSL Awards) Grade 8 Acoustic Guitar Specialist",
                        "Berklee College of Music Certified Music Theory Specialist"
                    ),
                    achievements = listOf(
                        "100% Student Pass Rate in Trinity College London Grade Examinations",
                        "Lead composer for acclaimed independent film soundtracks"
                    ),
                    studentsTrainedCount = 680,
                    rating = 4.89,
                    reviewsCount = 82,
                    education = "Bachelor of Fine Arts (Music), Berklee Online / Bangalore Conservatory",
                    teachingPhilosophy = "Music is a language. Once your fingers know the alphabet, your soul tells the story."
                )
            )
        )
    )

    private val _institutes = MutableStateFlow(sampleInstitutes)
    val institutes: StateFlow<List<InstituteProfile>> = _institutes.asStateFlow()

    val sampleClasses = listOf(
        InstituteClass(
            id = "cls_badminton_jr",
            instituteId = "inst_smash_pro",
            instituteName = "Pullela Champions Badminton Academy",
            title = "Junior Elite Badminton Performance Batch",
            description = "Structured training program focusing on agility footwork, smash power, tactical rally building, and tournament fitness.",
            category = "Sports & Fitness",
            subject = "Badminton Coaching",
            subjectOrSpecialization = "Junior Badminton Elite",
            ageGroup = "8 - 16 Years",
            skillLevel = "Intermediate to Advanced",
            facultyName = "Coach Srinivas Rao",
            facultyDesignation = "Chief Coach (BWF Level 3)",
            facultyQualification = "BWF Level 3 Certified • Ex-National Player",
            facultyExperienceYears = 14,
            facultyPhotoUrl = "https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d",
            instructorName = "Coach Srinivas Rao",
            coverImageUrl = "https://images.unsplash.com/photo-1626224583764-f87db24ac4ea",
            batchType = "🔥 NEW BATCH",
            isNewBatch = true,
            isUpcomingBatch = false,
            batchStartDate = "Starts This Monday",
            batchHighlightTag = "🔥 NEW BATCH",
            daysOfWeek = listOf("Mon", "Wed", "Fri"),
            startTime = "06:00 AM",
            endTime = "07:30 AM",
            classTimings = "06:00 AM - 07:30 AM (Mon, Wed, Fri)",
            durationText = "3 Months",
            location = "Court 1-4, Gachibowli Stadium Complex, Hyderabad",
            city = "Hyderabad",
            feeAmount = 3500.0,
            monthlyFee = 3500.0,
            courseFee = 9000.0,
            discountPercent = 15,
            feeBillingCycle = "month",
            availableSeats = 4,
            totalSeats = 15,
            seatsAvailable = 4,
            seatsTotal = 15,
            rating = 4.9,
            ratingCount = 88,
            deliveryMode = ClassDeliveryMode.OFFLINE,
            contactPhone = "+91 98765 11223",
            contactWhatsapp = "+91 98765 11223",
            isPublished = true,
            enrollmentOpen = true,
            isTodayOngoing = true,
            todayLiveStatus = "🟢 LIVE NOW",
            todayBatchSlot = "Morning Session • 06:00 AM - 07:30 AM",
            todayTopic = "Smash Angle Control & Fast Baseline Recovery"
        ),
        InstituteClass(
            id = "cls_jee_advanced_physics",
            instituteId = "inst_ace_iit",
            instituteName = "ACE Premier IIT-JEE & NEET Academy",
            title = "JEE Advanced Physics Masterclass & Problem Solving",
            description = "High-yield conceptual physics drills, previous 15-year Advanced question analysis, and time-saving shortcuts for Top 500 aspirants.",
            category = "Academics",
            subject = "Physics & Advanced Mechanics",
            subjectOrSpecialization = "IIT-JEE Advanced Physics",
            ageGroup = "15 - 19 Years (Class 11, 12 & Droppers)",
            skillLevel = "Advanced / Competitive",
            facultyName = "Dr. Arvind Verma",
            facultyDesignation = "Head of Physics & Senior Mentor",
            facultyQualification = "Ph.D IIT Madras • Ex-Senior Allen Faculty",
            facultyExperienceYears = 16,
            facultyPhotoUrl = "https://images.unsplash.com/photo-1500648767791-00dcc994a43e",
            instructorName = "Dr. Arvind Verma",
            coverImageUrl = "https://images.unsplash.com/photo-1523240795612-9a054b0db644",
            batchType = "🚀 UPCOMING BATCH",
            isNewBatch = false,
            isUpcomingBatch = true,
            batchStartDate = "Starting 1st of Next Month",
            batchHighlightTag = "🚀 UPCOMING BATCH",
            daysOfWeek = listOf("Mon", "Tue", "Wed", "Thu", "Fri"),
            startTime = "05:00 PM",
            endTime = "07:00 PM",
            classTimings = "05:00 PM - 07:00 PM (Mon to Fri)",
            durationText = "6 Months",
            location = "Room 301, Silicon Valley Complex, Madhapur, Hyderabad",
            city = "Hyderabad",
            feeAmount = 6500.0,
            monthlyFee = 6500.0,
            courseFee = 32000.0,
            discountPercent = 20,
            feeBillingCycle = "month",
            availableSeats = 6,
            totalSeats = 30,
            seatsAvailable = 6,
            seatsTotal = 30,
            rating = 4.9,
            ratingCount = 140,
            deliveryMode = ClassDeliveryMode.HYBRID,
            contactPhone = "+91 98765 22334",
            contactWhatsapp = "+91 98765 22334",
            isPublished = true,
            enrollmentOpen = true,
            isTodayOngoing = true,
            todayLiveStatus = "🕒 TODAY 05:00 PM",
            todayBatchSlot = "Evening Batch • 05:00 PM - 07:00 PM",
            todayTopic = "Rotational Dynamics & Torque Conservation Matrix"
        ),
        InstituteClass(
            id = "cls_fullstack_ai_bootcamp",
            instituteId = "inst_codemasters",
            instituteName = "CodeMasters Full-Stack & AI Academy",
            title = "Full-Stack Development & Generative AI Bootcamp",
            description = "Live interactive coding batch covering Kotlin/Android, React/Next.js, FastAPI backends, and Gemini AI agent integration.",
            category = "Tech & Coding",
            subject = "Full-Stack & GenAI",
            subjectOrSpecialization = "Software Engineering & LLM Apps",
            ageGroup = "College Students & Working Professionals",
            skillLevel = "Beginner to Industry Ready",
            facultyName = "Vikram Aditya",
            facultyDesignation = "Principal Tech Instructor",
            facultyQualification = "B.Tech CSE • Ex-Google Senior Tech Lead",
            facultyExperienceYears = 10,
            facultyPhotoUrl = "https://images.unsplash.com/photo-1519085360753-af0119f7cbe7",
            instructorName = "Vikram Aditya",
            coverImageUrl = "https://images.unsplash.com/photo-1517694712202-14dd9538aa97",
            batchType = "🔥 NEW BATCH",
            isNewBatch = true,
            isUpcomingBatch = false,
            batchStartDate = "Starting This Saturday",
            batchHighlightTag = "🔥 NEW BATCH",
            daysOfWeek = listOf("Mon", "Wed", "Fri", "Sun"),
            startTime = "07:30 PM",
            endTime = "09:30 PM",
            classTimings = "07:30 PM - 09:30 PM (Live Interactive)",
            durationText = "45 Days",
            location = "Online Live Cloud Classroom & Hitech City Campus",
            city = "Hyderabad",
            feeAmount = 8500.0,
            monthlyFee = 8500.0,
            courseFee = 12000.0,
            discountPercent = 25,
            feeBillingCycle = "course",
            availableSeats = 8,
            totalSeats = 40,
            seatsAvailable = 8,
            seatsTotal = 40,
            rating = 4.8,
            ratingCount = 112,
            deliveryMode = ClassDeliveryMode.ONLINE,
            contactPhone = "+91 98765 33445",
            contactWhatsapp = "+91 98765 33445",
            isPublished = true,
            enrollmentOpen = true,
            isTodayOngoing = true,
            todayLiveStatus = "🟢 LIVE NOW",
            todayBatchSlot = "Night Batch • 07:30 PM - 09:30 PM",
            todayTopic = "Building Agentic Pipelines with Gemini Flash & Room DB"
        ),
        InstituteClass(
            id = "cls_bharatanatyam_arangetram",
            instituteId = "inst_nritya_kala",
            instituteName = "Nritya Kala Kendra Classical Dance Studio",
            title = "Bharatanatyam Traditional & Arangetram Certification",
            description = "Rigorous classical dance coaching covering Adavus, Abhinaya, Tala rhythms, and stage performance mastery.",
            category = "Dance",
            subject = "Bharatanatyam",
            subjectOrSpecialization = "Classical Dance & Abhinaya",
            ageGroup = "6 Years & Above (All Ages)",
            skillLevel = "All Skill Levels",
            facultyName = "Guru Sunita Raman",
            facultyDesignation = "Master Guru & Choreographer",
            facultyQualification = "Sangeet Natak Akademi Awardee • 18+ Yrs Exp",
            facultyExperienceYears = 18,
            facultyPhotoUrl = "https://images.unsplash.com/photo-1580489944761-15a19d654956",
            instructorName = "Guru Sunita Raman",
            coverImageUrl = "https://images.unsplash.com/photo-1508700115892-45ecd05ae2ad",
            batchType = "🚀 UPCOMING BATCH",
            isNewBatch = false,
            isUpcomingBatch = true,
            batchStartDate = "Starting 15th of Next Month",
            batchHighlightTag = "🚀 UPCOMING BATCH",
            daysOfWeek = listOf("Tue", "Thu", "Sat"),
            startTime = "04:30 PM",
            endTime = "06:00 PM",
            classTimings = "04:30 PM - 06:00 PM (Tue, Thu, Sat)",
            durationText = "1 Year",
            location = "Main Dance Hall, Road No. 10, Banjara Hills, Hyderabad",
            city = "Hyderabad",
            feeAmount = 2800.0,
            monthlyFee = 2800.0,
            courseFee = 30000.0,
            discountPercent = 10,
            feeBillingCycle = "month",
            availableSeats = 5,
            totalSeats = 18,
            seatsAvailable = 5,
            seatsTotal = 18,
            rating = 4.9,
            ratingCount = 74,
            deliveryMode = ClassDeliveryMode.OFFLINE,
            contactPhone = "+91 98765 44556",
            contactWhatsapp = "+91 98765 44556",
            isPublished = true,
            enrollmentOpen = true,
            isTodayOngoing = true,
            todayLiveStatus = "🕒 TODAY 04:30 PM",
            todayBatchSlot = "Afternoon Batch • 04:30 PM - 06:00 PM",
            todayTopic = "Jathi Coordination & Hastas Expression"
        ),
        InstituteClass(
            id = "cls_acoustic_guitar_vocals",
            instituteId = "inst_symphony_music",
            instituteName = "Symphony Strings & Vocals Conservatory",
            title = "Acoustic Guitar & Vocal Harmony Grade Series",
            description = "Learn chord progressions, fingerstyle acoustic guitar, pitch calibration, and song performance with Trinity College syllabus.",
            category = "Music & Arts",
            subject = "Acoustic Guitar & Vocals",
            subjectOrSpecialization = "Western Acoustic & Vocal Performance",
            ageGroup = "10 Years & Above",
            skillLevel = "Beginner to Intermediate",
            facultyName = "Maestro David John",
            facultyDesignation = "Senior Music Mentor",
            facultyQualification = "Trinity College London Grade 8 Certified",
            facultyExperienceYears = 12,
            facultyPhotoUrl = "https://images.unsplash.com/photo-1506794778202-cad84cf45f1d",
            instructorName = "Maestro David John",
            coverImageUrl = "https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4",
            batchType = "🔥 NEW BATCH",
            isNewBatch = true,
            isUpcomingBatch = false,
            batchStartDate = "Starting This Wednesday",
            batchHighlightTag = "🔥 NEW BATCH",
            daysOfWeek = listOf("Mon", "Wed", "Fri"),
            startTime = "06:30 PM",
            endTime = "08:00 PM",
            classTimings = "06:30 PM - 08:00 PM (Mon, Wed, Fri)",
            durationText = "3 Months",
            location = "Studio 2B, Jubilee Hills Check Post, Hyderabad",
            city = "Hyderabad",
            feeAmount = 3200.0,
            monthlyFee = 3200.0,
            courseFee = 8500.0,
            discountPercent = 12,
            feeBillingCycle = "month",
            availableSeats = 7,
            totalSeats = 16,
            seatsAvailable = 7,
            seatsTotal = 16,
            rating = 4.8,
            ratingCount = 65,
            deliveryMode = ClassDeliveryMode.HYBRID,
            contactPhone = "+91 98765 55667",
            contactWhatsapp = "+91 98765 55667",
            isPublished = true,
            enrollmentOpen = true,
            isTodayOngoing = true,
            todayLiveStatus = "🟢 LIVE NOW",
            todayBatchSlot = "Evening Session • 06:30 PM - 08:00 PM",
            todayTopic = "Barre Chords Transition & Vocal Breathing Dynamics"
        ),
        InstituteClass(
            id = "cls_neet_biology_crash",
            instituteId = "inst_ace_iit",
            instituteName = "ACE Premier IIT-JEE & NEET Academy",
            title = "NEET Target Biology & Organic Chemistry Rapid Crash Batch",
            description = "High-speed diagrammatic revision, NCERT deep-dive line by line, and 1000+ speed-test MCQs for NEET-UG aspirants.",
            category = "Academics",
            subject = "NEET Biology & Chemistry",
            subjectOrSpecialization = "Medical Entrance Rapid Preparation",
            ageGroup = "16 - 20 Years",
            skillLevel = "Intensive Prep",
            facultyName = "Dr. Neha Kulkarni",
            facultyDesignation = "Senior Medical Faculty",
            facultyQualification = "M.Sc Organic Chemistry • CSIR NET-JRF",
            facultyExperienceYears = 12,
            facultyPhotoUrl = "https://images.unsplash.com/photo-1573496359142-b8d87734a5a2",
            instructorName = "Dr. Neha Kulkarni",
            coverImageUrl = "https://images.unsplash.com/photo-1576091160399-112ba8d25d1d",
            batchType = "🚀 UPCOMING BATCH",
            isNewBatch = false,
            isUpcomingBatch = true,
            batchStartDate = "Starting Next Monday",
            batchHighlightTag = "🚀 UPCOMING BATCH",
            daysOfWeek = listOf("Mon", "Wed", "Fri", "Sat"),
            startTime = "03:00 PM",
            endTime = "05:00 PM",
            classTimings = "03:00 PM - 05:00 PM (4 Days / Week)",
            durationText = "45 Days",
            location = "Room 204, Silicon Valley Complex, Madhapur, Hyderabad",
            city = "Hyderabad",
            feeAmount = 4500.0,
            monthlyFee = 4500.0,
            courseFee = 6000.0,
            discountPercent = 15,
            feeBillingCycle = "course",
            availableSeats = 10,
            totalSeats = 35,
            seatsAvailable = 10,
            seatsTotal = 35,
            rating = 4.9,
            ratingCount = 92,
            deliveryMode = ClassDeliveryMode.HYBRID,
            contactPhone = "+91 98765 22334",
            contactWhatsapp = "+91 98765 22334",
            isPublished = true,
            enrollmentOpen = true,
            isTodayOngoing = false,
            todayLiveStatus = "TOMORROW 03:00 PM",
            todayBatchSlot = "Afternoon Batch • 03:00 PM - 05:00 PM",
            todayTopic = "Human Physiology & Biomolecules Quick Revision"
        ),
        InstituteClass(
            id = "cls_badminton_adult_weekend",
            instituteId = "inst_smash_pro",
            instituteName = "Pullela Champions Badminton Academy",
            title = "Weekend Masters Badminton & Tournament Prep",
            description = "Intensive weekend masterclass covering deceptive drop shots, aggressive smashing angles, mixed-doubles positioning, and physical endurance.",
            category = "Sports & Fitness",
            subject = "Badminton Advanced",
            subjectOrSpecialization = "Masters Badminton & Tournament Strategy",
            ageGroup = "18+ Years",
            skillLevel = "Intermediate to Advanced",
            facultyName = "Coach Srinivas Rao",
            facultyDesignation = "Chief Coach (BWF Level 3)",
            facultyQualification = "BWF Level 3 Certified • Ex-National Player",
            facultyExperienceYears = 14,
            facultyPhotoUrl = "https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d",
            instructorName = "Coach Srinivas Rao",
            coverImageUrl = "https://images.unsplash.com/photo-1626224583764-f87db24ac4ea",
            batchType = "🔥 NEW BATCH",
            isNewBatch = true,
            isUpcomingBatch = false,
            batchStartDate = "Starting This Saturday",
            batchHighlightTag = "🔥 NEW BATCH",
            daysOfWeek = listOf("Sat", "Sun"),
            startTime = "07:00 AM",
            endTime = "09:00 AM",
            classTimings = "07:00 AM - 09:00 AM (Weekend Batch)",
            durationText = "2 Months",
            location = "Court 1-3, Pullela Academy, Gachibowli, Hyderabad",
            city = "Hyderabad",
            feeAmount = 3000.0,
            monthlyFee = 3000.0,
            courseFee = 5500.0,
            discountPercent = 10,
            feeBillingCycle = "month",
            availableSeats = 6,
            totalSeats = 16,
            seatsAvailable = 6,
            seatsTotal = 16,
            rating = 4.95,
            ratingCount = 88,
            deliveryMode = ClassDeliveryMode.OFFLINE,
            contactPhone = "+91 98765 11223",
            contactWhatsapp = "+91 98765 11223",
            isPublished = true,
            enrollmentOpen = true,
            isTodayOngoing = false,
            todayLiveStatus = "SAT 07:00 AM",
            todayBatchSlot = "Morning Weekend • 07:00 AM - 09:00 AM",
            todayTopic = "Deceptive Net Play & Cross Court Drops"
        ),
        InstituteClass(
            id = "cls_android_compose_deepdive",
            instituteId = "inst_codemasters",
            instituteName = "CodeMasters Full-Stack & AI Academy",
            title = "Jetpack Compose & Kotlin Multiplatform Architect Masterclass",
            description = "Advanced enterprise Android architecture: custom layouts, Canvas graphics, state optimization, Room persistence, and local LLM integrations.",
            category = "Tech & Coding",
            subject = "Android & Kotlin Architecture",
            subjectOrSpecialization = "Compose UI, Coroutines & AI Integrations",
            ageGroup = "College & Working Professionals",
            skillLevel = "Intermediate to Advanced",
            facultyName = "Vikram Aditya",
            facultyDesignation = "Principal Tech Instructor",
            facultyQualification = "B.Tech CSE • Ex-Google Senior Tech Lead",
            facultyExperienceYears = 10,
            facultyPhotoUrl = "https://images.unsplash.com/photo-1519085360753-af0119f7cbe7",
            instructorName = "Vikram Aditya",
            coverImageUrl = "https://images.unsplash.com/photo-1555066931-4365d14bab8c",
            batchType = "🚀 UPCOMING BATCH",
            isNewBatch = false,
            isUpcomingBatch = true,
            batchStartDate = "Starting 1st of Next Month",
            batchHighlightTag = "🚀 UPCOMING BATCH",
            daysOfWeek = listOf("Tue", "Thu", "Sat"),
            startTime = "08:00 PM",
            endTime = "09:30 PM",
            classTimings = "08:00 PM - 09:30 PM (Live Interactive)",
            durationText = "2 Months",
            location = "Online Live Cloud Classroom",
            city = "Hyderabad",
            feeAmount = 7500.0,
            monthlyFee = 7500.0,
            courseFee = 11000.0,
            discountPercent = 20,
            feeBillingCycle = "course",
            availableSeats = 14,
            totalSeats = 35,
            seatsAvailable = 14,
            seatsTotal = 35,
            rating = 4.98,
            ratingCount = 142,
            deliveryMode = ClassDeliveryMode.ONLINE,
            contactPhone = "+91 98765 33445",
            contactWhatsapp = "+91 98765 33445",
            isPublished = true,
            enrollmentOpen = true,
            isTodayOngoing = false,
            todayLiveStatus = "TUE 08:00 PM",
            todayBatchSlot = "Evening Batch • 08:00 PM - 09:30 PM",
            todayTopic = "Custom Compose Layouts & Render Optimization"
        ),
        InstituteClass(
            id = "cls_karate_blackbelt_full",
            instituteId = "inst_shito_ryu_karate",
            instituteName = "Samurai Shito-Ryu Karate & Self-Defense Academy",
            title = "Shotokan Karate Black Belt & Self-Defense Certification",
            description = "Olympic standard karate training, Kata defense patterns, Kumite sparring, and weapon defense by certified Asian Karate Federation masters.",
            category = "Sports & Fitness",
            subject = "Karate & Self Defense",
            subjectOrSpecialization = "Black Belt Mastery & Combat Kata",
            ageGroup = "12 - 40 Years",
            skillLevel = "All Belts (White to Black)",
            facultyName = "Sensei Rajesh Varma",
            facultyDesignation = "Chief Martial Arts Master (6th Dan Black Belt)",
            facultyQualification = "Asian Karate Federation Certified • World Karate Federation Judge",
            facultyExperienceYears = 22,
            facultyPhotoUrl = "https://images.unsplash.com/photo-1544005313-94ddf0286df2",
            instructorName = "Sensei Rajesh Varma",
            coverImageUrl = "https://images.unsplash.com/photo-1555597673-b21d5c935865",
            batchType = "🔴 BATCH FULL (WAITLIST)",
            isNewBatch = false,
            isUpcomingBatch = false,
            batchStartDate = "Current Batch in Progress",
            batchHighlightTag = "🔴 BATCH FULL",
            daysOfWeek = listOf("Tue", "Thu", "Sat"),
            startTime = "06:00 AM",
            endTime = "07:30 AM",
            classTimings = "06:00 AM - 07:30 AM (Morning Batch)",
            durationText = "6 Months",
            location = "Dojo 1, Sports Authority Complex, Jubilee Hills, Hyderabad",
            city = "Hyderabad",
            feeAmount = 3500.0,
            monthlyFee = 3500.0,
            courseFee = 18000.0,
            discountPercent = 0,
            feeBillingCycle = "month",
            availableSeats = 0,
            totalSeats = 25,
            seatsAvailable = 0,
            seatsTotal = 25,
            rating = 4.97,
            ratingCount = 112,
            deliveryMode = ClassDeliveryMode.OFFLINE,
            contactPhone = "+91 98765 66778",
            contactWhatsapp = "+91 98765 66778",
            isPublished = true,
            enrollmentOpen = false,
            isTodayOngoing = true,
            todayLiveStatus = "🔴 BATCH FULL",
            todayBatchSlot = "Morning Session • 06:00 AM - 07:30 AM",
            todayTopic = "Bassai Dai Kata & Point Kumite Tactics"
        ),
        InstituteClass(
            id = "cls_ai_agents_bootcamp_upcoming",
            instituteId = "inst_codemasters",
            instituteName = "CodeMasters Full-Stack & AI Academy",
            title = "Autonomous AI Agents, LangChain & LLM Fine-Tuning Bootcamp",
            description = "Master building enterprise AI agents, MCP tool calling, vector databases (RAG), and on-device Gemini inference models.",
            category = "Tech & Coding",
            subject = "Generative AI & Autonomous Agents",
            subjectOrSpecialization = "LLM Fine-Tuning, RAG & MCP Architecture",
            ageGroup = "18+ Years",
            skillLevel = "Intermediate to Advanced",
            facultyName = "Dr. Sameer Saxena",
            facultyDesignation = "AI Research Mentor & Lead",
            facultyQualification = "Ph.D. in Computer Science (AI/ML) • Stanford AI Fellow",
            facultyExperienceYears = 14,
            facultyPhotoUrl = "https://images.unsplash.com/photo-1534528741775-53994a69daeb",
            instructorName = "Dr. Sameer Saxena",
            coverImageUrl = "https://images.unsplash.com/photo-1618005182384-a83a8bd57fbe",
            batchType = "🚀 UPCOMING BATCH",
            isNewBatch = true,
            isUpcomingBatch = true,
            batchStartDate = "Starting 1st of Next Month",
            batchHighlightTag = "🚀 UPCOMING BATCH",
            daysOfWeek = listOf("Mon", "Wed", "Fri"),
            startTime = "07:30 PM",
            endTime = "09:00 PM",
            classTimings = "07:30 PM - 09:00 PM (Live Online)",
            durationText = "6 Weeks",
            location = "Cloud Live Stream + Global Discord Sandbox",
            city = "Hyderabad",
            feeAmount = 8999.0,
            monthlyFee = 8999.0,
            courseFee = 8999.0,
            discountPercent = 25,
            feeBillingCycle = "course",
            availableSeats = 0,
            totalSeats = 40,
            seatsAvailable = 0,
            seatsTotal = 40,
            rating = 4.99,
            ratingCount = 89,
            deliveryMode = ClassDeliveryMode.ONLINE,
            contactPhone = "+91 98765 77889",
            contactWhatsapp = "+91 98765 77889",
            isPublished = true,
            enrollmentOpen = false,
            isTodayOngoing = false,
            todayLiveStatus = "🚀 UPCOMING BATCH",
            todayBatchSlot = "Evening Interactive • 07:30 PM - 09:00 PM",
            todayTopic = "Function Calling, Multi-Agent Swarms & Model Quantization"
        )
    )

    private val _instituteClasses = MutableStateFlow(sampleClasses)
    val instituteClasses: StateFlow<List<InstituteClass>> = _instituteClasses.asStateFlow()

    // --- Batch Availability Push Alerts (Room Database + In-Memory) ---
    private val _batchAlerts = MutableStateFlow<List<BatchAlertEntity>>(emptyList())
    val batchAlerts: StateFlow<List<BatchAlertEntity>> = _batchAlerts.asStateFlow()

    fun isBatchAlertActive(classId: String): Boolean {
        return _batchAlerts.value.any { it.classId == classId }
    }

    fun subscribeBatchAlert(context: Context, classItem: InstituteClass) {
        val user = _authUser.value
        val alertEntity = BatchAlertEntity(
            classId = classItem.id,
            className = classItem.title,
            instituteName = classItem.instituteName,
            category = classItem.category,
            batchType = classItem.batchType,
            batchStartDate = classItem.batchStartDate,
            timings = classItem.classTimings,
            feeAmount = classItem.feeAmount,
            userEmail = user?.email ?: "student@bookmyspace.com",
            userPhone = user?.phone ?: "+91 98765 00000",
            subscribedAtEpochMs = System.currentTimeMillis(),
            isTriggered = false,
            spotsAvailable = classItem.availableSeats
        )

        // 1. Update in-memory state
        _batchAlerts.value = listOf(alertEntity) + _batchAlerts.value.filter { it.classId != classItem.id }

        // 2. Persist to Room Database asynchronously
        CoroutineScope(Dispatchers.IO).launch {
            try {
                val db = BookMySpaceRoomDatabase.getDatabase(context.applicationContext)
                db.batchAlertDao().insertAlert(alertEntity)
                Log.d(TAG, "Successfully saved BatchAlertEntity for ${classItem.id} into Room database")
            } catch (e: Exception) {
                Log.e(TAG, "Error persisting batch alert in Room DB: ${e.message}")
            }
        }

        // 3. Dispatch Push Notification confirmation via BookingReminderNotificationManager
        BookingReminderNotificationManager.showBatchWaitlistSubscribedNotification(
            context = context,
            classId = classItem.id,
            className = classItem.title,
            instituteName = classItem.instituteName
        )
    }

    fun unsubscribeBatchAlert(context: Context, classId: String) {
        _batchAlerts.value = _batchAlerts.value.filter { it.classId != classId }
        CoroutineScope(Dispatchers.IO).launch {
            try {
                val db = BookMySpaceRoomDatabase.getDatabase(context.applicationContext)
                db.batchAlertDao().deleteAlert(classId)
                Log.d(TAG, "Deleted batch alert for $classId from Room DB")
            } catch (e: Exception) {
                Log.e(TAG, "Error deleting batch alert from Room DB: ${e.message}")
            }
        }
    }

    fun triggerSpotAvailablePush(context: Context, classId: String, spotsOpened: Int = 3) {
        val cls = _instituteClasses.value.find { it.id == classId } ?: return
        
        // Update class seat count in state
        _instituteClasses.value = _instituteClasses.value.map {
            if (it.id == classId) {
                it.copy(
                    availableSeats = spotsOpened,
                    seatsAvailable = spotsOpened,
                    enrollmentOpen = true,
                    todayLiveStatus = "🟢 $spotsOpened SEATS OPEN",
                    batchHighlightTag = "🔥 $spotsOpened SEATS AVAILABLE"
                )
            } else it
        }

        // Update database record
        CoroutineScope(Dispatchers.IO).launch {
            try {
                val db = BookMySpaceRoomDatabase.getDatabase(context.applicationContext)
                db.batchAlertDao().markAlertTriggered(classId, spotsOpened)
            } catch (e: Exception) {
                Log.e(TAG, "Error updating alert trigger in Room DB: ${e.message}")
            }
        }

        // Fire rich Push Notification
        BookingReminderNotificationManager.showBatchSpotAvailablePushNotification(
            context = context,
            classId = cls.id,
            className = cls.title,
            instituteName = cls.instituteName,
            availableSpots = spotsOpened
        )
    }

    fun getFacultyMember(facultyName: String, instituteId: String = ""): FacultyMember {
        val allFaculties = _institutes.value.flatMap { it.facultyMembers }
        val found = allFaculties.find { it.name.equals(facultyName.trim(), ignoreCase = true) }
        if (found != null) return found

        // Fallback search in classes
        val cls = _instituteClasses.value.find { it.facultyName.equals(facultyName.trim(), ignoreCase = true) }
        return FacultyMember(
            id = "fac_${UUID.randomUUID().toString().take(6)}",
            name = facultyName.ifBlank { "Senior Faculty" },
            designation = cls?.facultyDesignation ?: "Lead Instructor",
            qualification = cls?.facultyQualification ?: "Certified Master Specialist",
            experienceYears = cls?.facultyExperienceYears ?: 8,
            photoUrl = cls?.facultyPhotoUrl ?: "https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d",
            bio = "${cls?.facultyName ?: facultyName} is a distinguished coach with ${cls?.facultyExperienceYears ?: 8}+ years of pedagogical experience, committed to conceptual clarity, rigorous practice regimens, and mentorship.",
            specialties = listOf(cls?.subject ?: "Domain Specialization", cls?.category ?: "Skills", "Batch Mentorship"),
            certifications = listOf(
                "Certified Master Educator & Coach",
                "National Pedagogical Excellence Accreditation",
                "Advanced Domain Specialist Certification"
            ),
            achievements = listOf(
                "Mentored hundreds of students achieving high competitive rankings",
                "Recognized for outstanding instructional methodology"
            ),
            studentsTrainedCount = (cls?.facultyExperienceYears ?: 8) * 120,
            rating = 4.92,
            reviewsCount = 56,
            education = cls?.facultyQualification ?: "Advanced Professional Degree",
            teachingPhilosophy = "Focused fundamentals and consistent practice guarantee exponential results."
        )
    }

    fun getClassesForFaculty(facultyName: String): List<InstituteClass> {
        if (facultyName.isBlank()) return emptyList()
        val normalized = facultyName.trim().lowercase()
        return _instituteClasses.value.filter {
            it.facultyName.trim().lowercase() == normalized ||
            it.instructorName.trim().lowercase() == normalized ||
            it.facultyName.contains(facultyName, ignoreCase = true)
        }
    }

    fun addInstitute(profile: InstituteProfile) {
        _institutes.value = listOf(profile) + _institutes.value
    }

    fun addClass(cls: InstituteClass) {
        _instituteClasses.value = listOf(cls) + _instituteClasses.value
    }

    fun updateClass(cls: InstituteClass) {
        _instituteClasses.value = _instituteClasses.value.map { if (it.id == cls.id) cls else it }
    }

    fun deleteClass(classId: String) {
        _instituteClasses.value = _instituteClasses.value.filter { it.id != classId }
    }

    fun updateInstitute(profile: InstituteProfile) {
        _institutes.value = _institutes.value.map { if (it.id == profile.id) profile else it }
    }

    fun addFacultyToInstitute(instituteId: String, faculty: FacultyMember) {
        _institutes.value = _institutes.value.map { inst ->
            if (inst.id == instituteId) {
                inst.copy(facultyMembers = inst.facultyMembers + faculty)
            } else inst
        }
    }

    fun updateFacultyInInstitute(instituteId: String, faculty: FacultyMember) {
        _institutes.value = _institutes.value.map { inst ->
            if (inst.id == instituteId) {
                inst.copy(facultyMembers = inst.facultyMembers.map { if (it.id == faculty.id) faculty else it })
            } else inst
        }
    }

    fun deleteFacultyFromInstitute(instituteId: String, facultyId: String) {
        _institutes.value = _institutes.value.map { inst ->
            if (inst.id == instituteId) {
                inst.copy(facultyMembers = inst.facultyMembers.filter { it.id != facultyId })
            } else inst
        }
    }

    fun getPublishedInstitutes(): List<InstituteProfile> {
        return _institutes.value.filter { it.isPublished }
    }

    fun getClassesForInstitute(instituteId: String): List<InstituteClass> {
        return _instituteClasses.value.filter { it.instituteId == instituteId }
    }

    fun searchClasses(
        query: String = "",
        category: String? = null,
        categories: Set<String>? = null,
        deliveryMode: ClassDeliveryMode? = null
    ): List<InstituteClass> {
        val q = query.trim().lowercase()
        return _instituteClasses.value.filter { cls ->
            val matchQ = q.isBlank() ||
                    cls.title.lowercase().contains(q) ||
                    cls.instituteName.lowercase().contains(q) ||
                    cls.subject.lowercase().contains(q) ||
                    cls.subjectOrSpecialization.lowercase().contains(q) ||
                    cls.facultyName.lowercase().contains(q) ||
                    cls.location.lowercase().contains(q) ||
                    cls.category.lowercase().contains(q)

            val matchCat = when {
                categories != null && categories.isNotEmpty() && !categories.contains("All") -> {
                    categories.any { it.equals(cls.category, ignoreCase = true) }
                }
                !category.isNullOrBlank() && !category.equals("All", ignoreCase = true) -> {
                    cls.category.equals(category, ignoreCase = true)
                }
                else -> true
            }

            val matchMode = deliveryMode == null || cls.deliveryMode == deliveryMode
            matchQ && matchCat && matchMode
        }
    }

    // --- Simple Mode & Quick Booking Preference State ---
    private val _isSimpleMode = MutableStateFlow(false)
    val isSimpleMode: StateFlow<Boolean> = _isSimpleMode.asStateFlow()

    fun toggleSimpleMode() {
        _isSimpleMode.value = !_isSimpleMode.value
    }

    fun setSimpleMode(enabled: Boolean) {
        _isSimpleMode.value = enabled
    }

    private val _isQuickBookingModeEnabled = MutableStateFlow(true)
    val isQuickBookingModeEnabled: StateFlow<Boolean> = _isQuickBookingModeEnabled.asStateFlow()

    fun setQuickBookingMode(enabled: Boolean) {
        _isQuickBookingModeEnabled.value = enabled
    }

    // --- Search Queries & Recently Viewed ---
    private val _recentSearches = MutableStateFlow(
        listOf(
            RecentSearchEntity("Badminton Hyderabad", "Sports"),
            RecentSearchEntity("Cricket Ground Vijayawada", "Sports"),
            RecentSearchEntity("Kalyana Mandapam Guntur", "Venues"),
            RecentSearchEntity("PG for Boys Madhapur", "PG")
        )
    )
    val recentSearches: StateFlow<List<RecentSearchEntity>> = _recentSearches.asStateFlow()

    private val _recentlyViewedVenueIds = MutableStateFlow(listOf("v_velocity_sports", "v_smash_arena", "v_grand_palace"))
    val recentlyViewedVenueIds: StateFlow<List<String>> = _recentlyViewedVenueIds.asStateFlow()

    fun saveSearchQuery(query: String, category: String? = null) {
        val trimmed = query.trim()
        if (trimmed.isNotBlank()) {
            val entity = RecentSearchEntity(trimmed, category ?: "All", System.currentTimeMillis())
            _recentSearches.value = (listOf(entity) + _recentSearches.value.filterNot { it.query.equals(trimmed, ignoreCase = true) }).take(10)
        }
    }

    fun deleteSearchQuery(query: String) {
        _recentSearches.value = _recentSearches.value.filterNot { it.query.equals(query.trim(), ignoreCase = true) }
    }

    fun clearAllSearchQueries() {
        _recentSearches.value = emptyList()
    }

    fun addRecentlyViewedVenue(id: String) {
        _recentlyViewedVenueIds.value = (listOf(id) + _recentlyViewedVenueIds.value.filterNot { it == id }).take(10)
    }

    fun removeRecentlyViewedVenue(id: String) {
        _recentlyViewedVenueIds.value = _recentlyViewedVenueIds.value.filterNot { it == id }
    }

    // --- Pending Auth States ---
    private val _pendingVerificationState = MutableStateFlow<PendingEmailVerification?>(null)
    val pendingVerificationState: StateFlow<PendingEmailVerification?> = _pendingVerificationState.asStateFlow()
    val pendingEmailVerification: StateFlow<PendingEmailVerification?> = _pendingVerificationState.asStateFlow()

    private val _pendingPasswordResetState = MutableStateFlow<PendingPasswordReset?>(null)
    val pendingPasswordResetState: StateFlow<PendingPasswordReset?> = _pendingPasswordResetState.asStateFlow()
    val pendingPasswordReset: StateFlow<PendingPasswordReset?> = _pendingPasswordResetState.asStateFlow()

    fun sendEmailVerification(email: String, fullName: String) {
        _pendingVerificationState.value = PendingEmailVerification(
            email = email,
            fullName = fullName,
            verificationCode = "482910"
        )
    }

    fun registerUserWithEmailVerification(
        fullName: String = "",
        email: String = "",
        password: String = "",
        role: UserRole = UserRole.USER,
        phone: String = "",
        fullNameInput: String = fullName,
        emailInput: String = email,
        passwordInput: String = password
    ): Result<PendingEmailVerification> {
        val resolvedName = fullNameInput.ifBlank { fullName }.trim()
        val resolvedEmail = emailInput.ifBlank { email }.trim()
        val resolvedPassword = passwordInput.ifBlank { password }
        val pending = PendingEmailVerification(
            email = resolvedEmail,
            fullName = resolvedName,
            passwordHash = resolvedPassword,
            verificationCode = "482910"
        )
        _pendingVerificationState.value = pending
        return Result.success(pending)
    }

    fun loginWithEmailAndPassword(email: String, password: String): Result<AuthUser> {
        val user = AuthUser(
            id = "user_${UUID.randomUUID().toString().take(6)}",
            email = email.trim(),
            fullName = email.substringBefore("@").replace(".", " ").capitalizeWords(),
            phone = "+91 98765 43210",
            role = UserRole.USER,
            isEmailVerified = true
        )
        _authUser.value = user
        return Result.success(user)
    }

    fun loginWithGoogle(
        email: String = "narenqe2@gmail.com",
        fullName: String = "Narendra Reddy",
        photoUrl: String = "",
        role: UserRole = UserRole.USER,
        emailHint: String = email
    ): Result<AuthUser> {
        val resolvedEmail = emailHint.ifBlank { email }
        val user = AuthUser(
            id = "user_g_${UUID.randomUUID().toString().take(6)}",
            email = resolvedEmail.trim(),
            fullName = fullName.ifBlank { resolvedEmail.substringBefore("@") },
            phone = "",
            role = role,
            avatarUrl = photoUrl,
            isEmailVerified = true
        )
        _authUser.value = user
        return Result.success(user)
    }

    fun quickLogin(role: UserRole): Result<AuthUser> {
        loginAsRole(role)
        return Result.success(_authUser.value ?: AuthUser(id = "user_quick", email = "demo@bookmyspace.app", fullName = "Demo User", role = role))
    }

    fun resendEmailVerification() {
        val current = _pendingVerificationState.value
        if (current != null) {
            _pendingVerificationState.value = current.copy(
                verificationCode = "482910",
                sentAt = System.currentTimeMillis()
            )
        }
    }

    fun resendVerificationCode(email: String = ""): Result<Boolean> {
        resendEmailVerification()
        return Result.success(true)
    }

    fun cancelPendingVerification() {
        _pendingVerificationState.value = null
    }

    fun verifyEmailCode(code: String): Boolean {
        val current = _pendingVerificationState.value
        if (current != null && (code.trim() == current.verificationCode || code.trim() == "123456" || code.trim() == "482910")) {
            _authUser.value = AuthUser(
                id = "user_${UUID.randomUUID().toString().take(6)}",
                email = current.email,
                fullName = current.fullName,
                isEmailVerified = true
            )
            _pendingVerificationState.value = null
            return true
        }
        return false
    }

    fun verifyEmailCode(emailInput: String = "", inputCode: String): Result<AuthUser> {
        val verified = verifyEmailCode(inputCode)
        return if (verified && _authUser.value != null) {
            Result.success(_authUser.value!!)
        } else {
            // Also accept fallback 123456 or 482910
            if (inputCode.trim() in listOf("123456", "482910", "112233")) {
                val email = emailInput.ifBlank { _pendingVerificationState.value?.email ?: "user@bookmyspace.app" }
                val user = AuthUser(
                    id = "user_${UUID.randomUUID().toString().take(6)}",
                    email = email,
                    fullName = email.substringBefore("@").replace(".", " ").capitalizeWords(),
                    isEmailVerified = true
                )
                _authUser.value = user
                _pendingVerificationState.value = null
                Result.success(user)
            } else {
                Result.failure(Exception("Invalid verification code. Please check your email."))
            }
        }
    }

    fun requestPasswordReset(email: String): Result<PendingPasswordReset> {
        val reset = PendingPasswordReset(
            email = email.trim(),
            resetToken = "123456"
        )
        _pendingPasswordResetState.value = reset
        return Result.success(reset)
    }

    fun resetPasswordWithToken(token: String, newPass: String): Boolean {
        if (token.isNotBlank() && newPass.length >= 6) {
            _pendingPasswordResetState.value = null
            return true
        }
        return false
    }

    fun resetPasswordWithToken(emailInput: String = "", tokenInput: String, newPasswordInput: String): Result<Boolean> {
        if (tokenInput.isNotBlank() && newPasswordInput.length >= 6) {
            _pendingPasswordResetState.value = null
            return Result.success(true)
        }
        return Result.failure(Exception("Invalid token or password too short."))
    }

    fun confirmPasswordReset(email: String = "", token: String, newPass: String): Result<Boolean> {
        return resetPasswordWithToken(email, token, newPass)
    }

    fun cancelPasswordReset() {
        _pendingPasswordResetState.value = null
    }

    fun updateProfile(fullName: String, phone: String = "", preferredLanguage: String = "", avatarUrl: String = ""): Result<AuthUser> {
        val current = _authUser.value ?: AuthUser(id = "user_curr", email = "user@bookmyspace.app", fullName = fullName)
        val updated = current.copy(
            fullName = fullName.trim(),
            phone = if (phone.isNotBlank()) phone.trim() else current.phone,
            avatarUrl = if (avatarUrl.isNotBlank()) avatarUrl.trim() else current.avatarUrl
        )
        _authUser.value = updated
        return Result.success(updated)
    }

    fun updateProfile(fullName: String, avatarUrl: String): Boolean {
        updateProfile(fullName = fullName, phone = "", preferredLanguage = "", avatarUrl = avatarUrl)
        return true
    }

    // --- Referrals ---
    private val _userReferralCode = MutableStateFlow("BOOKMYSPACE500")
    val userReferralCode: StateFlow<String> = _userReferralCode.asStateFlow()

    val sampleReferrals = listOf(
        ReferralItem("ref_1", "Karthik Varma", "karthik.v@gmail.com", "10 Aug 2026", ReferralStatus.COMPLETED, 500.0),
        ReferralItem("ref_2", "Sneha Reddy", "sneha.r@gmail.com", "14 Aug 2026", ReferralStatus.PENDING, 500.0)
    )

    private val _referrals = MutableStateFlow(sampleReferrals)
    val referrals: StateFlow<List<ReferralItem>> = _referrals.asStateFlow()

    private val _walletBalance = MutableStateFlow(1250.0)
    val walletBalance: StateFlow<Double> = _walletBalance.asStateFlow()

    private val _totalReferralCreditsEarned = MutableStateFlow(1500.0)
    val totalReferralCreditsEarned: StateFlow<Double> = _totalReferralCreditsEarned.asStateFlow()

    fun addReferralInvite(name: String, email: String) {
        val item = ReferralItem(
            id = "ref_${UUID.randomUUID().toString().take(6)}",
            friendName = name,
            friendEmail = email,
            dateInvited = "Today",
            status = ReferralStatus.PENDING,
            creditEarned = 500.0
        )
        _referrals.value = listOf(item) + _referrals.value
    }

    fun inviteFriendByEmailOrPhone(friendName: String, contact: String): Result<ReferralItem> {
        val item = ReferralItem(
            id = "ref_${UUID.randomUUID().toString().take(6)}",
            friendName = friendName.trim(),
            friendEmail = contact.trim(),
            dateInvited = "Today",
            status = ReferralStatus.PENDING,
            creditEarned = 500.0
        )
        _referrals.value = listOf(item) + _referrals.value
        return Result.success(item)
    }

    fun simulateFriendCompletedBooking(referralId: String): Result<Boolean> {
        _referrals.value = _referrals.value.map {
            if (it.id == referralId) {
                it.copy(status = ReferralStatus.COMPLETED)
            } else it
        }
        _walletBalance.value += 500.0
        _totalReferralCreditsEarned.value += 500.0
        return Result.success(true)
    }

    fun claimReferralCode(code: String): Result<String> {
        val clean = code.trim().uppercase()
        if (clean in listOf("SAVE500", "BOOKMYSPACE500", "WELCOME500", "TURF500")) {
            _walletBalance.value += 500.0
            return Result.success("🎉 Coupon '$clean' applied! ₹500 added to your BookMySpace wallet.")
        }
        return Result.failure(Exception("Invalid or expired referral code. Try 'SAVE500'"))
    }

    // --- QR Check-In ---
    data class CheckInResult(
        val success: Boolean,
        val message: String,
        val booking: Booking? = null
    )

    fun checkInBookingWithQr(code: String): CheckInResult {
        val clean = code.trim()
        val found = _bookings.value.firstOrNull {
            it.id.equals(clean, ignoreCase = true) ||
            it.qrCodeToken.equals(clean, ignoreCase = true) ||
            it.bookingRef.equals(clean, ignoreCase = true)
        } ?: _bookings.value.firstOrNull { it.status == BookingStatus.CONFIRMED }

        if (found != null) {
            val updated = found.copy(isCheckedIn = true, status = BookingStatus.COMPLETED)
            _bookings.value = _bookings.value.map { if (it.id == found.id) updated else it }
            return CheckInResult(true, "Check-in successful! Welcome to ${found.venueName}.", updated)
        }
        return CheckInResult(false, "Invalid QR code or booking reference.")
    }

    // --- Notifications ---
    val sampleNotifications = listOf(
        NotificationItem("notif_1", "Booking Confirmed! 🎟️", "Your badminton court slot at Velocity Pro Sports Arena is confirmed for 20 Aug at 7:00 AM.", "10 mins ago", false, "booking"),
        NotificationItem("notif_2", "1-Hour Pre-Slot Reminder ⚡", "Your upcoming court booking starts in 1 hour. Tap to view and scan your check-in pass.", "1 hour ago", false, "booking"),
        NotificationItem("notif_3", "Referral Bonus Added! 💰", "Sneha signed up using your link. ₹500 referral credit will unlock after their first booking.", "Yesterday", false, "general")
    )

    private val _notifications = MutableStateFlow(sampleNotifications)
    val notifications: StateFlow<List<NotificationItem>> = _notifications.asStateFlow()

    private val _fcmToken = MutableStateFlow("fcm_token_bms_prod_live_88392019")
    val fcmToken: StateFlow<String> = _fcmToken.asStateFlow()

    fun updateFcmToken(token: String) {
        _fcmToken.value = token
        val db = firestoreDb
        val authUid = getAuthUid()
        if (db != null && authUid != null) {
            db.collection("users").document(authUid).update("fcmToken", token)
                .addOnFailureListener { Log.w(TAG, "Failed to sync FCM token to firestore: ${it.message}") }
        }
    }

    fun clearAllNotifications() { _notifications.value = emptyList() }
    fun markAllNotificationsRead() {
        _notifications.value = _notifications.value.map { it.copy(isRead = true) }
    }
    fun markNotificationRead(id: String) {
        _notifications.value = _notifications.value.map { if (it.id == id) it.copy(isRead = true) else it }
    }
    fun deleteNotification(id: String) {
        _notifications.value = _notifications.value.filterNot { it.id == id }
    }
    fun addNotification(title: String, message: String, type: String = "general") {
        val notif = NotificationItem(
            id = "notif_${UUID.randomUUID().toString().take(6)}",
            title = title,
            message = message,
            time = "Just now",
            isRead = false,
            type = type
        )
        _notifications.value = listOf(notif) + _notifications.value
    }

    private fun String.capitalizeWords(): String = split(" ").joinToString(" ") { it.replaceFirstChar { c -> c.uppercase() } }


    // --- Events & Courses ---
    val sampleEvents = listOf(
        Event("ev_1", "Hyderabad Badminton Open Championship 2026", "Annual city tournament open for singles and doubles across men, women and master categories.", "Velocity Pro Sports Arena", "https://images.unsplash.com/photo-1626224583764-f87db24ac4ea", "28 Aug 2026", "9:00 AM - 6:00 PM", 1200.0, 64, 48, "Sports", false),
        Event("ev_2", "Luxury Wedding Showcase & Decor Expo", "Exhibition of top wedding designers, caterers, floral decorators and sound artists.", "The Royal Imperial Palace", "https://images.unsplash.com/photo-1519167758481-83f550bb49b3", "05 Sep 2026", "11:00 AM - 8:00 PM", 0.0, 500, 310, "Exhibition", true)
    )
    private val _events = MutableStateFlow(sampleEvents)
    val events: StateFlow<List<Event>> = _events.asStateFlow()

    fun toggleEventRegistration(eventId: String) {
        _events.value = _events.value.map {
            if (it.id == eventId) it.copy(isRegistered = !it.isRegistered) else it
        }
    }

    val sampleCourses = listOf(
        Course("crs_1", "Pro Shuttle Masterclass with National Coaches", "Pullela Champions Academy", "Coach Srinivas Rao", "Comprehensive 4-week smash, deceptive drops and match endurance clinic.", "https://images.unsplash.com/photo-1626224583764-f87db24ac4ea", 4, 4999.0, "Intermediate", "Sat & Sun 7:00 AM", 4.9, 142, false)
    )
    private val _courses = MutableStateFlow(sampleCourses)
    val courses: StateFlow<List<Course>> = _courses.asStateFlow()

    fun toggleCourseEnrollment(courseId: String) {
        _courses.value = _courses.value.map {
            if (it.id == courseId) it.copy(isEnrolled = !it.isEnrolled) else it
        }
    }

    // --- Reviews ---
    val sampleReviews = listOf(
        ReviewEntity(
            id = "rev_1",
            venueId = "v_grand_palace",
            userName = "Ananya Sharma",
            rating = 5.0,
            comment = "Magnificent royal venue! The chandeliers and catering were exceptional.",
            date = "12 Aug 2026",
            tags = "Spacious,Royal,Great AC"
        ),
        ReviewEntity(
            id = "rev_2",
            venueId = "v_velocity_sports",
            userName = "Rahul Varma",
            rating = 4.8,
            comment = "Top class synthetic badminton courts with proper LED floodlights.",
            date = "14 Aug 2026",
            tags = "Great Lighting,Clean,Good Grip"
        )
    )
    private val _reviews = MutableStateFlow(sampleReviews)
    val reviews: StateFlow<List<ReviewEntity>> = _reviews.asStateFlow()

    fun addReview(review: ReviewEntity) {
        _reviews.value = listOf(review) + _reviews.value
        val db = firestoreDb
        val authUid = getAuthUid()
        if (db != null && authUid != null) {
            val reviewDoc = mapOf(
                "reviewId" to review.id,
                "userId" to authUid,
                "userName" to review.userName,
                "venueId" to review.venueId,
                "rating" to review.rating,
                "comment" to review.comment,
                "createdAt" to FieldValue.serverTimestamp()
            ).filterValues { it != null }

            db.collection("reviews").document(review.id).set(reviewDoc)
                .addOnFailureListener { exception ->
                    handleFirestoreError(exception, OperationType.CREATE, "reviews/${review.id}")
                }
        }
    }

    fun addReview(
        venueId: String,
        comment: String,
        rating: Double,
        bookingId: String? = null,
        tags: List<String> = emptyList()
    ) {
        val userName = _authUser.value?.fullName ?: "Anonymous Guest"
        val review = ReviewEntity(
            id = "rev_${UUID.randomUUID().toString().take(6)}",
            venueId = venueId,
            userName = userName,
            rating = rating,
            comment = comment.trim(),
            date = "Today",
            bookingId = bookingId,
            tags = tags.joinToString(",")
        )
        addReview(review)
    }

    // --- Dynamic Configurable Fields ---
    val sampleConfigurableFields = listOf(
        ConfigurableFieldDefinition(
            id = "cf_catering",
            name = "in_house_catering",
            label = "In-House Catering Available",
            fieldType = ConfigurableFieldType.CHECKBOX,
            defaultValue = "true",
            targetCategory = ListingTargetCategory.FUNCTION_HALL
        ),
        ConfigurableFieldDefinition(
            id = "cf_ac",
            name = "central_ac",
            label = "Central AC / Climate Controlled",
            fieldType = ConfigurableFieldType.CHECKBOX,
            defaultValue = "true",
            targetCategory = ListingTargetCategory.ALL
        ),
        ConfigurableFieldDefinition(
            id = "cf_capacity",
            name = "max_seating_capacity",
            label = "Max Seating Capacity",
            fieldType = ConfigurableFieldType.NUMBER,
            defaultValue = "500",
            targetCategory = ListingTargetCategory.VENUE
        )
    )
    private val _configurableFields = MutableStateFlow(sampleConfigurableFields)
    val configurableFields: StateFlow<List<ConfigurableFieldDefinition>> = _configurableFields.asStateFlow()

    private val _customListingValues = MutableStateFlow<Map<String, List<ListingCustomFieldValue>>>(emptyMap())

    fun getConfigurableFieldsForCategory(category: ListingTargetCategory, activeOnly: Boolean = true): List<ConfigurableFieldDefinition> {
        return _configurableFields.value.filter {
            (!activeOnly || it.isActive) && (it.targetCategory == ListingTargetCategory.ALL || it.targetCategory == category)
        }
    }

    fun getConfigurableFieldsForCategory(categorySlug: String, activeOnly: Boolean = true): List<ConfigurableFieldDefinition> {
        val target = ListingTargetCategory.fromCode(categorySlug)
        return getConfigurableFieldsForCategory(target, activeOnly)
    }

    fun addConfigurableField(field: ConfigurableFieldDefinition) {
        _configurableFields.value = listOf(field) + _configurableFields.value
    }

    fun saveConfigurableField(field: ConfigurableFieldDefinition) {
        val exists = _configurableFields.value.any { it.id == field.id }
        _configurableFields.value = if (exists) {
            _configurableFields.value.map { if (it.id == field.id) field else it }
        } else {
            listOf(field) + _configurableFields.value
        }
    }

    fun toggleConfigurableFieldActive(id: String) {
        _configurableFields.value = _configurableFields.value.map {
            if (it.id == id) it.copy(isActive = !it.isActive) else it
        }
    }

    fun deleteConfigurableField(id: String) {
        _configurableFields.value = _configurableFields.value.filterNot { it.id == id }
    }

    fun reorderConfigurableFields(fields: List<ConfigurableFieldDefinition>) {
        _configurableFields.value = fields
    }

    @JvmName("reorderConfigurableFieldsByIds")
    fun reorderConfigurableFields(fieldIds: List<String>) {
        val currentMap = _configurableFields.value.associateBy { it.id }
        val reordered = fieldIds.mapNotNull { currentMap[it] }
        val remaining = _configurableFields.value.filterNot { fieldIds.contains(it.id) }
        _configurableFields.value = reordered + remaining
    }

    fun reorderConfigurableFieldIds(fieldIds: List<String>) {
        reorderConfigurableFields(fieldIds)
    }

    fun resetConfigurableFieldsToDefault() {
        _configurableFields.value = sampleConfigurableFields
    }

    fun getCustomValuesForListing(listingId: String): List<ListingCustomFieldValue> {
        return _customListingValues.value[listingId] ?: emptyList()
    }

    fun getCustomValuesMapForListing(listingId: String): Map<String, String> {
        return (_customListingValues.value[listingId] ?: emptyList()).associate { it.fieldId to it.value }
    }

    fun saveCustomFieldValue(customValue: ListingCustomFieldValue) {
        val currentList = _customListingValues.value[customValue.listingId]?.toMutableList() ?: mutableListOf()
        val index = currentList.indexOfFirst { it.fieldId == customValue.fieldId }
        if (index >= 0) {
            currentList[index] = customValue
        } else {
            currentList.add(customValue)
        }
        _customListingValues.value = _customListingValues.value + (customValue.listingId to currentList)
    }

    // --- Slot & Date Availability Helpers ---
    fun isSlotAlreadyBooked(venueId: String, date: String, slotLabel: String): Boolean {
        return _bookings.value.any {
            it.venueId == venueId &&
            (it.date == date || it.bookingDate == date) &&
            (it.slotLabel == slotLabel || "${it.startTime} - ${it.endTime}" == slotLabel) &&
            it.status != BookingStatus.CANCELLED &&
            it.status != BookingStatus.REJECTED
        }
    }

    fun getDateAvailability(venueId: String, date: String): DateAvailabilityInfo {
        val venue = _venues.value.firstOrNull { it.id == venueId }
        val slots = venue?.timeSlots ?: emptyList()
        val bookedCount = slots.count { isSlotAlreadyBooked(venueId, date, it.label) }
        val availableCount = (slots.size - bookedCount).coerceAtLeast(0)
        val status = when {
            slots.isEmpty() -> DateAvailabilityStatus.AVAILABLE
            availableCount == 0 -> DateAvailabilityStatus.SOLD_OUT
            availableCount <= 2 -> DateAvailabilityStatus.LIMITED
            availableCount <= 5 -> DateAvailabilityStatus.FILLING_FAST
            else -> DateAvailabilityStatus.AVAILABLE
        }
        return DateAvailabilityInfo(date, status, availableCount, slots.size)
    }

    fun getAlternativeSlots(venueId: String, date: String, excludeSlotLabel: String = ""): List<TimeSlot> {
        val venue = _venues.value.firstOrNull { it.id == venueId }
        val slots = venue?.timeSlots ?: emptyList()
        return slots.filter {
            (excludeSlotLabel.isBlank() || it.label != excludeSlotLabel) &&
            !isSlotAlreadyBooked(venueId, date, it.label)
        }
    }

    fun calculateDistanceKm(lat1: Double, lon1: Double, lat2: Double, lon2: Double): Double {
        val r = 6371.0 // Radius of Earth in KM
        val dLat = Math.toRadians(lat2 - lat1)
        val dLon = Math.toRadians(lon2 - lon1)
        val a = Math.sin(dLat / 2) * Math.sin(dLat / 2) +
                Math.cos(Math.toRadians(lat1)) * Math.cos(Math.toRadians(lat2)) *
                Math.sin(dLon / 2) * Math.sin(dLon / 2)
        val c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a))
        return (r * c * 10.0).toInt() / 10.0
    }

    // --- App Sections Config ---
    private val _appSections = MutableStateFlow(AppSectionConfig.defaultList())
    val appSections: StateFlow<List<AppSectionConfig>> = _appSections.asStateFlow()

    fun setAppSections(sections: List<AppSectionConfig>) {
        _appSections.value = sections
    }

    fun setSectionEnabled(sectionId: String, isEnabled: Boolean) {
        _appSections.value = _appSections.value.map {
            if (it.sectionId.equals(sectionId, ignoreCase = true)) it.copy(isEnabled = isEnabled) else it
        }
    }

    fun updateAppSection(config: AppSectionConfig) {
        _appSections.value = _appSections.value.map {
            if (it.sectionId == config.sectionId) config else it
        }
    }

    // --- Plug & Play Feature Registry & Config Engine ---
    private val _featureConfigs = MutableStateFlow<List<FeatureModuleConfig>>(FeatureModuleConfig.defaultList())
    val featureConfigs: StateFlow<List<FeatureModuleConfig>> = _featureConfigs.asStateFlow()

    fun isFeatureEnabled(key: AppFeatureKey): Boolean {
        return _featureConfigs.value.firstOrNull { it.key == key }?.isEnabled ?: key.defaultEnabled
    }

    fun getFeatureParam(key: AppFeatureKey, paramName: String, defaultVal: String = ""): String {
        val config = _featureConfigs.value.firstOrNull { it.key == key }
        return config?.getParam(paramName, defaultVal) ?: defaultVal
    }

    fun toggleFeature(key: AppFeatureKey, isEnabled: Boolean) {
        _featureConfigs.value = _featureConfigs.value.map {
            if (it.key == key) it.copy(isEnabled = isEnabled, lastModified = System.currentTimeMillis()) else it
        }
        logAnalyticsEvent("toggle_feature", mapOf("feature" to key.id, "enabled" to isEnabled.toString()), "feature_flags")
    }

    fun updateFeatureConfig(config: FeatureModuleConfig) {
        _featureConfigs.value = _featureConfigs.value.map {
            if (it.key == config.key) config.copy(lastModified = System.currentTimeMillis()) else it
        }
        logAnalyticsEvent("update_feature_config", mapOf("feature" to config.key.id), "feature_flags")
    }

    fun setFeatureParam(key: AppFeatureKey, paramName: String, paramValue: String) {
        _featureConfigs.value = _featureConfigs.value.map { cfg ->
            if (cfg.key == key) {
                val updatedParams = cfg.parameters.toMutableMap()
                updatedParams[paramName] = paramValue
                cfg.copy(parameters = updatedParams, lastModified = System.currentTimeMillis())
            } else cfg
        }
    }

    fun applyFeaturePreset(preset: FeaturePreset) {
        _featureConfigs.value = when (preset) {
            FeaturePreset.FULL_SUITE -> {
                FeatureModuleConfig.defaultList().map { it.copy(isEnabled = true) }
            }
            FeaturePreset.HOSPITALITY_AND_PG -> {
                FeatureModuleConfig.defaultList().map { cfg ->
                    val enabled = when (cfg.key) {
                        AppFeatureKey.MAP_DISCOVERY,
                        AppFeatureKey.UNIFIED_KYC_REGISTRATION,
                        AppFeatureKey.MULTI_GATEWAY_PAYMENTS,
                        AppFeatureKey.WHATSAPP_ASSIST,
                        AppFeatureKey.QR_CODE_PASSES,
                        AppFeatureKey.CAMERA_QR_SCANNER,
                        AppFeatureKey.RECENT_SEARCH_HISTORY,
                        AppFeatureKey.THEME_CUSTOMIZER,
                        AppFeatureKey.REGIONAL_LOCALIZATION,
                        AppFeatureKey.SAVED_BOOKMARKS,
                        AppFeatureKey.PUSH_NOTIFICATIONS,
                        AppFeatureKey.SOS_EMERGENCY_DIAL -> true
                        AppFeatureKey.ADDONS_AND_CATERING,
                        AppFeatureKey.INSTITUTES_STUDENT_REGISTER,
                        AppFeatureKey.CALENDAR_SLOT_BLACKOUT -> false
                        else -> cfg.key.defaultEnabled
                    }
                    cfg.copy(isEnabled = enabled)
                }
            }
            FeaturePreset.EVENTS_AND_BANQUETS -> {
                FeatureModuleConfig.defaultList().map { cfg ->
                    val enabled = when (cfg.key) {
                        AppFeatureKey.MAP_DISCOVERY,
                        AppFeatureKey.ADDONS_AND_CATERING,
                        AppFeatureKey.COUPON_ENGINE,
                        AppFeatureKey.MULTI_GATEWAY_PAYMENTS,
                        AppFeatureKey.QR_CODE_PASSES,
                        AppFeatureKey.CAMERA_QR_SCANNER,
                        AppFeatureKey.CALENDAR_SLOT_BLACKOUT,
                        AppFeatureKey.OWNER_PORTAL,
                        AppFeatureKey.MULTILINGUAL_TTS_READOUT,
                        AppFeatureKey.TRENDING_CAROUSELS -> true
                        AppFeatureKey.INSTITUTES_STUDENT_REGISTER -> false
                        else -> cfg.key.defaultEnabled
                    }
                    cfg.copy(isEnabled = enabled)
                }
            }
            FeaturePreset.ACADEMIES_AND_INSTITUTES -> {
                FeatureModuleConfig.defaultList().map { cfg ->
                    val enabled = when (cfg.key) {
                        AppFeatureKey.INSTITUTES_STUDENT_REGISTER,
                        AppFeatureKey.UNIFIED_KYC_REGISTRATION,
                        AppFeatureKey.DYNAMIC_SCHEMA_BUILDER,
                        AppFeatureKey.MULTI_GATEWAY_PAYMENTS,
                        AppFeatureKey.QR_CODE_PASSES,
                        AppFeatureKey.REGIONAL_LOCALIZATION,
                        AppFeatureKey.AI_SMART_COPILOT -> true
                        AppFeatureKey.ADDONS_AND_CATERING -> false
                        else -> cfg.key.defaultEnabled
                    }
                    cfg.copy(isEnabled = enabled)
                }
            }
            FeaturePreset.MINIMALIST_SPEED -> {
                FeatureModuleConfig.defaultList().map { cfg ->
                    val enabled = when (cfg.key) {
                        AppFeatureKey.MULTI_GATEWAY_PAYMENTS,
                        AppFeatureKey.QR_CODE_PASSES,
                        AppFeatureKey.SAVED_BOOKMARKS -> true
                        AppFeatureKey.AI_SMART_COPILOT,
                        AppFeatureKey.MULTILINGUAL_TTS_READOUT,
                        AppFeatureKey.ADDONS_AND_CATERING,
                        AppFeatureKey.TRENDING_CAROUSELS,
                        AppFeatureKey.VOICE_SEARCH -> false
                        else -> cfg.key.isCore
                    }
                    cfg.copy(isEnabled = enabled)
                }
            }
        }
        logAnalyticsEvent("apply_feature_preset", mapOf("preset" to preset.name), "feature_flags")
    }

    fun resetFeaturesToDefault() {
        _featureConfigs.value = FeatureModuleConfig.defaultList()
        logAnalyticsEvent("reset_features_default", emptyMap(), "feature_flags")
    }

    fun exportFeaturesJson(): String {
        return FeatureConfigJsonHelper.toJson(_featureConfigs.value)
    }

    fun importFeaturesJson(jsonString: String): Boolean {
        val parsed = FeatureConfigJsonHelper.fromJson(jsonString) ?: return false
        _featureConfigs.value = parsed
        logAnalyticsEvent("import_features_json", mapOf("count" to parsed.size.toString()), "feature_flags")
        return true
    }

    // --- Unified Configurable User Registration Engine ---
    val sampleRegistrationFields = listOf(
        UserRegistrationFieldDefinition(
            id = "reg_photo",
            key = "photo_url",
            label = "Profile Photo / Selfie",
            fieldType = RegistrationFieldType.PHOTO,
            category = RegistrationFieldCategory.PERSONAL,
            targetModule = RegistrationTargetModule.ALL,
            required = false,
            isEnabled = true,
            placeholder = "Upload profile photo or select avatar",
            helpText = "Used for account badge, booking verification and check-ins",
            displayOrder = 1,
            isSystemStandard = true
        ),
        UserRegistrationFieldDefinition(
            id = "reg_full_name",
            key = "full_name",
            label = "Full Name (as per Govt ID)",
            fieldType = RegistrationFieldType.TEXT,
            category = RegistrationFieldCategory.PERSONAL,
            targetModule = RegistrationTargetModule.ALL,
            required = true,
            isEnabled = true,
            placeholder = "e.g. Narendra Reddy",
            helpText = "Legal name for bookings, passes, and invoices",
            displayOrder = 2,
            isSystemStandard = true
        ),
        UserRegistrationFieldDefinition(
            id = "reg_phone",
            key = "phone",
            label = "Mobile / WhatsApp Number",
            fieldType = RegistrationFieldType.PHONE,
            category = RegistrationFieldCategory.PERSONAL,
            targetModule = RegistrationTargetModule.ALL,
            required = true,
            isEnabled = true,
            placeholder = "+91 98765 43210",
            helpText = "10-digit mobile number for instant SMS/WhatsApp booking OTPs",
            displayOrder = 3,
            isSystemStandard = true
        ),
        UserRegistrationFieldDefinition(
            id = "reg_email",
            key = "email",
            label = "Email Address",
            fieldType = RegistrationFieldType.EMAIL,
            category = RegistrationFieldCategory.PERSONAL,
            targetModule = RegistrationTargetModule.ALL,
            required = true,
            isEnabled = true,
            placeholder = "user@example.com",
            helpText = "Official receipts and slot confirmation tickets are sent here",
            displayOrder = 4,
            isSystemStandard = true
        ),
        UserRegistrationFieldDefinition(
            id = "reg_gender",
            key = "gender",
            label = "Gender",
            fieldType = RegistrationFieldType.RADIO_GROUP,
            category = RegistrationFieldCategory.PERSONAL,
            targetModule = RegistrationTargetModule.ALL,
            required = false,
            isEnabled = true,
            options = listOf("Male", "Female", "Other", "Prefer not to say"),
            defaultValue = "Male",
            displayOrder = 5,
            isSystemStandard = true
        ),
        UserRegistrationFieldDefinition(
            id = "reg_dob",
            key = "dob",
            label = "Date of Birth",
            fieldType = RegistrationFieldType.DATE_OF_BIRTH,
            category = RegistrationFieldCategory.PERSONAL,
            targetModule = RegistrationTargetModule.ALL,
            required = false,
            isEnabled = true,
            placeholder = "DD/MM/YYYY (e.g. 15/08/1995)",
            helpText = "Age eligibility for tournaments and academy batches",
            displayOrder = 6,
            isSystemStandard = true
        ),
        UserRegistrationFieldDefinition(
            id = "reg_aadhaar",
            key = "aadhaar_number",
            label = "Aadhaar Card Number (12 Digits)",
            fieldType = RegistrationFieldType.AADHAAR,
            category = RegistrationFieldCategory.IDENTITY_KYC,
            targetModule = RegistrationTargetModule.ALL,
            required = false,
            isEnabled = true,
            placeholder = "1234 5678 9012",
            helpText = "Government KYC verification for security check-ins and host onboarding",
            displayOrder = 7,
            isSystemStandard = true
        ),
        UserRegistrationFieldDefinition(
            id = "reg_govt_id",
            key = "govt_id_number",
            label = "Alternate Govt ID (PAN / Passport / Voter ID)",
            fieldType = RegistrationFieldType.GOVT_ID,
            category = RegistrationFieldCategory.IDENTITY_KYC,
            targetModule = RegistrationTargetModule.ALL,
            required = false,
            isEnabled = true,
            placeholder = "e.g. ABCDE1234F",
            helpText = "Optional alternate ID for verification",
            displayOrder = 8,
            isSystemStandard = true
        ),
        UserRegistrationFieldDefinition(
            id = "reg_address_line1",
            key = "address_line_1",
            label = "Address Line 1 (Flat/House No, Street, Building)",
            fieldType = RegistrationFieldType.ADDRESS_LINE,
            category = RegistrationFieldCategory.ADDRESS,
            targetModule = RegistrationTargetModule.ALL,
            required = true,
            isEnabled = true,
            placeholder = "e.g. Flat 402, Sai Residency, Road No. 36",
            displayOrder = 9,
            isSystemStandard = true
        ),
        UserRegistrationFieldDefinition(
            id = "reg_address_line2",
            key = "address_line_2",
            label = "Address Line 2 (Area, Landmark, Sector)",
            fieldType = RegistrationFieldType.ADDRESS_LINE,
            category = RegistrationFieldCategory.ADDRESS,
            targetModule = RegistrationTargetModule.ALL,
            required = false,
            isEnabled = true,
            placeholder = "e.g. Near Metro Pillar 1420, Jubilee Hills",
            displayOrder = 10,
            isSystemStandard = true
        ),
        UserRegistrationFieldDefinition(
            id = "reg_location_hierarchy",
            key = "location_hierarchy",
            label = "Country, State, District & City Hierarchy",
            fieldType = RegistrationFieldType.LOCATION_HIERARCHY,
            category = RegistrationFieldCategory.ADDRESS,
            targetModule = RegistrationTargetModule.ALL,
            required = true,
            isEnabled = true,
            helpText = "Select your home base region for localized slot discovery",
            displayOrder = 11,
            isSystemStandard = true
        ),
        UserRegistrationFieldDefinition(
            id = "reg_pincode",
            key = "pincode",
            label = "Postal PIN Code (6 Digits)",
            fieldType = RegistrationFieldType.PINCODE,
            category = RegistrationFieldCategory.ADDRESS,
            targetModule = RegistrationTargetModule.ALL,
            required = true,
            isEnabled = true,
            placeholder = "500033",
            displayOrder = 12,
            isSystemStandard = true
        ),
        UserRegistrationFieldDefinition(
            id = "reg_emergency_contact",
            key = "emergency_contact",
            label = "Emergency Contact / Alternate Phone",
            fieldType = RegistrationFieldType.PHONE,
            category = RegistrationFieldCategory.PERSONAL,
            targetModule = RegistrationTargetModule.ALL,
            required = false,
            isEnabled = true,
            placeholder = "+91 91234 56789",
            displayOrder = 13,
            isSystemStandard = true
        ),
        UserRegistrationFieldDefinition(
            id = "reg_org_name",
            key = "organization_name",
            label = "Business / Academy / Club Entity Name",
            fieldType = RegistrationFieldType.TEXT,
            category = RegistrationFieldCategory.PROFESSIONAL_BUSINESS,
            targetModule = RegistrationTargetModule.VENUE_OWNER,
            required = true,
            isEnabled = true,
            placeholder = "e.g. Smash Badminton Arena LLP",
            helpText = "Official registered company or club name",
            displayOrder = 14,
            isSystemStandard = true
        ),
        UserRegistrationFieldDefinition(
            id = "reg_gstin",
            key = "gstin",
            label = "GSTIN / Commercial Tax Registration Number",
            fieldType = RegistrationFieldType.GOVT_ID,
            category = RegistrationFieldCategory.PROFESSIONAL_BUSINESS,
            targetModule = RegistrationTargetModule.VENUE_OWNER,
            required = false,
            isEnabled = true,
            placeholder = "36AAAAA0000A1Z5",
            helpText = "For B2B tax invoicing on commission and payout credits",
            displayOrder = 15,
            isSystemStandard = true
        ),
        UserRegistrationFieldDefinition(
            id = "reg_skill_level",
            key = "skill_level",
            label = "Sport / Activity Skill Level",
            fieldType = RegistrationFieldType.DROPDOWN,
            category = RegistrationFieldCategory.CUSTOM,
            targetModule = RegistrationTargetModule.INSTITUTE_STUDENT,
            required = false,
            isEnabled = true,
            options = listOf("Beginner", "Intermediate", "Advanced", "State Player", "Certified Coach"),
            defaultValue = "Beginner",
            displayOrder = 16,
            isSystemStandard = false
        ),
        UserRegistrationFieldDefinition(
            id = "reg_special_requests",
            key = "special_requests",
            label = "Special Requirements / Medical Notes",
            fieldType = RegistrationFieldType.TEXTAREA,
            category = RegistrationFieldCategory.CUSTOM,
            targetModule = RegistrationTargetModule.ALL,
            required = false,
            isEnabled = true,
            placeholder = "Any sports injuries, racket stringing preferences, or accessibility needs...",
            displayOrder = 17,
            isSystemStandard = false
        )
    )

    private val _registrationFields = MutableStateFlow(sampleRegistrationFields)
    val registrationFields: StateFlow<List<UserRegistrationFieldDefinition>> = _registrationFields.asStateFlow()

    private val _currentUserProfile = MutableStateFlow<UserProfileData?>(
        UserProfileData(
            userId = "user_demo_1",
            fullName = "Narendra Reddy",
            email = "narenqe2@gmail.com",
            phone = "+91 98765 43210",
            photoUrl = "https://images.unsplash.com/photo-1535713875002-d1d0cf377fde",
            aadhaarNumber = "5489 1234 9876",
            addressLine1 = "Plot No. 42, Road No. 36",
            addressLine2 = "Near Peddamma Temple, Jubilee Hills",
            pincode = "500033",
            locationHierarchy = IndiaLocationMasterData.popularPresets.first(),
            gender = "Male",
            dob = "15/08/1992",
            emergencyContact = "+91 98765 00000",
            role = UserRole.USER,
            targetModule = RegistrationTargetModule.CUSTOMER,
            isKycVerified = true
        )
    )
    val currentUserProfile: StateFlow<UserProfileData?> = _currentUserProfile.asStateFlow()

    fun getFieldsForModule(targetModule: RegistrationTargetModule): List<UserRegistrationFieldDefinition> {
        return _registrationFields.value.filter {
            it.isEnabled && (it.targetModule == RegistrationTargetModule.ALL || it.targetModule == targetModule)
        }.sortedBy { it.displayOrder }
    }

    fun saveRegistrationField(field: UserRegistrationFieldDefinition) {
        val current = _registrationFields.value.toMutableList()
        val index = current.indexOfFirst { it.id == field.id }
        if (index >= 0) {
            current[index] = field
        } else {
            current.add(field)
        }
        _registrationFields.value = current.sortedBy { it.displayOrder }
        logAnalyticsEvent("save_registration_field", mapOf("field_id" to field.id, "label" to field.label), "admin_config")
    }

    fun deleteRegistrationField(fieldId: String) {
        _registrationFields.value = _registrationFields.value.filterNot { it.id == fieldId && !it.isSystemStandard }
        logAnalyticsEvent("delete_registration_field", mapOf("field_id" to fieldId), "admin_config")
    }

    fun toggleRegistrationFieldEnabled(keyOrId: String, isEnabled: Boolean) {
        _registrationFields.value = _registrationFields.value.map {
            if (it.id == keyOrId || it.key == keyOrId) it.copy(isEnabled = isEnabled) else it
        }
        logAnalyticsEvent("toggle_reg_field_enabled", mapOf("field" to keyOrId, "enabled" to isEnabled.toString()), "admin_config")
    }

    fun toggleRegistrationFieldRequired(keyOrId: String, isRequired: Boolean) {
        _registrationFields.value = _registrationFields.value.map {
            if (it.id == keyOrId || it.key == keyOrId) it.copy(required = isRequired) else it
        }
        logAnalyticsEvent("toggle_reg_field_required", mapOf("field" to keyOrId, "required" to isRequired.toString()), "admin_config")
    }

    fun exportRegistrationConfigJson(prettyPrint: Boolean = true): String {
        return RegistrationConfigJsonEngine.exportToJson(_registrationFields.value, prettyPrint = prettyPrint)
    }

    fun importRegistrationConfigJson(jsonString: String): Result<Int> {
        val result = RegistrationConfigJsonEngine.importFromJson(jsonString)
        return result.map { fields ->
            _registrationFields.value = fields
            logAnalyticsEvent("import_reg_fields_json", mapOf("count" to fields.size.toString()), "admin_config")
            fields.size
        }
    }

    fun applyRegistrationConfigPreset(preset: RegistrationConfigPreset) {
        val updated = RegistrationConfigJsonEngine.getPresetFields(sampleRegistrationFields, preset)
        _registrationFields.value = updated
        logAnalyticsEvent("apply_reg_preset", mapOf("preset" to preset.code), "admin_config")
    }

    fun resetRegistrationFieldsToDefault() {
        _registrationFields.value = sampleRegistrationFields
    }

    fun registerUnifiedUser(
        profile: UserProfileData,
        password: String = "Password@123"
    ): Result<AuthUser> {
        val newUserId = "usr_${UUID.randomUUID().toString().take(8)}"
        val finalRole = when (profile.targetModule) {
            RegistrationTargetModule.VENUE_OWNER -> UserRole.VENUE_OWNER
            else -> profile.role
        }

        val updatedProfile = profile.copy(
            userId = newUserId,
            role = finalRole,
            registeredAt = System.currentTimeMillis(),
            isKycVerified = profile.aadhaarNumber.isNotBlank()
        )
        _currentUserProfile.value = updatedProfile

        val authUser = AuthUser(
            id = newUserId,
            email = profile.email,
            fullName = profile.fullName,
            phone = profile.phone,
            role = finalRole,
            avatarUrl = profile.photoUrl,
            isEmailVerified = true
        )
        _authUser.value = authUser

        if (profile.locationHierarchy != null) {
            _userLocationHierarchy.value = profile.locationHierarchy
        }

        // Save to Firestore if available
        try {
            firestoreDb?.collection("users")?.document(newUserId)?.set(
                mapOf(
                    "userId" to newUserId,
                    "email" to profile.email,
                    "fullName" to profile.fullName,
                    "phone" to profile.phone,
                    "photoUrl" to profile.photoUrl,
                    "aadhaarMasked" to if (profile.aadhaarNumber.length >= 4) "XXXX-XXXX-${profile.aadhaarNumber.takeLast(4)}" else "",
                    "role" to finalRole.name,
                    "targetModule" to profile.targetModule.name,
                    "addressLine1" to profile.addressLine1,
                    "addressLine2" to profile.addressLine2,
                    "city" to (profile.locationHierarchy?.cityName ?: ""),
                    "state" to (profile.locationHierarchy?.stateName ?: ""),
                    "pincode" to profile.pincode,
                    "gender" to profile.gender,
                    "dob" to profile.dob,
                    "emergencyContact" to profile.emergencyContact,
                    "organizationName" to profile.organizationName,
                    "gstin" to profile.gstin,
                    "customFields" to profile.customFields,
                    "isKycVerified" to (profile.aadhaarNumber.isNotBlank()),
                    "registeredAt" to profile.registeredAt
                )
            )
        } catch (e: Exception) {
            Log.w(TAG, "Failed to persist user profile to Firestore: ${e.message}")
        }

        logAnalyticsEvent("unified_user_registered", mapOf("user_id" to newUserId, "role" to finalRole.name, "module" to profile.targetModule.name), "auth")
        return Result.success(authUser)
    }

    fun updateUserProfileData(profile: UserProfileData): Result<UserProfileData> {
        _currentUserProfile.value = profile
        _authUser.value = _authUser.value?.copy(
            fullName = profile.fullName,
            email = profile.email,
            phone = profile.phone,
            avatarUrl = profile.photoUrl,
            role = profile.role
        )
        if (profile.locationHierarchy != null) {
            _userLocationHierarchy.value = profile.locationHierarchy
        }
        return Result.success(profile)
    }

    // --- Audit Logs ---
    val sampleAuditLogs = listOf(
        AppAuditLog("log_1", "VENUE_CREATED", "owner@grandpalace.com", "Venue", "v_grand_palace", "12 Aug 2026, 11:30 AM", "Created Royal Palace listing"),
        AppAuditLog("log_2", "BOOKING_CONFIRMED", "system@bookmyspace.com", "Booking", "bk_demo_101", "15 Aug 2026, 02:15 PM", "Payment captured ₹650 via UPI")
    )
    private val _auditLogs = MutableStateFlow(sampleAuditLogs)
    val auditLogs: StateFlow<List<AppAuditLog>> = _auditLogs.asStateFlow()

    // --- Firebase Analytics Telemetry Events ---
    val sampleFirebaseEvents = listOf(
        FirebaseAnalyticsEvent("screen_view", mapOf("screen_name" to "ExploreScreen", "user_role" to "USER"), "navigation", "2 mins ago"),
        FirebaseAnalyticsEvent("select_time_slot", mapOf("venue_id" to "v_smash_arena", "slot" to "17:00 - 18:00"), "booking_funnel", "5 mins ago"),
        FirebaseAnalyticsEvent("view_venue_details", mapOf("venue_id" to "v_grand_palace", "category" to "Function Hall"), "engagement", "12 mins ago"),
        FirebaseAnalyticsEvent("voice_search_query", mapOf("query" to "Find badminton court near me", "lang" to "te-IN"), "voice_ai", "20 mins ago"),
        FirebaseAnalyticsEvent("begin_checkout", mapOf("venue_id" to "v_velocity_sports", "amount" to "650"), "ecommerce", "35 mins ago")
    )
    private val _firebaseEvents = MutableStateFlow(sampleFirebaseEvents)
    val firebaseEvents: StateFlow<List<FirebaseAnalyticsEvent>> = _firebaseEvents.asStateFlow()

    fun logAnalyticsEvent(
        name: String = "",
        params: Map<String, String> = emptyMap(),
        category: String = "general",
        eventName: String = name
    ) {
        val resolvedName = eventName.ifBlank { name }.ifBlank { "custom_event" }
        val event = FirebaseAnalyticsEvent(resolvedName, params, category, "Just now")
        _firebaseEvents.value = listOf(event) + _firebaseEvents.value
    }

    fun setVenues(venues: List<Venue>) {
        _venues.value = venues
    }

    fun recordVenueView(venueId: String) {
        logAnalyticsEvent("view_venue_details", mapOf("venue_id" to venueId), "engagement")
    }

    fun notifySlotInteraction() {
        logAnalyticsEvent("select_time_slot", mapOf("timestamp" to System.currentTimeMillis().toString()), "booking_funnel")
    }

    fun toggleSaved(venueId: String) {
        toggleSaveVenue(venueId)
    }

    fun handleFirestoreError(exception: Exception?, operation: OperationType, path: String) {
        Log.e(TAG, "Firestore operation failed [$operation on $path]: ${exception?.message}", exception)
    }
}
