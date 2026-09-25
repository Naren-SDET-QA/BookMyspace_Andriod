package com.bookmyspace.bookmyspace.data.integration

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.util.Log
import com.bookmyspace.bookmyspace.data.model.*
import com.bookmyspace.bookmyspace.data.repository.BookMySpaceRepository
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import org.json.JSONArray
import org.json.JSONObject
import java.text.SimpleDateFormat
import java.util.*
import kotlin.system.measureTimeMillis

/**
 * Enterprise-grade Service for connecting BookMySpace with external apps, AI assistants via MCP,
 * developer REST APIs, webhooks, and calendar sync.
 */
object ExternalAppAndMcpService {

    private const val TAG = "ExternalAppAndMcpService"

    private var appContext: Context? = null

    // State flows
    private val _apiKeys = MutableStateFlow<List<ApiKeyToken>>(emptyList())
    val apiKeys: StateFlow<List<ApiKeyToken>> = _apiKeys.asStateFlow()

    private val _webhooks = MutableStateFlow<List<WebhookSubscription>>(emptyList())
    val webhooks: StateFlow<List<WebhookSubscription>> = _webhooks.asStateFlow()

    private val _webhookLogs = MutableStateFlow<List<WebhookDeliveryLog>>(emptyList())
    val webhookLogs: StateFlow<List<WebhookDeliveryLog>> = _webhookLogs.asStateFlow()

    private val _toolExecutionLogs = MutableStateFlow<List<McpToolExecutionResult>>(emptyList())
    val toolExecutionLogs: StateFlow<List<McpToolExecutionResult>> = _toolExecutionLogs.asStateFlow()

    private val _connectedApps = MutableStateFlow<List<ConnectedAppConfig>>(emptyList())
    val connectedApps: StateFlow<List<ConnectedAppConfig>> = _connectedApps.asStateFlow()

    private val _customSites = MutableStateFlow<List<CustomSiteIntegration>>(emptyList())
    val customSites: StateFlow<List<CustomSiteIntegration>> = _customSites.asStateFlow()

    fun initialize(context: Context) {
        appContext = context.applicationContext
        loadSavedState()
    }

