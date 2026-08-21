package com.bookmyspace.bookmyspace.ui.components

import androidx.compose.animation.core.*
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.composed
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Shape
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp

/**
 * High-performance, eye-catching multi-stop shimmer gradient effect.
 * Creates a fluid metallic/light gleam that animates diagonally across UI components.
 */
fun Modifier.shimmerLoading(
    durationMillis: Int = 1200,
    shimmerColors: List<Color>? = null
): Modifier = composed {
    val transition = rememberInfiniteTransition(label = "shimmerTransition")
    val translateAnim by transition.animateFloat(
        initialValue = -500f,
        targetValue = 1500f,
        animationSpec = infiniteRepeatable(
            animation = tween(durationMillis = durationMillis, easing = LinearEasing),
            repeatMode = RepeatMode.Restart
        ),
        label = "shimmerTranslate"
    )

    val isDark = MaterialTheme.colorScheme.surface.let {
        // Simple luminance check or theme check
        it.red * 0.299f + it.green * 0.587f + it.blue * 0.114f < 0.5f
    }

    val defaultColors = if (isDark) {
        listOf(
            Color(0xFF2A2E3D),
            Color(0xFF3F465C),
            Color(0xFF555F7C),
            Color(0xFF3F465C),
            Color(0xFF2A2E3D)
        )
    } else {
        listOf(
            Color(0xFFE2E8F0),
            Color(0xFFEDF2F7),
            Color(0xFFFFFFFF).copy(alpha = 0.85f),
            Color(0xFFEDF2F7),
            Color(0xFFE2E8F0)
        )
    }

    val colors = shimmerColors ?: defaultColors

    val brush = Brush.linearGradient(
        colors = colors,
        start = Offset(translateAnim - 400f, translateAnim - 400f),
        end = Offset(translateAnim + 400f, translateAnim + 400f)
    )

    this.background(brush = brush)
}

/**
 * Pulsing glow modifier for live indicators, radars, and deal badges.
 */
fun Modifier.pulsingGlow(
    minAlpha: Float = 0.35f,
    maxAlpha: Float = 1.0f,
    durationMillis: Int = 1000
): Modifier = composed {
    val infiniteTransition = rememberInfiniteTransition(label = "pulsingGlow")
    val alphaValue by infiniteTransition.animateFloat(
        initialValue = minAlpha,
        targetValue = maxAlpha,
        animationSpec = infiniteRepeatable(
            animation = tween(durationMillis, easing = FastOutSlowInEasing),
            repeatMode = RepeatMode.Reverse
        ),
        label = "glowAlpha"
    )

    this.alpha(alphaValue)
}

/**
 * Generic shimmering placeholder box.
 */
@Composable
fun ShimmerBox(
    modifier: Modifier = Modifier,
    shape: Shape = RoundedCornerShape(8.dp),
    height: Dp? = null,
    width: Dp? = null
) {
    var mod = modifier.clip(shape)
    if (width != null) mod = mod.width(width)
    if (height != null) mod = mod.height(height)
    Box(
        modifier = mod.shimmerLoading()
    )
}

/**
 * Eye-catching Skeleton for the Deals & Offers Widget.
 */
@Composable
fun EyeCatchingHotDealsSkeleton(
    modifier: Modifier = Modifier
) {
    Card(
        shape = RoundedCornerShape(22.dp),
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.4f)),
        modifier = modifier
            .fillMaxWidth()
            .height(140.dp)
            .testTag("hot_deals_skeleton")
    ) {
        Row(
            modifier = Modifier
                .fillMaxSize()
                .padding(16.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Column(modifier = Modifier.weight(1f)) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    ShimmerBox(
                        modifier = Modifier.size(24.dp),
                        shape = CircleShape
                    )
                    Spacer(modifier = Modifier.width(8.dp))
                    ShimmerBox(
                        modifier = Modifier
                            .width(100.dp)
                            .height(16.dp),
                        shape = RoundedCornerShape(8.dp)
                    )
                }
                Spacer(modifier = Modifier.height(12.dp))
                ShimmerBox(
                    modifier = Modifier
                        .fillMaxWidth(0.85f)
                        .height(20.dp),
                    shape = RoundedCornerShape(6.dp)
                )
                Spacer(modifier = Modifier.height(8.dp))
                ShimmerBox(
                    modifier = Modifier
                        .fillMaxWidth(0.6f)
                        .height(14.dp),
                    shape = RoundedCornerShape(6.dp)
                )
            }
            Spacer(modifier = Modifier.width(16.dp))
            ShimmerBox(
                modifier = Modifier
                    .width(80.dp)
                    .height(80.dp),
                shape = RoundedCornerShape(16.dp)
            )
        }
    }
}

/**
 * Eye-catching Skeleton for the Smart Space Radar Widget.
 */
