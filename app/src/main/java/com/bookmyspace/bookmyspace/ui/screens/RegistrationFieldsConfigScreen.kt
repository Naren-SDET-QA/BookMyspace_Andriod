package com.bookmyspace.bookmyspace.ui.screens

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
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.bookmyspace.bookmyspace.data.model.*
import com.bookmyspace.bookmyspace.data.repository.BookMySpaceRepository
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

    Scaffold(
        snackbarHost = { SnackbarHost(snackbarHostState) },
        topBar = {
            TopAppBar(
                title = {
                    Column {
                        Text("User Registration Fields", fontWeight = FontWeight.Bold, fontSize = 18.sp)
                        Text("Configurable fields for All Modules & KYC", fontSize = 11.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                    }
                },
                navigationIcon = {
                    IconButton(onClick = onNavigateBack) {
                        Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "Back")
                    }
                },
                actions = {
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
                text = { Text("Add Custom Field") },
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

            // Category Filter Chips & Search Bar
            Column(modifier = Modifier.padding(horizontal = 16.dp, vertical = 8.dp)) {
                OutlinedTextField(
                    value = searchQuery,
                    onValueChange = { searchQuery = it },
                    placeholder = { Text("Search fields (e.g. photo, aadhaar, address, phone)...") },
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
                        .horizontalScroll(androidx.compose.foundation.rememberScrollState()),
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
                        .padding(horizontal = 16.dp, vertical = 8.dp),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Text(
                        text = "Configured Fields: ${filteredFields.size} (${filteredFields.count { it.isEnabled }} active)",
                        fontSize = 12.sp,
                        fontWeight = FontWeight.Medium
                    )
                    FilledTonalButton(
                        onClick = onNavigateToUnifiedRegistration,
                        contentPadding = PaddingValues(horizontal = 10.dp, vertical = 4.dp),
                        modifier = Modifier.height(32.dp)
                    ) {
                        Icon(Icons.Default.PersonAdd, contentDescription = null, modifier = Modifier.size(14.dp))
                        Spacer(modifier = Modifier.width(4.dp))
                        Text("Test Registration Form", fontSize = 11.sp, fontWeight = FontWeight.Bold)
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
                            "Tap '+ Add Custom Field' to configure a new field for this module.",
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
                    itemsIndexed(filteredFields, key = { _, field -> field.id }) { index, field ->
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

    // Add / Edit Dialog
    if (showAddEditDialog) {
        AddEditRegistrationFieldDialog(
            initialField = editingField,
            onDismiss = { showAddEditDialog = false },
            onSave = { field ->
                BookMySpaceRepository.saveRegistrationField(field)
                showAddEditDialog = false
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
                                    text = "*Required",
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
                        modifier = Modifier.height(28.dp)
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

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun AddEditRegistrationFieldDialog(
    initialField: UserRegistrationFieldDefinition?,
    onDismiss: () -> Unit,
    onSave: (UserRegistrationFieldDefinition) -> Unit
) {
    var label by remember { mutableStateOf(initialField?.label ?: "") }
    var key by remember { mutableStateOf(initialField?.key ?: "") }
    var fieldType by remember { mutableStateOf(initialField?.fieldType ?: RegistrationFieldType.TEXT) }
    var category by remember { mutableStateOf(initialField?.category ?: RegistrationFieldCategory.CUSTOM) }
    var targetModule by remember { mutableStateOf(initialField?.targetModule ?: RegistrationTargetModule.ALL) }
    var required by remember { mutableStateOf(initialField?.required ?: false) }
    var isEnabled by remember { mutableStateOf(initialField?.isEnabled ?: true) }
    var placeholder by remember { mutableStateOf(initialField?.placeholder ?: "") }
    var helpText by remember { mutableStateOf(initialField?.helpText ?: "") }
    var optionsText by remember { mutableStateOf(initialField?.options?.joinToString(", ") ?: "") }
    var errorMessage by remember { mutableStateOf<String?>(null) }

    val isEditing = initialField != null

    AlertDialog(
        onDismissRequest = onDismiss,
        title = {
            Text(
                text = if (isEditing) "Edit Registration Field" else "Add New Registration Field",
                fontWeight = FontWeight.Bold,
                fontSize = 18.sp
            )
        },
        text = {
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .verticalScroll(rememberScrollState()),
                verticalArrangement = Arrangement.spacedBy(12.dp)
            ) {
                if (errorMessage != null) {
                    Text(
                        text = errorMessage ?: "",
                        color = MaterialTheme.colorScheme.error,
                        fontSize = 12.sp,
                        fontWeight = FontWeight.Medium
                    )
                }

                // Field Label
                OutlinedTextField(
                    value = label,
                    onValueChange = {
                        label = it
                        if (!isEditing && key.isBlank()) {
                            key = it.lowercase().replace(" ", "_").replace(Regex("[^a-z0-9_]"), "")
                        }
                    },
                    label = { Text("Display Label *") },
                    placeholder = { Text("e.g. Aadhaar Card Photo, Blood Group, Father's Name") },
                    singleLine = true,
                    modifier = Modifier.fillMaxWidth()
                )

                // Field Key
                OutlinedTextField(
                    value = key,
                    onValueChange = { key = it.lowercase().replace(" ", "_") },
                    label = { Text("Internal Field Key *") },
                    placeholder = { Text("e.g. aadhaar_photo, blood_group") },
                    enabled = initialField?.isSystemStandard != true,
                    singleLine = true,
                    modifier = Modifier.fillMaxWidth()
                )

                // Field Type Selector
                Text("Field Type:", fontWeight = FontWeight.Bold, fontSize = 12.sp)
                var expandedType by remember { mutableStateOf(false) }
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

                // Options (for Dropdown or Radio)
                if (fieldType.hasOptions) {
                    OutlinedTextField(
                        value = optionsText,
                        onValueChange = { optionsText = it },
                        label = { Text("Options (comma separated)") },
                        placeholder = { Text("Option 1, Option 2, Option 3") },
                        modifier = Modifier.fillMaxWidth()
                    )
                }

                // Category Selector
                Text("Category Group:", fontWeight = FontWeight.Bold, fontSize = 12.sp)
                var expandedCat by remember { mutableStateOf(false) }
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
                Text("Target Module / Role:", fontWeight = FontWeight.Bold, fontSize = 12.sp)
                var expandedModule by remember { mutableStateOf(false) }
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
