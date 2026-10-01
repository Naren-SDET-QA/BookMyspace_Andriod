package com.bookmyspace.bookmyspace.ui.components

import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.animateColorAsState
import androidx.compose.animation.core.*
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.togetherWith
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.interaction.collectIsHoveredAsState
import androidx.compose.foundation.interaction.collectIsPressedAsState
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowForward
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.draw.scale
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import coil.compose.AsyncImage
import com.bookmyspace.bookmyspace.data.model.Venue
import com.bookmyspace.bookmyspace.data.repository.BookMySpaceRepository
import com.bookmyspace.bookmyspace.data.repository.HomeCategoryDiscoveryStyle
import com.bookmyspace.bookmyspace.ui.screens.MainHomeSection
import com.bookmyspace.bookmyspace.ui.screens.SubSectionItemModel
import com.bookmyspace.bookmyspace.ui.screens.getCategoryVisualTheme

/**
 * Interactive 3D Glass Matrix Category Discovery Component.
 * Features:
 * - Central Selected Master Category Card with 3D Depth & Rim Lighting
 * - Surrounding Sub-Section Cards in a 3D Perspective Matrix / Orbit Layout
 * - Category-specific accent glows, floating icons, and translucent glassmorphism
 * - Real venue counts directly from data (honest representation without fake counts)
 * - 1-tap navigation to Search / Venue route
 * - Smooth spring transitions & hardware-accelerated 3D tilt interaction
 * - Admin Style Switcher (Style 1: 3D Matrix, Style 2: Tactile Grid, Style 3: Compact Carousel)
 */
@Composable
fun CategoryDiscovery3DGlassMatrix(
    sections: List<MainHomeSection>,
    selectedSection: MainHomeSection?,
    onSectionSelected: (MainHomeSection?) -> Unit,
    venues: List<Venue>,
    onSubSectionClick: (slug: String) -> Unit,
    onViewAllClick: (MainHomeSection) -> Unit,
    onCustomCategoryClick: (() -> Unit)? = null,
    modifier: Modifier = Modifier
) {
    val isDark = isSystemInDarkTheme()
    val resolvedSections = remember(sections) {
        if (sections.size >= 5) sections else MainHomeSection.values().toList()
    }
    val visualTheme = remember(selectedSection) { getCategoryVisualTheme(selectedSection) }
    val currentStyle by BookMySpaceRepository.homeCategoryDiscoveryStyle.collectAsState()

    Column(
        modifier = modifier
            .fillMaxWidth()
            .padding(vertical = 12.dp)
            .testTag("category_discovery_3d_glass_matrix")
    ) {
        // --- 1. Hero Copy & Header Bar ---
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 16.dp),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.Top
        ) {
            Column(modifier = Modifier.weight(1f)) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Box(
                        modifier = Modifier
                            .size(8.dp)
                            .clip(CircleShape)
                            .background(visualTheme.primaryColor)
                    )
                    Spacer(modifier = Modifier.width(6.dp))
                    Text(
                        text = if (selectedSection == null) "ALL MASTER CATEGORIES & MATRIX" else "EXPLORE VERIFIED SPACES",
                        style = MaterialTheme.typography.labelSmall.copy(
                            fontWeight = FontWeight.Black,
                            letterSpacing = 1.2.sp
                        ),
                        color = visualTheme.primaryColor
                    )
                }
                Spacer(modifier = Modifier.height(4.dp))
                Text(
                    text = if (selectedSection == null) {
                        "All 6 master categories • 36+ verified sub-sections • Interactive 3D depth"
                    } else {
                        "${selectedSection.title} • Instant sub-section discovery • Live availability"
                    },
                    style = MaterialTheme.typography.bodySmall.copy(
                        fontWeight = FontWeight.Medium,
                        lineHeight = 16.sp
                    ),
                    color = MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.85f),
                    maxLines = 2,
                    overflow = TextOverflow.Ellipsis
                )
            }

            // Quick Admin UI Style Switcher Pill
            AdminUiStyleSwitcherPill(
                currentStyle = currentStyle,
                onStyleChange = { style ->
                    BookMySpaceRepository.setHomeCategoryDiscoveryStyle(style)
                },
                accentColor = visualTheme.primaryColor,
                isDark = isDark
            )
        }

        Spacer(modifier = Modifier.height(14.dp))

        // --- 2. Master Categories Selector Strip (Includes 'All Categories' & All 6 Main Categories) ---
        MasterCategoriesHorizontalBar(
            sections = resolvedSections,
            selectedSection = selectedSection,
            onSectionSelected = onSectionSelected,
            isDark = isDark
        )

        Spacer(modifier = Modifier.height(16.dp))

        // --- 3. Dynamic Animated Content (Smooth Transition on Category Switch) ---
        AnimatedContent(
            targetState = selectedSection,
            transitionSpec = {
                (fadeIn(animationSpec = spring(stiffness = Spring.StiffnessMediumLow)) +
                        androidx.compose.animation.scaleIn(initialScale = 0.95f)) togetherWith
                        (fadeOut(animationSpec = spring(stiffness = Spring.StiffnessMediumLow)) +
                                androidx.compose.animation.scaleOut(targetScale = 0.95f))
            },
            label = "Section3DMatrixTransition"
        ) { currentSection ->
            if (currentSection == null) {
                // UNIFIED MATRIX VIEW: Shows All Main Categories and All Subsections
                Column(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(horizontal = 16.dp)
                ) {
                    AllCategoriesUnified3DHeroCard(
                        sections = resolvedSections,
                        totalVenuesCount = venues.size,
                        isDark = isDark,
                        onViewCategory = { onSectionSelected(it) }
                    )

                    Spacer(modifier = Modifier.height(18.dp))

                    if (currentStyle == HomeCategoryDiscoveryStyle.STYLE_3_COMPACT_CAROUSEL) {
                        AllCategoriesCompactCarouselLayout(
                            sections = resolvedSections,
                            venues = venues,
                            isDark = isDark,
                            onSubSectionClick = onSubSectionClick,
                            onCustomCategoryClick = onCustomCategoryClick
                        )
                    } else {
                        AllCategoriesUnified3DMatrixLayout(
                            sections = resolvedSections,
                            venues = venues,
                            isDark = isDark,
                            onSubSectionClick = onSubSectionClick,
                            onViewCategoryClick = { onSectionSelected(it) },
                            onCustomCategoryClick = onCustomCategoryClick
                        )
                    }
                }
            } else {
                // SINGLE CATEGORY 3D MATRIX VIEW
                val theme = remember(currentSection) { getCategoryVisualTheme(currentSection) }
                val realCountForCategory = remember(currentSection, venues) {
                    venues.count { v ->
                        when (currentSection) {
                            MainHomeSection.FUNCTION_HALLS -> v.capacity >= 100 || v.category?.slug in listOf(
                                "marriage_hall", "banquet_hall", "convention_center", "party_lawn",
                                "engagement_hall", "reception_hall", "luxury_hall", "outdoor_garden", "community_hall"
                            )
                            MainHomeSection.LODGE_ROOMS -> v.hotelDetails != null || v.category?.slug in listOf(
                                "hotel", "lodge", "guest_house", "hourly_room", "resort", "other_stay"
                            )
                            MainHomeSection.PG_HOSTELS -> v.pgDetails != null || v.category?.slug in listOf(
                                "gents_pg", "ladies_pg", "student_hostel", "co_living", "single_room"
                            )
                            MainHomeSection.INSTITUTES_CLASSES -> v.category?.slug in listOf(
                                "coaching", "computer_it", "dance_academy", "music_class", "sports_academy"
                            )
                            MainHomeSection.SPORTS_TURFS -> v.category?.slug in listOf(
                                "sports", "sports_turf", "badminton", "gym", "swimming_pool", "coworking"
                            )
                            MainHomeSection.OTHER_ADD -> v.category?.slug in listOf("other", "photography_studio", "exhibition_ground")
                        }
                    }
                }

                Column(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(horizontal = 16.dp)
                ) {
                    // Central Selected Category Hero Card with 3D Depth
                    Central3DGlassHeroCard(
                        section = currentSection,
                        realCount = realCountForCategory,
                        theme = theme,
                        isDark = isDark,
                        onViewAllClick = { onViewAllClick(currentSection) }
                    )

                    Spacer(modifier = Modifier.height(16.dp))

                    if (currentStyle == HomeCategoryDiscoveryStyle.STYLE_3_COMPACT_CAROUSEL) {
                        SubSectionsCompactCarouselLayout(
                            section = currentSection,
                            subSections = currentSection.subSections,
                            venues = venues,
                            theme = theme,
                            isDark = isDark,
                            onSubSectionClick = onSubSectionClick,
                            onCustomCategoryClick = onCustomCategoryClick
                        )
                    } else {
                        // Sub-sections 3D Glass Matrix
                        SubSections3DGlassMatrixLayout(
                            section = currentSection,
                            subSections = currentSection.subSections,
                            venues = venues,
                            theme = theme,
                            isDark = isDark,
                            onSubSectionClick = onSubSectionClick,
                            onCustomCategoryClick = onCustomCategoryClick
                        )
                    }
                }
            }
        }
    }
}

