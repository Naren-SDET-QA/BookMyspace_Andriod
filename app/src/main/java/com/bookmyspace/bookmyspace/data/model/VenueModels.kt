package com.bookmyspace.bookmyspace.data.model

data class VenueCategory(
    val id: String,
    val slug: String,
    val name: String,
    val iconName: String = "sports",
    val isActive: Boolean = true,
    val isUnifiedRegistrationEnabled: Boolean = false,
    val customEmoji: String? = null,
    val parentSection: String? = null
) {
    val icon: String
        get() = customEmoji ?: when (slug.lowercase()) {
            "sports", "sports_turf", "sports-fitness" -> "🏸"
            "wedding_banquet", "function_hall", "banquet-halls", "venues", "marriage_hall", "kalyana_mandapam", "mini_hall", "banquet_hall", "convention_center", "community_hall", "govt_hall", "party_lawn", "other_hall" -> "🏛️"
            "pg_hostel", "pg-co-living", "pg", "gents_pg", "ladies_pg", "student_hostel", "co_living", "single_room", "other_pg" -> "🏠"
            "hotel_stay", "hotels-resorts", "hotels", "resort", "lodge", "guest_house", "hourly_room", "other_stay" -> "🏨"
            "classes_academy", "coaching-institutes", "academies", "coaching", "computer_it", "dance_academy", "music_class", "sports_academy", "other_class" -> "🎓"
            "events_workshops", "events" -> "🎟️"
            else -> "✨"
        }
}

data class VenueImage(
    val id: String,
    val url: String,
    val altText: String = "",
    val isCover: Boolean = false,
    val tag: String = "General" // "Cover", "Main Hall", "Dining", "Rooms", "Lawn", "Exterior", "Stage"
)

data class VenueVideo(
    val id: String = "",
    val title: String = "Short Walkthrough",
    val videoUrl: String = "",
    val thumbnailUrl: String = "",
    val durationSeconds: Int = 30
)

data class Venue3dWalkthrough(
    val id: String = "",
    val title: String = "360° Virtual Tour",
    val tourUrl: String = "",
    val previewImageUrl: String = "",
    val tourType: String = "360_PANORAMA", // "360_PANORAMA", "3D_MATTERPORT", "VIRTUAL_WALKTHROUGH"
    val hotspots: List<String> = listOf("Grand Stage", "Dining Arena", "VIP Suite", "Lawn Grounds", "Entrance")
)

data class VenueFacility(
    val facility: String,
    val isAvailable: Boolean = true
)

data class VenueOperatingHours(
    val dayOfWeek: Int, // 0 = Mon, 6 = Sun
    val opensAt: String,
    val closesAt: String,
    val isClosed: Boolean = false
)

data class VenuePackage(
    val id: String,
    val name: String,
    val priceAmount: Double,
    val description: String,
    val itemsIncluded: List<String> = emptyList(),
    val vegPlatePrice: Double = 0.0,
    val nonVegPlatePrice: Double = 0.0
)

data class VenueAddon(
    val id: String,
    val name: String,
    val priceAmount: Double,
    val description: String = ""
)

data class PgSharingOption(
    val id: String,
    val typeName: String,
    val monthlyRent: Double,
    val depositAmount: Double,
    val isAvailable: Boolean = true,
    val roomFeatures: List<String> = emptyList()
)

data class PgDetails(
    val pgType: String = "Co-living",
    val sharingOptions: List<PgSharingOption> = emptyList(),
    val gateLockTime: String = "10:30 PM",
    val noticePeriodDays: Int = 30,
    val securityDepositMonths: Double = 1.0,
    val mealPlan: String = "3 Meals Daily Included (Veg & Non-Veg)",
    val preferredOccupants: String = "Students & Working Professionals",
    val electricityCharges: String = "Sub-metered at ₹8/unit",
    val maintenanceFee: Double = 0.0
)

data class HotelDetails(
    val starRating: Int = 4, // 3, 4, 5
    val propertyType: String = "4-Star Luxury Boutique Hotel",
    val roomTypes: List<String> = listOf("Deluxe King Room", "Executive Business Suite", "Flexi Day Stay"),
    val checkInTime: String = "12:00 PM",
    val checkOutTime: String = "11:00 AM",
    val allowsFlexiStay: Boolean = true
)

