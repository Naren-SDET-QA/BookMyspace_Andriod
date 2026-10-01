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
    DARK,
    HIGH_CONTRAST_GLASS
}

enum class AppBackgroundColor(
    val id: String,
    val displayName: String,
    val subtitle: String,
    val background: Color,
    val surface: Color,
    val surfaceVariant: Color,
    val onBackground: Color,
    val onSurface: Color,
    val isDark: Boolean,
    val accentGlow: Color,
    val previewColors: List<Color>
) {
    MIDNIGHT_SPACE(
        id = "midnight_space",
        displayName = "Midnight Space",
        subtitle = "Deep celestial dark slate",
        background = Color(0xFF090E1A),
        surface = Color(0xFF11192E),
        surfaceVariant = Color(0xFF1B2640),
        onBackground = Color(0xFFF1F5F9),
        onSurface = Color(0xFFF1F5F9),
        isDark = true,
        accentGlow = Color(0xFF38BDF8),
        previewColors = listOf(Color(0xFF090E1A), Color(0xFF11192E), Color(0xFF38BDF8))
    ),
    OBSIDIAN_OLED(
        id = "obsidian_oled",
        displayName = "Obsidian OLED",
        subtitle = "Pure pitch black OLED contrast",
        background = Color(0xFF000000),
        surface = Color(0xFF0D0F14),
        surfaceVariant = Color(0xFF1A1D24),
        onBackground = Color(0xFFFAFAFA),
        onSurface = Color(0xFFFAFAFA),
        isDark = true,
        accentGlow = Color(0xFF8B5CF6),
        previewColors = listOf(Color(0xFF000000), Color(0xFF1A1D24), Color(0xFF8B5CF6))
    ),
    DEEP_NAVY(
        id = "deep_navy",
        displayName = "Deep Navy Abyss",
        subtitle = "Classic BookMySpace night sky",
        background = Color(0xFF081A2B),
        surface = Color(0xFF102A43),
        surfaceVariant = Color(0xFF1C3A5A),
        onBackground = Color(0xFFF8FAFC),
        onSurface = Color(0xFFF8FAFC),
        isDark = true,
        accentGlow = Color(0xFF00C9A7),
        previewColors = listOf(Color(0xFF081A2B), Color(0xFF102A43), Color(0xFF00C9A7))
    ),
    EMERALD_FOREST(
        id = "emerald_forest",
        displayName = "Emerald Turf Dark",
        subtitle = "Lush botanical green for sports & turfs",
        background = Color(0xFF031912),
        surface = Color(0xFF072E22),
        surfaceVariant = Color(0xFF0F4232),
        onBackground = Color(0xFFECFDF5),
        onSurface = Color(0xFFECFDF5),
        isDark = true,
        accentGlow = Color(0xFF10B981),
        previewColors = listOf(Color(0xFF031912), Color(0xFF072E22), Color(0xFF10B981))
    ),
    ROYAL_AMETHYST(
        id = "royal_amethyst",
        displayName = "Royal Amethyst",
        subtitle = "Opulent purple banquet & luxury ambiance",
        background = Color(0xFF120824),
        surface = Color(0xFF22113F),
        surfaceVariant = Color(0xFF331C5C),
        onBackground = Color(0xFFFAF5FF),
        onSurface = Color(0xFFFAF5FF),
        isDark = true,
        accentGlow = Color(0xFFA855F7),
        previewColors = listOf(Color(0xFF120824), Color(0xFF22113F), Color(0xFFA855F7))
    ),
    CRIMSON_EMBER(
        id = "crimson_ember",
        displayName = "Crimson Ember Ruby",
        subtitle = "Warm celebration ruby for grand halls",
        background = Color(0xFF1A070D),
        surface = Color(0xFF2E0F18),
        surfaceVariant = Color(0xFF451925),
        onBackground = Color(0xFFFFF1F2),
        onSurface = Color(0xFFFFF1F2),
        isDark = true,
        accentGlow = Color(0xFFF43F5E),
        previewColors = listOf(Color(0xFF1A070D), Color(0xFF2E0F18), Color(0xFFF43F5E))
    ),
    CYBERPUNK_3D(
        id = "cyberpunk_3d",
        displayName = "Cyberpunk 3D Neon",
        subtitle = "Crystalline cyber glass with glowing cyan edges",
        background = Color(0xFF040714),
        surface = Color(0xFF0B1429),
        surfaceVariant = Color(0xFF152445),
        onBackground = Color(0xFFE0F2FE),
        onSurface = Color(0xFFE0F2FE),
        isDark = true,
        accentGlow = Color(0xFF00F0FF),
        previewColors = listOf(Color(0xFF040714), Color(0xFF0B1429), Color(0xFF00F0FF))
    ),
    TITANIUM_SLATE(
        id = "titanium_slate",
        displayName = "Titanium Slate",
        subtitle = "Corporate neutral dark with sleek grey metal",
        background = Color(0xFF181F2A),
        surface = Color(0xFF242E3D),
        surfaceVariant = Color(0xFF323F52),
        onBackground = Color(0xFFF1F5F9),
        onSurface = Color(0xFFF1F5F9),
        isDark = true,
        accentGlow = Color(0xFF94A3B8),
        previewColors = listOf(Color(0xFF181F2A), Color(0xFF242E3D), Color(0xFF94A3B8))
    ),
    DAYLIGHT_WHITE(
        id = "daylight_white",
        displayName = "Pure Daylight White",
        subtitle = "Crisp, airy high-clarity minimalist day layout",
        background = Color(0xFFF8FAFC),
        surface = Color(0xFFFFFFFF),
        surfaceVariant = Color(0xFFF1F5F9),
        onBackground = Color(0xFF0F172A),
        onSurface = Color(0xFF0F172A),
        isDark = false,
        accentGlow = Color(0xFF673AB7),
        previewColors = listOf(Color(0xFFF8FAFC), Color(0xFFFFFFFF), Color(0xFF673AB7))
    ),
    WARM_PEARL_SAND(
        id = "warm_pearl_sand",
        displayName = "Warm Pearl Cream",
        subtitle = "Cozy editorial resort aesthetic with soft tint",
        background = Color(0xFFFAF7F2),
        surface = Color(0xFFFFFFFF),
        surfaceVariant = Color(0xFFF4ECE1),
        onBackground = Color(0xFF1C1917),
        onSurface = Color(0xFF1C1917),
        isDark = false,
        accentGlow = Color(0xFFD97706),
        previewColors = listOf(Color(0xFFFAF7F2), Color(0xFFF4ECE1), Color(0xFFD97706))
    ),
    MINT_BREEZE(
        id = "mint_breeze",
        displayName = "Mint Breeze Light",
        subtitle = "Refreshing subtle light sage and mint",
        background = Color(0xFFF0FDF4),
        surface = Color(0xFFFFFFFF),
        surfaceVariant = Color(0xFFDCFCE7),
        onBackground = Color(0xFF064E3B),
        onSurface = Color(0xFF064E3B),
        isDark = false,
        accentGlow = Color(0xFF059669),
        previewColors = listOf(Color(0xFFF0FDF4), Color(0xFFFFFFFF), Color(0xFF059669))
    ),
    LILAC_MIST(
        id = "lilac_mist",
        displayName = "Soft Lilac Mist",
        subtitle = "Gentle soft lilac and lavender daylight",
        background = Color(0xFFFAF5FF),
        surface = Color(0xFFFFFFFF),
        surfaceVariant = Color(0xFFF3E8FF),
        onBackground = Color(0xFF3B0764),
        onSurface = Color(0xFF3B0764),
        isDark = false,
        accentGlow = Color(0xFF9333EA),
        previewColors = listOf(Color(0xFFFAF5FF), Color(0xFFFFFFFF), Color(0xFF9333EA))
    )
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
    GLASS_3D_CYBER(
        id = "glass_3d_cyber",
        displayName = "3D Glassmorphic Neon",
        description = "Futuristic crystalline glass styling with glowing cyan & prism borders",
        primary = Color(0xFF00E5FF),
        secondary = Color(0xFF7C4DFF),
        previewColors = listOf(Color(0xFF00E5FF), Color(0xFF7C4DFF), Color(0xFFFF4081))
    ),
    GLASS_3D_FROSTED(
        id = "glass_3d_frosted",
        displayName = "Frosted 3D Pearl Glass",
        description = "Modern translucent pearl glass with subtle depth rim lighting",
        primary = Color(0xFF0D9488),
        secondary = Color(0xFF6366F1),
        previewColors = listOf(Color(0xFF0D9488), Color(0xFF38BDF8), Color(0xFF6366F1))
    ),
    GLASS_3D_AMETHYST(
        id = "glass_3d_amethyst",
        displayName = "3D Glass Amethyst & Prism",
        description = "Deep translucent crystal surfaces with violet reflection highlights",
        primary = Color(0xFF9333EA),
        secondary = Color(0xFFEC4899),
        previewColors = listOf(Color(0xFF9333EA), Color(0xFFC084FC), Color(0xFFEC4899))
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
    val selectedBg by BookMySpaceRepository.selectedBackgroundColor.collectAsState()

    val isDark = when (themeMode) {
        ThemeMode.SYSTEM_DEFAULT -> if (selectedBg.isDark) true else isSystemInDarkTheme()
        ThemeMode.LIGHT -> false
        ThemeMode.DARK, ThemeMode.HIGH_CONTRAST_GLASS -> true
    }

    val primaryColor = if (selectedPreset == ThemePreset.CUSTOM) {
        parseHexToColor(customHex) ?: selectedPreset.primary
    } else {
        selectedPreset.primary
    }
    val secondaryColor = selectedPreset.secondary

    val colorScheme = when {
        themeMode == ThemeMode.HIGH_CONTRAST_GLASS -> {
            darkColorScheme(
                primary = primaryColor,
                onPrimary = Color.Black,
                primaryContainer = primaryColor.copy(alpha = 0.35f),
                onPrimaryContainer = Color(0xFFE0F7FA),
                secondary = Color(0xFFF59E0B),
                onSecondary = Color.Black,
                secondaryContainer = Color(0xFFF59E0B).copy(alpha = 0.3f),
                onSecondaryContainer = Color(0xFFFFFBEB),
                tertiary = Color(0xFFFF4081),
                onTertiary = Color.White,
                background = selectedBg.background,
                onBackground = selectedBg.onBackground,
                surface = selectedBg.surface,
                onSurface = selectedBg.onSurface,
                surfaceVariant = selectedBg.surfaceVariant,
                onSurfaceVariant = Color(0xFFCBD5E1),
                outline = Color(0xFF38BDF8),
                outlineVariant = Color(0xFF475569),
                error = Color(0xFFFF5252),
                onError = Color.Black
            )
        }
        isDark -> {
            val bgPalette = if (selectedBg.isDark) selectedBg else AppBackgroundColor.DEEP_NAVY
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
                background = bgPalette.background,
                onBackground = bgPalette.onBackground,
                surface = bgPalette.surface,
                onSurface = bgPalette.onSurface,
                surfaceVariant = bgPalette.surfaceVariant,
                onSurfaceVariant = Color(0xFF94A3B8),
                outline = Color(0xFF475569),
                outlineVariant = Color(0xFF334155),
                error = Color(0xFFEF4444),
                onError = Color.White
            )
        }
        else -> {
            val bgPalette = if (!selectedBg.isDark) selectedBg else AppBackgroundColor.DAYLIGHT_WHITE
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
                background = bgPalette.background,
                onBackground = bgPalette.onBackground,
                surface = bgPalette.surface,
                onSurface = bgPalette.onSurface,
                surfaceVariant = bgPalette.surfaceVariant,
                onSurfaceVariant = Color(0xFF64748B),
                outline = Color(0xFFCBD5E1),
                outlineVariant = Color(0xFFE2E8F0),
                error = Color(0xFFDC2626),
                onError = Color.White
            )
        }
    }

    val view = LocalView.current
    if (!view.isInEditMode) {
        SideEffect {
            val window = (view.context as? Activity)?.window
            if (window != null) {
                window.statusBarColor = colorScheme.background.toArgb()
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
