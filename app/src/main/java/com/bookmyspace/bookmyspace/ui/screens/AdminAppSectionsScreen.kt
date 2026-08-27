package com.bookmyspace.bookmyspace.ui.screens

import android.widget.Toast
import androidx.compose.animation.*
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
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.bookmyspace.bookmyspace.data.health.CategoryHealthEngine
import com.bookmyspace.bookmyspace.data.health.CategoryHealthReport
import com.bookmyspace.bookmyspace.data.health.SelfHealResult
import com.bookmyspace.bookmyspace.data.model.AppSectionConfig
import com.bookmyspace.bookmyspace.data.model.VenueCategory
import com.bookmyspace.bookmyspace.data.repository.BookMySpaceRepository
import java.text.SimpleDateFormat
import java.util.*

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun AdminAppSectionsScreen(
    onNavigateBack: () -> Unit,
    onNavigateToPlugAndPlay: () -> Unit = {},
    modifier: Modifier = Modifier
) {
    val context = LocalContext.current
    val appSections by BookMySpaceRepository.appSections.collectAsState()
    val categories by BookMySpaceRepository.categories.collectAsState()
    val healthReports by CategoryHealthEngine.categoryHealthReports.collectAsState()
    val lastAuditLogs by CategoryHealthEngine.lastSelfHealAudit.collectAsState()

    var selectedTab by remember { mutableIntStateOf(0) } // 0: Categories (ON/OFF & Self-Healing), 1: Core App Sections, 2: Self-Healing Audit
    var searchQuery by remember { mutableStateOf("") }
    var filterMode by remember { mutableStateOf("ALL") } // ALL, ACTIVE_ONLY, INACTIVE_ONLY, NEEDS_HEALING
    var showAddCategoryDialog by remember { mutableStateOf(false) }
    var showHealSummaryDialog by remember { mutableStateOf<List<SelfHealResult>?>(null) }
    var inspectingCategoryReport by remember { mutableStateOf<CategoryHealthReport?>(null) }

    val totalCategories = categories.size
    val activeCategoriesCount = categories.count { it.isActive }
    val disabledCategoriesCount = totalCategories - activeCategoriesCount
    val healthyCategoriesCount = healthReports.count { it.isHealthy }

    val filteredCategories = remember(categories, searchQuery, filterMode, healthReports) {
        categories.filter { cat ->
            val matchesQuery = searchQuery.isBlank() ||
                    cat.name.contains(searchQuery, ignoreCase = true) ||
                    cat.slug.contains(searchQuery, ignoreCase = true)

            val report = healthReports.firstOrNull { it.categorySlug == cat.slug || it.categoryId == cat.id }
            val isHealthy = report?.isHealthy ?: true

            val matchesFilter = when (filterMode) {
                "ACTIVE_ONLY" -> cat.isActive
                "INACTIVE_ONLY" -> !cat.isActive
                "NEEDS_HEALING" -> !isHealthy
                else -> true
            }

            matchesQuery && matchesFilter
        }
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = {
                    Column {
                        Text("Category Governance & Self-Healing", fontWeight = FontWeight.Bold, fontSize = 16.sp)
                        Text("Modular ON/OFF • Independent • Auto-Repair", fontSize = 11.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                    }
                },
                navigationIcon = {
                    IconButton(onClick = onNavigateBack) {
                        Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "Back")
                    }
                },
                actions = {
                    IconButton(
                        onClick = onNavigateToPlugAndPlay,
                        modifier = Modifier.testTag("admin_plug_and_play_icon_button")
                    ) {
                        Icon(Icons.Default.Extension, contentDescription = "Plug & Play Features", tint = MaterialTheme.colorScheme.primary)
                    }
                    IconButton(
                        onClick = {
                            val results = CategoryHealthEngine.selfHealAllCategories()
                            showHealSummaryDialog = results
                            Toast.makeText(context, "✨ Self-healing executed for all $totalCategories categories!", Toast.LENGTH_SHORT).show()
                        },
                        modifier = Modifier.testTag("admin_self_heal_all_icon_button")
                    ) {
                        Icon(Icons.Default.Healing, contentDescription = "Self-Heal All", tint = Color(0xFF2E7D32))
                    }
                    IconButton(
                        onClick = { showAddCategoryDialog = true },
                        modifier = Modifier.testTag("admin_add_category_button")
                    ) {
                        Icon(Icons.Default.AddCircle, contentDescription = "Add Category", tint = MaterialTheme.colorScheme.primary)
                    }
                },
                colors = TopAppBarDefaults.topAppBarColors(containerColor = MaterialTheme.colorScheme.surface)
            )
        },
        modifier = modifier.testTag("admin_app_sections_screen")
    ) { paddingValues ->
        LazyColumn(
            modifier = Modifier
                .fillMaxSize()
                .padding(paddingValues)
                .padding(horizontal = 16.dp, vertical = 8.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            // Master Navigation / Plug & Play Shortcut
            item {
                Card(
                    shape = RoundedCornerShape(14.dp),
                    colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.primaryContainer.copy(alpha = 0.45f)),
                    border = BorderStroke(1.dp, MaterialTheme.colorScheme.primary.copy(alpha = 0.25f)),
                    modifier = Modifier
                        .fillMaxWidth()
                        .clickable { onNavigateToPlugAndPlay() }
                        .testTag("admin_goto_plug_and_play_card")
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
                            Box(
                                modifier = Modifier
                                    .size(38.dp)
                                    .background(MaterialTheme.colorScheme.primary, RoundedCornerShape(10.dp)),
                                contentAlignment = Alignment.Center
                            ) {
                                Icon(Icons.Default.Extension, contentDescription = null, tint = MaterialTheme.colorScheme.onPrimary, modifier = Modifier.size(20.dp))
                            }
                            Spacer(modifier = Modifier.width(12.dp))
                            Column {
                                Text("Plug & Play Feature Hub 🔌", fontWeight = FontWeight.Bold, fontSize = 13.5.sp)
                                Text("Manage all 24+ modular plugins, payment gateways & AI services", fontSize = 11.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                            }
                        }
                        Icon(Icons.Default.ChevronRight, contentDescription = null, tint = MaterialTheme.colorScheme.primary)
                    }
                }
            }

            // Modular Health Overview Card
            item {
                Card(
                    shape = RoundedCornerShape(16.dp),
                    colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.45f)),
                    border = BorderStroke(1.dp, MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.3f)),
                    modifier = Modifier.fillMaxWidth()
                ) {
                    Column(modifier = Modifier.padding(14.dp)) {
                        Row(
                            modifier = Modifier.fillMaxWidth(),
                            horizontalArrangement = Arrangement.SpaceBetween,
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            Row(verticalAlignment = Alignment.CenterVertically) {
                                Box(
                                    modifier = Modifier
                                        .size(32.dp)
                                        .background(Color(0xFF2E7D32).copy(alpha = 0.15f), CircleShape),
                                    contentAlignment = Alignment.Center
                                ) {
                                    Icon(Icons.Default.Shield, contentDescription = null, tint = Color(0xFF2E7D32), modifier = Modifier.size(18.dp))
                                }
                                Spacer(modifier = Modifier.width(8.dp))
                                Column {
                                    Text("Autonomous Modular Health", fontWeight = FontWeight.Bold, fontSize = 14.sp)
                                    Text("Each category runs independently with zero ripple failures", fontSize = 10.5.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                                }
                            }

                            // Health indicator chip
                            Surface(
                                shape = RoundedCornerShape(8.dp),
                                color = if (healthyCategoriesCount == totalCategories) Color(0xFFE8F5E9) else Color(0xFFFFF3E0),
                                border = BorderStroke(1.dp, if (healthyCategoriesCount == totalCategories) Color(0xFF81C784) else Color(0xFFFFB74D))
                            ) {
                                Text(
                                    text = if (healthyCategoriesCount == totalCategories) "100% OPERATIONAL" else "$healthyCategoriesCount/$totalCategories HEALTHY",
                                    fontSize = 10.sp,
                                    fontWeight = FontWeight.Bold,
                                    color = if (healthyCategoriesCount == totalCategories) Color(0xFF2E7D32) else Color(0xFFE65100),
                                    modifier = Modifier.padding(horizontal = 8.dp, vertical = 4.dp)
                                )
                            }
                        }

                        Spacer(modifier = Modifier.height(12.dp))

                        // Stats Row
                        Row(
                            modifier = Modifier.fillMaxWidth(),
                            horizontalArrangement = Arrangement.spacedBy(8.dp)
                        ) {
                            CategoryStatPill(
                                label = "Total Categories",
                                value = "$totalCategories",
                                color = MaterialTheme.colorScheme.primary,
                                modifier = Modifier.weight(1f)
                            )
                            CategoryStatPill(
                                label = "Active (ON)",
                                value = "$activeCategoriesCount",
                                color = Color(0xFF2E7D32),
                                modifier = Modifier.weight(1f)
                            )
                            CategoryStatPill(
                                label = "Disabled (OFF)",
                                value = "$disabledCategoriesCount",
                                color = if (disabledCategoriesCount > 0) Color(0xFFC62828) else Color.Gray,
                                modifier = Modifier.weight(1f)
                            )
                        }

                        Spacer(modifier = Modifier.height(12.dp))

                        // Master Global Action Buttons
                        Row(
                            modifier = Modifier.fillMaxWidth(),
                            horizontalArrangement = Arrangement.spacedBy(8.dp)
                        ) {
                            Button(
                                onClick = {
                                    val results = CategoryHealthEngine.selfHealAllCategories()
                                    showHealSummaryDialog = results
                                    Toast.makeText(context, "✨ Self-healed all categories!", Toast.LENGTH_SHORT).show()
                                },
                                colors = ButtonDefaults.buttonColors(containerColor = Color(0xFF2E7D32)),
                                shape = RoundedCornerShape(10.dp),
                                contentPadding = PaddingValues(horizontal = 10.dp, vertical = 8.dp),
                                modifier = Modifier.weight(1.3f).testTag("master_self_heal_all_btn")
                            ) {
                                Icon(Icons.Default.Healing, contentDescription = null, modifier = Modifier.size(16.dp))
                                Spacer(modifier = Modifier.width(6.dp))
                                Text("Self-Heal All", fontSize = 12.sp, fontWeight = FontWeight.Bold)
                            }

                            OutlinedButton(
                                onClick = {
                                    val newTarget = activeCategoriesCount < totalCategories
                                    CategoryHealthEngine.setAllCategoriesEnabled(newTarget)
                                    Toast.makeText(context, if (newTarget) "All categories turned ON" else "All categories turned OFF", Toast.LENGTH_SHORT).show()
                                },
                                shape = RoundedCornerShape(10.dp),
                                contentPadding = PaddingValues(horizontal = 8.dp, vertical = 8.dp),
                                modifier = Modifier.weight(1f).testTag("master_toggle_all_btn")
                            ) {
                                Icon(
                                    if (activeCategoriesCount < totalCategories) Icons.Default.ToggleOn else Icons.Default.ToggleOff,
                                    contentDescription = null,
                                    modifier = Modifier.size(16.dp)
                                )
                                Spacer(modifier = Modifier.width(4.dp))
                                Text(if (activeCategoriesCount < totalCategories) "All ON" else "All OFF", fontSize = 11.5.sp)
                            }

                            OutlinedButton(
                                onClick = {
                                    CategoryHealthEngine.resetToFactoryDefaults()
                                    Toast.makeText(context, "Reset categories & sections to factory defaults", Toast.LENGTH_SHORT).show()
                                },
                                shape = RoundedCornerShape(10.dp),
                                contentPadding = PaddingValues(horizontal = 8.dp, vertical = 8.dp),
                                modifier = Modifier.weight(0.9f).testTag("master_reset_defaults_btn")
                            ) {
                                Icon(Icons.Default.RestartAlt, contentDescription = null, modifier = Modifier.size(16.dp))
                                Spacer(modifier = Modifier.width(4.dp))
                                Text("Reset", fontSize = 11.5.sp)
                            }
                        }
                    }
                }
            }

            // Tab Selector
            item {
                TabRow(
                    selectedTabIndex = selectedTab,
                    containerColor = Color.Transparent,
                    contentColor = MaterialTheme.colorScheme.primary,
                    divider = {}
                ) {
                    Tab(
                        selected = selectedTab == 0,
                        onClick = { selectedTab = 0 },
                        text = { Text("Categories ($totalCategories)", fontSize = 12.sp, fontWeight = FontWeight.Bold) },
                        icon = { Icon(Icons.Default.Category, contentDescription = null, modifier = Modifier.size(18.dp)) }
                    )
                    Tab(
                        selected = selectedTab == 1,
                        onClick = { selectedTab = 1 },
                        text = { Text("App Sections (${appSections.size})", fontSize = 12.sp, fontWeight = FontWeight.Bold) },
                        icon = { Icon(Icons.Default.ViewQuilt, contentDescription = null, modifier = Modifier.size(18.dp)) }
                    )
                    Tab(
                        selected = selectedTab == 2,
                        onClick = { selectedTab = 2 },
                        text = { Text("Audit & Logs", fontSize = 12.sp, fontWeight = FontWeight.Bold) },
                        icon = { Icon(Icons.Default.Checklist, contentDescription = null, modifier = Modifier.size(18.dp)) }
                    )
                }
            }

            when (selectedTab) {
                0 -> {
                    // Search & Filter controls for Categories
                    item {
                        OutlinedTextField(
                            value = searchQuery,
                            onValueChange = { searchQuery = it },
                            placeholder = { Text("Search category name or slug (e.g. pg, turf, banquet)...", fontSize = 12.5.sp) },
                            leadingIcon = { Icon(Icons.Default.Search, contentDescription = null, modifier = Modifier.size(18.dp)) },
                            trailingIcon = {
                                if (searchQuery.isNotEmpty()) {
                                    IconButton(onClick = { searchQuery = "" }) {
                                        Icon(Icons.Default.Clear, contentDescription = "Clear", modifier = Modifier.size(16.dp))
                                    }
                                }
                            },
                            singleLine = true,
                            shape = RoundedCornerShape(12.dp),
                            modifier = Modifier.fillMaxWidth().testTag("search_category_input")
                        )
                    }

                    // Filter chips row
                    item {
                        LazyRow(
                            horizontalArrangement = Arrangement.spacedBy(8.dp),
                            contentPadding = PaddingValues(vertical = 4.dp)
                        ) {
                            item {
                                FilterChip(
                                    selected = filterMode == "ALL",
                                    onClick = { filterMode = "ALL" },
                                    label = { Text("All ($totalCategories)", fontSize = 11.5.sp) },
                                    leadingIcon = { Icon(Icons.Default.List, contentDescription = null, modifier = Modifier.size(14.dp)) }
                                )
                            }
                            item {
                                FilterChip(
                                    selected = filterMode == "ACTIVE_ONLY",
                                    onClick = { filterMode = "ACTIVE_ONLY" },
                                    label = { Text("Active ON ($activeCategoriesCount)", fontSize = 11.5.sp) },
                                    leadingIcon = { Icon(Icons.Default.CheckCircle, contentDescription = null, tint = Color(0xFF2E7D32), modifier = Modifier.size(14.dp)) }
                                )
                            }
                            item {
                                FilterChip(
                                    selected = filterMode == "INACTIVE_ONLY",
                                    onClick = { filterMode = "INACTIVE_ONLY" },
                                    label = { Text("Disabled OFF ($disabledCategoriesCount)", fontSize = 11.5.sp) },
                                    leadingIcon = { Icon(Icons.Default.Block, contentDescription = null, tint = Color(0xFFC62828), modifier = Modifier.size(14.dp)) }
                                )
                            }
                            item {
                                FilterChip(
                                    selected = filterMode == "NEEDS_HEALING",
                                    onClick = { filterMode = "NEEDS_HEALING" },
                                    label = { Text("Needs Healing (${healthReports.count { !it.isHealthy }})", fontSize = 11.5.sp) },
                                    leadingIcon = { Icon(Icons.Default.Warning, contentDescription = null, tint = Color(0xFFE65100), modifier = Modifier.size(14.dp)) }
                                )
                            }
                        }
                    }

                    if (filteredCategories.isEmpty()) {
                        item {
                            Card(
                                shape = RoundedCornerShape(14.dp),
                                colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.3f)),
                                modifier = Modifier.fillMaxWidth().padding(vertical = 24.dp)
                            ) {
                                Column(
                                    modifier = Modifier.padding(24.dp),
                                    horizontalAlignment = Alignment.CenterHorizontally
                                ) {
                                    Icon(Icons.Default.FilterListOff, contentDescription = null, modifier = Modifier.size(40.dp), tint = MaterialTheme.colorScheme.onSurfaceVariant)
                                    Spacer(modifier = Modifier.height(8.dp))
                                    Text("No categories match the current filter", fontWeight = FontWeight.Bold, fontSize = 14.sp)
                                    Text("Try clearing your search query or selecting 'All'.", fontSize = 12.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                                }
                            }
                        }
                    } else {
                        items(filteredCategories, key = { it.id }) { cat ->
                            val report = healthReports.firstOrNull { it.categorySlug == cat.slug || it.categoryId == cat.id }
                            ModularCategoryCard(
                                category = cat,
                                report = report,
                                onToggleActive = { isEnabled ->
                                    BookMySpaceRepository.setCategoryActive(cat.id, isEnabled)
                                    CategoryHealthEngine.refreshHealthReports()
                                    Toast.makeText(context, "${cat.name} turned ${if (isEnabled) "ON" else "OFF"}", Toast.LENGTH_SHORT).show()
                                },
                                onToggleUnifiedReg = {
                                    BookMySpaceRepository.toggleCategoryUnifiedRegistration(cat.id)
                                },
                                onSelfHeal = {
                                    val healRes = CategoryHealthEngine.selfHealCategory(cat.slug)
                                    showHealSummaryDialog = listOf(healRes)
                                    Toast.makeText(context, "🩹 Self-healed ${cat.name}!", Toast.LENGTH_SHORT).show()
                                },
                                onInspectDiagnostics = {
                                    inspectingCategoryReport = report ?: CategoryHealthReport(
                                        categoryId = cat.id,
                                        categorySlug = cat.slug,
                                        categoryName = cat.name,
                                        isEnabled = cat.isActive,
                                        isUnifiedRegistrationEnabled = cat.isUnifiedRegistrationEnabled,
                                        listingCount = 0,
                                        isHealthy = true,
                                        healthScorePercent = 100
                                    )
                                }
                            )
                        }
                    }
                }

                1 -> {
                    // App Sections
                    item {
                        Card(
                            shape = RoundedCornerShape(14.dp),
                            colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.35f)),
                            modifier = Modifier.fillMaxWidth()
                        ) {
                            Column(modifier = Modifier.padding(14.dp)) {
                                Text("Core Modular App Sections", fontWeight = FontWeight.Bold, fontSize = 14.sp)
                                Text(
                                    "Turn entire sections ON or OFF independently. Disabled sections are automatically hidden across Home tabs, booking feeds, search, and navigation without affecting other active modules.",
                                    fontSize = 11.5.sp,
                                    color = MaterialTheme.colorScheme.onSurfaceVariant
                                )
                            }
                        }
                    }

                    items(appSections, key = { it.sectionId }) { section ->
                        ModularSectionCard(
                            section = section,
                            onToggleSection = { isEnabled ->
                                BookMySpaceRepository.setSectionEnabled(section.sectionId, isEnabled)
                                CategoryHealthEngine.refreshHealthReports()
                                Toast.makeText(context, "${section.title} turned ${if (isEnabled) "ON" else "OFF"}", Toast.LENGTH_SHORT).show()
                            }
                        )
                    }
                }

                2 -> {
                    // Audit Logs & Self-Healing History
                    item {
                        Card(
                            shape = RoundedCornerShape(14.dp),
                            colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.35f)),
                            modifier = Modifier.fillMaxWidth()
                        ) {
                            Column(modifier = Modifier.padding(14.dp)) {
                                Text("Self-Healing Telemetry & Audit Log", fontWeight = FontWeight.Bold, fontSize = 14.sp)
                                Text("Real-time log of automated data integrity repairs, fallback injections, and schema reconciliations.", fontSize = 11.5.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                            }
                        }
                    }

                    if (lastAuditLogs.isEmpty()) {
                        item {
                            Card(
                                shape = RoundedCornerShape(14.dp),
                                colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.2f)),
                                modifier = Modifier.fillMaxWidth().padding(vertical = 20.dp)
                            ) {
                                Column(
                                    modifier = Modifier.padding(20.dp),
                                    horizontalAlignment = Alignment.CenterHorizontally
                                ) {
                                    Icon(Icons.Default.Verified, contentDescription = null, modifier = Modifier.size(36.dp), tint = Color(0xFF2E7D32))
                                    Spacer(modifier = Modifier.height(8.dp))
                                    Text("No Anomalies Detected", fontWeight = FontWeight.Bold, fontSize = 14.sp)
                                    Text("All categories are operating in nominal health state.", fontSize = 11.5.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                                }
                            }
                        }
                    } else {
                        items(lastAuditLogs) { audit ->
                            AuditLogItemCard(audit)
                        }
                    }
                }
            }
        }
    }

    // Add Category Dialog
    if (showAddCategoryDialog) {
        var catName by remember { mutableStateOf("") }
        var catSlug by remember { mutableStateOf("") }
        var isUnifiedReg by remember { mutableStateOf(true) }

        AlertDialog(
            onDismissRequest = { showAddCategoryDialog = false },
            title = { Text("Add Modular Space Category", fontWeight = FontWeight.Bold) },
            text = {
                Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                    Text(
                        "Configure a fully modular independent category (e.g. Sports Turf, Luxury Villa, Recording Studio, Medical Chamber).",
                        fontSize = 12.sp,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                    OutlinedTextField(
                        value = catName,
                        onValueChange = {
                            catName = it
                            if (catSlug.isBlank() || catSlug == it.dropLast(1).lowercase().replace(" ", "_")) {
                                catSlug = it.lowercase().trim().replace(" ", "_")
                            }
                        },
                        label = { Text("Category Name (e.g. Badminton Courts)") },
                        modifier = Modifier.fillMaxWidth().testTag("add_category_name_field"),
                        singleLine = true
                    )
                    OutlinedTextField(
                        value = catSlug,
                        onValueChange = { catSlug = it },
                        label = { Text("Unique Slug (e.g. badminton_courts)") },
                        modifier = Modifier.fillMaxWidth().testTag("add_category_slug_field"),
                        singleLine = true
                    )
                    Row(
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.SpaceBetween,
                        modifier = Modifier.fillMaxWidth()
                    ) {
                        Text("Unified Registration KYC", fontSize = 12.sp, fontWeight = FontWeight.Medium)
                        Switch(
                            checked = isUnifiedReg,
                            onCheckedChange = { isUnifiedReg = it },
                            modifier = Modifier.testTag("add_category_unified_switch")
                        )
                    }
                }
            },
            confirmButton = {
                Button(
                    onClick = {
                        if (catName.isNotBlank()) {
                            val newCat = VenueCategory(
                                id = "cat_${UUID.randomUUID().toString().take(6)}",
                                slug = catSlug.ifBlank { catName.lowercase().replace(" ", "_") },
                                name = catName,
                                iconName = "domain",
                                isActive = true,
                                isUnifiedRegistrationEnabled = isUnifiedReg
                            )
                            BookMySpaceRepository.addCategory(newCat)
                            CategoryHealthEngine.selfHealCategory(newCat.slug)
                            showAddCategoryDialog = false
                            Toast.makeText(context, "Added '${newCat.name}' and initialized self-healing!", Toast.LENGTH_SHORT).show()
                        }
                    },
                    modifier = Modifier.testTag("submit_add_category_btn"),
                    enabled = catName.isNotBlank()
                ) {
                    Text("Create Category")
                }
            },
            dismissButton = {
                TextButton(onClick = { showAddCategoryDialog = false }) {
                    Text("Cancel")
                }
            }
        )
    }

    // Diagnostics Inspection Dialog
    inspectingCategoryReport?.let { rep ->
        AlertDialog(
            onDismissRequest = { inspectingCategoryReport = null },
            title = {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Icon(Icons.Default.Analytics, contentDescription = null, tint = MaterialTheme.colorScheme.primary)
                    Spacer(modifier = Modifier.width(8.dp))
                    Text("Category Diagnostics: ${rep.categoryName}", fontWeight = FontWeight.Bold, fontSize = 15.sp)
                }
            },
            text = {
                Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    Text("Identifier / Slug: ${rep.categorySlug}", fontSize = 12.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                    Text("Current Status: ${if (rep.isEnabled) "ACTIVE (ON)" else "DISABLED (OFF)"}", fontWeight = FontWeight.SemiBold, fontSize = 12.sp)
                    Text("Available Listings: ${rep.listingCount} venues", fontSize = 12.sp)
                    Text("Health Score: ${rep.healthScorePercent}%", fontWeight = FontWeight.Bold, color = if (rep.isHealthy) Color(0xFF2E7D32) else Color(0xFFE65100), fontSize = 13.sp)

                    if (rep.issues.isNotEmpty()) {
                        Spacer(modifier = Modifier.height(4.dp))
                        Text("Detected Diagnostic Notes:", fontWeight = FontWeight.Bold, fontSize = 12.sp, color = Color(0xFFC62828))
                        rep.issues.forEach { issue ->
                            Row(verticalAlignment = Alignment.CenterVertically) {
                                Text("• ", color = Color(0xFFC62828), fontWeight = FontWeight.Bold)
                                Text(issue, fontSize = 11.5.sp)
                            }
                        }
                    } else {
                        Spacer(modifier = Modifier.height(4.dp))
                        Text("✓ All integrity tests passed: Zero schema errors, verified photos, healthy pricing models.", fontSize = 11.5.sp, color = Color(0xFF2E7D32))
                    }
                }
            },
            confirmButton = {
                Button(
                    onClick = {
                        val res = CategoryHealthEngine.selfHealCategory(rep.categorySlug)
                        inspectingCategoryReport = null
                        showHealSummaryDialog = listOf(res)
                    },
                    colors = ButtonDefaults.buttonColors(containerColor = Color(0xFF2E7D32))
                ) {
                    Icon(Icons.Default.Healing, contentDescription = null, modifier = Modifier.size(16.dp))
                    Spacer(modifier = Modifier.width(6.dp))
                    Text("Self-Heal Now")
                }
            },
            dismissButton = {
                TextButton(onClick = { inspectingCategoryReport = null }) {
                    Text("Close")
                }
            }
        )
    }

    // Self-Healing Summary Dialog
    showHealSummaryDialog?.let { results ->
        AlertDialog(
            onDismissRequest = { showHealSummaryDialog = null },
            title = {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Icon(Icons.Default.CheckCircle, contentDescription = null, tint = Color(0xFF2E7D32))
                    Spacer(modifier = Modifier.width(8.dp))
                    Text("Self-Healing Summary", fontWeight = FontWeight.Bold)
                }
            },
            text = {
                LazyColumn(
                    modifier = Modifier.fillMaxWidth().heightIn(max = 300.dp),
                    verticalArrangement = Arrangement.spacedBy(8.dp)
                ) {
                    items(results) { res ->
                        Card(
                            shape = RoundedCornerShape(8.dp),
                            colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.4f)),
                            modifier = Modifier.fillMaxWidth()
                        ) {
                            Column(modifier = Modifier.padding(10.dp)) {
                                Text(res.categoryName, fontWeight = FontWeight.Bold, fontSize = 13.sp)
                                res.actionsTaken.forEach { act ->
                                    Text("• $act", fontSize = 11.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                                }
                            }
                        }
                    }
                }
            },
            confirmButton = {
                Button(onClick = { showHealSummaryDialog = null }) {
                    Text("Done")
                }
            }
        )
    }
}

