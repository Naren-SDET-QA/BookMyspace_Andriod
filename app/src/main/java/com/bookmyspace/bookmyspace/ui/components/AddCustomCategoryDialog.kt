package com.bookmyspace.bookmyspace.ui.components

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.Category
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.Star
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
import androidx.compose.ui.window.Dialog
import androidx.compose.ui.window.DialogProperties
import com.bookmyspace.bookmyspace.data.model.VenueCategory
import com.bookmyspace.bookmyspace.data.repository.BookMySpaceRepository

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun AddCustomCategoryDialog(
    initialSectionId: String? = null,
    onDismiss: () -> Unit,
    onCategoryCreated: (VenueCategory) -> Unit
) {
    var categoryName by remember { mutableStateOf("") }
    var selectedEmoji by remember { mutableStateOf("✨") }
    var selectedSection by remember {
        mutableStateOf(
            when (initialSectionId) {
                "function_halls", "venues_function_halls", "venues_halls" -> "function_halls"
                "lodge_rooms", "hotels_rooms", "hotels" -> "lodge_rooms"
                "pg_hostels", "pg" -> "pg_hostels"
                "institutes_classes", "institutes" -> "institutes_classes"
                else -> "function_halls"
            }
        )
    }
    var errorMessage by remember { mutableStateOf<String?>(null) }

    val presetEmojis = listOf(
        "✨", "🎪", "🏕️", "🎮", "🎙️", "📸", "💻", "☕",
        "🧘", "🏊", "🎨", "🏎️", "🧖", "🚴", "🍽️", "🏡"
    )

    val sectionOptions = listOf(
        "function_halls" to "🏛️ Function Halls",
        "lodge_rooms" to "🏨 Lodge / Rooms",
        "pg_hostels" to "🏠 PG / Hostels",
        "institutes_classes" to "🎓 Institutes / Classes",
        "general" to "🌐 Other / Custom Spaces"
    )

    val quickPresetSuggestions = listOf(
        "Esports & Gaming Lounge" to "🎮",
        "Photography & Video Studio" to "📸",
        "Sound Recording Studio" to "🎙️",
        "Coworking & Study Cafe" to "💻",
        "Rooftop Party Gazebo" to "🎪",
        "Yoga & Wellness Ashram" to "🧘",
        "Farmhouse Weekend Stay" to "🏕️",
        "Executive Studio PG" to "🏡",
        "Art & Pottery Workshop" to "🎨",
        "Badminton & Pickleball Arena" to "🏸"
    )

    Dialog(
        onDismissRequest = onDismiss,
        properties = DialogProperties(usePlatformDefaultWidth = false)
    ) {
        Surface(
            modifier = Modifier
                .fillMaxWidth(0.92f)
                .wrapContentHeight()
                .padding(vertical = 24.dp)
                .testTag("add_custom_category_dialog"),
            shape = RoundedCornerShape(24.dp),
            color = MaterialTheme.colorScheme.surface,
            tonalElevation = 6.dp,
            shadowElevation = 8.dp
        ) {
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(20.dp),
                verticalArrangement = Arrangement.spacedBy(14.dp)
            ) {
                // Header
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Box(
                            modifier = Modifier
                                .size(40.dp)
                                .clip(CircleShape)
                                .background(MaterialTheme.colorScheme.primaryContainer),
                            contentAlignment = Alignment.Center
                        ) {
                            Text(text = selectedEmoji, fontSize = 20.sp)
                        }
                        Spacer(modifier = Modifier.width(10.dp))
                        Column {
                            Text(
                                text = "Add New Category",
                                fontWeight = FontWeight.Bold,
                                fontSize = 17.sp,
                                color = MaterialTheme.colorScheme.onSurface
                            )
                            Text(
                                text = "Create a custom category for any space",
                                fontSize = 11.5.sp,
                                color = MaterialTheme.colorScheme.onSurfaceVariant
                            )
                        }
                    }
                    IconButton(
                        onClick = onDismiss,
                        modifier = Modifier.size(32.dp)
                    ) {
                        Icon(
                            imageVector = Icons.Default.Close,
                            contentDescription = "Close",
                            tint = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                    }
                }

                Divider(color = MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.5f))

                // Target Section Selector
                Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
                    Text(
                        text = "Belongs to Section *",
                        fontWeight = FontWeight.SemiBold,
                        fontSize = 12.5.sp,
                        color = MaterialTheme.colorScheme.onSurface
                    )
                    LazyRow(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                        items(sectionOptions) { (secKey, secLabel) ->
                            val isSelected = selectedSection == secKey
                            FilterChip(
                                selected = isSelected,
                                onClick = { selectedSection = secKey },
                                label = { Text(secLabel, fontSize = 12.sp) },
                                shape = RoundedCornerShape(12.dp),
                                colors = FilterChipDefaults.filterChipColors(
                                    selectedContainerColor = MaterialTheme.colorScheme.primary,
                                    selectedLabelColor = MaterialTheme.colorScheme.onPrimary
                                )
                            )
                        }
                    }
                }

                // Category Name Input
                Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
                    OutlinedTextField(
                        value = categoryName,
                        onValueChange = {
                            categoryName = it
                            if (errorMessage != null) errorMessage = null
                        },
                        label = { Text("Category Name *") },
                        placeholder = { Text("e.g. Esports Arena, Studio, Ashram...") },
                        leadingIcon = {
                            Icon(
                                imageVector = Icons.Default.Category,
                                contentDescription = null,
                                tint = MaterialTheme.colorScheme.primary
                            )
                        },
                        singleLine = true,
                        isError = errorMessage != null,
                        modifier = Modifier
                            .fillMaxWidth()
                            .testTag("input_custom_category_name"),
                        shape = RoundedCornerShape(14.dp)
                    )
                    if (errorMessage != null) {
                        Text(
                            text = errorMessage ?: "",
                            color = MaterialTheme.colorScheme.error,
                            fontSize = 11.sp,
                            modifier = Modifier.padding(start = 6.dp)
                        )
                    }
                }

                // Emoji Picker
                Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
                    Text(
                        text = "Category Icon / Emoji",
                        fontWeight = FontWeight.SemiBold,
                        fontSize = 12.5.sp,
                        color = MaterialTheme.colorScheme.onSurface
                    )
                    LazyRow(
                        horizontalArrangement = Arrangement.spacedBy(8.dp),
                        modifier = Modifier.fillMaxWidth()
                    ) {
                        items(presetEmojis) { emoji ->
                            val isSelected = selectedEmoji == emoji
                            Box(
                                modifier = Modifier
                                    .size(40.dp)
                                    .clip(RoundedCornerShape(10.dp))
                                    .background(
                                        if (isSelected) MaterialTheme.colorScheme.primary
                                        else MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.5f)
                                    )
                                    .clickable { selectedEmoji = emoji },
                                contentAlignment = Alignment.Center
                            ) {
                                Text(text = emoji, fontSize = 20.sp)
                            }
                        }
                    }
                }

                // Quick Suggestions Chips
                Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Icon(
                            imageVector = Icons.Default.Star,
                            contentDescription = null,
                            tint = Color(0xFFF59E0B),
                            modifier = Modifier.size(14.dp)
                        )
                        Spacer(modifier = Modifier.width(4.dp))
                        Text(
                            text = "Popular Suggestions (Tap to fill)",
                            fontSize = 11.sp,
                            fontWeight = FontWeight.SemiBold,
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                    }
                    LazyRow(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                        items(quickPresetSuggestions) { (suggName, suggEmoji) ->
                            SuggestionChip(
                                onClick = {
                                    categoryName = suggName
                                    selectedEmoji = suggEmoji
                                    if (errorMessage != null) errorMessage = null
                                },
                                label = {
                                    Row(verticalAlignment = Alignment.CenterVertically) {
                                        Text(suggEmoji, fontSize = 12.sp)
                                        Spacer(modifier = Modifier.width(4.dp))
                                        Text(suggName, fontSize = 11.sp)
                                    }
                                },
                                shape = RoundedCornerShape(10.dp)
                            )
                        }
                    }
                }

                Spacer(modifier = Modifier.height(4.dp))

                // Action Buttons
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.spacedBy(10.dp)
                ) {
                    OutlinedButton(
                        onClick = onDismiss,
                        modifier = Modifier.weight(1f),
                        shape = RoundedCornerShape(14.dp)
                    ) {
                        Text("Cancel", fontSize = 13.sp)
                    }

                    Button(
                        onClick = {
                            val cleanName = categoryName.trim()
                            if (cleanName.isBlank()) {
                                errorMessage = "Please enter a valid category name"
                                return@Button
                            }
                            if (cleanName.length < 2) {
                                errorMessage = "Category name must be at least 2 characters"
                                return@Button
                            }
                            val created = BookMySpaceRepository.addCustomCategory(
                                name = cleanName,
                                parentSectionId = selectedSection,
                                emoji = selectedEmoji
                            )
                            onCategoryCreated(created)
                            onDismiss()
                        },
                        modifier = Modifier
                            .weight(1.5f)
                            .testTag("btn_confirm_add_category"),
                        shape = RoundedCornerShape(14.dp)
                    ) {
                        Icon(
                            imageVector = Icons.Default.Add,
                            contentDescription = null,
                            modifier = Modifier.size(16.dp)
                        )
                        Spacer(modifier = Modifier.width(6.dp))
                        Text("Add Category", fontSize = 13.sp, fontWeight = FontWeight.Bold)
                    }
                }
            }
        }
    }
}
