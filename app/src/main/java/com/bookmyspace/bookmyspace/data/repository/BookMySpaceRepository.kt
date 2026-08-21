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
import com.bookmyspace.bookmyspace.data.payment.RazorpayRefundService
import com.bookmyspace.bookmyspace.data.payment.RefundResult
import com.bookmyspace.bookmyspace.data.repository.PaymentTransactionRepository
import com.google.firebase.firestore.ListenerRegistration
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import java.util.UUID

object BookMySpaceRepository {
    private const val TAG = "BookMySpaceRepository"
    private var appContext: Context? = null
    private var firestoreDb: FirebaseFirestore? = null
    private var bookingsListener: ListenerRegistration? = null
    private var savedListener: ListenerRegistration? = null
    private var reviewsListener: ListenerRegistration? = null
    private var paymentTxRepository: PaymentTransactionRepository? = null

    private val _paymentTransactions = MutableStateFlow<List<PaymentTransactionEntity>>(emptyList())
    val paymentTransactions: StateFlow<List<PaymentTransactionEntity>> = _paymentTransactions.asStateFlow()

    private val _favoriteItems = MutableStateFlow<List<FavoriteVenueItem>>(emptyList())
    val favoriteItems: StateFlow<List<FavoriteVenueItem>> = _favoriteItems.asStateFlow()

