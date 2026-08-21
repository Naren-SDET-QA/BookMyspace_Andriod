package com.bookmyspace.bookmyspace.ui.screens

import android.widget.Toast
import androidx.compose.animation.*
import androidx.compose.animation.core.*
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
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
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.bookmyspace.bookmyspace.data.auth.UserRoleProvider
import com.bookmyspace.bookmyspace.data.model.UserRole
import com.bookmyspace.bookmyspace.data.payment.*
import com.bookmyspace.bookmyspace.data.repository.BookMySpaceRepository
import kotlinx.coroutines.launch
import java.text.SimpleDateFormat
import java.util.*

enum class PaymentConfigTab(val title: String, val icon: androidx.compose.ui.graphics.vector.ImageVector) {
    SELF_HEALING_HEALTH("Self-Healing & Health", Icons.Default.Healing),
    PAYMENT_METHODS("Payment Methods", Icons.Default.Payments),
    GATEWAY_ROUTING("Gateway Routing", Icons.Default.AltRoute),
    OWNER_POLICIES("Owner Policies", Icons.Default.Storefront),
    CHAOS_TEST("Resilience Lab", Icons.Default.Science)
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun PaymentHealthAndConfigScreen(
    onNavigateBack: () -> Unit = {},
    initialVenueId: String? = null,
    modifier: Modifier = Modifier
) {
    val context = LocalContext.current
    val coroutineScope = rememberCoroutineScope()
    val configRepo = remember { PaymentConfigRepository.getInstance(context) }
    val selfHealingEngine = remember { PaymentSelfHealingEngine.getInstance(context) }

    val adminSettings by configRepo.adminSettings.collectAsState()
    val ownerPolicies by configRepo.ownerPolicies.collectAsState()
    val venues by BookMySpaceRepository.venues.collectAsState()
    val currentRole by UserRoleProvider.role.collectAsState()

    val gatewayHealth by selfHealingEngine.gatewayHealth.collectAsState()
    val currentLatency by selfHealingEngine.currentLatencyMs.collectAsState()
    val uptimePercentage by selfHealingEngine.uptimePercentage.collectAsState()
    val totalAutoHealed by selfHealingEngine.totalAutoHealedCount.collectAsState()
    val isScanning by selfHealingEngine.isScanning.collectAsState()
    val healingEvents by selfHealingEngine.healingEvents.collectAsState()

    var selectedTab by remember { mutableStateOf(PaymentConfigTab.SELF_HEALING_HEALTH) }
    var selectedVenueForPolicy by remember {
        mutableStateOf(venues.firstOrNull { it.id == initialVenueId } ?: venues.firstOrNull())
    }
    var scanResultDialog by remember { mutableStateOf<SelfHealingScanResult?>(null) }
    var showEditOwnerPolicyModal by remember { mutableStateOf(false) }

    Scaffold(
        topBar = {
            TopAppBar(
                title = {
                    Column {
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            Text(
                                text = "Payment & Self-Healing Control",
                                fontWeight = FontWeight.Bold,
                                fontSize = 17.sp
                            )
                            Spacer(modifier = Modifier.width(6.dp))
                            Surface(
                                shape = RoundedCornerShape(6.dp),
                                color = if (adminSettings.isSandboxMode) Color(0xFFFF9800).copy(alpha = 0.2f) else Color(0xFF4CAF50).copy(alpha = 0.2f)
                            ) {
                                Text(
                                    text = if (adminSettings.isSandboxMode) "SANDBOX" else "LIVE",
                                    color = if (adminSettings.isSandboxMode) Color(0xFFFF9800) else Color(0xFF4CAF50),
                                    fontWeight = FontWeight.Black,
                                    fontSize = 10.sp,
                                    modifier = Modifier.padding(horizontal = 6.dp, vertical = 2.dp)
                                )
                            }
                        }
                        Text(
                            text = if (currentRole == UserRole.ADMIN) "Admin Full Control & Gateway Matrix" else "Venue Owner Payment Config",
                            fontSize = 11.sp,
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                    }
                },
                navigationIcon = {
                    IconButton(
                        onClick = onNavigateBack,
                        modifier = Modifier.testTag("payment_config_back_btn")
                    ) {
                        Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "Back")
                    }
                },
                actions = {
                    IconButton(
                        onClick = {
                            coroutineScope.launch {
                                val res = selfHealingEngine.performDeepSelfHealingScan()
                                scanResultDialog = res
                            }
                        },
                        enabled = !isScanning,
                        modifier = Modifier.testTag("trigger_self_healing_scan_top_btn")
                    ) {
                        if (isScanning) {
                            CircularProgressIndicator(
                                modifier = Modifier.size(20.dp),
                                strokeWidth = 2.dp,
                                color = MaterialTheme.colorScheme.primary
                            )
                        } else {
                            Icon(
                                imageVector = Icons.Default.AutoAwesome,
                                contentDescription = "Run Self-Healing Scan",
                                tint = MaterialTheme.colorScheme.primary
                            )
                        }
                    }
                },
                colors = TopAppBarDefaults.topAppBarColors(containerColor = MaterialTheme.colorScheme.surface)
            )
        },
        modifier = modifier.testTag("payment_health_and_config_screen")
    ) { paddingValues ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(paddingValues)
        ) {
            // Horizontal Tab Bar
            ScrollableTabRow(
                selectedTabIndex = selectedTab.ordinal,
                edgePadding = 12.dp,
                containerColor = MaterialTheme.colorScheme.surface,
                contentColor = MaterialTheme.colorScheme.primary,
                divider = { HorizontalDivider(color = MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.5f)) }
            ) {
                PaymentConfigTab.values().forEach { tab ->
                    // Filter tabs based on role if needed
                    val isVisible = when (tab) {
                        PaymentConfigTab.GATEWAY_ROUTING -> currentRole == UserRole.ADMIN
                        PaymentConfigTab.CHAOS_TEST -> currentRole == UserRole.ADMIN
                        else -> true
                    }
                    if (isVisible) {
                        Tab(
                            selected = selectedTab == tab,
                            onClick = { selectedTab = tab },
                            text = {
                                Text(
                                    text = tab.title,
                                    fontSize = 13.sp,
                                    fontWeight = if (selectedTab == tab) FontWeight.Bold else FontWeight.Normal
                                )
                            },
                            icon = {
                                Icon(
                                    imageVector = tab.icon,
                                    contentDescription = tab.title,
                                    modifier = Modifier.size(18.dp)
                                )
                            },
                            modifier = Modifier.testTag("payment_tab_${tab.name.lowercase()}")
                        )
                    }
                }
            }

