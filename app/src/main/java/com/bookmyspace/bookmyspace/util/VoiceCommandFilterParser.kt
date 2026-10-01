package com.bookmyspace.bookmyspace.util

import com.bookmyspace.bookmyspace.data.model.VenueSortBy
import java.util.Locale
import java.util.regex.Pattern

/**
 * Visual badge representation of a parsed voice filter attribute.
 */
data class VoiceFilterBadge(
    val iconEmoji: String,
    val title: String,
    val value: String
)

/**
 * Structured filter payload extracted from natural speech voice commands.
 */
data class VoiceFilterResult(
    val rawSpokenText: String,
    val cleanedSearchQuery: String = "",
    val propertyType: String? = null, // "ALL", "VENUE", "PG", "HOTEL"
    val categorySlug: String? = null, // "function_hall", "banquet_hall", "pg_hostel", "hotel_stay", "meeting_room", "cricket", "football", "indoor"
    val pgType: String? = null, // "GENTS", "LADIES", "COLIVING"
    val sharingType: String? = null, // "1_SHARING", "2_SHARING", "3_SHARING"
    val minPrice: Float? = null,
    val maxPrice: Float? = null,
    val minRating: Float? = null,
    val minCapacity: Int? = null,
    val maxCapacity: Int? = null,
    val amenities: Set<String> = emptySet(),
    val sortBy: VenueSortBy? = null,
    val locationKeyword: String? = null,
    val isClearCommand: Boolean = false,
    val spokenFeedbackMessage: String = "",
    val badges: List<VoiceFilterBadge> = emptyList()
)

/**
 * Comprehensive Natural Language Processing (NLP) Parser for BookMySpace Voice Commands.
 * Translates conversational spoken voice requests into concrete database search & filter parameters.
 */
object VoiceCommandFilterParser {

