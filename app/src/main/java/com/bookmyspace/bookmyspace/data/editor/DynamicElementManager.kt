package com.bookmyspace.bookmyspace.data.editor

import android.content.Context
import android.content.SharedPreferences
import android.util.Log
import com.bookmyspace.bookmyspace.data.model.AdminElementConfig
import com.bookmyspace.bookmyspace.data.model.AdminElementType
import com.google.firebase.firestore.FirebaseFirestore
import com.google.firebase.firestore.ListenerRegistration
import com.google.firebase.firestore.SetOptions
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import org.json.JSONArray
import org.json.JSONObject

/**
 * Universal Dynamic Content & Admin Live Element Customizer Engine.
 * Enables Admins to dynamically edit ANY text, editbox placeholder, button CTA,
 * badge, banner, or application object live with instant on-screen reflection and persistence.
 */
object DynamicElementManager {
    private const val TAG = "DynamicElementManager"
    private const val PREFS_NAME = "bms_admin_dynamic_elements_prefs"
    private const val KEY_ELEMENTS_JSON = "saved_custom_elements_json"

    private var sharedPreferences: SharedPreferences? = null
    private var firestoreDb: FirebaseFirestore? = null
    private var elementsListener: ListenerRegistration? = null
    private val scope = CoroutineScope(Dispatchers.IO)

    // Visual Edit Mode Inspector Active State
    private val _isVisualEditModeActive = MutableStateFlow(false)
    val isVisualEditModeActive: StateFlow<Boolean> = _isVisualEditModeActive.asStateFlow()

    // Currently inspected element for modal sheet editing
    private val _inspectedElement = MutableStateFlow<AdminElementConfig?>(null)
    val inspectedElement: StateFlow<AdminElementConfig?> = _inspectedElement.asStateFlow()

    // Universal Registry of all App Elements
    private val _customElements = MutableStateFlow<Map<String, AdminElementConfig>>(emptyMap())
    val customElements: StateFlow<Map<String, AdminElementConfig>> = _customElements.asStateFlow()

