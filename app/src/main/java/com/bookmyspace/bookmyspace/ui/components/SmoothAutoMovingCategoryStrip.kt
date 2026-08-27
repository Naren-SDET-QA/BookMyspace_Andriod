package com.bookmyspace.bookmyspace.ui.components

import androidx.compose.animation.core.Spring
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.spring
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.gestures.animateScrollBy
import androidx.compose.foundation.gestures.snapping.rememberSnapFlingBehavior
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.interaction.collectIsPressedAsState
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.ChevronRight
import androidx.compose.material.icons.filled.TrendingUp
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import kotlinx.coroutines.delay
import kotlinx.coroutines.isActive
import kotlinx.coroutines.isActive

data class AutoMovingCategory(
    val id: String,
    val title: String,
    val emoji: String,
    val subtitle: String,
    val tag: String,
    val gradientColors: List<Color>,
    val targetSection: String
)

/**
 * High-performance, silky smooth horizontal category ticker.
 * Automatically scrolls gently from right to left with zero frame drop or GC overhead.
 * Automatically pauses when user interacts/touches, and seamlessly loops indefinitely.
 */
@Composable
fun SmoothAutoMovingCategoryStrip(
    onSelectCategory: (targetSection: String, categorySlug: String) -> Unit,
    onAddOtherCategory: () -> Unit = {},
    modifier: Modifier = Modifier
) {
    val baseCategories = remember {
        listOf(
            AutoMovingCategory(
                id = "turf",
                title = "Sports Turfs",
                emoji = "🏟️",
                subtitle = "From ₹600/hr",
                tag = "🔥 HOT",
                gradientColors = listOf(Color(0xFF059669), Color(0xFF10B981)),
                targetSection = "sports"
            ),
            AutoMovingCategory(
                id = "marriage_hall",
                title = "Marriage Halls",
                emoji = "💒",
                subtitle = "From ₹15k/day",
                tag = "⚡ INSTANT",
                gradientColors = listOf(Color(0xFFE11D48), Color(0xFFFB7185)),
                targetSection = "function_halls"
            ),
            AutoMovingCategory(
                id = "hotel",
                title = "24h Lodge Rooms",
                emoji = "🏨",
                subtitle = "From ₹899/night",
                tag = "⭐ 4.8★",
                gradientColors = listOf(Color(0xFF0284C7), Color(0xFF38BDF8)),
                targetSection = "lodge_rooms"
            ),
            AutoMovingCategory(
                id = "gents_pg",
                title = "Men's PGs",
                emoji = "🏠",
                subtitle = "From ₹4,500/mo",
                tag = "🍲 FOOD INCL",
                gradientColors = listOf(Color(0xFF7C3AED), Color(0xFFA78BFA)),
                targetSection = "pg_hostels"
            ),
            AutoMovingCategory(
                id = "ladies_pg",
                title = "Women's Hostels",
                emoji = "🌸",
                subtitle = "From ₹5,500/mo",
                tag = "🔒 SECURE",
                gradientColors = listOf(Color(0xFFDB2777), Color(0xFFF472B6)),
                targetSection = "pg_hostels"
            ),
            AutoMovingCategory(
                id = "party_lawn",
                title = "Open Party Lawns",
                emoji = "🌴",
                subtitle = "From ₹25k/day",
                tag = "✨ POPULAR",
                gradientColors = listOf(Color(0xFF16A34A), Color(0xFF4ADE80)),
                targetSection = "function_halls"
            ),
            AutoMovingCategory(
                id = "dance_academy",
                title = "Dance & Studios",
                emoji = "💃",
                subtitle = "From ₹350/hr",
                tag = "🎵 TOP RATED",
                gradientColors = listOf(Color(0xFFD97706), Color(0xFFFBBF24)),
                targetSection = "institutes_classes"
            ),
            AutoMovingCategory(
                id = "badminton",
                title = "Badminton Arenas",
                emoji = "🏸",
                subtitle = "From ₹400/hr",
                tag = "⚡ 1-TAP",
                gradientColors = listOf(Color(0xFF4F46E5), Color(0xFF818CF8)),
                targetSection = "sports"
            ),
            AutoMovingCategory(
                id = "co_living",
                title = "Luxury Co-Living",
                emoji = "🏢",
                subtitle = "From ₹7,000/mo",
                tag = "🌐 HIGH-SPEED WIFI",
                gradientColors = listOf(Color(0xFF0891B2), Color(0xFF22D3EE)),
                targetSection = "pg_hostels"
            ),
            AutoMovingCategory(
                id = "tuition_room",
                title = "Coaching Classes",
                emoji = "📚",
                subtitle = "From ₹500/hr",
                tag = "🎓 AC ROOMS",
                gradientColors = listOf(Color(0xFF4338CA), Color(0xFF6366F1)),
                targetSection = "institutes_classes"
            ),
            AutoMovingCategory(
                id = "other_hall",
                title = "Other Event Spaces",
                emoji = "🎪",
                subtitle = "Exhibitions & Stages",
                tag = "🎪 CUSTOM",
                gradientColors = listOf(Color(0xFFBE185D), Color(0xFFF43F5E)),
                targetSection = "function_halls"
            ),
            AutoMovingCategory(
                id = "other_stay",
                title = "Other Stays & Rentals",
                emoji = "🏕️",
                subtitle = "Farmhouses & Cottages",
                tag = "🌲 GETAWAY",
                gradientColors = listOf(Color(0xFF0D9488), Color(0xFF14B8A6)),
                targetSection = "lodge_rooms"
            ),
            AutoMovingCategory(
                id = "other_pg",
                title = "Other Hostels & PGs",
                emoji = "🏡",
                subtitle = "Studios & Custom Living",
                tag = "🔑 FLEXIBLE",
                gradientColors = listOf(Color(0xFF6366F1), Color(0xFF8B5CF6)),
                targetSection = "pg_hostels"
            ),
            AutoMovingCategory(
                id = "other_class",
                title = "Other Classes & Studios",
                emoji = "🎨",
                subtitle = "Art, Yoga & Workshops",
                tag = "✨ DISCOVER",
                gradientColors = listOf(Color(0xFFEA580C), Color(0xFFFB923C)),
                targetSection = "institutes_classes"
            )
        )
    }

    val categoriesState by com.bookmyspace.bookmyspace.data.repository.BookMySpaceRepository.categories.collectAsState()
    val appSectionsState by com.bookmyspace.bookmyspace.data.repository.BookMySpaceRepository.appSections.collectAsState()

    val activeTickerCategories = remember(categoriesState, appSectionsState) {
        val baseFiltered = baseCategories.filter { cat ->
            com.bookmyspace.bookmyspace.data.repository.BookMySpaceRepository.isCategoryEnabled(cat.id) &&
            com.bookmyspace.bookmyspace.data.repository.BookMySpaceRepository.isSectionEnabled(cat.targetSection)
        }.toMutableList()

        // Dynamically append user-created custom categories into the ticker
        val customCats = categoriesState.filter { it.parentSection != null && it.isActive }
        for (c in customCats) {
            baseFiltered.add(
                AutoMovingCategory(
                    id = c.slug,
                    title = c.name,
                    emoji = c.icon,
                    subtitle = "Explore Spaces",
                    tag = "✨ NEW",
                    gradientColors = listOf(Color(0xFF6366F1), Color(0xFF8B5CF6)),
                    targetSection = c.parentSection ?: "function_halls"
                )
            )
        }
        baseFiltered
    }

    if (activeTickerCategories.isEmpty()) {
        return
    }

    // High-performance LazyRow for smooth scrolling with zero main-thread pressure
    val listState = rememberLazyListState()

    // Smooth auto-scroll from right to left without blocking or lagging the UI
    LaunchedEffect(activeTickerCategories.size) {
        if (activeTickerCategories.size > 1) {
            while (isActive) {
                delay(3000L)
                if (!listState.isScrollInProgress) {
                    try {
                        val totalItems = activeTickerCategories.size + 1
                        val nextIndex = (listState.firstVisibleItemIndex + 1) % totalItems
                        listState.animateScrollToItem(nextIndex)
                    } catch (_: Exception) {
                        // ignore cancellation from user touch interaction
                    }
                }
            }
        }
    }

    Column(
        modifier = modifier
            .fillMaxWidth()
            .testTag("smooth_auto_moving_category_section")
    ) {
        // Section Header
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 4.dp, vertical = 6.dp),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically
        ) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Icon(
                    imageVector = Icons.Default.TrendingUp,
                    contentDescription = null,
                    tint = MaterialTheme.colorScheme.primary,
                    modifier = Modifier.size(18.dp)
                )
                Spacer(modifier = Modifier.width(6.dp))
                Text(
                    text = "Trending Categories",
                    fontWeight = FontWeight.ExtraBold,
                    fontSize = 15.sp,
                    color = MaterialTheme.colorScheme.onSurface
                )
            }
            Row(verticalAlignment = Alignment.CenterVertically) {
                TextButton(
                    onClick = onAddOtherCategory,
                    contentPadding = PaddingValues(horizontal = 6.dp, vertical = 2.dp)
                ) {
                    Icon(
                        imageVector = Icons.Default.Add,
                        contentDescription = null,
                        modifier = Modifier.size(14.dp)
                    )
                    Spacer(modifier = Modifier.width(2.dp))
                    Text("+ Add Other", fontSize = 11.5.sp, fontWeight = FontWeight.Bold)
                }
                Spacer(modifier = Modifier.width(4.dp))
                Surface(
                    shape = RoundedCornerShape(8.dp),
                    color = MaterialTheme.colorScheme.primary.copy(alpha = 0.12f)
                ) {
                    Row(
                        modifier = Modifier.padding(horizontal = 8.dp, vertical = 3.dp),
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Text(
                            text = "LIVE",
                            fontSize = 10.sp,
                            fontWeight = FontWeight.Black,
                            color = MaterialTheme.colorScheme.primary
                        )
                        Spacer(modifier = Modifier.width(4.dp))
                        Text(
                            text = "• Auto",
                            fontSize = 10.sp,
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                    }
                }
            }
        }

        Spacer(modifier = Modifier.height(4.dp))

        val snapFlingBehavior = rememberSnapFlingBehavior(lazyListState = listState)

        // High-Performance Horizontal LazyRow with Scroll-Snap Behavior
        LazyRow(
            state = listState,
            flingBehavior = snapFlingBehavior,
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(10.dp),
            contentPadding = PaddingValues(horizontal = 4.dp)
        ) {
            itemsIndexed(
                items = activeTickerCategories,
                key = { _, cat -> "ticker_${cat.id}" }
            ) { index, cat ->
                AutoMovingCategoryCard(
                    category = cat,
                    onClick = { onSelectCategory(cat.targetSection, cat.id) },
                    modifier = Modifier.testTag("auto_category_item_${cat.id}_$index")
                )
            }

            // Quick "+ Add Category" Card
            item {
                val addInteractionSource = remember { MutableInteractionSource() }
                val isAddPressed by addInteractionSource.collectIsPressedAsState()
                val addScale by animateFloatAsState(
                    targetValue = if (isAddPressed) 0.94f else 1.0f,
                    animationSpec = spring(dampingRatio = Spring.DampingRatioMediumBouncy),
                    label = "add_card_scale"
                )

                Card(
                    shape = RoundedCornerShape(18.dp),
                    colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.primaryContainer.copy(alpha = 0.35f)),
                    border = BorderStroke(1.dp, MaterialTheme.colorScheme.primary.copy(alpha = 0.35f)),
                    elevation = CardDefaults.cardElevation(defaultElevation = 1.dp),
                    modifier = Modifier
                        .width(150.dp)
                        .graphicsLayer {
                            scaleX = addScale
                            scaleY = addScale
                        }
                        .clickable(
                            interactionSource = addInteractionSource,
                            indication = ripple(bounded = true),
                            onClick = { onAddOtherCategory() }
                        )
                        .testTag("ticker_add_category_card")
                ) {
                    Column(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(12.dp),
                        horizontalAlignment = Alignment.CenterHorizontally,
                        verticalArrangement = Arrangement.Center
                    ) {
                        Box(
                            modifier = Modifier
                                .size(36.dp)
                                .clip(CircleShape)
                                .background(MaterialTheme.colorScheme.primary),
                            contentAlignment = Alignment.Center
                        ) {
                            Icon(
                                imageVector = Icons.Default.Add,
                                contentDescription = null,
                                tint = MaterialTheme.colorScheme.onPrimary,
                                modifier = Modifier.size(20.dp)
                            )
                        }
                        Spacer(modifier = Modifier.height(8.dp))
                        Text(
                            text = "+ Add Other",
                            fontWeight = FontWeight.Bold,
                            fontSize = 13.sp,
                            color = MaterialTheme.colorScheme.primary
                        )
                        Text(
                            text = "Any Category",
                            fontSize = 11.sp,
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                    }
                }
            }
        }
    }
}