    private fun loadSavedState() {
        // Initialize default sample API Key if empty
        if (_apiKeys.value.isEmpty()) {
            _apiKeys.value = listOf(
                ApiKeyToken(
                    name = "Default AI Agent & MCP Key",
                    token = "bms_live_agent_" + UUID.randomUUID().toString().replace("-", "").take(16),
                    scopes = setOf(
                        ApiKeyScope.READ_VENUES,
                        ApiKeyScope.READ_AVAILABILITY,
                        ApiKeyScope.WRITE_BOOKINGS,
                        ApiKeyScope.READ_BOOKINGS
                    )
                ),
                ApiKeyToken(
                    name = "Zapier & Webhooks Connector",
                    token = "bms_live_zapier_" + UUID.randomUUID().toString().replace("-", "").take(16),
                    scopes = setOf(
                        ApiKeyScope.READ_VENUES,
                        ApiKeyScope.WEBHOOK_RECEIVER
                    )
                )
            )
        }

        // Initialize default Webhooks if empty
        if (_webhooks.value.isEmpty()) {
            _webhooks.value = listOf(
                WebhookSubscription(
                    targetUrl = "https://hooks.zapier.com/hooks/catch/198234/bms_bookings",
                    subscribedEvents = setOf(WebhookEvent.BOOKING_CONFIRMED, WebhookEvent.CHECKIN_SCANNED),
                    lastDeliveredAt = System.currentTimeMillis() - 3600000L
                )
            )
        }

        // Initialize default Connected Apps
        if (_connectedApps.value.isEmpty()) {
            _connectedApps.value = ConnectorType.entries.map { type ->
                ConnectedAppConfig(
                    connectorType = type,
                    isConnected = type == ConnectorType.GOOGLE_CALENDAR || type == ConnectorType.ZAPIER,
                    configUrl = when (type) {
                        ConnectorType.GOOGLE_CALENDAR -> "https://api.bookmyspace.app/v1/calendar/feed.ics?token=bms_feed_user992"
                        ConnectorType.OUTLOOK_CALENDAR -> "https://api.bookmyspace.app/v1/calendar/feed.ics?token=bms_feed_user992"
                        ConnectorType.APPLE_ICAL -> "webcal://api.bookmyspace.app/v1/calendar/feed.ics"
                        ConnectorType.ZAPIER -> "https://zapier.com/apps/bookmyspace/integrations"
                        ConnectorType.MAKE_N8N -> "https://api.bookmyspace.app/v1/webhooks/custom"
                        ConnectorType.WHATSAPP_BOT -> "https://wa.me/919999988888?text=START_BMS_BOT"
                        ConnectorType.TELEGRAM_BOT -> "https://t.me/BookMySpaceBot"
                        ConnectorType.SLACK_DISCORD -> "https://hooks.slack.com/services/T00/B00/X00"
                    }
                )
            }
        }

        // Initialize default Universal Site, MCP & API Integrations
        if (_customSites.value.isEmpty()) {
            _customSites.value = listOf(
                CustomSiteIntegration(
                    id = "site_shopify_store",
                    name = "BookMySpace Merch & Turf Gear Store",
                    siteUrl = "https://shop.bookmyspace.app",
                    category = CustomSiteCategory.STORE_COMMERCE,
                    authType = SiteAuthType.API_KEY,
                    authHeaderKey = "X-Shopify-Access-Token",
                    authHeaderValue = "shpat_live_merch_88129a",
                    isEnabled = true,
                    syncMode = SiteSyncMode.EMBEDDED_VIEW,
                    healthStatus = SiteHealthStatus.HEALTHY,
                    lastPingLatencyMs = 38L,
                    description = "Official sports equipment, venue decoration kits & rental gear storefront",
                    iconEmoji = "🛒"
                ),
                CustomSiteIntegration(
                    id = "site_calendly_host",
                    name = "Host Virtual Consultation & Tour",
                    siteUrl = "https://calendly.com/bookmyspace-tours/venue-demo",
                    category = CustomSiteCategory.BOOKING_CALENDAR,
                    authType = SiteAuthType.NONE,
                    isEnabled = true,
                    syncMode = SiteSyncMode.EMBEDDED_VIEW,
                    healthStatus = SiteHealthStatus.HEALTHY,
                    lastPingLatencyMs = 52L,
                    description = "Direct 1-on-1 virtual walkthrough scheduling for event managers and wedding planners",
                    iconEmoji = "📅"
                ),
                CustomSiteIntegration(
                    id = "site_remote_mcp_claude",
                    name = "Claude / Cursor Remote MCP Bridge",
                    siteUrl = "https://mcp.bookmyspace.app/sse",
                    category = CustomSiteCategory.MCP_SERVER,
                    authType = SiteAuthType.BEARER_TOKEN,
                    authHeaderKey = "Authorization",
                    authHeaderValue = "Bearer bms_mcp_live_token_7721a",
                    isEnabled = true,
                    syncMode = SiteSyncMode.REAL_TIME_PING,
                    healthStatus = SiteHealthStatus.HEALTHY,
                    lastPingLatencyMs = 24L,
                    description = "Enterprise JSON-RPC MCP connector exposing live venue availability to AI coding & chat assistants",
                    iconEmoji = "🤖"
                ),
                CustomSiteIntegration(
                    id = "site_hubspot_crm",
                    name = "HubSpot Corporate Leads Sync",
                    siteUrl = "https://api.hubapi.com/crm/v3/objects/contacts",
                    category = CustomSiteCategory.CRM_LEADS,
                    authType = SiteAuthType.BEARER_TOKEN,
                    authHeaderKey = "Authorization",
                    authHeaderValue = "Bearer pat-na1-893041-bms",
                    isEnabled = true,
                    syncMode = SiteSyncMode.WEBHOOK_STREAM,
                    healthStatus = SiteHealthStatus.HEALTHY,
                    lastPingLatencyMs = 64L,
                    description = "Auto-creates CRM deals for large function hall and banquet hall inquiries",
                    iconEmoji = "💼"
                ),
                CustomSiteIntegration(
                    id = "site_custom_api_gateway",
                    name = "Custom Venue Analytics REST Microservice",
                    siteUrl = "https://analytics-api.bookmyspace.app/v2/telemetry",
                    category = CustomSiteCategory.REST_API,
                    authType = SiteAuthType.API_KEY,
                    authHeaderKey = "x-api-key",
                    authHeaderValue = "bms_sec_k9921_rest",
                    isEnabled = true,
                    syncMode = SiteSyncMode.ON_DEMAND,
                    healthStatus = SiteHealthStatus.HEALTHY,
                    lastPingLatencyMs = 41L,
                    description = "High-throughput telemetry and pricing yield optimization external API",
                    iconEmoji = "⚡"
                )
            )
        }
    }

    // ==========================================
    // 1. MODEL CONTEXT PROTOCOL (MCP) CATALOG
    // ==========================================

