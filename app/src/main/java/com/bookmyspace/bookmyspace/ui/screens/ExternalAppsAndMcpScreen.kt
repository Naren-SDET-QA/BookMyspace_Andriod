package com.bookmyspace.bookmyspace.ui.screens

import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.widget.Toast
import androidx.compose.animation.*
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.window.Dialog
import kotlinx.coroutines.launch
import com.bookmyspace.bookmyspace.data.integration.ExternalAppAndMcpService
import com.bookmyspace.bookmyspace.data.model.*
import com.bookmyspace.bookmyspace.data.repository.BookMySpaceRepository

enum class IntegrationsTab(val title: String, val icon: String) {
    UNIVERSAL_SITES("External Sites & Hub", "🌐"),
    MCP_AI("MCP & AI Tools", "🤖"),
    REST_API("REST API & Keys", "⚡"),
    WEBHOOKS("Webhooks & Automations", "🪝"),
    CONNECTED_APPS("Connected Apps & Links", "📅")
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ExternalAppsAndMcpScreen(
    onNavigateBack: () -> Unit,
    onNavigateToRoute: (String) -> Unit = {}
) {
    val context = LocalContext.current
    val coroutineScope = rememberCoroutineScope()
    val horizontalPadding = 16.dp

    var selectedTab by remember { mutableStateOf(IntegrationsTab.UNIVERSAL_SITES) }

    val customSites by ExternalAppAndMcpService.customSites.collectAsState()
    val apiKeys by ExternalAppAndMcpService.apiKeys.collectAsState()
    val webhooks by ExternalAppAndMcpService.webhooks.collectAsState()
    val webhookLogs by ExternalAppAndMcpService.webhookLogs.collectAsState()
    val toolExecutionLogs by ExternalAppAndMcpService.toolExecutionLogs.collectAsState()
    val connectedApps by ExternalAppAndMcpService.connectedApps.collectAsState()
    val bookings by BookMySpaceRepository.bookings.collectAsState()

    // Dialog states
    var showAddCustomSiteDialog by remember { mutableStateOf(false) }
    var editingCustomSite by remember { mutableStateOf<CustomSiteIntegration?>(null) }
    var viewingSnippetSite by remember { mutableStateOf<CustomSiteIntegration?>(null) }
    var activeConfigDialogType by remember { mutableStateOf<String?>(null) } // "claude", "cursor", "gemini"
    var testingMcpTool by remember { mutableStateOf<McpToolDefinition?>(null) }
    var testingToolInputText by remember { mutableStateOf("") }
    var lastExecutionResult by remember { mutableStateOf<McpToolExecutionResult?>(null) }
    var isExecutingTool by remember { mutableStateOf(false) }

    var showCreateApiKeyDialog by remember { mutableStateOf(false) }
    var newKeyName by remember { mutableStateOf("") }
    var selectedKeyScopes by remember { mutableStateOf<Set<ApiKeyScope>>(setOf(ApiKeyScope.READ_VENUES, ApiKeyScope.READ_AVAILABILITY)) }

    var showAddWebhookDialog by remember { mutableStateOf(false) }
    var newWebhookUrl by remember { mutableStateOf("") }
    var selectedWebhookEvents by remember { mutableStateOf<Set<WebhookEvent>>(setOf(WebhookEvent.BOOKING_CONFIRMED)) }

    var showCodeSnippetDialog by remember { mutableStateOf<ApiEndpointDoc?>(null) }
    var selectedCodeLanguage by remember { mutableStateOf("curl") } // "curl", "python", "javascript"

    fun copyToClipboard(text: String, label: String = "Copied to clipboard") {
        val clipboard = context.getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
        val clip = ClipData.newPlainText("BookMySpace Integrations", text)
        clipboard.setPrimaryClip(clip)
        Toast.makeText(context, label, Toast.LENGTH_SHORT).show()
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = {
                    Column {
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            Text(
                                text = "Connected Apps & MCP Hub",
                                fontWeight = FontWeight.Bold,
                                fontSize = 18.sp
                            )
                            Spacer(modifier = Modifier.width(8.dp))
                            Surface(
                                shape = RoundedCornerShape(8.dp),
                                color = Color(0xFF2E7D32).copy(alpha = 0.15f)
                            ) {
                                Text(
                                    text = "LIVE",
                                    color = Color(0xFF2E7D32),
                                    fontSize = 10.sp,
                                    fontWeight = FontWeight.Black,
                                    modifier = Modifier.padding(horizontal = 6.dp, vertical = 2.dp)
                                )
                            }
                        }
                        Text(
                            text = "Model Context Protocol, REST APIs, Webhooks & Deep Links",
                            fontSize = 11.5.sp,
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                    }
                },
                navigationIcon = {
                    IconButton(
                        onClick = onNavigateBack,
                        modifier = Modifier.testTag("btn_back_from_external_integrations")
                    ) {
                        Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "Back")
                    }
                },
                colors = TopAppBarDefaults.topAppBarColors(
                    containerColor = MaterialTheme.colorScheme.surface
                )
            )
        }
    ) { paddingValues ->
        LazyColumn(
            modifier = Modifier
                .fillMaxSize()
                .padding(paddingValues)
                .testTag("external_integrations_screen_list"),
            contentPadding = PaddingValues(bottom = 80.dp)
        ) {
            // 1. Overview & Connection Status Header Banner
            item {
                Surface(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(horizontal = horizontalPadding, vertical = 12.dp),
                    shape = RoundedCornerShape(20.dp),
                    color = MaterialTheme.colorScheme.primaryContainer.copy(alpha = 0.4f),
                    border = BorderStroke(1.dp, MaterialTheme.colorScheme.primary.copy(alpha = 0.2f))
                ) {
                    Column(modifier = Modifier.padding(16.dp)) {
                        Row(
                            verticalAlignment = Alignment.CenterVertically,
                            horizontalArrangement = Arrangement.SpaceBetween,
                            modifier = Modifier.fillMaxWidth()
                        ) {
                            Row(verticalAlignment = Alignment.CenterVertically) {
                                Text("🔗", fontSize = 24.sp)
                                Spacer(modifier = Modifier.width(10.dp))
                                Column {
                                    Text(
                                        text = "External Integration Engine",
                                        fontWeight = FontWeight.ExtraBold,
                                        fontSize = 16.sp,
                                        color = MaterialTheme.colorScheme.onPrimaryContainer
                                    )
                                    Text(
                                        text = "Connect AI Assistants (Claude, Cursor, Gemini), Zapier & Calendars",
                                        fontSize = 12.sp,
                                        color = MaterialTheme.colorScheme.onPrimaryContainer.copy(alpha = 0.8f)
                                    )
                                }
                            }
                        }

                        Spacer(modifier = Modifier.height(12.dp))

                        // Status Pills
                        Row(
                            modifier = Modifier
                                .fillMaxWidth()
                                .horizontalScroll(rememberScrollState()),
                            horizontalArrangement = Arrangement.spacedBy(8.dp)
                        ) {
                            IntegrationStatusPill(emoji = "🤖", label = "MCP Server: 6 Tools", isActive = true)
                            IntegrationStatusPill(emoji = "⚡", label = "REST API v1", isActive = true)
                            IntegrationStatusPill(emoji = "🪝", label = "Webhooks: Ready", isActive = true)
                            IntegrationStatusPill(emoji = "📅", label = ".ics Calendar Feed", isActive = true)
                        }
                    }
                }
            }

            // 2. Tab Bar Selector
            item {
                LazyRow(
                    contentPadding = PaddingValues(horizontal = horizontalPadding),
                    horizontalArrangement = Arrangement.spacedBy(8.dp),
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(bottom = 12.dp)
                        .testTag("integrations_tab_bar")
                ) {
                    items(IntegrationsTab.entries) { tab ->
                        val isSelected = selectedTab == tab
                        FilterChip(
                            selected = isSelected,
                            onClick = { selectedTab = tab },
                            label = {
                                Row(verticalAlignment = Alignment.CenterVertically) {
                                    Text(tab.icon, fontSize = 14.sp)
                                    Spacer(modifier = Modifier.width(6.dp))
                                    Text(
                                        text = tab.title,
                                        fontWeight = if (isSelected) FontWeight.Bold else FontWeight.Medium,
                                        fontSize = 13.sp
                                    )
                                }
                            },
                            colors = FilterChipDefaults.filterChipColors(
                                selectedContainerColor = MaterialTheme.colorScheme.primary,
                                selectedLabelColor = MaterialTheme.colorScheme.onPrimary
                            ),
                            shape = RoundedCornerShape(16.dp),
                            modifier = Modifier.defaultMinSize(minHeight = 40.dp)
                        )
                    }
                }
            }

            // 3. Tab Contents
            when (selectedTab) {
                IntegrationsTab.UNIVERSAL_SITES -> {
                    // Universal Site, MCP & Custom API Integrations
                    item {
                        Column(modifier = Modifier.padding(horizontal = horizontalPadding)) {
                            // Section Banner & Stats
                            Surface(
                                shape = RoundedCornerShape(16.dp),
                                color = MaterialTheme.colorScheme.surface,
                                border = BorderStroke(1.dp, MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.5f)),
                                modifier = Modifier.fillMaxWidth()
                            ) {
                                Column(modifier = Modifier.padding(16.dp)) {
                                    Row(
                                        verticalAlignment = Alignment.CenterVertically,
                                        horizontalArrangement = Arrangement.SpaceBetween,
                                        modifier = Modifier.fillMaxWidth()
                                    ) {
                                        Row(verticalAlignment = Alignment.CenterVertically) {
                                            Text("🌐", fontSize = 24.sp)
                                            Spacer(modifier = Modifier.width(10.dp))
                                            Column {
                                                Text(
                                                    text = "Universal Site & Platform Connector",
                                                    fontWeight = FontWeight.ExtraBold,
                                                    fontSize = 15.sp
                                                )
                                                Text(
                                                    text = "Integrate any website, remote MCP server, or external API",
                                                    fontSize = 11.5.sp,
                                                    color = MaterialTheme.colorScheme.onSurfaceVariant
                                                )
                                            }
                                        }

                                        Button(
                                            onClick = {
                                                editingCustomSite = null
                                                showAddCustomSiteDialog = true
                                            },
                                            shape = RoundedCornerShape(12.dp),
                                            contentPadding = PaddingValues(horizontal = 12.dp, vertical = 6.dp),
                                            modifier = Modifier
                                                .defaultMinSize(minHeight = 36.dp)
                                                .testTag("btn_add_custom_site_integration")
                                        ) {
                                            Icon(Icons.Default.Add, contentDescription = null, modifier = Modifier.size(16.dp))
                                            Spacer(modifier = Modifier.width(4.dp))
                                            Text("Add Any Site", fontSize = 12.sp, fontWeight = FontWeight.Bold)
                                        }
                                    }

                                    Spacer(modifier = Modifier.height(10.dp))

                                    // Metric badges
                                    val activeCount = customSites.count { it.isEnabled }
                                    val disabledCount = customSites.size - activeCount
                                    Row(
                                        modifier = Modifier
                                            .fillMaxWidth()
                                            .horizontalScroll(rememberScrollState()),
                                        horizontalArrangement = Arrangement.spacedBy(8.dp)
                                    ) {
                                        IntegrationStatusPill(emoji = "⚡", label = "$activeCount Active (ON)", isActive = true)
                                        IntegrationStatusPill(emoji = "⏸️", label = "$disabledCount Disabled (0% CPU)", isActive = false)
                                        IntegrationStatusPill(emoji = "🚀", label = "Modular & Isolated", isActive = true)
                                        IntegrationStatusPill(emoji = "🔒", label = "Auth & Headers Ready", isActive = true)
                                    }
                                }
                            }

                            Spacer(modifier = Modifier.height(14.dp))

                            // 1-Click Quick Preset Adder Carousel
                            Text(
                                text = "1-Click Quick Presets",
                                fontSize = 13.5.sp,
                                fontWeight = FontWeight.Bold,
                                color = MaterialTheme.colorScheme.onBackground
                            )
                            Spacer(modifier = Modifier.height(6.dp))
                            LazyRow(
                                horizontalArrangement = Arrangement.spacedBy(8.dp),
                                modifier = Modifier.fillMaxWidth()
                            ) {
                                val presets = listOf(
                                    Triple("🛒 Shopify Store", "https://shop.example.com", CustomSiteCategory.STORE_COMMERCE),
                                    Triple("📅 Calendly Link", "https://calendly.com/your-org/tour", CustomSiteCategory.BOOKING_CALENDAR),
                                    Triple("🤖 Remote MCP Server", "https://mcp.example.com/sse", CustomSiteCategory.MCP_SERVER),
                                    Triple("💼 HubSpot Leads CRM", "https://api.hubapi.com/crm/v3/objects/contacts", CustomSiteCategory.CRM_LEADS),
                                    Triple("⚡ Custom REST API", "https://api.example.com/v1/spaces", CustomSiteCategory.REST_API),
                                    Triple("🪝 Zapier / n8n Webhook", "https://hooks.zapier.com/hooks/catch/custom", CustomSiteCategory.WEBHOOK_TARGET),
                                    Triple("💬 Intercom Live Chat", "https://app.intercom.com/widget", CustomSiteCategory.CHAT_SUPPORT),
                                    Triple("🌐 Partner Web Portal", "https://portal.example.com", CustomSiteCategory.CUSTOM_PORTAL)
                                )

                                items(presets) { (presetName, defaultUrl, category) ->
                                    Surface(
                                        onClick = {
                                            editingCustomSite = CustomSiteIntegration(
                                                name = presetName.substringAfter(" "),
                                                siteUrl = defaultUrl,
                                                category = category,
                                                iconEmoji = presetName.take(2),
                                                description = "Integrated ${category.title} connection for BookMySpace"
                                            )
                                            showAddCustomSiteDialog = true
                                        },
                                        shape = RoundedCornerShape(12.dp),
                                        color = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.5f),
                                        border = BorderStroke(1.dp, MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.4f)),
                                        modifier = Modifier.defaultMinSize(minHeight = 36.dp)
                                    ) {
                                        Row(
                                            modifier = Modifier.padding(horizontal = 10.dp, vertical = 6.dp),
                                            verticalAlignment = Alignment.CenterVertically
                                        ) {
                                            Text(presetName, fontSize = 11.5.sp, fontWeight = FontWeight.SemiBold)
                                            Spacer(modifier = Modifier.width(4.dp))
                                            Icon(Icons.Default.AddCircleOutline, contentDescription = null, modifier = Modifier.size(14.dp), tint = MaterialTheme.colorScheme.primary)
                                        }
                                    }
                                }
                            }

                            Spacer(modifier = Modifier.height(14.dp))

                            Text(
                                text = "Configured External Integrations (${customSites.size})",
                                fontSize = 14.sp,
                                fontWeight = FontWeight.Bold,
                                color = MaterialTheme.colorScheme.onBackground
                            )
                            Text(
                                text = "Admins can turn any section or site ON/OFF independently. Inactive sites consume zero background resources.",
                                fontSize = 11.5.sp,
                                color = MaterialTheme.colorScheme.onSurfaceVariant
                            )
                            Spacer(modifier = Modifier.height(8.dp))
                        }
                    }

                    if (customSites.isEmpty()) {
                        item {
                            Surface(
                                shape = RoundedCornerShape(16.dp),
                                color = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.4f),
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .padding(horizontal = horizontalPadding, vertical = 12.dp)
                            ) {
                                Column(
                                    modifier = Modifier.padding(24.dp),
                                    horizontalAlignment = Alignment.CenterHorizontally
                                ) {
                                    Text("🌐", fontSize = 32.sp)
                                    Spacer(modifier = Modifier.height(8.dp))
                                    Text("No External Sites Connected", fontWeight = FontWeight.Bold, fontSize = 14.sp)
                                    Spacer(modifier = Modifier.height(4.dp))
                                    Text(
                                        "Click '+ Add Any Site' above or select a 1-click preset to connect Shopify, Calendly, MCP, CRM or custom REST APIs.",
                                        fontSize = 12.sp,
                                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                                        textAlign = androidx.compose.ui.text.style.TextAlign.Center
                                    )
                                }
                            }
                        }
                    } else {
                        items(customSites, key = { it.id }) { site ->
                            UniversalSiteCard(
                                site = site,
                                onToggleEnabled = { isChecked ->
                                    ExternalAppAndMcpService.toggleCustomSiteEnabled(site.id, isChecked)
                                    Toast.makeText(
                                        context,
                                        "${site.name} is now ${if (isChecked) "ACTIVATED (ON)" else "DISABLED (OFF)"}",
                                        Toast.LENGTH_SHORT
                                    ).show()
                                },
                                onTestPing = {
                                    coroutineScope.launch {
                                        Toast.makeText(context, "Pinging ${site.name}...", Toast.LENGTH_SHORT).show()
                                        val (success, latency) = ExternalAppAndMcpService.testPingSite(site.id)
                                        if (success) {
                                            Toast.makeText(context, "🟢 ${site.name} responded in ${latency}ms!", Toast.LENGTH_SHORT).show()
                                        } else {
                                            Toast.makeText(context, "🔴 Connection test failed for ${site.name}", Toast.LENGTH_SHORT).show()
                                        }
                                    }
                                },
                                onOpenSite = {
                                    val opened = ExternalAppAndMcpService.launchDeepLink(context, site.siteUrl)
                                    if (!opened) {
                                        Toast.makeText(context, "Opening in browser: ${site.siteUrl}", Toast.LENGTH_SHORT).show()
                                    }
                                },
                                onViewSnippet = {
                                    viewingSnippetSite = site
                                },
                                onEdit = {
                                    editingCustomSite = site
                                    showAddCustomSiteDialog = true
                                },
                                onDelete = {
                                    ExternalAppAndMcpService.deleteCustomSite(site.id)
                                    Toast.makeText(context, "Removed ${site.name}", Toast.LENGTH_SHORT).show()
                                },
                                modifier = Modifier.padding(horizontal = horizontalPadding, vertical = 6.dp)
                            )
                        }
                    }
                }

                IntegrationsTab.MCP_AI -> {
                    // Quick Setup Cards for Claude Desktop, Cursor, Gemini
                    item {
                        Column(modifier = Modifier.padding(horizontal = horizontalPadding)) {
                            Text(
                                text = "1-Click AI Agent & MCP Configs",
                                fontSize = 15.sp,
                                fontWeight = FontWeight.Bold,
                                color = MaterialTheme.colorScheme.onBackground
                            )
                            Spacer(modifier = Modifier.height(4.dp))
                            Text(
                                text = "Export configuration files for AI coding environments and desktop clients.",
                                fontSize = 12.sp,
                                color = MaterialTheme.colorScheme.onSurfaceVariant
                            )
                            Spacer(modifier = Modifier.height(10.dp))

                            Row(
                                modifier = Modifier.fillMaxWidth(),
                                horizontalArrangement = Arrangement.spacedBy(8.dp)
                            ) {
                                McpClientCard(
                                    title = "Claude Desktop",
                                    icon = "🟣",
                                    subtitle = "claude_desktop_config.json",
                                    onClick = { activeConfigDialogType = "claude" },
                                    modifier = Modifier.weight(1f)
                                )
                                McpClientCard(
                                    title = "Cursor / VS Code",
                                    icon = "⚡",
                                    subtitle = "cursor_mcp.json",
                                    onClick = { activeConfigDialogType = "cursor" },
                                    modifier = Modifier.weight(1f)
                                )
                                McpClientCard(
                                    title = "Gemini / OpenAI",
                                    icon = "✨",
                                    subtitle = "JSON Tool Schemas",
                                    onClick = { activeConfigDialogType = "gemini" },
                                    modifier = Modifier.weight(1f)
                                )
                            }
                        }
                    }

                    // MCP Tool Catalog
                    item {
                        Spacer(modifier = Modifier.height(18.dp))
                        Column(modifier = Modifier.padding(horizontal = horizontalPadding)) {
                            Row(
                                modifier = Modifier.fillMaxWidth(),
                                verticalAlignment = Alignment.CenterVertically,
                                horizontalArrangement = Arrangement.SpaceBetween
                            ) {
                                Text(
                                    text = "Model Context Protocol Tools (${ExternalAppAndMcpService.mcpTools.size})",
                                    fontSize = 15.sp,
                                    fontWeight = FontWeight.Bold,
                                    color = MaterialTheme.colorScheme.onBackground
                                )
                                Text(
                                    text = "Interactive Test Sandbox",
                                    fontSize = 11.5.sp,
                                    color = MaterialTheme.colorScheme.primary,
                                    fontWeight = FontWeight.SemiBold
                                )
                            }
                            Spacer(modifier = Modifier.height(4.dp))
                            Text(
                                text = "Any AI agent can query and execute these tools with real-time slot and pricing data:",
                                fontSize = 12.sp,
                                color = MaterialTheme.colorScheme.onSurfaceVariant
                            )
                            Spacer(modifier = Modifier.height(10.dp))
                        }
                    }

                    items(ExternalAppAndMcpService.mcpTools, key = { it.name }) { tool ->
                        McpToolItemCard(
                            tool = tool,
                            onRunTest = {
                                testingMcpTool = tool
                                testingToolInputText = tool.exampleInputJson
                                lastExecutionResult = null
                            },
                            onCopySchema = {
                                copyToClipboard(tool.inputSchemaJson, "Copied tool schema")
                            },
                            modifier = Modifier
                                .fillMaxWidth()
                                .padding(horizontal = horizontalPadding, vertical = 5.dp)
                        )
                    }

                    // MCP Resources
                    item {
                        Spacer(modifier = Modifier.height(16.dp))
                        Column(modifier = Modifier.padding(horizontal = horizontalPadding)) {
                            Text(
                                text = "Exposed MCP Resources (bms://)",
                                fontSize = 15.sp,
                                fontWeight = FontWeight.Bold,
                                color = MaterialTheme.colorScheme.onBackground
                            )
                            Spacer(modifier = Modifier.height(8.dp))
                        }
                    }

                    items(ExternalAppAndMcpService.mcpResources, key = { it.uri }) { resource ->
                        Surface(
                            shape = RoundedCornerShape(12.dp),
                            color = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.4f),
                            border = BorderStroke(1.dp, MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.4f)),
                            modifier = Modifier
                                .fillMaxWidth()
                                .padding(horizontal = horizontalPadding, vertical = 4.dp)
                        ) {
                            Row(
                                modifier = Modifier.padding(12.dp),
                                verticalAlignment = Alignment.CenterVertically,
                                horizontalArrangement = Arrangement.SpaceBetween
                            ) {
                                Column(modifier = Modifier.weight(1f)) {
                                    Text(
                                        text = resource.uri,
                                        fontFamily = FontFamily.Monospace,
                                        fontWeight = FontWeight.Bold,
                                        fontSize = 12.5.sp,
                                        color = MaterialTheme.colorScheme.primary
                                    )
                                    Spacer(modifier = Modifier.height(2.dp))
                                    Text(
                                        text = resource.description,
                                        fontSize = 11.5.sp,
                                        color = MaterialTheme.colorScheme.onSurfaceVariant
                                    )
                                }
                                IconButton(onClick = { copyToClipboard(resource.uri, "Copied Resource URI") }) {
                                    Icon(Icons.Default.ContentCopy, contentDescription = "Copy URI", modifier = Modifier.size(16.dp))
                                }
                            }
                        }
                    }
                }

                IntegrationsTab.REST_API -> {
                    // API Keys Section
                    item {
                        Column(modifier = Modifier.padding(horizontal = horizontalPadding)) {
                            Row(
                                modifier = Modifier.fillMaxWidth(),
                                verticalAlignment = Alignment.CenterVertically,
                                horizontalArrangement = Arrangement.SpaceBetween
                            ) {
                                Text(
                                    text = "API Access Tokens (${apiKeys.size})",
                                    fontSize = 15.sp,
                                    fontWeight = FontWeight.Bold,
                                    color = MaterialTheme.colorScheme.onBackground
                                )
                                Button(
                                    onClick = {
                                        newKeyName = ""
                                        selectedKeyScopes = setOf(ApiKeyScope.READ_VENUES, ApiKeyScope.READ_AVAILABILITY)
                                        showCreateApiKeyDialog = true
                                    },
                                    contentPadding = PaddingValues(horizontal = 12.dp, vertical = 6.dp),
                                    shape = RoundedCornerShape(12.dp),
                                    modifier = Modifier.defaultMinSize(minHeight = 36.dp)
                                ) {
                                    Icon(Icons.Default.Add, contentDescription = null, modifier = Modifier.size(16.dp))
                                    Spacer(modifier = Modifier.width(4.dp))
                                    Text("New Key", fontSize = 12.5.sp, fontWeight = FontWeight.Bold)
                                }
                            }
                            Spacer(modifier = Modifier.height(8.dp))
                        }
                    }

                    items(apiKeys, key = { it.id }) { key ->
                        Surface(
                            shape = RoundedCornerShape(14.dp),
                            color = MaterialTheme.colorScheme.surface,
                            border = BorderStroke(1.dp, MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.5f)),
                            modifier = Modifier
                                .fillMaxWidth()
                                .padding(horizontal = horizontalPadding, vertical = 4.dp)
                        ) {
                            Column(modifier = Modifier.padding(14.dp)) {
                                Row(
                                    modifier = Modifier.fillMaxWidth(),
                                    verticalAlignment = Alignment.CenterVertically,
                                    horizontalArrangement = Arrangement.SpaceBetween
                                ) {
                                    Row(verticalAlignment = Alignment.CenterVertically) {
                                        Text("🔑", fontSize = 16.sp)
                                        Spacer(modifier = Modifier.width(8.dp))
                                        Text(
                                            text = key.name,
                                            fontWeight = FontWeight.Bold,
                                            fontSize = 13.5.sp
                                        )
                                    }
                                    IconButton(
                                        onClick = { ExternalAppAndMcpService.revokeApiKey(key.id) },
                                        modifier = Modifier.size(28.dp)
                                    ) {
                                        Icon(
                                            imageVector = Icons.Default.Delete,
                                            contentDescription = "Revoke Key",
                                            tint = MaterialTheme.colorScheme.error,
                                            modifier = Modifier.size(16.dp)
                                        )
                                    }
                                }

                                Spacer(modifier = Modifier.height(6.dp))

                                Surface(
                                    shape = RoundedCornerShape(8.dp),
                                    color = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.5f),
                                    modifier = Modifier.fillMaxWidth()
                                ) {
                                    Row(
                                        modifier = Modifier.padding(horizontal = 10.dp, vertical = 6.dp),
                                        verticalAlignment = Alignment.CenterVertically,
                                        horizontalArrangement = Arrangement.SpaceBetween
                                    ) {
                                        Text(
                                            text = key.token.take(12) + "..." + key.token.takeLast(6),
                                            fontFamily = FontFamily.Monospace,
                                            fontSize = 12.sp,
                                            fontWeight = FontWeight.SemiBold
                                        )
                                        IconButton(
                                            onClick = { copyToClipboard(key.token, "API Key copied to clipboard") },
                                            modifier = Modifier.size(24.dp)
                                        ) {
                                            Icon(Icons.Default.ContentCopy, contentDescription = "Copy", modifier = Modifier.size(14.dp))
                                        }
                                    }
                                }

                                Spacer(modifier = Modifier.height(8.dp))

                                Row(
                                    modifier = Modifier.horizontalScroll(rememberScrollState()),
                                    horizontalArrangement = Arrangement.spacedBy(4.dp)
                                ) {
                                    key.scopes.forEach { scope ->
                                        Surface(
                                            shape = RoundedCornerShape(6.dp),
                                            color = MaterialTheme.colorScheme.primaryContainer.copy(alpha = 0.6f)
                                        ) {
                                            Text(
                                                text = scope.code,
                                                fontSize = 10.5.sp,
                                                fontWeight = FontWeight.Bold,
                                                color = MaterialTheme.colorScheme.onPrimaryContainer,
                                                modifier = Modifier.padding(horizontal = 6.dp, vertical = 2.dp)
                                            )
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // Endpoints Explorer
                    item {
                        Spacer(modifier = Modifier.height(18.dp))
                        Column(modifier = Modifier.padding(horizontal = horizontalPadding)) {
                            Text(
                                text = "REST API Endpoints & Code Snippets",
                                fontSize = 15.sp,
                                fontWeight = FontWeight.Bold,
                                color = MaterialTheme.colorScheme.onBackground
                            )
                            Spacer(modifier = Modifier.height(4.dp))
                            Text(
                                text = "Standard JSON endpoints with full CORS & Bearer Token authentication:",
                                fontSize = 12.sp,
                                color = MaterialTheme.colorScheme.onSurfaceVariant
                            )
                            Spacer(modifier = Modifier.height(10.dp))
                        }
                    }

                    items(ExternalAppAndMcpService.apiEndpoints, key = { it.path }) { endpoint ->
                        Surface(
                            shape = RoundedCornerShape(14.dp),
                            color = MaterialTheme.colorScheme.surface,
                            border = BorderStroke(1.dp, MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.5f)),
                            modifier = Modifier
                                .fillMaxWidth()
                                .padding(horizontal = horizontalPadding, vertical = 5.dp)
                        ) {
                            Column(modifier = Modifier.padding(14.dp)) {
                                Row(
                                    verticalAlignment = Alignment.CenterVertically,
                                    horizontalArrangement = Arrangement.SpaceBetween,
                                    modifier = Modifier.fillMaxWidth()
                                ) {
                                    Row(verticalAlignment = Alignment.CenterVertically) {
                                        Surface(
                                            shape = RoundedCornerShape(6.dp),
                                            color = if (endpoint.method == "GET") Color(0xFF2E7D32) else Color(0xFF1565C0)
                                        ) {
                                            Text(
                                                text = endpoint.method,
                                                color = Color.White,
                                                fontSize = 11.sp,
                                                fontWeight = FontWeight.Black,
                                                modifier = Modifier.padding(horizontal = 8.dp, vertical = 3.dp)
                                            )
                                        }
                                        Spacer(modifier = Modifier.width(8.dp))
                                        Text(
                                            text = endpoint.path,
                                            fontFamily = FontFamily.Monospace,
                                            fontWeight = FontWeight.Bold,
                                            fontSize = 13.sp
                                        )
                                    }

                                    OutlinedButton(
                                        onClick = {
                                            showCodeSnippetDialog = endpoint
                                            selectedCodeLanguage = "curl"
                                        },
                                        contentPadding = PaddingValues(horizontal = 10.dp, vertical = 4.dp),
                                        shape = RoundedCornerShape(10.dp),
                                        modifier = Modifier.defaultMinSize(minHeight = 32.dp)
                                    ) {
                                        Icon(Icons.Default.Code, contentDescription = null, modifier = Modifier.size(14.dp))
                                        Spacer(modifier = Modifier.width(4.dp))
                                        Text("Code Snippet", fontSize = 11.5.sp, fontWeight = FontWeight.Bold)
                                    }
                                }

                                Spacer(modifier = Modifier.height(6.dp))

                                Text(
                                    text = endpoint.summary,
                                    fontSize = 12.5.sp,
                                    fontWeight = FontWeight.SemiBold,
                                    color = MaterialTheme.colorScheme.onSurface
                                )
                                Text(
                                    text = endpoint.description,
                                    fontSize = 11.5.sp,
                                    color = MaterialTheme.colorScheme.onSurfaceVariant
                                )
                            }
                        }
                    }
                }

                IntegrationsTab.WEBHOOKS -> {
                    // Outgoing Webhooks Section
                    item {
                        Column(modifier = Modifier.padding(horizontal = horizontalPadding)) {
                            Row(
                                modifier = Modifier.fillMaxWidth(),
                                verticalAlignment = Alignment.CenterVertically,
                                horizontalArrangement = Arrangement.SpaceBetween
                            ) {
                                Text(
                                    text = "Outgoing Webhooks (${webhooks.size})",
                                    fontSize = 15.sp,
                                    fontWeight = FontWeight.Bold,
                                    color = MaterialTheme.colorScheme.onBackground
                                )
                                Button(
                                    onClick = {
                                        newWebhookUrl = ""
                                        selectedWebhookEvents = setOf(WebhookEvent.BOOKING_CONFIRMED)
                                        showAddWebhookDialog = true
                                    },
                                    contentPadding = PaddingValues(horizontal = 12.dp, vertical = 6.dp),
                                    shape = RoundedCornerShape(12.dp),
                                    modifier = Modifier.defaultMinSize(minHeight = 36.dp)
                                ) {
                                    Icon(Icons.Default.Add, contentDescription = null, modifier = Modifier.size(16.dp))
                                    Spacer(modifier = Modifier.width(4.dp))
                                    Text("Add Webhook", fontSize = 12.5.sp, fontWeight = FontWeight.Bold)
                                }
                            }
                            Spacer(modifier = Modifier.height(8.dp))
                        }
                    }

                    items(webhooks, key = { it.id }) { webhook ->
                        Surface(
                            shape = RoundedCornerShape(14.dp),
                            color = MaterialTheme.colorScheme.surface,
                            border = BorderStroke(1.dp, MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.5f)),
                            modifier = Modifier
                                .fillMaxWidth()
                                .padding(horizontal = horizontalPadding, vertical = 5.dp)
                        ) {
                            Column(modifier = Modifier.padding(14.dp)) {
                                Row(
                                    verticalAlignment = Alignment.CenterVertically,
                                    horizontalArrangement = Arrangement.SpaceBetween,
                                    modifier = Modifier.fillMaxWidth()
                                ) {
                                    Row(
                                        verticalAlignment = Alignment.CenterVertically,
                                        modifier = Modifier.weight(1f)
                                    ) {
                                        Text("🪝", fontSize = 16.sp)
                                        Spacer(modifier = Modifier.width(8.dp))
                                        Text(
                                            text = webhook.targetUrl,
                                            fontFamily = FontFamily.Monospace,
                                            fontSize = 12.sp,
                                            fontWeight = FontWeight.Bold,
                                            maxLines = 1,
                                            overflow = TextOverflow.Ellipsis
                                        )
                                    }

                                    IconButton(
                                        onClick = { ExternalAppAndMcpService.deleteWebhook(webhook.id) },
                                        modifier = Modifier.size(28.dp)
                                    ) {
                                        Icon(Icons.Default.Delete, contentDescription = "Delete", tint = MaterialTheme.colorScheme.error, modifier = Modifier.size(16.dp))
                                    }
                                }

                                Spacer(modifier = Modifier.height(6.dp))

                                Row(
                                    modifier = Modifier.horizontalScroll(rememberScrollState()),
                                    horizontalArrangement = Arrangement.spacedBy(4.dp)
                                ) {
                                    webhook.subscribedEvents.forEach { ev ->
                                        Surface(
                                            shape = RoundedCornerShape(6.dp),
                                            color = MaterialTheme.colorScheme.secondaryContainer.copy(alpha = 0.7f)
                                        ) {
                                            Text(
                                                text = ev.eventName,
                                                fontSize = 10.5.sp,
                                                fontWeight = FontWeight.Bold,
                                                color = MaterialTheme.colorScheme.onSecondaryContainer,
                                                modifier = Modifier.padding(horizontal = 6.dp, vertical = 2.dp)
                                            )
                                        }
                                    }
                                }

                                Spacer(modifier = Modifier.height(10.dp))

                                Row(
                                    modifier = Modifier.fillMaxWidth(),
                                    horizontalArrangement = Arrangement.SpaceBetween,
                                    verticalAlignment = Alignment.CenterVertically
                                ) {
                                    Text(
                                        text = if (webhook.lastDeliveredAt != null) "Last ping: Delivered OK" else "Pending first event",
                                        fontSize = 11.sp,
                                        color = MaterialTheme.colorScheme.onSurfaceVariant
                                    )

                                    FilledTonalButton(
                                        onClick = {
                                            val log = ExternalAppAndMcpService.testFireWebhook(webhook)
                                            Toast.makeText(context, "Test ping dispatched! (Status: ${log.httpStatusCode})", Toast.LENGTH_SHORT).show()
                                        },
                                        contentPadding = PaddingValues(horizontal = 10.dp, vertical = 4.dp),
                                        shape = RoundedCornerShape(10.dp),
                                        modifier = Modifier.defaultMinSize(minHeight = 32.dp)
                                    ) {
                                        Icon(Icons.Default.Send, contentDescription = null, modifier = Modifier.size(13.dp))
                                        Spacer(modifier = Modifier.width(4.dp))
                                        Text("Send Test Ping", fontSize = 11.5.sp, fontWeight = FontWeight.Bold)
                                    }
                                }
                            }
                        }
                    }

                    // Delivery Logs Section
                    if (webhookLogs.isNotEmpty()) {
                        item {
                            Spacer(modifier = Modifier.height(16.dp))
                            Column(modifier = Modifier.padding(horizontal = horizontalPadding)) {
                                Text(
                                    text = "Recent Delivery Logs",
                                    fontSize = 14.5.sp,
                                    fontWeight = FontWeight.Bold,
                                    color = MaterialTheme.colorScheme.onBackground
                                )
                                Spacer(modifier = Modifier.height(6.dp))
                            }
                        }

                        items(webhookLogs.take(5), key = { it.id }) { log ->
                            Surface(
                                shape = RoundedCornerShape(10.dp),
                                color = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.4f),
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .padding(horizontal = horizontalPadding, vertical = 3.dp)
                            ) {
                                Row(
                                    modifier = Modifier.padding(10.dp),
                                    verticalAlignment = Alignment.CenterVertically,
                                    horizontalArrangement = Arrangement.SpaceBetween
                                ) {
                                    Row(verticalAlignment = Alignment.CenterVertically) {
                                        Surface(
                                            shape = RoundedCornerShape(4.dp),
                                            color = Color(0xFF2E7D32)
                                        ) {
                                            Text(
                                                text = "${log.httpStatusCode}",
                                                color = Color.White,
                                                fontSize = 10.sp,
                                                fontWeight = FontWeight.Black,
                                                modifier = Modifier.padding(horizontal = 5.dp, vertical = 2.dp)
                                            )
                                        }
                                        Spacer(modifier = Modifier.width(8.dp))
                                        Column {
                                            Text(
                                                text = log.event.eventName,
                                                fontWeight = FontWeight.Bold,
                                                fontSize = 12.sp
                                            )
                                            Text(
                                                text = "${log.latencyMs}ms latency • ${log.targetUrl.take(28)}...",
                                                fontSize = 10.5.sp,
                                                color = MaterialTheme.colorScheme.onSurfaceVariant
                                            )
                                        }
                                    }

                                    IconButton(
                                        onClick = { copyToClipboard(log.payloadJson, "Copied payload JSON") },
                                        modifier = Modifier.size(24.dp)
                                    ) {
                                        Icon(Icons.Default.ContentCopy, contentDescription = "Copy payload", modifier = Modifier.size(13.dp))
                                    }
                                }
                            }
                        }
                    }
                }

                IntegrationsTab.CONNECTED_APPS -> {
                    // Google Calendar & Outlook Sync Banner
                    item {
                        Surface(
                            shape = RoundedCornerShape(16.dp),
                            color = MaterialTheme.colorScheme.surface,
                            border = BorderStroke(1.dp, MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.5f)),
                            modifier = Modifier
                                .fillMaxWidth()
                                .padding(horizontal = horizontalPadding, vertical = 6.dp)
                        ) {
                            Column(modifier = Modifier.padding(16.dp)) {
                                Row(
                                    verticalAlignment = Alignment.CenterVertically,
                                    horizontalArrangement = Arrangement.SpaceBetween,
                                    modifier = Modifier.fillMaxWidth()
                                ) {
                                    Row(verticalAlignment = Alignment.CenterVertically) {
                                        Text("📅", fontSize = 24.sp)
                                        Spacer(modifier = Modifier.width(10.dp))
                                        Column {
                                            Text(
                                                text = "Calendar Feed Sync (.ics)",
                                                fontWeight = FontWeight.Bold,
                                                fontSize = 15.sp
                                            )
                                            Text(
                                                text = "Auto-sync bookings with Google Calendar & Outlook",
                                                fontSize = 11.5.sp,
                                                color = MaterialTheme.colorScheme.onSurfaceVariant
                                            )
                                        }
                                    }
                                }

                                Spacer(modifier = Modifier.height(12.dp))

                                Row(
                                    modifier = Modifier.fillMaxWidth(),
                                    horizontalArrangement = Arrangement.spacedBy(8.dp)
                                ) {
                                    Button(
                                        onClick = {
                                            val icsContent = ExternalAppAndMcpService.generateIcsCalendarContent(bookings)
                                            copyToClipboard(icsContent, "iCalendar .ics feed copied!")
                                        },
                                        modifier = Modifier.weight(1f),
                                        shape = RoundedCornerShape(12.dp)
                                    ) {
                                        Icon(Icons.Default.Download, contentDescription = null, modifier = Modifier.size(16.dp))
                                        Spacer(modifier = Modifier.width(6.dp))
                                        Text("Copy .ics Feed", fontSize = 12.sp, fontWeight = FontWeight.Bold)
                                    }

                                    OutlinedButton(
                                        onClick = {
                                            copyToClipboard("https://api.bookmyspace.app/v1/calendar/feed.ics?token=bms_live_agent", "Subscribed feed URL copied!")
                                        },
                                        modifier = Modifier.weight(1f),
                                        shape = RoundedCornerShape(12.dp)
                                    ) {
                                        Icon(Icons.Default.Link, contentDescription = null, modifier = Modifier.size(16.dp))
                                        Spacer(modifier = Modifier.width(6.dp))
                                        Text("Subscribe URL", fontSize = 12.sp, fontWeight = FontWeight.Bold)
                                    }
                                }
                            }
                        }
                    }

                    // Android Deep Links & App-to-App Intents Hub
                    item {
                        Spacer(modifier = Modifier.height(14.dp))
                        Column(modifier = Modifier.padding(horizontal = horizontalPadding)) {
                            Text(
                                text = "Android Deep Links & App Intents",
                                fontSize = 15.sp,
                                fontWeight = FontWeight.Bold,
                                color = MaterialTheme.colorScheme.onBackground
                            )
                            Spacer(modifier = Modifier.height(4.dp))
                            Text(
                                text = "External apps and websites can launch BookMySpace directly with parameters:",
                                fontSize = 12.sp,
                                color = MaterialTheme.colorScheme.onSurfaceVariant
                            )
                            Spacer(modifier = Modifier.height(10.dp))

                            val sampleDeepLinks = listOf(
                                "bookmyspace://search?category=hotel" to "Search Hotel Rooms",
                                "bookmyspace://search?category=venue" to "Search Function Halls",
                                "bookmyspace://venues/v1" to "Open Venue Details (v1)",
                                "bookmyspace://venues/v1/book" to "Open Direct Slot Booking",
                                "bookmyspace://bookings" to "Open My Active Passes"
                            )

                            sampleDeepLinks.forEach { (link, label) ->
                                Surface(
                                    shape = RoundedCornerShape(12.dp),
                                    color = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.4f),
                                    modifier = Modifier
                                        .fillMaxWidth()
                                        .padding(vertical = 3.dp)
                                ) {
                                    Row(
                                        modifier = Modifier.padding(10.dp),
                                        verticalAlignment = Alignment.CenterVertically,
                                        horizontalArrangement = Arrangement.SpaceBetween
                                    ) {
                                        Column(modifier = Modifier.weight(1f)) {
                                            Text(
                                                text = label,
                                                fontWeight = FontWeight.Bold,
                                                fontSize = 12.5.sp
                                            )
                                            Text(
                                                text = link,
                                                fontFamily = FontFamily.Monospace,
                                                fontSize = 11.sp,
                                                color = MaterialTheme.colorScheme.primary
                                            )
                                        }
                                        Row {
                                            IconButton(
                                                onClick = { copyToClipboard(link, "Deep link copied") },
                                                modifier = Modifier.size(28.dp)
                                            ) {
                                                Icon(Icons.Default.ContentCopy, contentDescription = "Copy", modifier = Modifier.size(14.dp))
                                            }
                                            IconButton(
                                                onClick = {
                                                    Toast.makeText(context, "Testing Intent: $link", Toast.LENGTH_SHORT).show()
                                                },
                                                modifier = Modifier.size(28.dp)
                                            ) {
                                                Icon(Icons.Default.PlayArrow, contentDescription = "Test", tint = MaterialTheme.colorScheme.primary, modifier = Modifier.size(16.dp))
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // Connected Third-Party Automation Hubs
                    item {
                        Spacer(modifier = Modifier.height(16.dp))
                        Column(modifier = Modifier.padding(horizontal = horizontalPadding)) {
                            Text(
                                text = "Automation Connectors",
                                fontSize = 15.sp,
                                fontWeight = FontWeight.Bold,
                                color = MaterialTheme.colorScheme.onBackground
                            )
                            Spacer(modifier = Modifier.height(8.dp))
                        }
                    }

                    items(connectedApps, key = { it.connectorType.id }) { app ->
                        Surface(
                            shape = RoundedCornerShape(14.dp),
                            color = MaterialTheme.colorScheme.surface,
                            border = BorderStroke(1.dp, MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.5f)),
                            modifier = Modifier
                                .fillMaxWidth()
                                .padding(horizontal = horizontalPadding, vertical = 4.dp)
                        ) {
                            Row(
                                modifier = Modifier.padding(14.dp),
                                verticalAlignment = Alignment.CenterVertically,
                                horizontalArrangement = Arrangement.SpaceBetween
                            ) {
                                Row(
                                    verticalAlignment = Alignment.CenterVertically,
                                    modifier = Modifier.weight(1f)
                                ) {
                                    Text(app.connectorType.iconEmoji, fontSize = 20.sp)
                                    Spacer(modifier = Modifier.width(10.dp))
                                    Column {
                                        Text(
                                            text = app.connectorType.title,
                                            fontWeight = FontWeight.Bold,
                                            fontSize = 13.5.sp
                                        )
                                        Text(
                                            text = app.connectorType.category,
                                            fontSize = 11.5.sp,
                                            color = MaterialTheme.colorScheme.onSurfaceVariant
                                        )
                                    }
                                }

                                Surface(
                                    shape = RoundedCornerShape(8.dp),
                                    color = if (app.isConnected) Color(0xFF2E7D32).copy(alpha = 0.15f) else MaterialTheme.colorScheme.surfaceVariant
                                ) {
                                    Text(
                                        text = if (app.isConnected) "CONNECTED" else "AVAILABLE",
                                        color = if (app.isConnected) Color(0xFF2E7D32) else MaterialTheme.colorScheme.onSurfaceVariant,
                                        fontSize = 10.5.sp,
                                        fontWeight = FontWeight.Bold,
                                        modifier = Modifier.padding(horizontal = 8.dp, vertical = 3.dp)
                                    )
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // ==========================================
    // DIALOG: MCP CLIENT CONFIGURATION VIEWER
    // ==========================================
    if (activeConfigDialogType != null) {
        val configText = when (activeConfigDialogType) {
            "claude" -> ExternalAppAndMcpService.generateClaudeDesktopConfig()
            "cursor" -> ExternalAppAndMcpService.generateCursorMcpConfig()
            "gemini" -> ExternalAppAndMcpService.generateGeminiOpenAiSchemaJson()
            else -> ""
        }
        val title = when (activeConfigDialogType) {
            "claude" -> "Claude Desktop MCP Configuration"
            "cursor" -> "Cursor / VS Code MCP SSE Config"
            "gemini" -> "Gemini / OpenAI Agent Tool Schemas"
            else -> "Configuration"
        }

        Dialog(onDismissRequest = { activeConfigDialogType = null }) {
            Surface(
                shape = RoundedCornerShape(20.dp),
                color = MaterialTheme.colorScheme.surface,
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(16.dp)
            ) {
                Column(modifier = Modifier.padding(20.dp)) {
                    Text(
                        text = title,
                        fontWeight = FontWeight.Bold,
                        fontSize = 16.sp
                    )
                    Spacer(modifier = Modifier.height(4.dp))
                    Text(
                        text = "Paste this into your client configuration file to give your AI agent access to BookMySpace:",
                        fontSize = 12.sp,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                    Spacer(modifier = Modifier.height(12.dp))

                    Surface(
                        shape = RoundedCornerShape(12.dp),
                        color = Color(0xFF1E1E1E),
                        modifier = Modifier
                            .fillMaxWidth()
                            .heightIn(max = 240.dp)
                    ) {
                        LazyColumn(modifier = Modifier.padding(12.dp)) {
                            item {
                                Text(
                                    text = configText,
                                    fontFamily = FontFamily.Monospace,
                                    fontSize = 11.sp,
                                    color = Color(0xFF81C784)
                                )
                            }
                        }
                    }

                    Spacer(modifier = Modifier.height(16.dp))

                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.End
                    ) {
                        TextButton(onClick = { activeConfigDialogType = null }) {
                            Text("Close")
                        }
                        Spacer(modifier = Modifier.width(8.dp))
                        Button(
                            onClick = {
                                copyToClipboard(configText, "Config JSON copied to clipboard")
                                activeConfigDialogType = null
                            },
                            shape = RoundedCornerShape(12.dp)
                        ) {
                            Icon(Icons.Default.ContentCopy, contentDescription = null, modifier = Modifier.size(16.dp))
                            Spacer(modifier = Modifier.width(6.dp))
                            Text("Copy JSON", fontWeight = FontWeight.Bold)
                        }
                    }
                }
            }
        }
    }

    // ==========================================
    // DIALOG: MCP TOOL TESTER & RUNNER
    // ==========================================
    if (testingMcpTool != null) {
        val tool = testingMcpTool!!
        Dialog(onDismissRequest = { testingMcpTool = null }) {
            Surface(
                shape = RoundedCornerShape(20.dp),
                color = MaterialTheme.colorScheme.surface,
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(16.dp)
            ) {
                Column(modifier = Modifier.padding(18.dp)) {
                    Row(
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.SpaceBetween,
                        modifier = Modifier.fillMaxWidth()
                    ) {
                        Column {
                            Text(
                                text = "⚡ Test MCP Tool",
                                fontSize = 13.sp,
                                color = MaterialTheme.colorScheme.primary,
                                fontWeight = FontWeight.Bold
                            )
                            Text(
                                text = tool.name,
                                fontWeight = FontWeight.Black,
                                fontSize = 16.sp
                            )
                        }
                        IconButton(onClick = { testingMcpTool = null }) {
                            Icon(Icons.Default.Close, contentDescription = "Close")
                        }
                    }

                    Spacer(modifier = Modifier.height(8.dp))

                    Text(
                        text = "Input Arguments (JSON):",
                        fontSize = 12.sp,
                        fontWeight = FontWeight.Bold
                    )
                    Spacer(modifier = Modifier.height(4.dp))
                    OutlinedTextField(
                        value = testingToolInputText,
                        onValueChange = { testingToolInputText = it },
                        modifier = Modifier
                            .fillMaxWidth()
                            .height(110.dp),
                        textStyle = androidx.compose.ui.text.TextStyle(
                            fontFamily = FontFamily.Monospace,
                            fontSize = 11.5.sp
                        ),
                        shape = RoundedCornerShape(12.dp)
                    )

                    Spacer(modifier = Modifier.height(10.dp))

                    Button(
                        onClick = {
                            isExecutingTool = true
                            lastExecutionResult = ExternalAppAndMcpService.executeMcpTool(tool.name, testingToolInputText)
                            isExecutingTool = false
                        },
                        modifier = Modifier.fillMaxWidth(),
                        shape = RoundedCornerShape(12.dp)
                    ) {
                        Icon(Icons.Default.PlayArrow, contentDescription = null, modifier = Modifier.size(16.dp))
                        Spacer(modifier = Modifier.width(6.dp))
                        Text("Execute Tool Live", fontWeight = FontWeight.Bold)
                    }

                    if (lastExecutionResult != null) {
                        val res = lastExecutionResult!!
                        Spacer(modifier = Modifier.height(10.dp))
                        Row(
                            verticalAlignment = Alignment.CenterVertically,
                            horizontalArrangement = Arrangement.SpaceBetween,
                            modifier = Modifier.fillMaxWidth()
                        ) {
                            Text(
                                text = "Response (${res.executionTimeMs}ms):",
                                fontSize = 12.sp,
                                fontWeight = FontWeight.Bold
                            )
                            IconButton(
                                onClick = { copyToClipboard(res.outputJson, "Copied response JSON") },
                                modifier = Modifier.size(24.dp)
                            ) {
                                Icon(Icons.Default.ContentCopy, contentDescription = "Copy", modifier = Modifier.size(14.dp))
                            }
                        }
                        Spacer(modifier = Modifier.height(4.dp))
                        Surface(
                            shape = RoundedCornerShape(10.dp),
                            color = Color(0xFF1E1E1E),
                            modifier = Modifier
                                .fillMaxWidth()
                                .heightIn(max = 140.dp)
                        ) {
                            LazyColumn(modifier = Modifier.padding(10.dp)) {
                                item {
                                    Text(
                                        text = res.outputJson,
                                        fontFamily = FontFamily.Monospace,
                                        fontSize = 10.5.sp,
                                        color = if (res.isSuccess) Color(0xFF81C784) else Color(0xFFE57373)
                                    )
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // ==========================================
    // DIALOG: CREATE API KEY
    // ==========================================
    if (showCreateApiKeyDialog) {
        Dialog(onDismissRequest = { showCreateApiKeyDialog = false }) {
            Surface(
                shape = RoundedCornerShape(20.dp),
                color = MaterialTheme.colorScheme.surface,
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(16.dp)
            ) {
                Column(modifier = Modifier.padding(20.dp)) {
                    Text(
                        text = "Generate New API Token",
                        fontWeight = FontWeight.Bold,
                        fontSize = 16.sp
                    )
                    Spacer(modifier = Modifier.height(10.dp))

                    OutlinedTextField(
                        value = newKeyName,
                        onValueChange = { newKeyName = it },
                        label = { Text("Token Name / Application") },
                        placeholder = { Text("e.g. My Zapier Integration") },
                        modifier = Modifier.fillMaxWidth(),
                        shape = RoundedCornerShape(12.dp)
                    )

                    Spacer(modifier = Modifier.height(12.dp))
                    Text("Select Allowed Scopes:", fontSize = 12.sp, fontWeight = FontWeight.Bold)
                    Spacer(modifier = Modifier.height(6.dp))

                    ApiKeyScope.values().forEach { scope ->
                        val isSelected = selectedKeyScopes.contains(scope)
                        Row(
                            verticalAlignment = Alignment.CenterVertically,
                            modifier = Modifier
                                .fillMaxWidth()
                                .padding(vertical = 2.dp)
                        ) {
                            Checkbox(
                                checked = isSelected,
                                onCheckedChange = {
                                    selectedKeyScopes = if (isSelected) selectedKeyScopes - scope else selectedKeyScopes + scope
                                }
                            )
                            Column {
                                Text(scope.displayName, fontSize = 12.5.sp, fontWeight = FontWeight.SemiBold)
                                Text(scope.code, fontSize = 10.5.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                            }
                        }
                    }

                    Spacer(modifier = Modifier.height(16.dp))

                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.End
                    ) {
                        TextButton(onClick = { showCreateApiKeyDialog = false }) {
                            Text("Cancel")
                        }
                        Spacer(modifier = Modifier.width(8.dp))
                        Button(
                            onClick = {
                                val newKey = ExternalAppAndMcpService.createApiKey(newKeyName, selectedKeyScopes)
                                copyToClipboard(newKey.token, "New API Key generated & copied!")
                                showCreateApiKeyDialog = false
                            },
                            shape = RoundedCornerShape(12.dp)
                        ) {
                            Text("Generate & Copy", fontWeight = FontWeight.Bold)
                        }
                    }
                }
            }
        }
    }

    // ==========================================
    // DIALOG: ADD WEBHOOK
    // ==========================================
    if (showAddWebhookDialog) {
        Dialog(onDismissRequest = { showAddWebhookDialog = false }) {
            Surface(
                shape = RoundedCornerShape(20.dp),
                color = MaterialTheme.colorScheme.surface,
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(16.dp)
            ) {
                Column(modifier = Modifier.padding(20.dp)) {
                    Text(
                        text = "Add Webhook Subscription",
                        fontWeight = FontWeight.Bold,
                        fontSize = 16.sp
                    )
                    Spacer(modifier = Modifier.height(10.dp))

                    OutlinedTextField(
                        value = newWebhookUrl,
                        onValueChange = { newWebhookUrl = it },
                        label = { Text("Webhook Destination URL") },
                        placeholder = { Text("https://hooks.zapier.com/...") },
                        modifier = Modifier.fillMaxWidth(),
                        shape = RoundedCornerShape(12.dp)
                    )

                    Spacer(modifier = Modifier.height(12.dp))
                    Text("Trigger on Events:", fontSize = 12.sp, fontWeight = FontWeight.Bold)
                    Spacer(modifier = Modifier.height(6.dp))

                    WebhookEvent.values().forEach { ev ->
                        val isSelected = selectedWebhookEvents.contains(ev)
                        Row(
                            verticalAlignment = Alignment.CenterVertically,
                            modifier = Modifier
                                .fillMaxWidth()
                                .padding(vertical = 2.dp)
                        ) {
                            Checkbox(
                                checked = isSelected,
                                onCheckedChange = {
                                    selectedWebhookEvents = if (isSelected) selectedWebhookEvents - ev else selectedWebhookEvents + ev
                                }
                            )
                            Column {
                                Text(ev.displayName, fontSize = 12.5.sp, fontWeight = FontWeight.SemiBold)
                                Text(ev.eventName, fontSize = 10.5.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                            }
                        }
                    }

                    Spacer(modifier = Modifier.height(16.dp))

                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.End
                    ) {
                        TextButton(onClick = { showAddWebhookDialog = false }) {
                            Text("Cancel")
                        }
                        Spacer(modifier = Modifier.width(8.dp))
                        Button(
                            onClick = {
                                if (newWebhookUrl.isNotBlank()) {
                                    ExternalAppAndMcpService.addWebhook(newWebhookUrl, selectedWebhookEvents)
                                    Toast.makeText(context, "Webhook subscription added!", Toast.LENGTH_SHORT).show()
                                    showAddWebhookDialog = false
                                }
                            },
                            shape = RoundedCornerShape(12.dp)
                        ) {
                            Text("Save Webhook", fontWeight = FontWeight.Bold)
                        }
                    }
                }
            }
        }
    }

    // ==========================================
    // DIALOG: CODE SNIPPET EXPLORER
    // ==========================================
    if (showCodeSnippetDialog != null) {
        val endpoint = showCodeSnippetDialog!!
        val code = when (selectedCodeLanguage) {
            "curl" -> ExternalAppAndMcpService.generateCurlCommand(endpoint)
            "python" -> ExternalAppAndMcpService.generatePythonCode(endpoint)
            "javascript" -> ExternalAppAndMcpService.generateJavaScriptCode(endpoint)
            else -> ""
        }

        Dialog(onDismissRequest = { showCodeSnippetDialog = null }) {
            Surface(
                shape = RoundedCornerShape(20.dp),
                color = MaterialTheme.colorScheme.surface,
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(16.dp)
            ) {
                Column(modifier = Modifier.padding(20.dp)) {
                    Text(
                        text = "Code Generator: ${endpoint.method} ${endpoint.path}",
                        fontWeight = FontWeight.Bold,
                        fontSize = 15.sp
                    )
                    Spacer(modifier = Modifier.height(8.dp))

                    Row(
                        horizontalArrangement = Arrangement.spacedBy(6.dp),
                        modifier = Modifier.fillMaxWidth()
                    ) {
                        listOf("curl" to "cURL", "python" to "Python", "javascript" to "JavaScript").forEach { (id, label) ->
                            FilterChip(
                                selected = selectedCodeLanguage == id,
                                onClick = { selectedCodeLanguage = id },
                                label = { Text(label, fontSize = 11.5.sp) },
                                shape = RoundedCornerShape(12.dp)
                            )
                        }
                    }

                    Spacer(modifier = Modifier.height(10.dp))

                    Surface(
                        shape = RoundedCornerShape(12.dp),
                        color = Color(0xFF1E1E1E),
                        modifier = Modifier
                            .fillMaxWidth()
                            .heightIn(max = 200.dp)
                    ) {
                        LazyColumn(modifier = Modifier.padding(12.dp)) {
                            item {
                                Text(
                                    text = code,
                                    fontFamily = FontFamily.Monospace,
                                    fontSize = 11.sp,
                                    color = Color(0xFF80D8FF)
                                )
                            }
                        }
                    }

                    Spacer(modifier = Modifier.height(16.dp))

                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.End
                    ) {
                        TextButton(onClick = { showCodeSnippetDialog = null }) {
                            Text("Close")
                        }
                        Spacer(modifier = Modifier.width(8.dp))
                        Button(
                            onClick = {
                                copyToClipboard(code, "Code snippet copied!")
                                showCodeSnippetDialog = null
                            },
                            shape = RoundedCornerShape(12.dp)
                        ) {
                            Icon(Icons.Default.ContentCopy, contentDescription = null, modifier = Modifier.size(16.dp))
                            Spacer(modifier = Modifier.width(6.dp))
                            Text("Copy Code", fontWeight = FontWeight.Bold)
                        }
                    }
                }
            }
        }
    }

    // ==========================================
    // DIALOG: ADD / EDIT CUSTOM SITE INTEGRATION
    // ==========================================
    if (showAddCustomSiteDialog || editingCustomSite != null) {
        val initialSite = editingCustomSite
        var siteName by remember(initialSite) { mutableStateOf(initialSite?.name ?: "") }
        var siteUrl by remember(initialSite) { mutableStateOf(initialSite?.siteUrl ?: "https://") }
        var selectedCategory by remember(initialSite) { mutableStateOf(initialSite?.category ?: CustomSiteCategory.STORE_COMMERCE) }
        var selectedAuthType by remember(initialSite) { mutableStateOf(initialSite?.authType ?: SiteAuthType.BEARER_TOKEN) }
        var authHeaderKey by remember(initialSite) { mutableStateOf(initialSite?.authHeaderKey ?: "Authorization") }
        var authHeaderValue by remember(initialSite) { mutableStateOf(initialSite?.authHeaderValue ?: "") }
        var selectedSyncMode by remember(initialSite) { mutableStateOf(initialSite?.syncMode ?: SiteSyncMode.ON_DEMAND) }
        var siteDescription by remember(initialSite) { mutableStateOf(initialSite?.description ?: "") }
        var iconEmoji by remember(initialSite) { mutableStateOf(initialSite?.iconEmoji ?: selectedCategory.iconEmoji) }

        Dialog(onDismissRequest = {
            showAddCustomSiteDialog = false
            editingCustomSite = null
        }) {
            Surface(
                shape = RoundedCornerShape(20.dp),
                color = MaterialTheme.colorScheme.surface,
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(12.dp)
            ) {
                LazyColumn(modifier = Modifier.padding(18.dp)) {
                    item {
                        Text(
                            text = if (initialSite?.id?.isNotBlank() == true && initialSite.id.startsWith("site_")) "Edit Site Integration" else "Connect External Site / MCP / API",
                            fontWeight = FontWeight.Bold,
                            fontSize = 16.sp
                        )
                        Spacer(modifier = Modifier.height(4.dp))
                        Text(
                            text = "Connect any store, scheduling page, MCP server or REST API with zero performance loss.",
                            fontSize = 11.5.sp,
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                        Spacer(modifier = Modifier.height(12.dp))
                    }

                    item {
                        OutlinedTextField(
                            value = siteName,
                            onValueChange = { siteName = it },
                            label = { Text("Site / Service Name") },
                            placeholder = { Text("e.g. Shopify Merch Store") },
                            modifier = Modifier
                                .fillMaxWidth()
                                .testTag("input_custom_site_name"),
                            shape = RoundedCornerShape(12.dp),
                            singleLine = true
                        )
                        Spacer(modifier = Modifier.height(8.dp))
                    }

                    item {
                        OutlinedTextField(
                            value = siteUrl,
                            onValueChange = { siteUrl = it },
                            label = { Text("Target URL / Endpoint") },
                            placeholder = { Text("https://...") },
                            modifier = Modifier
                                .fillMaxWidth()
                                .testTag("input_custom_site_url"),
                            shape = RoundedCornerShape(12.dp),
                            singleLine = true
                        )
                        Spacer(modifier = Modifier.height(10.dp))
                    }

                    item {
                        Text("Category Type:", fontSize = 12.sp, fontWeight = FontWeight.Bold)
                        Spacer(modifier = Modifier.height(6.dp))
                        LazyRow(
                            horizontalArrangement = Arrangement.spacedBy(6.dp),
                            modifier = Modifier.fillMaxWidth()
                        ) {
                            items(CustomSiteCategory.entries) { cat ->
                                FilterChip(
                                    selected = selectedCategory == cat,
                                    onClick = {
                                        selectedCategory = cat
                                        iconEmoji = cat.iconEmoji
                                    },
                                    label = {
                                        Text("${cat.iconEmoji} ${cat.title}", fontSize = 11.sp)
                                    },
                                    shape = RoundedCornerShape(10.dp)
                                )
                            }
                        }
                        Spacer(modifier = Modifier.height(10.dp))
                    }

                    item {
                        Text("Authentication Type:", fontSize = 12.sp, fontWeight = FontWeight.Bold)
                        Spacer(modifier = Modifier.height(6.dp))
                        LazyRow(
                            horizontalArrangement = Arrangement.spacedBy(6.dp),
                            modifier = Modifier.fillMaxWidth()
                        ) {
                            items(SiteAuthType.entries) { auth ->
                                FilterChip(
                                    selected = selectedAuthType == auth,
                                    onClick = {
                                        selectedAuthType = auth
                                        if (auth == SiteAuthType.API_KEY) authHeaderKey = "X-Api-Key"
                                        if (auth == SiteAuthType.BEARER_TOKEN) authHeaderKey = "Authorization"
                                    },
                                    label = { Text(auth.title, fontSize = 11.sp) },
                                    shape = RoundedCornerShape(10.dp)
                                )
                            }
                        }
                        Spacer(modifier = Modifier.height(8.dp))
                    }

                    if (selectedAuthType != SiteAuthType.NONE) {
                        item {
                            Row(
                                modifier = Modifier.fillMaxWidth(),
                                horizontalArrangement = Arrangement.spacedBy(8.dp)
                            ) {
                                OutlinedTextField(
                                    value = authHeaderKey,
                                    onValueChange = { authHeaderKey = it },
                                    label = { Text("Header Key") },
                                    modifier = Modifier.weight(1f),
                                    shape = RoundedCornerShape(12.dp),
                                    singleLine = true
                                )
                                OutlinedTextField(
                                    value = authHeaderValue,
                                    onValueChange = { authHeaderValue = it },
                                    label = { Text("Token / Secret") },
                                    modifier = Modifier.weight(1.4f),
                                    shape = RoundedCornerShape(12.dp),
                                    singleLine = true
                                )
                            }
                            Spacer(modifier = Modifier.height(10.dp))
                        }
                    }

                    item {
                        Text("Sync Mode:", fontSize = 12.sp, fontWeight = FontWeight.Bold)
                        Spacer(modifier = Modifier.height(6.dp))
                        LazyRow(
                            horizontalArrangement = Arrangement.spacedBy(6.dp),
                            modifier = Modifier.fillMaxWidth()
                        ) {
                            items(SiteSyncMode.entries) { mode ->
                                FilterChip(
                                    selected = selectedSyncMode == mode,
                                    onClick = { selectedSyncMode = mode },
                                    label = { Text(mode.title, fontSize = 11.sp) },
                                    shape = RoundedCornerShape(10.dp)
                                )
                            }
                        }
                        Spacer(modifier = Modifier.height(10.dp))
                    }

                    item {
                        OutlinedTextField(
                            value = siteDescription,
                            onValueChange = { siteDescription = it },
                            label = { Text("Description & Notes (Optional)") },
                            placeholder = { Text("e.g. Sync inventory every hour") },
                            modifier = Modifier.fillMaxWidth(),
                            shape = RoundedCornerShape(12.dp),
                            maxLines = 2
                        )
                        Spacer(modifier = Modifier.height(16.dp))
                    }

                    item {
                        Row(
                            modifier = Modifier.fillMaxWidth(),
                            horizontalArrangement = Arrangement.End
                        ) {
                            TextButton(onClick = {
                                showAddCustomSiteDialog = false
                                editingCustomSite = null
                            }) {
                                Text("Cancel")
                            }
                            Spacer(modifier = Modifier.width(8.dp))
                            Button(
                                onClick = {
                                    if (siteName.isNotBlank() && siteUrl.isNotBlank()) {
                                        val siteToSave = CustomSiteIntegration(
                                            id = initialSite?.id?.takeIf { it.startsWith("site_") } ?: "site_${System.currentTimeMillis().toString().takeLast(6)}",
                                            name = siteName.trim(),
                                            siteUrl = siteUrl.trim(),
                                            category = selectedCategory,
                                            authType = selectedAuthType,
                                            authHeaderKey = authHeaderKey.trim(),
                                            authHeaderValue = authHeaderValue.trim(),
                                            syncMode = selectedSyncMode,
                                            description = siteDescription.ifBlank { "Integrated ${selectedCategory.title}" },
                                            iconEmoji = iconEmoji,
                                            isEnabled = true,
                                            healthStatus = SiteHealthStatus.HEALTHY,
                                            lastCheckedAt = System.currentTimeMillis()
                                        )

                                        if (initialSite != null && initialSite.id.startsWith("site_")) {
                                            ExternalAppAndMcpService.updateCustomSite(siteToSave)
                                            Toast.makeText(context, "Updated '${siteToSave.name}'", Toast.LENGTH_SHORT).show()
                                        } else {
                                            ExternalAppAndMcpService.addCustomSite(siteToSave)
                                            Toast.makeText(context, "Connected '${siteToSave.name}'!", Toast.LENGTH_SHORT).show()
                                        }

                                        showAddCustomSiteDialog = false
                                        editingCustomSite = null
                                    }
                                },
                                enabled = siteName.isNotBlank() && siteUrl.isNotBlank(),
                                shape = RoundedCornerShape(12.dp),
                                modifier = Modifier.testTag("btn_submit_custom_site_integration")
                            ) {
                                Text("Save & Connect", fontWeight = FontWeight.Bold)
                            }
                        }
                    }
                }
            }
        }
    }

    // ==========================================
    // DIALOG: VIEW SITE SNIPPET & MCP CONFIG
    // ==========================================
    viewingSnippetSite?.let { site ->
        val mcpSnippet = ExternalAppAndMcpService.generateMcpConfigSnippet(site)
        val curlSnippet = ExternalAppAndMcpService.generateCurlSnippet(site)
        var selectedSnippetTab by remember { mutableStateOf("mcp") }

        Dialog(onDismissRequest = { viewingSnippetSite = null }) {
            Surface(
                shape = RoundedCornerShape(20.dp),
                color = MaterialTheme.colorScheme.surface,
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(16.dp)
            ) {
                Column(modifier = Modifier.padding(18.dp)) {
                    Row(
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.SpaceBetween,
                        modifier = Modifier.fillMaxWidth()
                    ) {
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            Text(site.iconEmoji, fontSize = 22.sp)
                            Spacer(modifier = Modifier.width(8.dp))
                            Column {
                                Text(
                                    text = site.name,
                                    fontWeight = FontWeight.Bold,
                                    fontSize = 15.sp
                                )
                                Text(
                                    text = "Integration Snippets",
                                    fontSize = 11.5.sp,
                                    color = MaterialTheme.colorScheme.onSurfaceVariant
                                )
                            }
                        }
                        IconButton(onClick = { viewingSnippetSite = null }) {
                            Icon(Icons.Default.Close, contentDescription = "Close")
                        }
                    }

                    Spacer(modifier = Modifier.height(10.dp))

                    Row(
                        horizontalArrangement = Arrangement.spacedBy(6.dp),
                        modifier = Modifier.fillMaxWidth()
                    ) {
                        FilterChip(
                            selected = selectedSnippetTab == "mcp",
                            onClick = { selectedSnippetTab = "mcp" },
                            label = { Text("MCP Server JSON", fontSize = 11.5.sp) },
                            shape = RoundedCornerShape(10.dp)
                        )
                        FilterChip(
                            selected = selectedSnippetTab == "curl",
                            onClick = { selectedSnippetTab = "curl" },
                            label = { Text("cURL API Request", fontSize = 11.5.sp) },
                            shape = RoundedCornerShape(10.dp)
                        )
                    }

                    Spacer(modifier = Modifier.height(10.dp))

                    val activeSnippet = if (selectedSnippetTab == "mcp") mcpSnippet else curlSnippet

                    Surface(
                        shape = RoundedCornerShape(12.dp),
                        color = Color(0xFF1E1E1E),
                        modifier = Modifier
                            .fillMaxWidth()
                            .heightIn(max = 200.dp)
                    ) {
                        LazyColumn(modifier = Modifier.padding(12.dp)) {
                            item {
                                Text(
                                    text = activeSnippet,
                                    fontFamily = FontFamily.Monospace,
                                    fontSize = 11.sp,
                                    color = Color(0xFF80D8FF)
                                )
                            }
                        }
                    }

                    Spacer(modifier = Modifier.height(14.dp))

                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.End
                    ) {
                        Button(
                            onClick = {
                                copyToClipboard(activeSnippet, "Snippet copied to clipboard!")
                                viewingSnippetSite = null
                            },
                            shape = RoundedCornerShape(12.dp)
                        ) {
                            Icon(Icons.Default.ContentCopy, contentDescription = null, modifier = Modifier.size(16.dp))
                            Spacer(modifier = Modifier.width(6.dp))
                            Text("Copy Snippet", fontWeight = FontWeight.Bold)
                        }
                    }
                }
            }
        }
    }
}

// ==========================================
// SUB-COMPONENTS
// ==========================================

@Composable
fun IntegrationStatusPill(emoji: String, label: String, isActive: Boolean) {
    Surface(
        shape = RoundedCornerShape(10.dp),
        color = MaterialTheme.colorScheme.surface.copy(alpha = 0.8f),
        border = BorderStroke(1.dp, MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.5f))
    ) {
        Row(
            modifier = Modifier.padding(horizontal = 10.dp, vertical = 6.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Text(emoji, fontSize = 12.sp)
            Spacer(modifier = Modifier.width(6.dp))
            Text(
                text = label,
                fontSize = 11.5.sp,
                fontWeight = FontWeight.SemiBold,
                color = MaterialTheme.colorScheme.onSurface
            )
        }
    }
}

@Composable
fun McpClientCard(
    title: String,
    icon: String,
    subtitle: String,
    onClick: () -> Unit,
    modifier: Modifier = Modifier
) {
    Surface(
        onClick = onClick,
        shape = RoundedCornerShape(14.dp),
        color = MaterialTheme.colorScheme.surface,
        border = BorderStroke(1.dp, MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.5f)),
        modifier = modifier
    ) {
        Column(
            modifier = Modifier.padding(10.dp),
            horizontalAlignment = Alignment.CenterHorizontally
        ) {
            Text(icon, fontSize = 20.sp)
            Spacer(modifier = Modifier.height(4.dp))
            Text(
                text = title,
                fontWeight = FontWeight.Bold,
                fontSize = 12.sp,
                textAlign = androidx.compose.ui.text.style.TextAlign.Center
            )
            Text(
                text = subtitle,
                fontSize = 9.5.sp,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                textAlign = androidx.compose.ui.text.style.TextAlign.Center,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis
            )
        }
    }
}

@Composable
fun McpToolItemCard(
    tool: McpToolDefinition,
    onRunTest: () -> Unit,
    onCopySchema: () -> Unit,
    modifier: Modifier = Modifier
) {
    Surface(
        shape = RoundedCornerShape(14.dp),
        color = MaterialTheme.colorScheme.surface,
        border = BorderStroke(1.dp, MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.5f)),
        modifier = modifier
    ) {
        Column(modifier = Modifier.padding(14.dp)) {
            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.SpaceBetween,
                modifier = Modifier.fillMaxWidth()
            ) {
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    modifier = Modifier.weight(1f)
                ) {
                    Surface(
                        shape = RoundedCornerShape(6.dp),
                        color = MaterialTheme.colorScheme.primaryContainer
                    ) {
                        Text(
                            text = "TOOL",
                            fontSize = 10.sp,
                            fontWeight = FontWeight.Black,
                            color = MaterialTheme.colorScheme.onPrimaryContainer,
                            modifier = Modifier.padding(horizontal = 6.dp, vertical = 2.dp)
                        )
                    }
                    Spacer(modifier = Modifier.width(8.dp))
                    Text(
                        text = tool.name,
                        fontFamily = FontFamily.Monospace,
                        fontWeight = FontWeight.Bold,
                        fontSize = 13.5.sp,
                        color = MaterialTheme.colorScheme.onSurface
                    )
                }

                Row {
                    IconButton(onClick = onCopySchema, modifier = Modifier.size(30.dp)) {
                        Icon(Icons.Default.ContentCopy, contentDescription = "Copy Schema", modifier = Modifier.size(15.dp))
                    }
                    Spacer(modifier = Modifier.width(4.dp))
                    FilledTonalButton(
                        onClick = onRunTest,
                        contentPadding = PaddingValues(horizontal = 10.dp, vertical = 4.dp),
                        shape = RoundedCornerShape(10.dp),
                        modifier = Modifier.defaultMinSize(minHeight = 32.dp)
                    ) {
                        Icon(Icons.Default.PlayArrow, contentDescription = null, modifier = Modifier.size(14.dp))
                        Spacer(modifier = Modifier.width(4.dp))
                        Text("Test", fontSize = 11.5.sp, fontWeight = FontWeight.Bold)
                    }
                }
            }

            Spacer(modifier = Modifier.height(6.dp))

            Text(
                text = tool.description,
                fontSize = 12.sp,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                lineHeight = 16.sp
            )
        }
    }
}

@Composable
fun UniversalSiteCard(
    site: CustomSiteIntegration,
    onToggleEnabled: (Boolean) -> Unit,
    onTestPing: () -> Unit,
    onOpenSite: () -> Unit,
    onViewSnippet: () -> Unit,
    onEdit: () -> Unit,
    onDelete: () -> Unit,
    modifier: Modifier = Modifier
) {
    Surface(
        shape = RoundedCornerShape(16.dp),
        color = if (site.isEnabled) MaterialTheme.colorScheme.surface else MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.35f),
        border = BorderStroke(
            1.dp,
            if (site.isEnabled) MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.6f)
            else MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.3f)
        ),
        modifier = modifier.fillMaxWidth()
    ) {
        Column(modifier = Modifier.padding(14.dp)) {
            // Header Row: Emoji + Name + Category Tag + ON/OFF Switch
            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.SpaceBetween,
                modifier = Modifier.fillMaxWidth()
            ) {
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    modifier = Modifier.weight(1f)
                ) {
                    Text(site.iconEmoji, fontSize = 22.sp)
                    Spacer(modifier = Modifier.width(8.dp))
                    Column {
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            Text(
                                text = site.name,
                                fontWeight = FontWeight.Bold,
                                fontSize = 14.sp,
                                color = if (site.isEnabled) MaterialTheme.colorScheme.onSurface else MaterialTheme.colorScheme.onSurface.copy(alpha = 0.6f)
                            )
                            Spacer(modifier = Modifier.width(6.dp))
                            Surface(
                                shape = RoundedCornerShape(6.dp),
                                color = MaterialTheme.colorScheme.secondaryContainer.copy(alpha = 0.7f)
                            ) {
                                Text(
                                    text = site.category.title,
                                    fontSize = 9.5.sp,
                                    fontWeight = FontWeight.Bold,
                                    color = MaterialTheme.colorScheme.onSecondaryContainer,
                                    modifier = Modifier.padding(horizontal = 5.dp, vertical = 2.dp)
                                )
                            }
                        }

                        // Health Badge & Latency
                        Row(
                            verticalAlignment = Alignment.CenterVertically,
                            modifier = Modifier.padding(top = 2.dp)
                        ) {
                            val (dotColor, statusLabel) = when {
                                !site.isEnabled -> Pair(Color.Gray, "DISABLED (0% LOAD)")
                                site.healthStatus == SiteHealthStatus.HEALTHY -> Pair(Color(0xFF2E7D32), "HEALTHY${site.lastPingLatencyMs?.let { " ($it ms)" } ?: ""}")
                                site.healthStatus == SiteHealthStatus.DEGRADED -> Pair(Color(0xFFE65100), "DEGRADED")
                                else -> Pair(Color(0xFFC62828), "OFFLINE")
                            }

                            Box(
                                modifier = Modifier
                                    .size(7.dp)
                                    .background(dotColor, CircleShape)
                            )
                            Spacer(modifier = Modifier.width(4.dp))
                            Text(
                                text = statusLabel,
                                fontSize = 10.sp,
                                fontWeight = FontWeight.Black,
                                color = dotColor
                            )
                            Spacer(modifier = Modifier.width(8.dp))
                            Text(
                                text = "• ${site.authType.title}",
                                fontSize = 10.5.sp,
                                color = MaterialTheme.colorScheme.onSurfaceVariant
                            )
                        }
                    }
                }

                // Independent Toggle Switch
                Switch(
                    checked = site.isEnabled,
                    onCheckedChange = onToggleEnabled,
                    modifier = Modifier.testTag("toggle_custom_site_${site.id}")
                )
            }

            Spacer(modifier = Modifier.height(6.dp))

            // URL Preview & Description
            Text(
                text = site.siteUrl,
                fontFamily = FontFamily.Monospace,
                fontSize = 11.5.sp,
                color = MaterialTheme.colorScheme.primary,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis
            )

            if (site.description.isNotBlank()) {
                Text(
                    text = site.description,
                    fontSize = 11.5.sp,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    lineHeight = 15.sp,
                    modifier = Modifier.padding(top = 2.dp)
                )
            }

            Spacer(modifier = Modifier.height(10.dp))

            // Actions Row: Ping, Open, Snippet, Edit, Delete
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                    FilledTonalButton(
                        onClick = onTestPing,
                        contentPadding = PaddingValues(horizontal = 8.dp, vertical = 3.dp),
                        shape = RoundedCornerShape(8.dp),
                        modifier = Modifier.defaultMinSize(minHeight = 28.dp)
                    ) {
                        Icon(Icons.Default.PlayArrow, contentDescription = null, modifier = Modifier.size(13.dp))
                        Spacer(modifier = Modifier.width(3.dp))
                        Text("Test Ping", fontSize = 11.sp, fontWeight = FontWeight.Bold)
                    }

                    OutlinedButton(
                        onClick = onOpenSite,
                        contentPadding = PaddingValues(horizontal = 8.dp, vertical = 3.dp),
                        shape = RoundedCornerShape(8.dp),
                        modifier = Modifier.defaultMinSize(minHeight = 28.dp)
                    ) {
                        Icon(Icons.Default.OpenInNew, contentDescription = null, modifier = Modifier.size(13.dp))
                        Spacer(modifier = Modifier.width(3.dp))
                        Text("Launch", fontSize = 11.sp, fontWeight = FontWeight.Bold)
                    }

                    OutlinedButton(
                        onClick = onViewSnippet,
                        contentPadding = PaddingValues(horizontal = 8.dp, vertical = 3.dp),
                        shape = RoundedCornerShape(8.dp),
                        modifier = Modifier.defaultMinSize(minHeight = 28.dp)
                    ) {
                        Icon(Icons.Default.Code, contentDescription = null, modifier = Modifier.size(13.dp))
                        Spacer(modifier = Modifier.width(3.dp))
                        Text("Snippet", fontSize = 11.sp, fontWeight = FontWeight.Bold)
                    }
                }

                Row {
                    IconButton(onClick = onEdit, modifier = Modifier.size(28.dp)) {
                        Icon(Icons.Default.Edit, contentDescription = "Edit Site", modifier = Modifier.size(14.dp))
                    }
                    IconButton(onClick = onDelete, modifier = Modifier.size(28.dp)) {
                        Icon(Icons.Default.DeleteOutline, contentDescription = "Delete Site", tint = MaterialTheme.colorScheme.error, modifier = Modifier.size(15.dp))
                    }
                }
            }
        }
    }
}

