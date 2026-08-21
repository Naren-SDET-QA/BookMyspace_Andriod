package com.bookmyspace.bookmyspace.ui.theme

import android.app.Activity
import android.os.Build
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.runtime.SideEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.toArgb
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalView
import androidx.core.view.WindowCompat
import com.bookmyspace.bookmyspace.data.repository.BookMySpaceRepository

enum class ThemeMode {
    SYSTEM_DEFAULT,
    LIGHT,
    DARK
}

enum class ThemePreset(
    val id: String,
    val displayName: String,
    val description: String,
    val primary: Color,
    val secondary: Color,
    val previewColors: List<Color>
) {
    ROYAL_PURPLE(
        id = "royal_purple",
        displayName = "Royal Purple & Saffron",
        description = "Signature premium banquet & heritage convention halls",
        primary = Color(0xFF673AB7),
        secondary = Color(0xFFFF6B4A),
        previewColors = listOf(Color(0xFF673AB7), Color(0xFF9575CD), Color(0xFFFF6B4A))
    ),
    ELECTRIC_TEAL(
        id = "electric_teal",
        displayName = "Electric Teal & Mint",
        description = "Modern tech hub workspaces & executive boardrooms",
        primary = Color(0xFF00C9A7),
        secondary = Color(0xFF00A084),
        previewColors = listOf(Color(0xFF00C9A7), Color(0xFF64FFDA), Color(0xFF00796B))
    ),
    SAPPHIRE_NAVY(
        id = "sapphire_navy",
        displayName = "Sapphire Navy & Gold",
        description = "Luxury 5-star hotel resorts & royal lawn venues",
        primary = Color(0xFF1E3A8A),
        secondary = Color(0xFFF59E0B),
        previewColors = listOf(Color(0xFF1E3A8A), Color(0xFF3B82F6), Color(0xFFF59E0B))
    ),
    EMERALD_GREEN(
        id = "emerald_green",
        displayName = "Emerald Forest & Lime",
        description = "Open lawn farmhouses & organic eco-resort stays",
        primary = Color(0xFF059669),
        secondary = Color(0xFF84CC16),
        previewColors = listOf(Color(0xFF059669), Color(0xFF34D399), Color(0xFF84CC16))
    ),
    CRIMSON_RED(
        id = "crimson_red",
        displayName = "Crimson Ruby & Rose",
        description = "Grand Indian wedding mandapams & festive palaces",
        primary = Color(0xFFE11D48),
        secondary = Color(0xFFFB7185),
        previewColors = listOf(Color(0xFFE11D48), Color(0xFFFDA4AF), Color(0xFF9F1239))
    ),
    SUNSET_AMBER(
        id = "sunset_amber",
        displayName = "Sunset Amber & Terracotta",
        description = "Co-living PGs, student hostels & warm budget stays",
        primary = Color(0xFFD97706),
        secondary = Color(0xFFEA580C),
        previewColors = listOf(Color(0xFFD97706), Color(0xFFFBBF24), Color(0xFFEA580C))
    ),
    OCEAN_BLUE(
        id = "ocean_blue",
        displayName = "Ocean Blue & Cyan",
        description = "Coastal beach resorts, cruise decks & sports arenas",
        primary = Color(0xFF0284C7),
        secondary = Color(0xFF06B6D4),
        previewColors = listOf(Color(0xFF0284C7), Color(0xFF38BDF8), Color(0xFF06B6D4))
    ),
    ROSE_GOLD(
        id = "rose_gold",
        displayName = "Rose Gold & Champagne",
        description = "Boutique cocktail lounges & designer studio sets",
        primary = Color(0xFFDB2777),
        secondary = Color(0xFFE2E8F0),
        previewColors = listOf(Color(0xFFDB2777), Color(0xFFF472B6), Color(0xFFFDE047))
    ),
    CYBER_VIOLET(
        id = "cyber_violet",
        displayName = "Cyber Violet & Neon Pink",
        description = "Music festival grounds, gaming lounges & DJ stages",
        primary = Color(0xFF8B5CF6),
        secondary = Color(0xFFEC4899),
        previewColors = listOf(Color(0xFF8B5CF6), Color(0xFFA78BFA), Color(0xFFEC4899))
    ),
    FOREST_MOSS(
        id = "forest_moss",
        displayName = "Deep Forest & Sage",
        description = "Hill-station retreats, yoga shalas & serene spaces",
        primary = Color(0xFF166534),
        secondary = Color(0xFF4ADE80),
        previewColors = listOf(Color(0xFF166534), Color(0xFF22C55E), Color(0xFF86EFAC))
    ),
    NORDIC_SLATE(
        id = "nordic_slate",
        displayName = "Nordic Slate & Platinum",
        description = "Corporate auditoriums & institutional exam halls",
        primary = Color(0xFF475569),
        secondary = Color(0xFF94A3B8),
        previewColors = listOf(Color(0xFF475569), Color(0xFF64748B), Color(0xFFCBD5E1))
    ),
    CORAL_SAFFRON(
        id = "coral_saffron",
        displayName = "Coral Saffron & Marigold",
        description = "Cultural pavilions, theatre stages & food bazaars",
        primary = Color(0xFFFF6B4A),
        secondary = Color(0xFFFFB703),
        previewColors = listOf(Color(0xFFFF6B4A), Color(0xFFFF8E72), Color(0xFFFFB703))
    ),
    CUSTOM(
        id = "custom",
        displayName = "Custom Custom Color Seed",
        description = "Dynamically generated accessible Material 3 palette",
        primary = Color(0xFF00C9A7),
        secondary = Color(0xFF2979FF),
        previewColors = listOf(Color(0xFF00C9A7), Color(0xFF2979FF), Color(0xFFFF6B4A))
    )
}