    // Default built-in elements catalog
    private val defaultElementsCatalog: List<AdminElementConfig> = listOf(
        // --- 1. HOME SCREEN ---
        AdminElementConfig(
            key = "home_search_hint",
            screenName = "Home",
            elementType = AdminElementType.EDIT_BOX,
            displayName = "Home Search Bar Hint",
            description = "Placeholder hint displayed in the primary Home Screen search box",
            currentValue = "Search venues, halls, turfs, PGs, coaching...",
            defaultValue = "Search venues, halls, turfs, PGs, coaching...",
            placeholder = "Search venues, halls, turfs, PGs, coaching...",
            defaultPlaceholder = "Search venues, halls, turfs, PGs, coaching..."
        ),
        AdminElementConfig(
            key = "home_hero_title",
            screenName = "Home",
            elementType = AdminElementType.TEXT,
            displayName = "Home Hero Main Title",
            description = "Prominent welcome banner heading on the Home Screen",
            currentValue = "Book Spaces & Coaching Easily",
            defaultValue = "Book Spaces & Coaching Easily",
            fontWeightName = "Bold"
        ),
        AdminElementConfig(
            key = "home_hero_subtitle",
            screenName = "Home",
            elementType = AdminElementType.TEXT,
            displayName = "Home Hero Subtitle",
            description = "Descriptive tagline below the main Home title",
            currentValue = "Function halls, hotels, PGs, coaching academies & sports turfs with instant confirmed booking.",
            defaultValue = "Function halls, hotels, PGs, coaching academies & sports turfs with instant confirmed booking."
        ),
        AdminElementConfig(
            key = "home_voice_assistant_title",
            screenName = "Home",
            elementType = AdminElementType.BUTTON,
            displayName = "Easy Voice Assistant CTA",
            description = "Label on the floating Voice Assistant chip",
            currentValue = "Easy Voice Booking 🎙️",
            defaultValue = "Easy Voice Booking 🎙️"
        ),
        AdminElementConfig(
            key = "home_explore_venues_heading",
            screenName = "Home",
            elementType = AdminElementType.TEXT,
            displayName = "Explore Venues Section Heading",
            description = "Title for the top venues section on Home screen",
            currentValue = "Explore Venues & Spaces",
            defaultValue = "Explore Venues & Spaces",
            fontWeightName = "Bold"
        ),
        AdminElementConfig(
            key = "home_popular_spaces_heading",
            screenName = "Home",
            elementType = AdminElementType.TEXT,
            displayName = "Popular Spaces Heading",
            description = "Title for trending spaces section on Home screen",
            currentValue = "Popular & Trending Near You 🔥",
            defaultValue = "Popular & Trending Near You 🔥",
            fontWeightName = "Bold"
        ),
        AdminElementConfig(
            key = "home_featured_promo_banner",
            screenName = "Home",
            elementType = AdminElementType.BANNER,
            displayName = "Promotional Discount Banner",
            description = "Special promotional headline banner on Home screen",
            currentValue = "🎉 Monsoon Special: Get 20% Instant Discount on First Booking with code BMS20",
            defaultValue = "🎉 Monsoon Special: Get 20% Instant Discount on First Booking with code BMS20"
        ),

        // --- 2. SEARCH & DISCOVERY SCREEN ---
        AdminElementConfig(
            key = "search_input_placeholder",
            screenName = "Search",
            elementType = AdminElementType.EDIT_BOX,
            displayName = "Search Screen Input Hint",
            description = "Placeholder for search query bar on Search screen",
            currentValue = "Search by venue name, locality, or category...",
            defaultValue = "Search by venue name, locality, or category...",
            placeholder = "Search by venue name, locality, or category...",
            defaultPlaceholder = "Search by venue name, locality, or category..."
        ),
        AdminElementConfig(
            key = "search_filter_price_label",
            screenName = "Search",
            elementType = AdminElementType.TEXT,
            displayName = "Price Filter Slider Label",
            description = "Label on price range filter header",
            currentValue = "Max Price per Hour / Day",
            defaultValue = "Max Price per Hour / Day"
        ),
        AdminElementConfig(
            key = "search_empty_title",
            screenName = "Search",
            elementType = AdminElementType.TEXT,
            displayName = "Search Empty State Title",
            description = "Title displayed when no matching search results exist",
            currentValue = "No Spaces Found",
            defaultValue = "No Spaces Found",
            fontWeightName = "Bold"
        ),
        AdminElementConfig(
            key = "search_empty_subtitle",
            screenName = "Search",
            elementType = AdminElementType.TEXT,
            displayName = "Search Empty State Subtitle",
            description = "Helpful guidance when 0 search results are returned",
            currentValue = "Try broadening your filters, changing selected city, or resetting price limits.",
            defaultValue = "Try broadening your filters, changing selected city, or resetting price limits."
        ),
        AdminElementConfig(
            key = "search_clear_filters_btn",
            screenName = "Search",
            elementType = AdminElementType.BUTTON,
            displayName = "Clear Filters Button",
            description = "Button CTA to reset all active search filters",
            currentValue = "Clear All Filters",
            defaultValue = "Clear All Filters"
        ),

        // --- 3. VENUE DETAILS SCREEN ---
        AdminElementConfig(
            key = "venue_detail_book_button",
            screenName = "Venue Details",
            elementType = AdminElementType.BUTTON,
            displayName = "Book Court / Slot CTA Button",
            description = "Primary booking button on venue details bottom bar",
            currentValue = "Book Slot Now ⚡",
            defaultValue = "Book Slot Now ⚡",
            fontWeightName = "Bold"
        ),
        AdminElementConfig(
            key = "venue_detail_instant_badge",
            screenName = "Venue Details",
            elementType = AdminElementType.BADGE,
            displayName = "Instant Confirmation Badge",
            description = "Verification badge on verified venue listings",
            currentValue = "⚡ Instant Confirmation",
            defaultValue = "⚡ Instant Confirmation"
        ),
        AdminElementConfig(
            key = "venue_detail_call_owner_btn",
            screenName = "Venue Details",
            elementType = AdminElementType.BUTTON,
            displayName = "Call Owner Button",
            description = "Quick phone call action button",
            currentValue = "Call Owner",
            defaultValue = "Call Owner"
        ),
        AdminElementConfig(
            key = "venue_detail_whatsapp_btn",
            screenName = "Venue Details",
            elementType = AdminElementType.BUTTON,
            displayName = "WhatsApp Inquire Button",
            description = "WhatsApp direct chat action button",
            currentValue = "WhatsApp",
            defaultValue = "WhatsApp"
        ),
        AdminElementConfig(
            key = "venue_detail_amenities_heading",
            screenName = "Venue Details",
            elementType = AdminElementType.TEXT,
            displayName = "Amenities Section Title",
            description = "Header for amenities and features grid",
            currentValue = "Amenities & Facilities",
            defaultValue = "Amenities & Facilities",
            fontWeightName = "Bold"
        ),
        AdminElementConfig(
            key = "venue_detail_policy_heading",
            screenName = "Venue Details",
            elementType = AdminElementType.TEXT,
            displayName = "Cancellation Policy Title",
            description = "Header for booking cancellation policy card",
            currentValue = "Cancellation & Refund Policy",
            defaultValue = "Cancellation & Refund Policy",
            fontWeightName = "Bold"
        ),

        // --- 4. BOOKING & CHECKOUT FLOW ---
        AdminElementConfig(
            key = "booking_coupon_placeholder",
            screenName = "Booking Flow",
            elementType = AdminElementType.EDIT_BOX,
            displayName = "Coupon Code Input Placeholder",
            description = "Placeholder for promo code input box",
            currentValue = "Enter promo or referral code (e.g. BMS20)",
            defaultValue = "Enter promo or referral code (e.g. BMS20)",
            placeholder = "Enter promo or referral code (e.g. BMS20)",
            defaultPlaceholder = "Enter promo or referral code (e.g. BMS20)",
            helperText = "Apply valid voucher to get up to 20% discount",
            defaultHelperText = "Apply valid voucher to get up to 20% discount"
        ),
        AdminElementConfig(
            key = "booking_coupon_apply_btn",
            screenName = "Booking Flow",
            elementType = AdminElementType.BUTTON,
            displayName = "Apply Coupon Button",
            description = "Button CTA to validate and apply promo discount",
            currentValue = "Apply Code",
            defaultValue = "Apply Code"
        ),
        AdminElementConfig(
            key = "booking_confirm_pay_btn",
            screenName = "Booking Flow",
            elementType = AdminElementType.BUTTON,
            displayName = "Confirm & Pay Button",
            description = "Main CTA to finalize booking and initiate payment",
            currentValue = "Proceed to Pay & Confirm",
            defaultValue = "Proceed to Pay & Confirm",
            fontWeightName = "Bold"
        ),
        AdminElementConfig(
            key = "booking_cancellation_disclaimer",
            screenName = "Booking Flow",
            elementType = AdminElementType.TEXT,
            displayName = "Free Cancellation Disclaimer",
            description = "Safety assurance notice displayed on payment summary",
            currentValue = "🛡️ 100% Refund guaranteed if cancelled 2 hours prior to slot time.",
            defaultValue = "🛡️ 100% Refund guaranteed if cancelled 2 hours prior to slot time."
        ),
        AdminElementConfig(
            key = "booking_gst_breakdown_label",
            screenName = "Booking Flow",
            elementType = AdminElementType.TEXT,
            displayName = "GST & Platform Fee Notice",
            description = "Summary breakdown note on invoice card",
            currentValue = "Convenience Fee & Applicable GST (18%) Included",
            defaultValue = "Convenience Fee & Applicable GST (18%) Included"
        ),

        // --- 5. INSTITUTES & CLASSES SCREEN ---
        AdminElementConfig(
            key = "institutes_search_hint",
            screenName = "Institutes & Classes",
            elementType = AdminElementType.EDIT_BOX,
            displayName = "Institutes Search Bar Hint",
            description = "Placeholder for coaching and academy search box",
            currentValue = "Search coaching, batch timings, dance, music, coding...",
            defaultValue = "Search coaching, batch timings, dance, music, coding...",
            placeholder = "Search coaching, batch timings, dance, music, coding...",
            defaultPlaceholder = "Search coaching, batch timings, dance, music, coding..."
        ),
        AdminElementConfig(
            key = "institutes_today_ongoing_title",
            screenName = "Institutes & Classes",
            elementType = AdminElementType.TEXT,
            displayName = "Today's Ongoing Classes Heading",
            description = "Header for live running coaching sessions bar",
            currentValue = "🔴 Ongoing & Live Classes Today",
            defaultValue = "🔴 Ongoing & Live Classes Today",
            fontWeightName = "Bold"
        ),
        AdminElementConfig(
            key = "institutes_one_tap_book_btn",
            screenName = "Institutes & Classes",
            elementType = AdminElementType.BUTTON,
            displayName = "One-Tap Enroll Button",
            description = "Quick enroll CTA on class cards",
            currentValue = "Instant 1-Tap Enroll ⚡",
            defaultValue = "Instant 1-Tap Enroll ⚡"
        ),
        AdminElementConfig(
            key = "institutes_waitlist_alert_btn",
            screenName = "Institutes & Classes",
            elementType = AdminElementType.BUTTON,
            displayName = "Waitlist Alert CTA",
            description = "Button to subscribe to push notification when batch spots open",
            currentValue = "Notify When Spot Opens 🔔",
            defaultValue = "Notify When Spot Opens 🔔"
        ),
        AdminElementConfig(
            key = "institutes_faculty_modal_title",
            screenName = "Institutes & Classes",
            elementType = AdminElementType.TEXT,
            displayName = "Faculty Profile Modal Title",
            description = "Header for faculty credentials & experience popup",
            currentValue = "Faculty Profile & Credentials 🎓",
            defaultValue = "Faculty Profile & Credentials 🎓",
            fontWeightName = "Bold"
        ),

        // --- 6. USER PROFILE & SETTINGS ---
        AdminElementConfig(
            key = "profile_welcome_guest",
            screenName = "Profile",
            elementType = AdminElementType.TEXT,
            displayName = "Profile Guest Greeting",
            description = "Greeting text shown for unauthenticated users",
            currentValue = "Welcome to BookMySpace",
            defaultValue = "Welcome to BookMySpace",
            fontWeightName = "Bold"
        ),
        AdminElementConfig(
            key = "profile_referral_banner_title",
            screenName = "Profile",
            elementType = AdminElementType.BANNER,
            displayName = "Referral Card Heading",
            description = "Title of Refer & Earn promotional widget in Profile",
            currentValue = "🎁 Invite Friends & Earn ₹250 Wallet Credits",
            defaultValue = "🎁 Invite Friends & Earn ₹250 Wallet Credits"
        ),
        AdminElementConfig(
            key = "profile_support_btn_title",
            screenName = "Profile",
            elementType = AdminElementType.TEXT,
            displayName = "Customer Support Menu Title",
            description = "Title for help & support menu item",
            currentValue = "24/7 Customer Support & Help Desk",
            defaultValue = "24/7 Customer Support & Help Desk"
        ),

        // --- 7. LOGIN & AUTHENTICATION SCREEN ---
        AdminElementConfig(
            key = "auth_email_input",
            screenName = "Login & Auth",
            elementType = AdminElementType.EDIT_BOX,
            displayName = "Email Input Field",
            description = "Input box for user email address",
            currentValue = "Enter your email address",
            defaultValue = "Enter your email address",
            placeholder = "name@example.com",
            defaultPlaceholder = "name@example.com",
            helperText = "We will never share your email with third parties",
            defaultHelperText = "We will never share your email with third parties"
        ),
        AdminElementConfig(
            key = "auth_password_input",
            screenName = "Login & Auth",
            elementType = AdminElementType.EDIT_BOX,
            displayName = "Password Input Field",
            description = "Input box for account password",
            currentValue = "Enter password",
            defaultValue = "Enter password",
            placeholder = "••••••••",
            defaultPlaceholder = "••••••••",
            helperText = "Minimum 6 characters with letters and numbers",
            defaultHelperText = "Minimum 6 characters with letters and numbers"
        ),
        AdminElementConfig(
            key = "auth_login_submit_btn",
            screenName = "Login & Auth",
            elementType = AdminElementType.BUTTON,
            displayName = "Login Submit Button",
            description = "Primary sign-in button CTA",
            currentValue = "Sign In Securely",
            defaultValue = "Sign In Securely",
            fontWeightName = "Bold"
        ),
        AdminElementConfig(
            key = "auth_google_signin_btn",
            screenName = "Login & Auth",
            elementType = AdminElementType.BUTTON,
            displayName = "Google Sign-In Button",
            description = "One-tap Google login button text",
            currentValue = "Continue with Google",
            defaultValue = "Continue with Google"
        ),

        // --- 8. GLOBAL APP OBJECTS & PARAMETERS ---
        AdminElementConfig(
            key = "app_tax_rate_percent",
            screenName = "Global App Objects",
            elementType = AdminElementType.OBJECT_JSON,
            displayName = "GST Tax Rate (%)",
            description = "Standard Goods & Services Tax percentage applied on bookings",
            currentValue = "18.0",
            defaultValue = "18.0"
        ),
        AdminElementConfig(
            key = "app_currency_symbol",
            screenName = "Global App Objects",
            elementType = AdminElementType.OBJECT_JSON,
            displayName = "Currency Symbol",
            description = "Display currency symbol across all price tags",
            currentValue = "₹",
            defaultValue = "₹"
        ),
        AdminElementConfig(
            key = "app_support_phone",
            screenName = "Global App Objects",
            elementType = AdminElementType.OBJECT_JSON,
            displayName = "Helpline Phone Number",
            description = "Primary customer support dialer number",
            currentValue = "+91 98765 43210",
            defaultValue = "+91 98765 43210"
        ),
        AdminElementConfig(
            key = "app_support_email",
            screenName = "Global App Objects",
            elementType = AdminElementType.OBJECT_JSON,
            displayName = "Support Email Address",
            description = "Official customer support ticketing email",
            currentValue = "support@bookmyspace.app",
            defaultValue = "support@bookmyspace.app"
        ),
        AdminElementConfig(
            key = "app_platform_fee_inr",
            screenName = "Global App Objects",
            elementType = AdminElementType.OBJECT_JSON,
            displayName = "Platform Convenience Fee (INR)",
            description = "Fixed convenience charge per booking transaction",
            currentValue = "25.00",
            defaultValue = "25.00"
        ),
        AdminElementConfig(
            key = "app_free_cancellation_hours",
            screenName = "Global App Objects",
            elementType = AdminElementType.OBJECT_JSON,
            displayName = "Free Cancellation Window (Hours)",
            description = "Number of hours before slot start time for 100% refund",
            currentValue = "2",
            defaultValue = "2"
        )
    )