    fun parseVoiceCommand(spokenText: String): VoiceFilterResult {
        val raw = spokenText.trim()
        val lower = raw.lowercase(Locale.ROOT)

        // 1. Check for Reset / Clear Filters intent
        if (isResetQuery(lower)) {
            return VoiceFilterResult(
                rawSpokenText = raw,
                cleanedSearchQuery = "",
                propertyType = "ALL",
                categorySlug = null,
                minPrice = 0f,
                maxPrice = 500000f,
                minRating = 0f,
                minCapacity = 0,
                maxCapacity = 3000,
                amenities = emptySet(),
                sortBy = VenueSortBy.RELEVANCE,
                isClearCommand = true,
                spokenFeedbackMessage = "All search filters have been cleared. Showing all verified spaces.",
                badges = listOf(VoiceFilterBadge("🔄", "Filter", "Reset All"))
            )
        }

        var propertyType: String? = null
        var categorySlug: String? = null
        var pgType: String? = null
        var sharingType: String? = null
        var minPrice: Float? = null
        var maxPrice: Float? = null
        var minRating: Float? = null
        var minCapacity: Int? = null
        var maxCapacity: Int? = null
        val amenities = mutableSetOf<String>()
        var sortBy: VenueSortBy? = null
        var locationKeyword: String? = null
        val badges = mutableListOf<VoiceFilterBadge>()

        // 2. Detect Property Type & Category
        when {
            // PG & Hostels
            containsAny(lower, "pg", "hostel", "paying guest", "pgs", "hostels", "stay for men", "stay for women", "coliving", "co-living", "room mate") -> {
                propertyType = "PG"
                categorySlug = "pg_hostel"
                badges.add(VoiceFilterBadge("🏡", "Type", "PG & Hostels"))

                if (containsAny(lower, "gents", "men", "boys", "male", "guy", "ladko")) {
                    pgType = "Gents"
                    badges.add(VoiceFilterBadge("👨", "Gender", "Gents PG"))
                } else if (containsAny(lower, "ladies", "women", "girls", "female", "ladkiyo", "females")) {
                    pgType = "Ladies"
                    badges.add(VoiceFilterBadge("👩", "Gender", "Ladies PG"))
                } else if (containsAny(lower, "coliving", "co living", "unisex", "both")) {
                    pgType = "Coliving"
                    badges.add(VoiceFilterBadge("👥", "Type", "Co-Living"))
                }

                // Sharing options
                if (containsAny(lower, "single", "1 sharing", "one sharing", "private room")) {
                    sharingType = "Single"
                    badges.add(VoiceFilterBadge("🛏️", "Sharing", "Single Room"))
                } else if (containsAny(lower, "double", "2 sharing", "two sharing")) {
                    sharingType = "2 Sharing"
                    badges.add(VoiceFilterBadge("🛏️", "Sharing", "2 Sharing"))
                } else if (containsAny(lower, "triple", "3 sharing", "three sharing")) {
                    sharingType = "3 Sharing"
                    badges.add(VoiceFilterBadge("🛏️", "Sharing", "3 Sharing"))
                } else if (containsAny(lower, "four sharing", "4 sharing")) {
                    sharingType = "4 Sharing"
                    badges.add(VoiceFilterBadge("🛏️", "Sharing", "4 Sharing"))
                }
            }

            // Hotels & Stays
            containsAny(lower, "hotel", "hotels", "resort", "suite", "day stay", "night stay", "deluxe room", "hotel room", "motel") -> {
                propertyType = "HOTEL"
                categorySlug = "hotel_stay"
                badges.add(VoiceFilterBadge("🏨", "Type", "Hotels & Stays"))

                if (containsAny(lower, "5 star", "five star")) {
                    minRating = 4.8f
                    badges.add(VoiceFilterBadge("⭐", "Class", "5-Star Luxury"))
                } else if (containsAny(lower, "4 star", "four star")) {
                    minRating = 4.0f
                    badges.add(VoiceFilterBadge("⭐", "Class", "4-Star+"))
                } else if (containsAny(lower, "3 star", "three star")) {
                    minRating = 3.5f
                    badges.add(VoiceFilterBadge("⭐", "Class", "3-Star+"))
                }
            }

            // Function Halls & Banquets
            containsAny(lower, "function hall", "banquet", "marriage hall", "wedding hall", "kalyana mandapam", "mandapam", "party hall", "party lawn", "convention center", "convention hall", "reception hall") -> {
                propertyType = "VENUE"
                if (containsAny(lower, "banquet")) {
                    categorySlug = "banquet_hall"
                    badges.add(VoiceFilterBadge("🏛️", "Category", "Banquet Hall"))
                } else if (containsAny(lower, "marriage", "wedding", "kalyana", "mandapam")) {
                    categorySlug = "marriage_hall"
                    badges.add(VoiceFilterBadge("💍", "Category", "Marriage Hall"))
                } else if (containsAny(lower, "lawn", "garden", "outdoor")) {
                    categorySlug = "party_lawn"
                    badges.add(VoiceFilterBadge("🌳", "Category", "Party Lawn"))
                } else if (containsAny(lower, "convention")) {
                    categorySlug = "convention_center"
                    badges.add(VoiceFilterBadge("🎪", "Category", "Convention Center"))
                } else {
                    categorySlug = "function_hall"
                    badges.add(VoiceFilterBadge("🏰", "Category", "Function Hall"))
                }
            }

            // Sports & Turfs
            containsAny(lower, "cricket", "turf", "ground", "box cricket", "pitch") -> {
                propertyType = "OTHER"
                categorySlug = "cricket"
                badges.add(VoiceFilterBadge("🏏", "Category", "Cricket Turf"))
            }
            containsAny(lower, "football", "soccer", "futsal") -> {
                propertyType = "OTHER"
                categorySlug = "football"
                badges.add(VoiceFilterBadge("⚽", "Category", "Football Ground"))
            }
            containsAny(lower, "indoor", "badminton", "table tennis", "squash", "pickleball") -> {
                propertyType = "OTHER"
                categorySlug = "indoor"
                badges.add(VoiceFilterBadge("🏸", "Category", "Indoor Sports"))
            }

            // Coworking & Meeting rooms
            containsAny(lower, "meeting room", "conference room", "board room", "coworking", "workspace", "desk", "office") -> {
                propertyType = "OTHER"
                categorySlug = "meeting_room"
                badges.add(VoiceFilterBadge("💼", "Category", "Meeting & Coworking"))
            }
        }

        // 3. Detect Price Constraints
        val parsedMaxPrice = extractMaxPrice(lower)
        if (parsedMaxPrice != null) {
            maxPrice = parsedMaxPrice
            badges.add(VoiceFilterBadge("💰", "Max Budget", "₹${formatCurrency(parsedMaxPrice)}"))
        }

        val parsedMinPrice = extractMinPrice(lower)
        if (parsedMinPrice != null) {
            minPrice = parsedMinPrice
            badges.add(VoiceFilterBadge("💵", "Min Price", "₹${formatCurrency(parsedMinPrice)}"))
        }

        // 4. Detect Capacity Constraints (for halls, banquets, event spaces)
        val parsedCapacity = extractCapacity(lower)
        if (parsedCapacity != null) {
            minCapacity = parsedCapacity
            badges.add(VoiceFilterBadge("👥", "Capacity", "$parsedCapacity+ Guests"))
        }

        // 5. Detect Rating Constraints
        if (containsAny(lower, "top rated", "best rated", "highest rated", "top review", "best rating") && minRating == null) {
            minRating = 4.5f
            badges.add(VoiceFilterBadge("⭐", "Rating", "4.5+ ★"))
        } else if (containsAny(lower, "4 star", "four star", "above 4") && minRating == null) {
            minRating = 4.0f
            badges.add(VoiceFilterBadge("⭐", "Rating", "4.0+ ★"))
        }

        // 6. Detect Amenities
        if (containsAny(lower, "ac", "air condition", "air conditioned", "central ac", "cooling")) {
            amenities.add("ac")
            badges.add(VoiceFilterBadge("❄️", "Amenity", "Air Conditioned"))
        }
        if (containsAny(lower, "parking", "car parking", "valet", "garage")) {
            amenities.add("parking")
            badges.add(VoiceFilterBadge("🚗", "Amenity", "Car Parking"))
        }
        if (containsAny(lower, "wifi", "wi-fi", "internet", "high speed")) {
            amenities.add("wifi")
            badges.add(VoiceFilterBadge("📶", "Amenity", "High-Speed Wi-Fi"))
        }
        if (containsAny(lower, "catering", "food", "kitchen", "buffet", "veg", "non veg", "meal", "breakfast", "dinner")) {
            amenities.add("catering")
            badges.add(VoiceFilterBadge("🍽️", "Amenity", "Catering & Food"))
        }
        if (containsAny(lower, "pool", "swimming pool", "swim")) {
            amenities.add("pool")
            badges.add(VoiceFilterBadge("🏊", "Amenity", "Swimming Pool"))
        }
        if (containsAny(lower, "lawn", "garden", "outdoor", "terrace", "open air")) {
            amenities.add("lawn")
            badges.add(VoiceFilterBadge("🌿", "Amenity", "Lawn / Garden"))
        }
        if (containsAny(lower, "power backup", "generator", "backup")) {
            amenities.add("power_backup")
            badges.add(VoiceFilterBadge("⚡", "Amenity", "Power Backup"))
        }
        if (containsAny(lower, "stage", "sound", "speaker", "dj", "audio", "mic")) {
            amenities.add("stage_sound")
            badges.add(VoiceFilterBadge("🔊", "Amenity", "Stage & Audio"))
        }
        if (containsAny(lower, "rooms", "guest room", "stay", "bridal room", "changing room")) {
            amenities.add("rooms")
            badges.add(VoiceFilterBadge("🛏️", "Amenity", "Guest Rooms"))
        }
        if (containsAny(lower, "alcohol", "bar", "liquor", "drinks")) {
            amenities.add("alcohol")
            badges.add(VoiceFilterBadge("🍸", "Amenity", "Bar / Drinks"))
        }

        // 7. Detect Sort Orders
        when {
            containsAny(lower, "cheapest", "lowest price", "price low to high", "affordable", "budget friendly", "sasta", "low cost") -> {
                sortBy = VenueSortBy.PRICE_LOW_HIGH
                badges.add(VoiceFilterBadge("🏷️", "Sort", "Price: Low to High"))
            }
            containsAny(lower, "luxury", "most expensive", "premium", "price high to low", "high end", "mehenga") -> {
                sortBy = VenueSortBy.PRICE_HIGH_LOW
                badges.add(VoiceFilterBadge("💎", "Sort", "Price: High to Low"))
            }
            containsAny(lower, "top rated", "highest rating", "best rating", "best reviews", "popular") -> {
                sortBy = VenueSortBy.RATING
                badges.add(VoiceFilterBadge("🌟", "Sort", "Top Rated"))
            }
            containsAny(lower, "biggest", "largest", "maximum capacity", "highest capacity") -> {
                sortBy = VenueSortBy.RELEVANCE
                badges.add(VoiceFilterBadge("👑", "Filter", "Large Spaces"))
            }
            containsAny(lower, "nearest", "nearby", "closest", "near me", "around me", "pass me") -> {
                sortBy = VenueSortBy.DISTANCE
                badges.add(VoiceFilterBadge("📍", "Sort", "Nearest First"))
            }
        }

        // 8. Detect Location keywords & Extract Cleaned Search Keyword Query
        val locationMatch = extractLocationKeyword(lower)
        if (locationMatch != null) {
            locationKeyword = locationMatch
            badges.add(VoiceFilterBadge("📍", "Location", locationMatch.replaceFirstChar { it.uppercase() }))
        }

        val cleanedQuery = extractCleanedSearchKeyword(raw, propertyType, categorySlug, locationKeyword, amenities)

        // 9. Build a natural spoken TTS feedback sentence
        val feedbackBuilder = StringBuilder("Found spaces")
        if (badges.isNotEmpty()) {
            val keyBadges = badges.joinToString(", ") { "${it.title}: ${it.value}" }
            feedbackBuilder.append(" filtered by $keyBadges.")
        } else if (cleanedQuery.isNotBlank()) {
            feedbackBuilder.append(" matching '$cleanedQuery'.")
        } else {
            feedbackBuilder.append(" matching your voice command.")
        }

        return VoiceFilterResult(
            rawSpokenText = raw,
            cleanedSearchQuery = cleanedQuery,
            propertyType = propertyType,
            categorySlug = categorySlug,
            pgType = pgType,
            sharingType = sharingType,
            minPrice = minPrice,
            maxPrice = maxPrice,
            minRating = minRating,
            minCapacity = minCapacity,
            maxCapacity = maxCapacity,
            amenities = amenities,
            sortBy = sortBy,
            locationKeyword = locationKeyword,
            isClearCommand = false,
            spokenFeedbackMessage = feedbackBuilder.toString(),
            badges = badges
        )
    }