fun parseHexToColor(hex: String): Color? {
    val clean = hex.trim().removePrefix("#")
    if (clean.length != 6 && clean.length != 8) return null
    return try {
        val parsed = clean.toLong(16)
        if (clean.length == 6) {
            Color(0xFF000000 or parsed)
        } else {
            Color(parsed)
        }
    } catch (_: Exception) {
        null
    }
}

@Composable
fun BookMySpaceTheme(
    content: @Composable () -> Unit
) {
    val themeMode by BookMySpaceRepository.themeMode.collectAsState()
    val selectedPreset by BookMySpaceRepository.selectedThemePreset.collectAsState()
    val customHex by BookMySpaceRepository.customPrimaryColorHex.collectAsState()

    val isDark = when (themeMode) {
        ThemeMode.SYSTEM_DEFAULT -> isSystemInDarkTheme()
        ThemeMode.LIGHT -> false
        ThemeMode.DARK -> true
    }

    val primaryColor = if (selectedPreset == ThemePreset.CUSTOM) {
        parseHexToColor(customHex) ?: selectedPreset.primary
    } else {
        selectedPreset.primary
    }
    val secondaryColor = selectedPreset.secondary

    val colorScheme = if (isDark) {
        darkColorScheme(
            primary = primaryColor,
            onPrimary = Color.White,
            primaryContainer = primaryColor.copy(alpha = 0.3f),
            onPrimaryContainer = Color(0xFFE2E8F0),
            secondary = secondaryColor,
            onSecondary = Color.Black,
            secondaryContainer = secondaryColor.copy(alpha = 0.25f),
            onSecondaryContainer = Color(0xFFF1F5F9),
            tertiary = CoralAttention,
            onTertiary = Color.White,
            background = DeepNavy,
            onBackground = OffWhite,
            surface = NavyBlueCard,
            onSurface = OffWhite,
            surfaceVariant = Color(0xFF1E293B),
            onSurfaceVariant = Color(0xFF94A3B8),
            outline = Color(0xFF475569),
            outlineVariant = Color(0xFF334155),
            error = Color(0xFFEF4444),
            onError = Color.White
        )
    } else {
        lightColorScheme(
            primary = primaryColor,
            onPrimary = Color.White,
            primaryContainer = primaryColor.copy(alpha = 0.12f),
            onPrimaryContainer = primaryColor,
            secondary = secondaryColor,
            onSecondary = Color.White,
            secondaryContainer = secondaryColor.copy(alpha = 0.12f),
            onSecondaryContainer = secondaryColor,
            tertiary = CoralAttention,
            onTertiary = Color.White,
            background = OffWhite,
            onBackground = Color(0xFF0F172A),
            surface = Color.White,
            onSurface = Color(0xFF0F172A),
            surfaceVariant = Color(0xFFF1F5F9),
            onSurfaceVariant = Color(0xFF64748B),
            outline = Color(0xFFCBD5E1),
            outlineVariant = Color(0xFFE2E8F0),
            error = Color(0xFFDC2626),
            onError = Color.White
        )
    }

    val view = LocalView.current
    if (!view.isInEditMode) {
        SideEffect {
            val window = (view.context as? Activity)?.window
            if (window != null) {
                window.statusBarColor = colorScheme.surface.toArgb()
                WindowCompat.getInsetsController(window, view).isAppearanceLightStatusBars = !isDark
            }
        }
    }

    MaterialTheme(
        colorScheme = colorScheme,
        typography = Typography(),
        content = content
    )
}
