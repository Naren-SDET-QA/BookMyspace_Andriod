package com.bookmyspace.bookmyspace.ui.screens

import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
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
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.bookmyspace.bookmyspace.data.model.*
import com.bookmyspace.bookmyspace.data.repository.BookMySpaceRepository
import kotlinx.coroutines.launch
import java.util.UUID

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun RegistrationFieldsConfigScreen(
    onNavigateBack: () -> Unit,
    onNavigateToUnifiedRegistration: () -> Unit = {}
) {
    val allFields by BookMySpaceRepository.registrationFields.collectAsState()
    var selectedTargetModule by remember { mutableStateOf(RegistrationTargetModule.ALL) }
    var selectedCategoryFilter by remember { mutableStateOf<RegistrationFieldCategory?>(null) }
    var searchQuery by remember { mutableStateOf("") }
    var showAddEditDialog by remember { mutableStateOf(false) }
    var showJsonConfigDialog by remember { mutableStateOf(false) }
    var editingField by remember { mutableStateOf<UserRegistrationFieldDefinition?>(null) }
    var showResetDialog by remember { mutableStateOf(false) }
    var showDeleteConfirmDialog by remember { mutableStateOf<UserRegistrationFieldDefinition?>(null) }
    val snackbarHostState = remember { SnackbarHostState() }
    val coroutineScope = rememberCoroutineScope()

    val filteredFields = remember(allFields, selectedTargetModule, selectedCategoryFilter, searchQuery) {
        allFields.filter { field ->
            val matchesModule = selectedTargetModule == RegistrationTargetModule.ALL ||
                    field.targetModule == selectedTargetModule ||
                    field.targetModule == RegistrationTargetModule.ALL

            val matchesCategory = selectedCategoryFilter == null || field.category == selectedCategoryFilter

            val matchesQuery = searchQuery.isBlank() ||
                    field.label.contains(searchQuery, ignoreCase = true) ||
                    field.key.contains(searchQuery, ignoreCase = true) ||
                    field.category.displayName.contains(searchQuery, ignoreCase = true) ||
                    field.fieldType.displayName.contains(searchQuery, ignoreCase = true)

            matchesModule && matchesCategory && matchesQuery
        }.sortedBy { it.displayOrder }
    }

    // Quick lookup for requested highlight fields: Identity Proof, DOB, Company Name
    val aadhaarField = remember(allFields) { allFields.firstOrNull { it.key == "aadhaar_number" } }
    val dobField = remember(allFields) { allFields.firstOrNull { it.key == "dob" } }
    val orgField = remember(allFields) { allFields.firstOrNull { it.key == "organization_name" } }
    val locField = remember(allFields) { allFields.firstOrNull { it.key == "location_hierarchy" } }

    Scaffold(
        snackbarHost = { SnackbarHost(snackbarHostState) },
        topBar = {
            TopAppBar(
                title = {
                    Column {
                        Text("Registration Schema & KYC", fontWeight = FontWeight.Bold, fontSize = 18.sp)
                        Text("JSON-Configurable Field Rules", fontSize = 11.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                    }
                },
                navigationIcon = {
                    IconButton(onClick = onNavigateBack) {
                        Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "Back")
                    }
                },
                actions = {
                    IconButton(
                        onClick = { showJsonConfigDialog = true },
                        modifier = Modifier.testTag("open_json_config_button")
                    ) {
                        Icon(
                            imageVector = Icons.Default.DataObject,
                            contentDescription = "JSON Schema Configuration",
                            tint = MaterialTheme.colorScheme.primary
                        )
                    }
                    IconButton(
                        onClick = onNavigateToUnifiedRegistration,
                        modifier = Modifier.testTag("preview_unified_registration_button")
                    ) {
                        Icon(Icons.Default.Visibility, contentDescription = "Live Preview Registration Form", tint = MaterialTheme.colorScheme.primary)
                    }
                    IconButton(
                        onClick = { showResetDialog = true },
                        modifier = Modifier.testTag("reset_registration_fields_button")
                    ) {
                        Icon(Icons.Default.RestartAlt, contentDescription = "Reset Defaults")
                    }
                }
            )
        },
        floatingActionButton = {
            ExtendedFloatingActionButton(
                onClick = {
                    editingField = null
                    showAddEditDialog = true
                },
                icon = { Icon(Icons.Default.Add, contentDescription = null) },
                text = { Text("Add Field") },
                modifier = Modifier.testTag("add_registration_field_fab")
            )
        }
    ) { paddingValues ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(paddingValues)
        ) {
            // Target Module Filter Tabs
            ScrollableTabRow(
                selectedTabIndex = RegistrationTargetModule.entries.indexOf(selectedTargetModule),
                edgePadding = 12.dp,
                modifier = Modifier.fillMaxWidth()
            ) {
                RegistrationTargetModule.entries.forEach { module ->
                    val isSelected = selectedTargetModule == module
                    val count = if (module == RegistrationTargetModule.ALL) allFields.size else allFields.count { it.targetModule == module || it.targetModule == RegistrationTargetModule.ALL }
                    Tab(
                        selected = isSelected,
                        onClick = { selectedTargetModule = module },
                        text = {
                            Row(verticalAlignment = Alignment.CenterVertically) {
                                Text(module.displayName, fontWeight = if (isSelected) FontWeight.Bold else FontWeight.Normal)
                                Spacer(modifier = Modifier.width(6.dp))
                                Surface(
                                    color = if (isSelected) MaterialTheme.colorScheme.primaryContainer else MaterialTheme.colorScheme.surfaceVariant,
                                    shape = CircleShape
                                ) {
                                    Text(
                                        text = "$count",
                                        fontSize = 10.sp,
                                        fontWeight = FontWeight.Bold,
                                        modifier = Modifier.padding(horizontal = 6.dp, vertical = 2.dp)
                                    )
                                }
                            }
                        }
                    )
                }
            }

            // Quick JSON Config & Dynamic KYC Rules Hub Banner
            Card(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 16.dp, vertical = 8.dp)
                    .testTag("json_config_hub_banner"),
                shape = RoundedCornerShape(16.dp),
                colors = CardDefaults.cardColors(
                    containerColor = MaterialTheme.colorScheme.primaryContainer.copy(alpha = 0.35f)
                ),
                border = androidx.compose.foundation.BorderStroke(1.dp, MaterialTheme.colorScheme.primary.copy(alpha = 0.2f))
            ) {
                Column(modifier = Modifier.padding(14.dp)) {
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.SpaceBetween,
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            Icon(
                                imageVector = Icons.Default.Schema,
                                contentDescription = null,
                                tint = MaterialTheme.colorScheme.primary,
                                modifier = Modifier.size(18.dp)
                            )
                            Spacer(modifier = Modifier.width(8.dp))
                            Text(
                                "Dynamic JSON Configuration System",
                                fontWeight = FontWeight.Bold,
                                fontSize = 13.5.sp
                            )
                        }

                        FilledTonalButton(
                            onClick = { showJsonConfigDialog = true },
                            contentPadding = PaddingValues(horizontal = 10.dp, vertical = 2.dp),
                            modifier = Modifier
                                .height(30.dp)
                                .testTag("open_json_modal_btn")
                        ) {
                            Icon(Icons.Default.Code, contentDescription = null, modifier = Modifier.size(14.dp))
                            Spacer(modifier = Modifier.width(4.dp))
                            Text("Edit JSON", fontSize = 11.sp, fontWeight = FontWeight.Bold)
                        }
                    }

                    Spacer(modifier = Modifier.height(4.dp))
                    Text(
                        "Toggle mandatory fields instantly without hardcoding. Changes take effect across user registration, checkout KYC, and host onboarding in real time.",
                        fontSize = 11.sp,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                        lineHeight = 15.sp
                    )

                    Spacer(modifier = Modifier.height(10.dp))
                    HorizontalDivider(color = MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.5f))
                    Spacer(modifier = Modifier.height(8.dp))

                    Text(
                        "QUICK MANDATORY TOGGLES",
                        fontSize = 9.5.sp,
                        fontWeight = FontWeight.ExtraBold,
                        color = MaterialTheme.colorScheme.primary
                    )
                    Spacer(modifier = Modifier.height(6.dp))

                    // 4 Quick Switches for High-Priority Fields
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .horizontalScroll(rememberScrollState()),
                        horizontalArrangement = Arrangement.spacedBy(8.dp)
                    ) {
                        // 1. Identity Proof / Aadhaar
                        aadhaarField?.let { field ->
                            QuickToggleChip(
                                label = "Identity Proof",
                                isRequired = field.required,
                                testTag = "quick_toggle_aadhaar",
                                onToggle = { req ->
                                    BookMySpaceRepository.toggleRegistrationFieldRequired(field.id, req)
                                    coroutineScope.launch {
                                        snackbarHostState.showSnackbar(
                                            if (req) "Identity Proof set to MANDATORY in JSON schema" else "Identity Proof set to OPTIONAL in JSON schema"
                                        )
                                    }
                                }
                            )
                        }

                        // 2. Date of Birth
                        dobField?.let { field ->
                            QuickToggleChip(
                                label = "Date of Birth",
                                isRequired = field.required,
                                testTag = "quick_toggle_dob",
                                onToggle = { req ->
                                    BookMySpaceRepository.toggleRegistrationFieldRequired(field.id, req)
                                    coroutineScope.launch {
                                        snackbarHostState.showSnackbar(
                                            if (req) "Date of Birth set to MANDATORY in JSON schema" else "Date of Birth set to OPTIONAL in JSON schema"
                                        )
                                    }
                                }
                            )
                        }

                        // 3. Company / Entity Name
                        orgField?.let { field ->
                            QuickToggleChip(
                                label = "Company Name",
                                isRequired = field.required,
                                testTag = "quick_toggle_company_name",
                                onToggle = { req ->
                                    BookMySpaceRepository.toggleRegistrationFieldRequired(field.id, req)
                                    coroutineScope.launch {
                                        snackbarHostState.showSnackbar(
                                            if (req) "Company Name set to MANDATORY in JSON schema" else "Company Name set to OPTIONAL in JSON schema"
                                        )
                                    }
                                }
                            )
                        }

                        // 4. Location Hierarchy
                        locField?.let { field ->
                            QuickToggleChip(
                                label = "Location Hierarchy",
                                isRequired = field.required,
                                testTag = "quick_toggle_location",
                                onToggle = { req ->
                                    BookMySpaceRepository.toggleRegistrationFieldRequired(field.id, req)
                                    coroutineScope.launch {
                                        snackbarHostState.showSnackbar(
                                            if (req) "Location Hierarchy set to MANDATORY" else "Location Hierarchy set to OPTIONAL"
                                        )
                                    }
                                }
                            )
                        }
                    }
                }
            }

            // Category Filter Chips & Search Bar
            Column(modifier = Modifier.padding(horizontal = 16.dp, vertical = 4.dp)) {
                OutlinedTextField(
                    value = searchQuery,
                    onValueChange = { searchQuery = it },
                    placeholder = { Text("Search fields (e.g. photo, aadhaar, dob, company, phone)...") },
                    leadingIcon = { Icon(Icons.Default.Search, contentDescription = null) },
                    trailingIcon = if (searchQuery.isNotEmpty()) {
                        {
                            IconButton(onClick = { searchQuery = "" }) {
                                Icon(Icons.Default.Clear, contentDescription = "Clear")
                            }
                        }
                    } else null,
                    modifier = Modifier
                        .fillMaxWidth()
                        .testTag("search_registration_fields_input"),
                    shape = RoundedCornerShape(12.dp),
                    singleLine = true
                )

                Spacer(modifier = Modifier.height(8.dp))

                // Category filter chips
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .horizontalScroll(rememberScrollState()),
                    horizontalArrangement = Arrangement.spacedBy(8.dp)
                ) {
                    FilterChip(
                        selected = selectedCategoryFilter == null,
                        onClick = { selectedCategoryFilter = null },
                        label = { Text("All Categories (${allFields.size})") },
                        modifier = Modifier.testTag("filter_cat_all")
                    )
                    RegistrationFieldCategory.entries.forEach { cat ->
                        val catCount = allFields.count { it.category == cat }
                        FilterChip(
                            selected = selectedCategoryFilter == cat,
                            onClick = {
                                selectedCategoryFilter = if (selectedCategoryFilter == cat) null else cat
                            },
                            label = { Text("${cat.displayName} ($catCount)") }
                        )
                    }
                }
            }

            // Fields count summary bar
            Surface(
                color = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.5f),
                modifier = Modifier.fillMaxWidth()
            ) {
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(horizontal = 16.dp, vertical = 6.dp),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Text(
                        text = "Fields: ${filteredFields.size} (${allFields.count { it.required && it.isEnabled }} mandatory, ${allFields.count { it.isEnabled }} active)",
                        fontSize = 11.5.sp,
                        fontWeight = FontWeight.Medium
                    )
                    FilledTonalButton(
                        onClick = onNavigateToUnifiedRegistration,
                        contentPadding = PaddingValues(horizontal = 10.dp, vertical = 2.dp),
                        modifier = Modifier.height(28.dp)
                    ) {
                        Icon(Icons.Default.PersonAdd, contentDescription = null, modifier = Modifier.size(13.dp))
                        Spacer(modifier = Modifier.width(4.dp))
                        Text("Live Form Preview", fontSize = 10.5.sp, fontWeight = FontWeight.Bold)
                    }
                }
            }

            // Lazy List of Configurable Registration Fields
            if (filteredFields.isEmpty()) {
                Box(
                    modifier = Modifier
                        .fillMaxSize()
                        .padding(32.dp),
                    contentAlignment = Alignment.Center
                ) {
                    Column(horizontalAlignment = Alignment.CenterHorizontally) {
                        Icon(
                            imageVector = Icons.Default.Tune,
                            contentDescription = null,
                            modifier = Modifier.size(48.dp),
                            tint = MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.5f)
                        )
                        Spacer(modifier = Modifier.height(12.dp))
                        Text("No matching registration fields", fontWeight = FontWeight.Bold)
                        Text(
                            "Tap '+ Add Field' or use JSON Configuration to add or edit schema fields.",
                            fontSize = 12.sp,
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                            textAlign = androidx.compose.ui.text.style.TextAlign.Center
                        )
                    }
                }
            } else {
                LazyColumn(
                    modifier = Modifier.fillMaxSize(),
                    contentPadding = PaddingValues(start = 16.dp, end = 16.dp, top = 8.dp, bottom = 80.dp),
                    verticalArrangement = Arrangement.spacedBy(10.dp)
                ) {
                    itemsIndexed(filteredFields, key = { _, field -> field.id }) { _, field ->
                        RegistrationFieldCard(
                            field = field,
                            onToggleEnabled = { enabled ->
                                BookMySpaceRepository.toggleRegistrationFieldEnabled(field.id, enabled)
                            },
                            onToggleRequired = { req ->
                                BookMySpaceRepository.toggleRegistrationFieldRequired(field.id, req)
                            },
                            onEdit = {
                                editingField = field
                                showAddEditDialog = true
                            },
                            onDelete = {
                                showDeleteConfirmDialog = field
                            }
                        )
                    }
                }
            }
        }
    }

    // JSON Configuration Dialog
    if (showJsonConfigDialog) {
        JsonConfigurationDialog(
            currentFields = allFields,
            onDismiss = { showJsonConfigDialog = false },
            onApplyJson = { jsonStr ->
                val result = BookMySpaceRepository.importRegistrationConfigJson(jsonStr)
                result.fold(
                    onSuccess = { count ->
                        showJsonConfigDialog = false
                        coroutineScope.launch {
                            snackbarHostState.showSnackbar("Successfully applied JSON configuration ($count fields updated)!")
                        }
                    },
                    onFailure = { ex ->
                        coroutineScope.launch {
                            snackbarHostState.showSnackbar("Failed to apply JSON: ${ex.message}")
                        }
                    }
                )
            },
            onApplyPreset = { preset ->
                BookMySpaceRepository.applyRegistrationConfigPreset(preset)
                showJsonConfigDialog = false
                coroutineScope.launch {
                    snackbarHostState.showSnackbar("Applied preset '${preset.title}' successfully!")
                }
            }
        )
    }

    // Add / Edit Dialog
    if (showAddEditDialog) {
        AddEditRegistrationFieldDialog(
            initialField = editingField,
            onDismiss = { showAddEditDialog = false },
            onSave = { field ->
                BookMySpaceRepository.saveRegistrationField(field)
                showAddEditDialog = false
                coroutineScope.launch {
                    snackbarHostState.showSnackbar("Field '${field.label}' saved to registration schema!")
                }
            }
        )
    }

    // Reset Defaults Dialog
    if (showResetDialog) {
        AlertDialog(
            onDismissRequest = { showResetDialog = false },
            icon = { Icon(Icons.Default.RestartAlt, contentDescription = null, tint = MaterialTheme.colorScheme.error) },
            title = { Text("Reset to Recommended Defaults?") },
            text = {
                Text("This will restore the standard pre-configured set of Photo, Aadhaar, Name, Phone, Email, Address, Location Hierarchy, Gender, and Business fields.")
            },
            confirmButton = {
                Button(
                    onClick = {
                        BookMySpaceRepository.resetRegistrationFieldsToDefault()
                        showResetDialog = false
                        coroutineScope.launch {
                            snackbarHostState.showSnackbar("Reset registration schema to default successfully.")
                        }
                    },
                    colors = ButtonDefaults.buttonColors(containerColor = MaterialTheme.colorScheme.error)
                ) {
                    Text("Reset All")
                }
            },
            dismissButton = {
                TextButton(onClick = { showResetDialog = false }) {
                    Text("Cancel")
                }
            }
        )
    }

    // Delete Field Dialog
    showDeleteConfirmDialog?.let { fieldToDelete ->
        AlertDialog(
            onDismissRequest = { showDeleteConfirmDialog = null },
            icon = { Icon(Icons.Default.Delete, contentDescription = null, tint = MaterialTheme.colorScheme.error) },
            title = { Text("Delete Field '${fieldToDelete.label}'?") },
            text = {
                Text("Are you sure you want to permanently delete this custom field definition?")
            },
            confirmButton = {
                Button(
                    onClick = {
                        BookMySpaceRepository.deleteRegistrationField(fieldToDelete.id)
                        showDeleteConfirmDialog = null
                        coroutineScope.launch {
                            snackbarHostState.showSnackbar("Deleted field '${fieldToDelete.label}'")
                        }
                    },
                    colors = ButtonDefaults.buttonColors(containerColor = MaterialTheme.colorScheme.error)
                ) {
                    Text("Delete")
                }
            },
            dismissButton = {
                TextButton(onClick = { showDeleteConfirmDialog = null }) {
                    Text("Cancel")
                }
            }
        )
    }
}

