package com.bookmyspace.bookmyspace.ui.components

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
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
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.bookmyspace.bookmyspace.data.repository.BookMySpaceRepository
import com.bookmyspace.bookmyspace.ui.theme.ThemeMode
import com.bookmyspace.bookmyspace.ui.theme.ThemePreset
import com.bookmyspace.bookmyspace.ui.theme.parseHexToColor

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ThemeSettingsModal(
    onDismiss: () -> Unit,
    onNavigateToFullThemeCustomizer: () -> Unit = {}
) {
    val themeMode by BookMySpaceRepository.themeMode.collectAsState()
    val selectedPreset by BookMySpaceRepository.selectedThemePreset.collectAsState()
    val customHex by BookMySpaceRepository.customPrimaryColorHex.collectAsState()

    val sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)

    val quickPresets = remember {
        listOf(
            ThemePreset.ROYAL_PURPLE,
            ThemePreset.ELECTRIC_TEAL,
            ThemePreset.SAPPHIRE_NAVY,
            ThemePreset.EMERALD_GREEN,
            ThemePreset.CRIMSON_RED,
            ThemePreset.SUNSET_AMBER,
            ThemePreset.GLASS_3D_CYBER,
            ThemePreset.GLASS_3D_FROSTED
        )
    }

    ModalBottomSheet(
        onDismissRequest = onDismiss,
        sheetState = sheetState,
        containerColor = MaterialTheme.colorScheme.surface,
        shape = RoundedCornerShape(topStart = 28.dp, topEnd = 28.dp),
        dragHandle = { BottomSheetDefaults.DragHandle() },
        modifier = Modifier.testTag("theme_settings_modal")
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 20.dp)
                .padding(bottom = 32.dp),
            verticalArrangement = Arrangement.spacedBy(16.dp)
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
                            .size(38.dp)
                            .clip(CircleShape)
                            .background(MaterialTheme.colorScheme.primaryContainer),
                        contentAlignment = Alignment.Center
                    ) {
                        Icon(
                            imageVector = Icons.Default.Palette,
                            contentDescription = null,
                            tint = MaterialTheme.colorScheme.primary,
                            modifier = Modifier.size(22.dp)
                        )
                    }
                    Spacer(modifier = Modifier.width(12.dp))
                    Column {
                        Text(
                            text = "Appearance & Theme",
                            fontWeight = FontWeight.Bold,
                            fontSize = 18.sp,
                            color = MaterialTheme.colorScheme.onSurface
                        )
                        Text(
                            text = "Instant 60fps high-contrast zero-lag mode switching",
                            fontSize = 11.sp,
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                    }
                }

                IconButton(onClick = onDismiss, modifier = Modifier.size(32.dp)) {
                    Icon(Icons.Default.Close, contentDescription = "Close")
                }
            }

            HorizontalDivider(color = MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.5f))

            // 1. Theme Mode Options (Light, Dark, High-Contrast Glass, System)
            Text(
                text = "DISPLAY MODE",
                fontSize = 11.sp,
                fontWeight = FontWeight.Bold,
                letterSpacing = 0.5.sp,
                color = MaterialTheme.colorScheme.primary
            )

            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(10.dp)
            ) {
                // Light Mode
                ThemeModeOptionCard(
                    title = "Light",
                    icon = Icons.Default.LightMode,
                    isSelected = themeMode == ThemeMode.LIGHT,
                    modifier = Modifier.weight(1f),
                    onClick = { BookMySpaceRepository.setThemeMode(ThemeMode.LIGHT) }
                )

                // Dark Mode
                ThemeModeOptionCard(
                    title = "Dark",
                    icon = Icons.Default.DarkMode,
                    isSelected = themeMode == ThemeMode.DARK,
                    modifier = Modifier.weight(1f),
                    onClick = { BookMySpaceRepository.setThemeMode(ThemeMode.DARK) }
                )

                // High-Contrast Glass Mode
                ThemeModeOptionCard(
                    title = "Glass 3D ✨",
                    icon = Icons.Default.AutoAwesome,
                    isSelected = themeMode == ThemeMode.HIGH_CONTRAST_GLASS,
                    isHighlight = true,
                    modifier = Modifier.weight(1f),
                    onClick = { BookMySpaceRepository.setThemeMode(ThemeMode.HIGH_CONTRAST_GLASS) }
                )

                // System Default
                ThemeModeOptionCard(
                    title = "Auto",
                    icon = Icons.Default.BrightnessAuto,
                    isSelected = themeMode == ThemeMode.SYSTEM_DEFAULT,
                    modifier = Modifier.weight(1f),
                    onClick = { BookMySpaceRepository.setThemeMode(ThemeMode.SYSTEM_DEFAULT) }
                )
            }

            // Glass Mode Feature Callout
            AnimatedVisibility(visible = themeMode == ThemeMode.HIGH_CONTRAST_GLASS) {
                Surface(
                    color = Color(0xFF0F172A),
                    shape = RoundedCornerShape(14.dp),
                    border = BorderStroke(1.5.dp, Color(0xFF38BDF8)),
                    modifier = Modifier.fillMaxWidth()
                ) {
                    Row(
                        modifier = Modifier.padding(12.dp),
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Text("✨", fontSize = 22.sp)
                        Spacer(modifier = Modifier.width(10.dp))
                        Column {
                            Text(
                                text = "High-Contrast Glass UI Mode Active",
                                fontWeight = FontWeight.Bold,
                                fontSize = 12.sp,
                                color = Color(0xFF38BDF8)
                            )
                            Text(
                                text = "Obsidian background, luminous glowing cyan borders, and ultra-high readability without CPU render overhead.",
                                fontSize = 10.sp,
                                color = Color(0xFFCBD5E1)
                            )
                        }
                    }
                }
            }

            // 2. Color Preset Quick Switcher
            Text(
                text = "BRAND PALETTE PRESETS",
                fontSize = 11.sp,
                fontWeight = FontWeight.Bold,
                letterSpacing = 0.5.sp,
                color = MaterialTheme.colorScheme.primary
            )

            LazyRow(
                horizontalArrangement = Arrangement.spacedBy(10.dp),
                modifier = Modifier.fillMaxWidth()
            ) {
                items(quickPresets) { preset ->
                    val isSelected = selectedPreset == preset
                    Surface(
                        modifier = Modifier
                            .width(120.dp)
                            .clip(RoundedCornerShape(14.dp))
                            .clickable { BookMySpaceRepository.setThemePreset(preset) },
                        color = if (isSelected) MaterialTheme.colorScheme.primaryContainer.copy(alpha = 0.4f) else MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.4f),
                        border = BorderStroke(
                            if (isSelected) 2.dp else 1.dp,
                            if (isSelected) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.5f)
                        ),
                        shape = RoundedCornerShape(14.dp)
                    ) {
                        Column(
                            modifier = Modifier.padding(10.dp),
                            horizontalAlignment = Alignment.CenterHorizontally
                        ) {
                            Row(
                                horizontalArrangement = Arrangement.spacedBy(4.dp),
                                modifier = Modifier.padding(vertical = 4.dp)
                            ) {
                                preset.previewColors.take(3).forEach { color ->
                                    Box(
                                        modifier = Modifier
                                            .size(16.dp)
                                            .clip(CircleShape)
                                            .background(color)
                                    )
                                }
                            }
                            Spacer(modifier = Modifier.height(4.dp))
                            Text(
                                text = preset.displayName.split("&").firstOrNull()?.trim() ?: preset.displayName,
                                fontSize = 11.sp,
                                fontWeight = if (isSelected) FontWeight.Bold else FontWeight.Medium,
                                maxLines = 1,
                                textAlign = TextAlign.Center,
                                color = MaterialTheme.colorScheme.onSurface
                            )
                        }
                    }
                }
            }

            // Full Color Engine Customizer Button
            OutlinedButton(
                onClick = {
                    onDismiss()
                    onNavigateToFullThemeCustomizer()
                },
                modifier = Modifier
                    .fillMaxWidth()
                    .height(44.dp)
                    .testTag("open_advanced_theme_customizer_btn"),
                shape = RoundedCornerShape(12.dp)
            ) {
                Icon(Icons.Default.Tune, contentDescription = null, modifier = Modifier.size(16.dp))
                Spacer(modifier = Modifier.width(6.dp))
                Text("Open Full Color Engine & Custom Hex Seed", fontSize = 12.sp, fontWeight = FontWeight.SemiBold)
            }
        }
    }
}