            AnimatedContent(
                targetState = selectedTab,
                transitionSpec = { fadeIn(tween(250)) togetherWith fadeOut(tween(200)) },
                label = "PaymentConfigTabContent"
            ) { tab ->
                when (tab) {
                    PaymentConfigTab.SELF_HEALING_HEALTH -> {
                        SelfHealingHealthTab(
                            gatewayHealth = gatewayHealth,
                            latencyMs = currentLatency,
                            uptime = uptimePercentage,
                            totalHealed = totalAutoHealed,
                            isScanning = isScanning,
                            healingEvents = healingEvents,
                            adminSettings = adminSettings,
                            onRunScan = {
                                coroutineScope.launch {
                                    val res = selfHealingEngine.performDeepSelfHealingScan()
                                    scanResultDialog = res
                                }
                            },
                            onToggleAutoHeal = { enabled ->
                                configRepo.setSelfHealingAutoReconcile(enabled)
                                Toast.makeText(context, if (enabled) "Self-Healing Auto-Reconciler Activated" else "Self-Healing Paused", Toast.LENGTH_SHORT).show()
                            }
                        )
                    }
                    PaymentConfigTab.PAYMENT_METHODS -> {
                        PaymentMethodsTab(
                            adminSettings = adminSettings,
                            onToggleMethod = { methodId, enable ->
                                configRepo.toggleGlobalPaymentMethod(methodId, enable)
                                Toast.makeText(context, "Payment method updated", Toast.LENGTH_SHORT).show()
                            }
                        )
                    }
                    PaymentConfigTab.GATEWAY_ROUTING -> {
                        GatewayRoutingTab(
                            adminSettings = adminSettings,
                            onSetPrimary = { configRepo.setPrimaryGateway(it) },
                            onSetFallback = { configRepo.setFallbackGateway(it) },
                            onToggleSandbox = { configRepo.setSandboxMode(it) },
                            onToggleAutoFailover = { configRepo.setAutoFailoverEnabled(it) }
                        )
                    }
                    PaymentConfigTab.OWNER_POLICIES -> {
                        OwnerPoliciesTab(
                            venues = venues,
                            selectedVenue = selectedVenueForPolicy,
                            onSelectVenue = { selectedVenueForPolicy = it },
                            ownerPolicies = ownerPolicies,
                            onUpdatePolicy = { policy ->
                                configRepo.updateOwnerPolicy(policy)
                                Toast.makeText(context, "Venue policy saved successfully", Toast.LENGTH_SHORT).show()
                            }
                        )
                    }
                    PaymentConfigTab.CHAOS_TEST -> {
                        ChaosResilienceTab(
                            adminSettings = adminSettings,
                            onToggleDegradation = { degraded ->
                                configRepo.setSimulatedNetworkDegradation(degraded)
                            },
                            onRunChaosHealingTest = {
                                coroutineScope.launch {
                                    val res = selfHealingEngine.performDeepSelfHealingScan()
                                    scanResultDialog = res
                                }
                            }
                        )
                    }
                }
            }
        }

        // Diagnostic Scan Result Modal Dialog
        scanResultDialog?.let { result ->
            AlertDialog(
                onDismissRequest = { scanResultDialog = null },
                icon = { Icon(Icons.Default.Verified, contentDescription = null, tint = Color(0xFF4CAF50), modifier = Modifier.size(32.dp)) },
                title = {
                    Text("Self-Healing Diagnostic Report", fontWeight = FontWeight.Bold, textAlign = TextAlign.Center)
                },
                text = {
                    Column(
                        modifier = Modifier
                            .fillMaxWidth()
                            .heightIn(max = 380.dp)
                    ) {
                        Surface(
                            shape = RoundedCornerShape(12.dp),
                            color = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.5f),
                            modifier = Modifier.fillMaxWidth()
                        ) {
                            Row(
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .padding(12.dp),
                                horizontalArrangement = Arrangement.SpaceAround
                            ) {
                                Column(horizontalAlignment = Alignment.CenterHorizontally) {
                                    Text("Scanned", fontSize = 11.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                                    Text("${result.totalTransactionsScanned}", fontWeight = FontWeight.Bold, fontSize = 16.sp)
                                }
                                Column(horizontalAlignment = Alignment.CenterHorizontally) {
                                    Text("Repaired", fontSize = 11.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                                    Text("${result.pendingReconciledCount}", fontWeight = FontWeight.Bold, fontSize = 16.sp, color = Color(0xFF4CAF50))
                                }
                                Column(horizontalAlignment = Alignment.CenterHorizontally) {
                                    Text("Latency", fontSize = 11.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                                    Text("${result.averageLatencyMs}ms", fontWeight = FontWeight.Bold, fontSize = 16.sp, color = MaterialTheme.colorScheme.primary)
                                }
                                Column(horizontalAlignment = Alignment.CenterHorizontally) {
                                    Text("Gateways", fontSize = 11.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                                    Text("${result.healthyGatewaysCount}/3", fontWeight = FontWeight.Bold, fontSize = 16.sp, color = Color(0xFF2196F3))
                                }
                            }
                        }

                        Spacer(modifier = Modifier.height(12.dp))
                        Text("Execution Audit Log:", fontWeight = FontWeight.SemiBold, fontSize = 12.sp)
                        Spacer(modifier = Modifier.height(6.dp))

                        LazyColumn(
                            modifier = Modifier
                                .fillMaxWidth()
                                .weight(1f, fill = false)
                        ) {
                            items(result.messages) { msg ->
                                Text(
                                    text = msg,
                                    fontSize = 11.5.sp,
                                    lineHeight = 16.sp,
                                    modifier = Modifier.padding(vertical = 2.dp),
                                    color = MaterialTheme.colorScheme.onSurface
                                )
                            }
                        }
                    }
                },
                confirmButton = {
                    Button(
                        onClick = { scanResultDialog = null },
                        shape = RoundedCornerShape(8.dp)
                    ) {
                        Text("Dismiss")
                    }
                }
            )
        }
    }
}

@Composable
private fun SelfHealingHealthTab(
    gatewayHealth: GatewayHealthStatus,
    latencyMs: Long,
    uptime: Double,
    totalHealed: Int,
    isScanning: Boolean,
    healingEvents: List<SelfHealingLogEvent>,
    adminSettings: AdminPaymentSettings,
    onRunScan: () -> Unit,
    onToggleAutoHeal: (Boolean) -> Unit
) {
    LazyColumn(
        modifier = Modifier
            .fillMaxSize()
            .padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp)
    ) {
        // Radar Banner Card
        item {
            Card(
                shape = RoundedCornerShape(20.dp),
                colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.6f)),
                border = BorderStroke(1.dp, MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.5f)),
                modifier = Modifier.fillMaxWidth()
            ) {
                Column(modifier = Modifier.padding(16.dp)) {
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.SpaceBetween,
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            Box(
                                modifier = Modifier
                                    .size(12.dp)
                                    .clip(CircleShape)
                                    .background(Color(android.graphics.Color.parseColor(gatewayHealth.colorHex)))
                            )
                            Spacer(modifier = Modifier.width(8.dp))
                            Text(
                                text = "Gateway Status: ${gatewayHealth.label}",
                                fontWeight = FontWeight.Bold,
                                fontSize = 14.sp
                            )
                        }

                        Surface(
                            shape = RoundedCornerShape(12.dp),
                            color = MaterialTheme.colorScheme.primaryContainer
                        ) {
                            Text(
                                text = "${adminSettings.primaryGateway.displayName}",
                                fontSize = 11.sp,
                                fontWeight = FontWeight.SemiBold,
                                color = MaterialTheme.colorScheme.onPrimaryContainer,
                                modifier = Modifier.padding(horizontal = 8.dp, vertical = 4.dp)
                            )
                        }
                    }

                    Spacer(modifier = Modifier.height(16.dp))

                    // 3 Metric Pills
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.spacedBy(8.dp)
                    ) {
                        MetricPill(
                            title = "Uptime SLA",
                            value = "$uptime%",
                            color = Color(0xFF4CAF50),
                            modifier = Modifier.weight(1f)
                        )
                        MetricPill(
                            title = "Avg Latency",
                            value = "${latencyMs}ms",
                            color = if (latencyMs > 300) Color(0xFFFF9800) else Color(0xFF2196F3),
                            modifier = Modifier.weight(1f)
                        )
                        MetricPill(
                            title = "Auto-Healed",
                            value = "$totalHealed tx",
                            color = Color(0xFF9C27B0),
                            modifier = Modifier.weight(1f)
                        )
                    }

                    Spacer(modifier = Modifier.height(16.dp))

                    // Trigger Diagnostic Scan Button
                    Button(
                        onClick = onRunScan,
                        enabled = !isScanning,
                        shape = RoundedCornerShape(12.dp),
                        modifier = Modifier
                            .fillMaxWidth()
                            .height(48.dp)
                            .testTag("run_deep_self_healing_scan_btn")
                    ) {
                        if (isScanning) {
                            CircularProgressIndicator(color = Color.White, modifier = Modifier.size(18.dp), strokeWidth = 2.dp)
                            Spacer(modifier = Modifier.width(8.dp))
                            Text("Reconciling Transactions & Testing Gateways...", fontSize = 13.sp)
                        } else {
                            Icon(Icons.Default.AutoFixHigh, contentDescription = null, modifier = Modifier.size(18.dp))
                            Spacer(modifier = Modifier.width(8.dp))
                            Text("Run Deep Self-Healing Diagnostic Scan", fontWeight = FontWeight.Bold, fontSize = 13.sp)
                        }
                    }
                }
            }
        }

        // Autonomous Background Reconciler Switch Card
        item {
            Card(
                shape = RoundedCornerShape(16.dp),
                colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface),
                border = BorderStroke(1.dp, MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.4f)),
                modifier = Modifier.fillMaxWidth()
            ) {
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(16.dp),
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.SpaceBetween
                ) {
                    Row(
                        verticalAlignment = Alignment.CenterVertically,
                        modifier = Modifier.weight(1f)
                    ) {
                        Surface(
                            shape = CircleShape,
                            color = MaterialTheme.colorScheme.primaryContainer,
                            modifier = Modifier.size(40.dp)
                        ) {
                            Box(contentAlignment = Alignment.Center) {
                                Icon(
                                    imageVector = Icons.Default.Sync,
                                    contentDescription = null,
                                    tint = MaterialTheme.colorScheme.onPrimaryContainer,
                                    modifier = Modifier.size(20.dp)
                                )
                            }
                        }
                        Spacer(modifier = Modifier.width(12.dp))
                        Column {
                            Text(
                                text = "Autonomous 24/7 Self-Healing Reconciler",
                                fontWeight = FontWeight.Bold,
                                fontSize = 13.5.sp
                            )
                            Text(
                                text = "Auto-recovers stuck payments, fixes dropped webhooks & generates QR tokens in real-time.",
                                fontSize = 11.5.sp,
                                color = MaterialTheme.colorScheme.onSurfaceVariant,
                                lineHeight = 16.sp
                            )
                        }
                    }

                    Spacer(modifier = Modifier.width(8.dp))
                    Switch(
                        checked = adminSettings.isSelfHealingAutoReconcileEnabled,
                        onCheckedChange = onToggleAutoHeal,
                        modifier = Modifier.testTag("self_healing_auto_reconcile_toggle")
                    )
                }
            }
        }

        // Live Self-Healing Logs Section
        item {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Text(
                    text = "Live Self-Healing & Failover Events",
                    fontWeight = FontWeight.Bold,
                    fontSize = 15.sp
                )
                Text(
                    text = "${healingEvents.size} Recorded",
                    fontSize = 12.sp,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
            }
        }

        items(healingEvents) { event ->
            SelfHealingEventCard(event = event)
        }
    }
}

