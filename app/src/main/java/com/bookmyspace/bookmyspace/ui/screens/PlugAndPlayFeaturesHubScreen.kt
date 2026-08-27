package com.bookmyspace.bookmyspace.ui.screens

import android.widget.Toast
import androidx.compose.animation.*
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
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
import androidx.compose.ui.platform.LocalClipboardManager
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.AnnotatedString
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.window.Dialog
import com.bookmyspace.bookmyspace.data.healing.ModuleHealthReport
import com.bookmyspace.bookmyspace.data.healing.ModuleHealthStatus
import com.bookmyspace.bookmyspace.data.healing.SelfHealingManager
import com.bookmyspace.bookmyspace.data.model.*
import com.bookmyspace.bookmyspace.data.repository.BookMySpaceRepository
import kotlinx.coroutines.launch

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun PlugAndPlayFeaturesHubScreen(
    onNavigateBack: () -> Unit,
    modifier: Modifier = Modifier
) {
    val context = LocalContext.current
    val clipboardManager = LocalClipboardManager.current
    val coroutineScope = rememberCoroutineScope()

    val features by BookMySpaceRepository.featureConfigs.collectAsState()
    val healthReports by SelfHealingManager.moduleHealthReports.collectAsState()
    val isDiagnosticRunning by SelfHealingManager.isDiagnosticRunning.collectAsState()
    val auditLogs by SelfHealingManager.healingAuditLogs.collectAsState()

    var selectedCategoryFilter by remember { mutableStateOf<FeatureCategory?>(null) }
    var searchQuery by remember { mutableStateOf("") }
    var editingFeatureConfig by remember { mutableStateOf<FeatureModuleConfig?>(null) }
    var showJsonDialog by remember { mutableStateOf(false) }
    var showAuditLogsDialog by remember { mutableStateOf(false) }
    var showPresetConfirmDialog by remember { mutableStateOf<FeaturePreset?>(null) }

    val activeCount = remember(features) { features.count { it.isEnabled } }
    val totalCount = remember(features) { features.size }
    val healthyCount = remember(healthReports) { healthReports.values.count { it.status == ModuleHealthStatus.HEALTHY } }
    val autoRecoveredCount = remember(healthReports) { healthReports.values.count { it.status == ModuleHealthStatus.AUTO_RECOVERED } }

    val filteredFeatures = remember(features, selectedCategoryFilter, searchQuery) {
        features.filter { cfg ->
            val matchesCategory = selectedCategoryFilter == null || cfg.key.category == selectedCategoryFilter
            val matchesSearch = searchQuery.isBlank() ||
                    cfg.title.contains(searchQuery, ignoreCase = true) ||
                    cfg.description.contains(searchQuery, ignoreCase = true) ||
                    cfg.key.id.contains(searchQuery, ignoreCase = true) ||
                    cfg.key.category.title.contains(searchQuery, ignoreCase = true)
            matchesCategory && matchesSearch
        }
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = {
                    Column {
                        Text("Plug & Play Feature Hub 🔌", fontWeight = FontWeight.Bold, fontSize = 17.sp)
                        Text(
                            "$activeCount of $totalCount modules active • $healthyCount healthy",
                            fontSize = 11.5.sp,
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                    }
                },
                navigationIcon = {
                    IconButton(onClick = onNavigateBack, modifier = Modifier.testTag("features_back_button")) {
                        Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "Back")
                    }
                },
                actions = {
                    IconButton(
                        onClick = { showAuditLogsDialog = true },
                        modifier = Modifier.testTag("healing_audit_logs_btn")
                    ) {
                        BadgedBox(
                            badge = {
                                if (auditLogs.isNotEmpty()) {
                                    Badge(containerColor = MaterialTheme.colorScheme.primary) {
                                        Text("${auditLogs.size}")
                                    }
                                }
                            }
                        ) {
                            Icon(Icons.Default.Shield, contentDescription = "Self-Healing Audit Logs", tint = MaterialTheme.colorScheme.primary)
                        }
                    }
                    IconButton(
                        onClick = { showJsonDialog = true },
                        modifier = Modifier.testTag("features_json_io_button")
                    ) {
                        Icon(Icons.Default.Code, contentDescription = "JSON Config", tint = MaterialTheme.colorScheme.primary)
                    }
                    IconButton(
                        onClick = {
                            BookMySpaceRepository.resetFeaturesToDefault()
                            SelfHealingManager.resetAllModulesToHealthy()
                            Toast.makeText(context, "Reset all features & health state to standard defaults", Toast.LENGTH_SHORT).show()
                        },
                        modifier = Modifier.testTag("features_reset_button")
                    ) {
                        Icon(Icons.Default.RestartAlt, contentDescription = "Reset Defaults")
                    }
                },
                colors = TopAppBarDefaults.topAppBarColors(containerColor = MaterialTheme.colorScheme.surface)
            )
        },
        modifier = modifier.testTag("plug_and_play_features_screen")
    ) { paddingValues ->
        LazyColumn(
            modifier = Modifier
                .fillMaxSize()
                .padding(paddingValues)
                .padding(horizontal = 16.dp),
            verticalArrangement = Arrangement.spacedBy(14.dp)
        ) {
            item {
                Spacer(modifier = Modifier.height(4.dp))
                // 🛡️ SELF-HEALING & MODULAR ARCHITECTURE BANNER
                Card(
                    shape = RoundedCornerShape(16.dp),
                    colors = CardDefaults.cardColors(
                        containerColor = if (autoRecoveredCount > 0) Color(0xFF1976D2).copy(alpha = 0.12f) else MaterialTheme.colorScheme.primaryContainer.copy(alpha = 0.45f)
                    ),
                    border = BorderStroke(1.dp, if (autoRecoveredCount > 0) Color(0xFF1976D2).copy(alpha = 0.35f) else MaterialTheme.colorScheme.primary.copy(alpha = 0.3f)),
                    modifier = Modifier.fillMaxWidth()
                ) {
                    Column(modifier = Modifier.padding(14.dp)) {
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            Icon(
                                imageVector = Icons.Default.HealthAndSafety,
                                contentDescription = null,
                                tint = if (autoRecoveredCount > 0) Color(0xFF1976D2) else MaterialTheme.colorScheme.primary,
                                modifier = Modifier.size(20.dp)
                            )
                            Spacer(modifier = Modifier.width(8.dp))
                            Text(
                                text = "Independent & Self-Healing Modules",
                                fontWeight = FontWeight.Bold,
                                fontSize = 14.sp
                            )
                            Spacer(modifier = Modifier.weight(1f))
                            Surface(
                                color = if (autoRecoveredCount > 0) Color(0xFF1976D2) else Color(0xFF2E7D32),
                                shape = RoundedCornerShape(12.dp)
                            ) {
                                Text(
                                    text = if (autoRecoveredCount > 0) "AUTO-HEALED ($autoRecoveredCount)" else "100% HEALTHY",
                                    fontSize = 9.sp,
                                    fontWeight = FontWeight.ExtraBold,
                                    color = Color.White,
                                    modifier = Modifier.padding(horizontal = 8.dp, vertical = 3.dp)
                                )
                            }
                        }
                        Spacer(modifier = Modifier.height(6.dp))
                        Text(
                            text = "Every component (Category Checkbox Filter, Batch Waitlist Alerts, 1-Tap Booking, UPI Rail, Location Hierarchy, QR Passes) is isolated. If any module encounters a fault, it auto-switches to memory cache/fallback without crashing the app.",
                            fontSize = 11.5.sp,
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                            lineHeight = 16.sp
                        )

                        Spacer(modifier = Modifier.height(10.dp))

                        Row(
                            modifier = Modifier.fillMaxWidth(),
                            horizontalArrangement = Arrangement.spacedBy(8.dp)
                        ) {
                            Button(
                                onClick = {
                                    SelfHealingManager.runFullSystemDiagnostic(context) { result ->
                                        coroutineScope.launch {
                                            Toast.makeText(
                                                context,
                                                "✅ Diagnostics complete: ${result.healthyCount} healthy, ${result.autoRecoveredCount} auto-repaired in ${result.durationMs}ms",
                                                Toast.LENGTH_LONG
                                            ).show()
                                        }
                                    }
                                },
                                enabled = !isDiagnosticRunning,
                                shape = RoundedCornerShape(10.dp),
                                modifier = Modifier.weight(1f).height(38.dp).testTag("run_diagnostics_btn")
                            ) {
                                if (isDiagnosticRunning) {
                                    CircularProgressIndicator(modifier = Modifier.size(14.dp), strokeWidth = 2.dp, color = MaterialTheme.colorScheme.onPrimary)
                                    Spacer(modifier = Modifier.width(6.dp))
                                    Text("Diagnosing...", fontSize = 11.5.sp)
                                } else {
                                    Icon(Icons.Default.Healing, contentDescription = null, modifier = Modifier.size(15.dp))
                                    Spacer(modifier = Modifier.width(4.dp))
                                    Text("Run Auto-Heal Scan", fontSize = 11.5.sp, fontWeight = FontWeight.Bold)
                                }
                            }

                            OutlinedButton(
                                onClick = { showAuditLogsDialog = true },
                                shape = RoundedCornerShape(10.dp),
                                modifier = Modifier.height(38.dp)
                            ) {
                                Icon(Icons.Default.History, contentDescription = null, modifier = Modifier.size(14.dp))
                                Spacer(modifier = Modifier.width(4.dp))
                                Text("Audit Logs (${auditLogs.size})", fontSize = 11.sp)
                            }
                        }
                    }
                }
            }

            // Quick Preset Bar
            item {
                Column {
                    Text("Instant Presets (One-Click Configuration)", fontWeight = FontWeight.Bold, fontSize = 13.5.sp)
                    Spacer(modifier = Modifier.height(8.dp))
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .horizontalScroll(rememberScrollState()),
                        horizontalArrangement = Arrangement.spacedBy(8.dp)
                    ) {
                        FeaturePreset.entries.forEach { preset ->
                            FilterChip(
                                selected = false,
                                onClick = { showPresetConfirmDialog = preset },
                                label = {
                                    Row(verticalAlignment = Alignment.CenterVertically) {
                                        Text(preset.emoji, fontSize = 13.sp)
                                        Spacer(modifier = Modifier.width(5.dp))
                                        Column {
                                            Text(preset.title, fontWeight = FontWeight.Bold, fontSize = 11.sp)
                                        }
                                    }
                                },
                                shape = RoundedCornerShape(10.dp)
                            )
                        }
                    }
                }
            }

            // Search Bar & Filter Chips
            item {
                Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    OutlinedTextField(
                        value = searchQuery,
                        onValueChange = { searchQuery = it },
                        modifier = Modifier
                            .fillMaxWidth()
                            .testTag("feature_search_field"),
                        placeholder = { Text("Search feature, category, or parameter...") },
                        leadingIcon = { Icon(Icons.Default.Search, contentDescription = null) },
                        trailingIcon = {
                            if (searchQuery.isNotEmpty()) {
                                IconButton(onClick = { searchQuery = "" }) {
                                    Icon(Icons.Default.Close, contentDescription = "Clear")
                                }
                            }
                        },
                        singleLine = true,
                        shape = RoundedCornerShape(12.dp),
                        colors = OutlinedTextFieldDefaults.colors(
                            focusedContainerColor = MaterialTheme.colorScheme.surface,
                            unfocusedContainerColor = MaterialTheme.colorScheme.surface
                        )
                    )

                    // Category Tabs
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .horizontalScroll(rememberScrollState()),
                        horizontalArrangement = Arrangement.spacedBy(6.dp)
                    ) {
                        FilterChip(
                            selected = selectedCategoryFilter == null,
                            onClick = { selectedCategoryFilter = null },
                            label = { Text("All (${features.size})", fontSize = 11.sp) },
                            shape = RoundedCornerShape(8.dp)
                        )
                        FeatureCategory.entries.forEach { cat ->
                            val count = features.count { it.key.category == cat }
                            FilterChip(
                                selected = selectedCategoryFilter == cat,
                                onClick = { selectedCategoryFilter = if (selectedCategoryFilter == cat) null else cat },
                                label = { Text("${cat.emoji} ${cat.title} ($count)", fontSize = 11.sp) },
                                shape = RoundedCornerShape(8.dp)
                            )
                        }
                    }
                }
            }

            // Quick Batch Action Buttons
            item {
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.spacedBy(8.dp)
                ) {
                    OutlinedButton(
                        onClick = {
                            features.forEach { BookMySpaceRepository.toggleFeature(it.key, true) }
                            Toast.makeText(context, "Enabled all features", Toast.LENGTH_SHORT).show()
                        },
                        modifier = Modifier.weight(1f),
                        shape = RoundedCornerShape(10.dp)
                    ) {
                        Icon(Icons.Default.DoneAll, contentDescription = null, modifier = Modifier.size(15.dp))
                        Spacer(modifier = Modifier.width(4.dp))
                        Text("Enable All", fontSize = 11.sp)
                    }
                    OutlinedButton(
                        onClick = {
                            features.forEach {
                                if (!it.key.isCore) BookMySpaceRepository.toggleFeature(it.key, false)
                            }
                            Toast.makeText(context, "Disabled optional features", Toast.LENGTH_SHORT).show()
                        },
                        modifier = Modifier.weight(1f),
                        shape = RoundedCornerShape(10.dp)
                    ) {
                        Icon(Icons.Default.RemoveDone, contentDescription = null, modifier = Modifier.size(15.dp))
                        Spacer(modifier = Modifier.width(4.dp))
                        Text("Disable Non-Core", fontSize = 11.sp)
                    }
                }
            }

            // Feature Item List
            items(filteredFeatures, key = { it.key.id }) { config ->
                val report = healthReports[config.key]
                FeatureCardItem(
                    config = config,
                    healthReport = report,
                    onToggle = { isEnabled ->
                        BookMySpaceRepository.toggleFeature(config.key, isEnabled)
                        SelfHealingManager.updateModuleStatus(
                            config.key,
                            if (isEnabled) ModuleHealthStatus.HEALTHY else ModuleHealthStatus.STANDBY,
                            action = if (isEnabled) "Toggled ON by operator" else "Toggled OFF (Standby)"
                        )
                    },
                    onConfigure = {
                        editingFeatureConfig = config
                    },
                    onSimulateAnomaly = {
                        SelfHealingManager.updateModuleStatus(
                            config.key,
                            ModuleHealthStatus.AUTO_RECOVERED,
                            latencyMs = 4,
                            error = "Simulated synthetic I/O timeout",
                            action = "Self-healed: Switched to memory fallback cache & reset circuit breaker"
                        )
                        Toast.makeText(context, "🛡️ Simulated fault on ${config.title} -> Auto-Healed!", Toast.LENGTH_SHORT).show()
                    }
                )
            }

            item {
                Spacer(modifier = Modifier.height(24.dp))
            }
        }
    }

    // Modal: Self-Healing Audit Logs Dialog
    if (showAuditLogsDialog) {
        SelfHealingAuditLogsDialog(
            auditLogs = auditLogs,
            onDismiss = { showAuditLogsDialog = false },
            onClearLogs = {
                SelfHealingManager.resetAllModulesToHealthy()
                Toast.makeText(context, "Cleared audit logs & restored health states", Toast.LENGTH_SHORT).show()
            }
        )
    }

    // Modal: Edit Feature Parameters
    if (editingFeatureConfig != null) {
        FeatureParameterEditorDialog(
            config = editingFeatureConfig!!,
            onDismiss = { editingFeatureConfig = null },
            onSave = { updatedConfig ->
                BookMySpaceRepository.updateFeatureConfig(updatedConfig)
                editingFeatureConfig = null
                Toast.makeText(context, "Saved settings for ${updatedConfig.title}", Toast.LENGTH_SHORT).show()
            }
        )
    }

    // Modal: JSON Import / Export
    if (showJsonDialog) {
        FeatureJsonIoDialog(
            onDismiss = { showJsonDialog = false },
            onImport = { jsonStr ->
                val success = BookMySpaceRepository.importFeaturesJson(jsonStr)
                if (success) {
                    Toast.makeText(context, "Feature configuration imported successfully!", Toast.LENGTH_SHORT).show()
                    showJsonDialog = false
                } else {
                    Toast.makeText(context, "Invalid JSON format. Please verify syntax.", Toast.LENGTH_LONG).show()
                }
            }
        )
    }

    // Preset Confirmation Dialog
    if (showPresetConfirmDialog != null) {
        val preset = showPresetConfirmDialog!!
        AlertDialog(
            onDismissRequest = { showPresetConfirmDialog = null },
            title = {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Text(preset.emoji, fontSize = 20.sp)
                    Spacer(modifier = Modifier.width(8.dp))
                    Text("Apply Preset: ${preset.title}", fontSize = 16.sp, fontWeight = FontWeight.Bold)
                }
            },
            text = {
                Column {
                    Text(preset.description, fontSize = 13.sp)
                    Spacer(modifier = Modifier.height(10.dp))
                    Text("This will re-configure active module flags to match this profile.", fontSize = 11.5.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                }
            },
            confirmButton = {
                Button(
                    onClick = {
                        BookMySpaceRepository.applyFeaturePreset(preset)
                        Toast.makeText(context, "Applied ${preset.title}", Toast.LENGTH_SHORT).show()
                        showPresetConfirmDialog = null
                    }
                ) {
                    Text("Apply Preset")
                }
            },
            dismissButton = {
                TextButton(onClick = { showPresetConfirmDialog = null }) {
                    Text("Cancel")
                }
            }
        )
    }
}