@Composable
fun EyeCatchingRadarWidgetSkeleton(
    modifier: Modifier = Modifier
) {
    Card(
        shape = RoundedCornerShape(20.dp),
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.35f)),
        modifier = modifier
            .fillMaxWidth()
            .testTag("radar_widget_skeleton")
    ) {
        Column(modifier = Modifier.padding(16.dp)) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    ShimmerBox(modifier = Modifier.size(28.dp), shape = CircleShape)
                    Spacer(modifier = Modifier.width(10.dp))
                    Column {
                        ShimmerBox(modifier = Modifier.width(120.dp).height(14.dp), shape = RoundedCornerShape(4.dp))
                        Spacer(modifier = Modifier.height(4.dp))
                        ShimmerBox(modifier = Modifier.width(180.dp).height(10.dp), shape = RoundedCornerShape(4.dp))
                    }
                }
                ShimmerBox(modifier = Modifier.width(60.dp).height(24.dp), shape = RoundedCornerShape(12.dp))
            }
            Spacer(modifier = Modifier.height(14.dp))
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                repeat(4) {
                    ShimmerBox(
                        modifier = Modifier
                            .weight(1f)
                            .height(34.dp),
                        shape = RoundedCornerShape(12.dp)
                    )
                }
            }
        }
    }
}

/**
 * Eye-catching Hero Card Skeleton for the 4 Main Sections.
 */
@Composable
fun EyeCatchingHeroCardSkeleton(
    modifier: Modifier = Modifier,
    height: Dp = 155.dp
) {
    Card(
        shape = RoundedCornerShape(22.dp),
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.35f)),
        modifier = modifier
            .fillMaxWidth()
            .height(height)
            .testTag("hero_card_skeleton")
    ) {
        Box(modifier = Modifier.fillMaxSize()) {
            // Background Shimmer
            Box(
                modifier = Modifier
                    .fillMaxSize()
                    .shimmerLoading()
            )

            // Content Skeleton
            Column(
                modifier = Modifier
                    .fillMaxSize()
                    .padding(16.dp),
                verticalArrangement = Arrangement.SpaceBetween
            ) {
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.Top
                ) {
                    ShimmerBox(
                        modifier = Modifier.size(44.dp),
                        shape = RoundedCornerShape(14.dp)
                    )
                    ShimmerBox(
                        modifier = Modifier
                            .width(70.dp)
                            .height(24.dp),
                        shape = RoundedCornerShape(12.dp)
                    )
                }

                Column {
                    ShimmerBox(
                        modifier = Modifier
                            .width(160.dp)
                            .height(20.dp),
                        shape = RoundedCornerShape(6.dp)
                    )
                    Spacer(modifier = Modifier.height(6.dp))
                    ShimmerBox(
                        modifier = Modifier
                            .fillMaxWidth(0.75f)
                            .height(12.dp),
                        shape = RoundedCornerShape(4.dp)
                    )
                    Spacer(modifier = Modifier.height(10.dp))
                    Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                        ShimmerBox(modifier = Modifier.width(60.dp).height(20.dp), shape = RoundedCornerShape(6.dp))
                        ShimmerBox(modifier = Modifier.width(70.dp).height(20.dp), shape = RoundedCornerShape(6.dp))
                        ShimmerBox(modifier = Modifier.width(55.dp).height(20.dp), shape = RoundedCornerShape(6.dp))
                    }
                }
            }
        }
    }
}

/**
 * Eye-catching Skeleton for Individual Venue / Space Cards.
 */
@Composable
fun EyeCatchingVenueCardSkeleton(
    modifier: Modifier = Modifier
) {
    Card(
        shape = RoundedCornerShape(20.dp),
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface),
        elevation = CardDefaults.cardElevation(defaultElevation = 2.dp),
        modifier = modifier
            .fillMaxWidth()
            .testTag("venue_card_skeleton")
    ) {
        Column {
            // Image Box Shimmer
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .height(190.dp)
                    .shimmerLoading()
            ) {
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(12.dp),
                    horizontalArrangement = Arrangement.SpaceBetween
                ) {
                    ShimmerBox(modifier = Modifier.width(80.dp).height(24.dp), shape = RoundedCornerShape(12.dp))
                    ShimmerBox(modifier = Modifier.size(32.dp), shape = CircleShape)
                }
            }

            // Info Body
            Column(modifier = Modifier.padding(16.dp)) {
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    ShimmerBox(modifier = Modifier.width(180.dp).height(18.dp), shape = RoundedCornerShape(4.dp))
                    ShimmerBox(modifier = Modifier.width(50.dp).height(20.dp), shape = RoundedCornerShape(6.dp))
                }

                Spacer(modifier = Modifier.height(8.dp))
                ShimmerBox(modifier = Modifier.fillMaxWidth(0.6f).height(13.dp), shape = RoundedCornerShape(4.dp))

                Spacer(modifier = Modifier.height(12.dp))
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    repeat(3) {
                        ShimmerBox(modifier = Modifier.width(64.dp).height(22.dp), shape = RoundedCornerShape(8.dp))
                    }
                }

                Spacer(modifier = Modifier.height(14.dp))
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Column {
                        ShimmerBox(modifier = Modifier.width(60.dp).height(10.dp), shape = RoundedCornerShape(2.dp))
                        Spacer(modifier = Modifier.height(4.dp))
                        ShimmerBox(modifier = Modifier.width(100.dp).height(18.dp), shape = RoundedCornerShape(4.dp))
                    }
                    ShimmerBox(modifier = Modifier.width(90.dp).height(38.dp), shape = RoundedCornerShape(12.dp))
                }
            }
        }
    }
}

