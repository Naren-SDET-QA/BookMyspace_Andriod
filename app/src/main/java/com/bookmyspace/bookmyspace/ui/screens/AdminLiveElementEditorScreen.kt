package com.bookmyspace.bookmyspace.ui.screens

import android.widget.Toast
import androidx.compose.animation.*
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
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
import com.bookmyspace.bookmyspace.data.editor.DynamicElementManager
import com.bookmyspace.bookmyspace.data.model.AdminElementConfig
import com.bookmyspace.bookmyspace.data.model.AdminElementType
import com.bookmyspace.bookmyspace.ui.components.AdminElementInspectorModal

/**
 * 🛠️ ADMIN LIVE ELEMENT & OBJECT MASTER EDITOR SCREEN
 * Gives administrators complete, instantaneous control to edit any text,
 * input box placeholder, button label, badge, banner, or application object
 * with live on-device persistence, JSON import/export, and visual mode integration.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun AdminLiveElementEditorScreen(
    onNavigateBack: () -> Unit
) {
    val context = LocalContext.current
    val clipboardManager = LocalClipboardManager.current

    val elementsMap by DynamicElementManager.customElements.collectAsState()
    val isVisualEditMode by DynamicElementManager.isVisualEditModeActive.collectAsState()
    val inspectedElement by DynamicElementManager.inspectedElement.collectAsState()

    var searchQuery by remember { mutableStateOf("") }
    var selectedTypeFilter by remember { mutableStateOf<AdminElementType?>(null) }
    var selectedScreenFilter by remember { mutableStateOf<String?>(null) }
    var showAddCustomDialog by remember { mutableStateOf(false) }
    var showImportExportDialog by remember { mutableStateOf(false) }
    var showResetConfirmDialog by remember { mutableStateOf(false) }

    val allScreens = remember(elementsMap) {
        listOf("All Screens") + elementsMap.values.map { it.screenName }.distinct().sorted()
    }

    val filteredElements = remember(elementsMap, searchQuery, selectedTypeFilter, selectedScreenFilter) {
        elementsMap.values.filter { element ->
            val matchesSearch = searchQuery.isBlank() ||
                    element.displayName.contains(searchQuery, ignoreCase = true) ||
                    element.key.contains(searchQuery, ignoreCase = true) ||
                    element.currentValue.contains(searchQuery, ignoreCase = true) ||
                    (element.placeholder?.contains(searchQuery, ignoreCase = true) == true)

            val matchesType = selectedTypeFilter == null || element.elementType == selectedTypeFilter
            val matchesScreen = selectedScreenFilter == null || selectedScreenFilter == "All Screens" || element.screenName.equals(selectedScreenFilter, ignoreCase = true)

            matchesSearch && matchesType && matchesScreen
        }.sortedByDescending { it.isModified }
    }

    val modifiedCount = remember(elementsMap) {
        elementsMap.values.count { it.isModified }
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = {
                    Column {
                        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                            Text("Universal Element & Object Editor", fontSize = 16.sp, fontWeight = FontWeight.Bold)
                            Badge(containerColor = Color(0xFF673AB7)) {
                                Text("$modifiedCount edited", color = Color.White, fontSize = 10.sp)
                            }
                        }
                        Text("Live CMS for text, editboxes, CTAs & app objects", fontSize = 11.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                    }
                },
                navigationIcon = {
                    IconButton(onClick = onNavigateBack) {
                        Icon(Icons.Default.ArrowBack, contentDescription = "Back")
                    }
                },
                actions = {
                    // Visual Edit Mode Quick Toggle
                    IconButton(
                        onClick = {
                            DynamicElementManager.toggleVisualEditMode()
                            Toast.makeText(context, if (!isVisualEditMode) "✏️ Live Visual Edit Mode Enabled!" else "Visual Edit Mode Disabled", Toast.LENGTH_SHORT).show()
                        }
                    ) {
                        Icon(
                            imageVector = if (isVisualEditMode) Icons.Default.VisibilityOff else Icons.Default.Edit,
                            contentDescription = "Toggle Visual Edit",
                            tint = if (isVisualEditMode) Color(0xFF673AB7) else MaterialTheme.colorScheme.primary
                        )
                    }

                    // Import / Export JSON
                    IconButton(onClick = { showImportExportDialog = true }) {
                        Icon(Icons.Default.Code, contentDescription = "Import / Export JSON")
                    }

                    // Add Custom Element
                    IconButton(onClick = { showAddCustomDialog = true }) {
                        Icon(Icons.Default.AddCircleOutline, contentDescription = "Add Custom Element", tint = MaterialTheme.colorScheme.primary)
                    }
                }
            )
        }
    ) { padding ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(padding)
                .testTag("admin_element_editor_screen")
        ) {
            // Search Input
            OutlinedTextField(
                value = searchQuery,
                onValueChange = { searchQuery = it },
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 16.dp, vertical = 6.dp)
                    .testTag("element_search_input"),
                placeholder = { Text("Search by element name, key, or text...", fontSize = 13.sp) },
                leadingIcon = { Icon(Icons.Default.Search, contentDescription = null, modifier = Modifier.size(18.dp)) },
                trailingIcon = {
                    if (searchQuery.isNotBlank()) {
                        IconButton(onClick = { searchQuery = "" }) {
                            Icon(Icons.Default.Clear, contentDescription = "Clear", modifier = Modifier.size(16.dp))
                        }
                    }
                },
                shape = RoundedCornerShape(12.dp),
                singleLine = true
            )

            // Filter Chips by Element Type
            LazyRow(
                contentPadding = PaddingValues(horizontal = 16.dp, vertical = 4.dp),
                horizontalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                item {
                    FilterChip(
                        selected = selectedTypeFilter == null,
                        onClick = { selectedTypeFilter = null },
                        label = { Text("All Types (${elementsMap.size})", fontSize = 11.5.sp) }
                    )
                }
                items(AdminElementType.entries) { type ->
                    val count = elementsMap.values.count { it.elementType == type }
                    FilterChip(
                        selected = selectedTypeFilter == type,
                        onClick = { selectedTypeFilter = if (selectedTypeFilter == type) null else type },
                        label = { Text("${type.emoji} ${type.label} ($count)", fontSize = 11.5.sp) }
                    )
                }
            }

            // Screen Filter Chips
            LazyRow(
                contentPadding = PaddingValues(horizontal = 16.dp, vertical = 4.dp),
                horizontalArrangement = Arrangement.spacedBy(6.dp)
            ) {
                items(allScreens) { screen ->
                    val isSelected = (selectedScreenFilter == null && screen == "All Screens") || (selectedScreenFilter == screen)
                    SuggestionChip(
                        onClick = {
                            selectedScreenFilter = if (screen == "All Screens") null else screen
                        },
                        label = { Text(screen, fontSize = 11.sp, fontWeight = if (isSelected) FontWeight.Bold else FontWeight.Normal) },
                        colors = SuggestionChipDefaults.suggestionChipColors(
                            containerColor = if (isSelected) MaterialTheme.colorScheme.primaryContainer else MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.4f)
                        )
                    )
                }
            }

            // Summary Bar & Action Row
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 16.dp, vertical = 4.dp),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Text(
                    text = "Showing ${filteredElements.size} elements",
                    fontSize = 12.sp,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )

                if (modifiedCount > 0) {
                    TextButton(onClick = { showResetConfirmDialog = true }) {
                        Icon(Icons.Default.RestartAlt, contentDescription = null, modifier = Modifier.size(14.dp), tint = Color.Red)
                        Spacer(modifier = Modifier.width(4.dp))
                        Text("Reset All Defaults", fontSize = 11.5.sp, color = Color.Red)
                    }
                }
            }

            // Element Cards List
            LazyColumn(
                modifier = Modifier.fillMaxSize(),
                contentPadding = PaddingValues(start = 16.dp, end = 16.dp, bottom = 80.dp),
                verticalArrangement = Arrangement.spacedBy(10.dp)
            ) {
                items(filteredElements, key = { it.key }) { element ->
                    AdminElementCard(
                        element = element,
                        onEditClick = {
                            DynamicElementManager.openInspectorForElement(element)
                        },
                        onQuickTextUpdate = { updatedText ->
                            DynamicElementManager.updateElementText(element.key, updatedText)
                        },
                        onResetClick = {
                            DynamicElementManager.resetElement(element.key)
                            Toast.makeText(context, "Reverted '${element.displayName}' to default", Toast.LENGTH_SHORT).show()
                        }
                    )
                }
            }
        }
    }

    // Modal Inspector Sheet
    if (inspectedElement != null) {
        AdminElementInspectorModal(
            onDismissRequest = { DynamicElementManager.closeInspector() }
        )
    }

    // Dialog: Add Custom Dynamic Element
    if (showAddCustomDialog) {
        AddCustomElementDialog(
            onDismiss = { showAddCustomDialog = false },
            onAddElement = { newConfig ->
                DynamicElementManager.updateElement(newConfig)
                Toast.makeText(context, "Registered new custom element: ${newConfig.displayName}", Toast.LENGTH_SHORT).show()
                showAddCustomDialog = false
            }
        )
    }

    // Dialog: Import / Export Config
    if (showImportExportDialog) {
        ImportExportJsonDialog(
            onDismiss = { showImportExportDialog = false },
            onImport = { jsonStr ->
                val result = DynamicElementManager.importFromJson(jsonStr)
                if (result.isSuccess) {
                    Toast.makeText(context, "Successfully imported ${result.getOrNull()} elements!", Toast.LENGTH_SHORT).show()
                    showImportExportDialog = false
                } else {
                    Toast.makeText(context, "Import failed: ${result.exceptionOrNull()?.message}", Toast.LENGTH_LONG).show()
                }
            }
        )
    }

    // Dialog: Reset Confirm
    if (showResetConfirmDialog) {
        AlertDialog(
            onDismissRequest = { showResetConfirmDialog = false },
            title = { Text("Reset All Elements to Defaults?") },
            text = { Text("This will discard all customized texts, editbox hints, colors, and object parameters across the entire app.") },
            confirmButton = {
                Button(
                    onClick = {
                        DynamicElementManager.resetAllToDefaults()
                        Toast.makeText(context, "All app elements restored to factory defaults!", Toast.LENGTH_SHORT).show()
                        showResetConfirmDialog = false
                    },
                    colors = ButtonDefaults.buttonColors(containerColor = MaterialTheme.colorScheme.error)
                ) {
                    Text("Yes, Reset All")
                }
            },
            dismissButton = {
                TextButton(onClick = { showResetConfirmDialog = false }) {
                    Text("Cancel")
                }
            }
        )
    }
}

/**
 * 🃏 Individual Element Card with Quick Inline Editor.
 */