    init {
        // Load default catalog map
        val initial = mutableMapOf<String, AdminElementConfig>()
        defaultElementsCatalog.forEach { item ->
            initial[item.key] = item
        }
        _customElements.value = initial
    }

    /**
     * Initializes persistence context from Application / Activity and attaches Firestore live listener.
     */
    fun initialize(context: Context) {
        if (sharedPreferences == null) {
            sharedPreferences = context.applicationContext.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            loadSavedConfigsFromDisk()
        }
        try {
            if (firestoreDb == null) {
                firestoreDb = FirebaseFirestore.getInstance()
            }
            attachFirestoreLiveListener()
        } catch (e: Exception) {
            Log.w(TAG, "DynamicElementManager Firestore init: ${e.message}")
        }
    }

    private fun attachFirestoreLiveListener() {
        val db = firestoreDb ?: return
        try {
            elementsListener?.remove()
            elementsListener = db.collection("dynamic_elements")
                .addSnapshotListener { snapshot, error ->
                    if (error != null) {
                        Log.w(TAG, "Dynamic elements snapshot error: ${error.message}")
                        return@addSnapshotListener
                    }
                    if (snapshot != null && !snapshot.isEmpty) {
                        val cloudMap = mutableMapOf<String, AdminElementConfig>()
                        for (doc in snapshot.documents) {
                            val key = doc.getString("key") ?: doc.id
                            val typeStr = doc.getString("elementType") ?: "TEXT"
                            val type = try { AdminElementType.valueOf(typeStr) } catch (_: Exception) { AdminElementType.TEXT }
                            cloudMap[key] = AdminElementConfig(
                                key = key,
                                screenName = doc.getString("screenName") ?: "Home",
                                elementType = type,
                                displayName = doc.getString("displayName") ?: key,
                                description = doc.getString("description") ?: "",
                                currentValue = doc.getString("currentValue") ?: "",
                                defaultValue = doc.getString("defaultValue") ?: "",
                                placeholder = doc.getString("placeholder"),
                                defaultPlaceholder = doc.getString("defaultPlaceholder"),
                                helperText = doc.getString("helperText"),
                                defaultHelperText = doc.getString("defaultHelperText"),
                                iconName = doc.getString("iconName"),
                                colorHex = doc.getLong("colorHex"),
                                fontSizeSp = doc.getDouble("fontSizeSp")?.toFloat(),
                                fontWeightName = doc.getString("fontWeightName") ?: "Normal",
                                isVisible = doc.getBoolean("isVisible") ?: true,
                                lastModifiedTimestamp = doc.getLong("lastModifiedTimestamp") ?: System.currentTimeMillis()
                            )
                        }
                        if (cloudMap.isNotEmpty()) {
                            applyCloudElements(cloudMap)
                        }
                    }
                }
        } catch (e: Exception) {
            Log.w(TAG, "Could not attach dynamic elements Firestore listener: ${e.message}")
        }
    }