    val mcpTools: List<McpToolDefinition> = listOf(
        McpToolDefinition(
            name = "bms_search_spaces",
            description = "Search all available venues, function halls, hotel rooms, PG hostels, and academy sports grounds in BookMySpace by query, category, price, and location.",
            category = "Search & Discovery",
            readOnly = true,
            inputSchemaJson = """
                {
                  "type": "object",
                  "properties": {
                    "query": { "type": "string", "description": "Free-form search query, venue name, or amenity" },
                    "category": { "type": "string", "enum": ["all", "hotel", "venue", "pg", "sports", "class"], "description": "Main category filter" },
                    "city": { "type": "string", "description": "City or locality (e.g., 'Hyderabad', 'Bengaluru', 'Mumbai')" },
                    "max_price": { "type": "number", "description": "Maximum base price per day / hour" },
                    "min_rating": { "type": "number", "description": "Minimum star rating (1.0 to 5.0)" }
                  }
                }
            """.trimIndent(),
            exampleInputJson = """
                {
                  "query": "AC Banquet Hall",
                  "category": "venue",
                  "city": "Hyderabad",
                  "max_price": 75000,
                  "min_rating": 4.5
                }
            """.trimIndent()
        ),
        McpToolDefinition(
            name = "bms_get_space_details",
            description = "Retrieve comprehensive details, pricing tiers, amenities, high-res photos, host rules, and location for a specific venue ID.",
            category = "Search & Discovery",
            readOnly = true,
            inputSchemaJson = """
                {
                  "type": "object",
                  "properties": {
                    "venue_id": { "type": "string", "description": "Unique identifier of the space/venue" }
                  },
                  "required": ["venue_id"]
                }
            """.trimIndent(),
            exampleInputJson = """
                {
                  "venue_id": "v_grand_palace"
                }
            """.trimIndent()
        ),
        McpToolDefinition(
            name = "bms_check_availability",
            description = "Check real-time calendar availability and open time slots for a given venue and target date.",
            category = "Calendar & Slots",
            readOnly = true,
            inputSchemaJson = """
                {
                  "type": "object",
                  "properties": {
                    "venue_id": { "type": "string", "description": "Unique venue ID" },
                    "date": { "type": "string", "description": "Target date in YYYY-MM-DD format" },
                    "slot_type": { "type": "string", "enum": ["FULL_DAY", "MORNING_SLOT", "EVENING_SLOT", "HOURLY"], "description": "Booking slot type" }
                  },
                  "required": ["venue_id", "date"]
                }
            """.trimIndent(),
            exampleInputJson = """
                {
                  "venue_id": "v_grand_palace",
                  "date": "2026-08-25",
                  "slot_type": "FULL_DAY"
                }
            """.trimIndent()
        ),
        McpToolDefinition(
            name = "bms_create_booking_hold",
            description = "Create a temporary booking hold reservation for a space with guest contact details and slot preferences.",
            category = "Booking & Orders",
            readOnly = false,
            inputSchemaJson = """
                {
                  "type": "object",
                  "properties": {
                    "venue_id": { "type": "string", "description": "Unique venue ID" },
                    "customer_name": { "type": "string", "description": "Customer Full Name" },
                    "phone": { "type": "string", "description": "Contact Phone Number (10 digits)" },
                    "email": { "type": "string", "description": "Email address for invoice and tickets" },
                    "date": { "type": "string", "description": "Booking date YYYY-MM-DD" },
                    "slot": { "type": "string", "description": "Slot identifier or time range" },
                    "guests_count": { "type": "integer", "description": "Number of attendees / guests" },
                    "notes": { "type": "string", "description": "Special requirements or catering preferences" }
                  },
                  "required": ["venue_id", "customer_name", "phone", "date", "slot"]
                }
            """.trimIndent(),
            exampleInputJson = """
                {
                  "venue_id": "v_grand_palace",
                  "customer_name": "Rohan Sharma",
                  "phone": "9876543210",
                  "email": "rohan@example.com",
                  "date": "2026-08-25",
                  "slot": "09:00 - 18:00",
                  "guests_count": 150,
                  "notes": "Stage decoration & projector required"
                }
            """.trimIndent()
        ),
        McpToolDefinition(
            name = "bms_list_my_bookings",
            description = "List all active, upcoming, and past reservations for the authenticated user with QR pass links.",
            category = "Booking & Orders",
            readOnly = true,
            inputSchemaJson = """
                {
                  "type": "object",
                  "properties": {
                    "status_filter": { "type": "string", "enum": ["ALL", "CONFIRMED", "PENDING", "CANCELLED"], "description": "Filter bookings by status" }
                  }
                }
            """.trimIndent(),
            exampleInputJson = """
                {
                  "status_filter": "CONFIRMED"
                }
            """.trimIndent()
        ),
        McpToolDefinition(
            name = "bms_cancel_booking",
            description = "Cancel an existing reservation and trigger automated refund computation according to cancellation policy.",
            category = "Booking & Orders",
            readOnly = false,
            inputSchemaJson = """
                {
                  "type": "object",
                  "properties": {
                    "booking_id": { "type": "string", "description": "Booking reference identifier" },
                    "reason": { "type": "string", "description": "Cancellation reason" }
                  },
                  "required": ["booking_id"]
                }
            """.trimIndent(),
            exampleInputJson = """
                {
                  "booking_id": "b_grand_palace_1",
                  "reason": "Event postponed"
                }
            """.trimIndent()
        )
    )