    private fun isResetQuery(lower: String): Boolean {
        return containsAny(
            lower,
            "reset", "clear filter", "clear all", "reset all",
            "show all", "show everything", "remove filter", "remove all",
            "start over", "clear search"
        )
    }

    private fun containsAny(text: String, vararg keywords: String): Boolean {
        return keywords.any { kw ->
            text.contains(kw, ignoreCase = true)
        }
    }

    private fun extractMaxPrice(lower: String): Float? {
        // Patterns: "under 50000", "below 10k", "less than 20000", "within 8000", "under 1 lakh", "max 15000"
        val lakhPattern = Pattern.compile("(?:under|below|less than|within|max|budget)\\s*(\\d+(?:\\.\\d+)?)\\s*(?:lakh|lakhs|lac|lacs)")
        val lakhMatcher = lakhPattern.matcher(lower)
        if (lakhMatcher.find()) {
            val num = lakhMatcher.group(1)?.toFloatOrNull() ?: 1f
            return num * 100000f
        }

        val kPattern = Pattern.compile("(?:under|below|less than|within|max|budget)\\s*(?:rs\\.?|inr|₹)?\\s*(\\d+)\\s*(?:k|thousand)")
        val kMatcher = kPattern.matcher(lower)
        if (kMatcher.find()) {
            val num = kMatcher.group(1)?.toFloatOrNull() ?: 0f
            return num * 1000f
        }

        val numPattern = Pattern.compile("(?:under|below|less than|within|max|budget|costing)\\s*(?:rs\\.?|inr|₹)?\\s*(\\d{3,7})")
        val numMatcher = numPattern.matcher(lower)
        if (numMatcher.find()) {
            return numMatcher.group(1)?.toFloatOrNull()
        }

        return null
    }

