package com.bookmyspace.bookmyspace.ui.components

import androidx.compose.animation.animateColorAsState
import androidx.compose.animation.core.*
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.hoverable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.interaction.collectIsHoveredAsState
import androidx.compose.foundation.interaction.collectIsPressedAsState
import androidx.compose.foundation.layout.*
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
import androidx.compose.ui.draw.drawWithContent
import androidx.compose.ui.draw.scale
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Shape
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.input.pointer.PointerIcon
import androidx.compose.ui.input.pointer.pointerHoverIcon
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import coil.compose.AsyncImage
import com.bookmyspace.bookmyspace.data.model.Venue
import com.bookmyspace.bookmyspace.ui.screens.MainHomeSection
import kotlinx.coroutines.delay

/**
 * 3D Glass Type Modifier:
 * Applies a luxurious frosted glassmorphic surface with specular rim bevel,
 * dynamic gradient reflection gleam, and subtle depth shadow.
 */
fun Modifier.glass3dEffect(
    shape: Shape = RoundedCornerShape(20.dp),
    isSelected: Boolean = false,
    accentGlow: Color? = null,
    elevation: Dp = 8.dp
): Modifier = this
    .shadow(
        elevation = if (isSelected) elevation + 4.dp else elevation,
        shape = shape,
        ambientColor = if (isSelected) (accentGlow ?: Color(0xFF6366F1)).copy(alpha = 0.35f) else Color.Black.copy(alpha = 0.2f),
        spotColor = if (isSelected) (accentGlow ?: Color(0xFF6366F1)).copy(alpha = 0.45f) else Color.Black.copy(alpha = 0.3f)
    )
    .clip(shape)
    .drawBehind {
        // 1. Frosted translucent base background
        val baseGradient = if (isSelected) {
            Brush.linearGradient(
                colors = listOf(
                    (accentGlow ?: Color(0xFF4F46E5)).copy(alpha = 0.30f),
                    (accentGlow ?: Color(0xFF6366F1)).copy(alpha = 0.18f),
                    Color.White.copy(alpha = 0.12f)
                ),
                start = Offset.Zero,
                end = Offset(size.width, size.height)
            )
        } else {
            Brush.linearGradient(
                colors = listOf(
                    Color.White.copy(alpha = 0.22f),
                    Color.White.copy(alpha = 0.08f),
                    Color.White.copy(alpha = 0.14f)
                ),
                start = Offset.Zero,
                end = Offset(size.width, size.height)
            )
        }
        drawRect(brush = baseGradient)

        // 2. Top-edge glossy specular glass refraction sheen (curved reflection highlight)
        val sheenBrush = Brush.verticalGradient(
            colors = listOf(
                Color.White.copy(alpha = if (isSelected) 0.38f else 0.28f),
                Color.White.copy(alpha = 0.05f),
                Color.Transparent
            ),
            startY = 0f,
            endY = size.height * 0.45f
        )
        drawRect(
            brush = sheenBrush,
            topLeft = Offset.Zero,
            size = Size(size.width, size.height * 0.45f)
        )
    }
    .drawWithContent {
        drawContent()
        // 3. Specular 3D Glass rim bevel highlight on the inner border
        val rimStroke = Brush.linearGradient(
            colors = if (isSelected) {
                listOf(
                    Color.White.copy(alpha = 0.90f),
                    (accentGlow ?: Color(0xFF818CF8)).copy(alpha = 0.70f),
                    Color.White.copy(alpha = 0.25f)
                )
            } else {
                listOf(
                    Color.White.copy(alpha = 0.65f),
                    Color.White.copy(alpha = 0.20f),
                    Color.White.copy(alpha = 0.05f)
                )
            },
            start = Offset(0f, 0f),
            end = Offset(size.width, size.height)
        )
        // Outer rim highlight
        drawRect(
            brush = rimStroke,
            style = androidx.compose.ui.graphics.drawscope.Stroke(width = 1.5.dp.toPx())
        )
    }

