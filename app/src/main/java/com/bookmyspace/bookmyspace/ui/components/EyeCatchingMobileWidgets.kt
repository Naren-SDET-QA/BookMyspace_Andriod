package com.bookmyspace.bookmyspace.ui.components

import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.widget.Toast
import androidx.compose.animation.*
import androidx.compose.animation.core.*
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.pager.HorizontalPager
import androidx.compose.foundation.pager.rememberPagerState
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.bookmyspace.bookmyspace.data.model.LocationHierarchy
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

/**
 * Data Model for Hot Deals & Flash Offers
 */
data class HotDeal(
    val id: String,
    val tag: String,
    val title: String,
    val subtitle: String,
    val promoCode: String,
    val discountText: String,
    val expiryTime: String,
    val gradientColors: List<Color>,
    val emoji: String,
    val targetSection: String
)

/**
 * 1. 🔥 EYE-CATCHING HOT DEALS & FLASH OFFERS CAROUSEL WIDGET
 * Interactive, auto-animating promotional cards with pulsing timer, vibrant gradients, and 1-tap copy/claim.
 */
@Composable
fun HotDealsCarouselWidget(
    onSelectDeal: (HotDeal) -> Unit = {},
    modifier: Modifier = Modifier
) {
    val context = LocalContext.current
    val deals = remember {
        listOf(
            HotDeal(
                id = "deal_1",
                tag = "🔥 FLASH DEAL",
                title = "Grand Marriage & Banquet Halls",
                subtitle = "Up to 35% OFF on Advance Bookings + Free AC Suite",
                promoCode = "ROYALWED35",
                discountText = "35% OFF",
                expiryTime = "Ends in 03h 45m",
                gradientColors = listOf(Color(0xFFE11D48), Color(0xFF9333EA), Color(0xFF4F46E5)),
                emoji = "💒",
                targetSection = "function_halls"
            ),
            HotDeal(
                id = "deal_2",
                tag = "⚡ INSTANT STAY",
                title = "Hotels, Lodges & Day Rooms",
                subtitle = "Flat ₹600 OFF on 24-Hour & Hourly Check-ins",
                promoCode = "FASTSTAY600",
                discountText = "₹600 OFF",
                expiryTime = "Today Only",
                gradientColors = listOf(Color(0xFF0284C7), Color(0xFF0D9488), Color(0xFF10B981)),
                emoji = "🏨",
                targetSection = "lodge_rooms"
            ),
            HotDeal(
                id = "deal_3",
                tag = "🏠 MONTHLY SAVE",
                title = "Gents & Ladies PG Hostels",
                subtitle = "Zero Security Deposit + Free High-Speed WiFi Month",
                promoCode = "ZEROPG",
                discountText = "Zero Deposit",
                expiryTime = "Limited Beds",
                gradientColors = listOf(Color(0xFFD97706), Color(0xFFEA580C), Color(0xFFC026D3)),
                emoji = "🛏️",
                targetSection = "pg_hostels"
            ),
            HotDeal(
                id = "deal_4",
                tag = "🎓 EARLY BIRD",
                title = "Dance, Music & IT Academies",
                subtitle = "25% Cashback on First Batch Enrolment + Free Demo Class",
                promoCode = "SKILL25",
                discountText = "25% BACK",
                expiryTime = "5 Seats Left",
                gradientColors = listOf(Color(0xFF7C3AED), Color(0xFF2563EB), Color(0xFF06B6D4)),
                emoji = "🎯",
                targetSection = "institutes_classes"
            )
        )
    }

    val pagerState = rememberPagerState(initialPage = 0, pageCount = { deals.size })

    // Auto-scroll effect
    LaunchedEffect(Unit) {
        while (true) {
            delay(5000)
            if (!pagerState.isScrollInProgress) {
                val nextPage = (pagerState.currentPage + 1) % deals.size
                pagerState.animateScrollToPage(nextPage)
            }
        }
    }

    Column(
        modifier = modifier
            .fillMaxWidth()
            .testTag("hot_deals_carousel_widget")
    ) {
        // Carousel Header
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 4.dp),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically
        ) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Box(
                    modifier = Modifier
                        .size(10.dp)
                        .clip(CircleShape)
                        .background(Color(0xFFEF4444))
                        .pulsingGlow(minAlpha = 0.3f, maxAlpha = 1.0f, durationMillis = 800)
                )
                Spacer(modifier = Modifier.width(8.dp))
                Text(
                    text = "Spotlight & Hot Deals",
                    fontSize = 15.sp,
                    fontWeight = FontWeight.Black,
                    letterSpacing = (-0.3).sp,
                    color = MaterialTheme.colorScheme.onBackground
                )
            }

            // Pager Indicators
            Row(
                horizontalArrangement = Arrangement.spacedBy(4.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                repeat(deals.size) { index ->
                    val isSelected = pagerState.currentPage == index
                    Box(
                        modifier = Modifier
                            .height(6.dp)
                            .width(if (isSelected) 18.dp else 6.dp)
                            .clip(RoundedCornerShape(3.dp))
                            .background(
                                if (isSelected) MaterialTheme.colorScheme.primary
                                else MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.6f)
                            )
                    )
                }
            }
        }

        Spacer(modifier = Modifier.height(10.dp))

        // Pager
        HorizontalPager(
            state = pagerState,
            modifier = Modifier.fillMaxWidth(),
            pageSpacing = 12.dp
        ) { page ->
            val deal = deals[page]
            Card(
                shape = RoundedCornerShape(22.dp),
                elevation = CardDefaults.cardElevation(defaultElevation = 4.dp),
                modifier = Modifier
                    .fillMaxWidth()
                    .clickable {
                        val clipboard = context.getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
                        val clip = ClipData.newPlainText("Promo Code", deal.promoCode)
                        clipboard.setPrimaryClip(clip)
                        Toast.makeText(context, "🎁 Code ${deal.promoCode} copied!", Toast.LENGTH_SHORT).show()
                        onSelectDeal(deal)
                    }
                    .testTag("hot_deal_card_${deal.id}")
            ) {
                Box(
                    modifier = Modifier
                        .fillMaxWidth()
                        .background(
                            Brush.linearGradient(
                                colors = deal.gradientColors,
                                start = Offset(0f, 0f),
                                end = Offset(1000f, 600f)
                            )
                        )
                        .padding(18.dp)
                ) {
                    Column {
                        // Top Row: Tag & Timer
                        Row(
                            modifier = Modifier.fillMaxWidth(),
                            horizontalArrangement = Arrangement.SpaceBetween,
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            Surface(
                                shape = RoundedCornerShape(12.dp),
                                color = Color.White.copy(alpha = 0.25f),
                                border = BorderStroke(1.dp, Color.White.copy(alpha = 0.4f))
                            ) {
                                Row(
                                    modifier = Modifier.padding(horizontal = 8.dp, vertical = 4.dp),
                                    verticalAlignment = Alignment.CenterVertically
                                ) {
                                    Text(deal.emoji, fontSize = 12.sp)
                                    Spacer(modifier = Modifier.width(4.dp))
                                    Text(
                                        text = deal.tag,
                                        color = Color.White,
                                        fontSize = 10.5.sp,
                                        fontWeight = FontWeight.ExtraBold,
                                        letterSpacing = 0.5.sp
                                    )
                                }
                            }

                            Surface(
                                shape = RoundedCornerShape(12.dp),
                                color = Color.Black.copy(alpha = 0.35f)
                            ) {
                                Row(
                                    modifier = Modifier.padding(horizontal = 8.dp, vertical = 4.dp),
                                    verticalAlignment = Alignment.CenterVertically
                                ) {
                                    Icon(
                                        imageVector = Icons.Default.AccessTime,
                                        contentDescription = null,
                                        tint = Color(0xFFFFD54F),
                                        modifier = Modifier.size(12.dp)
                                    )
                                    Spacer(modifier = Modifier.width(4.dp))
                                    Text(
                                        text = deal.expiryTime,
                                        color = Color(0xFFFFD54F),
                                        fontSize = 10.sp,
                                        fontWeight = FontWeight.Bold
                                    )
                                }
                            }
                        }

                        Spacer(modifier = Modifier.height(10.dp))

                        // Title & Subtitle
                        Text(
                            text = deal.title,
                            color = Color.White,
                            fontSize = 17.sp,
                            fontWeight = FontWeight.Black,
                            lineHeight = 22.sp,
                            maxLines = 1,
                            overflow = TextOverflow.Ellipsis
                        )
                        Spacer(modifier = Modifier.height(2.dp))
                        Text(
                            text = deal.subtitle,
                            color = Color.White.copy(alpha = 0.9f),
                            fontSize = 12.sp,
                            lineHeight = 16.sp,
                            maxLines = 2,
                            overflow = TextOverflow.Ellipsis
                        )

                        Spacer(modifier = Modifier.height(14.dp))

                        // Bottom Action Row: Promo Chip & Copy Action
                        Row(
                            modifier = Modifier.fillMaxWidth(),
                            horizontalArrangement = Arrangement.SpaceBetween,
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            Surface(
                                shape = RoundedCornerShape(10.dp),
                                color = Color.White.copy(alpha = 0.2f),
                                border = BorderStroke(1.dp, Color.White.copy(alpha = 0.5f))
                            ) {
                                Row(
                                    modifier = Modifier.padding(horizontal = 10.dp, vertical = 6.dp),
                                    verticalAlignment = Alignment.CenterVertically
                                ) {
                                    Text(
                                        text = "USE CODE: ",
                                        color = Color.White.copy(alpha = 0.8f),
                                        fontSize = 10.sp,
                                        fontWeight = FontWeight.SemiBold
                                    )
                                    Text(
                                        text = deal.promoCode,
                                        color = Color.White,
                                        fontSize = 12.sp,
                                        fontWeight = FontWeight.Black,
                                        letterSpacing = 0.5.sp
                                    )
                                }
                            }

                            Surface(
                                shape = RoundedCornerShape(12.dp),
                                color = Color.White,
                                shadowElevation = 2.dp
                            ) {
                                Row(
                                    modifier = Modifier.padding(horizontal = 12.dp, vertical = 7.dp),
                                    verticalAlignment = Alignment.CenterVertically
                                ) {
                                    Text(
                                        text = "Claim Deal",
                                        color = Color(0xFF1E293B),
                                        fontSize = 12.sp,
                                        fontWeight = FontWeight.Bold
                                    )
                                    Spacer(modifier = Modifier.width(4.dp))
                                    Icon(
                                        imageVector = Icons.Default.ArrowForward,
                                        contentDescription = null,
                                        tint = Color(0xFF1E293B),
                                        modifier = Modifier.size(13.dp)
                                    )
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

/**
 * 2. 🎯 SMART SPACE RADAR & QUICK FINDER WIDGET
 * Live radar wave pulse animation with local venue availability count and 1-tap quick launchers.
 */
@Composable
fun SmartSpaceRadarWidget(
    location: LocationHierarchy,
    availableSpacesCount: Int,
    onQuickSearchCategory: (String) -> Unit = {},
    modifier: Modifier = Modifier
) {
    val infiniteTransition = rememberInfiniteTransition(label = "radarTransition")
    val pulseScale by infiniteTransition.animateFloat(
        initialValue = 0.6f,
        targetValue = 1.4f,
        animationSpec = infiniteRepeatable(
            animation = tween(2000, easing = LinearEasing),
            repeatMode = RepeatMode.Restart
        ),
        label = "radarPulse"
    )
    val pulseAlpha by infiniteTransition.animateFloat(
        initialValue = 0.7f,
        targetValue = 0.0f,
        animationSpec = infiniteRepeatable(
            animation = tween(2000, easing = LinearEasing),
            repeatMode = RepeatMode.Restart
        ),
        label = "radarAlpha"
    )

    Card(
        shape = RoundedCornerShape(22.dp),
        colors = CardDefaults.cardColors(
            containerColor = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.5f)
        ),
        border = BorderStroke(1.dp, MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.4f)),
        modifier = modifier
            .fillMaxWidth()
            .testTag("smart_space_radar_widget")
    ) {
        Column(modifier = Modifier.padding(16.dp)) {
            // Header with Live Radar Animation
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    modifier = Modifier.weight(1f)
                ) {
                    // Custom Radar Canvas
                    Box(
                        modifier = Modifier.size(34.dp),
                        contentAlignment = Alignment.Center
                    ) {
                        Canvas(modifier = Modifier.fillMaxSize()) {
                            // Pulsing outer wave
                            drawCircle(
                                color = Color(0xFF10B981).copy(alpha = pulseAlpha),
                                radius = size.minDimension / 2f * pulseScale
                            )
                            // Solid inner ring
                            drawCircle(
                                color = Color(0xFF10B981).copy(alpha = 0.2f),
                                radius = size.minDimension / 2.5f
                            )
                            // Center dot
                            drawCircle(
                                color = Color(0xFF10B981),
                                radius = size.minDimension / 6f
                            )
                        }
                    }

                    Spacer(modifier = Modifier.width(10.dp))

                    Column {
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            Text(
                                text = "Live Space Radar",
                                fontSize = 14.sp,
                                fontWeight = FontWeight.Black,
                                color = MaterialTheme.colorScheme.onSurface
                            )
                            Spacer(modifier = Modifier.width(6.dp))
                            Surface(
                                shape = RoundedCornerShape(6.dp),
                                color = Color(0xFF10B981).copy(alpha = 0.15f)
                            ) {
                                Text(
                                    text = "ACTIVE",
                                    fontSize = 9.sp,
                                    fontWeight = FontWeight.ExtraBold,
                                    color = Color(0xFF059669),
                                    modifier = Modifier.padding(horizontal = 5.dp, vertical = 2.dp)
                                )
                            }
                        }
                        Text(
                            text = "${location.shortLabel} • $availableSpacesCount+ Spaces Verified",
                            fontSize = 11.5.sp,
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                            maxLines = 1,
                            overflow = TextOverflow.Ellipsis
                        )
                    }
                }
            }

            Spacer(modifier = Modifier.height(14.dp))

            // Quick Category Launcher Pills
            val quickChips = listOf(
                Triple("marriage_hall", "💒 Weddings", Color(0xFFF43F5E)),
                Triple("hotel", "🏨 24h Rooms", Color(0xFF0EA5E9)),
                Triple("gents_pg", "🏠 Men PG", Color(0xFF8B5CF6)),
                Triple("ladies_pg", "🌸 Ladies PG", Color(0xFFEC4899)),
                Triple("party_lawn", "🌳 Open Lawns", Color(0xFF10B981)),
                Triple("dance_academy", "💃 Dance / Music", Color(0xFFF59E0B))
            )

            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .horizontalScroll(rememberScrollState()),
                horizontalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                quickChips.forEach { (slug, label, accentColor) ->
                    Surface(
                        onClick = { onQuickSearchCategory(slug) },
                        shape = RoundedCornerShape(14.dp),
                        color = accentColor.copy(alpha = 0.12f),
                        border = BorderStroke(1.dp, accentColor.copy(alpha = 0.3f)),
                        modifier = Modifier.testTag("radar_quick_chip_$slug")
                    ) {
                        Row(
                            modifier = Modifier.padding(horizontal = 12.dp, vertical = 8.dp),
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            Text(
                                text = label,
                                fontSize = 12.sp,
                                fontWeight = FontWeight.Bold,
                                color = MaterialTheme.colorScheme.onSurface
                            )
                        }
                    }
                }
            }
        }
    }
}

/**
 * 3. 🎁 DAILY LUCKY REWARD & ATTRACTION PASS WIDGET
 * Interactive gamified scratch/tap to reveal booking voucher coupon code.
 */
@Composable
fun DailyLuckyRewardWidget(
    modifier: Modifier = Modifier
) {
    val context = LocalContext.current
    var isRevealed by remember { mutableStateOf(false) }
    var rewardCode by remember { mutableStateOf("SUPERSPACE25") }
    var rewardTitle by remember { mutableStateOf("25% Instant Discount (Up to ₹1,500)") }

    Card(
        shape = RoundedCornerShape(22.dp),
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface),
        border = BorderStroke(1.dp, Color(0xFFFFB800).copy(alpha = 0.5f)),
        elevation = CardDefaults.cardElevation(defaultElevation = 2.dp),
        modifier = modifier
            .fillMaxWidth()
            .testTag("daily_lucky_reward_widget")
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .background(
                    Brush.linearGradient(
                        colors = listOf(
                            Color(0xFFFFFBEB),
                            Color(0xFFFEF3C7)
                        )
                    )
                )
                .padding(16.dp)
        ) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Text("🎡", fontSize = 22.sp)
                    Spacer(modifier = Modifier.width(8.dp))
                    Column {
                        Text(
                            text = "Daily Lucky Booking Pass",
                            fontWeight = FontWeight.Black,
                            fontSize = 14.sp,
                            color = Color(0xFF92400E)
                        )
                        Text(
                            text = if (isRevealed) "Code Unlocked! Tap to copy" else "Tap below to reveal today's instant reward",
                            fontSize = 11.sp,
                            color = Color(0xFFB45309)
                        )
                    }
                }
                Surface(
                    shape = RoundedCornerShape(8.dp),
                    color = Color(0xFFF59E0B)
                ) {
                    Text(
                        text = "FREE PASS",
                        fontSize = 9.sp,
                        fontWeight = FontWeight.ExtraBold,
                        color = Color.White,
                        modifier = Modifier.padding(horizontal = 6.dp, vertical = 3.dp)
                    )
                }
            }

            Spacer(modifier = Modifier.height(12.dp))

            // Interactive Scratch / Tap Reveal Card
            AnimatedContent(
                targetState = isRevealed,
                transitionSpec = {
                    fadeIn(animationSpec = tween(400)) + scaleIn(initialScale = 0.85f) togetherWith
                            fadeOut(animationSpec = tween(200))
                },
                label = "scratchReveal"
            ) { revealed ->
                if (!revealed) {
                    Surface(
                        onClick = {
                            isRevealed = true
                            Toast.makeText(context, "🎉 You won 25% Off! Code: SUPERSPACE25", Toast.LENGTH_SHORT).show()
                        },
                        shape = RoundedCornerShape(14.dp),
                        color = Color(0xFFD97706),
                        shadowElevation = 2.dp,
                        modifier = Modifier
                            .fillMaxWidth()
                            .height(52.dp)
                            .testTag("scratch_card_tap_button")
                    ) {
                        Row(
                            modifier = Modifier.fillMaxSize(),
                            verticalAlignment = Alignment.CenterVertically,
                            horizontalArrangement = Arrangement.Center
                        ) {
                            Text("✨", fontSize = 16.sp)
                            Spacer(modifier = Modifier.width(8.dp))
                            Text(
                                text = "TAP TO SCRATCH & UNLOCK CODE",
                                fontWeight = FontWeight.Black,
                                color = Color.White,
                                fontSize = 12.5.sp,
                                letterSpacing = 0.5.sp
                            )
                            Spacer(modifier = Modifier.width(8.dp))
                            Text("🎁", fontSize = 16.sp)
                        }
                    }
                } else {
                    Surface(
                        onClick = {
                            val clipboard = context.getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
                            val clip = ClipData.newPlainText("Promo Code", rewardCode)
                            clipboard.setPrimaryClip(clip)
                            Toast.makeText(context, "✅ Coupon '$rewardCode' copied to clipboard!", Toast.LENGTH_SHORT).show()
                        },
                        shape = RoundedCornerShape(14.dp),
                        color = Color.White,
                        border = BorderStroke(1.5.dp, Color(0xFF10B981)),
                        modifier = Modifier
                            .fillMaxWidth()
                            .testTag("scratched_reward_coupon_box")
                    ) {
                        Row(
                            modifier = Modifier
                                .fillMaxWidth()
                                .padding(horizontal = 14.dp, vertical = 10.dp),
                            horizontalArrangement = Arrangement.SpaceBetween,
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            Column {
                                Row(verticalAlignment = Alignment.CenterVertically) {
                                    Text(
                                        text = rewardCode,
                                        fontWeight = FontWeight.Black,
                                        fontSize = 15.sp,
                                        color = Color(0xFF047857),
                                        letterSpacing = 1.sp
                                    )
                                    Spacer(modifier = Modifier.width(6.dp))
                                    Text("🎉", fontSize = 13.sp)
                                }
                                Text(
                                    text = rewardTitle,
                                    fontSize = 11.sp,
                                    color = Color(0xFF065F46),
                                    fontWeight = FontWeight.Medium
                                )
                            }
                            Surface(
                                shape = RoundedCornerShape(8.dp),
                                color = Color(0xFF10B981)
                            ) {
                                Text(
                                    text = "COPY CODE",
                                    fontSize = 11.sp,
                                    fontWeight = FontWeight.Bold,
                                    color = Color.White,
                                    modifier = Modifier.padding(horizontal = 10.dp, vertical = 6.dp)
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
 * 4. 📢 LIVE COMMUNITY ACTIVITY PULSE TICKER
 * Real-time social proof activity marquee showing user bookings & reviews.
 */
@Composable
fun LiveActivityPulseTicker(
    modifier: Modifier = Modifier
) {
    val activities = remember {
        listOf(
            "🎉 Rahul booked Grand Royal Palace (Hyderabad) • 2 min ago",
            "⭐ Priya rated Sunrise PG 5.0 stars (Bengaluru) • 5 min ago",
            "🏨 2 Executive Rooms booked at Comfort Lodge (Pune) • 8 min ago",
            "💃 Anjali enrolled in Bharatanatyam Batch (Chennai) • 12 min ago",
            "🌴 Open Lawn Ground booked for Reception (Vijayawada) • 15 min ago"
        )
    }

    var currentIndex by remember { mutableIntStateOf(0) }

    LaunchedEffect(Unit) {
        while (true) {
            delay(4000)
            currentIndex = (currentIndex + 1) % activities.size
        }
    }

    Surface(
        shape = RoundedCornerShape(16.dp),
        color = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.4f),
        border = BorderStroke(1.dp, MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.3f)),
        modifier = modifier
            .fillMaxWidth()
            .testTag("live_activity_ticker_widget")
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 14.dp, vertical = 10.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Box(
                modifier = Modifier
                    .size(8.dp)
                    .clip(CircleShape)
                    .background(Color(0xFF22C55E))
                    .pulsingGlow(durationMillis = 600)
            )
            Spacer(modifier = Modifier.width(8.dp))
            AnimatedContent(
                targetState = currentIndex,
                transitionSpec = {
                    slideInVertically { height -> height } + fadeIn() togetherWith
                            slideOutVertically { height -> -height } + fadeOut()
                },
                label = "tickerAnimation",
                modifier = Modifier.weight(1f)
            ) { index ->
                Text(
                    text = activities[index],
                    fontSize = 11.5.sp,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis
                )
            }
        }
    }
}

/**
 * 5. 🌦️ SMART WEATHER & BEST TIME TO BOOK SPACE INSIGHTS WIDGET
 */
@Composable
fun SmartWeatherSpaceInsightsWidget(
    location: LocationHierarchy,
    modifier: Modifier = Modifier
) {
    Card(
        shape = RoundedCornerShape(20.dp),
        colors = CardDefaults.cardColors(
            containerColor = MaterialTheme.colorScheme.primaryContainer.copy(alpha = 0.45f)
        ),
        border = BorderStroke(1.dp, MaterialTheme.colorScheme.primary.copy(alpha = 0.25f)),
        modifier = modifier
            .fillMaxWidth()
            .testTag("smart_weather_insights_widget")
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(14.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Box(
                modifier = Modifier
                    .size(42.dp)
                    .clip(CircleShape)
                    .background(MaterialTheme.colorScheme.primary.copy(alpha = 0.15f)),
                contentAlignment = Alignment.Center
            ) {
                Text("☀️", fontSize = 20.sp)
            }

            Spacer(modifier = Modifier.width(12.dp))

            Column(modifier = Modifier.weight(1f)) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Text(
                        text = "Today in ${location.shortLabel}: 29°C Clear",
                        fontWeight = FontWeight.Bold,
                        fontSize = 12.5.sp,
                        color = MaterialTheme.colorScheme.onPrimaryContainer
                    )
                }
                Spacer(modifier = Modifier.height(2.dp))
                Text(
                    text = "🌟 Ideal weather for Open Party Lawns, Rooftop Stays & Evening Sports Turfs!",
                    fontSize = 11.sp,
                    color = MaterialTheme.colorScheme.onPrimaryContainer.copy(alpha = 0.85f),
                    lineHeight = 15.sp
                )
            }
        }
    }
}