@Composable
fun FeatureCardItem(
    config: FeatureModuleConfig,
    healthReport: ModuleHealthReport?,
    onToggle: (Boolean) -> Unit,
    onConfigure: () -> Unit,
    onSimulateAnomaly: () -> Unit
) {
    val key = config.key
    val isEnabled = config.isEnabled
    val healthStatus = healthReport?.status ?: if (isEnabled) ModuleHealthStatus.HEALTHY else ModuleHealthStatus.STANDBY

    Card(
        shape = RoundedCornerShape(14.dp),
        colors = CardDefaults.cardColors(
            containerColor = if (isEnabled) MaterialTheme.colorScheme.surface else MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.4f)
        ),
        border = BorderStroke(
            1.dp,
            if (healthStatus == ModuleHealthStatus.AUTO_RECOVERED) Color(0xFF1976D2).copy(alpha = 0.6f)
            else if (isEnabled) MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.5f)
            else MaterialTheme.colorScheme.outline.copy(alpha = 0.15f)
        ),
        elevation = CardDefaults.cardElevation(defaultElevation = if (isEnabled) 1.5.dp else 0.dp),
        modifier = Modifier
            .fillMaxWidth()
            .testTag("feature_card_${key.id}")
    ) {
        Column(modifier = Modifier.padding(14.dp)) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    modifier = Modifier.weight(1f)
                ) {
                    Box(
                        modifier = Modifier
                            .size(40.dp)
                            .clip(RoundedCornerShape(10.dp))
                            .background(
                                if (healthStatus == ModuleHealthStatus.AUTO_RECOVERED) Color(0xFF1976D2).copy(alpha = 0.15f)
                                else if (isEnabled) MaterialTheme.colorScheme.primaryContainer.copy(alpha = 0.6f)
                                else MaterialTheme.colorScheme.surfaceVariant
                            ),
                        contentAlignment = Alignment.Center
                    ) {
                        Text(key.emoji, fontSize = 18.sp)
                    }
                    Spacer(modifier = Modifier.width(10.dp))
                    Column {
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            Text(
                                text = config.title,
                                fontWeight = FontWeight.Bold,
                                fontSize = 13.5.sp,
                                color = if (isEnabled) MaterialTheme.colorScheme.onSurface else MaterialTheme.colorScheme.onSurface.copy(alpha = 0.6f)
                            )
                            if (key.isCore) {
                                Spacer(modifier = Modifier.width(6.dp))
                                Surface(
                                    color = Color(0xFF1E88E5).copy(alpha = 0.15f),
                                    shape = RoundedCornerShape(4.dp)
                                ) {
                                    Text(
                                        "CORE",
                                        fontSize = 8.5.sp,
                                        fontWeight = FontWeight.ExtraBold,
                                        color = Color(0xFF1E88E5),
                                        modifier = Modifier.padding(horizontal = 5.dp, vertical = 1.dp)
                                    )
                                }
                            }
                        }
                        
                        Row(
                            verticalAlignment = Alignment.CenterVertically,
                            horizontalArrangement = Arrangement.spacedBy(6.dp)
                        ) {
                            Text(
                                text = key.category.title,
                                fontSize = 10.5.sp,
                                color = MaterialTheme.colorScheme.onSurfaceVariant
                            )
                            Text("•", fontSize = 10.sp, color = MaterialTheme.colorScheme.outlineVariant)
                            
                            // Health Status Badge
                            Surface(
                                color = Color(healthStatus.colorHex).copy(alpha = 0.12f),
                                shape = RoundedCornerShape(4.dp)
                            ) {
                                Row(
                                    verticalAlignment = Alignment.CenterVertically,
                                    modifier = Modifier.padding(horizontal = 4.dp, vertical = 1.dp)
                                ) {
                                    Text(healthStatus.emoji, fontSize = 8.sp)
                                    Spacer(modifier = Modifier.width(3.dp))
                                    Text(
                                        healthStatus.label,
                                        fontSize = 9.sp,
                                        fontWeight = FontWeight.Bold,
                                        color = Color(healthStatus.colorHex)
                                    )
                                    if (healthReport != null && isEnabled) {
                                        Spacer(modifier = Modifier.width(3.dp))
                                        Text("(${healthReport.latencyMs}ms)", fontSize = 8.5.sp, color = Color(healthStatus.colorHex))
                                    }
                                }
                            }
                        }
                    }
                }

                Switch(
                    checked = isEnabled,
                    onCheckedChange = onToggle,
                    modifier = Modifier.testTag("toggle_${key.id}")
                )
            }

            Spacer(modifier = Modifier.height(8.dp))
            Text(
                text = config.description,
                fontSize = 11.5.sp,
                color = if (isEnabled) MaterialTheme.colorScheme.onSurfaceVariant else MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.6f),
                lineHeight = 16.sp
            )

            // Self-Healing Status Detail if recovered
            if (healthStatus == ModuleHealthStatus.AUTO_RECOVERED && healthReport?.lastHealingAction != null) {
                Spacer(modifier = Modifier.height(6.dp))
                Surface(
                    color = Color(0xFF1976D2).copy(alpha = 0.08f),
                    shape = RoundedCornerShape(6.dp),
                    modifier = Modifier.fillMaxWidth()
                ) {
                    Row(
                        modifier = Modifier.padding(horizontal = 8.dp, vertical = 4.dp),
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Icon(Icons.Default.Healing, contentDescription = null, tint = Color(0xFF1976D2), modifier = Modifier.size(12.dp))
                        Spacer(modifier = Modifier.width(6.dp))
                        Text(
                            text = healthReport.lastHealingAction ?: "Auto-repaired via safe memory fallback",
                            fontSize = 10.sp,
                            color = Color(0xFF1976D2),
                            maxLines = 2
                        )
                    }
                }
            }

            // Bottom Actions & Parameter Details
            Spacer(modifier = Modifier.height(10.dp))
            HorizontalDivider(color = MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.35f))
            Spacer(modifier = Modifier.height(6.dp))

            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Row(
                    modifier = Modifier.weight(1f),
                    horizontalArrangement = Arrangement.spacedBy(4.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Icon(Icons.Default.Tune, contentDescription = null, modifier = Modifier.size(13.dp), tint = MaterialTheme.colorScheme.primary)
                    val paramPreview = config.parameters.entries.take(2).joinToString(", ") { "${it.key}: ${it.value}" }
                    Text(
                        text = if (paramPreview.isNotBlank()) paramPreview else "Default parameters",
                        fontSize = 10.sp,
                        color = MaterialTheme.colorScheme.primary,
                        maxLines = 1
                    )
                }

                Row(horizontalArrangement = Arrangement.spacedBy(4.dp)) {
                    if (isEnabled) {
                        TextButton(
                            onClick = onSimulateAnomaly,
                            contentPadding = PaddingValues(horizontal = 6.dp, vertical = 2.dp),
                            modifier = Modifier.testTag("test_healing_${key.id}")
                        ) {
                            Text("Test Heal 🛡️", fontSize = 10.5.sp, color = MaterialTheme.colorScheme.secondary)
                        }
                    }

                    TextButton(
                        onClick = onConfigure,
                        contentPadding = PaddingValues(horizontal = 8.dp, vertical = 2.dp),
                        modifier = Modifier.testTag("configure_${key.id}")
                    ) {
                        Text("Configure ⚙️", fontSize = 11.sp, fontWeight = FontWeight.SemiBold)
                    }
                }
            }
        }
    }
}

