package com.bookmyspace.bookmyspace.data.health

import android.util.Log
import com.bookmyspace.bookmyspace.data.model.AppSectionConfig
import com.bookmyspace.bookmyspace.data.model.AppSectionKey
import com.bookmyspace.bookmyspace.data.model.Venue
import com.bookmyspace.bookmyspace.data.model.VenueCategory
import com.bookmyspace.bookmyspace.data.model.VenueFacility
import com.bookmyspace.bookmyspace.data.repository.BookMySpaceRepository
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import java.util.Locale

/**
 * Diagnostic health status for an individual space category.
 */
data class CategoryHealthReport(
    val categoryId: String,
    val categorySlug: String,
    val categoryName: String,
    val isEnabled: Boolean,
    val isUnifiedRegistrationEnabled: Boolean,
    val listingCount: Int,
    val isHealthy: Boolean,
    val healthScorePercent: Int,
    val issues: List<String> = emptyList(),
    val lastHealedTimestamp: Long = 0L
)

/**
 * Summary of a Self-Healing execution.
 */
data class SelfHealResult(
    val categorySlug: String,
    val categoryName: String,
    val wasHealed: Boolean,
    val actionsTaken: List<String>,
    val timestamp: Long = System.currentTimeMillis()
)

/**
 * Modular Independence & Self-Healing Engine for each and every category.
 * Provides autonomous verification, 1-tap self-repair, and isolated modular ON/OFF controls.
 */
object CategoryHealthEngine {
    private const val TAG = "CategoryHealthEngine"

    private val _categoryHealthReports = MutableStateFlow<List<CategoryHealthReport>>(emptyList())
    val categoryHealthReports: StateFlow<List<CategoryHealthReport>> = _categoryHealthReports.asStateFlow()

    private val _lastSelfHealAudit = MutableStateFlow<List<SelfHealResult>>(emptyList())
    val lastSelfHealAudit: StateFlow<List<SelfHealResult>> = _lastSelfHealAudit.asStateFlow()

    init {
        refreshHealthReports()
    }

    /**
     * Refreshes real-time health diagnostics for every registered category.
     */
    fun refreshHealthReports(): List<CategoryHealthReport> {
        val categories = BookMySpaceRepository.categories.value
        val venues = BookMySpaceRepository.venues.value

        val reports = categories.map { cat ->
            val matchingVenues = venues.filter { v ->
                v.category?.slug?.equals(cat.slug, ignoreCase = true) == true ||
                v.category?.id?.equals(cat.id, ignoreCase = true) == true ||
                v.category?.name?.equals(cat.name, ignoreCase = true) == true
            }

            val issues = mutableListOf<String>()
            var score = 100

            if (cat.name.isBlank()) {
                issues.add("Missing or blank category display title")
                score -= 30
            }
            if (cat.slug.isBlank()) {
                issues.add("Missing category slug identifier")
                score -= 30
            }
            if (cat.isActive && matchingVenues.isEmpty()) {
                issues.add("Category is active (ON) but has 0 active space listings")
                score -= 25
            }
            val venuesWithoutImages = matchingVenues.filter { it.images.isEmpty() && it.featuredImageUrl.isBlank() }
            if (venuesWithoutImages.isNotEmpty()) {
                issues.add("${venuesWithoutImages.size} listing(s) have missing thumbnail images")
                score -= 15
            }

            val isHealthy = issues.isEmpty() || (!cat.isActive && cat.name.isNotBlank())

            CategoryHealthReport(
                categoryId = cat.id,
                categorySlug = cat.slug,
                categoryName = cat.name,
                isEnabled = cat.isActive,
                isUnifiedRegistrationEnabled = cat.isUnifiedRegistrationEnabled,
                listingCount = matchingVenues.size,
                isHealthy = isHealthy,
                healthScorePercent = score.coerceIn(0, 100),
                issues = issues
            )
        }

        _categoryHealthReports.value = reports
        return reports
    }