@Composable
private fun CategoryStatPill(
    label: String,
    value: String,
    color: Color,
    modifier: Modifier = Modifier
) {
    Surface(
        shape = RoundedCornerShape(10.dp),
        color = color.copy(alpha = 0.1f),
        border = BorderStroke(1.dp, color.copy(alpha = 0.3f)),
        modifier = modifier
    ) {
        Column(
            modifier = Modifier.padding(horizontal = 8.dp, vertical = 8.dp),
            horizontalAlignment = Alignment.CenterHorizontally
        ) {
            Text(value, fontWeight = FontWeight.Bold, fontSize = 15.sp, color = color)
            Text(label, fontSize = 9.5.sp, color = MaterialTheme.colorScheme.onSurfaceVariant, maxLines = 1)
        }
    }
}

@Composable
private fun ModularCategoryCard(
    category: VenueCategory,
    report: CategoryHealthReport?,
    onToggleActive: (Boolean) -> Unit,
    onToggleUnifiedReg: () -> Unit,
    onSelfHeal: () -> Unit,
    onInspectDiagnostics: () -> Unit
) {
    val isHealthy = report?.isHealthy ?: true
    val listingCount = report?.listingCount ?: 0

    Card(
        shape = RoundedCornerShape(14.dp),
        colors = CardDefaults.cardColors(
            containerColor = if (category.isActive) MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.45f)
            else MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.2f)
        ),
        border = BorderStroke(
            1.dp,
            if (category.isActive) MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.35f)
            else MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.15f)
        ),
        modifier = Modifier
            .fillMaxWidth()
            .testTag("category_card_${category.id}")
    ) {
        Column(modifier = Modifier.padding(12.dp)) {
            // Header Row: Icon, Title, Status & Big ON/OFF Switch
            Row(
                modifier = Modifier.fillMaxWidth(),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.SpaceBetween
            ) {
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    modifier = Modifier.weight(1f)
                ) {
                    Box(
                        modifier = Modifier
                            .size(38.dp)
                            .background(
                                if (category.isActive) MaterialTheme.colorScheme.primaryContainer.copy(alpha = 0.7f)
                                else Color.Gray.copy(alpha = 0.15f),
                                RoundedCornerShape(10.dp)
                            ),
                        contentAlignment = Alignment.Center
                    ) {
                        Text(category.icon, fontSize = 20.sp)
                    }
                    Spacer(modifier = Modifier.width(10.dp))
                    Column {
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            Text(category.name, fontWeight = FontWeight.Bold, fontSize = 13.5.sp)
                            Spacer(modifier = Modifier.width(6.dp))
                            // Active/Inactive status pill
                            Surface(
                                shape = RoundedCornerShape(4.dp),
                                color = if (category.isActive) Color(0xFFE8F5E9) else Color(0xFFFFEBEE)
                            ) {
                                Text(
                                    text = if (category.isActive) "ON" else "OFF",
                                    fontSize = 9.5.sp,
                                    fontWeight = FontWeight.Bold,
                                    color = if (category.isActive) Color(0xFF2E7D32) else Color(0xFFC62828),
                                    modifier = Modifier.padding(horizontal = 5.dp, vertical = 2.dp)
                                )
                            }
                        }
                        Text("Slug: ${category.slug} • $listingCount listing(s)", fontSize = 10.5.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                    }
                }

                // Simple ON/OFF Switch
                Switch(
                    checked = category.isActive,
                    onCheckedChange = onToggleActive,
                    modifier = Modifier.testTag("toggle_category_active_${category.id}")
                )
            }

            Spacer(modifier = Modifier.height(10.dp))

            // Health & Metadata Badges Row
            Row(
                modifier = Modifier.fillMaxWidth(),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.SpaceBetween
            ) {
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(6.dp)
                ) {
                    // Health Shield Badge
                    Surface(
                        shape = RoundedCornerShape(6.dp),
                        color = if (isHealthy) Color(0xFFE8F5E9) else Color(0xFFFFF3E0),
                        border = BorderStroke(1.dp, if (isHealthy) Color(0xFF81C784) else Color(0xFFFFB74D)),
                        modifier = Modifier.clickable { onInspectDiagnostics() }
                    ) {
                        Row(
                            verticalAlignment = Alignment.CenterVertically,
                            modifier = Modifier.padding(horizontal = 6.dp, vertical = 3.dp)
                        ) {
                            Icon(
                                if (isHealthy) Icons.Default.Shield else Icons.Default.Warning,
                                contentDescription = null,
                                tint = if (isHealthy) Color(0xFF2E7D32) else Color(0xFFE65100),
                                modifier = Modifier.size(12.dp)
                            )
                            Spacer(modifier = Modifier.width(4.dp))
                            Text(
                                text = if (isHealthy) "Healthy" else "Needs Healing",
                                fontSize = 10.sp,
                                fontWeight = FontWeight.Bold,
                                color = if (isHealthy) Color(0xFF2E7D32) else Color(0xFFE65100)
                            )
                        }
                    }

                    // Unified Registration Badge
                    Surface(
                        shape = RoundedCornerShape(6.dp),
                        color = if (category.isUnifiedRegistrationEnabled) MaterialTheme.colorScheme.primaryContainer.copy(alpha = 0.5f) else MaterialTheme.colorScheme.surfaceVariant,
                        modifier = Modifier.clickable { onToggleUnifiedReg() }
                    ) {
                        Row(
                            verticalAlignment = Alignment.CenterVertically,
                            modifier = Modifier.padding(horizontal = 6.dp, vertical = 3.dp)
                        ) {
                            Icon(
                                Icons.Default.Badge,
                                contentDescription = null,
                                tint = if (category.isUnifiedRegistrationEnabled) MaterialTheme.colorScheme.primary else Color.Gray,
                                modifier = Modifier.size(12.dp)
                            )
                            Spacer(modifier = Modifier.width(4.dp))
                            Text(
                                text = if (category.isUnifiedRegistrationEnabled) "KYC: ON" else "KYC: OFF",
                                fontSize = 10.sp,
                                fontWeight = FontWeight.SemiBold,
                                color = if (category.isUnifiedRegistrationEnabled) MaterialTheme.colorScheme.primary else Color.Gray
                            )
                        }
                    }
                }

                // Action Buttons: Self-Heal & Info
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(4.dp)
                ) {
                    IconButton(
                        onClick = onInspectDiagnostics,
                        modifier = Modifier.size(28.dp)
                    ) {
                        Icon(Icons.Default.Info, contentDescription = "Diagnostics", modifier = Modifier.size(16.dp), tint = MaterialTheme.colorScheme.primary)
                    }

                    OutlinedButton(
                        onClick = onSelfHeal,
                        shape = RoundedCornerShape(8.dp),
                        contentPadding = PaddingValues(horizontal = 8.dp, vertical = 2.dp),
                        border = BorderStroke(1.dp, Color(0xFF2E7D32).copy(alpha = 0.6f)),
                        modifier = Modifier.height(28.dp).testTag("self_heal_btn_${category.slug}")
                    ) {
                        Icon(Icons.Default.Healing, contentDescription = null, modifier = Modifier.size(12.dp), tint = Color(0xFF2E7D32))
                        Spacer(modifier = Modifier.width(4.dp))
                        Text("Self-Heal", fontSize = 10.5.sp, fontWeight = FontWeight.Bold, color = Color(0xFF2E7D32))
                    }
                }
            }
        }
    }
}