@Composable
private fun QuickToggleChip(
    label: String,
    isRequired: Boolean,
    testTag: String,
    onToggle: (Boolean) -> Unit
) {
    Surface(
        color = if (isRequired) MaterialTheme.colorScheme.primaryContainer else MaterialTheme.colorScheme.surfaceVariant,
        shape = RoundedCornerShape(10.dp),
        modifier = Modifier
            .clickable { onToggle(!isRequired) }
            .testTag(testTag)
    ) {
        Row(
            modifier = Modifier.padding(horizontal = 10.dp, vertical = 6.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Icon(
                imageVector = if (isRequired) Icons.Default.CheckCircle else Icons.Default.RadioButtonUnchecked,
                contentDescription = null,
                tint = if (isRequired) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.onSurfaceVariant,
                modifier = Modifier.size(14.dp)
            )
            Spacer(modifier = Modifier.width(6.dp))
            Column {
                Text(
                    text = label,
                    fontSize = 11.sp,
                    fontWeight = FontWeight.Bold,
                    color = if (isRequired) MaterialTheme.colorScheme.onPrimaryContainer else MaterialTheme.colorScheme.onSurfaceVariant
                )
                Text(
                    text = if (isRequired) "MANDATORY" else "OPTIONAL",
                    fontSize = 9.sp,
                    fontWeight = FontWeight.ExtraBold,
                    color = if (isRequired) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.outline
                )
            }
        }
    }
}

@Composable
fun RegistrationFieldCard(
    field: UserRegistrationFieldDefinition,
    onToggleEnabled: (Boolean) -> Unit,
    onToggleRequired: (Boolean) -> Unit,
    onEdit: () -> Unit,
    onDelete: () -> Unit
) {
    Card(
        modifier = Modifier
            .fillMaxWidth()
            .testTag("reg_field_card_${field.key}"),
        shape = RoundedCornerShape(16.dp),
        colors = CardDefaults.cardColors(
            containerColor = if (field.isEnabled) MaterialTheme.colorScheme.surface else MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.5f)
        ),
        elevation = CardDefaults.cardElevation(defaultElevation = if (field.isEnabled) 2.dp else 0.dp)
    ) {
        Column(modifier = Modifier.padding(14.dp)) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Row(
                    modifier = Modifier.weight(1f),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Box(
                        modifier = Modifier
                            .size(36.dp)
                            .clip(CircleShape)
                            .background(
                                when (field.fieldType) {
                                    RegistrationFieldType.PHOTO -> MaterialTheme.colorScheme.primaryContainer
                                    RegistrationFieldType.AADHAAR -> MaterialTheme.colorScheme.tertiaryContainer
                                    RegistrationFieldType.LOCATION_HIERARCHY -> MaterialTheme.colorScheme.secondaryContainer
                                    RegistrationFieldType.ADDRESS_LINE -> MaterialTheme.colorScheme.primaryContainer
                                    else -> MaterialTheme.colorScheme.surfaceVariant
                                }
                            ),
                        contentAlignment = Alignment.Center
                    ) {
                        Icon(
                            imageVector = when (field.fieldType) {
                                RegistrationFieldType.PHOTO -> Icons.Default.AccountCircle
                                RegistrationFieldType.AADHAAR -> Icons.Default.Badge
                                RegistrationFieldType.PHONE -> Icons.Default.Phone
                                RegistrationFieldType.EMAIL -> Icons.Default.Email
                                RegistrationFieldType.ADDRESS_LINE -> Icons.Default.Home
                                RegistrationFieldType.LOCATION_HIERARCHY -> Icons.Default.Place
                                RegistrationFieldType.PINCODE -> Icons.Default.Pin
                                RegistrationFieldType.DROPDOWN, RegistrationFieldType.RADIO_GROUP -> Icons.Default.List
                                RegistrationFieldType.DATE_OF_BIRTH -> Icons.Default.CalendarToday
                                else -> Icons.Default.TextFields
                            },
                            contentDescription = null,
                            modifier = Modifier.size(20.dp),
                            tint = MaterialTheme.colorScheme.primary
                        )
                    }

                    Spacer(modifier = Modifier.width(10.dp))

                    Column {
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            Text(
                                text = field.label,
                                fontWeight = FontWeight.Bold,
                                fontSize = 14.sp
                            )
                            if (field.required) {
                                Spacer(modifier = Modifier.width(4.dp))
                                Text(
                                    text = "*Mandatory",
                                    color = MaterialTheme.colorScheme.error,
                                    fontSize = 11.sp,
                                    fontWeight = FontWeight.Bold
                                )
                            }
                        }

                        Text(
                            text = "Key: ${field.key} • Type: ${field.fieldType.displayName}",
                            fontSize = 11.sp,
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                    }
                }

                Switch(
                    checked = field.isEnabled,
                    onCheckedChange = onToggleEnabled,
                    modifier = Modifier.testTag("toggle_enabled_${field.key}")
                )
            }

            if (field.helpText.isNotBlank()) {
                Spacer(modifier = Modifier.height(6.dp))
                Text(
                    text = field.helpText,
                    fontSize = 11.sp,
                    color = MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.8f)
                )
            }

            if (field.options.isNotEmpty()) {
                Spacer(modifier = Modifier.height(6.dp))
                Text(
                    text = "Options: ${field.options.joinToString(", ")}",
                    fontSize = 10.sp,
                    color = MaterialTheme.colorScheme.primary,
                    fontWeight = FontWeight.Medium
                )
            }

            Spacer(modifier = Modifier.height(10.dp))
            HorizontalDivider(color = MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.5f))
            Spacer(modifier = Modifier.height(8.dp))

            // Badges & Action Controls
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Row(
                    horizontalArrangement = Arrangement.spacedBy(6.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Surface(
                        color = MaterialTheme.colorScheme.surfaceVariant,
                        shape = RoundedCornerShape(6.dp)
                    ) {
                        Text(
                            text = field.category.displayName,
                            fontSize = 10.sp,
                            modifier = Modifier.padding(horizontal = 6.dp, vertical = 2.dp),
                            fontWeight = FontWeight.Medium
                        )
                    }

                    Surface(
                        color = MaterialTheme.colorScheme.primaryContainer,
                        shape = RoundedCornerShape(6.dp)
                    ) {
                        Text(
                            text = field.targetModule.displayName,
                            fontSize = 10.sp,
                            modifier = Modifier.padding(horizontal = 6.dp, vertical = 2.dp),
                            fontWeight = FontWeight.Bold,
                            color = MaterialTheme.colorScheme.primary
                        )
                    }

                    if (field.isSystemStandard) {
                        Surface(
                            color = MaterialTheme.colorScheme.secondaryContainer,
                            shape = RoundedCornerShape(6.dp)
                        ) {
                            Text(
                                text = "Standard",
                                fontSize = 9.sp,
                                modifier = Modifier.padding(horizontal = 4.dp, vertical = 2.dp),
                                fontWeight = FontWeight.Bold
                            )
                        }
                    }
                }

                Row(verticalAlignment = Alignment.CenterVertically) {
                    // Required toggle chip
                    FilterChip(
                        selected = field.required,
                        onClick = { onToggleRequired(!field.required) },
                        label = { Text(if (field.required) "Required" else "Optional", fontSize = 10.sp) },
                        modifier = Modifier
                            .height(28.dp)
                            .testTag("toggle_required_${field.key}")
                    )

                    IconButton(
                        onClick = onEdit,
                        modifier = Modifier.size(32.dp)
                    ) {
                        Icon(Icons.Default.Edit, contentDescription = "Edit Field", modifier = Modifier.size(16.dp))
                    }

                    if (!field.isSystemStandard) {
                        IconButton(
                            onClick = onDelete,
                            modifier = Modifier.size(32.dp)
                        ) {
                            Icon(Icons.Default.Delete, contentDescription = "Delete", tint = MaterialTheme.colorScheme.error, modifier = Modifier.size(16.dp))
                        }
                    }
                }
            }
        }
    }
}