/**
 * Reusable 3D Glass Surface Card
 */
@Composable
fun Glass3DCard(
    modifier: Modifier = Modifier,
    shape: Shape = RoundedCornerShape(22.dp),
    isSelected: Boolean = false,
    accentGlow: Color? = null,
    onClick: (() -> Unit)? = null,
    content: @Composable BoxScope.() -> Unit
) {
    val interactionSource = remember { MutableInteractionSource() }
    val isHovered by interactionSource.collectIsHoveredAsState()
    val isPressed by interactionSource.collectIsPressedAsState()

    val targetScale = when {
        isPressed -> 0.97f
        isHovered -> 1.025f
        else -> 1f
    }
    val pressScale by animateFloatAsState(
        targetValue = targetScale,
        animationSpec = tween(durationMillis = 120, easing = FastOutSlowInEasing),
        label = "glassCardScale"
    )

    Box(
        modifier = modifier
            .hoverable(interactionSource = interactionSource)
            .pointerHoverIcon(PointerIcon.Hand)
            .graphicsLayer {
                scaleX = pressScale
                scaleY = pressScale
            }
            .glass3dEffect(
                shape = shape,
                isSelected = isSelected || isHovered,
                accentGlow = if (isHovered) (accentGlow ?: Color(0xFF6366F1)) else accentGlow
            )
            .then(
                if (onClick != null) {
                    Modifier.clickable(
                        interactionSource = interactionSource,
                        indication = null,
                        onClick = onClick
                    )
                } else Modifier
            ),
        content = content
    )
}

/**
 * 3D Glass Category Pill for top category navigation ("catagerios")
 */