/**
 * Category Chips Row Skeleton.
 */
@Composable
fun EyeCatchingCategoryChipsSkeleton(
    modifier: Modifier = Modifier
) {
    Row(
        modifier = modifier
            .fillMaxWidth()
            .padding(horizontal = 20.dp, vertical = 6.dp),
        horizontalArrangement = Arrangement.spacedBy(10.dp)
    ) {
        repeat(5) {
            ShimmerBox(
                modifier = Modifier
                    .width(100.dp)
                    .height(38.dp),
                shape = RoundedCornerShape(16.dp)
            )
        }
    }
}

/**
 * Full Home Screen Shimmer Layout for initial launch or refresh.
 */
@Composable
fun EyeCatchingFullHomeSkeleton(
    modifier: Modifier = Modifier
) {
    Column(
        modifier = modifier
            .fillMaxSize()
            .padding(horizontal = 20.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp)
    ) {
        Spacer(modifier = Modifier.height(8.dp))
        // Hot Deals Shimmer
        EyeCatchingHotDealsSkeleton()

        // Radar Widget Shimmer
        EyeCatchingRadarWidgetSkeleton()

        // Section Title Shimmer
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically
        ) {
            ShimmerBox(modifier = Modifier.width(160.dp).height(22.dp), shape = RoundedCornerShape(6.dp))
            ShimmerBox(modifier = Modifier.width(80.dp).height(16.dp), shape = RoundedCornerShape(4.dp))
        }

        // 4 Main Section Shimmer Cards
        repeat(4) {
            EyeCatchingHeroCardSkeleton()
        }

        Spacer(modifier = Modifier.height(20.dp))
    }
}

/**
 * Eye-catching Skeleton for the Venue Details Screen.
 */
@Composable
fun EyeCatchingVenueDetailsSkeleton(
    modifier: Modifier = Modifier
) {
    Box(
        modifier = modifier
            .fillMaxSize()
            .background(MaterialTheme.colorScheme.background)
            .testTag("venue_details_skeleton")
    ) {
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(bottom = 80.dp)
        ) {
            // Hero Image Carousel Placeholder
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .height(270.dp)
                    .shimmerLoading()
            ) {
                // Image counter and tag overlays
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(16.dp),
                    horizontalArrangement = Arrangement.SpaceBetween
                ) {
                    ShimmerBox(modifier = Modifier.width(90.dp).height(28.dp), shape = RoundedCornerShape(14.dp))
                    ShimmerBox(modifier = Modifier.size(36.dp), shape = CircleShape)
                }

                Row(
                    modifier = Modifier
                        .align(Alignment.BottomCenter)
                        .padding(bottom = 12.dp),
                    horizontalArrangement = Arrangement.spacedBy(6.dp)
                ) {
                    repeat(5) {
                        ShimmerBox(modifier = Modifier.width(16.dp).height(6.dp), shape = RoundedCornerShape(3.dp))
                    }
                }
            }

            // Venue Details Body
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(20.dp),
                verticalArrangement = Arrangement.spacedBy(14.dp)
            ) {
                // Title and Rating
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    ShimmerBox(modifier = Modifier.width(220.dp).height(24.dp), shape = RoundedCornerShape(6.dp))
                    ShimmerBox(modifier = Modifier.width(60.dp).height(24.dp), shape = RoundedCornerShape(12.dp))
                }

                // Location line
                Row(verticalAlignment = Alignment.CenterVertically) {
                    ShimmerBox(modifier = Modifier.size(16.dp), shape = CircleShape)
                    Spacer(modifier = Modifier.width(6.dp))
                    ShimmerBox(modifier = Modifier.width(180.dp).height(14.dp), shape = RoundedCornerShape(4.dp))
                }

                Spacer(modifier = Modifier.height(4.dp))

                // Quick Action Assist Chips Row
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.spacedBy(8.dp)
                ) {
                    repeat(3) {
                        ShimmerBox(modifier = Modifier.weight(1f).height(36.dp), shape = RoundedCornerShape(12.dp))
                    }
                }

                Spacer(modifier = Modifier.height(4.dp))

                // Amenities Section Header & Chips
                ShimmerBox(modifier = Modifier.width(130.dp).height(18.dp), shape = RoundedCornerShape(4.dp))
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.spacedBy(8.dp)
                ) {
                    repeat(4) {
                        ShimmerBox(modifier = Modifier.weight(1f).height(44.dp), shape = RoundedCornerShape(12.dp))
                    }
                }

                Spacer(modifier = Modifier.height(6.dp))

                // Date & Time Slots Section Header
                ShimmerBox(modifier = Modifier.width(150.dp).height(18.dp), shape = RoundedCornerShape(4.dp))
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.spacedBy(8.dp)
                ) {
                    repeat(4) {
                        ShimmerBox(modifier = Modifier.width(68.dp).height(56.dp), shape = RoundedCornerShape(14.dp))
                    }
                }

                Spacer(modifier = Modifier.height(4.dp))

                // Time Slots Grid Placeholder
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.spacedBy(8.dp)
                ) {
                    repeat(3) {
                        ShimmerBox(modifier = Modifier.weight(1f).height(40.dp), shape = RoundedCornerShape(12.dp))
                    }
                }
            }
        }

        // Fixed Bottom Booking Bar Skeleton
        Surface(
            modifier = Modifier
                .align(Alignment.BottomCenter)
                .fillMaxWidth(),
            shadowElevation = 8.dp,
            color = MaterialTheme.colorScheme.surface
        ) {
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(16.dp),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Column {
                    ShimmerBox(modifier = Modifier.width(60.dp).height(12.dp), shape = RoundedCornerShape(4.dp))
                    Spacer(modifier = Modifier.height(4.dp))
                    ShimmerBox(modifier = Modifier.width(90.dp).height(22.dp), shape = RoundedCornerShape(4.dp))
                }
                ShimmerBox(modifier = Modifier.width(150.dp).height(48.dp), shape = RoundedCornerShape(14.dp))
            }
        }
    }
}