    private fun extractMinPrice(lower: String): Float? {
        // Pattern: "above 10000", "more than 5000", "min 20k", "starting from 15000"
        val minPattern = Pattern.compile("(?:above|more than|min|starting from|greater than)\\s*(?:rs\\.?|inr|₹)?\\s*(\\d{3,7})")
        val minMatcher = minPattern.matcher(lower)
        if (minMatcher.find()) {
            return minMatcher.group(1)?.toFloatOrNull()
        }

        val kPattern = Pattern.compile("(?:above|more than|min|starting from)\\s*(?:rs\\.?|inr|₹)?\\s*(\\d+)\\s*(?:k|thousand)")
        val kMatcher = kPattern.matcher(lower)
        if (kMatcher.find()) {
            val num = kMatcher.group(1)?.toFloatOrNull() ?: 0f
            return num * 1000f
        }

        return null
    }

    private fun extractCapacity(lower: String): Int? {
        // Patterns: "for 500 people", "capacity 1000", "500 guests", "300 members", "seats 200"
        val pattern = Pattern.compile("(?:for|capacity|seats?|fit|accommodate|min)?\\s*(\\d{2,5})\\s*(?:people|guests|members|capacity|seats|persons|pax)")
        val matcher = pattern.matcher(lower)
        if (matcher.find()) {
            return matcher.group(1)?.toIntOrNull()
        }

        val capPattern = Pattern.compile("capacity\\s*(?:of)?\\s*(\\d{2,5})")
        val capMatcher = capPattern.matcher(lower)
        if (capMatcher.find()) {
            return capMatcher.group(1)?.toIntOrNull()
        }

        return null
    }