    fun applyCloudElements(cloudMap: Map<String, AdminElementConfig>) {
        val merged = _customElements.value.toMutableMap()
        cloudMap.forEach { (key, elem) ->
            merged[key] = elem
        }
        _customElements.value = merged
        saveConfigsToDisk()
    }

    private fun loadSavedConfigsFromDisk() {
        val prefs = sharedPreferences ?: return
        val rawJson = prefs.getString(KEY_ELEMENTS_JSON, null) ?: return

        try {
            val jsonArray = JSONArray(rawJson)
            val merged = _customElements.value.toMutableMap()
            for (i in 0 until jsonArray.length()) {
                val obj = jsonArray.getJSONObject(i)
                val config = AdminElementConfig.fromJson(obj)
                merged[config.key] = config
            }
            _customElements.value = merged
            Log.d(TAG, "Loaded ${jsonArray.length()} custom element overrides from storage.")
        } catch (e: Exception) {
            Log.e(TAG, "Failed parsing saved custom elements JSON", e)
        }
    }

    private fun saveConfigsToDisk() {
        val prefs = sharedPreferences ?: return
        scope.launch {
            try {
                val array = JSONArray()
                _customElements.value.values.forEach { config ->
                    if (config.isModified || config.isCustom) {
                        array.put(config.toJson())
                    }
                }
                prefs.edit().putString(KEY_ELEMENTS_JSON, array.toString()).apply()
            } catch (e: Exception) {
                Log.e(TAG, "Error saving custom elements to disk", e)
            }
        }
    }