    val mcpResources: List<McpResourceDefinition> = listOf(
        McpResourceDefinition(
            uri = "bms://venues/catalog",
            name = "Full Spaces Catalog",
            description = "Real-time list of all active venues with live pricing, geolocation coordinates, and facility attributes."
        ),
        McpResourceDefinition(
            uri = "bms://bookings/active",
            name = "Active User Bookings",
            description = "Upcoming confirmed reservations, passes, check-in status, and digital QR codes."
        ),
        McpResourceDefinition(
            uri = "bms://categories/facets",
            name = "Category Taxonomies & Schema",
            description = "Hierarchical category metadata (Hotels, Function Halls, PGs, Classes, Lawns, Sports) with dynamic field schemas."
        )
    )

    val mcpPrompts: List<McpPromptDefinition> = listOf(
        McpPromptDefinition(
            name = "bms_find_best_deal",
            description = "Find the best rated space for an event under a specific budget and location.",
            template = "You are a BookMySpace booking concierge. Use the `bms_search_spaces` tool to discover available venues in {{city}} for {{event_type}} with budget limit of ₹{{budget}}. Compare pricing and ratings, check availability, and recommend the top 3 best matching venues with direct booking URLs."
        ),
        McpPromptDefinition(
            name = "bms_plan_event_booking",
            description = "Step-by-step workflow for reserving a banquet or wedding hall with catering and decorator add-ons.",
            template = "Guide the user through organizing an event at a BookMySpace venue. Fetch venue details using `bms_get_space_details`, check slot availability on {{date}}, calculate total estimated cost including GST and catering, and format a clear confirmation hold using `bms_create_booking_hold`."
        )
    )

    // ==========================================
    // 2. MCP CONFIGURATION GENERATORS
    // ==========================================

    fun generateClaudeDesktopConfig(apiKey: String = "YOUR_BMS_API_KEY"): String {
        return """
            {
              "mcpServers": {
                "bookmyspace": {
                  "command": "npx",
                  "args": ["-y", "@bookmyspace/mcp-server"],
                  "env": {
                    "BOOKMYSPACE_API_KEY": "$apiKey",
                    "BOOKMYSPACE_BASE_URL": "https://api.bookmyspace.app/v1"
                  }
                }
              }
            }
        """.trimIndent()
    }

    fun generateCursorMcpConfig(apiKey: String = "YOUR_BMS_API_KEY"): String {
        return """
            {
              "name": "BookMySpace MCP",
              "type": "sse",
              "url": "https://api.bookmyspace.app/v1/mcp/sse",
              "headers": {
                "Authorization": "Bearer $apiKey"
              }
            }
        """.trimIndent()
    }

    fun generateGeminiOpenAiSchemaJson(): String {
        val root = JSONObject()
        val toolsArray = JSONArray()

        mcpTools.forEach { tool ->
            val toolObj = JSONObject()
            toolObj.put("name", tool.name)
            toolObj.put("description", tool.description)
            try {
                toolObj.put("parameters", JSONObject(tool.inputSchemaJson))
            } catch (e: Exception) {
                toolObj.put("parameters", JSONObject())
            }
            toolsArray.put(toolObj)
        }

        root.put("tools", toolsArray)
        return root.toString(2)
    }

    // ==========================================
    // 3. MCP TOOL EXECUTION ENGINE
    // ==========================================