/**
 * Eye-catching Skeleton for the Search Screen & Filtered Venues.
 */
@Composable
fun EyeCatchingSearchScreenSkeleton(
    modifier: Modifier = Modifier,
    cardCount: Int = 3
) {
    Column(
        modifier = modifier
            .fillMaxSize()
            .padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(14.dp)
    ) {
        // Location selector header skeleton
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically
        ) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                ShimmerBox(modifier = Modifier.size(24.dp), shape = CircleShape)
                Spacer(modifier = Modifier.width(8.dp))
                ShimmerBox(modifier = Modifier.width(130.dp).height(16.dp), shape = RoundedCornerShape(4.dp))
            }
            ShimmerBox(modifier = Modifier.width(80.dp).height(24.dp), shape = RoundedCornerShape(12.dp))
        }

        // Search Bar Skeleton
        ShimmerBox(modifier = Modifier.fillMaxWidth().height(52.dp), shape = RoundedCornerShape(16.dp))

        // Horizontal Category Filter Pills
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            repeat(4) {
                ShimmerBox(modifier = Modifier.width(88.dp).height(34.dp), shape = RoundedCornerShape(16.dp))
            }
        }

        // Result count & Sort Row
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically
        ) {
            ShimmerBox(modifier = Modifier.width(120.dp).height(16.dp), shape = RoundedCornerShape(4.dp))
            ShimmerBox(modifier = Modifier.width(70.dp).height(22.dp), shape = RoundedCornerShape(8.dp))
        }

        // Venue Cards Skeletons
        repeat(cardCount) {
            EyeCatchingVenueCardSkeleton()
        }
    }
}

/**
 * Eye-catching Skeleton for the My Bookings Screen.
 */