@Composable
private fun ThemeModeOptionCard(
    title: String,
    icon: androidx.compose.ui.graphics.vector.ImageVector,
    isSelected: Boolean,
    modifier: Modifier = Modifier,
    isHighlight: Boolean = false,
    onClick: () -> Unit
) {
    Surface(
        modifier = modifier
            .clip(RoundedCornerShape(12.dp))
            .clickable(onClick = onClick)
            .testTag("theme_mode_card_${title.lowercase()}"),
        color = when {
            isSelected && isHighlight -> Color(0xFF0F172A)
            isSelected -> MaterialTheme.colorScheme.primaryContainer.copy(alpha = 0.5f)
            else -> MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.35f)
        },
        border = BorderStroke(
            if (isSelected) 2.dp else 1.dp,
            when {
                isSelected && isHighlight -> Color(0xFF38BDF8)
                isSelected -> MaterialTheme.colorScheme.primary
                else -> MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.4f)
            }
        ),
        shape = RoundedCornerShape(12.dp)
    ) {
        Column(
            modifier = Modifier.padding(vertical = 12.dp, horizontal = 4.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.Center
        ) {
            Icon(
                imageVector = icon,
                contentDescription = title,
                tint = when {
                    isSelected && isHighlight -> Color(0xFF38BDF8)
                    isSelected -> MaterialTheme.colorScheme.primary
                    else -> MaterialTheme.colorScheme.onSurfaceVariant
                },
                modifier = Modifier.size(20.dp)
            )
            Spacer(modifier = Modifier.height(4.dp))
            Text(
                text = title,
                fontSize = 11.sp,
                fontWeight = if (isSelected) FontWeight.Bold else FontWeight.Medium,
                color = when {
                    isSelected && isHighlight -> Color(0xFF38BDF8)
                    isSelected -> MaterialTheme.colorScheme.primary
                    else -> MaterialTheme.colorScheme.onSurface
                },
                maxLines = 1,
                textAlign = TextAlign.Center
            )
        }
    }
}