data class TimeSlot(
    val id: String = "",
    val venueId: String = "",
    val label: String = "",
    val startTime: String = "",
    val endTime: String = "",
    val priceAmount: Double = 0.0,
    val isAvailable: Boolean = true
) {
    constructor(
        id: String,
        label: String,
        startTime: String,
        endTime: String,
        priceAmount: Double,
        isAvailable: Boolean = true
    ) : this(
        id = id,
        venueId = "",
        label = label,
        startTime = startTime,
        endTime = endTime,
        priceAmount = priceAmount,
        isAvailable = isAvailable
    )
}

data class ContactSettings(
    val showCall: Boolean = false,
    val showWhatsapp: Boolean = false,
    val showChat: Boolean = false,
    val showOwnerContact: Boolean = false,
    val contactBookMySpace: Boolean = true,
    val allowPostBookingDirectContact: Boolean = false
)

data class Venue(
    val id: String,
    val name: String,
    val slug: String = "",
    val description: String = "",
    val addressLine1: String = "",
    val city: String = "Hyderabad",
    val state: String = "Telangana",
    val latitude: Double = 17.3850,
    val longitude: Double = 78.4866,
    val capacity: Int = 500,
    val minGuests: Int = 100,
    val maxGuests: Int = 1200,
    val distanceKm: Double = 2.4,
    val pricingBaseAmount: Double = 75000.0,
    val taxRate: Double = 18.0,
    val parkingCapacity: Int = 150,
    val foodOptions: String = "In-house & External Catering",
    val rules: String = "No firecrackers after 10 PM. Outside caterers permitted with NOC. Alcohol permitted with temporary license.",
    val isVerified: Boolean = true,
    val isActive: Boolean = true,
    val avgRating: Double = 4.8,
    val ratingCount: Int = 324,
    val category: VenueCategory? = null,
    val images: List<VenueImage> = emptyList(),
    val facilities: List<VenueFacility> = emptyList(),
    val packages: List<VenuePackage> = emptyList(),
    val addons: List<VenueAddon> = emptyList(),
    val pgDetails: PgDetails? = null,
    val hotelDetails: HotelDetails? = null,
    val operatingHours: List<VenueOperatingHours> = emptyList(),
    val timeSlots: List<TimeSlot> = emptyList(),
    val contactPhone: String = "98765-43210",
    val contactWhatsapp: String = "919876543210",
    val contactSettings: ContactSettings = ContactSettings(),
    val isSaved: Boolean = false,
    val locationHierarchy: LocationHierarchy? = null,
    val featuredImageUrl: String = "",
    val videos: List<VenueVideo> = emptyList(),
    val virtual3dTour: Venue3dWalkthrough? = null,
    val ownerId: String = "user_venue_owner"
) {
    val imageUrls: List<String>
        get() = images.map { it.url }.ifEmpty { listOf(coverImageUrl) }

    val coverImageUrl: String
        get() = featuredImageUrl.ifBlank {
            images.firstOrNull { it.isCover }?.url
                ?: images.firstOrNull()?.url
                ?: "https://images.unsplash.com/photo-1519167758481-83f550bb49b3"
        }

    val fullAddress: String
        get() = locationHierarchy?.fullAddressText
            ?: listOf(addressLine1, city, state).filter { it.isNotBlank() }.joinToString(", ")
}

enum class VenueSortBy {
    RELEVANCE,
    PRICE_LOW_HIGH,
    PRICE_HIGH_LOW,
    RATING,
    DISTANCE
}

data class VenueSearchQuery(
    val query: String = "",
    val categorySlug: String? = null,
    val city: String? = null,
    val minPrice: Double? = null,
    val maxPrice: Double? = null,
    val radiusKm: Double? = null,
    val minGuests: Int? = null,
    val eventType: String? = null,
    val propertyType: String? = null, // "VENUE", "PG", "HOTEL"
    val pgType: String? = null,
    val roomSharingType: String? = null,
    val minStarRating: Int? = null,
    val hotelRoomType: String? = null,
    val sortBy: VenueSortBy = VenueSortBy.RELEVANCE
)

data class FavoriteVenueItem(
    val id: String = "",
    val userId: String = "",
    val venueId: String = "",
    val venueName: String = "",
    val category: String = "",
    val city: String = "",
    val rating: Double = 4.8,
    val coverImageUrl: String = "",
    val pricingBaseAmount: Double = 500.0,
    val addedAt: Long = System.currentTimeMillis(),
    val notes: String = ""
)