@Composable
fun EyeCatchingBookingsSkeleton(
    modifier: Modifier = Modifier,
    count: Int = 3
) {
    Column(
        modifier = modifier
            .fillMaxSize()
            .padding(horizontal = 16.dp, vertical = 12.dp),
        verticalArrangement = Arrangement.spacedBy(14.dp)
    ) {
        // Segmented Tabs Skeleton
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            repeat(4) {
                ShimmerBox(modifier = Modifier.weight(1f).height(38.dp), shape = RoundedCornerShape(12.dp))
            }
        }

        Spacer(modifier = Modifier.height(4.dp))

        // Booking Cards Skeletons
        repeat(count) {
            Card(
                shape = RoundedCornerShape(20.dp),
                colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface),
                elevation = CardDefaults.cardElevation(2.dp),
                modifier = Modifier.fillMaxWidth()
            ) {
                Column(modifier = Modifier.padding(16.dp)) {
                    // Header: Venue Name and Status Pill
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.SpaceBetween,
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            ShimmerBox(modifier = Modifier.size(46.dp), shape = RoundedCornerShape(12.dp))
                            Spacer(modifier = Modifier.width(12.dp))
                            Column {
                                ShimmerBox(modifier = Modifier.width(140.dp).height(16.dp), shape = RoundedCornerShape(4.dp))
                                Spacer(modifier = Modifier.height(6.dp))
                                ShimmerBox(modifier = Modifier.width(100.dp).height(12.dp), shape = RoundedCornerShape(4.dp))
                            }
                        }
                        ShimmerBox(modifier = Modifier.width(75.dp).height(24.dp), shape = RoundedCornerShape(12.dp))
                    }

                    Spacer(modifier = Modifier.height(14.dp))

                    // Date, Slot & Pass code Row
                    Surface(
                        color = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.5f),
                        shape = RoundedCornerShape(12.dp),
                        modifier = Modifier.fillMaxWidth()
                    ) {
                        Row(
                            modifier = Modifier
                                .fillMaxWidth()
                                .padding(12.dp),
                            horizontalArrangement = Arrangement.SpaceBetween,
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            Column {
                                ShimmerBox(modifier = Modifier.width(80.dp).height(10.dp), shape = RoundedCornerShape(2.dp))
                                Spacer(modifier = Modifier.height(4.dp))
                                ShimmerBox(modifier = Modifier.width(110.dp).height(14.dp), shape = RoundedCornerShape(4.dp))
                            }
                            ShimmerBox(modifier = Modifier.size(38.dp), shape = RoundedCornerShape(8.dp))
                        }
                    }

                    Spacer(modifier = Modifier.height(12.dp))

                    // Price & Action Buttons
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.SpaceBetween,
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Column {
                            ShimmerBox(modifier = Modifier.width(50.dp).height(10.dp), shape = RoundedCornerShape(2.dp))
                            Spacer(modifier = Modifier.height(4.dp))
                            ShimmerBox(modifier = Modifier.width(70.dp).height(18.dp), shape = RoundedCornerShape(4.dp))
                        }
                        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                            ShimmerBox(modifier = Modifier.width(80.dp).height(36.dp), shape = RoundedCornerShape(10.dp))
                            ShimmerBox(modifier = Modifier.width(90.dp).height(36.dp), shape = RoundedCornerShape(10.dp))
                        }
                    }
                }
            }
        }
    }
}

/**
 * Eye-catching Skeleton for Institutes, Classes & Coaching Screen.
 */
@Composable
fun EyeCatchingClassesAndInstitutesSkeleton(
    modifier: Modifier = Modifier,
    count: Int = 3
) {
    Column(
        modifier = modifier
            .fillMaxSize()
            .padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(14.dp)
    ) {
        // Location Header
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically
        ) {
            ShimmerBox(modifier = Modifier.width(160.dp).height(20.dp), shape = RoundedCornerShape(6.dp))
            ShimmerBox(modifier = Modifier.width(70.dp).height(24.dp), shape = RoundedCornerShape(12.dp))
        }

        // Search Bar
        ShimmerBox(modifier = Modifier.fillMaxWidth().height(50.dp), shape = RoundedCornerShape(14.dp))

        // Category Filter Chips
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            repeat(4) {
                ShimmerBox(modifier = Modifier.width(90.dp).height(34.dp), shape = RoundedCornerShape(16.dp))
            }
        }

        // Tab Row (Classes vs Institutes)
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            ShimmerBox(modifier = Modifier.weight(1f).height(40.dp), shape = RoundedCornerShape(10.dp))
            ShimmerBox(modifier = Modifier.weight(1f).height(40.dp), shape = RoundedCornerShape(10.dp))
        }

        // Class / Institute Card Skeletons
        repeat(count) {
            Card(
                shape = RoundedCornerShape(18.dp),
                colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface),
                elevation = CardDefaults.cardElevation(2.dp),
                modifier = Modifier.fillMaxWidth()
            ) {
                Column(modifier = Modifier.padding(14.dp)) {
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.SpaceBetween
                    ) {
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            ShimmerBox(modifier = Modifier.size(54.dp), shape = RoundedCornerShape(14.dp))
                            Spacer(modifier = Modifier.width(12.dp))
                            Column {
                                ShimmerBox(modifier = Modifier.width(150.dp).height(16.dp), shape = RoundedCornerShape(4.dp))
                                Spacer(modifier = Modifier.height(6.dp))
                                ShimmerBox(modifier = Modifier.width(110.dp).height(12.dp), shape = RoundedCornerShape(4.dp))
                            }
                        }
                        ShimmerBox(modifier = Modifier.width(55.dp).height(22.dp), shape = RoundedCornerShape(8.dp))
                    }

                    Spacer(modifier = Modifier.height(12.dp))
                    ShimmerBox(modifier = Modifier.fillMaxWidth(0.85f).height(12.dp), shape = RoundedCornerShape(4.dp))
                    Spacer(modifier = Modifier.height(6.dp))

                    Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                        ShimmerBox(modifier = Modifier.width(65.dp).height(20.dp), shape = RoundedCornerShape(6.dp))
                        ShimmerBox(modifier = Modifier.width(75.dp).height(20.dp), shape = RoundedCornerShape(6.dp))
                    }

                    Spacer(modifier = Modifier.height(12.dp))
                    HorizontalDivider()
                    Spacer(modifier = Modifier.height(10.dp))

                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.SpaceBetween,
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Column {
                            ShimmerBox(modifier = Modifier.width(45.dp).height(10.dp), shape = RoundedCornerShape(2.dp))
                            Spacer(modifier = Modifier.height(4.dp))
                            ShimmerBox(modifier = Modifier.width(75.dp).height(18.dp), shape = RoundedCornerShape(4.dp))
                        }
                        ShimmerBox(modifier = Modifier.width(95.dp).height(38.dp), shape = RoundedCornerShape(12.dp))
                    }
                }
            }
        }
    }
}