/**
 * Sub-Sections Compact Glass Carousel Layout (Style 3):
 * Horizontally scrolling glass carousel with 1-tap filters.
 */
@Composable
private fun SubSectionsCompactCarouselLayout(
    section: MainHomeSection,
    subSections: List<SubSectionItemModel>,
    venues: List<Venue>,
    theme: com.bookmyspace.bookmyspace.ui.screens.CategoryVisualTheme,
    isDark: Boolean,
    onSubSectionClick: (slug: String) -> Unit,
    onCustomCategoryClick: (() -> Unit)? = null
) {
    Column(
        modifier = Modifier.fillMaxWidth(),
        verticalArrangement = Arrangement.spacedBy(10.dp)
    ) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically
        ) {
            Text(
                text = "${section.title} Carousel",
                style = MaterialTheme.typography.titleMedium.copy(fontWeight = FontWeight.Bold),
                color = MaterialTheme.colorScheme.onSurface
            )
            Text(
                text = "Swipe to explore →",
                style = MaterialTheme.typography.labelSmall.copy(fontWeight = FontWeight.Medium),
                color = theme.primaryColor
            )
        }

        LazyRow(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(12.dp),
            contentPadding = PaddingValues(end = 16.dp)
        ) {
            items(subSections, key = { it.slug }) { item ->
                val realCount = remember(item.slug, venues) {
                    venues.count { v ->
                        v.category?.slug.equals(item.slug, ignoreCase = true) ||
                                (v.category?.name?.contains(item.label, ignoreCase = true) == true)
                    }
                }

                Box(modifier = Modifier.width(165.dp)) {
                    SubSection3DGlassCard(
                        item = item,
                        realCount = realCount,
                        tiltDegrees = 0f,
                        theme = theme,
                        isDark = isDark,
                        onClick = {
                            if (item.slug == "custom_category" || item.slug == "add_space") {
                                onCustomCategoryClick?.invoke() ?: onSubSectionClick(item.slug)
                            } else {
                                onSubSectionClick(item.slug)
                            }
                        }
                    )
                }
            }
        }
    }
}

/**
 * Master Categories Top Strip:
 * High-performance horizontal glass pills with spring scale, category emojis & accent glows.
 * Includes "All Categories" pill as well as all 6 main categories.
 */