@Composable
fun FeatureParameterEditorDialog(
    config: FeatureModuleConfig,
    onDismiss: () -> Unit,
    onSave: (FeatureModuleConfig) -> Unit
) {
    var customTitle by remember { mutableStateOf(config.customTitle) }
    var customDescription by remember { mutableStateOf(config.customDescription) }
    val paramState = remember { mutableStateMapOf<String, String>().apply { putAll(config.parameters) } }

    Dialog(onDismissRequest = onDismiss) {
        Card(
            shape = RoundedCornerShape(20.dp),
            colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface),
            modifier = Modifier
                .fillMaxWidth()
                .padding(vertical = 16.dp)
        ) {
            Column(
                modifier = Modifier
                    .padding(20.dp)
                    .fillMaxWidth()
            ) {
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Text(config.key.emoji, fontSize = 22.sp)
                        Spacer(modifier = Modifier.width(8.dp))
                        Column {
                            Text("Configure Feature", fontWeight = FontWeight.Bold, fontSize = 16.sp)
                            Text(config.key.id, fontSize = 10.5.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                        }
                    }
                    IconButton(onClick = onDismiss) {
                        Icon(Icons.Default.Close, contentDescription = "Close")
                    }
                }

                Spacer(modifier = Modifier.height(14.dp))

                LazyColumn(
                    modifier = Modifier
                        .weight(1f, fill = false)
                        .fillMaxWidth(),
                    verticalArrangement = Arrangement.spacedBy(10.dp)
                ) {
                    item {
                        OutlinedTextField(
                            value = customTitle,
                            onValueChange = { customTitle = it },
                            label = { Text("Display Title (Optional Override)") },
                            placeholder = { Text(config.key.displayName) },
                            modifier = Modifier.fillMaxWidth(),
                            singleLine = true
                        )
                    }

                    item {
                        OutlinedTextField(
                            value = customDescription,
                            onValueChange = { customDescription = it },
                            label = { Text("Summary Description") },
                            placeholder = { Text(config.key.summary) },
                            modifier = Modifier.fillMaxWidth(),
                            minLines = 2
                        )
                    }

                    item {
                        Spacer(modifier = Modifier.height(4.dp))
                        Text("Module Parameters 🎛️", fontWeight = FontWeight.Bold, fontSize = 13.sp)
                        Text("Tune behavior without editing application code.", fontSize = 11.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                    }

                    // Dynamically render all parameter fields
                    val allParamKeys = (config.key.defaultParameters.keys + config.parameters.keys).toList()
                    items(allParamKeys) { paramKey ->
                        val currentVal = paramState[paramKey] ?: config.key.defaultParameters[paramKey] ?: ""
                        OutlinedTextField(
                            value = currentVal,
                            onValueChange = { paramState[paramKey] = it },
                            label = { Text(paramKey) },
                            modifier = Modifier.fillMaxWidth(),
                            singleLine = true
                        )
                    }
                }

                Spacer(modifier = Modifier.height(16.dp))

                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.End,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    TextButton(
                        onClick = {
                            paramState.clear()
                            paramState.putAll(config.key.defaultParameters)
                            customTitle = ""
                            customDescription = ""
                        }
                    ) {
                        Text("Reset Defaults", fontSize = 12.sp)
                    }
                    Spacer(modifier = Modifier.width(8.dp))
                    Button(
                        onClick = {
                            val updated = config.copy(
                                customTitle = customTitle.trim(),
                                customDescription = customDescription.trim(),
                                parameters = paramState.toMap(),
                                lastModified = System.currentTimeMillis()
                            )
                            onSave(updated)
                        }
                    ) {
                        Text("Save Changes")
                    }
                }
            }
        }
    }
}