/**
 * Eye-catching Skeleton for Events and Courses Screens.
 */
@Composable
fun EyeCatchingEventsAndCoursesSkeleton(
    modifier: Modifier = Modifier,
    count: Int = 3
) {
    Column(
        modifier = modifier
            .fillMaxSize()
            .padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(14.dp)
    ) {
        // Hero Featured Banner Skeleton
        Card(
            shape = RoundedCornerShape(20.dp),
            colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.4f)),
            modifier = Modifier
                .fillMaxWidth()
                .height(130.dp)
        ) {
            Box(
                modifier = Modifier
                    .fillMaxSize()
                    .shimmerLoading()
            )
        }

        // Section Title & Category Filter
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically
        ) {
            ShimmerBox(modifier = Modifier.width(140.dp).height(20.dp), shape = RoundedCornerShape(4.dp))
            ShimmerBox(modifier = Modifier.width(60.dp).height(16.dp), shape = RoundedCornerShape(4.dp))
        }

        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            repeat(4) {
                ShimmerBox(modifier = Modifier.width(80.dp).height(32.dp), shape = RoundedCornerShape(16.dp))
            }
        }

        // Items List
        repeat(count) {
            Card(
                shape = RoundedCornerShape(16.dp),
                colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface),
                elevation = CardDefaults.cardElevation(2.dp),
                modifier = Modifier.fillMaxWidth()
            ) {
                Row(
                    modifier = Modifier.padding(12.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    ShimmerBox(modifier = Modifier.size(76.dp), shape = RoundedCornerShape(12.dp))
                    Spacer(modifier = Modifier.width(12.dp))
                    Column(modifier = Modifier.weight(1f)) {
                        ShimmerBox(modifier = Modifier.fillMaxWidth(0.9f).height(16.dp), shape = RoundedCornerShape(4.dp))
                        Spacer(modifier = Modifier.height(6.dp))
                        ShimmerBox(modifier = Modifier.fillMaxWidth(0.6f).height(12.dp), shape = RoundedCornerShape(4.dp))
                        Spacer(modifier = Modifier.height(8.dp))
                        Row(
                            modifier = Modifier.fillMaxWidth(),
                            horizontalArrangement = Arrangement.SpaceBetween,
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            ShimmerBox(modifier = Modifier.width(65.dp).height(16.dp), shape = RoundedCornerShape(4.dp))
                            ShimmerBox(modifier = Modifier.width(70.dp).height(26.dp), shape = RoundedCornerShape(8.dp))
                        }
                    }
                }
            }
        }
    }
}

/**
 * Eye-catching Skeleton for Owner & Admin Dashboards.
 */