@Composable
private fun MasterCategoriesHorizontalBar(
    sections: List<MainHomeSection>,
    selectedSection: MainHomeSection?,
    onSectionSelected: (MainHomeSection?) -> Unit,
    isDark: Boolean
) {
    val scrollState = rememberScrollState()

    Row(
        modifier = Modifier
            .fillMaxWidth()
            .horizontalScroll(scrollState)
            .padding(horizontal = 16.dp),
        horizontalArrangement = Arrangement.spacedBy(10.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        // Tab 1: All Categories Pill (🌟 All Categories & Subsections)
        val isAllSelected = selectedSection == null
        val allTheme = remember { getCategoryVisualTheme(null) }
        val allInteractionSource = remember { MutableInteractionSource() }
        val isAllHovered by allInteractionSource.collectIsHoveredAsState()
        val isAllPressed by allInteractionSource.collectIsPressedAsState()

        val allScale by animateFloatAsState(
            targetValue = if (isAllPressed) 0.94f else if (isAllSelected || isAllHovered) 1.04f else 1.0f,
            animationSpec = spring(dampingRatio = Spring.DampingRatioMediumBouncy, stiffness = Spring.StiffnessLow),
            label = "allCatScale"
        )

        val allContainerColor = if (isAllSelected) {
            if (isDark) allTheme.primaryColor.copy(alpha = 0.28f) else allTheme.primaryColor.copy(alpha = 0.12f)
        } else {
            if (isDark) Color(0xFF1E293B).copy(alpha = 0.65f) else Color.White.copy(alpha = 0.85f)
        }

        val allBorderColor = if (isAllSelected) {
            allTheme.primaryColor
        } else {
            if (isDark) Color.White.copy(alpha = 0.12f) else Color.Black.copy(alpha = 0.08f)
        }

        Surface(
            onClick = { onSectionSelected(null) },
            shape = RoundedCornerShape(16.dp),
            color = allContainerColor,
            border = BorderStroke(if (isAllSelected) 2.dp else 1.dp, allBorderColor),
            shadowElevation = if (isAllSelected) 8.dp else 2.dp,
            interactionSource = allInteractionSource,
            modifier = Modifier
                .graphicsLayer {
                    scaleX = allScale
                    scaleY = allScale
                }
                .testTag("master_cat_tab_all")
        ) {
            Row(
                modifier = Modifier.padding(horizontal = 14.dp, vertical = 10.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                Text(
                    text = "🌟",
                    fontSize = 18.sp,
                    modifier = Modifier.padding(end = 6.dp)
                )
                Text(
                    text = "All Categories",
                    style = MaterialTheme.typography.labelLarge.copy(
                        fontWeight = if (isAllSelected) FontWeight.Bold else FontWeight.Medium
                    ),
                    color = if (isAllSelected) {
                        if (isDark) Color.White else allTheme.primaryColor
                    } else {
                        MaterialTheme.colorScheme.onSurface
                    }
                )
                if (isAllSelected) {
                    Spacer(modifier = Modifier.width(6.dp))
                    Box(
                        modifier = Modifier
                            .size(6.dp)
                            .clip(CircleShape)
                            .background(allTheme.primaryColor)
                    )
                }
            }
        }

        // Individual Master Category Pills
        sections.forEach { section ->
            val isSelected = section == selectedSection
            val sectionTheme = remember(section) { getCategoryVisualTheme(section) }
            val interactionSource = remember { MutableInteractionSource() }
            val isHovered by interactionSource.collectIsHoveredAsState()
            val isPressed by interactionSource.collectIsPressedAsState()

            val scale by animateFloatAsState(
                targetValue = if (isPressed) 0.94f else if (isSelected || isHovered) 1.04f else 1.0f,
                animationSpec = spring(dampingRatio = Spring.DampingRatioMediumBouncy, stiffness = Spring.StiffnessLow),
                label = "masterCatScale"
            )

            val containerColor = if (isSelected) {
                if (isDark) sectionTheme.primaryColor.copy(alpha = 0.28f) else sectionTheme.primaryColor.copy(alpha = 0.12f)
            } else {
                if (isDark) Color(0xFF1E293B).copy(alpha = 0.65f) else Color.White.copy(alpha = 0.85f)
            }

            val borderColor = if (isSelected) {
                sectionTheme.primaryColor
            } else {
                if (isDark) Color.White.copy(alpha = 0.12f) else Color.Black.copy(alpha = 0.08f)
            }

            Surface(
                onClick = { onSectionSelected(section) },
                shape = RoundedCornerShape(16.dp),
                color = containerColor,
                border = BorderStroke(if (isSelected) 2.dp else 1.dp, borderColor),
                shadowElevation = if (isSelected) 8.dp else 2.dp,
                interactionSource = interactionSource,
                modifier = Modifier
                    .graphicsLayer {
                        scaleX = scale
                        scaleY = scale
                    }
                    .testTag("master_cat_tab_${section.id}")
            ) {
                Row(
                    modifier = Modifier.padding(horizontal = 14.dp, vertical = 10.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Text(
                        text = section.emoji,
                        fontSize = 18.sp,
                        modifier = Modifier.padding(end = 6.dp)
                    )
                    Text(
                        text = section.title,
                        style = MaterialTheme.typography.labelLarge.copy(
                            fontWeight = if (isSelected) FontWeight.Bold else FontWeight.Medium
                        ),
                        color = if (isSelected) {
                            if (isDark) Color.White else sectionTheme.primaryColor
                        } else {
                            MaterialTheme.colorScheme.onSurface
                        }
                    )
                    if (isSelected) {
                        Spacer(modifier = Modifier.width(6.dp))
                        Box(
                            modifier = Modifier
                                .size(6.dp)
                                .clip(CircleShape)
                                .background(sectionTheme.primaryColor)
                        )
                    }
                }
            }
        }
    }
}

/**
 * All Categories Unified 3D Glass Hero Card:
 * Displays aggregate space counts, quick jump chips to all 6 categories,
 * and high-fidelity 3D tilt perspective.
 */
@Composable
private fun AllCategoriesUnified3DHeroCard(
    sections: List<MainHomeSection>,
    totalVenuesCount: Int,
    isDark: Boolean,
    onViewCategory: (MainHomeSection) -> Unit
) {
    val allTheme = remember { getCategoryVisualTheme(null) }
    TransformGestureGlassCard(
        modifier = Modifier
            .fillMaxWidth()
            .testTag("all_categories_unified_hero"),
        maxTiltDegrees = 6.5f,
        perspectiveFactor = 0.0016f,
        shape = RoundedCornerShape(22.dp),
        isDark = isDark,
        ambientGlowColor = allTheme.glowColor,
        spotGlowColor = allTheme.primaryColor
    ) { matrix, isHovered, isPressed, currentTiltX, currentTiltY ->
        val cardBgGradient = if (isDark) {
            Brush.linearGradient(
                colors = listOf(
                    Color(0xFF042F2E).copy(alpha = 0.90f),
                    Color(0xFF083344).copy(alpha = 0.94f),
                    Color(0xFF0F172A).copy(alpha = 0.98f)
                ),
                start = Offset(0f, 0f),
                end = Offset(800f, 600f)
            )
        } else {
            Brush.linearGradient(
                colors = listOf(
                    Color.White.copy(alpha = 0.95f),
                    Color(0xFFCCFBF1).copy(alpha = 0.50f),
                    Color.White.copy(alpha = 0.90f)
                ),
                start = Offset(0f, 0f),
                end = Offset(800f, 600f)
            )
        }

        Box(
            modifier = Modifier
                .fillMaxWidth()
                .clip(RoundedCornerShape(22.dp))
                .background(cardBgGradient)
                .drawBehind {
                    drawRoundRect(
                        brush = Brush.sweepGradient(
                            listOf(
                                Color(0xFF0D9488).copy(alpha = 0.90f),
                                Color(0xFF06B6D4).copy(alpha = 0.85f),
                                Color(0xFFF59E0B).copy(alpha = 0.75f),
                                Color(0xFF8B5CF6).copy(alpha = 0.70f),
                                Color.White.copy(alpha = 0.80f),
                                Color(0xFF0D9488).copy(alpha = 0.90f)
                            )
                        ),
                        cornerRadius = androidx.compose.ui.geometry.CornerRadius(22.dp.toPx())
                    )
                }
                .padding(1.5.dp)
                .clip(RoundedCornerShape(20.5.dp))
                .background(cardBgGradient)
                .padding(18.dp)
        ) {
            Column {
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Surface(
                        shape = RoundedCornerShape(100.dp),
                        color = allTheme.primaryColor.copy(alpha = 0.16f),
                        border = BorderStroke(1.dp, allTheme.primaryColor.copy(alpha = 0.4f))
                    ) {
                        Row(
                            modifier = Modifier.padding(horizontal = 10.dp, vertical = 4.dp),
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            Text("✦", fontSize = 11.sp, color = allTheme.primaryColor)
                            Spacer(modifier = Modifier.width(4.dp))
                            Text(
                                "ALL MASTER CATEGORIES",
                                fontSize = 11.sp,
                                fontWeight = FontWeight.Bold,
                                color = allTheme.primaryColor
                            )
                        }
                    }

                    Surface(
                        shape = RoundedCornerShape(100.dp),
                        color = Color(0xFF10B981).copy(alpha = 0.15f),
                        border = BorderStroke(1.dp, Color(0xFF10B981).copy(alpha = 0.5f))
                    ) {
                        Row(
                            modifier = Modifier.padding(horizontal = 8.dp, vertical = 3.dp),
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            Box(
                                modifier = Modifier
                                    .size(6.dp)
                                    .clip(CircleShape)
                                    .background(Color(0xFF10B981))
                            )
                            Spacer(modifier = Modifier.width(5.dp))
                            Text(
                                "$totalVenuesCount Verified Spaces",
                                fontSize = 11.sp,
                                fontWeight = FontWeight.SemiBold,
                                color = if (isDark) Color(0xFF6EE7B7) else Color(0xFF047857)
                            )
                        }
                    }
                }

                Spacer(modifier = Modifier.height(10.dp))

                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    modifier = Modifier.graphicsLayer {
                        translationX = -currentTiltY * 0.5f
                        translationY = -currentTiltX * 0.5f
                    }
                ) {
                    Box(
                        modifier = Modifier
                            .size(46.dp)
                            .clip(RoundedCornerShape(14.dp))
                            .background(
                                Brush.radialGradient(
                                    listOf(
                                        Color(0xFF0D9488).copy(alpha = 0.35f),
                                        Color(0xFF06B6D4).copy(alpha = 0.15f)
                                    )
                                )
                            ),
                        contentAlignment = Alignment.Center
                    ) {
                        Text("🌟", fontSize = 24.sp)
                    }
                    Spacer(modifier = Modifier.width(12.dp))
                    Column {
                        Text(
                            text = "All Categories 3D Matrix",
                            style = MaterialTheme.typography.titleLarge.copy(
                                fontWeight = FontWeight.ExtraBold,
                                letterSpacing = (-0.3).sp
                            ),
                            color = MaterialTheme.colorScheme.onSurface
                        )
                        Text(
                            text = "${sections.size} Master Categories • ${sections.sumOf { it.subSections.size }} Sub-Sections",
                            style = MaterialTheme.typography.labelMedium,
                            color = allTheme.primaryColor
                        )
                    }
                }

                Spacer(modifier = Modifier.height(8.dp))

                Text(
                    text = "Seamlessly discover celebration venues, sports turfs, hostels, coaching academies, lodges and unique creative spaces in a unified 3D perspective matrix.",
                    style = MaterialTheme.typography.bodyMedium.copy(lineHeight = 20.sp),
                    color = MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.9f)
                )

                Spacer(modifier = Modifier.height(12.dp))

                // Fast Jump Chips for all Master Categories
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .horizontalScroll(rememberScrollState()),
                    horizontalArrangement = Arrangement.spacedBy(8.dp)
                ) {
                    sections.forEach { sec ->
                        val secTheme = remember(sec) { getCategoryVisualTheme(sec) }
                        Surface(
                            onClick = { onViewCategory(sec) },
                            shape = RoundedCornerShape(12.dp),
                            color = if (isDark) secTheme.primaryColor.copy(alpha = 0.20f) else secTheme.badgeBgColor.copy(alpha = 0.8f),
                            border = BorderStroke(1.dp, secTheme.primaryColor.copy(alpha = 0.40f))
                        ) {
                            Row(
                                modifier = Modifier.padding(horizontal = 10.dp, vertical = 6.dp),
                                verticalAlignment = Alignment.CenterVertically
                            ) {
                                Text(sec.emoji, fontSize = 14.sp)
                                Spacer(modifier = Modifier.width(6.dp))
                                Text(
                                    sec.title.substringBefore(" &").substringBefore(" /"),
                                    style = MaterialTheme.typography.labelMedium.copy(fontWeight = FontWeight.Bold),
                                    color = if (isDark) Color.White else secTheme.primaryColor
                                )
                                Spacer(modifier = Modifier.width(4.dp))
                                Text(
                                    "(${sec.subSections.size})",
                                    style = MaterialTheme.typography.labelSmall,
                                    color = secTheme.primaryColor.copy(alpha = 0.8f)
                                )
                            }
                        }
                    }

                    // Anti-Hang Quick Self-Heal Pill
                    val isSafeMode by com.bookmyspace.bookmyspace.data.healing.AppHangSelfHealingWatchdog.isSafePerformanceMode.collectAsState()
                    Surface(
                        onClick = {
                            if (isSafeMode) {
                                com.bookmyspace.bookmyspace.data.healing.AppHangSelfHealingWatchdog.setSafePerformanceMode(false)
                            } else {
                                com.bookmyspace.bookmyspace.data.healing.AppHangSelfHealingWatchdog.triggerEmergencySelfHeal("User tapped self-heal on 3D Matrix")
                            }
                        },
                        shape = RoundedCornerShape(12.dp),
                        color = if (isSafeMode) Color(0xFF047857).copy(alpha = 0.25f) else allTheme.primaryColor.copy(alpha = 0.12f),
                        border = BorderStroke(1.dp, if (isSafeMode) Color(0xFF10B981) else allTheme.primaryColor.copy(alpha = 0.35f))
                    ) {
                        Row(
                            modifier = Modifier.padding(horizontal = 10.dp, vertical = 6.dp),
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            Text(if (isSafeMode) "🛡️" else "⚡", fontSize = 13.sp)
                            Spacer(modifier = Modifier.width(5.dp))
                            Text(
                                if (isSafeMode) "Safe 60fps Active" else "Anti-Hang Heal",
                                style = MaterialTheme.typography.labelMedium.copy(fontWeight = FontWeight.Bold),
                                color = if (isSafeMode) Color(0xFF10B981) else allTheme.primaryColor
                            )
                        }
                    }
                }
            }
        }
    }
}