@Composable
fun AdminElementCard(
    element: AdminElementConfig,
    onEditClick: () -> Unit,
    onQuickTextUpdate: (String) -> Unit,
    onResetClick: () -> Unit
) {
    var isInlineEditing by remember { mutableStateOf(false) }
    var inlineTextValue by remember(element.currentValue) { mutableStateOf(element.currentValue) }

    Card(
        modifier = Modifier
            .fillMaxWidth()
            .testTag("element_card_${element.key}"),
        shape = RoundedCornerShape(14.dp),
        colors = CardDefaults.cardColors(
            containerColor = if (element.isModified) Color(0xFFF3E5F5) else MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.5f)
        ),
        elevation = CardDefaults.cardElevation(defaultElevation = if (element.isModified) 3.dp else 1.dp)
    ) {
        Column(
            modifier = Modifier.padding(14.dp),
            verticalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            // Header Row: Type Emoji + Name + Screen + Badges
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(6.dp),
                    modifier = Modifier.weight(1f)
                ) {
                    Text(element.elementType.emoji, fontSize = 16.sp)
                    Text(
                        text = element.displayName,
                        fontWeight = FontWeight.Bold,
                        fontSize = 14.sp
                    )
                }

                Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(4.dp)) {
                    Surface(
                        shape = RoundedCornerShape(4.dp),
                        color = MaterialTheme.colorScheme.primary.copy(alpha = 0.12f)
                    ) {
                        Text(
                            text = element.screenName,
                            fontSize = 10.sp,
                            fontWeight = FontWeight.Medium,
                            color = MaterialTheme.colorScheme.primary,
                            modifier = Modifier.padding(horizontal = 6.dp, vertical = 2.dp)
                        )
                    }

                    if (element.isModified) {
                        Surface(
                            shape = RoundedCornerShape(4.dp),
                            color = Color(0xFF673AB7)
                        ) {
                            Text(
                                text = "CUSTOMIZED",
                                fontSize = 9.sp,
                                fontWeight = FontWeight.Bold,
                                color = Color.White,
                                modifier = Modifier.padding(horizontal = 5.dp, vertical = 2.dp)
                            )
                        }
                    }
                }
            }

            // Key tag
            Text(
                text = "Key: ${element.key}",
                fontSize = 11.sp,
                fontFamily = androidx.compose.ui.text.font.FontFamily.Monospace,
                color = MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.8f)
            )

            // Current Value Display / Inline Editor
            if (isInlineEditing) {
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(8.dp)
                ) {
                    OutlinedTextField(
                        value = inlineTextValue,
                        onValueChange = { inlineTextValue = it },
                        modifier = Modifier.weight(1f),
                        singleLine = element.elementType != AdminElementType.BANNER,
                        shape = RoundedCornerShape(8.dp)
                    )
                    IconButton(
                        onClick = {
                            onQuickTextUpdate(inlineTextValue)
                            isInlineEditing = false
                        }
                    ) {
                        Icon(Icons.Default.Check, contentDescription = "Save", tint = Color(0xFF2E7D32))
                    }
                    IconButton(onClick = { isInlineEditing = false }) {
                        Icon(Icons.Default.Close, contentDescription = "Cancel", tint = Color.Gray)
                    }
                }
            } else {
                Surface(
                    color = MaterialTheme.colorScheme.surface,
                    shape = RoundedCornerShape(8.dp),
                    modifier = Modifier
                        .fillMaxWidth()
                        .clickable { isInlineEditing = true }
                ) {
                    Column(modifier = Modifier.padding(10.dp)) {
                        Text(
                            text = element.currentValue.ifEmpty { "(Empty String)" },
                            fontSize = 13.sp,
                            fontWeight = if (element.fontWeightName.equals("bold", true)) FontWeight.Bold else FontWeight.Normal,
                            color = MaterialTheme.colorScheme.onSurface
                        )

                        if (element.elementType == AdminElementType.EDIT_BOX && !element.placeholder.isNullOrBlank()) {
                            Text(
                                text = "Placeholder: \"${element.placeholder}\"",
                                fontSize = 11.sp,
                                color = MaterialTheme.colorScheme.onSurfaceVariant
                            )
                        }
                    }
                }
            }

            // Footer Actions (Advanced Inspector Modal, Quick Inline Edit, Revert)
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                    FilledTonalButton(
                        onClick = onEditClick,
                        contentPadding = PaddingValues(horizontal = 10.dp, vertical = 4.dp),
                        modifier = Modifier.height(32.dp)
                    ) {
                        Icon(Icons.Default.Tune, contentDescription = null, modifier = Modifier.size(14.dp))
                        Spacer(modifier = Modifier.width(4.dp))
                        Text("Customize Sheet", fontSize = 11.5.sp)
                    }

                    if (!isInlineEditing) {
                        OutlinedButton(
                            onClick = { isInlineEditing = true },
                            contentPadding = PaddingValues(horizontal = 8.dp, vertical = 4.dp),
                            modifier = Modifier.height(32.dp)
                        ) {
                            Icon(Icons.Default.Edit, contentDescription = null, modifier = Modifier.size(13.dp))
                            Spacer(modifier = Modifier.width(4.dp))
                            Text("Inline Edit", fontSize = 11.sp)
                        }
                    }
                }

                if (element.isModified) {
                    TextButton(
                        onClick = onResetClick,
                        contentPadding = PaddingValues(horizontal = 8.dp, vertical = 4.dp),
                        modifier = Modifier.height(32.dp)
                    ) {
                        Icon(Icons.Default.Restore, contentDescription = null, modifier = Modifier.size(13.dp), tint = Color.Gray)
                        Spacer(modifier = Modifier.width(2.dp))
                        Text("Revert", fontSize = 11.sp, color = Color.Gray)
                    }
                }
            }
        }
    }
}