    // -------------------------------------------------------------
    // Live Queries & Getters
    // -------------------------------------------------------------

    /**
     * Gets customized text value for given key or returns fallback default.
     */
    fun getText(key: String, defaultVal: String): String {
        val config = _customElements.value[key]
        return if (config != null && config.isVisible) config.currentValue else defaultVal
    }

    /**
     * Gets placeholder string for given editbox key or returns fallback default.
     */
    fun getPlaceholder(key: String, defaultPlaceholder: String): String {
        val config = _customElements.value[key]
        return if (config != null && config.isVisible && !config.placeholder.isNullOrBlank()) config.placeholder else defaultPlaceholder
    }

    /**
     * Gets helper text string for given editbox key or returns fallback default.
     */
    fun getHelperText(key: String, defaultHelper: String?): String? {
        val config = _customElements.value[key]
        return if (config != null && config.isVisible && !config.helperText.isNullOrBlank()) config.helperText else defaultHelper
    }

    /**
     * Gets element configuration or creates dynamic entry if not yet registered.
     */
    fun getElement(key: String, defaultVal: String = "", screenName: String = "Global", type: AdminElementType = AdminElementType.TEXT): AdminElementConfig {
        return _customElements.value[key] ?: AdminElementConfig(
            key = key,
            screenName = screenName,
            elementType = type,
            displayName = key,
            currentValue = defaultVal,
            defaultValue = defaultVal
        )
    }