@Composable
private fun MetricPill(title: String, value: String, color: Color, modifier: Modifier = Modifier) {
    Surface(
        shape = RoundedCornerShape(12.dp),
        color = color.copy(alpha = 0.12f),
        border = BorderStroke(1.dp, color.copy(alpha = 0.3f)),
        modifier = modifier
    ) {
        Column(
            modifier = Modifier.padding(vertical = 10.dp, horizontal = 8.dp),
            horizontalAlignment = Alignment.CenterHorizontally
        ) {
            Text(title, fontSize = 10.5.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
            Spacer(modifier = Modifier.height(2.dp))
            Text(value, fontWeight = FontWeight.Black, fontSize = 15.sp, color = color)
        }
    }
}

@Composable
private fun SelfHealingEventCard(event: SelfHealingLogEvent) {
    val timeFormat = remember { SimpleDateFormat("hh:mm:ss a, dd MMM", Locale.getDefault()) }
    val (badgeColor, badgeText) = when (event.actionType) {
        HealingActionType.RECONCILED_SUCCESS -> Color(0xFF4CAF50) to "RECONCILED"
        HealingActionType.AUTO_FAILOVER_ROUTED -> Color(0xFFFF9800) to "AUTO-FAILOVER"
        HealingActionType.DUPLICATE_AUTO_REFUNDED -> Color(0xFFE91E63) to "AUTO-REFUND"
        HealingActionType.SIGNATURE_VERIFIED_CONFIRMED -> Color(0xFF2196F3) to "VERIFIED"
        HealingActionType.WEBHOOK_REPAIRED -> Color(0xFF9C27B0) to "WEBHOOK FIX"
        HealingActionType.STUCK_SLOT_RELEASED -> Color(0xFF607D8B) to "SLOT RESET"
    }

    Card(
        shape = RoundedCornerShape(14.dp),
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface),
        border = BorderStroke(1.dp, MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.4f)),
        modifier = Modifier
            .fillMaxWidth()
            .testTag("healing_event_card_${event.id}")
    ) {
        Column(modifier = Modifier.padding(14.dp)) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Surface(
                        shape = RoundedCornerShape(6.dp),
                        color = badgeColor.copy(alpha = 0.15f)
                    ) {
                        Text(
                            text = badgeText,
                            color = badgeColor,
                            fontWeight = FontWeight.Bold,
                            fontSize = 10.5.sp,
                            modifier = Modifier.padding(horizontal = 6.dp, vertical = 2.dp)
                        )
                    }
                    Spacer(modifier = Modifier.width(8.dp))
                    Text(
                        text = "TX: ${event.transactionId.take(16)}",
                        fontFamily = FontFamily.Monospace,
                        fontSize = 11.sp,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                }

                Text(
                    text = "${event.latencyMs}ms",
                    fontSize = 11.sp,
                    fontWeight = FontWeight.SemiBold,
                    color = MaterialTheme.colorScheme.primary
                )
            }

            Spacer(modifier = Modifier.height(8.dp))
            Text(
                text = event.message,
                fontSize = 12.5.sp,
                lineHeight = 17.sp,
                color = MaterialTheme.colorScheme.onSurface
            )

            Spacer(modifier = Modifier.height(8.dp))
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween
            ) {
                Text(
                    text = "Gateway: ${event.resolvedGateway}",
                    fontSize = 11.sp,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
                Text(
                    text = timeFormat.format(Date(event.timestamp)),
                    fontSize = 10.5.sp,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
            }
        }
    }
}