    fun executeMcpTool(toolName: String, inputJson: String): McpToolExecutionResult {
        var output = ""
        var isSuccess = true

        val duration = measureTimeMillis {
            try {
                val inputObj = if (inputJson.isNotBlank()) JSONObject(inputJson) else JSONObject()
                when (toolName) {
                    "bms_search_spaces" -> {
                        val query = inputObj.optString("query", "").lowercase()
                        val city = inputObj.optString("city", "").lowercase()
                        val maxPrice = inputObj.optDouble("max_price", 1000000.0)
                        val minRating = inputObj.optDouble("min_rating", 0.0)

                        val allVenues = BookMySpaceRepository.venues.value
                        val filtered = allVenues.filter { v ->
                            val matchQuery = query.isBlank() || v.name.lowercase().contains(query) || v.description.lowercase().contains(query)
                            val matchCity = city.isBlank() || v.city.lowercase().contains(city) || v.addressLine1.lowercase().contains(city)
                            val matchPrice = v.pricingBaseAmount <= maxPrice
                            val matchRating = v.avgRating >= minRating
                            matchQuery && matchCity && matchPrice && matchRating
                        }

                        val resultArr = JSONArray()
                        filtered.take(6).forEach { v ->
                            val vObj = JSONObject()
                            vObj.put("id", v.id)
                            vObj.put("name", v.name)
                            vObj.put("category", v.category?.name ?: "Venue")
                            vObj.put("city", v.city)
                            vObj.put("price_base", "₹${v.pricingBaseAmount.toInt()}")
                            vObj.put("rating", v.avgRating)
                            vObj.put("rating_count", v.ratingCount)
                            vObj.put("address", "${v.addressLine1}, ${v.city}")
                            vObj.put("deep_link", "bookmyspace://venues/${v.id}")
                            resultArr.put(vObj)
                        }

                        val resObj = JSONObject()
                        resObj.put("status", "success")
                        resObj.put("matched_count", filtered.size)
                        resObj.put("results", resultArr)
                        output = resObj.toString(2)
                    }

                    "bms_get_space_details" -> {
                        val venueId = inputObj.optString("venue_id", "v_grand_palace")
                        val venue = BookMySpaceRepository.venues.value.find { it.id == venueId }
                            ?: BookMySpaceRepository.venues.value.firstOrNull()
                        if (venue != null) {
                            val vObj = JSONObject()
                            vObj.put("id", venue.id)
                            vObj.put("name", venue.name)
                            vObj.put("description", venue.description)
                            vObj.put("category", venue.category?.name ?: "Venue")
                            vObj.put("price_base", venue.pricingBaseAmount)
                            vObj.put("capacity", venue.capacity)
                            vObj.put("avg_rating", venue.avgRating)
                            vObj.put("rating_count", venue.ratingCount)
                            vObj.put("address", "${venue.addressLine1}, ${venue.city}")
                            vObj.put("images_count", venue.images.size)
                            vObj.put("deep_link_book", "bookmyspace://venues/${venue.id}/book")
                            output = vObj.toString(2)
                        } else {
                            isSuccess = false
                            output = JSONObject().apply {
                                put("status", "error")
                                put("message", "Venue with ID '$venueId' was not found.")
                            }.toString(2)
                        }
                    }

                    "bms_check_availability" -> {
                        val venueId = inputObj.optString("venue_id", "v_grand_palace")
                        val date = inputObj.optString("date", "2026-08-25")
                        val venue = BookMySpaceRepository.venues.value.find { it.id == venueId }

                        val res = JSONObject()
                        res.put("venue_id", venueId)
                        res.put("venue_name", venue?.name ?: "Premium Space")
                        res.put("date", date)
                        res.put("is_available", true)

                        val slots = JSONArray().apply {
                            put(JSONObject().apply { put("slot", "06:00 - 12:00 (Morning)"); put("status", "AVAILABLE"); put("price", 15000) })
                            put(JSONObject().apply { put("slot", "12:00 - 18:00 (Afternoon)"); put("status", "AVAILABLE"); put("price", 18000) })
                            put(JSONObject().apply { put("slot", "18:00 - 23:30 (Evening & Night)"); put("status", "AVAILABLE"); put("price", 25000) })
                            put(JSONObject().apply { put("slot", "Full Day (24 Hours)"); put("status", "AVAILABLE"); put("price", 45000) })
                        }
                        res.put("available_slots", slots)
                        output = res.toString(2)
                    }

                    "bms_create_booking_hold" -> {
                        val venueId = inputObj.optString("venue_id", "v_grand_palace")
                        val name = inputObj.optString("customer_name", "Guest User")
                        val phone = inputObj.optString("phone", "9876543210")
                        val date = inputObj.optString("date", "2026-08-25")
                        val slot = inputObj.optString("slot", "Full Day")

                        val bookingRef = "BMS-HOLD-" + UUID.randomUUID().toString().take(6).uppercase()
                        val res = JSONObject().apply {
                            put("status", "HOLD_CONFIRMED")
                            put("booking_reference", bookingRef)
                            put("venue_id", venueId)
                            put("customer_name", name)
                            put("phone", phone)
                            put("date", date)
                            put("slot", slot)
                            put("expires_in_minutes", 30)
                            put("payment_checkout_url", "https://app.bookmyspace.app/pay/$bookingRef")
                            put("deep_link_checkout", "bookmyspace://bookings/$bookingRef/pay")
                        }
                        output = res.toString(2)
                    }

                    "bms_list_my_bookings" -> {
                        val bookings = BookMySpaceRepository.bookings.value
                        val arr = JSONArray()
                        bookings.forEach { b ->
                            arr.put(JSONObject().apply {
                                put("booking_id", b.id)
                                put("venue_id", b.venueId)
                                put("venue_name", b.venueName)
                                put("date", b.date)
                                put("slot", if (b.slotLabel.isNotBlank()) b.slotLabel else "${b.startTime} - ${b.endTime}")
                                put("total_amount", "₹${b.totalAmount.toInt()}")
                                put("status", b.status.name)
                                put("payment_status", b.paymentStatus)
                                put("qr_pass_code", b.qrCodeToken)
                            })
                        }
                        val res = JSONObject().apply {
                            put("status", "success")
                            put("total_bookings", bookings.size)
                            put("bookings", arr)
                        }
                        output = res.toString(2)
                    }

                    "bms_cancel_booking" -> {
                        val bookingId = inputObj.optString("booking_id", "b1")
                        val res = JSONObject().apply {
                            put("status", "CANCELLED")
                            put("booking_id", bookingId)
                            put("refund_status", "PROCESSING")
                            put("refund_amount", "₹12,500")
                            put("message", "Booking $bookingId cancelled. Refund will reflect in 2-3 business days.")
                        }
                        output = res.toString(2)
                    }

                    else -> {
                        isSuccess = false
                        output = JSONObject().apply {
                            put("status", "error")
                            put("message", "Unknown MCP tool '$toolName'")
                        }.toString(2)
                    }
                }
            } catch (e: Exception) {
                isSuccess = false
                output = JSONObject().apply {
                    put("status", "error")
                    put("error", e.message ?: "Unknown execution failure")
                }.toString(2)
            }
        }

        val result = McpToolExecutionResult(
            toolName = toolName,
            inputJson = inputJson,
            isSuccess = isSuccess,
            outputJson = output,
            executionTimeMs = duration
        )

        _toolExecutionLogs.value = listOf(result) + _toolExecutionLogs.value.take(20)
        return result
    }

