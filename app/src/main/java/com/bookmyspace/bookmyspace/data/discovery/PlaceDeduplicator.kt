package com.bookmyspace.bookmyspace.data.discovery

import com.bookmyspace.bookmyspace.data.location.IndiaLocationMasterData
import com.bookmyspace.bookmyspace.data.model.PlaceDiscoveryModel
import java.util.Locale
import kotlin.math.min

/**
 * Intelligent Deduplication Engine for Place Discovery
 * Merges duplicate entries from different sources (BookMySpace DB, OpenStreetMap, Postal directories, Geocoders)
 * while preserving BookMySpace registered verification & booking capabilities.
 */
object PlaceDeduplicator {

    private val NOISE_WORDS = setOf(
        "the", "a", "an", "and", "or", "pvt", "ltd", "private", "limited",
        "hall", "halls", "function", "kalyana", "mandapam", "mandap", "mahal",
        "hotel", "lodge", "resort", "inn", "pg", "hostel", "accommodation",
        "institute", "academy", "classes", "coaching", "center", "centre",
        "convention", "banquet", "gardens", "palace", "residency", "deluxe"
    )

    /**
     * Deduplicates a list of PlaceDiscoveryModel items
     */
    fun deduplicate(places: List<PlaceDiscoveryModel>): List<PlaceDiscoveryModel> {
        if (places.size <= 1) return places

        val uniqueList = mutableListOf<PlaceDiscoveryModel>()

        for (candidate in places) {
            val existingIndex = uniqueList.indexOfFirst { existing ->
                isSamePlace(existing, candidate)
            }

            if (existingIndex == -1) {
                uniqueList.add(candidate)
            } else {
                val existing = uniqueList[existingIndex]
                val merged = mergePlaces(existing, candidate)
                uniqueList[existingIndex] = merged
            }
        }

        return uniqueList
    }

    /**
     * Checks if two records represent the exact same physical place
     */
    fun isSamePlace(a: PlaceDiscoveryModel, b: PlaceDiscoveryModel): Boolean {
        // 1. Check exact sourcePlaceId or BookMySpace ID match
        if (a.sourcePlaceId.isNotBlank() && a.sourcePlaceId == b.sourcePlaceId) return true
        if (a.bookMySpaceVenueId != null && a.bookMySpaceVenueId == b.bookMySpaceVenueId) return true

        // 2. Exact normalized phone number match
        val cleanPhoneA = normalizePhone(a.phone)
        val cleanPhoneB = normalizePhone(b.phone)
        val hasMatchingPhone = cleanPhoneA.length >= 10 && cleanPhoneA == cleanPhoneB

        // 3. Proximity distance calculation
        val distanceKm = IndiaLocationMasterData.calculateDistanceKm(
            a.latitude, a.longitude,
            b.latitude, b.longitude
        )
        val distanceMeters = distanceKm * 1000.0

        // If phone numbers match and they are within 500m of each other -> definitely same place
        if (hasMatchingPhone && distanceMeters < 500.0) {
            return true
        }

        // 4. Name similarity & coordinate proximity
        val normalizedNameA = normalizeName(a.name)
        val normalizedNameB = normalizeName(b.name)
        val nameSimilarity = calculateSimilarity(normalizedNameA, normalizedNameB)

        // Close proximity (< 120m) with high name similarity (> 0.65) or exact core tokens match
        if (distanceMeters <= 120.0) {
            if (nameSimilarity >= 0.65) return true

            val tokensA = extractKeywords(a.name)
            val tokensB = extractKeywords(b.name)
            val overlap = tokensA.intersect(tokensB)
            if (tokensA.isNotEmpty() && tokensB.isNotEmpty() && overlap.size >= min(tokensA.size, tokensB.size)) {
                return true
            }
        }

        // Medium proximity (< 350m) with very high name similarity (> 0.85) and same category
        if (distanceMeters <= 350.0 && nameSimilarity >= 0.85 && isCategoryCompatible(a.categorySlug, b.categorySlug)) {
            return true
        }

        return false
    }