    private val _favoriteVenueIds = MutableStateFlow<Set<String>>(setOf("v_grand_palace", "v_smash_arena"))
    val favoriteVenueIds: StateFlow<Set<String>> = _favoriteVenueIds.asStateFlow()

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
        } catch (e: Exception) {
            Log.e(TAG, "Failed to initialize Firestore: ${e.message}", e)
        }
    }

    private fun listenToLiveFirestoreData() {
        val db = firestoreDb ?: return
        val currentUserId = FirebaseAuth.getInstance().currentUser?.uid ?: _authUser.value?.id

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
    }

    // --- Themes ---
    private val _themeMode = MutableStateFlow(ThemeMode.SYSTEM_DEFAULT)
    val themeMode: StateFlow<ThemeMode> = _themeMode.asStateFlow()

    private val _selectedThemePreset = MutableStateFlow(ThemePreset.ELECTRIC_TEAL)
    val selectedThemePreset: StateFlow<ThemePreset> = _selectedThemePreset.asStateFlow()

    private val _customPrimaryColorHex = MutableStateFlow("#00C9A7")
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
        VenueCategory("cat_banquet", "banquet_hall", "Banquet Halls", "restaurant"),
        VenueCategory("cat_sports", "sports", "Sports Arenas", "sports_tennis"),
        VenueCategory("cat_hotel", "hotel_stay", "Hotels & Stays", "hotel"),
        VenueCategory("cat_pg", "pg_hostel", "PG & Hostels", "house"),
        VenueCategory("cat_convention", "convention_center", "Convention Centers", "corporate_fare"),
        VenueCategory("cat_lawn", "party_lawn", "Party Lawns", "deck")
    )

    private val _categories = MutableStateFlow(sampleCategories)
    val categories: StateFlow<List<VenueCategory>> = _categories.asStateFlow()

    fun toggleCategoryActive(categoryId: String) {
        _categories.value = _categories.value.map {
            if (it.id == categoryId) it.copy(isActive = !it.isActive) else it
        }
    }

    // --- Venues with High-Quality Multi-Photo Galleries ---
    val sampleVenues = listOf(
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
            category = sampleCategories[1],
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
            addons = listOf(
                VenueAddon("add_drone", "Aerial Drone Photography Access & Rigging", 15000.0),
                VenueAddon("add_pyro", "Cold Pyro & Low Fog Entry Machine", 12000.0),
                VenueAddon("add_valet", "Dedicated VIP Valet Chauffeur Fleet", 18000.0)
            ),
            locationHierarchy = IndiaLocationMasterData.popularPresets[0]
        ),
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
            category = sampleCategories[3],
            isSaved = false,
            images = listOf(
                VenueImage("img_sp_1", "https://images.unsplash.com/photo-1626224583764-f87db24ac4ea", "Yonex BWF Synthetic Badminton Courts", isCover = true),
                VenueImage("img_sp_2", "https://images.unsplash.com/photo-1574629810360-7efbbe195018", "FIFA Approved All-Weather Football & Cricket Turf"),
                VenueImage("img_sp_3", "https://images.unsplash.com/photo-1534438327276-14e5300c3a48", "High-Intensity Fitness & Warm-up Conditioning Zone"),
                VenueImage("img_sp_4", "https://images.unsplash.com/photo-1540497077202-7c8a3999166f", "Player Locker Rooms, Steam Shower & Cafe Lounge"),
                VenueImage("img_sp_5", "https://images.unsplash.com/photo-1517649763962-0c623266ddc0", "Spectator Gallery & Night Tournament Lighting")
            ),
            facilities = listOf(
                VenueFacility("8 BWF Standard Synthetic Courts", true),
                VenueFacility("Anti-glare 600 Lux Tournament LEDs", true),
                VenueFacility("Air-conditioned Player Waiting Lounge", true),
                VenueFacility("Clean Shower & Locker Facilities", true),
                VenueFacility("Equipment Pro-Shop & Racket Stringing", true),
                VenueFacility("Live Match Video Recording", true)
            ),
            timeSlots = listOf(
                TimeSlot("slot_1", "v_smash_arena", "6:00 AM - 7:00 AM (Early Bird)", "06:00", "07:00", 500.0, true),
                TimeSlot("slot_2", "v_smash_arena", "7:00 AM - 8:00 AM", "07:00", "08:00", 650.0, true),
                TimeSlot("slot_3", "v_smash_arena", "6:00 PM - 7:00 PM (Prime Time)", "18:00", "19:00", 850.0, true),
                TimeSlot("slot_4", "v_smash_arena", "7:00 PM - 8:00 PM (Prime Time)", "19:00", "20:00", 850.0, true),
                TimeSlot("slot_5", "v_smash_arena", "8:00 PM - 9:00 PM (Night Owl)", "20:00", "21:00", 750.0, true)
            ),
            locationHierarchy = IndiaLocationMasterData.popularPresets[0]
        ),
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
            category = sampleCategories[4],
            isSaved = true,
            images = listOf(
                VenueImage("img_ht_1", "https://images.unsplash.com/photo-1566073771259-6a8506099945", "Modern Skyline Suite with Panoramic City Views", isCover = true),
                VenueImage("img_ht_2", "https://images.unsplash.com/photo-1582719478250-c89cae4dc85b", "King Deluxe Master Bedroom & Plush Bedding"),
                VenueImage("img_ht_3", "https://images.unsplash.com/photo-1571896349842-33c89424de2d", "Rooftop Glass Infinity Swimming Pool & Cabanas"),
                VenueImage("img_ht_4", "https://images.unsplash.com/photo-1590490360182-c33d57733427", "Executive Boardroom & Business Workstation"),
                VenueImage("img_ht_5", "https://images.unsplash.com/photo-1520250497591-112f2f40a3f4", "Fine Dining Restaurant & Cocktail Lounge Bar")
            ),
            facilities = listOf(
                VenueFacility("High-Speed 500 Mbps Wi-Fi", true),
                VenueFacility("Rooftop Infinity Swimming Pool", true),
                VenueFacility("24/7 Concierge & In-Room Dining", true),
                VenueFacility("Smart Ergonomic Workstation", true),
                VenueFacility("Fitness Gym & Sauna", true)
            ),
            hotelDetails = HotelDetails(
                starRating = 5,
                propertyType = "5-Star Luxury Business Hotel",
                roomTypes = listOf("Deluxe King Room (₹3,499/night)", "Executive Suite (₹5,999/night)", "Flexi 6-Hour Day Pass (₹1,899)")
            ),
            locationHierarchy = IndiaLocationMasterData.popularPresets[1]
        ),
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
            category = sampleCategories[5],
            isSaved = false,
            images = listOf(
                VenueImage("img_pg_1", "https://images.unsplash.com/photo-1522771739844-6a9f6d5f14af", "Spacious Executive Room with Study Table & Balcony", isCover = true),
                VenueImage("img_pg_2", "https://images.unsplash.com/photo-1502672260266-1c1ef2d93688", "Modern Common Living Room & OTT Entertainment Lounge"),
                VenueImage("img_pg_3", "https://images.unsplash.com/photo-1556911220-e15b29be8c8f", "Hygienic Modern Modular Dining Hall & Kitchen"),
                VenueImage("img_pg_4", "https://images.unsplash.com/photo-1584622650111-993a426fbf0a", "Attached Sparkling Clean Bathroom & Geyser"),
                VenueImage("img_pg_5", "https://images.unsplash.com/photo-1513694203232-719a280e022f", "Co-Working Desk Pods & High-Speed Wi-Fi Area")
            ),
            facilities = listOf(
                VenueFacility("3 Meals Daily Included (Veg & Non-Veg)", true),
                VenueFacility("High Speed Wi-Fi on Every Floor", true),
                VenueFacility("Daily Housekeeping & Room Cleaning", true),
                VenueFacility("Automatic Washing Machines & Ironing", true),
                VenueFacility("24/7 CCTV & Biometric Entry", true),
                VenueFacility("Power Backup & RO Mineral Drinking Water", true)
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
            category = sampleCategories[7],
            isSaved = false,
            images = listOf(
                VenueImage("img_eg_1", "https://images.unsplash.com/photo-1530103862676-de8c9debad1d", "Lush Party Lawn Decorated with Fairy Lighting", isCover = true),
                VenueImage("img_eg_2", "https://images.unsplash.com/photo-1519741497674-611481863552", "Open Air Stage Architecture & Floral Walkway"),
                VenueImage("img_eg_3", "https://images.unsplash.com/photo-1470225620780-dba8ba36b745", "Evening DJ Deck & Ambient Laser Illumination"),
                VenueImage("img_eg_4", "https://images.unsplash.com/photo-1541123437800-1bb1317badc2", "Poolside Cocktail Tables & Lounge Cabanas"),
                VenueImage("img_eg_5", "https://images.unsplash.com/photo-1505236858219-8359eb29e329", "Buffet Counters & Live Barbecue Gazebo")
            ),
            facilities = listOf(
                VenueFacility("3-Acre Natural Bermuda Grass Turf", true),
                VenueFacility("Illuminated Canopy & Fairy Light Grid", true),
                VenueFacility("Swimming Pool Deck for Pre-Event Parties", true),
                VenueFacility("Parking for 300+ Vehicles with Guards", true),
                VenueFacility("Green Rooms & Cottages for Family Stay", true)
            ),
            locationHierarchy = IndiaLocationMasterData.popularPresets[3]
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
        val currentUserId = FirebaseAuth.getInstance().currentUser?.uid ?: _authUser.value?.id ?: "user_demo_1"
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
            venueId = "v_smash_arena",
            date = "2026-08-20",
            startTime = "07:00",
            endTime = "08:00",
            totalPrice = 650.0,
            status = BookingStatus.CONFIRMED,
            qrCodeToken = "BMS-PASS-VSA-20260820-0700",
            paymentStatus = "PAID",
            paymentMethod = "UPI (Google Pay)"
        ),
        Booking(
            id = "bk_demo_102",
            userId = "user_demo_1",
            venueId = "v_grand_palace",
            date = "2026-09-15",
            startTime = "10:00",
            endTime = "23:00",
            totalPrice = 220000.0,
            status = BookingStatus.PENDING,
            qrCodeToken = "BMS-PASS-RGP-20260915-1000",
            paymentStatus = "PENDING",
            paymentMethod = "Bank Transfer"
        )
    )

    private val _bookings = MutableStateFlow(sampleBookings)
    val bookings: StateFlow<List<Booking>> = _bookings.asStateFlow()

    fun addBooking(booking: Booking) {
        _bookings.value = listOf(booking) + _bookings.value
        val db = firestoreDb
        val authUid = FirebaseAuth.getInstance().currentUser?.uid ?: _authUser.value?.id
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

    fun updateBookingPayment(bookingId: String, paymentId: String, method: String) {
        _bookings.value = _bookings.value.map { b ->
            if (b.id == bookingId) {
                b.copy(
                    paymentStatus = "PAID",
                    paymentId = paymentId,
                    paymentMethod = method,
                    status = BookingStatus.CONFIRMED
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
        webhookEvent: String? = null
    ) {
        updateBookingPayment(bookingId, paymentId, paymentMethod)
        val booking = _bookings.value.find { it.id == bookingId }
        val venueName = booking?.venueName?.ifBlank { _venues.value.find { it.id == booking.venueId }?.name ?: "Venue Space" } ?: "Venue Space"
        val amount = booking?.totalPrice ?: (booking?.totalAmount ?: 500.0)
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
            notes = if (isVerified) "Cryptographically Verified Payment for Booking #$bookingId" else "Payment for Booking #$bookingId"
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
            address = "Gachibowli Stadium Complex",
            city = "Hyderabad",
            state = "Telangana",
            rating = 4.9,
            ratingCount = 210,
            isVerified = true,
            isPublished = true,
            coverImageUrl = "https://images.unsplash.com/photo-1626224583764-f87db24ac4ea",
            facultyMembers = listOf(
                FacultyMember("fac_1", "Coach Srinivas Rao", "Chief Coach (BWF Level 3)", "BWF Level 3 Certified", 14, "https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d", "Former National player and chief selector", listOf("Badminton", "Endurance")),
                FacultyMember("fac_2", "Priya Sharma", "Senior Strength Coach", "CSCS Certified", 8, "https://images.unsplash.com/photo-1534528741775-53994a69daeb", "CSCS Certified athletic performance trainer", listOf("Agility", "Recovery"))
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
            subjectOrSpecialization = "Junior Badminton",
            ageGroup = "8 - 16 Years",
            skillLevel = "Intermediate to Advanced",
            monthlyFee = 3500.0,
            courseFee = 9000.0,
            feeAmount = 3500.0,
            feeBillingCycle = "month",
            seatsTotal = 15,
            seatsAvailable = 4,
            availableSeats = 4,
            totalSeats = 15,
            instructorName = "Coach Srinivas Rao",
            facultyName = "Coach Srinivas Rao",
            coverImageUrl = "https://images.unsplash.com/photo-1626224583764-f87db24ac4ea",
            rating = 4.9,
            ratingCount = 88,
            durationText = "3 Months",
            deliveryMode = ClassDeliveryMode.OFFLINE,
            isPublished = true
        )
    )

    private val _instituteClasses = MutableStateFlow(sampleClasses)
    val instituteClasses: StateFlow<List<InstituteClass>> = _instituteClasses.asStateFlow()

    fun addInstitute(profile: InstituteProfile) {
        _institutes.value = listOf(profile) + _institutes.value
    }

    fun addClass(cls: InstituteClass) {
        _instituteClasses.value = listOf(cls) + _instituteClasses.value
    }

    fun getPublishedInstitutes(): List<InstituteProfile> {
        return _institutes.value.filter { it.isPublished }
    }

    fun getClassesForInstitute(instituteId: String): List<InstituteClass> {
        return _instituteClasses.value.filter { it.instituteId == instituteId }
    }

    fun searchClasses(query: String = "", category: String? = null, deliveryMode: ClassDeliveryMode? = null): List<InstituteClass> {
        val q = query.trim().lowercase()
        return _instituteClasses.value.filter { cls ->
            val matchQ = q.isBlank() || cls.title.lowercase().contains(q) || cls.instituteName.lowercase().contains(q) || cls.subjectOrSpecialization.lowercase().contains(q)
            val matchCat = category.isNullOrBlank() || cls.category.equals(category, ignoreCase = true)
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
        val authUid = FirebaseAuth.getInstance().currentUser?.uid ?: _authUser.value?.id
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
            it.status != BookingStatus.CANCELLED
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

    fun updateAppSection(config: AppSectionConfig) {
        _appSections.value = _appSections.value.map {
            if (it.sectionId == config.sectionId) config else it
        }
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

    fun toggleRegistrationFieldEnabled(fieldId: String, isEnabled: Boolean) {
        _registrationFields.value = _registrationFields.value.map {
            if (it.id == fieldId) it.copy(isEnabled = isEnabled) else it
        }
    }

    fun toggleRegistrationFieldRequired(fieldId: String, isRequired: Boolean) {
        _registrationFields.value = _registrationFields.value.map {
            if (it.id == fieldId) it.copy(required = isRequired) else it
        }
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

    fun isSectionEnabled(slug: String): Boolean {
        return _appSections.value.firstOrNull { it.sectionId.equals(slug, ignoreCase = true) || it.title.contains(slug, ignoreCase = true) }?.isEnabled ?: true
    }

    fun isCategoryEnabled(slug: String): Boolean {
        return _categories.value.firstOrNull { it.slug.equals(slug, ignoreCase = true) }?.isActive ?: true
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