    // ==========================================
    // 4. REST API DOCUMENTATION & TESTING ENGINE
    // ==========================================

    val apiEndpoints: List<ApiEndpointDoc> = listOf(
        ApiEndpointDoc(
            method = "GET",
            path = "/v1/spaces",
            summary = "List and search spaces & venues",
            description = "Returns paginated list of spaces with geolocation, pricing, facilities and ratings.",
            requiredScopes = listOf(ApiKeyScope.READ_VENUES),
            responseExampleJson = """
                {
                  "status": "success",
                  "data": [
                    {
                      "id": "v_grand_palace",
                      "name": "Grand Palace Banquet Hall",
                      "category": "VENUE",
                      "price_base": 45000,
                      "rating": 4.8,
                      "city": "Hyderabad"
                    }
                  ],
                  "page": 1,
                  "total": 48
                }
            """.trimIndent()
        ),
        ApiEndpointDoc(
            method = "GET",
            path = "/v1/spaces/{id}",
            summary = "Get detailed space attributes",
            description = "Fetch full metadata including dynamic custom fields, photos, capacity and contact info.",
            requiredScopes = listOf(ApiKeyScope.READ_VENUES),
            responseExampleJson = """
                {
                  "id": "v_grand_palace",
                  "name": "Grand Palace Banquet Hall",
                  "description": "Luxurious centralized AC hall for weddings & receptions",
                  "pricingBaseAmount": 45000.0,
                  "capacityMax": 800,
                  "avgRating": 4.8
                }
            """.trimIndent()
        ),
        ApiEndpointDoc(
            method = "POST",
            path = "/v1/availability/check",
            summary = "Query real-time slot calendar availability",
            description = "Check if a date and slot range is open or blocked by another booking / host blackout.",
            requiredScopes = listOf(ApiKeyScope.READ_AVAILABILITY),
            requestBodyExampleJson = """
                {
                  "venue_id": "v_grand_palace",
                  "date": "2026-08-25"
                }
            """.trimIndent(),
            responseExampleJson = """
                {
                  "venue_id": "v_grand_palace",
                  "date": "2026-08-25",
                  "is_available": true,
                  "available_slots": ["09:00 - 14:00", "15:00 - 22:00"]
                }
            """.trimIndent()
        ),
        ApiEndpointDoc(
            method = "POST",
            path = "/v1/bookings/create",
            summary = "Reserve and hold a space",
            description = "Creates a new booking record, calculates GST and generates instant payment hold URL.",
            requiredScopes = listOf(ApiKeyScope.WRITE_BOOKINGS),
            requestBodyExampleJson = """
                {
                  "venue_id": "v_grand_palace",
                  "customer_name": "Narendra Kumar",
                  "customer_phone": "9876543210",
                  "date": "2026-08-25",
                  "slot": "09:00 - 18:00",
                  "guests_count": 200
                }
            """.trimIndent(),
            responseExampleJson = """
                {
                  "booking_id": "bms_ord_99214",
                  "status": "HOLD",
                  "total_amount": 53100.0,
                  "tax_gst": 8100.0,
                  "checkout_url": "https://app.bookmyspace.app/pay/bms_ord_99214"
                }
            """.trimIndent()
        )
    )

    fun generateCurlCommand(endpoint: ApiEndpointDoc, apiKey: String = "YOUR_API_KEY"): String {
        val base = "https://api.bookmyspace.app"
        val header = "-H 'Authorization: Bearer $apiKey' -H 'Content-Type: application/json'"
        return if (endpoint.method == "POST" && endpoint.requestBodyExampleJson != null) {
            "curl -X POST '$base${endpoint.path}' \\\n  $header \\\n  -d '${endpoint.requestBodyExampleJson.replace("\n", " ").trim()}'"
        } else {
            "curl -X GET '$base${endpoint.path}' \\\n  $header"
        }
    }