    // -------------------------------------------------------------
    // Admin Mutation Methods
    // -------------------------------------------------------------

    /**
     * Updates an element's entire configuration and immediately persists it to disk and Firestore.
     */
    fun updateElement(config: AdminElementConfig) {
        val updated = _customElements.value.toMutableMap()
        val modifiedConfig = config.copy(lastModifiedTimestamp = System.currentTimeMillis())
        updated[config.key] = modifiedConfig
        _customElements.value = updated
        saveConfigsToDisk()

        // Sync to Firestore
        scope.launch {
            try {
                val db = firestoreDb ?: FirebaseFirestore.getInstance().also { firestoreDb = it }
                val docRef = db.collection("dynamic_elements").document(config.key)
                val data = mapOf(
                    "key" to modifiedConfig.key,
                    "screenName" to modifiedConfig.screenName,
                    "elementType" to modifiedConfig.elementType.name,
                    "displayName" to modifiedConfig.displayName,
                    "description" to modifiedConfig.description,
                    "currentValue" to modifiedConfig.currentValue,
                    "defaultValue" to modifiedConfig.defaultValue,
                    "placeholder" to modifiedConfig.placeholder,
                    "defaultPlaceholder" to modifiedConfig.defaultPlaceholder,
                    "colorHex" to modifiedConfig.colorHex,
                    "fontSizeSp" to modifiedConfig.fontSizeSp,
                    "fontWeightName" to modifiedConfig.fontWeightName,
                    "isVisible" to modifiedConfig.isVisible,
                    "updatedAt" to System.currentTimeMillis()
                )
                docRef.set(data, SetOptions.merge())
            } catch (e: Exception) {
                Log.w(TAG, "Failed to sync dynamic element to Firestore: ${e.message}")
            }
        }
    }