@Composable
fun FeatureJsonIoDialog(
    onDismiss: () -> Unit,
    onImport: (String) -> Unit
) {
    val clipboardManager = LocalClipboardManager.current
    val context = LocalContext.current
    var jsonText by remember { mutableStateOf(BookMySpaceRepository.exportFeaturesJson()) }

    Dialog(onDismissRequest = onDismiss) {
        Card(
            shape = RoundedCornerShape(20.dp),
            colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface),
            modifier = Modifier
                .fillMaxWidth()
                .padding(vertical = 16.dp)
        ) {
            Column(modifier = Modifier.padding(20.dp)) {
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Icon(Icons.Default.Code, contentDescription = null, tint = MaterialTheme.colorScheme.primary)
                        Spacer(modifier = Modifier.width(8.dp))
                        Text("Export / Import JSON", fontWeight = FontWeight.Bold, fontSize = 16.sp)
                    }
                    IconButton(onClick = onDismiss) {
                        Icon(Icons.Default.Close, contentDescription = "Close")
                    }
                }

                Spacer(modifier = Modifier.height(8.dp))
                Text(
                    "Export your exact feature setup to share across staging/production, or paste a JSON configuration string below.",
                    fontSize = 11.5.sp,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
                Spacer(modifier = Modifier.height(12.dp))

                OutlinedTextField(
                    value = jsonText,
                    onValueChange = { jsonText = it },
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(220.dp),
                    textStyle = LocalTextStyle.current.copy(fontSize = 11.sp),
                    placeholder = { Text("Paste JSON here...") }
                )

                Spacer(modifier = Modifier.height(14.dp))

                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    OutlinedButton(
                        onClick = {
                            clipboardManager.setText(AnnotatedString(jsonText))
                            Toast.makeText(context, "Copied JSON to clipboard!", Toast.LENGTH_SHORT).show()
                        }
                    ) {
                        Icon(Icons.Default.ContentCopy, contentDescription = null, modifier = Modifier.size(15.dp))
                        Spacer(modifier = Modifier.width(4.dp))
                        Text("Copy JSON", fontSize = 12.sp)
                    }

                    Button(
                        onClick = { onImport(jsonText) }
                    ) {
                        Icon(Icons.Default.Download, contentDescription = null, modifier = Modifier.size(15.dp))
                        Spacer(modifier = Modifier.width(4.dp))
                        Text("Apply JSON", fontSize = 12.sp)
                    }
                }
            }
        }
    }
}

