package com.bookmyspace.bookmyspace.data.model

import org.json.JSONArray
import org.json.JSONObject

/**
 * High-level categories for organizing all plug-and-play features.
 */
enum class FeatureCategory(val title: String, val emoji: String, val description: String) {
    DISCOVERY_NAVIGATION("Discovery & Search", "🗺️", "Interactive maps, voice queries, carousels and smart filters"),
    BOOKING_CHECKOUT("Booking & Checkout", "⚡", "Slot engines, KYC verification, catering add-ons, promo coupons & payments"),
    PASSES_VERIFICATION("Passes & QR Check-In", "🎟️", "Digital passes, CameraX entrance scanners, and entry validations"),
    HOST_MANAGEMENT("Host & Admin Portals", "📊", "Owner revenue dashboards, slot blackout controls, and academy registers"),
    AI_ASSISTANCE("AI & Smart Tools", "🤖", "Floating AI Assistant copilot, multilingual TTS readout, and WhatsApp bridge"),
    APPEARANCE_SYSTEM("Theme & Localization", "🎨", "Dynamic M3 themes, 7 regional languages, and notification engines")
}

/**
 * Standard registry of all 24+ plug-and-play modular features in BookMySpace.
 */
enum class AppFeatureKey(
    val id: String,
    val displayName: String,
    val category: FeatureCategory,
    val summary: String,
    val emoji: String,
    val iconName: String,
    val defaultEnabled: Boolean,
    val isCore: Boolean = false,
    val defaultParameters: Map<String, String> = emptyMap()
) {
    // --- Discovery & Search ---
    MAP_DISCOVERY(
        id = "feat_map_discovery",
        displayName = "Interactive Geo-Radius Map",
        category = FeatureCategory.DISCOVERY_NAVIGATION,
        summary = "Live clustering of venue pins color-coded by category with radial distance slider (1-50 km).",
        emoji = "🗺️",
        iconName = "map",
        defaultEnabled = true,
        defaultParameters = mapOf("defaultRadiusKm" to "15", "maxRadiusKm" to "50", "enableClustering" to "true")
    ),
    VOICE_SEARCH(
        id = "feat_voice_search",
        displayName = "Voice Query & Speech Search",
        category = FeatureCategory.DISCOVERY_NAVIGATION,
        summary = "Speech-to-text voice recognition with sound wave animation in regional Indian languages.",
        emoji = "🎙️",
        iconName = "mic",
        defaultEnabled = true,
        defaultParameters = mapOf("defaultLocale" to "en-IN", "allowAutoListen" to "true")
    ),
    TRENDING_CAROUSELS(
        id = "feat_trending_carousels",
        displayName = "Dynamic Discovery Carousels",
        category = FeatureCategory.DISCOVERY_NAVIGATION,
        summary = "Curated horizontal carousels for 'Trending Near You', 'Best Rated Venues', and 'Budget Stays'.",
        emoji = "✨",
        iconName = "view_carousel",
        defaultEnabled = true,
        defaultParameters = mapOf("autoScrollSeconds" to "4", "itemsPerCarousel" to "8")
    ),
    SHIMMER_SKELETONS(
        id = "feat_shimmer_skeletons",
        displayName = "Smooth Shimmer Loading Skeletons",
        category = FeatureCategory.DISCOVERY_NAVIGATION,
        summary = "Aspect-ratio preserved shimmering skeleton placeholders for low-latency visual transitions.",
        emoji = "⚡",
        iconName = "hourglass_empty",
        defaultEnabled = true,
        defaultParameters = mapOf("shimmerDurationMs" to "900")
    ),
    RECENT_SEARCH_HISTORY(
        id = "feat_recent_search_history",
        displayName = "Recent Searches & Fast Tags",
        category = FeatureCategory.DISCOVERY_NAVIGATION,
        summary = "Local history tracking for fast one-tap replay of previous queries and location presets.",
        emoji = "🕒",
        iconName = "history",
        defaultEnabled = true,
        defaultParameters = mapOf("maxSavedQueries" to "10")
    ),

    // --- Booking & Checkout ---
    UNIFIED_KYC_REGISTRATION(
        id = "feat_unified_kyc_registration",
        displayName = "Unified User KYC & Profile",
        category = FeatureCategory.BOOKING_CHECKOUT,
        summary = "Category-mandated verified profile details (Aadhaar / Govt ID) during slot checkout.",
        emoji = "🪪",
        iconName = "badge",
        defaultEnabled = true,
        defaultParameters = mapOf("requireAadhaar" to "true", "requireEmergencyContact" to "true")
    ),
    ADDONS_AND_CATERING(
        id = "feat_addons_and_catering",
        displayName = "Catering & Decor Add-On Customizer",
        category = FeatureCategory.BOOKING_CHECKOUT,
        summary = "Configurable buffet catering (Veg/Non-Veg plate counters) and stage decoration packages.",
        emoji = "🍽️",
        iconName = "restaurant",
        defaultEnabled = true,
        defaultParameters = mapOf("defaultPlatePrice" to "450", "allowCustomNotes" to "true")
    ),
    COUPON_ENGINE(
        id = "feat_coupon_engine",
        displayName = "Promo Discount & Coupon Engine",
        category = FeatureCategory.BOOKING_CHECKOUT,
        summary = "Instant coupon verification, percentage/flat discounts, and festive promo codes.",
        emoji = "🏷️",
        iconName = "local_offer",
        defaultEnabled = true,
        defaultParameters = mapOf("maxDiscountCap" to "5000", "allowStacking" to "false")
    ),
    MULTI_GATEWAY_PAYMENTS(
        id = "feat_multi_gateway_payments",
        displayName = "Multi-Rail Payment System",
        category = FeatureCategory.BOOKING_CHECKOUT,
        summary = "UPI Intent (GPay, PhonePe, Paytm), Credit/Debit Cards, NetBanking, and Pay-At-Venue.",
        emoji = "💳",
        iconName = "payments",
        defaultEnabled = true,
        isCore = true,
        defaultParameters = mapOf("gstRatePercent" to "18.0", "allowPayAtVenue" to "true")
    ),
    PAYMENT_CIRCUIT_BREAKER(
        id = "feat_payment_circuit_breaker",
        displayName = "Self-Healing Payment Circuit Breaker",
        category = FeatureCategory.BOOKING_CHECKOUT,
        summary = "Real-time telemetry and automatic fallback to healthy payment rails on gateway hiccups.",
        emoji = "🛡️",
        iconName = "healing",
        defaultEnabled = true,
        defaultParameters = mapOf("failureThresholdCount" to "3", "retryCooldownSec" to "15")
    ),

    // --- Passes & Verification ---
    QR_CODE_PASSES(
        id = "feat_qr_code_passes",
        displayName = "Digital Booking Pass & QR Ticket",
        category = FeatureCategory.PASSES_VERIFICATION,
        summary = "Animated dynamic QR code passes with date, slot, directions, and host verification hash.",
        emoji = "🎟️",
        iconName = "qr_code",
        defaultEnabled = true,
        defaultParameters = mapOf("autoRefreshQrMinutes" to "15", "allowOfflineCache" to "true")
    ),
    CAMERA_QR_SCANNER(
        id = "feat_camera_qr_scanner",
        displayName = "Host Fast Check-In QR Scanner",
        category = FeatureCategory.PASSES_VERIFICATION,
        summary = "CameraX-powered QR scanner for venue owners with audio/haptic confirmation chimes.",
        emoji = "📷",
        iconName = "qr_code_scanner",
        defaultEnabled = true,
        defaultParameters = mapOf("playHapticFeedback" to "true", "enableSoundChime" to "true")
    ),

    // --- Host & Management ---
    OWNER_PORTAL(
        id = "feat_owner_portal",
        displayName = "Venue Owner & Host Management Suite",
        category = FeatureCategory.HOST_MANAGEMENT,
        summary = "Host listing onboarding, active booking approval/rejection, and revenue analytics.",
        emoji = "📊",
        iconName = "dashboard",
        defaultEnabled = true,
        defaultParameters = mapOf("platformCommissionPercent" to "5.0", "payoutCycleDays" to "7")
    ),
    CALENDAR_SLOT_BLACKOUT(
        id = "feat_calendar_slot_blackout",
        displayName = "Calendar Slot Blackout & Maintenance",
        category = FeatureCategory.HOST_MANAGEMENT,
        summary = "One-tap date/slot blackout tool for private events, renovation, and holiday blocking.",
        emoji = "📅",
        iconName = "event_busy",
        defaultEnabled = true,
        defaultParameters = mapOf("allowBulkBlackout" to "true")
    ),
    INSTITUTES_STUDENT_REGISTER(
        id = "feat_institutes_student_register",
        displayName = "Academies & Student Attendance Register",
        category = FeatureCategory.HOST_MANAGEMENT,
        summary = "Batch schedule manager, student roster, syllabus links, and daily attendance marking.",
        emoji = "🎓",
        iconName = "school",
        defaultEnabled = true,
        defaultParameters = mapOf("maxBatchStudents" to "40", "allowOnlineBatches" to "true")
    ),
    DYNAMIC_SCHEMA_BUILDER(
        id = "feat_dynamic_schema_builder",
        displayName = "Dynamic Custom Schema & Fields Builder",
        category = FeatureCategory.HOST_MANAGEMENT,
        summary = "Admin runtime builder for custom category attributes (stage size, curfew, instruments).",
        emoji = "🛠️",
        iconName = "tune",
        defaultEnabled = true,
        defaultParameters = mapOf("maxCustomFieldsPerCategory" to "20")
    ),

    // --- AI & Smart Tools ---
    AI_SMART_COPILOT(
        id = "feat_ai_smart_copilot",
        displayName = "Context-Aware AI Floating Assistant",
        category = FeatureCategory.AI_ASSISTANCE,
        summary = "Floating Gemini-powered AI Copilot that knows active screen context to assist users in real-time.",
        emoji = "🤖",
        iconName = "smart_toy",
        defaultEnabled = true,
        defaultParameters = mapOf("responseSpeed" to "instant", "suggestSmartChips" to "true")
    ),
    MULTILINGUAL_TTS_READOUT(
        id = "feat_multilingual_tts_readout",
        displayName = "Venue Audio Voice Readout (TTS)",
        category = FeatureCategory.AI_ASSISTANCE,
        summary = "Natural voice synthesis readout of venue highlights, pricing, and policies in Indian languages.",
        emoji = "🔊",
        iconName = "volume_up",
        defaultEnabled = true,
        defaultParameters = mapOf("speechRate" to "1.0", "pitch" to "1.0")
    ),
    WHATSAPP_ASSIST(
        id = "feat_whatsapp_assist",
        displayName = "Direct Host WhatsApp & Chat Bridge",
        category = FeatureCategory.AI_ASSISTANCE,
        summary = "One-tap WhatsApp direct messaging with pre-formatted inquiry templates.",
        emoji = "💬",
        iconName = "chat",
        defaultEnabled = true,
        defaultParameters = mapOf("includeBookingRef" to "true")
    ),
    SOS_EMERGENCY_DIAL(
        id = "feat_sos_emergency_dial",
        displayName = "Venue Security & Emergency Dial",
        category = FeatureCategory.AI_ASSISTANCE,
        summary = "Direct phone launcher for venue host, security manager, and emergency help lines.",
        emoji = "📞",
        iconName = "call",
        defaultEnabled = true,
        defaultParameters = mapOf("emergencyHelpline" to "112")
    ),

    // --- Appearance & System ---
    THEME_CUSTOMIZER(
        id = "feat_theme_customizer",
        displayName = "M3 Theme & Dynamic Palette Studio",
        category = FeatureCategory.APPEARANCE_SYSTEM,
        summary = "Theme selector supporting Emerald Green, Royal Navy, Sunset Ruby, and Auto Dark/Light modes.",
        emoji = "🎨",
        iconName = "palette",
        defaultEnabled = true,
        defaultParameters = mapOf("defaultThemePalette" to "Emerald", "enableDynamicAccent" to "true")
    ),
    REGIONAL_LOCALIZATION(
        id = "feat_regional_localization",
        displayName = "Multi-Language Regional Localization",
        category = FeatureCategory.APPEARANCE_SYSTEM,
        summary = "Instant UI string translation for 7 languages (EN, HI, TE, TA, KN, MR, BN).",
        emoji = "🌐",
        iconName = "translate",
        defaultEnabled = true,
        defaultParameters = mapOf("defaultLanguage" to "en", "allowFallback" to "true")
    ),
    SAVED_BOOKMARKS(
        id = "feat_saved_bookmarks",
        displayName = "Wishlist & Saved Bookmarks Sync",
        category = FeatureCategory.APPEARANCE_SYSTEM,
        summary = "Cloud and offline synchronized favorites folder for spaces, rooms, and courses.",
        emoji = "❤️",
        iconName = "bookmark",
        defaultEnabled = true,
        defaultParameters = mapOf("maxFavorites" to "100")
    ),
    PUSH_NOTIFICATIONS(
        id = "feat_push_notifications",
        displayName = "Booking Alert & Push Notifications",
        category = FeatureCategory.APPEARANCE_SYSTEM,
        summary = "In-app notifications and banner alerts for slot confirmation, payment receipts, and reminders.",
        emoji = "🔔",
        iconName = "notifications",
        defaultEnabled = true,
        defaultParameters = mapOf("reminderHoursBefore" to "4", "enableInAppToasts" to "true")
    ),
    SELF_HEALING_ENGINE(
        id = "feat_self_healing_engine",
        displayName = "Independent Self-Healing & Fault Recovery Engine",
        category = FeatureCategory.APPEARANCE_SYSTEM,
        summary = "Automatic diagnostic health checks, crash guards, memory fallback and self-repair for all sub-modules.",
        emoji = "🛡️",
        iconName = "healing",
        defaultEnabled = true,
        isCore = true,
        defaultParameters = mapOf("autoHealIntervalSec" to "30", "enableMemoryCacheFallback" to "true", "logDiagnostics" to "true")
    ),

    // --- Institutes, Coaching & Classes Modular Systems ---
    CATEGORY_CHECKBOX_FILTER(
        id = "feat_category_checkbox_filter",
        displayName = "Right-Side Category Checkbox Drawer & Filter",
        category = FeatureCategory.DISCOVERY_NAVIGATION,
        summary = "Right-side search bar checkbook filter sheet with multi-category selection, batch counters, and delivery mode pills.",
        emoji = "☑️",
        iconName = "checklist",
        defaultEnabled = true,
        defaultParameters = mapOf("defaultMultiSelect" to "true", "showBatchCounts" to "true", "enableDeliveryModeFilter" to "true")
    ),
    BATCH_WAITLIST_ALERTS(
        id = "feat_batch_waitlist_alerts",
        displayName = "Batch Waitlist & Push Notification Spot Alerts",
        category = FeatureCategory.HOST_MANAGEMENT,
        summary = "Instant 'Notify Me' push alert subscription for full, closed, or upcoming coaching batches with push simulations.",
        emoji = "🔔",
        iconName = "notifications_active",
        defaultEnabled = true,
        defaultParameters = mapOf("maxAlertsPerStudent" to "10", "triggerInstantPush" to "true", "allowWaitlistQueue" to "true")
    ),
    TODAY_ONGOING_CLASSES(
        id = "feat_today_ongoing_classes",
        displayName = "Live Today Ongoing Classes Ticker & Filter",
        category = FeatureCategory.DISCOVERY_NAVIGATION,
        summary = "Live visual ticker displaying today's ongoing batches, current topics, schedule times, and 1-tap filter toggle.",
        emoji = "🔴",
        iconName = "play_circle_outline",
        defaultEnabled = true,
        defaultParameters = mapOf("highlightLiveSlots" to "true", "autoFilterOngoing" to "false")
    ),
    ONE_TAP_INSTANT_BOOKING(
        id = "feat_one_tap_instant_booking",
        displayName = "1-Tap Single-Tab Instant Class Booking",
        category = FeatureCategory.BOOKING_CHECKOUT,
        summary = "Direct single-tab booking modal with dynamic attendee selection, instant summary, and direct confirmation.",
        emoji = "⚡",
        iconName = "flash_on",
        defaultEnabled = true,
        defaultParameters = mapOf("defaultBillingCycle" to "monthly", "allowInstantCheckout" to "true")
    ),
    LOCATION_RADIAL_HIERARCHY(
        id = "feat_location_radial_hierarchy",
        displayName = "Hierarchical Indian Region & GPS Radial Selector",
        category = FeatureCategory.DISCOVERY_NAVIGATION,
        summary = "Cascading Country -> State -> District -> City -> Zone selector with automatic fallback on GPS faults.",
        emoji = "📍",
        iconName = "location_on",
        defaultEnabled = true,
        defaultParameters = mapOf("defaultState" to "Telangana", "defaultCity" to "Hyderabad", "enableGpsFallback" to "true")
    ),
    FACULTY_CREDENTIALS_MODAL(
        id = "feat_faculty_credentials_modal",
        displayName = "Faculty Bio & Master Credentials Hub",
        category = FeatureCategory.HOST_MANAGEMENT,
        summary = "Detailed mentor profiles, verified awards, years of experience, direct call/WhatsApp and coaching credentials.",
        emoji = "👨‍🏫",
        iconName = "person_celebrate",
        defaultEnabled = true,
        defaultParameters = mapOf("showDirectContact" to "true", "showExperienceYears" to "true")
    ),
    TAX_INVOICE_GENERATOR(
        id = "feat_tax_invoice_generator",
        displayName = "Automated B2B/B2C GST Tax Invoicing",
        category = FeatureCategory.HOST_MANAGEMENT,
        summary = "Compliant PDF/preview tax invoices with SAC codes, GSTIN breakdown, reverse charge, and download actions.",
        emoji = "🧾",
        iconName = "receipt_long",
        defaultEnabled = true,
        defaultParameters = mapOf("defaultGstRate" to "18.0", "includeStateBreakdown" to "true")
    ),
    REFERRAL_AND_REWARDS(
        id = "feat_referral_rewards",
        displayName = "Referral Wallet & Loyalty Cashback",
        category = FeatureCategory.BOOKING_CHECKOUT,
        summary = "Referral code generator, invite links, discount credit wallet, and milestone reward tracking.",
        emoji = "🎁",
        iconName = "card_giftcard",
        defaultEnabled = true,
        defaultParameters = mapOf("referrerReward" to "250", "refereeReward" to "150")
    ),

    // --- External APIs & MCP Connectors ---
    EXTERNAL_API_AND_MCP(
        id = "feat_external_api_mcp",
        displayName = "MCP, REST APIs & App Connectors",
        category = FeatureCategory.AI_ASSISTANCE,
        summary = "Model Context Protocol (MCP) server for Claude/Cursor/Gemini, REST APIs, Webhooks, and Calendar sync.",
        emoji = "🔗",
        iconName = "hub",
        defaultEnabled = true,
        defaultParameters = mapOf("enableMcpServer" to "true", "enableRestApiV1" to "true", "enableCalendarIcsFeed" to "true")
    ),

    // --- India Hierarchical & Auto Place Discovery Engine ---
    INDIA_PLACE_DISCOVERY(
        id = "feat_india_place_discovery",
        displayName = "India Location Hierarchy & Auto Place Discovery",
        category = FeatureCategory.DISCOVERY_NAVIGATION,
        summary = "Modular Country->State->District->Mandal->Town cascade, 6-digit PIN code resolver, OpenStreetMap/India Post auto discovery, and self-healing local cache fallback.",
        emoji = "🇮🇳",
        iconName = "travel_explore",
        defaultEnabled = true,
        defaultParameters = mapOf(
            "defaultRadiusKm" to "10",
            "enableOsmOverpass" to "true",
            "enablePinCodeResolver" to "true",
            "enableSelfHealing" to "true",
            "cacheTtlHours" to "24"
        )
    );

    companion object {
        fun fromId(id: String): AppFeatureKey? {
            return entries.find { it.id.equals(id, ignoreCase = true) }
        }
    }
}