@Composable
fun EyeCatchingDashboardSkeleton(
    modifier: Modifier = Modifier
) {
    Column(
        modifier = modifier
            .fillMaxSize()
            .padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp)
    ) {
        // Welcome banner skeleton
        Card(
            shape = RoundedCornerShape(18.dp),
            colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.primaryContainer.copy(alpha = 0.4f)),
            modifier = Modifier.fillMaxWidth()
        ) {
            Column(modifier = Modifier.padding(16.dp)) {
                ShimmerBox(modifier = Modifier.width(180.dp).height(20.dp), shape = RoundedCornerShape(4.dp))
                Spacer(modifier = Modifier.height(6.dp))
                ShimmerBox(modifier = Modifier.fillMaxWidth(0.7f).height(12.dp), shape = RoundedCornerShape(4.dp))
            }
        }

        // 4 KPI Metric Cards Grid
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            Card(
                shape = RoundedCornerShape(16.dp),
                colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface),
                elevation = CardDefaults.cardElevation(2.dp),
                modifier = Modifier.weight(1f)
            ) {
                Column(modifier = Modifier.padding(14.dp)) {
                    ShimmerBox(modifier = Modifier.size(28.dp), shape = CircleShape)
                    Spacer(modifier = Modifier.height(8.dp))
                    ShimmerBox(modifier = Modifier.width(80.dp).height(12.dp), shape = RoundedCornerShape(4.dp))
                    Spacer(modifier = Modifier.height(4.dp))
                    ShimmerBox(modifier = Modifier.width(60.dp).height(20.dp), shape = RoundedCornerShape(4.dp))
                }
            }

            Card(
                shape = RoundedCornerShape(16.dp),
                colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface),
                elevation = CardDefaults.cardElevation(2.dp),
                modifier = Modifier.weight(1f)
            ) {
                Column(modifier = Modifier.padding(14.dp)) {
                    ShimmerBox(modifier = Modifier.size(28.dp), shape = CircleShape)
                    Spacer(modifier = Modifier.height(8.dp))
                    ShimmerBox(modifier = Modifier.width(80.dp).height(12.dp), shape = RoundedCornerShape(4.dp))
                    Spacer(modifier = Modifier.height(4.dp))
                    ShimmerBox(modifier = Modifier.width(60.dp).height(20.dp), shape = RoundedCornerShape(4.dp))
                }
            }
        }

        // Tab Controls
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            repeat(3) {
                ShimmerBox(modifier = Modifier.weight(1f).height(38.dp), shape = RoundedCornerShape(10.dp))
            }
        }

        // Section Title & Action Button
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically
        ) {
            ShimmerBox(modifier = Modifier.width(140.dp).height(18.dp), shape = RoundedCornerShape(4.dp))
            ShimmerBox(modifier = Modifier.width(90.dp).height(30.dp), shape = RoundedCornerShape(8.dp))
        }

        // 2 Content Items Skeleton
        repeat(2) {
            EyeCatchingVenueCardSkeleton()
        }
    }
}

/**
 * Eye-catching Skeleton for Payment Transactions Screen.
 */
@Composable
fun EyeCatchingTransactionsSkeleton(
    modifier: Modifier = Modifier,
    count: Int = 4
) {
    Column(
        modifier = modifier
            .fillMaxSize()
            .padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        // Summary KPI Banner
        Card(
            shape = RoundedCornerShape(18.dp),
            colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface),
            elevation = CardDefaults.cardElevation(2.dp),
            modifier = Modifier.fillMaxWidth()
        ) {
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(16.dp),
                horizontalArrangement = Arrangement.SpaceBetween
            ) {
                Column {
                    ShimmerBox(modifier = Modifier.width(80.dp).height(12.dp), shape = RoundedCornerShape(4.dp))
                    Spacer(modifier = Modifier.height(6.dp))
                    ShimmerBox(modifier = Modifier.width(110.dp).height(22.dp), shape = RoundedCornerShape(4.dp))
                }
                Column(horizontalAlignment = Alignment.End) {
                    ShimmerBox(modifier = Modifier.width(70.dp).height(12.dp), shape = RoundedCornerShape(4.dp))
                    Spacer(modifier = Modifier.height(6.dp))
                    ShimmerBox(modifier = Modifier.width(90.dp).height(22.dp), shape = RoundedCornerShape(4.dp))
                }
            }
        }

        // Filter Pills Row
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            repeat(4) {
                ShimmerBox(modifier = Modifier.weight(1f).height(32.dp), shape = RoundedCornerShape(12.dp))
            }
        }

        // Transaction Card Items
        repeat(count) {
            Card(
                shape = RoundedCornerShape(14.dp),
                colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface),
                elevation = CardDefaults.cardElevation(1.dp),
                modifier = Modifier.fillMaxWidth()
            ) {
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(14.dp),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        ShimmerBox(modifier = Modifier.size(40.dp), shape = CircleShape)
                        Spacer(modifier = Modifier.width(12.dp))
                        Column {
                            ShimmerBox(modifier = Modifier.width(130.dp).height(15.dp), shape = RoundedCornerShape(4.dp))
                            Spacer(modifier = Modifier.height(4.dp))
                            ShimmerBox(modifier = Modifier.width(100.dp).height(11.dp), shape = RoundedCornerShape(4.dp))
                        }
                    }
                    Column(horizontalAlignment = Alignment.End) {
                        ShimmerBox(modifier = Modifier.width(60.dp).height(16.dp), shape = RoundedCornerShape(4.dp))
                        Spacer(modifier = Modifier.height(4.dp))
                        ShimmerBox(modifier = Modifier.width(50.dp).height(18.dp), shape = RoundedCornerShape(6.dp))
                    }
                }
            }
        }
    }
}

/**
 * Eye-catching Skeleton for Saved Bookmarks and Wishlist.
 */
@Composable
fun EyeCatchingSavedItemsSkeleton(
    modifier: Modifier = Modifier,
    count: Int = 3
) {
    Column(
        modifier = modifier
            .fillMaxSize()
            .padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(14.dp)
    ) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically
        ) {
            ShimmerBox(modifier = Modifier.width(160.dp).height(22.dp), shape = RoundedCornerShape(4.dp))
            ShimmerBox(modifier = Modifier.width(60.dp).height(18.dp), shape = RoundedCornerShape(8.dp))
        }

        repeat(count) {
            EyeCatchingVenueCardSkeleton()
        }
    }
}