/**
 * Full JSON Schema Configuration Editor & Preset Manager Modal Dialog.
 */
@Composable
fun JsonConfigurationDialog(
    currentFields: List<UserRegistrationFieldDefinition>,
    onDismiss: () -> Unit,
    onApplyJson: (String) -> Unit,
    onApplyPreset: (RegistrationConfigPreset) -> Unit
) {
    val context = LocalContext.current
    var jsonText by remember {
        mutableStateOf(RegistrationConfigJsonEngine.exportToJson(currentFields, prettyPrint = true))
    }
    var validationError by remember { mutableStateOf<String?>(null) }
    var selectedPreset by remember { mutableStateOf<RegistrationConfigPreset?>(null) }

    AlertDialog(
        onDismissRequest = onDismiss,
        modifier = Modifier
            .fillMaxWidth()
            .padding(vertical = 12.dp)
            .testTag("json_config_dialog"),
        title = {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Icon(Icons.Default.DataObject, contentDescription = null, tint = MaterialTheme.colorScheme.primary)
                    Spacer(modifier = Modifier.width(8.dp))
                    Column {
                        Text("JSON Schema Configuration", fontSize = 16.sp, fontWeight = FontWeight.Bold)
                        Text("Dynamic Plug-and-Play Registration Rules", fontSize = 10.5.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                    }
                }
            }
        },
        text = {
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .verticalScroll(rememberScrollState())
            ) {
                Text(
                    "Select a pre-built preset or edit the raw JSON schema below to configure required fields dynamically:",
                    fontSize = 11.5.sp,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
                Spacer(modifier = Modifier.height(10.dp))

                // Presets Horizontal Scroller
                Text("QUICK PRESETS (1-TAP APPLY)", fontSize = 9.5.sp, fontWeight = FontWeight.ExtraBold, color = MaterialTheme.colorScheme.primary)
                Spacer(modifier = Modifier.height(4.dp))
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .horizontalScroll(rememberScrollState()),
                    horizontalArrangement = Arrangement.spacedBy(6.dp)
                ) {
                    RegistrationConfigPreset.entries.forEach { preset ->
                        val isSelected = selectedPreset == preset
                        FilterChip(
                            selected = isSelected,
                            onClick = {
                                selectedPreset = preset
                                val presetFields = RegistrationConfigJsonEngine.getPresetFields(currentFields, preset)
                                jsonText = RegistrationConfigJsonEngine.exportToJson(presetFields, presetName = preset.title, prettyPrint = true)
                                validationError = null
                            },
                            label = {
                                Column {
                                    Text(preset.title, fontSize = 11.sp, fontWeight = FontWeight.Bold)
                                    Text(preset.badge, fontSize = 8.5.sp, color = MaterialTheme.colorScheme.primary)
                                }
                            },
                            modifier = Modifier.testTag("preset_chip_${preset.code}")
                        )
                    }
                }

                Spacer(modifier = Modifier.height(12.dp))

                // JSON Tools Bar
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Text("SCHEMA DEFINITION", fontSize = 9.5.sp, fontWeight = FontWeight.ExtraBold, color = MaterialTheme.colorScheme.onSurface)

                    Row(horizontalArrangement = Arrangement.spacedBy(4.dp)) {
                        TextButton(
                            onClick = {
                                val (isValid, formattedOrError) = RegistrationConfigJsonEngine.validateAndFormatJson(jsonText)
                                if (isValid) {
                                    jsonText = formattedOrError
                                    validationError = null
                                } else {
                                    validationError = formattedOrError
                                }
                            },
                            contentPadding = PaddingValues(horizontal = 6.dp, vertical = 2.dp),
                            modifier = Modifier.height(28.dp).testTag("format_json_button")
                        ) {
                            Icon(Icons.Default.AutoFixHigh, contentDescription = null, modifier = Modifier.size(12.dp))
                            Spacer(modifier = Modifier.width(2.dp))
                            Text("Format", fontSize = 10.5.sp)
                        }

                        TextButton(
                            onClick = {
                                val clipboard = context.getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
                                val clip = ClipData.newPlainText("BookMySpace Registration Schema", jsonText)
                                clipboard.setPrimaryClip(clip)
                            },
                            contentPadding = PaddingValues(horizontal = 6.dp, vertical = 2.dp),
                            modifier = Modifier.height(28.dp).testTag("copy_json_config_button")
                        ) {
                            Icon(Icons.Default.ContentCopy, contentDescription = null, modifier = Modifier.size(12.dp))
                            Spacer(modifier = Modifier.width(2.dp))
                            Text("Copy", fontSize = 10.5.sp)
                        }
                    }
                }

                Spacer(modifier = Modifier.height(4.dp))

                // Monospaced JSON Text Editor Field
                OutlinedTextField(
                    value = jsonText,
                    onValueChange = {
                        jsonText = it
                        validationError = null
                    },
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(260.dp)
                        .testTag("json_editor_input"),
                    textStyle = LocalTextStyle.current.copy(
                        fontFamily = FontFamily.Monospace,
                        fontSize = 11.sp,
                        lineHeight = 15.sp
                    ),
                    placeholder = { Text("Paste or edit JSON schema here...") },
                    shape = RoundedCornerShape(8.dp)
                )

                if (validationError != null) {
                    Spacer(modifier = Modifier.height(6.dp))
                    Surface(
                        color = MaterialTheme.colorScheme.errorContainer,
                        shape = RoundedCornerShape(8.dp)
                    ) {
                        Row(
                            modifier = Modifier.padding(8.dp),
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            Icon(Icons.Default.ErrorOutline, contentDescription = null, tint = MaterialTheme.colorScheme.onErrorContainer, modifier = Modifier.size(16.dp))
                            Spacer(modifier = Modifier.width(6.dp))
                            Text(
                                text = validationError ?: "",
                                fontSize = 11.sp,
                                color = MaterialTheme.colorScheme.onErrorContainer
                            )
                        }
                    }
                }

                Spacer(modifier = Modifier.height(8.dp))
                Text(
                    "Tip: Set '\"required\": true' to make Identity Proof, Date of Birth, or Company Name mandatory.",
                    fontSize = 10.sp,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
            }
        },
        confirmButton = {
            Button(
                onClick = {
                    val (isValid, formattedOrError) = RegistrationConfigJsonEngine.validateAndFormatJson(jsonText)
                    if (isValid) {
                        onApplyJson(formattedOrError)
                    } else {
                        validationError = formattedOrError
                    }
                },
                modifier = Modifier.testTag("apply_json_config_button")
            ) {
                Icon(Icons.Default.Check, contentDescription = null, modifier = Modifier.size(16.dp))
                Spacer(modifier = Modifier.width(6.dp))
                Text("Apply Configuration")
            }
        },
        dismissButton = {
            TextButton(onClick = onDismiss) {
                Text("Cancel")
            }
        }
    )
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun AddEditRegistrationFieldDialog(
    initialField: UserRegistrationFieldDefinition?,
    onDismiss: () -> Unit,
    onSave: (UserRegistrationFieldDefinition) -> Unit
) {
    val isEditing = initialField != null
    var label by remember { mutableStateOf(initialField?.label ?: "") }
    var key by remember { mutableStateOf(initialField?.key ?: "") }
    var fieldType by remember { mutableStateOf(initialField?.fieldType ?: RegistrationFieldType.TEXT) }
    var category by remember { mutableStateOf(initialField?.category ?: RegistrationFieldCategory.PERSONAL) }
    var targetModule by remember { mutableStateOf(initialField?.targetModule ?: RegistrationTargetModule.ALL) }
    var required by remember { mutableStateOf(initialField?.required ?: false) }
    var isEnabled by remember { mutableStateOf(initialField?.isEnabled ?: true) }
    var placeholder by remember { mutableStateOf(initialField?.placeholder ?: "") }
    var helpText by remember { mutableStateOf(initialField?.helpText ?: "") }
    var optionsText by remember { mutableStateOf(initialField?.options?.joinToString(", ") ?: "") }
    var errorMessage by remember { mutableStateOf<String?>(null) }

    var expandedType by remember { mutableStateOf(false) }
    var expandedCat by remember { mutableStateOf(false) }
    var expandedModule by remember { mutableStateOf(false) }

    AlertDialog(
        onDismissRequest = onDismiss,
        title = {
            Text(
                if (isEditing) "Edit Registration Field" else "Add New Registration Field",
                fontWeight = FontWeight.Bold,
                fontSize = 18.sp
            )
        },
        text = {
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .verticalScroll(rememberScrollState()),
                verticalArrangement = Arrangement.spacedBy(10.dp)
            ) {
                if (errorMessage != null) {
                    Text(errorMessage ?: "", color = MaterialTheme.colorScheme.error, fontSize = 12.sp)
                }

                // Field Label
                OutlinedTextField(
                    value = label,
                    onValueChange = {
                        label = it
                        if (!isEditing && key.isBlank()) {
                            key = it.lowercase().replace(" ", "_").filter { ch -> ch.isLetterOrDigit() || ch == '_' }
                        }
                    },
                    label = { Text("Display Label *") },
                    placeholder = { Text("e.g. Identity Proof / Aadhaar Number") },
                    singleLine = true,
                    modifier = Modifier.fillMaxWidth()
                )

                // Internal Key
                OutlinedTextField(
                    value = key,
                    onValueChange = { key = it.lowercase().replace(" ", "_") },
                    label = { Text("Internal Key * (e.g. aadhaar_number)") },
                    placeholder = { Text("e.g. identity_proof_doc") },
                    singleLine = true,
                    modifier = Modifier.fillMaxWidth(),
                    enabled = initialField?.isSystemStandard != true
                )

                // Field Type Selector
                ExposedDropdownMenuBox(
                    expanded = expandedType,
                    onExpandedChange = { expandedType = it }
                ) {
                    OutlinedTextField(
                        value = fieldType.displayName,
                        onValueChange = {},
                        readOnly = true,
                        trailingIcon = { ExposedDropdownMenuDefaults.TrailingIcon(expanded = expandedType) },
                        modifier = Modifier
                            .fillMaxWidth()
                            .menuAnchor()
                    )
                    ExposedDropdownMenu(
                        expanded = expandedType,
                        onDismissRequest = { expandedType = false }
                    ) {
                        RegistrationFieldType.entries.forEach { type ->
                            DropdownMenuItem(
                                text = { Text(type.displayName) },
                                onClick = {
                                    fieldType = type
                                    expandedType = false
                                }
                            )
                        }
                    }
                }

                if (fieldType.hasOptions) {
                    OutlinedTextField(
                        value = optionsText,
                        onValueChange = { optionsText = it },
                        label = { Text("Options (comma-separated)") },
                        placeholder = { Text("Option A, Option B, Option C") },
                        modifier = Modifier.fillMaxWidth()
                    )
                }

                // Category Selector
                ExposedDropdownMenuBox(
                    expanded = expandedCat,
                    onExpandedChange = { expandedCat = it }
                ) {
                    OutlinedTextField(
                        value = category.displayName,
                        onValueChange = {},
                        readOnly = true,
                        trailingIcon = { ExposedDropdownMenuDefaults.TrailingIcon(expanded = expandedCat) },
                        modifier = Modifier
                            .fillMaxWidth()
                            .menuAnchor()
                    )
                    ExposedDropdownMenu(
                        expanded = expandedCat,
                        onDismissRequest = { expandedCat = false }
                    ) {
                        RegistrationFieldCategory.entries.forEach { cat ->
                            DropdownMenuItem(
                                text = { Text(cat.displayName) },
                                onClick = {
                                    category = cat
                                    expandedCat = false
                                }
                            )
                        }
                    }
                }

                // Target Module Selector
                ExposedDropdownMenuBox(
                    expanded = expandedModule,
                    onExpandedChange = { expandedModule = it }
                ) {
                    OutlinedTextField(
                        value = targetModule.displayName,
                        onValueChange = {},
                        readOnly = true,
                        trailingIcon = { ExposedDropdownMenuDefaults.TrailingIcon(expanded = expandedModule) },
                        modifier = Modifier
                            .fillMaxWidth()
                            .menuAnchor()
                    )
                    ExposedDropdownMenu(
                        expanded = expandedModule,
                        onDismissRequest = { expandedModule = false }
                    ) {
                        RegistrationTargetModule.entries.forEach { mod ->
                            DropdownMenuItem(
                                text = { Text("${mod.displayName} (${mod.description})") },
                                onClick = {
                                    targetModule = mod
                                    expandedModule = false
                                }
                            )
                        }
                    }
                }

                // Placeholder
                OutlinedTextField(
                    value = placeholder,
                    onValueChange = { placeholder = it },
                    label = { Text("Placeholder Text") },
                    singleLine = true,
                    modifier = Modifier.fillMaxWidth()
                )

                // Help Text
                OutlinedTextField(
                    value = helpText,
                    onValueChange = { helpText = it },
                    label = { Text("Help Text / Description") },
                    singleLine = true,
                    modifier = Modifier.fillMaxWidth()
                )

                // Toggles
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Text("Mandatory Field (*Required):", fontSize = 13.sp)
                    Switch(checked = required, onCheckedChange = { required = it })
                }

                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Text("Field Enabled in UI:", fontSize = 13.sp)
                    Switch(checked = isEnabled, onCheckedChange = { isEnabled = it })
                }
            }
        },
        confirmButton = {
            Button(
                onClick = {
                    if (label.isBlank()) {
                        errorMessage = "Please enter a field label."
                        return@Button
                    }
                    if (key.isBlank()) {
                        errorMessage = "Please enter an internal field key."
                        return@Button
                    }

                    val optionsList = optionsText.split(",")
                        .map { it.trim() }
                        .filter { it.isNotEmpty() }

                    val newField = UserRegistrationFieldDefinition(
                        id = initialField?.id ?: "reg_${UUID.randomUUID().toString().take(8)}",
                        key = key.trim(),
                        label = label.trim(),
                        fieldType = fieldType,
                        category = category,
                        targetModule = targetModule,
                        required = required,
                        isEnabled = isEnabled,
                        placeholder = placeholder.trim(),
                        helpText = helpText.trim(),
                        options = optionsList,
                        displayOrder = initialField?.displayOrder ?: 20,
                        isSystemStandard = initialField?.isSystemStandard ?: false
                    )

                    onSave(newField)
                }
            ) {
                Text(if (isEditing) "Save Changes" else "Add Field")
            }
        },
        dismissButton = {
            TextButton(onClick = onDismiss) {
                Text("Cancel")
            }
        }
    )
}