@Composable
private fun PaymentMethodsTab(
    adminSettings: AdminPaymentSettings,
    onToggleMethod: (String, Boolean) -> Unit
) {
    LazyColumn(
        modifier = Modifier
            .fillMaxSize()
            .padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(14.dp)
    ) {
        item {
            Surface(
                shape = RoundedCornerShape(14.dp),
                color = MaterialTheme.colorScheme.primaryContainer.copy(alpha = 0.4f),
                modifier = Modifier.fillMaxWidth()
            ) {
                Row(
                    modifier = Modifier.padding(14.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Text("💡", fontSize = 20.sp)
                    Spacer(modifier = Modifier.width(10.dp))
                    Text(
                        text = "Global Payment Method Controls: Master toggles apply across all search, booking, institute and space flows. Disabled methods are instantly removed from checkout.",
                        fontSize = 12.sp,
                        lineHeight = 17.sp,
                        color = MaterialTheme.colorScheme.onSurface
                    )
                }
            }
        }

        val grouped = ConfigurablePaymentMethod.values().groupBy { it.category }

        grouped.forEach { (category, methods) ->
            item {
                Text(
                    text = category.uppercase(),
                    fontWeight = FontWeight.Black,
                    fontSize = 12.sp,
                    color = MaterialTheme.colorScheme.primary,
                    letterSpacing = 1.sp,
                    modifier = Modifier.padding(top = 6.dp)
                )
            }

            items(methods) { method ->
                val isEnabled = adminSettings.enabledGlobalMethods.contains(method.id)
                Card(
                    shape = RoundedCornerShape(14.dp),
                    colors = CardDefaults.cardColors(
                        containerColor = if (isEnabled) MaterialTheme.colorScheme.surface else MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.4f)
                    ),
                    border = BorderStroke(1.dp, MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.4f)),
                    modifier = Modifier.fillMaxWidth()
                ) {
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(14.dp),
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.SpaceBetween
                    ) {
                        Row(
                            verticalAlignment = Alignment.CenterVertically,
                            modifier = Modifier.weight(1f)
                        ) {
                            Text(method.iconEmoji, fontSize = 24.sp)
                            Spacer(modifier = Modifier.width(12.dp))
                            Column {
                                Row(verticalAlignment = Alignment.CenterVertically) {
                                    Text(
                                        text = method.title,
                                        fontWeight = FontWeight.Bold,
                                        fontSize = 14.sp
                                    )
                                    if (!method.isOnline) {
                                        Spacer(modifier = Modifier.width(6.dp))
                                        Surface(
                                            shape = RoundedCornerShape(4.dp),
                                            color = Color(0xFF607D8B).copy(alpha = 0.2f)
                                        ) {
                                            Text(
                                                text = "OFFLINE",
                                                color = Color(0xFF607D8B),
                                                fontWeight = FontWeight.Bold,
                                                fontSize = 9.sp,
                                                modifier = Modifier.padding(horizontal = 4.dp, vertical = 1.dp)
                                            )
                                        }
                                    }
                                }
                                Text(
                                    text = method.subtitle,
                                    fontSize = 11.5.sp,
                                    color = MaterialTheme.colorScheme.onSurfaceVariant
                                )
                            }
                        }

                        Switch(
                            checked = isEnabled,
                            onCheckedChange = { onToggleMethod(method.id, it) },
                            modifier = Modifier.testTag("toggle_method_${method.id}")
                        )
                    }
                }
            }
        }
    }
}