    /**
     * Merges two matching place records, prioritizing BookMySpace verified details
     */
    private fun mergePlaces(existing: PlaceDiscoveryModel, newCandidate: PlaceDiscoveryModel): PlaceDiscoveryModel {
        val isExistingRegistered = existing.isRegisteredInBookMySpace
        val isNewRegistered = newCandidate.isRegisteredInBookMySpace

        val primary = if (isExistingRegistered) existing else if (isNewRegistered) newCandidate else existing
        val secondary = if (primary === existing) newCandidate else existing

        return primary.copy(
            isRegisteredInBookMySpace = isExistingRegistered || isNewRegistered,
            bookMySpaceVenueId = primary.bookMySpaceVenueId ?: secondary.bookMySpaceVenueId,
            claimStatus = if (isExistingRegistered || isNewRegistered) "REGISTERED" else primary.claimStatus,
            phone = primary.phone.ifBlank { secondary.phone },
            website = primary.website.ifBlank { secondary.website },
            openingHours = primary.openingHours.ifBlank { secondary.openingHours },
            rating = if (primary.rating > 0.0) primary.rating else secondary.rating,
            reviewCount = if (primary.reviewCount > 0) primary.reviewCount else secondary.reviewCount,
            photoUrl = primary.photoUrl.ifBlank { secondary.photoUrl },
            pricingEstimate = primary.pricingEstimate.ifBlank { secondary.pricingEstimate },
            facilities = (primary.facilities + secondary.facilities).distinct(),
            address = primary.address.ifBlank { secondary.address }
        )
    }

    private fun normalizeName(name: String): String {
        return name.lowercase(Locale.ROOT)
            .replace(Regex("[^a-z0-9\\s]"), " ")
            .split(Regex("\\s+"))
            .filter { it.isNotBlank() && it !in NOISE_WORDS }
            .joinToString(" ")
            .trim()
    }

    private fun extractKeywords(name: String): Set<String> {
        return name.lowercase(Locale.ROOT)
            .replace(Regex("[^a-z0-9\\s]"), " ")
            .split(Regex("\\s+"))
            .filter { it.length > 2 && it !in NOISE_WORDS }
            .toSet()
    }

    private fun normalizePhone(phone: String): String {
        return phone.replace(Regex("[^0-9]"), "").takeLast(10)
    }

    private fun isCategoryCompatible(catA: String, catB: String): Boolean {
        if (catA == catB) return true
        val weddingGroup = setOf("function_hall", "marriage_hall", "banquet_hall", "convention_center")
        val stayGroup = setOf("hotel", "lodge", "resort", "pg", "hostel")
        val eduGroup = setOf("institute", "coaching_center", "training_center")

        if (catA in weddingGroup && catB in weddingGroup) return true
        if (catA in stayGroup && catB in stayGroup) return true
        if (catA in eduGroup && catB in eduGroup) return true
        return false
    }

    /**
     * Levenshtein similarity (0.0 to 1.0)
     */
    private fun calculateSimilarity(s1: String, s2: String): Double {
        if (s1 == s2) return 1.0
        if (s1.isEmpty() || s2.isEmpty()) return 0.0

        val maxLen = maxOf(s1.length, s2.length)
        val distance = levenshteinDistance(s1, s2)
        return 1.0 - (distance.toDouble() / maxLen)
    }

    private fun levenshteinDistance(lhs: CharSequence, rhs: CharSequence): Int {
        val lhsLength = lhs.length
        val rhsLength = rhs.length

        var cost = IntArray(lhsLength + 1) { it }
        var newCost = IntArray(lhsLength + 1) { 0 }

        for (i in 1..rhsLength) {
            newCost[0] = i
            for (j in 1..lhsLength) {
                val match = if (lhs[j - 1] == rhs[i - 1]) 0 else 1
                val costReplace = cost[j - 1] + match
                val costInsert = cost[j] + 1
                val costDelete = newCost[j - 1] + 1
                newCost[j] = minOf(costInsert, costDelete, costReplace)
            }
            val swap = cost
            cost = newCost
            newCost = swap
        }
        return cost[lhsLength]
    }
}