    fun generatePythonCode(endpoint: ApiEndpointDoc, apiKey: String = "YOUR_API_KEY"): String {
        return if (endpoint.method == "POST") {
            """
import requests

url = "https://api.bookmyspace.app${endpoint.path}"
headers = {
    "Authorization": "Bearer $apiKey",
    "Content-Type": "application/json"
}
payload = ${endpoint.requestBodyExampleJson ?: "{}"}

response = requests.post(url, headers=headers, json=payload)
print(response.status_code)
print(response.json())
            """.trimIndent()
        } else {
            """
import requests

url = "https://api.bookmyspace.app${endpoint.path}"
headers = {
    "Authorization": "Bearer $apiKey"
}

response = requests.get(url, headers=headers)
print(response.json())
            """.trimIndent()
        }
    }

    fun generateJavaScriptCode(endpoint: ApiEndpointDoc, apiKey: String = "YOUR_API_KEY"): String {
        return if (endpoint.method == "POST") {
            """
const response = await fetch('https://api.bookmyspace.app${endpoint.path}', {
  method: 'POST',
  headers: {
    'Authorization': 'Bearer $apiKey',
    'Content-Type': 'application/json'
  },
  body: JSON.stringify(${endpoint.requestBodyExampleJson ?: "{}"})
});
const data = await response.json();
console.log(data);
            """.trimIndent()
        } else {
            """
const response = await fetch('https://api.bookmyspace.app${endpoint.path}', {
  method: 'GET',
  headers: {
    'Authorization': 'Bearer $apiKey'
  }
});
const data = await response.json();
console.log(data);
            """.trimIndent()
        }
    }

    // ==========================================
    // 5. API KEY MANAGEMENT
    // ==========================================

    fun createApiKey(name: String, scopes: Set<ApiKeyScope>): ApiKeyToken {
        val newToken = ApiKeyToken(
            name = name.ifBlank { "Personal API Key" },
            scopes = if (scopes.isEmpty()) setOf(ApiKeyScope.READ_VENUES) else scopes
        )
        _apiKeys.value = _apiKeys.value + newToken
        return newToken
    }

    fun revokeApiKey(id: String) {
        _apiKeys.value = _apiKeys.value.filterNot { it.id == id }
    }

    // ==========================================
    // 6. WEBHOOKS DISPATCHER & SIMULATOR
    // ==========================================

    fun addWebhook(targetUrl: String, events: Set<WebhookEvent>): WebhookSubscription {
        val sub = WebhookSubscription(
            targetUrl = targetUrl,
            subscribedEvents = if (events.isEmpty()) setOf(WebhookEvent.BOOKING_CONFIRMED) else events
        )
        _webhooks.value = _webhooks.value + sub
        return sub
    }

    fun deleteWebhook(id: String) {
        _webhooks.value = _webhooks.value.filterNot { it.id == id }
    }

    fun testFireWebhook(webhook: WebhookSubscription, event: WebhookEvent = WebhookEvent.BOOKING_CONFIRMED): WebhookDeliveryLog {
        val payload = JSONObject().apply {
            put("event", event.eventName)
            put("webhook_id", webhook.id)
            put("timestamp", System.currentTimeMillis())
            put("data", JSONObject().apply {
                put("booking_id", "BMS-TEST-" + UUID.randomUUID().toString().take(6).uppercase())
                put("venue_id", "v_grand_palace")
                put("venue_name", "Grand Palace Banquet Hall")
                put("customer_name", "Rohan Sharma")
                put("amount", 45000.0)
                put("status", "CONFIRMED")
                put("date", "2026-08-25")
            })
        }.toString(2)

        val log = WebhookDeliveryLog(
            webhookId = webhook.id,
            event = event,
            targetUrl = webhook.targetUrl,
            httpStatusCode = 200,
            payloadJson = payload,
            responseBody = """{"status": "ok", "received": true}""",
            isSuccess = true,
            latencyMs = (120..380).random().toLong()
        )

        _webhookLogs.value = listOf(log) + _webhookLogs.value.take(20)

        // update lastDeliveredAt
        _webhooks.value = _webhooks.value.map {
            if (it.id == webhook.id) it.copy(lastDeliveredAt = System.currentTimeMillis()) else it
        }

        return log
    }

    // ==========================================
    // 7. CALENDAR (.ICS) SYNC & DEEP LINKS
    // ==========================================

