package com.bookmyspace.bookmyspace.ui.components

import android.widget.Toast
import androidx.compose.animation.*
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
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
import androidx.compose.ui.platform.LocalClipboardManager
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.AnnotatedString
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.TextUnit
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.bookmyspace.bookmyspace.data.auth.UserRoleProvider
import com.bookmyspace.bookmyspace.data.editor.DynamicElementManager
import com.bookmyspace.bookmyspace.data.model.AdminElementConfig
import com.bookmyspace.bookmyspace.data.model.AdminElementType

/**
 * 🔤 Dynamic Admin Editable Text Composable.
 * In normal mode, renders styled text.
 * In Admin Visual Edit Mode, adds an interactive edit outline and tap-to-customize trigger.
 */
@Composable
fun AdminEditableText(
    elementKey: String,
    defaultText: String,
    modifier: Modifier = Modifier,
    screenName: String = "Global",
    style: TextStyle = LocalTextStyle.current,
    color: Color = Color.Unspecified,
    fontSize: TextUnit = TextUnit.Unspecified,
    fontWeight: FontWeight? = null,
    textAlign: TextAlign? = null,
    maxLines: Int = Int.MAX_VALUE,
    overflow: TextOverflow = TextOverflow.Clip
) {
    val elements by DynamicElementManager.customElements.collectAsState()
    val isVisualEditMode by DynamicElementManager.isVisualEditModeActive.collectAsState()
    val isAdmin = UserRoleProvider.hasAdminPrivileges

    val config = remember(elements, elementKey) {
        DynamicElementManager.getElement(
            key = elementKey,
            defaultVal = defaultText,
            screenName = screenName,
            type = AdminElementType.TEXT
        )
    }

    if (!config.isVisible) return

    val resolvedText = config.currentValue.ifEmpty { defaultText }
    val resolvedColor = if (config.colorHex != null) Color(config.colorHex) else color
    val resolvedFontSize = if (config.fontSizeSp != null) config.fontSizeSp.sp else fontSize
    val resolvedFontWeight = when (config.fontWeightName.lowercase()) {
        "bold" -> FontWeight.Bold
        "semibold" -> FontWeight.SemiBold
        "medium" -> FontWeight.Medium
        else -> fontWeight
    }

    if (isVisualEditMode && isAdmin) {
        Box(
            modifier = modifier
                .clip(RoundedCornerShape(6.dp))
                .border(
                    width = 1.5.dp,
                    color = if (config.isModified) Color(0xFF673AB7) else Color(0xFF2196F3),
                    shape = RoundedCornerShape(6.dp)
                )
                .background(
                    if (config.isModified) Color(0x1A673AB7) else Color(0x152196F3)
                )
                .clickable {
                    DynamicElementManager.openInspectorForElement(config)
                }
                .padding(horizontal = 4.dp, vertical = 2.dp)
                .testTag("admin_editable_text_$elementKey")
        ) {
            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(4.dp)
            ) {
                Icon(
                    imageVector = Icons.Default.Edit,
                    contentDescription = "Edit $elementKey",
                    tint = if (config.isModified) Color(0xFF673AB7) else Color(0xFF1976D2),
                    modifier = Modifier.size(12.dp)
                )
                Text(
                    text = resolvedText,
                    style = style,
                    color = resolvedColor,
                    fontSize = resolvedFontSize,
                    fontWeight = resolvedFontWeight,
                    textAlign = textAlign,
                    maxLines = maxLines,
                    overflow = overflow
                )
            }
        }
    } else {
        Text(
            text = resolvedText,
            modifier = modifier.testTag("text_$elementKey"),
            style = style,
            color = resolvedColor,
            fontSize = resolvedFontSize,
            fontWeight = resolvedFontWeight,
            textAlign = textAlign,
            maxLines = maxLines,
            overflow = overflow
        )
    }
}

/**
 * 📝 Dynamic Admin Editable TextField / EditBox.
 * Live-updates placeholder, helper text, and label with instant admin customization.
 */