/**
 * Eye-catching Skeleton for Notifications.
 */
@Composable
fun EyeCatchingNotificationsSkeleton(
    modifier: Modifier = Modifier,
    count: Int = 4
) {
    Column(
        modifier = modifier
            .fillMaxSize()
            .padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(10.dp)
    ) {
        repeat(count) {
            Card(
                shape = RoundedCornerShape(14.dp),
                colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface),
                modifier = Modifier.fillMaxWidth()
            ) {
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(14.dp),
                    verticalAlignment = Alignment.Top
                ) {
                    ShimmerBox(modifier = Modifier.size(36.dp), shape = CircleShape)
                    Spacer(modifier = Modifier.width(12.dp))
                    Column(modifier = Modifier.weight(1f)) {
                        ShimmerBox(modifier = Modifier.width(140.dp).height(15.dp), shape = RoundedCornerShape(4.dp))
                        Spacer(modifier = Modifier.height(6.dp))
                        ShimmerBox(modifier = Modifier.fillMaxWidth(0.9f).height(12.dp), shape = RoundedCornerShape(4.dp))
                        Spacer(modifier = Modifier.height(6.dp))
                        ShimmerBox(modifier = Modifier.width(70.dp).height(10.dp), shape = RoundedCornerShape(2.dp))
                    }
                }
            }
        }
    }
}

/**
 * Eye-catching Skeleton for the Interactive Venue Map Screen.
 */
@Composable
fun EyeCatchingVenueMapSkeleton(
    modifier: Modifier = Modifier
) {
    Box(
        modifier = modifier
            .fillMaxSize()
            .background(MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.3f))
            .testTag("venue_map_skeleton")
    ) {
        // Map Grid Pattern Background
        Box(
            modifier = Modifier
                .fillMaxSize()
                .shimmerLoading()
        )

        // Top Search & Filter Bar Overlay
        Surface(
            shape = RoundedCornerShape(16.dp),
            shadowElevation = 6.dp,
            color = MaterialTheme.colorScheme.surface,
            modifier = Modifier
                .align(Alignment.TopCenter)
                .fillMaxWidth()
                .padding(16.dp)
        ) {
            Row(
                modifier = Modifier.padding(12.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                ShimmerBox(modifier = Modifier.size(24.dp), shape = CircleShape)
                Spacer(modifier = Modifier.width(10.dp))
                ShimmerBox(modifier = Modifier.weight(1f).height(20.dp), shape = RoundedCornerShape(4.dp))
                Spacer(modifier = Modifier.width(10.dp))
                ShimmerBox(modifier = Modifier.size(28.dp), shape = RoundedCornerShape(8.dp))
            }
        }

        // Simulated Pins across the map
        Box(modifier = Modifier.align(Alignment.CenterStart).padding(start = 60.dp, bottom = 40.dp)) {
            ShimmerBox(modifier = Modifier.size(32.dp), shape = CircleShape)
        }
        Box(modifier = Modifier.align(Alignment.Center).padding(bottom = 80.dp)) {
            ShimmerBox(modifier = Modifier.size(36.dp), shape = CircleShape)
        }
        Box(modifier = Modifier.align(Alignment.CenterEnd).padding(end = 70.dp, top = 60.dp)) {
            ShimmerBox(modifier = Modifier.size(32.dp), shape = CircleShape)
        }

        // Bottom Selected Venue Card Preview Skeleton
        Surface(
            shape = RoundedCornerShape(20.dp),
            shadowElevation = 10.dp,
            color = MaterialTheme.colorScheme.surface,
            modifier = Modifier
                .align(Alignment.BottomCenter)
                .fillMaxWidth()
                .padding(16.dp)
        ) {
            Row(
                modifier = Modifier.padding(14.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                ShimmerBox(modifier = Modifier.size(70.dp), shape = RoundedCornerShape(14.dp))
                Spacer(modifier = Modifier.width(12.dp))
                Column(modifier = Modifier.weight(1f)) {
                    ShimmerBox(modifier = Modifier.width(130.dp).height(16.dp), shape = RoundedCornerShape(4.dp))
                    Spacer(modifier = Modifier.height(4.dp))
                    ShimmerBox(modifier = Modifier.width(90.dp).height(12.dp), shape = RoundedCornerShape(4.dp))
                    Spacer(modifier = Modifier.height(6.dp))
                    ShimmerBox(modifier = Modifier.width(60.dp).height(16.dp), shape = RoundedCornerShape(4.dp))
                }
                ShimmerBox(modifier = Modifier.width(80.dp).height(36.dp), shape = RoundedCornerShape(10.dp))
            }
        }
    }
}
