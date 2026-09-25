package com.bookmyspace.bookmyspace.data.model

/**
 * Normalized Place Discovery Model
 * Unifies places discovered from BookMySpace DB, OpenStreetMap, Indian Postal Directory, and Geocoders.
 */
data class PlaceDiscoveryModel(
    val id: String,
    val name: String,
    val category: String,
    val categorySlug: String,
    val address: String,
    val state: String = "",
    val district: String = "",
    val mandal: String = "",
    val town: String = "",
    val pincode: String = "",
    val latitude: Double,
    val longitude: Double,
    val distanceMeters: Double = 0.0,
    val distanceKm: Double = 0.0,
    val phone: String = "",
    val website: String = "",
    val openingHours: String = "",
    val rating: Double = 0.0,
    val reviewCount: Int = 0,
    val photoUrl: String = "",
    val source: String = "BookMySpace", // "BookMySpace Verified", "OpenStreetMap", "India Postal Directory", "GeoPlaces Hub"
    val sourcePlaceId: String = "",
    val isRegisteredInBookMySpace: Boolean = false,
    val bookMySpaceVenueId: String? = null,
    val claimStatus: String = if (isRegisteredInBookMySpace) "REGISTERED" else "UNCLAIMED", // REGISTERED, UNCLAIMED, PENDING_VERIFICATION
    val pricingEstimate: String = "",
    val facilities: List<String> = emptyList(),
    val lastUpdated: Long = System.currentTimeMillis()
) {
    val formattedDistance: String
        get() = if (distanceKm < 1.0) {
            "${(distanceKm * 1000).toInt()} m away"
        } else {
            String.format("%.1f km away", distanceKm)
        }

    val displayAddress: String
        get() = address.ifBlank {
            listOf(town, mandal, district, state, pincode).filter { it.isNotBlank() }.joinToString(", ")
        }
}

/**
 * Pin Code Resolution Result representing Indian 6-digit postal code details
 */
data class PinCodeResolutionResult(
    val pincode: String,
    val state: String,
    val district: String,
    val localities: List<ResolvedLocality> = emptyList(),
    val primaryLocality: String = "",
    val latitude: Double = 0.0,
    val longitude: Double = 0.0,
    val isResolved: Boolean = true,
    val source: String = "India Postal Registry",
    val errorMessage: String? = null
)

/**
 * Detailed Locality / Post Office branch under a PIN code
 */
data class ResolvedLocality(
    val name: String,
    val branchType: String = "Sub Post Office",
    val deliveryStatus: String = "Delivery",
    val district: String = "",
    val state: String = "",
    val pincode: String = ""
)

/**
 * Categories supported by BookMySpace Discovery
 */
enum class DiscoveryCategory(val displayName: String, val slug: String, val iconEmoji: String) {
    ALL("All Places", "all", "📍"),
    FUNCTION_HALLS("Function Halls", "function_hall", "💒"),
    MARRIAGE_HALLS("Marriage / Wedding Halls", "marriage_hall", "💍"),
    BANQUET_HALLS("Banquet Halls", "banquet_hall", "🏛️"),
    CONVENTION_CENTERS("Convention Centers", "convention_center", "🏢"),
    HOTELS("Hotels & Lodges", "hotel", "🏨"),
    RESORTS("Resorts", "resort", "🌴"),
    PG_ACCOMMODATION("PG Accommodations", "pg", "🛏️"),
    HOSTELS("Hostels", "hostel", "🏠"),
    INSTITUTES("Institutes", "institute", "🎓"),
    COACHING_CENTERS("Coaching Centers", "coaching_center", "📚"),
    TRAINING_CENTERS("Training Centers", "training_center", "💻"),
    SPORTS_VENUES("Sports Venues", "sports_venue", "🏸"),
    OTHER_SPACES("Other Bookable Spaces", "other", "✨");

    companion object {
        fun fromSlug(slug: String): DiscoveryCategory {
            return entries.firstOrNull { it.slug.equals(slug, ignoreCase = true) } ?: ALL
        }
    }
}

/**
 * Sort options for discovered places
 */
enum class DiscoverySortBy(val label: String) {
    NEAREST("Nearest Distance"),
    HIGHEST_RATED("Highest Rated"),
    NAME_AZ("Name (A to Z)"),
    CATEGORY("Category")
}

/**
 * Configurable search radius around resolved point
 */
enum class DiscoveryRadius(val km: Double, val label: String) {
    RADIUS_5KM(5.0, "5 km"),
    RADIUS_10KM(10.0, "10 km (Default)"),
    RADIUS_25KM(25.0, "25 km"),
    RADIUS_50KM(50.0, "50 km"),
    RADIUS_100KM(100.0, "100 km")
}