/**
 * All Categories Unified 3D Matrix Layout:
 * Groups each master category and displays all its sub-sections in 3D perspective cards.
 */
@Composable
private fun AllCategoriesUnified3DMatrixLayout(
    sections: List<MainHomeSection>,
    venues: List<Venue>,
    isDark: Boolean,
    onSubSectionClick: (slug: String) -> Unit,
    onViewCategoryClick: (MainHomeSection) -> Unit,
    onCustomCategoryClick: (() -> Unit)? = null
) {
    Column(
        modifier = Modifier.fillMaxWidth(),
        verticalArrangement = Arrangement.spacedBy(22.dp)
    ) {
        sections.forEach { section ->
            val theme = remember(section) { getCategoryVisualTheme(section) }
            val countForCategory = remember(section, venues) {
                venues.count { v ->
                    when (section) {
                        MainHomeSection.FUNCTION_HALLS -> v.capacity >= 100 || v.category?.slug in listOf(
                            "marriage_hall", "banquet_hall", "convention_center", "party_lawn",
                            "engagement_hall", "reception_hall", "luxury_hall", "outdoor_garden", "community_hall"
                        )
                        MainHomeSection.LODGE_ROOMS -> v.hotelDetails != null || v.category?.slug in listOf(
                            "hotel", "lodge", "guest_house", "hourly_room", "resort", "other_stay"
                        )
                        MainHomeSection.PG_HOSTELS -> v.pgDetails != null || v.category?.slug in listOf(
                            "gents_pg", "ladies_pg", "student_hostel", "co_living", "single_room"
                        )
                        MainHomeSection.INSTITUTES_CLASSES -> v.category?.slug in listOf(
                            "coaching", "computer_it", "dance_academy", "music_class", "sports_academy"
                        )
                        MainHomeSection.SPORTS_TURFS -> v.category?.slug in listOf(
                            "sports", "sports_turf", "badminton", "gym", "swimming_pool", "coworking"
                        )
                        MainHomeSection.OTHER_ADD -> v.category?.slug in listOf("other", "photography_studio", "exhibition_ground")
                    }
                }
            }

            Column(
                modifier = Modifier.fillMaxWidth(),
                verticalArrangement = Arrangement.spacedBy(10.dp)
            ) {
                // Category Group Header
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Box(
                            modifier = Modifier
                                .size(36.dp)
                                .clip(RoundedCornerShape(10.dp))
                                .background(theme.primaryColor.copy(alpha = 0.18f)),
                            contentAlignment = Alignment.Center
                        ) {
                            Text(section.emoji, fontSize = 19.sp)
                        }
                        Spacer(modifier = Modifier.width(10.dp))
                        Column {
                            Text(
                                text = section.title,
                                style = MaterialTheme.typography.titleMedium.copy(fontWeight = FontWeight.ExtraBold),
                                color = MaterialTheme.colorScheme.onSurface
                            )
                            Text(
                                text = "${section.subSections.size} Sub-sections • $countForCategory spaces",
                                style = MaterialTheme.typography.labelSmall,
                                color = theme.primaryColor
                            )
                        }
                    }

                    TextButton(
                        onClick = { onViewCategoryClick(section) },
                        contentPadding = PaddingValues(horizontal = 8.dp, vertical = 4.dp)
                    ) {
                        Text(
                            text = "Explore",
                            style = MaterialTheme.typography.labelMedium.copy(fontWeight = FontWeight.Bold),
                            color = theme.primaryColor
                        )
                        Spacer(modifier = Modifier.width(2.dp))
                        Icon(
                            imageVector = Icons.AutoMirrored.Filled.ArrowForward,
                            contentDescription = "Explore ${section.title}",
                            modifier = Modifier.size(13.dp),
                            tint = theme.primaryColor
                        )
                    }
                }

                // Sub-sections 3D Glass Matrix for this category
                val chunkedPairs = remember(section.subSections) { section.subSections.chunked(2) }
                chunkedPairs.forEach { pair ->
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.spacedBy(12.dp)
                    ) {
                        val leftItem = pair[0]
                        val countLeft = remember(leftItem.slug, venues) {
                            venues.count { v ->
                                v.category?.slug.equals(leftItem.slug, ignoreCase = true) ||
                                        (v.category?.name?.contains(leftItem.label, ignoreCase = true) == true)
                            }
                        }

                        Box(modifier = Modifier.weight(1f)) {
                            SubSection3DGlassCard(
                                item = leftItem,
                                realCount = countLeft,
                                tiltDegrees = -4.5f,
                                theme = theme,
                                isDark = isDark,
                                onClick = {
                                    if (leftItem.slug == "custom_category" || leftItem.slug == "add_space") {
                                        onCustomCategoryClick?.invoke() ?: onSubSectionClick(leftItem.slug)
                                    } else {
                                        onSubSectionClick(leftItem.slug)
                                    }
                                }
                            )
                        }

                        if (pair.size > 1) {
                            val rightItem = pair[1]
                            val countRight = remember(rightItem.slug, venues) {
                                venues.count { v ->
                                    v.category?.slug.equals(rightItem.slug, ignoreCase = true) ||
                                            (v.category?.name?.contains(rightItem.label, ignoreCase = true) == true)
                                }
                            }

                            Box(modifier = Modifier.weight(1f)) {
                                SubSection3DGlassCard(
                                    item = rightItem,
                                    realCount = countRight,
                                    tiltDegrees = 4.5f,
                                    theme = theme,
                                    isDark = isDark,
                                    onClick = {
                                        if (rightItem.slug == "custom_category" || rightItem.slug == "add_space") {
                                            onCustomCategoryClick?.invoke() ?: onSubSectionClick(rightItem.slug)
                                        } else {
                                            onSubSectionClick(rightItem.slug)
                                        }
                                    }
                                )
                            }
                        } else {
                            Spacer(modifier = Modifier.weight(1f))
                        }
                    }
                }

                // Subtle category partition
                HorizontalDivider(
                    modifier = Modifier.padding(vertical = 4.dp),
                    color = if (isDark) Color.White.copy(alpha = 0.08f) else theme.primaryColor.copy(alpha = 0.15f)
                )
            }
        }
    }
}

