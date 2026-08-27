package com.bookmyspace.bookmyspace.ui.components

import androidx.compose.animation.*
import androidx.compose.animation.core.*
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.rotate
import androidx.compose.ui.draw.scale
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.bookmyspace.bookmyspace.R
import kotlinx.coroutines.delay
import kotlinx.coroutines.isActive

/**
 * High-definition BookMySpace Brand Logo Component.
 * Displays the custom vector emblem with optional styled typography.
 */
@Composable
fun BMSBrandLogo(
    modifier: Modifier = Modifier,
    size: Dp = 64.dp,
    showText: Boolean = false,
    subtitle: String? = "Turfs • Halls • PGs • Studios"
) {
    if (showText) {
        Row(
            modifier = modifier.testTag("bms_brand_logo_with_text"),
            verticalAlignment = Alignment.CenterVertically
        ) {
            BMSLogoIconBadge(size = size)
            Spacer(modifier = Modifier.width(12.dp))
            Column {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Text(
                        text = "Book",
                        fontWeight = FontWeight.Black,
                        fontSize = (size.value * 0.38f).sp,
                        color = MaterialTheme.colorScheme.primary
                    )
                    Text(
                        text = "My",
                        fontWeight = FontWeight.ExtraBold,
                        fontSize = (size.value * 0.38f).sp,
                        color = MaterialTheme.colorScheme.onSurface
                    )
                    Text(
                        text = "Space",
                        fontWeight = FontWeight.Black,
                        fontSize = (size.value * 0.38f).sp,
                        color = Color(0xFF10B981)
                    )
                }
                if (subtitle != null) {
                    Text(
                        text = subtitle,
                        fontSize = (size.value * 0.17f).coerceAtLeast(10f).sp,
                        fontWeight = FontWeight.SemiBold,
                        color = MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.8f)
                    )
                }
            }
        }
    } else {
        BMSLogoIconBadge(
            size = size,
            modifier = modifier.testTag("bms_brand_logo_icon")
        )
    }
}

/**
 * Crisp Emblem with ambient radial glow and rounded squircle border.
 */
@Composable
fun BMSLogoIconBadge(
    modifier: Modifier = Modifier,
    size: Dp = 64.dp
) {
    Box(
        modifier = modifier
            .size(size)
            .shadow(
                elevation = 8.dp,
                shape = RoundedCornerShape((size.value * 0.26f).dp),
                spotColor = Color(0xFF10B981).copy(alpha = 0.4f)
            )
            .clip(RoundedCornerShape((size.value * 0.26f).dp))
            .background(
                Brush.linearGradient(
                    listOf(
                        Color(0xFF0F172A),
                        Color(0xFF1E293B),
                        Color(0xFF0B1329)
                    )
                )
            )
            .border(
                width = (size.value * 0.025f).coerceAtLeast(1.5f).dp,
                brush = Brush.linearGradient(
                    listOf(
                        Color(0xFF10B981),
                        Color(0xFF38BDF8),
                        Color(0xFF818CF8)
                    )
                ),
                shape = RoundedCornerShape((size.value * 0.26f).dp)
            ),
        contentAlignment = Alignment.Center
    ) {
        Image(
            painter = painterResource(id = R.drawable.ic_bms_logo),
            contentDescription = "BookMySpace Logo",
            modifier = Modifier
                .fillMaxSize()
                .padding((size.value * 0.06f).dp),
            contentScale = ContentScale.Fit
        )
    }
}

/**
 * Animated Logo Pulse Loader.
 * The logo breathes rhythmically with radiating ripple rings, orbital particle rotation, and a metallic progress beam.
 */