@Composable
private fun ModularSectionCard(
    section: AppSectionConfig,
    onToggleSection: (Boolean) -> Unit
) {
    Card(
        shape = RoundedCornerShape(14.dp),
        colors = CardDefaults.cardColors(
            containerColor = if (section.isEnabled) MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.45f)
            else MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.2f)
        ),
        border = BorderStroke(
            1.dp,
            if (section.isEnabled) MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.3f)
            else MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.15f)
        ),
        modifier = Modifier.fillMaxWidth().testTag("section_card_${section.sectionId}")
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
                Box(
                    modifier = Modifier
                        .size(40.dp)
                        .background(
                            if (section.isEnabled) MaterialTheme.colorScheme.primaryContainer.copy(alpha = 0.6f)
                            else Color.Gray.copy(alpha = 0.15f),
                            RoundedCornerShape(10.dp)
                        ),
                    contentAlignment = Alignment.Center
                ) {
                    Text(section.iconResOrEmoji, fontSize = 22.sp)
                }
                Spacer(modifier = Modifier.width(12.dp))
                Column {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Text(section.title, fontWeight = FontWeight.Bold, fontSize = 13.5.sp)
                        Spacer(modifier = Modifier.width(6.dp))
                        Surface(
                            shape = RoundedCornerShape(4.dp),
                            color = if (section.isEnabled) Color(0xFFE8F5E9) else Color(0xFFFFEBEE)
                        ) {
                            Text(
                                text = if (section.isEnabled) "ONLINE" else "DISABLED",
                                fontSize = 9.5.sp,
                                fontWeight = FontWeight.Bold,
                                color = if (section.isEnabled) Color(0xFF2E7D32) else Color(0xFFC62828),
                                modifier = Modifier.padding(horizontal = 5.dp, vertical = 2.dp)
                            )
                        }
                    }
                    Text(section.subtitle, fontSize = 11.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                }
            }

            Switch(
                checked = section.isEnabled,
                onCheckedChange = onToggleSection,
                modifier = Modifier.testTag("toggle_section_${section.sectionId}")
            )
        }
    }
}

@Composable
private fun AuditLogItemCard(audit: SelfHealResult) {
    val formatter = remember { SimpleDateFormat("hh:mm:ss a", Locale.getDefault()) }
    val timeStr = remember(audit.timestamp) { formatter.format(Date(audit.timestamp)) }

    Card(
        shape = RoundedCornerShape(10.dp),
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.35f)),
        border = BorderStroke(1.dp, MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.25f)),
        modifier = Modifier.fillMaxWidth()
    ) {
        Column(modifier = Modifier.padding(10.dp)) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Icon(
                        if (audit.wasHealed) Icons.Default.AutoFixHigh else Icons.Default.CheckCircle,
                        contentDescription = null,
                        tint = if (audit.wasHealed) Color(0xFF1565C0) else Color(0xFF2E7D32),
                        modifier = Modifier.size(16.dp)
                    )
                    Spacer(modifier = Modifier.width(6.dp))
                    Text(audit.categoryName, fontWeight = FontWeight.Bold, fontSize = 12.5.sp)
                }
                Text(timeStr, fontSize = 10.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
            }
            Spacer(modifier = Modifier.height(4.dp))
            audit.actionsTaken.forEach { action ->
                Text("• $action", fontSize = 11.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
            }
        }
    }
}
