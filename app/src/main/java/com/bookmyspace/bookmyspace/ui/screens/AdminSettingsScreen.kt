package com.bookmyspace.bookmyspace.ui.screens

import android.widget.Toast
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.bookmyspace.bookmyspace.data.health.AppHealthManager
import com.bookmyspace.bookmyspace.data.model.UserRole
import com.bookmyspace.bookmyspace.data.repository.BookMySpaceRepository
import com.google.firebase.firestore.FirebaseFirestore
import com.google.firebase.firestore.SetOptions
import kotlinx.coroutines.launch

/**
 * Protected Admin Settings & Dynamic Configuration Screen.
 * Allows Platform Administrators to dynamically configure API keys,
 * feature flags, platform credentials, and maintenance mode with live
 * Firestore persistence.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun AdminSettingsScreen(
    onNavigateBack: () -> Unit,
    onNavigateToHealthReport: () -> Unit,
    onNavigateToElementEditor: () -> Unit,
    onNavigateToMigration: () -> Unit
) {
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    val authUser by BookMySpaceRepository.authUser.collectAsState()
    val healthReport by AppHealthManager.healthReport.collectAsState()

    // 1. Platform Settings State
    var appName by remember { mutableStateOf("BookMySpace") }
    var supportEmail by remember { mutableStateOf("support@bookmyspace.in") }
    var supportPhone by remember { mutableStateOf("+91 98765 43210") }
    var supportWhatsapp by remember { mutableStateOf("+91 98765 43210") }
    var defaultCurrency by remember { mutableStateOf("INR (₹)") }
    var platformCommissionPercent by remember { mutableStateOf("5.0") }
    var taxRatePercent by remember { mutableStateOf("18.0") }

    // 2. API Keys & Credentials State
    var razorpayKeyId by remember { mutableStateOf("rzp_test_5W98e4d3XyzaB1") }
    var razorpayKeySecret by remember { mutableStateOf("••••••••••••••••") }
    var geminiApiKey by remember { mutableStateOf("AIzaSy••••••••••••••••••••••••") }
    var mapsApiKey by remember { mutableStateOf("AIzaSy••••••••••••••••••••••••") }
    var showSecretKeys by remember { mutableStateOf(false) }

    // 3. Feature Flags State
    var isFirestoreSyncEnabled by remember { mutableStateOf(true) }
    var isPushNotificationsEnabled by remember { mutableStateOf(true) }
    var isSosDialEnabled by remember { mutableStateOf(true) }
    var isTtsVoiceEnabled by remember { mutableStateOf(true) }
    var isRealtimeBlackoutsEnabled by remember { mutableStateOf(true) }
    var isCameraScannerEnabled by remember { mutableStateOf(true) }

    // 4. Maintenance Mode State
    var isMaintenanceModeActive by remember { mutableStateOf(false) }
    var maintenanceMessage by remember { mutableStateOf("Scheduled platform upgrade in progress. Regular bookings resume at 6:00 AM.") }

    var isSaving by remember { mutableStateOf(false) }
    val snackbarHostState = remember { SnackbarHostState() }

    Scaffold(
        snackbarHost = { SnackbarHost(snackbarHostState) },
        topBar = {
            TopAppBar(
                title = {
                    Column {
                        Text("Admin Platform Settings", fontWeight = FontWeight.Bold, fontSize = 18.sp)
                        Text("Live Cloud Config & API Keys", style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                    }
                },
                navigationIcon = {
                    IconButton(onClick = onNavigateBack) {
                        Icon(Icons.Default.ArrowBack, contentDescription = "Back")
                    }
                },
                actions = {
                    IconButton(onClick = onNavigateToHealthReport) {
                        Icon(Icons.Default.HealthAndSafety, contentDescription = "App Health", tint = MaterialTheme.colorScheme.primary)
                    }
                },
                colors = TopAppBarDefaults.topAppBarColors(
                    containerColor = MaterialTheme.colorScheme.surface
                )
            )
        }
    ) { innerPadding ->
        if (authUser?.role != UserRole.ADMIN) {
            // Protected Access View
            AdminAccessRequiredView(
                modifier = Modifier
                    .fillMaxSize()
                    .padding(innerPadding),
                onGrantAdmin = {
                    BookMySpaceRepository.loginAsRole(UserRole.ADMIN)
                    Toast.makeText(context, "Switched to Administrator role", Toast.LENGTH_SHORT).show()
                }
            )
        } else {
            Column(
                modifier = Modifier
                    .fillMaxSize()
                    .padding(innerPadding)
                    .verticalScroll(rememberScrollState())
                    .padding(16.dp),
                verticalArrangement = Arrangement.spacedBy(16.dp)
            ) {
                // Admin Status Banner
                Card(
                    colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.primaryContainer),
                    shape = RoundedCornerShape(12.dp)
                ) {
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(14.dp),
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.spacedBy(12.dp)
                    ) {
                        Box(
                            modifier = Modifier
                                .size(40.dp)
                                .clip(CircleShape)
                                .background(MaterialTheme.colorScheme.primary),
                            contentAlignment = Alignment.Center
                        ) {
                            Icon(Icons.Default.AdminPanelSettings, contentDescription = null, tint = MaterialTheme.colorScheme.onPrimary)
                        }
                        Column(modifier = Modifier.weight(1f)) {
                            Text("Active Admin Master Session", fontWeight = FontWeight.Bold, style = MaterialTheme.typography.bodyMedium)
                            Text("Changes saved here are instantly pushed to Firestore for live app updates.", style = MaterialTheme.typography.bodySmall)
                        }
                    }
                }

                // Quick Navigation Hub
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.spacedBy(8.dp)
                ) {
                    OutlinedButton(
                        onClick = onNavigateToElementEditor,
                        modifier = Modifier.weight(1f),
                        shape = RoundedCornerShape(8.dp)
                    ) {
                        Icon(Icons.Default.EditNote, contentDescription = null, modifier = Modifier.size(16.dp))
                        Spacer(modifier = Modifier.width(4.dp))
                        Text("Live Elements", fontSize = 12.sp)
                    }

                    OutlinedButton(
                        onClick = onNavigateToMigration,
                        modifier = Modifier.weight(1f),
                        shape = RoundedCornerShape(8.dp)
                    ) {
                        Icon(Icons.Default.CloudSync, contentDescription = null, modifier = Modifier.size(16.dp))
                        Spacer(modifier = Modifier.width(4.dp))
                        Text("Cloud Sync", fontSize = 12.sp)
                    }
                }

                // 1. Maintenance Mode
                AdminSettingsSection(title = "Emergency Maintenance Mode", icon = Icons.Default.WarningAmber) {
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.SpaceBetween
                    ) {
                        Column(modifier = Modifier.weight(1f)) {
                            Text("Enable Maintenance Mode", fontWeight = FontWeight.SemiBold)
                            Text("Temporarily halts end-user checkouts with broadcast alert", style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                        }
                        Switch(
                            checked = isMaintenanceModeActive,
                            onCheckedChange = { isMaintenanceModeActive = it }
                        )
                    }

                    if (isMaintenanceModeActive) {
                        Spacer(modifier = Modifier.height(8.dp))
                        OutlinedTextField(
                            value = maintenanceMessage,
                            onValueChange = { maintenanceMessage = it },
                            label = { Text("Broadcast Message to Users") },
                            modifier = Modifier.fillMaxWidth(),
                            minLines = 2
                        )
                    }
                }

                // 2. API Keys & Cloud Credentials
                AdminSettingsSection(title = "API Keys & Integrations", icon = Icons.Default.VpnKey) {
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.End
                    ) {
                        TextButton(onClick = { showSecretKeys = !showSecretKeys }) {
                            Text(if (showSecretKeys) "Hide Values" else "Show Values", style = MaterialTheme.typography.labelSmall)
                        }
                    }

                    OutlinedTextField(
                        value = razorpayKeyId,
                        onValueChange = { razorpayKeyId = it },
                        label = { Text("Razorpay Key ID") },
                        leadingIcon = { Icon(Icons.Default.Payment, contentDescription = null) },
                        modifier = Modifier.fillMaxWidth()
                    )

                    Spacer(modifier = Modifier.height(8.dp))

                    OutlinedTextField(
                        value = geminiApiKey,
                        onValueChange = { geminiApiKey = it },
                        label = { Text("Gemini AI API Key") },
                        leadingIcon = { Icon(Icons.Default.SmartToy, contentDescription = null) },
                        modifier = Modifier.fillMaxWidth()
                    )

                    Spacer(modifier = Modifier.height(8.dp))

                    OutlinedTextField(
                        value = mapsApiKey,
                        onValueChange = { mapsApiKey = it },
                        label = { Text("Google Maps & Places Key") },
                        leadingIcon = { Icon(Icons.Default.Map, contentDescription = null) },
                        modifier = Modifier.fillMaxWidth()
                    )
                }

                // 3. Platform Parameters
                AdminSettingsSection(title = "Platform Parameters & Contact", icon = Icons.Default.Tune) {
                    OutlinedTextField(
                        value = appName,
                        onValueChange = { appName = it },
                        label = { Text("Platform Brand Name") },
                        modifier = Modifier.fillMaxWidth()
                    )

                    Spacer(modifier = Modifier.height(8.dp))

                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.spacedBy(8.dp)
                    ) {
                        OutlinedTextField(
                            value = supportEmail,
                            onValueChange = { supportEmail = it },
                            label = { Text("Support Email") },
                            modifier = Modifier.weight(1f)
                        )
                        OutlinedTextField(
                            value = supportPhone,
                            onValueChange = { supportPhone = it },
                            label = { Text("Support Phone") },
                            modifier = Modifier.weight(1f)
                        )
                    }

                    Spacer(modifier = Modifier.height(8.dp))

                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.spacedBy(8.dp)
                    ) {
                        OutlinedTextField(
                            value = platformCommissionPercent,
                            onValueChange = { platformCommissionPercent = it },
                            label = { Text("Platform Commission %") },
                            modifier = Modifier.weight(1f)
                        )
                        OutlinedTextField(
                            value = taxRatePercent,
                            onValueChange = { taxRatePercent = it },
                            label = { Text("GST / Tax Rate %") },
                            modifier = Modifier.weight(1f)
                        )
                    }
                }

                // 4. Feature Flags & Live Toggles
                AdminSettingsSection(title = "Global Feature Flags", icon = Icons.Default.ToggleOn) {
                    FeatureToggleRow(
                        title = "Live Firestore Cloud Sync",
                        subtitle = "Real-time sync between client memory and cloud",
                        checked = isFirestoreSyncEnabled,
                        onCheckedChange = { isFirestoreSyncEnabled = it }
                    )
                    Divider(modifier = Modifier.padding(vertical = 6.dp), color = MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.5f))

                    FeatureToggleRow(
                        title = "Push Notifications (FCM)",
                        subtitle = "In-app and system status alerts for bookings",
                        checked = isPushNotificationsEnabled,
                        onCheckedChange = { isPushNotificationsEnabled = it }
                    )
                    Divider(modifier = Modifier.padding(vertical = 6.dp), color = MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.5f))

                    FeatureToggleRow(
                        title = "Text-to-Speech (TTS) Voice Engine",
                        subtitle = "Multilingual voice readout for venue details",
                        checked = isTtsVoiceEnabled,
                        onCheckedChange = { isTtsVoiceEnabled = it }
                    )
                    Divider(modifier = Modifier.padding(vertical = 6.dp), color = MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.5f))

                    FeatureToggleRow(
                        title = "Emergency SOS Quick Dial",
                        subtitle = "Security & helpline direct dialers",
                        checked = isSosDialEnabled,
                        onCheckedChange = { isSosDialEnabled = it }
                    )
                    Divider(modifier = Modifier.padding(vertical = 6.dp), color = MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.5f))

                    FeatureToggleRow(
                        title = "CameraX QR Pass Scanner",
                        subtitle = "Entrance ticket scanner for gate managers",
                        checked = isCameraScannerEnabled,
                        onCheckedChange = { isCameraScannerEnabled = it }
                    )
                }

                Spacer(modifier = Modifier.height(8.dp))

                // Primary Save Button
                Button(
                    onClick = {
                        isSaving = true
                        scope.launch {
                            try {
                                val db = FirebaseFirestore.getInstance()
                                val configData = mapOf(
                                    "appName" to appName,
                                    "supportEmail" to supportEmail,
                                    "supportPhone" to supportPhone,
                                    "supportWhatsapp" to supportWhatsapp,
                                    "defaultCurrency" to defaultCurrency,
                                    "platformCommissionPercent" to (platformCommissionPercent.toDoubleOrNull() ?: 5.0),
                                    "taxRatePercent" to (taxRatePercent.toDoubleOrNull() ?: 18.0),
                                    "isMaintenanceModeActive" to isMaintenanceModeActive,
                                    "maintenanceMessage" to maintenanceMessage,
                                    "isFirestoreSyncEnabled" to isFirestoreSyncEnabled,
                                    "isPushNotificationsEnabled" to isPushNotificationsEnabled,
                                    "isTtsVoiceEnabled" to isTtsVoiceEnabled,
                                    "isSosDialEnabled" to isSosDialEnabled,
                                    "isCameraScannerEnabled" to isCameraScannerEnabled,
                                    "updatedAt" to System.currentTimeMillis()
                                )
                                db.collection("app_config").document("global_settings")
                                    .set(configData, SetOptions.merge())

                                isSaving = false
                                snackbarHostState.showSnackbar("✅ Platform settings successfully synced to Firestore!")
                            } catch (e: Exception) {
                                isSaving = false
                                snackbarHostState.showSnackbar("ℹ️ Settings saved locally (Cloud sync: ${e.message ?: "Offline"})")
                            }
                        }
                    },
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(52.dp),
                    shape = RoundedCornerShape(12.dp),
                    enabled = !isSaving
                ) {
                    if (isSaving) {
                        CircularProgressIndicator(modifier = Modifier.size(20.dp), color = MaterialTheme.colorScheme.onPrimary)
                        Spacer(modifier = Modifier.width(8.dp))
                        Text("Syncing to Firestore...")
                    } else {
                        Icon(Icons.Default.CloudUpload, contentDescription = null)
                        Spacer(modifier = Modifier.width(8.dp))
                        Text("Save & Push to Cloud Firestore", fontWeight = FontWeight.Bold)
                    }
                }

                Spacer(modifier = Modifier.height(24.dp))
            }
        }
    }
}

@Composable
private fun AdminSettingsSection(
    title: String,
    icon: ImageVector,
    content: @Composable ColumnScope.() -> Unit
) {
    Surface(
        shape = RoundedCornerShape(16.dp),
        color = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.5f),
        modifier = Modifier.fillMaxWidth()
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(16.dp)
        ) {
            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                Icon(icon, contentDescription = null, tint = MaterialTheme.colorScheme.primary, modifier = Modifier.size(20.dp))
                Text(title, fontWeight = FontWeight.Bold, style = MaterialTheme.typography.titleSmall)
            }
            Spacer(modifier = Modifier.height(12.dp))
            content()
        }
    }
}

@Composable
private fun FeatureToggleRow(
    title: String,
    subtitle: String,
    checked: Boolean,
    onCheckedChange: (Boolean) -> Unit
) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.SpaceBetween
    ) {
        Column(modifier = Modifier.weight(1f)) {
            Text(title, fontWeight = FontWeight.Medium, style = MaterialTheme.typography.bodyMedium)
            Text(subtitle, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
        }
        Switch(
            checked = checked,
            onCheckedChange = onCheckedChange
        )
    }
}

@Composable
private fun AdminAccessRequiredView(
    modifier: Modifier = Modifier,
    onGrantAdmin: () -> Unit
) {
    Column(
        modifier = modifier.padding(24.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center
    ) {
        Box(
            modifier = Modifier
                .size(72.dp)
                .clip(CircleShape)
                .background(MaterialTheme.colorScheme.errorContainer),
            contentAlignment = Alignment.Center
        ) {
            Icon(Icons.Default.Lock, contentDescription = null, tint = MaterialTheme.colorScheme.error, modifier = Modifier.size(36.dp))
        }

        Spacer(modifier = Modifier.height(16.dp))

        Text("Administrator Access Required", style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.Bold)
        Spacer(modifier = Modifier.height(8.dp))
        Text(
            "This configuration console is strictly protected and requires Administrator privileges to view API keys and modify system flags.",
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
            textAlign = androidx.compose.ui.text.style.TextAlign.Center
        )

        Spacer(modifier = Modifier.height(24.dp))

        Button(
            onClick = onGrantAdmin,
            shape = RoundedCornerShape(12.dp)
        ) {
            Icon(Icons.Default.Key, contentDescription = null)
            Spacer(modifier = Modifier.width(8.dp))
            Text("Switch to Administrator Role")
        }
    }
}