@Composable
private fun GatewayRoutingTab(
    adminSettings: AdminPaymentSettings,
    onSetPrimary: (PaymentGatewayProvider) -> Unit,
    onSetFallback: (PaymentGatewayProvider) -> Unit,
    onToggleSandbox: (Boolean) -> Unit,
    onToggleAutoFailover: (Boolean) -> Unit
) {
    LazyColumn(
        modifier = Modifier
            .fillMaxSize()
            .padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp)
    ) {
        item {
            Card(
                shape = RoundedCornerShape(16.dp),
                colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface),
                border = BorderStroke(1.dp, MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.5f)),
                modifier = Modifier.fillMaxWidth()
            ) {
                Column(modifier = Modifier.padding(16.dp)) {
                    Text("Gateway Operations Mode", fontWeight = FontWeight.Bold, fontSize = 15.sp)
                    Spacer(modifier = Modifier.height(12.dp))

                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.SpaceBetween,
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Column(modifier = Modifier.weight(1f)) {
                            Text("Sandbox / Test Simulator Mode", fontWeight = FontWeight.SemiBold, fontSize = 13.sp)
                            Text("Safe testing environment with instant payment verification and test credentials.", fontSize = 11.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                        }
                        Switch(
                            checked = adminSettings.isSandboxMode,
                            onCheckedChange = onToggleSandbox,
                            modifier = Modifier.testTag("toggle_sandbox_mode")
                        )
                    }

                    HorizontalDivider(modifier = Modifier.padding(vertical = 12.dp))

                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.SpaceBetween,
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Column(modifier = Modifier.weight(1f)) {
                            Text("Automated Gateway Failover", fontWeight = FontWeight.SemiBold, fontSize = 13.sp)
                            Text("Automatically reroutes checkout to backup gateway if primary reports timeout.", fontSize = 11.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                        }
                        Switch(
                            checked = adminSettings.isAutoFailoverEnabled,
                            onCheckedChange = onToggleAutoFailover,
                            modifier = Modifier.testTag("toggle_auto_failover")
                        )
                    }
                }
            }
        }

        item {
            Text("PRIMARY GATEWAY (DEFAULT)", fontWeight = FontWeight.Black, fontSize = 12.sp, color = MaterialTheme.colorScheme.primary, letterSpacing = 0.5.sp)
        }

        items(PaymentGatewayProvider.values()) { gw ->
            val isSelected = adminSettings.primaryGateway == gw
            Card(
                onClick = { onSetPrimary(gw) },
                shape = RoundedCornerShape(14.dp),
                colors = CardDefaults.cardColors(
                    containerColor = if (isSelected) MaterialTheme.colorScheme.primaryContainer.copy(alpha = 0.4f) else MaterialTheme.colorScheme.surface
                ),
                border = BorderStroke(
                    if (isSelected) 2.dp else 1.dp,
                    if (isSelected) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.4f)
                ),
                modifier = Modifier.fillMaxWidth()
            ) {
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(14.dp),
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.SpaceBetween
                ) {
                    Row(
                        verticalAlignment = Alignment.CenterVertically,
                        modifier = Modifier.weight(1f)
                    ) {
                        Text(gw.badgeIcon, fontSize = 24.sp)
                        Spacer(modifier = Modifier.width(12.dp))
                        Column {
                            Text(gw.displayName, fontWeight = FontWeight.Bold, fontSize = 14.sp)
                            Text(gw.description, fontSize = 11.5.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                        }
                    }
                    RadioButton(
                        selected = isSelected,
                        onClick = { onSetPrimary(gw) },
                        modifier = Modifier.testTag("radio_primary_${gw.id}")
                    )
                }
            }
        }

        item {
            Spacer(modifier = Modifier.height(6.dp))
            Text("STANDBY FALLBACK GATEWAY (FAILOVER TARGET)", fontWeight = FontWeight.Black, fontSize = 12.sp, color = Color(0xFFFF9800), letterSpacing = 0.5.sp)
        }

        items(PaymentGatewayProvider.values().filter { it != adminSettings.primaryGateway }) { gw ->
            val isSelected = adminSettings.fallbackGateway == gw
            Card(
                onClick = { onSetFallback(gw) },
                shape = RoundedCornerShape(14.dp),
                colors = CardDefaults.cardColors(
                    containerColor = if (isSelected) Color(0xFFFF9800).copy(alpha = 0.1f) else MaterialTheme.colorScheme.surface
                ),
                border = BorderStroke(
                    if (isSelected) 2.dp else 1.dp,
                    if (isSelected) Color(0xFFFF9800) else MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.4f)
                ),
                modifier = Modifier.fillMaxWidth()
            ) {
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(14.dp),
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.SpaceBetween
                ) {
                    Row(
                        verticalAlignment = Alignment.CenterVertically,
                        modifier = Modifier.weight(1f)
                    ) {
                        Text(gw.badgeIcon, fontSize = 24.sp)
                        Spacer(modifier = Modifier.width(12.dp))
                        Column {
                            Text(gw.displayName, fontWeight = FontWeight.Bold, fontSize = 14.sp)
                            Text(gw.description, fontSize = 11.5.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                        }
                    }
                    RadioButton(
                        selected = isSelected,
                        onClick = { onSetFallback(gw) },
                        modifier = Modifier.testTag("radio_fallback_${gw.id}")
                    )
                }
            }
        }
    }
}

