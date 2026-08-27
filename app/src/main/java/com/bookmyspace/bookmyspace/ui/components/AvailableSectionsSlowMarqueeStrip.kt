package com.bookmyspace.bookmyspace.ui.components

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.gestures.animateScrollBy
import androidx.compose.foundation.gestures.snapping.rememberSnapFlingBehavior
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.ChevronRight
import androidx.compose.material.icons.filled.Layers
import androidx.compose.material.icons.filled.Stars
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.bookmyspace.bookmyspace.data.repository.BookMySpaceRepository
import kotlinx.coroutines.delay
import kotlinx.coroutines.isActive

data class AvailableSectionMarqueeItem(
    val id: String,
    val title: String,
    val subtitle: String,
    val emoji: String,
    val liveCount: String,
    val tag: String,
    val gradientColors: List<Color>
)

/**
 * High-performance, gentle continuous right-to-left marquee strip
 * highlighting all available sections and spaces in the platform.
 */
@Composable
fun AvailableSectionsSlowMarqueeStrip(
    onSelectSection: (String) -> Unit,
    onAddOtherCategory: () -> Unit,
    modifier: Modifier = Modifier
) {
    val venues by BookMySpaceRepository.venues.collectAsState()
    val appSections by BookMySpaceRepository.appSections.collectAsState()
    val categories by BookMySpaceRepository.categories.collectAsState()

    val sectionItems = remember(venues, appSections, categories) {
        val list = mutableListOf<AvailableSectionMarqueeItem>()

        if (BookMySpaceRepository.isSectionEnabled("venues_function_halls")) {
            val count = venues.count { (it.category?.slug ?: "") in listOf("function_hall", "marriage_hall", "convention_center", "banquet_hall", "community_hall", "govt_hall", "party_lawn", "other_hall") }
            list.add(
                AvailableSectionMarqueeItem(
                    id = "function_halls",
                    title = "Function Halls",
                    subtitle = "Marriage, Banquets & Lawns",
                    emoji = "🏛️",
                    liveCount = "$count Spaces",
                    tag = "INSTANT BOOK",
                    gradientColors = listOf(Color(0xFFE11D48), Color(0xFFFB7185))
                )
            )
        }

        if (BookMySpaceRepository.isSectionEnabled("hotels_rooms")) {
            val count = venues.count { (it.category?.slug ?: "") in listOf("hotel", "hotel_stay", "lodge", "guest_house", "hourly_room", "resort", "other_stay") }
            list.add(
                AvailableSectionMarqueeItem(
                    id = "lodge_rooms",
                    title = "Lodge / Rooms",
                    subtitle = "24h Hotels, Lodges & Day Stays",
                    emoji = "🏨",
                    liveCount = "$count Available",
                    tag = "24/7 CHECK-IN",
                    gradientColors = listOf(Color(0xFF0284C7), Color(0xFF38BDF8))
                )
            )
        }

        if (BookMySpaceRepository.isSectionEnabled("pg_hostels")) {
            val count = venues.count { (it.category?.slug ?: "") in listOf("pg_hostel", "gents_pg", "ladies_pg", "student_hostel", "co_living", "single_room", "other_pg") }
            list.add(
                AvailableSectionMarqueeItem(
                    id = "pg_hostels",
                    title = "PG / Hostels",
                    subtitle = "Men, Women & Co-Living Stays",
                    emoji = "🏠",
                    liveCount = "$count Verified",
                    tag = "FOOD & WIFI",
                    gradientColors = listOf(Color(0xFF7C3AED), Color(0xFFA78BFA))
                )
            )
        }

        if (BookMySpaceRepository.isSectionEnabled("institutes_classes")) {
            val count = venues.count { (it.category?.slug ?: "") in listOf("coaching", "computer_it", "dance_academy", "music_class", "sports_academy", "other_class") }
            list.add(
                AvailableSectionMarqueeItem(
                    id = "institutes_classes",
                    title = "Institutes / Classes",
                    subtitle = "Coaching, IT, Dance & Sports",
                    emoji = "🎓",
                    liveCount = "$count Academies",
                    tag = "FREE DEMO",
                    gradientColors = listOf(Color(0xFFEA580C), Color(0xFFFB923C))
                )
            )
        }

        // Custom & Other Spaces Section
        val customCount = categories.count { it.parentSection != null || it.slug.startsWith("other") }
        list.add(
            AvailableSectionMarqueeItem(
                id = "other_spaces",
                title = "Other & Custom Spaces",
                subtitle = "Studios, Gaming, Ashrams & Stays",
                emoji = "🎪",
                liveCount = "$customCount Categories",
                tag = "+ ADD ANY",
                gradientColors = listOf(Color(0xFF0D9488), Color(0xFF14B8A6))
            )
        )

        list
    }

    if (sectionItems.isEmpty()) return

    val listState = rememberLazyListState()

    // Smooth continuous right-to-left scroll animation
    LaunchedEffect(sectionItems.size) {
        if (sectionItems.size > 1) {
            while (isActive) {
                delay(3000L)
                if (!listState.isScrollInProgress) {
                    try {
                        val totalItems = sectionItems.size + 1
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
            .testTag("available_sections_marquee_strip")
    ) {
        // Marquee Header
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 4.dp, vertical = 6.dp),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically
        ) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Icon(
                    imageVector = Icons.Default.Layers,
                    contentDescription = null,
                    tint = MaterialTheme.colorScheme.primary,
                    modifier = Modifier.size(17.dp)
                )
                Spacer(modifier = Modifier.width(6.dp))
                Text(
                    text = "Available Sections",
                    fontWeight = FontWeight.ExtraBold,
                    fontSize = 14.5.sp,
                    color = MaterialTheme.colorScheme.onSurface
                )
                Spacer(modifier = Modifier.width(6.dp))
                Surface(
                    shape = RoundedCornerShape(6.dp),
                    color = MaterialTheme.colorScheme.primaryContainer.copy(alpha = 0.6f)
                ) {
                    Text(
                        text = "LIVE",
                        fontSize = 9.5.sp,
                        fontWeight = FontWeight.Black,
                        color = MaterialTheme.colorScheme.onPrimaryContainer,
                        modifier = Modifier.padding(horizontal = 5.dp, vertical = 2.dp)
                    )
                }
            }

            // Add Category Quick Button
            TextButton(
                onClick = onAddOtherCategory,
                contentPadding = PaddingValues(horizontal = 8.dp, vertical = 2.dp)
            ) {
                Icon(
                    imageVector = Icons.Default.Add,
                    contentDescription = null,
                    modifier = Modifier.size(14.dp)
                )
                Spacer(modifier = Modifier.width(3.dp))
                Text("+ Other Category", fontSize = 11.5.sp, fontWeight = FontWeight.Bold)
            }
        }

        val snapFlingBehavior = rememberSnapFlingBehavior(lazyListState = listState)

        // Horizontal Scrolling Row with Scroll-Snap Behavior
        LazyRow(
            state = listState,
            flingBehavior = snapFlingBehavior,
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(10.dp),
            contentPadding = PaddingValues(horizontal = 4.dp)
        ) {
            itemsIndexed(
                items = sectionItems,
                key = { _, item -> "section_marquee_${item.id}" }
            ) { index, item ->
                Card(
                    shape = RoundedCornerShape(16.dp),
                    colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface),
                    border = BorderStroke(1.dp, MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.45f)),
                    elevation = CardDefaults.cardElevation(defaultElevation = 1.dp),
                    modifier = Modifier
                        .width(175.dp)
                        .clickable {
                            if (item.id == "other_spaces") {
                                onAddOtherCategory()
                            } else {
                                onSelectSection(item.id)
                            }
                        }
                        .testTag("marquee_section_item_${item.id}")
                ) {
                    Column(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(12.dp)
                    ) {
                        Row(
                            modifier = Modifier.fillMaxWidth(),
                            horizontalArrangement = Arrangement.SpaceBetween,
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            Box(
                                modifier = Modifier
                                    .size(34.dp)
                                    .clip(CircleShape)
                                    .background(Brush.linearGradient(item.gradientColors)),
                                contentAlignment = Alignment.Center
                            ) {
                                Text(text = item.emoji, fontSize = 17.sp)
                            }

                            Surface(
                                shape = RoundedCornerShape(5.dp),
                                color = item.gradientColors.first().copy(alpha = 0.12f)
                            ) {
                                Text(
                                    text = item.tag,
                                    fontSize = 8.5.sp,
                                    fontWeight = FontWeight.Black,
                                    color = item.gradientColors.first(),
                                    modifier = Modifier.padding(horizontal = 5.dp, vertical = 2.dp)
                                )
                            }
                        }

                        Spacer(modifier = Modifier.height(8.dp))

                        Text(
                            text = item.title,
                            fontWeight = FontWeight.Bold,
                            fontSize = 13.5.sp,
                            color = MaterialTheme.colorScheme.onSurface,
                            maxLines = 1
                        )

                        Text(
                            text = item.subtitle,
                            fontSize = 10.5.sp,
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                            maxLines = 1
                        )

                        Spacer(modifier = Modifier.height(4.dp))

                        Row(
                            modifier = Modifier.fillMaxWidth(),
                            horizontalArrangement = Arrangement.SpaceBetween,
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            Text(
                                text = item.liveCount,
                                fontSize = 11.sp,
                                fontWeight = FontWeight.SemiBold,
                                color = item.gradientColors.first()
                            )
                            Icon(
                                imageVector = Icons.Default.ChevronRight,
                                contentDescription = null,
                                tint = MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.5f),
                                modifier = Modifier.size(14.dp)
                            )
                        }
                    }
                }
            }

            // Quick "+ Add Category" Card at end of Row
            item {
                Card(
                    shape = RoundedCornerShape(16.dp),
                    colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.primaryContainer.copy(alpha = 0.35f)),
                    border = BorderStroke(1.dp, MaterialTheme.colorScheme.primary.copy(alpha = 0.35f)),
                    modifier = Modifier
                        .width(140.dp)
                        .clickable { onAddOtherCategory() }
                        .testTag("marquee_add_category_card")
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
                                .size(34.dp)
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
                        Spacer(modifier = Modifier.height(6.dp))
                        Text(
                            text = "+ Add Other",
                            fontWeight = FontWeight.Bold,
                            fontSize = 12.5.sp,
                            color = MaterialTheme.colorScheme.primary
                        )
                        Text(
                            text = "Any Category",
                            fontSize = 10.sp,
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                    }
                }
            }
        }
    }
}