/**
 * ➕ Dialog to Register a New Dynamic Element on the Fly.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun AddCustomElementDialog(
    onDismiss: () -> Unit,
    onAddElement: (AdminElementConfig) -> Unit
) {
    var key by remember { mutableStateOf("") }
    var displayName by remember { mutableStateOf("") }
    var screenName by remember { mutableStateOf("Global") }
    var selectedType by remember { mutableStateOf(AdminElementType.TEXT) }
    var defaultValue by remember { mutableStateOf("") }
    var description by remember { mutableStateOf("") }

    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text("Add New Editable Element") },
        text = {
            Column(
                modifier = Modifier.fillMaxWidth(),
                verticalArrangement = Arrangement.spacedBy(10.dp)
            ) {
                OutlinedTextField(
                    value = key,
                    onValueChange = { key = it.trim().lowercase().replace(" ", "_") },
                    label = { Text("Unique Element Key (e.g. checkout_badge)") },
                    modifier = Modifier.fillMaxWidth()
                )

                OutlinedTextField(
                    value = displayName,
                    onValueChange = { displayName = it },
                    label = { Text("Display Name") },
                    modifier = Modifier.fillMaxWidth()
                )

                OutlinedTextField(
                    value = screenName,
                    onValueChange = { screenName = it },
                    label = { Text("Target Screen (e.g. Home, Search, Bookings)") },
                    modifier = Modifier.fillMaxWidth()
                )

                OutlinedTextField(
                    value = defaultValue,
                    onValueChange = { defaultValue = it },
                    label = { Text("Default Text / Value") },
                    modifier = Modifier.fillMaxWidth()
                )

                OutlinedTextField(
                    value = description,
                    onValueChange = { description = it },
                    label = { Text("Description / Usage Context") },
                    modifier = Modifier.fillMaxWidth()
                )
            }
        },
        confirmButton = {
            Button(
                onClick = {
                    if (key.isNotBlank() && defaultValue.isNotBlank()) {
                        val config = AdminElementConfig(
                            key = key,
                            screenName = screenName.ifBlank { "Global" },
                            elementType = selectedType,
                            displayName = displayName.ifBlank { key },
                            description = description,
                            currentValue = defaultValue,
                            defaultValue = defaultValue,
                            isCustom = true
                        )
                        onAddElement(config)
                    }
                },
                enabled = key.isNotBlank() && defaultValue.isNotBlank()
            ) {
                Text("Register Element")
            }
        },
        dismissButton = {
            TextButton(onClick = onDismiss) {
                Text("Cancel")
            }
        }
    )
}

/**
 * 💾 Import / Export Config JSON Dialog.
 */