@Composable
fun AdminEditableTextField(
    elementKey: String,
    value: String,
    onValueChange: (String) -> Unit,
    defaultPlaceholder: String,
    modifier: Modifier = Modifier,
    screenName: String = "Global",
    defaultLabel: String? = null,
    defaultHelper: String? = null,
    leadingIcon: @Composable (() -> Unit)? = null,
    trailingIcon: @Composable (() -> Unit)? = null,
    singleLine: Boolean = true,
    isError: Boolean = false,
    enabled: Boolean = true,
    colors: TextFieldColors = OutlinedTextFieldDefaults.colors()
) {
    val elements by DynamicElementManager.customElements.collectAsState()
    val isVisualEditMode by DynamicElementManager.isVisualEditModeActive.collectAsState()
    val isAdmin = UserRoleProvider.hasAdminPrivileges

    val config = remember(elements, elementKey) {
        DynamicElementManager.getElement(
            key = elementKey,
            defaultVal = defaultPlaceholder,
            screenName = screenName,
            type = AdminElementType.EDIT_BOX
        ).let { cfg ->
            if (cfg.placeholder == null) cfg.copy(placeholder = defaultPlaceholder, defaultPlaceholder = defaultPlaceholder, helperText = defaultHelper, defaultHelperText = defaultHelper)
            else cfg
        }
    }

    val resolvedPlaceholder = config.placeholder ?: defaultPlaceholder
    val resolvedHelper = config.helperText ?: defaultHelper

    Column(modifier = modifier) {
        if (isVisualEditMode && isAdmin) {
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(bottom = 4.dp),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Surface(
                    color = if (config.isModified) Color(0xFFEDE7F6) else Color(0xFFE3F2FD),
                    shape = RoundedCornerShape(4.dp),
                    modifier = Modifier.clickable { DynamicElementManager.openInspectorForElement(config) }
                ) {
                    Row(
                        modifier = Modifier.padding(horizontal = 6.dp, vertical = 2.dp),
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.spacedBy(4.dp)
                    ) {
                        Icon(
                            imageVector = Icons.Default.Tune,
                            contentDescription = null,
                            tint = if (config.isModified) Color(0xFF673AB7) else Color(0xFF1976D2),
                            modifier = Modifier.size(12.dp)
                        )
                        Text(
                            text = "EditBox: ${config.displayName}",
                            fontSize = 11.sp,
                            fontWeight = FontWeight.Bold,
                            color = if (config.isModified) Color(0xFF673AB7) else Color(0xFF1976D2)
                        )
                    }
                }
            }
        }

        OutlinedTextField(
            value = value,
            onValueChange = onValueChange,
            modifier = Modifier
                .fillMaxWidth()
                .testTag("input_$elementKey"),
            placeholder = { Text(resolvedPlaceholder, fontSize = 14.sp) },
            label = defaultLabel?.let { { Text(it) } },
            supportingText = resolvedHelper?.let { { Text(it, fontSize = 11.sp) } },
            leadingIcon = leadingIcon,
            trailingIcon = trailingIcon,
            singleLine = singleLine,
            isError = isError,
            enabled = enabled,
            shape = RoundedCornerShape(12.dp),
            colors = colors
        )
    }
}

/**
 * 🔘 Dynamic Admin Editable Button.
 */