/**
 * All Categories Compact Carousel Layout:
 * Groups each master category in compact horizontally scrolling carousels.
 */
@Composable
private fun AllCategoriesCompactCarouselLayout(
    sections: List<MainHomeSection>,
    venues: List<Venue>,
    isDark: Boolean,
    onSubSectionClick: (slug: String) -> Unit,
    onCustomCategoryClick: (() -> Unit)? = null
) {
    Column(
        modifier = Modifier.fillMaxWidth(),
        verticalArrangement = Arrangement.spacedBy(16.dp)
    ) {
        sections.forEach { section ->
            val theme = remember(section) { getCategoryVisualTheme(section) }
            SubSectionsCompactCarouselLayout(
                section = section,
                subSections = section.subSections,
                venues = venues,
                theme = theme,
                isDark = isDark,
                onSubSectionClick = onSubSectionClick,
                onCustomCategoryClick = onCustomCategoryClick
            )
        }
    }
}

/**
 * Central Selected Category Hero Card:
 * Displays category title, description, real counts, and subtle 3D tilt.
 */
@Composable
private fun Central3DGlassHeroCard(
    section: MainHomeSection,
    realCount: Int,
    theme: com.bookmyspace.bookmyspace.ui.screens.CategoryVisualTheme,
    isDark: Boolean,
    onViewAllClick: () -> Unit
) {
    TransformGestureGlassCard(
        modifier = Modifier
            .fillMaxWidth()
            .testTag("central_category_hero_${section.id}"),
        maxTiltDegrees = 7f,
        perspectiveFactor = 0.0016f, // Matrix4 perspective transform
        shape = RoundedCornerShape(22.dp),
        isDark = isDark,
        ambientGlowColor = theme.glowColor,
        spotGlowColor = theme.primaryColor
    ) { matrix, isHovered, isPressed, currentTiltX, currentTiltY ->
        val cardBgGradient = if (isDark) {
            Brush.linearGradient(
                colors = listOf(
                    Color(0xFF042F2E).copy(alpha = 0.88f),
                    Color(0xFF083344).copy(alpha = 0.92f),
                    Color(0xFF0F172A).copy(alpha = 0.96f)
                ),
                start = Offset(0f, 0f),
                end = Offset(800f, 600f)
            )
        } else {
            Brush.linearGradient(
                colors = listOf(
                    Color.White.copy(alpha = 0.92f),
                    theme.badgeBgColor.copy(alpha = 0.55f),
                    Color.White.copy(alpha = 0.85f)
                ),
                start = Offset(0f, 0f),
                end = Offset(800f, 600f)
            )
        }

        Box(
            modifier = Modifier
                .fillMaxWidth()
                .clip(RoundedCornerShape(22.dp))
                .background(cardBgGradient)
                .drawBehind {
                    // Specular rim gradient border
                    drawRoundRect(
                        brush = Brush.sweepGradient(
                            listOf(
                                theme.primaryColor.copy(alpha = 0.90f),
                                theme.secondaryColor.copy(alpha = 0.80f),
                                Color.White.copy(alpha = 0.65f),
                                theme.primaryColor.copy(alpha = 0.90f)
                            )
                        ),
                        cornerRadius = androidx.compose.ui.geometry.CornerRadius(22.dp.toPx())
                    )
                }
                .padding(1.5.dp) // border thickness
                .clip(RoundedCornerShape(20.5.dp))
                .background(cardBgGradient)
                .padding(18.dp)
        ) {
            Column {
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    // Badge
                    Surface(
                        shape = RoundedCornerShape(100.dp),
                        color = theme.primaryColor.copy(alpha = 0.16f),
                        border = BorderStroke(1.dp, theme.primaryColor.copy(alpha = 0.4f))
                    ) {
                        Row(
                            modifier = Modifier.padding(horizontal = 10.dp, vertical = 4.dp),
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            Text(
                                text = "✦",
                                fontSize = 11.sp,
                                color = theme.primaryColor
                            )
                            Spacer(modifier = Modifier.width(4.dp))
                            Text(
                                text = section.popularBadge.ifBlank { "VERIFIED SPACES" },
                                fontSize = 11.sp,
                                fontWeight = FontWeight.Bold,
                                color = theme.primaryColor
                            )
                        }
                    }

                    // Honest Real Venue Count Badge
                    Surface(
                        shape = RoundedCornerShape(100.dp),
                        color = if (realCount > 0) Color(0xFF10B981).copy(alpha = 0.15f) else MaterialTheme.colorScheme.surfaceVariant,
                        border = BorderStroke(
                            1.dp,
                            if (realCount > 0) Color(0xFF10B981).copy(alpha = 0.5f) else MaterialTheme.colorScheme.outlineVariant
                        )
                    ) {
                        Row(
                            modifier = Modifier.padding(horizontal = 8.dp, vertical = 3.dp),
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            if (realCount > 0) {
                                Box(
                                    modifier = Modifier
                                        .size(6.dp)
                                        .clip(CircleShape)
                                        .background(Color(0xFF10B981))
                                )
                                Spacer(modifier = Modifier.width(5.dp))
                                Text(
                                    text = "$realCount Live Spaces",
                                    fontSize = 11.sp,
                                    fontWeight = FontWeight.SemiBold,
                                    color = if (isDark) Color(0xFF6EE7B7) else Color(0xFF047857)
                                )
                            } else {
                                Text(
                                    text = "Live on Request",
                                    fontSize = 11.sp,
                                    fontWeight = FontWeight.Medium,
                                    color = MaterialTheme.colorScheme.onSurfaceVariant
                                )
                            }
                        }
                    }
                }

                Spacer(modifier = Modifier.height(10.dp))

                // Main Category Title & Emoji with 3D Matrix Parallax
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    modifier = Modifier.graphicsLayer {
                        translationX = -currentTiltY * 0.5f
                        translationY = -currentTiltX * 0.5f
                    }
                ) {
                    Box(
                        modifier = Modifier
                            .size(46.dp)
                            .clip(RoundedCornerShape(14.dp))
                            .background(
                                Brush.radialGradient(
                                    listOf(
                                        theme.primaryColor.copy(alpha = 0.35f),
                                        theme.secondaryColor.copy(alpha = 0.15f)
                                    )
                                )
                            ),
                        contentAlignment = Alignment.Center
                    ) {
                        Text(text = section.emoji, fontSize = 24.sp)
                    }
                    Spacer(modifier = Modifier.width(12.dp))
                    Column {
                        Text(
                            text = section.displayTitle,
                            style = MaterialTheme.typography.titleLarge.copy(
                                fontWeight = FontWeight.ExtraBold,
                                letterSpacing = (-0.3).sp
                            ),
                            color = MaterialTheme.colorScheme.onSurface
                        )
                        Text(
                            text = "Matrix4 Perspective Glass",
                            style = MaterialTheme.typography.labelMedium,
                            color = theme.primaryColor
                        )
                    }
                }

                Spacer(modifier = Modifier.height(8.dp))

                // Master Category Subtitle (for Function Halls: "Marriage halls, banquets, convention centers, party halls, lawns and premium celebration spaces.")
                Text(
                    text = section.displaySubtitle,
                    style = MaterialTheme.typography.bodyMedium.copy(lineHeight = 20.sp),
                    color = MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.9f)
                )

                Spacer(modifier = Modifier.height(14.dp))

                // Action Row
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Text(
                        text = "Starts from ${section.startsFromPrice}",
                        style = MaterialTheme.typography.labelLarge.copy(fontWeight = FontWeight.Bold),
                        color = theme.primaryColor
                    )

                    Button(
                        onClick = onViewAllClick,
                        shape = RoundedCornerShape(12.dp),
                        colors = ButtonDefaults.buttonColors(containerColor = theme.primaryColor),
                        contentPadding = PaddingValues(horizontal = 14.dp, vertical = 8.dp)
                    ) {
                        Text(
                            text = "Browse All",
                            style = MaterialTheme.typography.labelMedium.copy(fontWeight = FontWeight.Bold),
                            color = Color.White
                        )
                        Spacer(modifier = Modifier.width(4.dp))
                        Icon(
                            imageVector = Icons.AutoMirrored.Filled.ArrowForward,
                            contentDescription = "View All",
                            modifier = Modifier.size(14.dp),
                            tint = Color.White
                        )
                    }
                }
            }
        }
    }
}