/**
 * Runtime state for a plug-and-play feature module.
 */
data class FeatureModuleConfig(
    val key: AppFeatureKey,
    val isEnabled: Boolean,
    val customTitle: String = "",
    val customDescription: String = "",
    val parameters: Map<String, String> = emptyMap(),
    val lastModified: Long = System.currentTimeMillis()
) {
    val title: String get() = customTitle.ifBlank { key.displayName }
    val description: String get() = customDescription.ifBlank { key.summary }

    fun getParam(paramName: String, fallback: String = ""): String {
        return parameters[paramName] ?: key.defaultParameters[paramName] ?: fallback
    }

    companion object {
        fun defaultList(): List<FeatureModuleConfig> {
            return AppFeatureKey.entries.map { key ->
                FeatureModuleConfig(
                    key = key,
                    isEnabled = key.defaultEnabled,
                    parameters = key.defaultParameters
                )
            }
        }
    }
}

/**
 * Quick-start preset bundles for one-click easy configuration.
 */
enum class FeaturePreset(
    val title: String,
    val subtitle: String,
    val emoji: String,
    val description: String
) {
    FULL_SUITE(
        title = "Full Enterprise Suite",
        subtitle = "All 24 Features Active",
        emoji = "🚀",
        description = "Enables all discovery, booking, KYC, catering, AI copilot, QR check-in, and host management tools."
    ),
    HOSPITALITY_AND_PG(
        title = "Hospitality, Hotels & PGs",
        subtitle = "Optimized for Stays & Room Sharing",
        emoji = "🏨",
        description = "Focuses on room stays, student hostels, KYC verification, WhatsApp assist, and dynamic pricing."
    ),
    EVENTS_AND_BANQUETS(
        title = "Events, Banquets & Venues",
        subtitle = "Optimized for Wedding & Event Halls",
        emoji = "🏛️",
        description = "Enables function halls, catering & decor add-ons, calendar blackout, and QR digital passes."
    ),
    ACADEMIES_AND_INSTITUTES(
        title = "Academies, Classes & Tuitions",
        subtitle = "Optimized for Courses & Coaching",
        emoji = "🎓",
        description = "Enables coaching centers, student attendance registers, batch managers, and custom KYC."
    ),
    MINIMALIST_SPEED(
        title = "Ultra-Fast Minimalist Mode",
        subtitle = "Zero Overhead Raw Performance",
        emoji = "⚡",
        description = "Disables secondary add-ons, AI copilot, voice TTS, and extra carousels for instant lightweight checkout."
    )
}