@Composable
fun AdminEditableButton(
    elementKey: String,
    defaultText: String,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    screenName: String = "Global",
    enabled: Boolean = true,
    icon: @Composable (() -> Unit)? = null,
    colors: ButtonColors = ButtonDefaults.buttonColors()
) {
    val elements by DynamicElementManager.customElements.collectAsState()
    val isVisualEditMode by DynamicElementManager.isVisualEditModeActive.collectAsState()
    val isAdmin = UserRoleProvider.hasAdminPrivileges

    val config = remember(elements, elementKey) {
        DynamicElementManager.getElement(
            key = elementKey,
            defaultVal = defaultText,
            screenName = screenName,
            type = AdminElementType.BUTTON
        )
    }

    if (!config.isVisible) return

    val resolvedText = config.currentValue.ifEmpty { defaultText }

    Box(modifier = modifier) {
        Button(
            onClick = {
                if (isVisualEditMode && isAdmin) {
                    DynamicElementManager.openInspectorForElement(config)
                } else {
                    onClick()
                }
            },
            enabled = enabled,
            modifier = Modifier
                .fillMaxWidth()
                .testTag("btn_$elementKey"),
            shape = RoundedCornerShape(12.dp),
            colors = colors
        ) {
            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.Center,
                modifier = Modifier.padding(vertical = 2.dp)
            ) {
                if (isVisualEditMode && isAdmin) {
                    Icon(
                        imageVector = Icons.Default.Edit,
                        contentDescription = null,
                        modifier = Modifier
                            .size(16.dp)
                            .padding(end = 4.dp)
                    )
                } else if (icon != null) {
                    icon()
                    Spacer(modifier = Modifier.width(6.dp))
                }
                Text(
                    text = resolvedText,
                    fontWeight = if (config.fontWeightName.equals("bold", true)) FontWeight.Bold else FontWeight.SemiBold,
                    fontSize = if (config.fontSizeSp != null) config.fontSizeSp.sp else 14.sp
                )
            }
        }
    }
}

/**
 * 🎛️ Floating Admin Quick Edit Toolbar & Inspector Trigger.
 * Appears as a sleek floating bottom HUD for Admin users across all screens.
 */