@Composable
fun Glass3DCategoryPill(
    title: String,
    emoji: String,
    isSelected: Boolean,
    countBadge: String? = null,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    testTag: String = ""
) {
    val interactionSource = remember { MutableInteractionSource() }
    val isHovered by interactionSource.collectIsHoveredAsState()
    val isPressed by interactionSource.collectIsPressedAsState()

    // Distinct signature light-source highlight color per category
    val categoryColor = remember(title, emoji) {
        when {
            title.contains("Function", ignoreCase = true) || emoji == "🏛️" -> Color(0xFF818CF8) // Royal Indigo & Violet
            title.contains("Lodge", ignoreCase = true) || title.contains("Room", ignoreCase = true) || emoji == "🏨" -> Color(0xFFF59E0B) // Sunset Amber & Gold
            title.contains("PG", ignoreCase = true) || title.contains("Hostel", ignoreCase = true) || emoji == "🏡" -> Color(0xFF10B981) // Mint Emerald
            title.contains("Institute", ignoreCase = true) || title.contains("Class", ignoreCase = true) || emoji == "📚" -> Color(0xFF0EA5E9) // Electric Sky Blue
            title.contains("Sport", ignoreCase = true) || title.contains("Turf", ignoreCase = true) || emoji == "⚽" -> Color(0xFF84CC16) // Neon Lime
            else -> Color(0xFF00F2FE) // Luminous Ice-Cyan for All Spaces
        }
    }

    // 1. Subtle 3D Tilt Animation on Hover
    val tiltX by animateFloatAsState(
        targetValue = when {
            isPressed -> 2.5f
            isHovered -> -5.0f
            isSelected -> -2.0f
            else -> 0f
        },
        animationSpec = tween(durationMillis = 150, easing = FastOutSlowInEasing),
        label = "pillTiltX"
    )
    val tiltY by animateFloatAsState(
        targetValue = when {
            isPressed -> -1.5f
            isHovered -> 4.0f
            isSelected -> 1.5f
            else -> 0f
        },
        animationSpec = tween(durationMillis = 150, easing = FastOutSlowInEasing),
        label = "pillTiltY"
    )
    val liftY by animateFloatAsState(
        targetValue = when {
            isPressed -> 2f
            isHovered -> -6f
            isSelected -> -2f
            else -> 0f
        },
        animationSpec = tween(durationMillis = 150, easing = FastOutSlowInEasing),
        label = "pillLiftY"
    )
    val targetScale = when {
        isPressed -> 0.94f
        isHovered -> 1.08f
        isSelected -> 1.04f
        else -> 1f
    }
    val scaleAnim by animateFloatAsState(
        targetValue = targetScale,
        animationSpec = tween(durationMillis = 150, easing = FastOutSlowInEasing),
        label = "pillScale"
    )

    // 2. Dynamic Elevated Drop-Shadows that deepen during interaction
    val dynamicElevation by animateDpAsState(
        targetValue = when {
            isPressed -> 1.5.dp
            isHovered -> 16.dp
            isSelected -> 7.dp
            else -> 2.5.dp
        },
        animationSpec = tween(durationMillis = 150),
        label = "pillElevation"
    )

    val animatedContainerColor by animateColorAsState(
        targetValue = when {
            isSelected -> categoryColor.copy(alpha = 0.28f)
            isHovered -> categoryColor.copy(alpha = 0.18f)
            else -> MaterialTheme.colorScheme.surface.copy(alpha = 0.65f)
        },
        animationSpec = tween(durationMillis = 120),
        label = "pillColor"
    )

    Surface(
        onClick = onClick,
        interactionSource = interactionSource,
        shape = RoundedCornerShape(20.dp),
        color = animatedContainerColor,
        // Border with directional light-source gradient (top is brightest with category color)
        border = BorderStroke(
            width = if (isSelected || isHovered) 1.8.dp else 1.2.dp,
            brush = if (isSelected || isHovered) {
                Brush.verticalGradient(
                    listOf(
                        Color.White.copy(alpha = 0.98f),
                        categoryColor.copy(alpha = if (isHovered) 0.90f else 0.75f),
                        categoryColor.copy(alpha = 0.35f),
                        Color.White.copy(alpha = 0.10f)
                    )
                )
            } else {
                Brush.verticalGradient(
                    listOf(
                        Color.White.copy(alpha = 0.65f),
                        categoryColor.copy(alpha = 0.30f),
                        Color.Transparent
                    )
                )
            }
        ),
        modifier = modifier
            .hoverable(interactionSource = interactionSource)
            .pointerHoverIcon(PointerIcon.Hand)
            .shadow(
                elevation = dynamicElevation,
                shape = RoundedCornerShape(20.dp),
                ambientColor = categoryColor.copy(alpha = if (isHovered) 0.45f else if (isSelected) 0.32f else 0.14f),
                spotColor = categoryColor.copy(alpha = if (isHovered) 0.70f else if (isSelected) 0.48f else 0.24f)
            )
            .graphicsLayer {
                scaleX = scaleAnim
                scaleY = scaleAnim
                rotationX = tiltX
                rotationY = tiltY
                translationY = liftY
                cameraDistance = 16f * density
            }
            .defaultMinSize(minHeight = 48.dp)
            .testTag(testTag)
    ) {
        // Restructured layout: Top edge highlight bar + content
        Box(modifier = Modifier.clip(RoundedCornerShape(20.dp))) {
            // 3. Pronounced Border-Based Highlight on Top Edge (Light-source effect with distinct category color)
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .height(3.dp)
                    .align(Alignment.TopCenter)
                    .background(
                        Brush.horizontalGradient(
                            listOf(
                                categoryColor.copy(alpha = 0.25f),
                                categoryColor.copy(alpha = if (isHovered) 0.95f else 0.80f),
                                Color.White.copy(alpha = if (isHovered) 1.0f else 0.95f),
                                categoryColor.copy(alpha = if (isHovered) 0.95f else 0.80f),
                                categoryColor.copy(alpha = 0.25f)
                            )
                        )
                    )
            )

            // Secondary subtle overhead beam bloom
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .height(9.dp)
                    .align(Alignment.TopCenter)
                    .background(
                        Brush.verticalGradient(
                            listOf(
                                categoryColor.copy(alpha = if (isHovered) 0.22f else 0.12f),
                                Color.Transparent
                            )
                        )
                    )
            )

            Row(
                modifier = Modifier.padding(horizontal = 14.dp, vertical = 10.dp),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.Center
            ) {
                // 3D Emoji Avatar with category tinted glow
                Box(
                    modifier = Modifier
                        .size(28.dp)
                        .clip(CircleShape)
                        .background(
                            if (isSelected) categoryColor.copy(alpha = 0.25f)
                            else MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.7f)
                        ),
                    contentAlignment = Alignment.Center
                ) {
                    Text(
                        text = emoji,
                        fontSize = 15.sp
                    )
                }

                Spacer(modifier = Modifier.width(8.dp))

                Text(
                    text = title,
                    fontSize = 13.5.sp,
                    fontWeight = if (isSelected) FontWeight.Black else FontWeight.SemiBold,
                    color = if (isSelected) categoryColor else MaterialTheme.colorScheme.onSurface
                )

                if (!countBadge.isNullOrBlank()) {
                    Spacer(modifier = Modifier.width(6.dp))
                    Surface(
                        shape = RoundedCornerShape(10.dp),
                        color = if (isSelected) categoryColor else MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.8f),
                        modifier = Modifier.padding(start = 2.dp)
                    ) {
                        Text(
                            text = countBadge,
                            fontSize = 10.5.sp,
                            fontWeight = FontWeight.Bold,
                            color = if (isSelected) Color.White else MaterialTheme.colorScheme.onSurfaceVariant,
                            modifier = Modifier.padding(horizontal = 6.dp, vertical = 2.dp)
                        )
                    }
                }
            }
        }
    }
}