@Composable
fun BMSLogoPulseLoader(
    modifier: Modifier = Modifier,
    logoSize: Dp = 80.dp,
    titleText: String = "Loading BookMySpace...",
    subtitleText: String? = "Finding available sports turfs, halls & rooms",
    showProgressBar: Boolean = true
) {
    val infiniteTransition = rememberInfiniteTransition(label = "bmsLogoPulse")

    // Breathing scale animation
    val scale by infiniteTransition.animateFloat(
        initialValue = 0.92f,
        targetValue = 1.08f,
        animationSpec = infiniteRepeatable(
            animation = tween(durationMillis = 1100, easing = FastOutSlowInEasing),
            repeatMode = RepeatMode.Reverse
        ),
        label = "logoScale"
    )

    // Glowing aura alpha animation
    val glowAlpha by infiniteTransition.animateFloat(
        initialValue = 0.35f,
        targetValue = 0.85f,
        animationSpec = infiniteRepeatable(
            animation = tween(durationMillis = 1100, easing = LinearEasing),
            repeatMode = RepeatMode.Reverse
        ),
        label = "glowAlpha"
    )

    // Orbital ring rotation
    val rotationAngle by infiniteTransition.animateFloat(
        initialValue = 0f,
        targetValue = 360f,
        animationSpec = infiniteRepeatable(
            animation = tween(durationMillis = 3000, easing = LinearEasing),
            repeatMode = RepeatMode.Restart
        ),
        label = "orbitalRotation"
    )

    // Secondary ripple expansion
    val rippleScale by infiniteTransition.animateFloat(
        initialValue = 0.9f,
        targetValue = 1.45f,
        animationSpec = infiniteRepeatable(
            animation = tween(durationMillis = 1800, easing = FastOutSlowInEasing),
            repeatMode = RepeatMode.Restart
        ),
        label = "rippleScale"
    )
    val rippleAlpha by infiniteTransition.animateFloat(
        initialValue = 0.6f,
        targetValue = 0.0f,
        animationSpec = infiniteRepeatable(
            animation = tween(durationMillis = 1800, easing = LinearEasing),
            repeatMode = RepeatMode.Restart
        ),
        label = "rippleAlpha"
    )

    Column(
        modifier = modifier
            .fillMaxWidth()
            .padding(24.dp)
            .testTag("bms_logo_pulse_loader"),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center
    ) {
        // Logo Container with Radiating Rings
        Box(
            contentAlignment = Alignment.Center,
            modifier = Modifier.size(logoSize * 1.8f)
        ) {
            // Radiating expanding ripple
            Box(
                modifier = Modifier
                    .size(logoSize * 1.35f)
                    .scale(rippleScale)
                    .alpha(rippleAlpha)
                    .clip(CircleShape)
                    .background(Color(0xFF10B981).copy(alpha = 0.25f))
            )

            // Orbital Ring with Gradient Border
            Box(
                modifier = Modifier
                    .size(logoSize * 1.45f)
                    .rotate(rotationAngle)
                    .border(
                        width = 1.5.dp,
                        brush = Brush.sweepGradient(
                            listOf(
                                Color(0xFF10B981),
                                Color(0xFF38BDF8),
                                Color(0xFF818CF8),
                                Color.Transparent,
                                Color(0xFF10B981)
                            )
                        ),
                        shape = CircleShape
                    )
            )

            // Ambient background glow
            Box(
                modifier = Modifier
                    .size(logoSize * 1.15f)
                    .alpha(glowAlpha)
                    .clip(CircleShape)
                    .background(
                        Brush.radialGradient(
                            colors = listOf(
                                Color(0xFF10B981).copy(alpha = 0.45f),
                                Color(0xFF0284C7).copy(alpha = 0.25f),
                                Color.Transparent
                            )
                        )
                    )
            )

            // Centered Breathing Logo
            Box(
                modifier = Modifier.scale(scale)
            ) {
                BMSLogoIconBadge(size = logoSize)
            }
        }

        Spacer(modifier = Modifier.height(18.dp))

        // Title and Subtitle with Smooth Typography
        Text(
            text = titleText,
            fontSize = 16.sp,
            fontWeight = FontWeight.ExtraBold,
            color = MaterialTheme.colorScheme.onSurface,
            textAlign = TextAlign.Center
        )

        if (subtitleText != null) {
            Spacer(modifier = Modifier.height(4.dp))
            Text(
                text = subtitleText,
                fontSize = 12.5.sp,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                textAlign = TextAlign.Center,
                modifier = Modifier.padding(horizontal = 16.dp)
            )
        }

        if (showProgressBar) {
            Spacer(modifier = Modifier.height(16.dp))
            // High-Tech Shimmering Linear Progress Bar
            Box(
                modifier = Modifier
                    .width(180.dp)
                    .height(4.dp)
                    .clip(RoundedCornerShape(2.dp))
                    .background(MaterialTheme.colorScheme.surfaceVariant)
            ) {
                Box(
                    modifier = Modifier
                        .fillMaxSize()
                        .shimmerLoading(
                            durationMillis = 900,
                            shimmerColors = listOf(
                                Color(0xFF10B981),
                                Color(0xFF38BDF8),
                                Color(0xFFFFFFFF),
                                Color(0xFF38BDF8),
                                Color(0xFF10B981)
                            )
                        )
                )
            }
        }
    }
}

/**
 * Full-Screen Animated Splash & App-Loading Screen.
 * Renders the official logo, animated rotating badge, dynamic rotating step messages, and secure badges.
 */