@Composable
fun AdminGlobalFloatingToolbar(
    modifier: Modifier = Modifier,
    onNavigateToMasterEditor: (() -> Unit)? = null,
    onNavigateToFirebaseMigration: (() -> Unit)? = null,
    onNavigateToAdminSettings: (() -> Unit)? = null
) {
    val isAdmin = UserRoleProvider.hasAdminPrivileges
    val isVisualEditMode by DynamicElementManager.isVisualEditModeActive.collectAsState()
    val elements by DynamicElementManager.customElements.collectAsState()
    val modifiedCount = remember(elements) { elements.values.count { it.isModified } }
    var isExpanded by remember { mutableStateOf(false) }

    if (!isAdmin) return

    Box(
        modifier = modifier
            .fillMaxWidth()
            .padding(bottom = 80.dp, end = 16.dp, start = 16.dp),
        contentAlignment = Alignment.BottomEnd
    ) {
        Column(
            horizontalAlignment = Alignment.End,
            verticalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            // Expanded Admin Action Menu
            AnimatedVisibility(
                visible = isExpanded,
                enter = fadeIn() + expandVertically(),
                exit = fadeOut() + shrinkVertically()
            ) {
                Card(
                    shape = RoundedCornerShape(18.dp),
                    colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface),
                    elevation = CardDefaults.cardElevation(defaultElevation = 8.dp),
                    modifier = Modifier.width(270.dp)
                ) {
                    Column(
                        modifier = Modifier.padding(14.dp),
                        verticalArrangement = Arrangement.spacedBy(10.dp)
                    ) {
                        Row(
                            verticalAlignment = Alignment.CenterVertically,
                            horizontalArrangement = Arrangement.SpaceBetween,
                            modifier = Modifier.fillMaxWidth()
                        ) {
                            Text("Admin Live Customizer", fontWeight = FontWeight.Bold, fontSize = 13.sp)
                            Badge(containerColor = Color(0xFF673AB7)) {
                                Text("$modifiedCount edited", color = Color.White, fontSize = 10.sp)
                            }
                        }

                        Divider()

                        // Toggle Visual Edit Mode
                        FilledTonalButton(
                            onClick = {
                                DynamicElementManager.toggleVisualEditMode()
                                isExpanded = false
                            },
                            modifier = Modifier.fillMaxWidth(),
                            colors = ButtonDefaults.filledTonalButtonColors(
                                containerColor = if (isVisualEditMode) Color(0xFFFFEBEE) else Color(0xFFE8F5E9)
                            )
                        ) {
                            Icon(
                                imageVector = if (isVisualEditMode) Icons.Default.Visibility else Icons.Default.Edit,
                                contentDescription = null,
                                tint = if (isVisualEditMode) Color(0xFFD32F2F) else Color(0xFF2E7D32),
                                modifier = Modifier.size(16.dp)
                            )
                            Spacer(modifier = Modifier.width(6.dp))
                            Text(
                                text = if (isVisualEditMode) "Exit Visual Edit" else "Turn Visual Edit ON",
                                fontSize = 12.sp,
                                color = if (isVisualEditMode) Color(0xFFD32F2F) else Color(0xFF2E7D32),
                                fontWeight = FontWeight.Bold
                            )
                        }

                        // Open Master Catalog
                        if (onNavigateToMasterEditor != null) {
                            OutlinedButton(
                                onClick = {
                                    isExpanded = false
                                    onNavigateToMasterEditor()
                                },
                                modifier = Modifier.fillMaxWidth()
                            ) {
                                Icon(Icons.Default.Tune, contentDescription = null, modifier = Modifier.size(16.dp))
                                Spacer(modifier = Modifier.width(6.dp))
                                Text("All Elements Catalog", fontSize = 12.sp)
                            }
                        }

                        // Open Admin Platform Settings
                        if (onNavigateToAdminSettings != null) {
                            OutlinedButton(
                                onClick = {
                                    isExpanded = false
                                    onNavigateToAdminSettings()
                                },
                                modifier = Modifier.fillMaxWidth()
                            ) {
                                Icon(Icons.Default.Settings, contentDescription = null, modifier = Modifier.size(16.dp), tint = Color(0xFF1565C0))
                                Spacer(modifier = Modifier.width(6.dp))
                                Text("Platform Config & Keys", fontSize = 12.sp, color = Color(0xFF1565C0), fontWeight = FontWeight.Bold)
                            }
                        }

                        // Open Firebase Migration Hub
                        if (onNavigateToFirebaseMigration != null) {
                            OutlinedButton(
                                onClick = {
                                    isExpanded = false
                                    onNavigateToFirebaseMigration()
                                },
                                modifier = Modifier.fillMaxWidth()
                            ) {
                                Icon(Icons.Default.CloudSync, contentDescription = null, modifier = Modifier.size(16.dp), tint = Color(0xFFE65100))
                                Spacer(modifier = Modifier.width(6.dp))
                                Text("Firebase DB Migration", fontSize = 12.sp, color = Color(0xFFE65100), fontWeight = FontWeight.Bold)
                            }
                        }

                        // Reset All Button
                        TextButton(
                            onClick = {
                                DynamicElementManager.resetAllToDefaults()
                                isExpanded = false
                            },
                            modifier = Modifier.fillMaxWidth()
                        ) {
                            Icon(Icons.Default.RestartAlt, contentDescription = null, modifier = Modifier.size(14.dp), tint = Color.Gray)
                            Spacer(modifier = Modifier.width(4.dp))
                            Text("Reset All to Defaults", fontSize = 11.sp, color = Color.Gray)
                        }
                    }
                }
            }

            // Main Floating Pill
            Surface(
                onClick = { isExpanded = !isExpanded },
                shape = CircleShape,
                color = if (isVisualEditMode) Color(0xFF673AB7) else MaterialTheme.colorScheme.primaryContainer,
                shadowElevation = 6.dp,
                modifier = Modifier
                    .height(44.dp)
                    .testTag("admin_floating_edit_hud")
            ) {
                Row(
                    modifier = Modifier.padding(horizontal = 14.dp),
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(8.dp)
                ) {
                    Icon(
                        imageVector = if (isVisualEditMode) Icons.Default.EditNote else Icons.Default.AdminPanelSettings,
                        contentDescription = "Admin Customizer",
                        tint = if (isVisualEditMode) Color.White else MaterialTheme.colorScheme.onPrimaryContainer,
                        modifier = Modifier.size(18.dp)
                    )
                    Text(
                        text = if (isVisualEditMode) "✏️ Live Edit ON" else "Admin UI Tools",
                        fontSize = 12.5.sp,
                        fontWeight = FontWeight.Bold,
                        color = if (isVisualEditMode) Color.White else MaterialTheme.colorScheme.onPrimaryContainer
                    )
                    if (modifiedCount > 0) {
                        Surface(
                            shape = CircleShape,
                            color = if (isVisualEditMode) Color.White else MaterialTheme.colorScheme.primary,
                            modifier = Modifier.size(18.dp)
                        ) {
                            Box(contentAlignment = Alignment.Center) {
                                Text(
                                    text = "$modifiedCount",
                                    fontSize = 10.sp,
                                    fontWeight = FontWeight.Bold,
                                    color = if (isVisualEditMode) Color(0xFF673AB7) else Color.White
                                )
                            }
                        }
                    }
                }
            }
        }
    }
}