/**
 * TOP 3D GLASS CATEGORIES STRIP:
 * Displayed at the top of the home screen, allowing frictionless navigation
 * across all space categories with modern 3D glass styling.
 */
@Composable
fun Top3DGlassCategoriesStrip(
    availableSections: List<MainHomeSection>,
    selectedSection: MainHomeSection?,
    onSelectSection: (MainHomeSection?) -> Unit,
    onAddCustomCategory: () -> Unit,
    modifier: Modifier = Modifier
) {
    val scrollState = rememberScrollState()

    Column(modifier = modifier.fillMaxWidth()) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 4.dp, vertical = 2.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.SpaceBetween
        ) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text(
                    text = "Categories",
                    fontSize = 17.sp,
                    fontWeight = FontWeight.Black,
                    color = MaterialTheme.colorScheme.onBackground,
                    letterSpacing = (-0.3).sp
                )
                Spacer(modifier = Modifier.width(6.dp))
                Surface(
                    shape = RoundedCornerShape(8.dp),
                    color = MaterialTheme.colorScheme.primaryContainer.copy(alpha = 0.6f)
                ) {
                    Text(
                        text = "3D Glass",
                        fontSize = 10.sp,
                        fontWeight = FontWeight.Bold,
                        color = MaterialTheme.colorScheme.primary,
                        modifier = Modifier.padding(horizontal = 6.dp, vertical = 2.dp)
                    )
                }
            }

            TextButton(
                onClick = onAddCustomCategory,
                contentPadding = PaddingValues(horizontal = 8.dp, vertical = 4.dp)
            ) {
                Icon(Icons.Default.Add, contentDescription = null, modifier = Modifier.size(16.dp))
                Spacer(modifier = Modifier.width(4.dp))
                Text("Add Category", fontSize = 12.sp, fontWeight = FontWeight.Bold)
            }
        }

        Spacer(modifier = Modifier.height(6.dp))

        Row(
            modifier = Modifier
                .fillMaxWidth()
                .horizontalScroll(scrollState)
                .padding(vertical = 4.dp),
            horizontalArrangement = Arrangement.spacedBy(10.dp)
        ) {
            // "All Spaces" 3D Glass Pill
            Glass3DCategoryPill(
                title = "All Spaces",
                emoji = "✨",
                isSelected = selectedSection == null,
                countBadge = "Explore",
                onClick = { onSelectSection(null) },
                testTag = "glass_cat_pill_all"
            )

            // Dynamic 3D Glass Pills for Available Sections
            availableSections.forEach { section ->
                Glass3DCategoryPill(
                    title = section.title,
                    emoji = section.emoji,
                    isSelected = selectedSection == section,
                    countBadge = "${section.defaultCount}+",
                    onClick = { onSelectSection(section) },
                    testTag = "glass_cat_pill_${section.id}"
                )
            }

            // Custom Category Add Pill
            Glass3DCategoryPill(
                title = "More Categories",
                emoji = "➕",
                isSelected = false,
                onClick = onAddCustomCategory,
                testTag = "glass_cat_pill_add_custom"
            )
        }
    }
}