@Composable
fun SelfHealingAuditLogsDialog(
    auditLogs: List<com.bookmyspace.bookmyspace.data.healing.SelfHealingAuditEntry>,
    onDismiss: () -> Unit,
    onClearLogs: () -> Unit
) {
    Dialog(onDismissRequest = onDismiss) {
        Card(
            shape = RoundedCornerShape(20.dp),
            colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface),
            modifier = Modifier
                .fillMaxWidth()
                .padding(vertical = 16.dp)
        ) {
            Column(modifier = Modifier.padding(20.dp)) {
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Icon(Icons.Default.Shield, contentDescription = null, tint = Color(0xFF1976D2))
                        Spacer(modifier = Modifier.width(8.dp))
                        Text("Self-Healing Telemetry", fontWeight = FontWeight.Bold, fontSize = 16.sp)
                    }
                    IconButton(onClick = onDismiss) {
                        Icon(Icons.Default.Close, contentDescription = "Close")
                    }
                }

                Spacer(modifier = Modifier.height(4.dp))
                Text(
                    "Real-time ledger of fault detections, isolated exceptions, memory fallback activations, and auto-repair actions.",
                    fontSize = 11.sp,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )

                Spacer(modifier = Modifier.height(12.dp))

                if (auditLogs.isEmpty()) {
                    Box(
                        modifier = Modifier
                            .fillMaxWidth()
                            .height(180.dp)
                            .background(MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.3f), RoundedCornerShape(12.dp)),
                        contentAlignment = Alignment.Center
                    ) {
                        Column(horizontalAlignment = Alignment.CenterHorizontally) {
                            Text("🛡️", fontSize = 32.sp)
                            Spacer(modifier = Modifier.height(8.dp))
                            Text("Zero Faults Detected", fontWeight = FontWeight.Bold, fontSize = 13.sp)
                            Text("All independent modules are running seamlessly.", fontSize = 11.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                        }
                    }
                } else {
                    LazyColumn(
                        modifier = Modifier
                            .fillMaxWidth()
                            .heightIn(max = 300.dp),
                        verticalArrangement = Arrangement.spacedBy(8.dp)
                    ) {
                        items(auditLogs, key = { it.id }) { log ->
                            Card(
                                shape = RoundedCornerShape(10.dp),
                                colors = CardDefaults.cardColors(containerColor = Color(0xFF1976D2).copy(alpha = 0.07f)),
                                border = BorderStroke(1.dp, Color(0xFF1976D2).copy(alpha = 0.25f))
                            ) {
                                Column(modifier = Modifier.padding(10.dp)) {
                                    Row(
                                        modifier = Modifier.fillMaxWidth(),
                                        horizontalArrangement = Arrangement.SpaceBetween,
                                        verticalAlignment = Alignment.CenterVertically
                                    ) {
                                        Text(
                                            "${log.featureKey.emoji} ${log.featureKey.displayName}",
                                            fontWeight = FontWeight.Bold,
                                            fontSize = 11.5.sp
                                        )
                                        Surface(
                                            color = Color(0xFF2E7D32),
                                            shape = RoundedCornerShape(4.dp)
                                        ) {
                                            Text(
                                                log.recoveryOutcome,
                                                color = Color.White,
                                                fontSize = 8.5.sp,
                                                fontWeight = FontWeight.ExtraBold,
                                                modifier = Modifier.padding(horizontal = 4.dp, vertical = 1.dp)
                                            )
                                        }
                                    }
                                    Spacer(modifier = Modifier.height(4.dp))
                                    Text(
                                        "Anomaly: ${log.anomalyDescription}",
                                        fontSize = 10.5.sp,
                                        color = MaterialTheme.colorScheme.error,
                                        maxLines = 2
                                    )
                                    Text(
                                        "Auto-Heal: ${log.selfHealingAction}",
                                        fontSize = 10.5.sp,
                                        color = Color(0xFF1976D2),
                                        fontWeight = FontWeight.Medium
                                    )
                                }
                            }
                        }
                    }
                }

                Spacer(modifier = Modifier.height(14.dp))

                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.End
                ) {
                    if (auditLogs.isNotEmpty()) {
                        OutlinedButton(onClick = onClearLogs) {
                            Text("Clear & Reset", fontSize = 11.5.sp)
                        }
                        Spacer(modifier = Modifier.width(8.dp))
                    }
                    Button(onClick = onDismiss) {
                        Text("Done", fontSize = 11.5.sp)
                    }
                }
            }
        }
    }
}