@Composable
private fun OwnerPoliciesTab(
    venues: List<com.bookmyspace.bookmyspace.data.model.Venue>,
    selectedVenue: com.bookmyspace.bookmyspace.data.model.Venue?,
    onSelectVenue: (com.bookmyspace.bookmyspace.data.model.Venue) -> Unit,
    ownerPolicies: Map<String, OwnerPaymentPolicy>,
    onUpdatePolicy: (OwnerPaymentPolicy) -> Unit
) {
    val context = LocalContext.current
    var currentPolicy by remember(selectedVenue, ownerPolicies) {
        val p = if (selectedVenue != null) {
            ownerPolicies[selectedVenue.id] ?: OwnerPaymentPolicy(venueId = selectedVenue.id)
        } else OwnerPaymentPolicy(venueId = "global_default")
        mutableStateOf(p)
    }

    LazyColumn(
        modifier = Modifier
            .fillMaxSize()
            .padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp)
    ) {
        item {
            Text("Select Your Venue Listing:", fontWeight = FontWeight.Bold, fontSize = 13.sp)
            Spacer(modifier = Modifier.height(8.dp))
            LazyRow(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                items(venues) { venue ->
                    val isSelected = selectedVenue?.id == venue.id
                    FilterChip(
                        selected = isSelected,
                        onClick = { onSelectVenue(venue) },
                        label = { Text(venue.name.take(24), fontSize = 12.sp) },
                        leadingIcon = {
                            if (isSelected) Icon(Icons.Default.Check, contentDescription = null, modifier = Modifier.size(14.dp))
                        },
                        modifier = Modifier.testTag("owner_venue_chip_${venue.id}")
                    )
                }
            }
        }

        if (selectedVenue != null) {
            item {
                Card(
                    shape = RoundedCornerShape(18.dp),
                    colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface),
                    border = BorderStroke(1.dp, MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.5f)),
                    modifier = Modifier.fillMaxWidth()
                ) {
                    Column(modifier = Modifier.padding(16.dp)) {
                        Text(
                            text = "Payment Policies for: ${selectedVenue.name}",
                            fontWeight = FontWeight.Bold,
                            fontSize = 15.sp
                        )
                        Spacer(modifier = Modifier.height(14.dp))

                        // Pay at Venue toggle
                        Row(
                            modifier = Modifier.fillMaxWidth(),
                            horizontalArrangement = Arrangement.SpaceBetween,
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            Column(modifier = Modifier.weight(1f)) {
                                Text("Allow Pay at Venue / Cash on Check-in", fontWeight = FontWeight.SemiBold, fontSize = 13.sp)
                                Text("Users can reserve online without upfront payment and pay 100% at the desk.", fontSize = 11.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                            }
                            Switch(
                                checked = currentPolicy.allowPayAtVenue,
                                onCheckedChange = {
                                    val updated = currentPolicy.copy(allowPayAtVenue = it)
                                    currentPolicy = updated
                                    onUpdatePolicy(updated)
                                },
                                modifier = Modifier.testTag("owner_allow_pay_at_venue_toggle")
                            )
                        }

                        HorizontalDivider(modifier = Modifier.padding(vertical = 12.dp))

                        // Split Payment / Advance Token toggle
                        Row(
                            modifier = Modifier.fillMaxWidth(),
                            horizontalArrangement = Arrangement.SpaceBetween,
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            Column(modifier = Modifier.weight(1f)) {
                                Text("Allow Split Advance Payment (${currentPolicy.splitAdvancePercentage}%)", fontWeight = FontWeight.SemiBold, fontSize = 13.sp)
                                Text("Require only a token advance online; remaining balance collected on check-in.", fontSize = 11.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                            }
                            Switch(
                                checked = currentPolicy.allowSplitPayment,
                                onCheckedChange = {
                                    val updated = currentPolicy.copy(allowSplitPayment = it)
                                    currentPolicy = updated
                                    onUpdatePolicy(updated)
                                },
                                modifier = Modifier.testTag("owner_allow_split_payment_toggle")
                            )
                        }

                        HorizontalDivider(modifier = Modifier.padding(vertical = 12.dp))

                        // BMS Wallet balance toggle
                        Row(
                            modifier = Modifier.fillMaxWidth(),
                            horizontalArrangement = Arrangement.SpaceBetween,
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            Column(modifier = Modifier.weight(1f)) {
                                Text("Accept BMS Wallet & Referral Credits", fontWeight = FontWeight.SemiBold, fontSize = 13.sp)
                                Text("Allow customers to redeem reward points (reimbursed by BookMySpace).", fontSize = 11.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                            }
                            Switch(
                                checked = currentPolicy.allowWalletRedemption,
                                onCheckedChange = {
                                    val updated = currentPolicy.copy(allowWalletRedemption = it)
                                    currentPolicy = updated
                                    onUpdatePolicy(updated)
                                },
                                modifier = Modifier.testTag("owner_allow_wallet_toggle")
                            )
                        }

                        HorizontalDivider(modifier = Modifier.padding(vertical = 12.dp))

                        // Instant Auto-Refund on Cancellation
                        Row(
                            modifier = Modifier.fillMaxWidth(),
                            horizontalArrangement = Arrangement.SpaceBetween,
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            Column(modifier = Modifier.weight(1f)) {
                                Text("Instant Auto-Refund Engine", fontWeight = FontWeight.SemiBold, fontSize = 13.sp)
                                Text("Automatically refund booking fees if customer cancels before slot start.", fontSize = 11.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                            }
                            Switch(
                                checked = currentPolicy.instantAutoRefunds,
                                onCheckedChange = {
                                    val updated = currentPolicy.copy(instantAutoRefunds = it)
                                    currentPolicy = updated
                                    onUpdatePolicy(updated)
                                },
                                modifier = Modifier.testTag("owner_instant_auto_refund_toggle")
                            )
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun ChaosResilienceTab(
    adminSettings: AdminPaymentSettings,
    onToggleDegradation: (Boolean) -> Unit,
    onRunChaosHealingTest: () -> Unit
) {
    LazyColumn(
        modifier = Modifier
            .fillMaxSize()
            .padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp)
    ) {
        item {
            Card(
                shape = RoundedCornerShape(18.dp),
                colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.5f)),
                border = BorderStroke(1.dp, MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.4f)),
                modifier = Modifier.fillMaxWidth()
            ) {
                Column(modifier = Modifier.padding(16.dp)) {
                    Text("🧪 Resilience & Chaos Simulation Lab", fontWeight = FontWeight.Bold, fontSize = 15.sp)
                    Spacer(modifier = Modifier.height(4.dp))
                    Text(
                        text = "Simulate real-world network packet drops, degraded gateway latency (>400ms), and dropped webhooks to observe the Autonomous Self-Healing Engine in action.",
                        fontSize = 12.sp,
                        lineHeight = 17.sp,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )

                    Spacer(modifier = Modifier.height(16.dp))

                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.SpaceBetween,
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Column(modifier = Modifier.weight(1f)) {
                            Text("Inject Gateway Network Degradation", fontWeight = FontWeight.SemiBold, fontSize = 13.5.sp)
                            Text("Trips circuit breaker to test zero-cart-drop auto-failover to backup gateway.", fontSize = 11.5.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                        }
                        Switch(
                            checked = adminSettings.simulatedNetworkDegradation,
                            onCheckedChange = onToggleDegradation,
                            modifier = Modifier.testTag("chaos_network_degradation_switch")
                        )
                    }

                    Spacer(modifier = Modifier.height(16.dp))

                    Button(
                        onClick = onRunChaosHealingTest,
                        colors = ButtonDefaults.buttonColors(containerColor = MaterialTheme.colorScheme.error),
                        shape = RoundedCornerShape(12.dp),
                        modifier = Modifier
                            .fillMaxWidth()
                            .height(48.dp)
                            .testTag("chaos_test_healing_btn")
                    ) {
                        Icon(Icons.Default.Bolt, contentDescription = null)
                        Spacer(modifier = Modifier.width(8.dp))
                        Text("Simulate Chaos & Trigger Auto-Healing", fontWeight = FontWeight.Bold)
                    }
                }
            }
        }
    }
}