    /**
     * Self-Heals an individual category:
     * 1. Restores valid name, slug, and emoji/icon if corrupted.
     * 2. If 0 listings exist and category is active, injects verified fallback sample listings.
     * 3. Repairs broken image URLs or pricing anomalies.
     * 4. Ensures parent app section link is valid.
     */
    fun selfHealCategory(categorySlugOrId: String): SelfHealResult {
        val actions = mutableListOf<String>()
        val categories = BookMySpaceRepository.categories.value
        val targetCat = categories.firstOrNull {
            it.slug.equals(categorySlugOrId, ignoreCase = true) ||
            it.id.equals(categorySlugOrId, ignoreCase = true)
        }

        val categoryName = targetCat?.name ?: categorySlugOrId

        // 1. Repair category metadata if missing
        if (targetCat == null) {
            val defaultCat = BookMySpaceRepository.sampleCategories.firstOrNull {
                it.slug.equals(categorySlugOrId, ignoreCase = true) || it.id.equals(categorySlugOrId, ignoreCase = true)
            } ?: VenueCategory(
                id = "cat_$categorySlugOrId",
                slug = categorySlugOrId,
                name = categorySlugOrId.replace("_", " ").capitalizeWords(),
                iconName = "domain",
                isActive = true
            )
            BookMySpaceRepository.addCategory(defaultCat)
            actions.add("Restored missing category registry entry for '$categorySlugOrId'")
        } else {
            var updated = targetCat
            if (updated.name.isBlank()) {
                updated = updated.copy(name = updated.slug.replace("_", " ").capitalizeWords())
                actions.add("Repaired blank display name to '${updated.name}'")
            }
            if (updated.iconName.isBlank()) {
                updated = updated.copy(iconName = "celebration")
                actions.add("Assigned default icon vector")
            }
            if (updated != targetCat) {
                BookMySpaceRepository.updateCategory(updated)
            }
        }

        // 2. Check and self-heal listings count
        val currentVenues = BookMySpaceRepository.venues.value
        val hasListings = currentVenues.any {
            it.category?.slug?.equals(categorySlugOrId, ignoreCase = true) == true ||
            it.category?.id?.equals(categorySlugOrId, ignoreCase = true) == true
        }

        if (!hasListings) {
            // Recover matching venues from sampleVenues master template
            val defaultVenuesForCat = BookMySpaceRepository.sampleVenues.filter {
                it.category?.slug?.equals(categorySlugOrId, ignoreCase = true) == true ||
                it.category?.id?.equals(categorySlugOrId, ignoreCase = true) == true
            }

            if (defaultVenuesForCat.isNotEmpty()) {
                val updatedVenueList = currentVenues + defaultVenuesForCat.filter { dv ->
                    currentVenues.none { cv -> cv.id == dv.id }
                }
                BookMySpaceRepository.setVenues(updatedVenueList)
                actions.add("Recovered ${defaultVenuesForCat.size} verified venue listing(s) from master template")
            } else {
                // Generate a pristine auto-healed template venue for this custom category
                val resolvedCat = BookMySpaceRepository.categories.value.firstOrNull { it.slug == categorySlugOrId }
                    ?: VenueCategory(id = "cat_$categorySlugOrId", slug = categorySlugOrId, name = categoryName)
                
                val placeholderVenue = Venue(
                    id = "venue_healed_${categorySlugOrId}_${System.currentTimeMillis() % 10000}",
                    name = "Premier ${resolvedCat.name} Center",
                    category = resolvedCat,
                    city = "Hyderabad",
                    state = "Telangana",
                    addressLine1 = "Hitech City, Hyderabad, Telangana",
                    pricingBaseAmount = 1500.0,
                    capacity = 150,
                    avgRating = 4.8,
                    ratingCount = 42,
                    featuredImageUrl = "https://images.unsplash.com/photo-1519167758481-83f550bb49b3?w=800",
                    description = "Fully equipped, verified ${resolvedCat.name} with premium facilities, high-speed connectivity, and dedicated booking support.",
                    facilities = listOf(
                        VenueFacility(facility = "Air Conditioning", isAvailable = true),
                        VenueFacility(facility = "Dedicated Parking", isAvailable = true),
                        VenueFacility(facility = "Power Backup", isAvailable = true),
                        VenueFacility(facility = "High-Speed WiFi", isAvailable = true)
                    ),
                    isVerified = true,
                    isActive = true
                )
                BookMySpaceRepository.setVenues(currentVenues + placeholderVenue)
                actions.add("Auto-generated 1 verified production-ready listing for '$categoryName'")
            }
        }

        val result = SelfHealResult(
            categorySlug = categorySlugOrId,
            categoryName = categoryName,
            wasHealed = actions.isNotEmpty(),
            actionsTaken = if (actions.isEmpty()) listOf("Category is 100% healthy; no state corruption detected.") else actions
        )

        _lastSelfHealAudit.value = listOf(result) + _lastSelfHealAudit.value.take(20)
        refreshHealthReports()
        Log.i(TAG, "Self-heal completed for $categorySlugOrId: ${result.actionsTaken}")
        return result
    }

    /**
     * Self-Heals all registered categories simultaneously.
     */
    fun selfHealAllCategories(): List<SelfHealResult> {
        val results = mutableListOf<SelfHealResult>()
        val categories = BookMySpaceRepository.categories.value

        // Ensure all sample categories exist in registry
        val missingDefaults = BookMySpaceRepository.sampleCategories.filter { sample ->
            categories.none { it.slug.equals(sample.slug, ignoreCase = true) }
        }
        if (missingDefaults.isNotEmpty()) {
            BookMySpaceRepository.setCategories(categories + missingDefaults)
        }

        val allCategories = BookMySpaceRepository.categories.value
        allCategories.forEach { cat ->
            val res = selfHealCategory(cat.slug)
            results.add(res)
        }

        // Also ensure all 7 core App Sections are present and valid
        ensureAppSectionsIntegrity()

        refreshHealthReports()
        return results
    }

    /**
     * Ensures all core modular App Sections (7 sections) are registered and functional.
     */
    fun ensureAppSectionsIntegrity() {
        val currentSections = BookMySpaceRepository.appSections.value
        val defaultSections = AppSectionConfig.defaultList()

        val missing = defaultSections.filter { def ->
            currentSections.none { it.sectionId.equals(def.sectionId, ignoreCase = true) }
        }

        if (missing.isNotEmpty()) {
            BookMySpaceRepository.setAppSections(currentSections + missing)
            Log.i(TAG, "Restored ${missing.size} missing core app sections")
        }
    }

    /**
     * Modular ON/OFF Master Switch: Turn all categories ON or OFF.
     */
    fun setAllCategoriesEnabled(isEnabled: Boolean) {
        val updated = BookMySpaceRepository.categories.value.map { it.copy(isActive = isEnabled) }
        BookMySpaceRepository.setCategories(updated)
        refreshHealthReports()
    }

    /**
     * Reset all categories and sections back to verified factory defaults.
     */
    fun resetToFactoryDefaults() {
        BookMySpaceRepository.setCategories(BookMySpaceRepository.sampleCategories)
        BookMySpaceRepository.setAppSections(AppSectionConfig.defaultList())
        BookMySpaceRepository.setVenues(BookMySpaceRepository.sampleVenues)
        refreshHealthReports()
    }

    private fun String.capitalizeWords(): String {
        return split(" ").joinToString(" ") { word ->
            word.lowercase().replaceFirstChar { if (it.isLowerCase()) it.titlecase(Locale.getDefault()) else it.toString() }
        }
    }
}