    /**
     * Updates an element's text / current value.
     */
    fun updateElementText(key: String, newText: String) {
        val current = _customElements.value[key]
        if (current != null) {
            updateElement(current.copy(currentValue = newText))
        } else {
            val dynamic = AdminElementConfig(
                key = key,
                screenName = "Global",
                elementType = AdminElementType.TEXT,
                displayName = key,
                currentValue = newText,
                defaultValue = newText,
                isCustom = true
            )
            updateElement(dynamic)
        }
    }

    /**
     * Updates editbox placeholder, label and helper text.
     */
    fun updateEditBox(key: String, placeholder: String, helperText: String? = null) {
        val current = _customElements.value[key]
        if (current != null) {
            updateElement(current.copy(placeholder = placeholder, helperText = helperText))
        } else {
            val dynamic = AdminElementConfig(
                key = key,
                screenName = "Global",
                elementType = AdminElementType.EDIT_BOX,
                displayName = key,
                currentValue = placeholder,
                defaultValue = placeholder,
                placeholder = placeholder,
                defaultPlaceholder = placeholder,
                helperText = helperText,
                defaultHelperText = helperText,
                isCustom = true
            )
            updateElement(dynamic)
        }
    }

    /**
     * Reverts a single element back to its factory default value.
     */
    fun resetElement(key: String) {
        val default = defaultElementsCatalog.find { it.key == key }
        val updated = _customElements.value.toMutableMap()
        if (default != null) {
            updated[key] = default
        } else {
            updated.remove(key)
        }
        _customElements.value = updated
        saveConfigsToDisk()
    }

    /**
     * Resets all elements across the entire app back to factory defaults.
     */
    fun resetAllToDefaults() {
        val initial = mutableMapOf<String, AdminElementConfig>()
        defaultElementsCatalog.forEach { item ->
            initial[item.key] = item
        }
        _customElements.value = initial
        saveConfigsToDisk()
    }

    // -------------------------------------------------------------
    // Visual Edit Mode Controls
    // -------------------------------------------------------------

    fun toggleVisualEditMode() {
        _isVisualEditModeActive.value = !_isVisualEditModeActive.value
    }

    fun setVisualEditMode(active: Boolean) {
        _isVisualEditModeActive.value = active
    }

    fun openInspectorForElement(config: AdminElementConfig) {
        _inspectedElement.value = config
    }

    fun closeInspector() {
        _inspectedElement.value = null
    }

    // -------------------------------------------------------------
    // JSON Import & Export
    // -------------------------------------------------------------

    fun exportToJson(): String {
        val array = JSONArray()
        _customElements.value.values.forEach { config ->
            array.put(config.toJson())
        }
        return array.toString(2)
    }

    fun importFromJson(jsonString: String): Result<Int> {
        return try {
            val array = JSONArray(jsonString)
            val updated = _customElements.value.toMutableMap()
            var count = 0
            for (i in 0 until array.length()) {
                val obj = array.getJSONObject(i)
                val config = AdminElementConfig.fromJson(obj)
                updated[config.key] = config
                count++
            }
            _customElements.value = updated
            saveConfigsToDisk()
            Result.success(count)
        } catch (e: Exception) {
            Log.e(TAG, "Import error: ${e.message}", e)
            Result.failure(e)
        }
    }
}