/**
 * 🛠️ Modal Bottom Sheet Dialog for Live Element & Object Customization.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun AdminElementInspectorModal(
    onDismissRequest: () -> Unit
) {
    val inspectedElement by DynamicElementManager.inspectedElement.collectAsState()
    val context = LocalContext.current
    val clipboardManager = LocalClipboardManager.current

    if (inspectedElement == null) return
    val element = inspectedElement!!

    var editedText by remember(element) { mutableStateOf(element.currentValue) }
    var editedPlaceholder by remember(element) { mutableStateOf(element.placeholder ?: "") }
    var editedHelperText by remember(element) { mutableStateOf(element.helperText ?: "") }
    var isVisible by remember(element) { mutableStateOf(element.isVisible) }
    var selectedWeight by remember(element) { mutableStateOf(element.fontWeightName) }
    var selectedFontSizeStr by remember(element) { mutableStateOf(element.fontSizeSp?.toString() ?: "") }
    var selectedColorHexStr by remember(element) {
        mutableStateOf(element.colorHex?.let { java.lang.Long.toHexString(it).uppercase() } ?: "")
    }

    ModalBottomSheet(
        onDismissRequest = {
            DynamicElementManager.closeInspector()
            onDismissRequest()
        },
        shape = RoundedCornerShape(topStart = 24.dp, topEnd = 24.dp)
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 20.dp, vertical = 12.dp)
                .verticalScroll(rememberScrollState())
                .testTag("admin_element_inspector_sheet"),
            verticalArrangement = Arrangement.spacedBy(14.dp)
        ) {
            // Header
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Column {
                    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                        Text(element.elementType.emoji, fontSize = 20.sp)
                        Text(
                            text = element.displayName,
                            fontWeight = FontWeight.Bold,
                            fontSize = 17.sp
                        )
                    }
                    Text(
                        text = "Key: ${element.key} • Screen: ${element.screenName}",
                        fontSize = 11.5.sp,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                }
                IconButton(onClick = { DynamicElementManager.closeInspector() }) {
                    Icon(Icons.Default.Close, contentDescription = "Close")
                }
            }

            Divider()

            // Description / Context
            if (element.description.isNotBlank()) {
                Surface(
                    color = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.5f),
                    shape = RoundedCornerShape(8.dp)
                ) {
                    Text(
                        text = "💡 ${element.description}",
                        fontSize = 12.sp,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                        modifier = Modifier.padding(10.dp)
                    )
                }
            }

            // Text / Value Input
            Text(
                text = if (element.elementType == AdminElementType.EDIT_BOX) "Label / Primary Text" else "Element Text / Value",
                fontWeight = FontWeight.SemiBold,
                fontSize = 13.sp
            )
            OutlinedTextField(
                value = editedText,
                onValueChange = { editedText = it },
                modifier = Modifier
                    .fillMaxWidth()
                    .testTag("inspector_text_input"),
                shape = RoundedCornerShape(10.dp),
                minLines = if (element.elementType == AdminElementType.BANNER) 3 else 1
            )

            // EditBox specific inputs
            if (element.elementType == AdminElementType.EDIT_BOX) {
                Text("Placeholder Hint", fontWeight = FontWeight.SemiBold, fontSize = 13.sp)
                OutlinedTextField(
                    value = editedPlaceholder,
                    onValueChange = { editedPlaceholder = it },
                    modifier = Modifier.fillMaxWidth(),
                    shape = RoundedCornerShape(10.dp)
                )

                Text("Helper / Sub-label Text (Optional)", fontWeight = FontWeight.SemiBold, fontSize = 13.sp)
                OutlinedTextField(
                    value = editedHelperText,
                    onValueChange = { editedHelperText = it },
                    modifier = Modifier.fillMaxWidth(),
                    shape = RoundedCornerShape(10.dp)
                )
            }

            // Object / Key-Value Specific JSON Info
            if (element.elementType == AdminElementType.OBJECT_JSON) {
                Surface(
                    color = Color(0xFFFFF8E1),
                    shape = RoundedCornerShape(8.dp),
                    modifier = Modifier.fillMaxWidth()
                ) {
                    Row(modifier = Modifier.padding(10.dp), verticalAlignment = Alignment.CenterVertically) {
                        Icon(Icons.Default.Info, contentDescription = null, tint = Color(0xFFF57F17), modifier = Modifier.size(16.dp))
                        Spacer(modifier = Modifier.width(6.dp))
                        Text(
                            "This parameter directly configures live application fee calculations & policies.",
                            fontSize = 11.5.sp,
                            color = Color(0xFF5D4037)
                        )
                    }
                }
            }

            // Quick Styling Options (Font weight, Font Size, Visibility)
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(12.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                // Font Weight Selector
                Column(modifier = Modifier.weight(1f)) {
                    Text("Weight", fontSize = 12.sp, fontWeight = FontWeight.Medium)
                    Row(horizontalArrangement = Arrangement.spacedBy(4.dp)) {
                        listOf("Normal", "Medium", "Bold").forEach { w ->
                            FilterChip(
                                selected = selectedWeight.equals(w, true),
                                onClick = { selectedWeight = w },
                                label = { Text(w, fontSize = 10.5.sp) }
                            )
                        }
                    }
                }

                // Visibility Toggle
                Column(horizontalAlignment = Alignment.End) {
                    Text("Visibility", fontSize = 12.sp, fontWeight = FontWeight.Medium)
                    Switch(
                        checked = isVisible,
                        onCheckedChange = { isVisible = it }
                    )
                }
            }

            // Actions (Save, Reset, Copy JSON)
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(top = 8.dp, bottom = 16.dp),
                horizontalArrangement = Arrangement.spacedBy(10.dp)
            ) {
                // Revert to Default
                OutlinedButton(
                    onClick = {
                        DynamicElementManager.resetElement(element.key)
                        Toast.makeText(context, "Reverted '${element.displayName}' to default!", Toast.LENGTH_SHORT).show()
                        DynamicElementManager.closeInspector()
                    },
                    modifier = Modifier.weight(1f)
                ) {
                    Icon(Icons.Default.Restore, contentDescription = null, modifier = Modifier.size(16.dp))
                    Spacer(modifier = Modifier.width(4.dp))
                    Text("Revert", fontSize = 12.sp)
                }

                // Save Live Button
                Button(
                    onClick = {
                        val parsedFontSize = selectedFontSizeStr.toFloatOrNull()
                        val parsedColor = try {
                            if (selectedColorHexStr.isNotBlank()) java.lang.Long.parseLong(selectedColorHexStr, 16) else null
                        } catch (e: Exception) { null }

                        val updated = element.copy(
                            currentValue = editedText,
                            placeholder = if (element.elementType == AdminElementType.EDIT_BOX) editedPlaceholder else element.placeholder,
                            helperText = if (element.elementType == AdminElementType.EDIT_BOX) editedHelperText else element.helperText,
                            fontWeightName = selectedWeight,
                            fontSizeSp = parsedFontSize,
                            colorHex = parsedColor,
                            isVisible = isVisible
                        )
                        DynamicElementManager.updateElement(updated)
                        Toast.makeText(context, "Saved changes for '${element.displayName}'!", Toast.LENGTH_SHORT).show()
                        DynamicElementManager.closeInspector()
                    },
                    colors = ButtonDefaults.buttonColors(containerColor = Color(0xFF673AB7)),
                    modifier = Modifier
                        .weight(1.5f)
                        .testTag("save_element_btn")
                ) {
                    Icon(Icons.Default.Check, contentDescription = null, modifier = Modifier.size(16.dp))
                    Spacer(modifier = Modifier.width(6.dp))
                    Text("Save Live", fontWeight = FontWeight.Bold)
                }
            }
        }
    }
}
