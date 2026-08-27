package com.bookmyspace.bookmyspace.data.model

import org.json.JSONArray
import org.json.JSONObject
import java.util.UUID

/**
 * Model definitions for Model Context Protocol (MCP), REST APIs, Webhooks, and Third-Party Connectors.
 */

// ==========================================
// 1. MODEL CONTEXT PROTOCOL (MCP) DATA TYPES
// ==========================================

data class McpToolDefinition(
    val name: String,
    val description: String,
    val inputSchemaJson: String,
    val exampleInputJson: String,
    val category: String = "Search & Booking",
    val readOnly: Boolean = true
)

data class McpResourceDefinition(
    val uri: String,
    val name: String,
    val description: String,
    val mimeType: String = "application/json"
)

data class McpPromptDefinition(
    val name: String,
    val description: String,
    val template: String
)

data class McpToolExecutionResult(
    val toolName: String,
    val inputJson: String,
    val isSuccess: Boolean,
    val outputJson: String,
    val executionTimeMs: Long,
    val timestamp: Long = System.currentTimeMillis()
)

// ==========================================
// 2. REST API & AUTHENTICATION KEY TYPES
// ==========================================

enum class ApiKeyScope(val code: String, val displayName: String, val description: String) {
    READ_VENUES("read:venues", "Read Spaces & Venues", "Access public spaces, amenities, reviews & photos"),
    READ_AVAILABILITY("read:availability", "Read Slot Availability", "Query calendar slots & real-time available hours"),
    WRITE_BOOKINGS("write:bookings", "Create & Manage Bookings", "Hold slots, book spaces, calculate tax invoices"),
    READ_BOOKINGS("read:bookings", "Read User Bookings", "Access active passes, history, and status"),
    WEBHOOK_RECEIVER("webhook:receiver", "Webhook Stream", "Receive real-time dispatch payloads"),
    HOST_ADMIN("host:admin", "Host Management Admin", "Manage venue listings, slot blackouts, student rosters")
}

data class ApiKeyToken(
    val id: String = UUID.randomUUID().toString().take(8),
    val name: String,
    val token: String = "bms_live_" + UUID.randomUUID().toString().replace("-", "").take(24),
    val scopes: Set<ApiKeyScope>,
    val createdAt: Long = System.currentTimeMillis(),
    val lastUsedAt: Long? = null,
    val isActive: Boolean = true
)

data class ApiEndpointDoc(
    val method: String,
    val path: String,
    val summary: String,
    val description: String,
    val requiredScopes: List<ApiKeyScope>,
    val requestBodyExampleJson: String? = null,
    val responseExampleJson: String
)

// ==========================================
// 3. OUTGOING WEBHOOKS & AUTOMATION
// ==========================================

enum class WebhookEvent(val eventName: String, val displayName: String, val description: String) {
    BOOKING_CREATED("booking.created", "Booking Created / Held", "Fires whenever a user initiates a booking reservation hold"),
    BOOKING_CONFIRMED("booking.confirmed", "Booking Confirmed & Paid", "Fires when payment is completed & QR pass generated"),
    BOOKING_CANCELLED("booking.cancelled", "Booking Cancelled", "Fires when a booking is cancelled or refunded"),
    CHECKIN_SCANNED("checkin.scanned", "QR Entry Verified", "Fires when host scans customer's entry QR pass"),
    SLOT_BLACKED_OUT("slot.blackout", "Slot Blackout Updated", "Fires when a host blocks or unblocks calendar slots")
}

data class WebhookSubscription(
    val id: String = UUID.randomUUID().toString().take(8),
    val targetUrl: String,
    val secretKey: String = "whsec_" + UUID.randomUUID().toString().replace("-", "").take(16),
    val subscribedEvents: Set<WebhookEvent>,
    val isActive: Boolean = true,
    val createdAt: Long = System.currentTimeMillis(),
    val failureCount: Int = 0,
    val lastDeliveredAt: Long? = null
)

data class WebhookDeliveryLog(
    val id: String = UUID.randomUUID().toString().take(8),
    val webhookId: String,
    val event: WebhookEvent,
    val targetUrl: String,
    val httpStatusCode: Int,
    val payloadJson: String,
    val responseBody: String,
    val isSuccess: Boolean,
    val latencyMs: Long,
    val timestamp: Long = System.currentTimeMillis()
)

// ==========================================
// 4. THIRD-PARTY CONNECTORS & CALENDAR
// ==========================================