/**
 * Sub-Sections 3D Glass Matrix Layout:
 * Arranges the sub-sections in an interactive 3D perspective matrix.
 * Cards on the left tilt slightly right, cards on the right tilt slightly left,
 * creating an immersive tactile 3D curved matrix carousel effect.
 */
@Composable
private fun SubSections3DGlassMatrixLayout(
    section: MainHomeSection,
    subSections: List<SubSectionItemModel>,
    venues: List<Venue>,
    theme: com.bookmyspace.bookmyspace.ui.screens.CategoryVisualTheme,
    isDark: Boolean,
    onSubSectionClick: (slug: String) -> Unit,
    onCustomCategoryClick: (() -> Unit)? = null
) {
    Column(
        modifier = Modifier.fillMaxWidth(),
        verticalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        // Section Subtitle / Header
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically
        ) {
            Text(
                text = "${section.title} Matrix",
                style = MaterialTheme.typography.titleMedium.copy(fontWeight = FontWeight.Bold),
                color = MaterialTheme.colorScheme.onSurface
            )
            Text(
                text = "${subSections.size} Sub-Sections",
                style = MaterialTheme.typography.labelSmall.copy(fontWeight = FontWeight.Medium),
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )
        }

        // 3D Matrix: 2 columns with depth perspective tilt
        val chunkedPairs = remember(subSections) { subSections.chunked(2) }

        chunkedPairs.forEachIndexed { rowIndex, pair ->
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(12.dp)
            ) {
                // Card 1 (Left card: subtle tilt inwards from left)
                val leftItem = pair[0]
                val realCountLeft = remember(leftItem.slug, venues) {
                    venues.count { v ->
                        v.category?.slug.equals(leftItem.slug, ignoreCase = true) ||
                                (v.category?.name?.contains(leftItem.label, ignoreCase = true) == true)
                    }
                }

                Box(modifier = Modifier.weight(1f)) {
                    SubSection3DGlassCard(
                        item = leftItem,
                        realCount = realCountLeft,
                        tiltDegrees = -4.5f,
                        theme = theme,
                        isDark = isDark,
                        onClick = {
                            if (leftItem.slug == "custom_category" || leftItem.slug == "add_space") {
                                onCustomCategoryClick?.invoke() ?: onSubSectionClick(leftItem.slug)
                            } else {
                                onSubSectionClick(leftItem.slug)
                            }
                        }
                    )
                }

                // Card 2 (Right card: subtle tilt inwards from right)
                if (pair.size > 1) {
                    val rightItem = pair[1]
                    val realCountRight = remember(rightItem.slug, venues) {
                        venues.count { v ->
                            v.category?.slug.equals(rightItem.slug, ignoreCase = true) ||
                                    (v.category?.name?.contains(rightItem.label, ignoreCase = true) == true)
                        }
                    }

                    Box(modifier = Modifier.weight(1f)) {
                        SubSection3DGlassCard(
                            item = rightItem,
                            realCount = realCountRight,
                            tiltDegrees = 4.5f,
                            theme = theme,
                            isDark = isDark,
                            onClick = {
                                if (rightItem.slug == "custom_category" || rightItem.slug == "add_space") {
                                    onCustomCategoryClick?.invoke() ?: onSubSectionClick(rightItem.slug)
                                } else {
                                    onSubSectionClick(rightItem.slug)
                                }
                            }
                        )
                    }
                } else {
                    Spacer(modifier = Modifier.weight(1f))
                }
            }
        }
    }
}