/**
 * TOP SPOTLIGHT SECTION:
 * Placed at the very top of the home screen ("spotlight kee in top").
 * Displays a stage-light spotlight illumination beam gradient effect
 * over curated top-rated spaces with 3D Glass card aesthetics.
 */
@Composable
fun TopSpotlightSection(
    venues: List<Venue>,
    onNavigateToVenue: (String) -> Unit,
    modifier: Modifier = Modifier
) {
    // Filter top spotlight venues (rating >= 4.7 or verified venues)
    val spotlightVenues = remember(venues) {
        val topPicks = venues.filter { it.avgRating >= 4.7 || it.isVerified }.sortedByDescending { it.avgRating }
        if (topPicks.isNotEmpty()) topPicks.take(6) else venues.take(4)
    }

    if (spotlightVenues.isEmpty()) return

    var currentIndex by remember { mutableIntStateOf(0) }
    val currentVenue = spotlightVenues[currentIndex.coerceIn(0, spotlightVenues.lastIndex)]

    // Subtle auto-advance every 6.5s to showcase spotlight spaces
    LaunchedEffect(spotlightVenues.size) {
        while (true) {
            delay(6500L)
            if (spotlightVenues.size > 1) {
                currentIndex = (currentIndex + 1) % spotlightVenues.size
            }
        }
    }

    // Spotlight beam animated sweep
    val infiniteTransition = rememberInfiniteTransition(label = "spotlightTransition")
    val beamOffset by infiniteTransition.animateFloat(
        initialValue = -0.2f,
        targetValue = 1.2f,
        animationSpec = infiniteRepeatable(
            animation = tween(durationMillis = 4200, easing = LinearEasing),
            repeatMode = RepeatMode.Reverse
        ),
        label = "beamOffset"
    )

    Column(
        modifier = modifier
            .fillMaxWidth()
            .testTag("top_spotlight_section")
    ) {
        // Spotlight Section Header with Spotlight Badge & Indicators
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 4.dp, vertical = 4.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.SpaceBetween
        ) {
            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                // Spotlight Luminous Badge
                Surface(
                    shape = RoundedCornerShape(12.dp),
                    color = Color(0xFFF59E0B),
                    shadowElevation = 4.dp
                ) {
                    Row(
                        modifier = Modifier.padding(horizontal = 8.dp, vertical = 4.dp),
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Icon(
                            imageVector = Icons.Default.AutoAwesome,
                            contentDescription = null,
                            tint = Color.Black,
                            modifier = Modifier.size(13.dp)
                        )
                        Spacer(modifier = Modifier.width(4.dp))
                        Text(
                            text = "SPOTLIGHT",
                            fontSize = 11.sp,
                            fontWeight = FontWeight.Black,
                            color = Color.Black,
                            letterSpacing = 0.5.sp
                        )
                    }
                }

                Text(
                    text = "Top-Rated Spaces",
                    fontSize = 15.sp,
                    fontWeight = FontWeight.Bold,
                    color = MaterialTheme.colorScheme.onBackground
                )
            }

            // Carousel Slide Controls / Page Counter
            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(4.dp)
            ) {
                IconButton(
                    onClick = {
                        currentIndex = if (currentIndex > 0) currentIndex - 1 else spotlightVenues.lastIndex
                    },
                    modifier = Modifier
                        .size(32.dp)
                        .pointerHoverIcon(PointerIcon.Hand)
                ) {
                    Icon(
                        imageVector = Icons.Default.ChevronLeft,
                        contentDescription = "Previous Spotlight",
                        tint = MaterialTheme.colorScheme.onSurfaceVariant,
                        modifier = Modifier.size(20.dp)
                    )
                }

                Text(
                    text = "${currentIndex + 1}/${spotlightVenues.size}",
                    fontSize = 12.sp,
                    fontWeight = FontWeight.Bold,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )

                IconButton(
                    onClick = {
                        currentIndex = (currentIndex + 1) % spotlightVenues.size
                    },
                    modifier = Modifier
                        .size(32.dp)
                        .pointerHoverIcon(PointerIcon.Hand)
                ) {
                    Icon(
                        imageVector = Icons.Default.ChevronRight,
                        contentDescription = "Next Spotlight",
                        tint = MaterialTheme.colorScheme.onSurfaceVariant,
                        modifier = Modifier.size(20.dp)
                    )
                }
            }
        }

        Spacer(modifier = Modifier.height(6.dp))

        // Fast mouse hover interaction state for Spotlight Card
        val cardInteractionSource = remember { MutableInteractionSource() }
        val isCardHovered by cardInteractionSource.collectIsHoveredAsState()
        val isCardPressed by cardInteractionSource.collectIsPressedAsState()

        val cardScale by animateFloatAsState(
            targetValue = when {
                isCardPressed -> 0.985f
                isCardHovered -> 1.025f
                else -> 1.0f
            },
            animationSpec = tween(durationMillis = 130, easing = FastOutSlowInEasing),
            label = "spotlightCardScale"
        )
        val cardLiftY by animateFloatAsState(
            targetValue = if (isCardHovered) -4f else 0f,
            animationSpec = tween(durationMillis = 130, easing = FastOutSlowInEasing),
            label = "spotlightCardLiftY"
        )
        val cardElevation by animateDpAsState(
            targetValue = if (isCardHovered) 22.dp else 12.dp,
            animationSpec = tween(durationMillis = 130),
            label = "spotlightCardElevation"
        )

        // 3D Glass Spotlight Hero Card with Stage Spotlight Beam Effect
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .height(230.dp)
                .hoverable(cardInteractionSource)
                .pointerHoverIcon(PointerIcon.Hand)
                .graphicsLayer {
                    scaleX = cardScale
                    scaleY = cardScale
                    translationY = cardLiftY
                }
                .shadow(
                    elevation = cardElevation,
                    shape = RoundedCornerShape(26.dp),
                    spotColor = if (isCardHovered) Color(0xFFF59E0B).copy(alpha = 0.55f) else Color(0xFFF59E0B).copy(alpha = 0.3f),
                    ambientColor = if (isCardHovered) Color(0xFFF59E0B).copy(alpha = 0.35f) else Color.Black.copy(alpha = 0.2f)
                )
                .clip(RoundedCornerShape(26.dp))
                // Stage Spotlight Lighting Cone / Beam
                .drawBehind {
                    // Dramatic stage spotlight illumination cone
                    val spotlightOrigin = Offset(size.width * beamOffset, 0f)
                    val beamBrush = Brush.radialGradient(
                        colors = listOf(
                            Color(0xFFFEF08A).copy(alpha = if (isCardHovered) 0.45f else 0.35f),
                            Color(0xFFF59E0B).copy(alpha = if (isCardHovered) 0.22f else 0.15f),
                            Color.Transparent
                        ),
                        center = spotlightOrigin,
                        radius = size.width * 0.85f
                    )
                    drawRect(brush = beamBrush)
                }
                .clickable(
                    interactionSource = cardInteractionSource,
                    indication = null,
                    onClick = { onNavigateToVenue(currentVenue.id) }
                )
                .testTag("spotlight_card_${currentVenue.id}")
        ) {
            // Venue Hero Image
            AsyncImage(
                model = currentVenue.coverImageUrl,
                contentDescription = currentVenue.name,
                contentScale = ContentScale.Crop,
                modifier = Modifier.fillMaxSize()
            )

            // Deep vignette gradient overlay for contrast and depth
            Box(
                modifier = Modifier
                    .fillMaxSize()
                    .background(
                        Brush.verticalGradient(
                            colors = listOf(
                                Color.Black.copy(alpha = 0.25f),
                                Color.Transparent,
                                Color.Black.copy(alpha = 0.85f)
                            )
                        )
                    )
            )

            // Top Badges Overlay (Spotlight Pick + Rating Star)
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(14.dp),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                // 3D Glass Pill: Spotlight Choice
                Surface(
                    shape = RoundedCornerShape(14.dp),
                    color = Color.Black.copy(alpha = 0.45f),
                    border = BorderStroke(1.dp, Color(0xFFF59E0B).copy(alpha = 0.8f))
                ) {
                    Row(
                        modifier = Modifier.padding(horizontal = 10.dp, vertical = 5.dp),
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Text("✨", fontSize = 12.sp)
                        Spacer(modifier = Modifier.width(4.dp))
                        Text(
                            text = "Featured Spotlight",
                            fontSize = 11.5.sp,
                            fontWeight = FontWeight.Bold,
                            color = Color(0xFFFDE68A)
                        )
                    }
                }

                // Rating & Verified Glass Badge
                Surface(
                    shape = RoundedCornerShape(14.dp),
                    color = Color.Black.copy(alpha = 0.55f),
                    border = BorderStroke(1.dp, Color.White.copy(alpha = 0.35f))
                ) {
                    Row(
                        modifier = Modifier.padding(horizontal = 10.dp, vertical = 5.dp),
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Icon(
                            imageVector = Icons.Default.Star,
                            contentDescription = null,
                            tint = Color(0xFFFBBF24),
                            modifier = Modifier.size(15.dp)
                        )
                        Spacer(modifier = Modifier.width(4.dp))
                        Text(
                            text = "%.1f".format(currentVenue.avgRating),
                            fontSize = 12.sp,
                            fontWeight = FontWeight.Black,
                            color = Color.White
                        )
                        Text(
                            text = " (${currentVenue.ratingCount})",
                            fontSize = 10.5.sp,
                            color = Color.White.copy(alpha = 0.8f)
                        )
                    }
                }
            }

            // Bottom 3D Glass Venue Details Plate
            Box(
                modifier = Modifier
                    .align(Alignment.BottomCenter)
                    .fillMaxWidth()
                    .padding(12.dp)
                    .glass3dEffect(
                        shape = RoundedCornerShape(18.dp),
                        isSelected = false,
                        elevation = 0.dp
                    )
                    .background(Color.Black.copy(alpha = 0.45f))
            ) {
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(12.dp),
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.SpaceBetween
                ) {
                    Column(modifier = Modifier.weight(1f)) {
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            Text(
                                text = currentVenue.name,
                                fontSize = 16.sp,
                                fontWeight = FontWeight.Black,
                                color = Color.White,
                                maxLines = 1,
                                overflow = TextOverflow.Ellipsis
                            )
                            if (currentVenue.isVerified) {
                                Spacer(modifier = Modifier.width(4.dp))
                                Icon(
                                    imageVector = Icons.Default.Verified,
                                    contentDescription = "Verified",
                                    tint = Color(0xFF38BDF8),
                                    modifier = Modifier.size(16.dp)
                                )
                            }
                        }

                        Spacer(modifier = Modifier.height(2.dp))

                        Row(verticalAlignment = Alignment.CenterVertically) {
                            Icon(
                                imageVector = Icons.Default.LocationOn,
                                contentDescription = null,
                                tint = Color.White.copy(alpha = 0.85f),
                                modifier = Modifier.size(13.dp)
                            )
                            Spacer(modifier = Modifier.width(3.dp))
                            Text(
                                text = "${currentVenue.city} • ${currentVenue.distanceKm} km away",
                                fontSize = 12.sp,
                                color = Color.White.copy(alpha = 0.85f),
                                maxLines = 1,
                                overflow = TextOverflow.Ellipsis
                            )
                        }
                    }

                    Spacer(modifier = Modifier.width(8.dp))

                    // Price and CTA
                    Column(horizontalAlignment = Alignment.End) {
                        Text(
                            text = "₹%,d".format(currentVenue.pricingBaseAmount.toInt()),
                            fontSize = 16.sp,
                            fontWeight = FontWeight.Black,
                            color = Color(0xFFFDE68A)
                        )
                        Text(
                            text = "starts from",
                            fontSize = 10.sp,
                            color = Color.White.copy(alpha = 0.75f)
                        )
                    }

                    Spacer(modifier = Modifier.width(10.dp))

                    // 3D Glass Action Arrow Button with fast mouse hover feedback
                    val arrowInteraction = remember { MutableInteractionSource() }
                    val isArrowHovered by arrowInteraction.collectIsHoveredAsState()
                    val isArrowPressed by arrowInteraction.collectIsPressedAsState()
                    val arrowScale by animateFloatAsState(
                        targetValue = when {
                            isArrowPressed -> 0.92f
                            isArrowHovered -> 1.15f
                            else -> 1.0f
                        },
                        animationSpec = tween(durationMillis = 100, easing = FastOutSlowInEasing),
                        label = "arrowScale"
                    )

                    Surface(
                        onClick = { onNavigateToVenue(currentVenue.id) },
                        interactionSource = arrowInteraction,
                        shape = CircleShape,
                        color = if (isArrowHovered) Color(0xFFF59E0B) else MaterialTheme.colorScheme.primary,
                        shadowElevation = if (isArrowHovered) 8.dp else 4.dp,
                        modifier = Modifier
                            .size(38.dp)
                            .hoverable(arrowInteraction)
                            .pointerHoverIcon(PointerIcon.Hand)
                            .graphicsLayer {
                                scaleX = arrowScale
                                scaleY = arrowScale
                            }
                    ) {
                        Box(contentAlignment = Alignment.Center) {
                            Icon(
                                imageVector = Icons.AutoMirrored.Filled.ArrowForward,
                                contentDescription = "View Spotlight Space",
                                tint = if (isArrowHovered) Color.Black else MaterialTheme.colorScheme.onPrimary,
                                modifier = Modifier.size(18.dp)
                            )
                        }
                    }
                }
            }
        }

        // Spotlight Pagination Dots Indicator
        if (spotlightVenues.size > 1) {
            Spacer(modifier = Modifier.height(8.dp))
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.Center,
                verticalAlignment = Alignment.CenterVertically
            ) {
                spotlightVenues.forEachIndexed { index, _ ->
                    val isCurrent = index == currentIndex
                    Box(
                        modifier = Modifier
                            .padding(horizontal = 3.dp)
                            .height(6.dp)
                            .width(if (isCurrent) 24.dp else 6.dp)
                            .clip(RoundedCornerShape(3.dp))
                            .background(
                                if (isCurrent) Color(0xFFF59E0B)
                                else MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.5f)
                            )
                            .pointerHoverIcon(PointerIcon.Hand)
                            .clickable { currentIndex = index }
                    )
                }
            }
        }
    }
}