enum class ConnectorType(val id: String, val title: String, val iconEmoji: String, val category: String) {
    GOOGLE_CALENDAR("gcal", "Google Calendar", "📅", "Calendar Sync"),
    OUTLOOK_CALENDAR("outlook", "Microsoft Outlook", "📆", "Calendar Sync"),
    APPLE_ICAL("apple_ical", "Apple Calendar (.ics)", "🍏", "Calendar Sync"),
    ZAPIER("zapier", "Zapier Automation", "⚡", "Workflow Integrations"),
    MAKE_N8N("make", "Make / n8n Webhooks", "🔄", "Workflow Integrations"),
    WHATSAPP_BOT("whatsapp", "WhatsApp Business Bot", "💬", "Messaging & Notifications"),
    TELEGRAM_BOT("telegram", "Telegram Bot Bridge", "✈️", "Messaging & Notifications"),
    SLACK_DISCORD("slack", "Slack / Discord Alerts", "🔔", "Team Notifications")
}

data class ConnectedAppConfig(
    val connectorType: ConnectorType,
    val isConnected: Boolean,
    val configUrl: String = "",
    val autoSyncEnabled: Boolean = true,
    val lastSyncedAt: Long? = null
)

// ==========================================
// 5. UNIVERSAL SITE, MCP & CUSTOM API MODELS
// ==========================================

enum class CustomSiteCategory(val title: String, val iconEmoji: String, val description: String) {
    STORE_COMMERCE("E-Commerce & Store", "🛒", "Shopify, WooCommerce, Custom Merch & Gear Storefronts"),
    BOOKING_CALENDAR("External Scheduling", "📅", "Calendly, Cal.com, Acuity, Host Appointment links"),
    CRM_LEADS("CRM & Leads", "💼", "HubSpot, Salesforce, Zoho, Customer lead dispatchers"),
    MCP_SERVER("Remote MCP Server", "🤖", "Claude Desktop, Cursor, Gemini MCP JSON-RPC endpoints"),
    REST_API("Custom REST API", "⚡", "External microservices, JSON endpoints & database query APIs"),
    WEBHOOK_TARGET("Webhook Automation", "🪝", "Zapier, Make, n8n, custom event triggers"),
    CHAT_SUPPORT("Live Chat & Support", "💬", "Intercom, Zendesk, Tawk.to, Crisp live chat widgets"),
    CUSTOM_PORTAL("Web Portal / Web App", "🌐", "Host partner dashboard, custom web iframe or URL")
}

enum class SiteAuthType(val title: String) {
    NONE("No Authentication (Public)"),
    API_KEY("API Key (Header / Query)"),
    BEARER_TOKEN("Bearer Token (JWT)"),
    BASIC_AUTH("Basic Auth (Base64)"),
    CUSTOM_HEADER("Custom Header")
}

enum class SiteSyncMode(val title: String) {
    ON_DEMAND("On-Demand (Zero background overhead)"),
    REAL_TIME_PING("Health Monitored (Non-blocking ping)"),
    WEBHOOK_STREAM("Event-Driven Stream"),
    EMBEDDED_VIEW("Interactive In-App Web Launch")
}

enum class SiteHealthStatus(val label: String, val icon: String) {
    HEALTHY("Healthy (Online)", "🟢"),
    DEGRADED("High Latency", "🟡"),
    OFFLINE("Unreachable", "🔴"),
    DISABLED("Turned OFF", "⏸️")
}

data class CustomSiteIntegration(
    val id: String = UUID.randomUUID().toString().take(8),
    val name: String,
    val siteUrl: String,
    val category: CustomSiteCategory = CustomSiteCategory.CUSTOM_PORTAL,
    val authType: SiteAuthType = SiteAuthType.NONE,
    val authHeaderKey: String = "Authorization",
    val authHeaderValue: String = "",
    val customHeaders: Map<String, String> = emptyMap(),
    val isEnabled: Boolean = true,
    val syncMode: SiteSyncMode = SiteSyncMode.ON_DEMAND,
    val healthStatus: SiteHealthStatus = SiteHealthStatus.HEALTHY,
    val lastPingLatencyMs: Long? = 45L,
    val lastCheckedAt: Long? = System.currentTimeMillis(),
    val description: String = "",
    val iconEmoji: String = "🌐",
    val allowInAppBrowser: Boolean = true,
    val createdAt: Long = System.currentTimeMillis()
)