/**
 * Individual Sub-Section 3D Glass Card:
 * Features:
 * - Subtle 3D perspective rotation (rotationY = tiltDegrees, cameraDistance = 16f)
 * - Translucent glass surface with rim shine
 * - Floating emoji orb with micro-glow
 * - Sub-section name & honest real venue count
 * - 1-tap navigation directly to search route
 */
@Composable
private fun SubSection3DGlassCard(
    item: SubSectionItemModel,
    realCount: Int,
    tiltDegrees: Float,
    theme: com.bookmyspace.bookmyspace.ui.screens.CategoryVisualTheme,
    isDark: Boolean,
    onClick: () -> Unit
) {
    val isSafeMode by com.bookmyspace.bookmyspace.data.healing.AppHangSelfHealingWatchdog.isSafePerformanceMode.collectAsState()
    val is3dEnabled by com.bookmyspace.bookmyspace.data.repository.BookMySpaceRepository.is3dInteractiveModeEnabled.collectAsState()
    val effective3d = is3dEnabled && !isSafeMode

    val surfaceGradient = remember(isDark, theme) {
        if (isDark) {
            Brush.verticalGradient(
                listOf(
                    Color(0xFF042F2E).copy(alpha = 0.85f),
                    Color(0xFF0F172A).copy(alpha = 0.92f)
                )
            )
        } else {
            Brush.verticalGradient(
                listOf(
                    Color.White.copy(alpha = 0.95f),
                    theme.badgeBgColor.copy(alpha = 0.55f)
                )
            )
        }
    }

    val borderBrush = remember(theme, isDark) {
        Brush.linearGradient(
            colors = listOf(
                theme.primaryColor.copy(alpha = 0.85f),
                Color.White.copy(alpha = if (isDark) 0.25f else 0.65f),
                theme.secondaryColor.copy(alpha = 0.50f),
                theme.primaryColor.copy(alpha = 0.70f)
            )
        )
    }

    Surface(
        onClick = onClick,
        modifier = Modifier
            .fillMaxWidth()
            .height(108.dp)
            .testTag("sub_section_card_${item.slug}")
            .then(
                if (effective3d) {
                    Modifier.graphicsLayer {
                        rotationY = tiltDegrees * 0.85f
                        cameraDistance = 14f * density
                    }
                } else Modifier
            ),
        shape = RoundedCornerShape(18.dp),
        color = Color.Transparent,
        shadowElevation = if (effective3d) 3.dp else 1.dp,
        border = BorderStroke(1.dp, borderBrush)
    ) {
        Box(
            modifier = Modifier
                .fillMaxSize()
                .background(surfaceGradient)
        ) {
            Row(
                modifier = Modifier
                    .fillMaxSize()
                    .padding(12.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                // Floating Emoji Orb with Micro-Glow
                Box(
                    modifier = Modifier
                        .size(44.dp)
                        .clip(CircleShape)
                        .background(
                            Brush.radialGradient(
                                listOf(
                                    theme.primaryColor.copy(alpha = 0.35f),
                                    theme.secondaryColor.copy(alpha = 0.15f)
                                )
                            )
                        )
                        .drawBehind {
                            drawCircle(
                                color = theme.primaryColor.copy(alpha = 0.25f),
                                radius = size.minDimension / 2f
                            )
                        },
                    contentAlignment = Alignment.Center
                ) {
                    Text(
                        text = item.emoji,
                        fontSize = 22.sp
                    )
                }

                Spacer(modifier = Modifier.width(10.dp))

                Column(
                    modifier = Modifier.weight(1f),
                    verticalArrangement = Arrangement.Center
                ) {
                    Text(
                        text = item.label,
                        style = MaterialTheme.typography.bodyMedium.copy(
                            fontWeight = FontWeight.Bold,
                            lineHeight = 18.sp
                        ),
                        color = MaterialTheme.colorScheme.onSurface,
                        maxLines = 2,
                        overflow = TextOverflow.Ellipsis
                    )

                    Spacer(modifier = Modifier.height(3.dp))

                    // Honest Real Venue Count / Explore
                    if (realCount > 0) {
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            Box(
                                modifier = Modifier
                                    .size(5.dp)
                                    .clip(CircleShape)
                                    .background(Color(0xFF10B981))
                            )
                            Spacer(modifier = Modifier.width(4.dp))
                            Text(
                                text = "$realCount spaces",
                                style = MaterialTheme.typography.labelSmall.copy(
                                    fontWeight = FontWeight.SemiBold
                                ),
                                color = if (isDark) Color(0xFF6EE7B7) else Color(0xFF047857)
                            )
                        }
                    } else {
                        Text(
                            text = "Explore",
                            style = MaterialTheme.typography.labelSmall.copy(
                                fontWeight = FontWeight.Medium
                            ),
                            color = theme.primaryColor
                        )
                    }
                }

                // Arrow Indicator in frosted circle
                Box(
                    modifier = Modifier
                        .size(28.dp)
                        .clip(CircleShape)
                        .background(theme.primaryColor.copy(alpha = 0.12f)),
                    contentAlignment = Alignment.Center
                ) {
                    Icon(
                        imageVector = Icons.AutoMirrored.Filled.ArrowForward,
                        contentDescription = null,
                        modifier = Modifier.size(15.dp),
                        tint = theme.primaryColor
                    )
                }
            }
        }
    }
}