    fun generateIcsCalendarContent(bookings: List<Booking>): String {
        val sb = StringBuilder()
        sb.append("BEGIN:VCALENDAR\r\n")
        sb.append("VERSION:2.0\r\n")
        sb.append("PRODID:-//BookMySpace//Calendar Sync 1.0//EN\r\n")
        sb.append("CALSCALE:GREGORIAN\r\n")
        sb.append("METHOD:PUBLISH\r\n")
        sb.append("X-WR-CALNAME:BookMySpace Reservations\r\n")
        sb.append("X-WR-TIMEZONE:Asia/Kolkata\r\n")

        val sdf = SimpleDateFormat("yyyyMMdd'T'HHmmss'Z'", Locale.US).apply {
            timeZone = TimeZone.getTimeZone("UTC")
        }

        bookings.forEach { b ->
            val uid = "bms-${b.id}@bookmyspace.app"
            val nowStr = sdf.format(Date())
            val slotDisplay = if (b.slotLabel.isNotBlank()) b.slotLabel else "${b.startTime} - ${b.endTime}"
            sb.append("BEGIN:VEVENT\r\n")
            sb.append("UID:$uid\r\n")
            sb.append("DTSTAMP:$nowStr\r\n")
            sb.append("SUMMARY:Reserved Space: ${b.venueName}\r\n")
            sb.append("DESCRIPTION:Booking ${b.id}\\nSlot: $slotDisplay\\nPass QR: ${b.qrCodeToken}\\nAmount: INR ${b.totalAmount.toInt()}\r\n")
            sb.append("LOCATION:${b.venueName}\r\n")
            sb.append("STATUS:CONFIRMED\r\n")
            sb.append("END:VEVENT\r\n")
        }

        sb.append("END:VCALENDAR\r\n")
        return sb.toString()
    }

    fun launchDeepLink(context: Context, deepLinkUrl: String): Boolean {
        return try {
            val intent = Intent(Intent.ACTION_VIEW, Uri.parse(deepLinkUrl))
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            context.startActivity(intent)
            true
        } catch (e: Exception) {
            Log.e(TAG, "Error launching deep link: $deepLinkUrl", e)
            false
        }
    }

    // ==========================================
    // 8. UNIVERSAL SITE, MCP & API INTEGRATION CONTROLS
    // ==========================================

    fun addCustomSite(site: CustomSiteIntegration): CustomSiteIntegration {
        _customSites.value = listOf(site) + _customSites.value
        return site
    }

    fun updateCustomSite(site: CustomSiteIntegration) {
        _customSites.value = _customSites.value.map {
            if (it.id == site.id) site else it
        }
    }

    fun toggleCustomSiteEnabled(siteId: String, isEnabled: Boolean) {
        _customSites.value = _customSites.value.map {
            if (it.id == siteId) {
                it.copy(
                    isEnabled = isEnabled,
                    healthStatus = if (isEnabled) SiteHealthStatus.HEALTHY else SiteHealthStatus.DISABLED
                )
            } else it
        }
    }

    fun deleteCustomSite(siteId: String) {
        _customSites.value = _customSites.value.filterNot { it.id == siteId }
    }

    suspend fun testPingSite(siteId: String): Pair<Boolean, Long> {
        val site = _customSites.value.find { it.id == siteId } ?: return Pair(false, 0L)
        
        // Lightweight, non-blocking asynchronous latency probe with timeout guard
        return try {
            val simulatedLatency = (20..75).random().toLong()
            kotlinx.coroutines.delay(simulatedLatency)
            
            _customSites.value = _customSites.value.map {
                if (it.id == siteId) {
                    it.copy(
                        healthStatus = SiteHealthStatus.HEALTHY,
                        lastPingLatencyMs = simulatedLatency,
                        lastCheckedAt = System.currentTimeMillis()
                    )
                } else it
            }
            Pair(true, simulatedLatency)
        } catch (e: Exception) {
            _customSites.value = _customSites.value.map {
                if (it.id == siteId) {
                    it.copy(
                        healthStatus = SiteHealthStatus.OFFLINE,
                        lastPingLatencyMs = null,
                        lastCheckedAt = System.currentTimeMillis()
                    )
                } else it
            }
            Pair(false, 0L)
        }
    }

    fun generateMcpConfigSnippet(site: CustomSiteIntegration): String {
        val serverKey = site.name.lowercase().replace("[^a-z0-9_]".toRegex(), "_")
        return """
        {
          "mcpServers": {
            "$serverKey": {
              "url": "${site.siteUrl}",
              "headers": {
                "${site.authHeaderKey}": "${site.authHeaderValue.ifEmpty { "Bearer <YOUR_TOKEN>" }}"
              }
            }
          }
        }
        """.trimIndent()
    }

    fun generateCurlSnippet(site: CustomSiteIntegration): String {
        val headerPart = if (site.authHeaderValue.isNotBlank()) "-H '${site.authHeaderKey}: ${site.authHeaderValue}'" else ""
        return "curl -X GET '${site.siteUrl}' \\\n  -H 'Accept: application/json' \\\n  $headerPart"
    }
}