    private fun extractLocationKeyword(lower: String): String? {
        // Patterns: "in Madhapur", "near Gachibowli", "at Jubilee Hills", "in Bangalore", "around Hitech City"
        val pattern = Pattern.compile("(?:in|at|near|around|located in)\\s+([a-zA-Z\\s]{3,25})")
        val matcher = pattern.matcher(lower)
        if (matcher.find()) {
            val candidate = matcher.group(1)?.trim() ?: ""
            // Filter out common stop words
            val stopWords = setOf("hyderabad", "bangalore", "chennai", "mumbai", "delhi", "pune", "madhapur", "gachibowli", "kondapur", "jubilee hills", "banjara hills", "whitefield", "koramangala", "indiranagar", "hitech city", "kukatpally", "begumpet", "secunderabad")
            if (stopWords.any { candidate.contains(it, ignoreCase = true) }) {
                return candidate.split(" ").take(3).joinToString(" ")
            }
            if (candidate.isNotBlank() && !candidate.contains("a ") && !candidate.contains("the ") && candidate.length in 3..25) {
                return candidate.split(" ").take(2).joinToString(" ")
            }
        }
        return null
    }

    private fun extractCleanedSearchKeyword(
        raw: String,
        propertyType: String?,
        categorySlug: String?,
        locationKeyword: String?,
        amenities: Set<String>
    ): String {
        // If a specific location is mentioned or specific venue name, return it cleanly
        if (locationKeyword != null && locationKeyword.isNotBlank()) {
            return locationKeyword
        }

        // Clean out filler words e.g. "search for", "find me", "show me", "i want", "looking for"
        var cleaned = raw
        val stopPhrases = listOf(
            "search for", "find me", "show me", "i want", "looking for", "please find", "give me",
            "venues in", "spaces in", "rooms in", "under", "below", "with ac", "with parking",
            "with wifi", "with catering", "with pool", "with lawn", "for 500 people", "top rated",
            "cheapest", "best"
        )
        for (phrase in stopPhrases) {
            cleaned = cleaned.replace(Regex("(?i)$phrase"), "")
        }

        cleaned = cleaned.trim().replace(Regex("\\s+"), " ")

        // If the remaining string is too generic (e.g. "hotel", "pg", "banquet hall"), leave it blank so filters do the work
        val genericTerms = setOf("pg", "hostel", "hotel", "hotels", "hall", "halls", "banquet", "banquet hall", "function hall", "turf", "cricket", "meeting room", "workspace")
        if (genericTerms.contains(cleaned.lowercase(Locale.ROOT))) {
            return ""
        }

        return cleaned
    }

    private fun formatCurrency(amount: Float): String {
        return if (amount >= 100000) {
            "${String.format(Locale.US, "%.1f", amount / 100000f)}L"
        } else if (amount >= 1000) {
            "${(amount / 1000).toInt()}k"
        } else {
            amount.toInt().toString()
        }
    }
}