@Composable
fun ImportExportJsonDialog(
    onDismiss: () -> Unit,
    onImport: (String) -> Unit
) {
    val clipboardManager = LocalClipboardManager.current
    val context = LocalContext.current
    var jsonText by remember { mutableStateOf(DynamicElementManager.exportToJson()) }

    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text("Export / Import Element Configuration") },
        text = {
            Column(
                modifier = Modifier.fillMaxWidth(),
                verticalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                Text("Copy this JSON configuration to backup your customizations, or paste an external JSON schema to import changes across all screens.", fontSize = 12.sp)

                OutlinedTextField(
                    value = jsonText,
                    onValueChange = { jsonText = it },
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(200.dp),
                    textStyle = androidx.compose.ui.text.TextStyle(
                        fontSize = 11.sp,
                        fontFamily = androidx.compose.ui.text.font.FontFamily.Monospace
                    )
                )

                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.End
                ) {
                    TextButton(
                        onClick = {
                            clipboardManager.setText(AnnotatedString(jsonText))
                            Toast.makeText(context, "Exported JSON copied to clipboard!", Toast.LENGTH_SHORT).show()
                        }
                    ) {
                        Icon(Icons.Default.ContentCopy, contentDescription = null, modifier = Modifier.size(16.dp))
                        Spacer(modifier = Modifier.width(4.dp))
                        Text("Copy to Clipboard")
                    }
                }
            }
        },
        confirmButton = {
            Button(
                onClick = { onImport(jsonText) }
            ) {
                Text("Apply & Import")
            }
        },
        dismissButton = {
            TextButton(onClick = onDismiss) {
                Text("Close")
            }
        }
    )
}