@Composable
private fun AutoMovingCategoryCard(
    category: AutoMovingCategory,
    onClick: () -> Unit,
    modifier: Modifier = Modifier
) {
    val interactionSource = remember { MutableInteractionSource() }
    val isPressed by interactionSource.collectIsPressedAsState()
    val cardScale by animateFloatAsState(
        targetValue = if (isPressed) 0.94f else 1.0f,
        animationSpec = spring(
            dampingRatio = Spring.DampingRatioMediumBouncy,
            stiffness = Spring.StiffnessMediumLow
        ),
        label = "auto_category_card_scale"
    )

    Card(
        shape = RoundedCornerShape(18.dp),
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface),
        border = BorderStroke(1.dp, MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.45f)),
        elevation = CardDefaults.cardElevation(defaultElevation = 1.dp),
        modifier = modifier
            .width(160.dp)
            .graphicsLayer {
                scaleX = cardScale
                scaleY = cardScale
            }
            .clickable(
                interactionSource = interactionSource,
                indication = ripple(bounded = true),
                onClick = onClick
            )
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(12.dp)
        ) {
            // Top Row: Emoji Icon with Gradient Background + Tag Badge
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Box(
                    modifier = Modifier
                        .size(36.dp)
                        .clip(CircleShape)
                        .background(Brush.linearGradient(category.gradientColors)),
                    contentAlignment = Alignment.Center
                ) {
                    Text(text = category.emoji, fontSize = 18.sp)
                }

                Surface(
                    shape = RoundedCornerShape(6.dp),
                    color = category.gradientColors.first().copy(alpha = 0.15f)
                ) {
                    Text(
                        text = category.tag,
                        fontSize = 8.5.sp,
                        fontWeight = FontWeight.Black,
                        color = category.gradientColors.first(),
                        modifier = Modifier.padding(horizontal = 5.dp, vertical = 2.dp)
                    )
                }
            }

            Spacer(modifier = Modifier.height(10.dp))

            // Title
            Text(
                text = category.title,
                fontWeight = FontWeight.Bold,
                fontSize = 13.5.sp,
                color = MaterialTheme.colorScheme.onSurface,
                maxLines = 1
            )

            Spacer(modifier = Modifier.height(2.dp))

            // Price / Info Subtitle + Arrow
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Text(
                    text = category.subtitle,
                    fontSize = 11.5.sp,
                    fontWeight = FontWeight.SemiBold,
                    color = category.gradientColors.first()
                )

                Icon(
                    imageVector = Icons.Default.ChevronRight,
                    contentDescription = null,
                    tint = MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.6f),
                    modifier = Modifier.size(14.dp)
                )
            }
        }
    }
}