/**
 * JSON serialization helper for exporting/importing feature configurations.
 */
object FeatureConfigJsonHelper {
    fun toJson(configs: List<FeatureModuleConfig>): String {
        val root = JSONObject()
        root.put("version", 1)
        root.put("timestamp", System.currentTimeMillis())
        val array = JSONArray()

        configs.forEach { cfg ->
            val obj = JSONObject()
            obj.put("id", cfg.key.id)
            obj.put("enabled", cfg.isEnabled)
            if (cfg.customTitle.isNotBlank()) obj.put("customTitle", cfg.customTitle)
            if (cfg.customDescription.isNotBlank()) obj.put("customDescription", cfg.customDescription)

            val paramsObj = JSONObject()
            cfg.parameters.forEach { (k, v) -> paramsObj.put(k, v) }
            obj.put("parameters", paramsObj)
            array.put(obj)
        }
        root.put("features", array)
        return root.toString(2)
    }

    fun fromJson(jsonStr: String): List<FeatureModuleConfig>? {
        return try {
            val root = JSONObject(jsonStr)
            val array = root.optJSONArray("features") ?: return null
            val result = mutableListOf<FeatureModuleConfig>()

            for (i in 0 until array.length()) {
                val obj = array.getJSONObject(i)
                val id = obj.optString("id")
                val key = AppFeatureKey.fromId(id) ?: continue
                val isEnabled = obj.optBoolean("enabled", key.defaultEnabled)
                val customTitle = obj.optString("customTitle", "")
                val customDesc = obj.optString("customDescription", "")

                val paramsMap = mutableMapOf<String, String>()
                val paramsObj = obj.optJSONObject("parameters")
                if (paramsObj != null) {
                    val keys = paramsObj.keys()
                    while (keys.hasNext()) {
                        val k = keys.next()
                        paramsMap[k] = paramsObj.optString(k, "")
                    }
                }

                result.add(
                    FeatureModuleConfig(
                        key = key,
                        isEnabled = isEnabled,
                        customTitle = customTitle,
                        customDescription = customDesc,
                        parameters = if (paramsMap.isNotEmpty()) paramsMap else key.defaultParameters
                    )
                )
            }

            // Fill any missing features with default state
            val existingKeys = result.map { it.key }.toSet()
            AppFeatureKey.entries.forEach { k ->
                if (k !in existingKeys) {
                    result.add(FeatureModuleConfig(key = k, isEnabled = k.defaultEnabled, parameters = k.defaultParameters))
                }
            }

            result
        } catch (e: Exception) {
            null
        }
    }
}