/**
 * Compact Admin UI Style Switcher Pill:
 * Lets the admin toggle between Style 1 (3D Matrix), Style 2 (Tactile Grid), and Style 3 (Compact Carousel).
 */
@Composable
private fun AdminUiStyleSwitcherPill(
    currentStyle: HomeCategoryDiscoveryStyle,
    onStyleChange: (HomeCategoryDiscoveryStyle) -> Unit,
    accentColor: Color,
    isDark: Boolean
) {
    var expanded by remember { mutableStateOf(false) }

    Box {
        Surface(
            onClick = { expanded = !expanded },
            shape = RoundedCornerShape(100.dp),
            color = if (isDark) Color(0xFF1E293B) else Color.White,
            border = BorderStroke(1.dp, accentColor.copy(alpha = 0.45f)),
            shadowElevation = 2.dp
        ) {
            Row(
                modifier = Modifier.padding(horizontal = 8.dp, vertical = 4.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                Text(
                    text = when (currentStyle) {
                        HomeCategoryDiscoveryStyle.STYLE_1_3D_GLASS_MATRIX -> "UI 1: 3D Matrix"
                        HomeCategoryDiscoveryStyle.STYLE_2_TACTILE_GRID -> "UI 2: Tactile Grid"
                        HomeCategoryDiscoveryStyle.STYLE_3_COMPACT_CAROUSEL -> "UI 3: Carousel"
                    },
                    fontSize = 10.sp,
                    fontWeight = FontWeight.Bold,
                    color = accentColor
                )
                Icon(
                    imageVector = Icons.Default.ArrowDropDown,
                    contentDescription = "Switch UI Style",
                    modifier = Modifier.size(14.dp),
                    tint = accentColor
                )
            }
        }

        DropdownMenu(
            expanded = expanded,
            onDismissRequest = { expanded = false }
        ) {
            DropdownMenuItem(
                text = {
                    Column {
                        Text("Style 1: 3D Glass Matrix & Orbit", fontWeight = FontWeight.Bold, fontSize = 13.sp)
                        Text("Interactive 3D depth, perspective rotation & live data", fontSize = 11.sp, color = Color.Gray)
                    }
                },
                leadingIcon = {
                    if (currentStyle == HomeCategoryDiscoveryStyle.STYLE_1_3D_GLASS_MATRIX) {
                        Icon(Icons.Default.Check, contentDescription = null, tint = accentColor)
                    }
                },
                onClick = {
                    onStyleChange(HomeCategoryDiscoveryStyle.STYLE_1_3D_GLASS_MATRIX)
                    expanded = false
                }
            )

            DropdownMenuItem(
                text = {
                    Column {
                        Text("Style 2: Classic Tactile Grid", fontWeight = FontWeight.Bold, fontSize = 13.sp)
                        Text("Original tactile cards with live status & quick chips", fontSize = 11.sp, color = Color.Gray)
                    }
                },
                leadingIcon = {
                    if (currentStyle == HomeCategoryDiscoveryStyle.STYLE_2_TACTILE_GRID) {
                        Icon(Icons.Default.Check, contentDescription = null, tint = accentColor)
                    }
                },
                onClick = {
                    onStyleChange(HomeCategoryDiscoveryStyle.STYLE_2_TACTILE_GRID)
                    expanded = false
                }
            )

            DropdownMenuItem(
                text = {
                    Column {
                        Text("Style 3: Compact Glass Carousel", fontWeight = FontWeight.Bold, fontSize = 13.sp)
                        Text("Horizontally scrolling glass cards with quick filter pills", fontSize = 11.sp, color = Color.Gray)
                    }
                },
                leadingIcon = {
                    if (currentStyle == HomeCategoryDiscoveryStyle.STYLE_3_COMPACT_CAROUSEL) {
                        Icon(Icons.Default.Check, contentDescription = null, tint = accentColor)
                    }
                },
                onClick = {
                    onStyleChange(HomeCategoryDiscoveryStyle.STYLE_3_COMPACT_CAROUSEL)
                    expanded = false
                }
            )
        }
    }
}