@Composable
fun BMSFullPageLoadingScreen(
    modifier: Modifier = Modifier,
    onLoadingFinished: (() -> Unit)? = null,
    minimumDurationMillis: Long = 1200L
) {
    val loadingSteps = remember {
        listOf(
            "Connecting to BookMySpace Cloud ⚡",
            "Checking live turf & hall availability...",
            "Loading verified properties & deals...",
            "Ready for instant booking! 🚀"
        )
    }

    var currentStepIndex by remember { mutableIntStateOf(0) }

    LaunchedEffect(Unit) {
        var elapsed = 0L
        val stepInterval = 400L
        while (isActive && currentStepIndex < loadingSteps.size - 1) {
            delay(stepInterval)
            elapsed += stepInterval
            currentStepIndex = (currentStepIndex + 1).coerceAtMost(loadingSteps.size - 1)
        }
        if (onLoadingFinished != null) {
            if (elapsed < minimumDurationMillis) {
                delay(minimumDurationMillis - elapsed)
            }
            onLoadingFinished()
        }
    }

    Box(
        modifier = modifier
            .fillMaxSize()
            .background(
                Brush.verticalGradient(
                    listOf(
                        MaterialTheme.colorScheme.surface,
                        MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.6f),
                        MaterialTheme.colorScheme.surface
                    )
                )
            )
            .systemBarsPadding()
            .testTag("bms_full_page_loading_screen"),
        contentAlignment = Alignment.Center
    ) {
        Column(
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.Center,
            modifier = Modifier.padding(24.dp)
        ) {
            // Main Animated Logo Pulse
            BMSLogoPulseLoader(
                logoSize = 96.dp,
                titleText = "BookMySpace",
                subtitleText = loadingSteps[currentStepIndex],
                showProgressBar = true
            )

            Spacer(modifier = Modifier.height(32.dp))

            // Verified Feature Badges Pill
            Surface(
                shape = RoundedCornerShape(20.dp),
                color = MaterialTheme.colorScheme.primaryContainer.copy(alpha = 0.5f),
                border = BorderStroke(1.dp, MaterialTheme.colorScheme.primary.copy(alpha = 0.2f))
            ) {
                Row(
                    modifier = Modifier.padding(horizontal = 14.dp, vertical = 6.dp),
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(8.dp)
                ) {
                    Text("⚡ Instant Confirmation", fontSize = 11.sp, fontWeight = FontWeight.Bold, color = MaterialTheme.colorScheme.onPrimaryContainer)
                    Text("•", fontSize = 11.sp, color = MaterialTheme.colorScheme.onPrimaryContainer.copy(alpha = 0.5f))
                    Text("🛡️ 100% Verified", fontSize = 11.sp, fontWeight = FontWeight.Bold, color = MaterialTheme.colorScheme.onPrimaryContainer)
                }
            }
        }

        // Bottom Brand Slogan
        Column(
            modifier = Modifier
                .align(Alignment.BottomCenter)
                .padding(bottom = 24.dp),
            horizontalAlignment = Alignment.CenterHorizontally
        ) {
            Text(
                text = "India's Premier Space Booking Platform",
                fontSize = 11.5.sp,
                fontWeight = FontWeight.SemiBold,
                color = MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.7f)
            )
            Spacer(modifier = Modifier.height(2.dp))
            Text(
                text = "v2.5 • Fast & 256-Bit SSL Encrypted",
                fontSize = 10.sp,
                color = MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.5f)
            )
        }
    }
}

/**
 * Compact Inline Logo Loader with Shimmer for placement inside venue lists, dialogs, and cards.
 */
@Composable
fun BMSInlineLogoLoader(
    modifier: Modifier = Modifier,
    text: String = "Refreshing venue availability..."
) {
    Card(
        shape = RoundedCornerShape(16.dp),
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.45f)),
        border = BorderStroke(1.dp, MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.35f)),
        modifier = modifier
            .fillMaxWidth()
            .testTag("bms_inline_logo_loader")
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(14.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.SpaceBetween
        ) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                BMSLogoIconBadge(size = 38.dp)
                Spacer(modifier = Modifier.width(12.dp))
                Column {
                    Text(
                        text = "BookMySpace",
                        fontWeight = FontWeight.Bold,
                        fontSize = 13.sp,
                        color = MaterialTheme.colorScheme.onSurface
                    )
                    Text(
                        text = text,
                        fontSize = 11.sp,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                }
            }

            CircularProgressIndicator(
                modifier = Modifier.size(20.dp),
                strokeWidth = 2.5.dp,
                color = MaterialTheme.colorScheme.primary
            )
        }
    }
}
