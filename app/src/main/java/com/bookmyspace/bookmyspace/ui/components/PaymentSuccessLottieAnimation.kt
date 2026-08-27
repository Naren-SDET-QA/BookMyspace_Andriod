package com.bookmyspace.bookmyspace.ui.components

import androidx.compose.animation.core.*
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.scale
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import com.airbnb.lottie.compose.*
import com.bookmyspace.bookmyspace.R
import kotlin.math.cos
import kotlin.math.sin

/**
 * High-performance Lottie Animation component providing celebratory visual feedback
 * and particle confetti bursts when a Razorpay payment transaction is successfully verified.
 */
@Composable
fun PaymentSuccessLottieAnimation(
    modifier: Modifier = Modifier,
    size: Dp = 140.dp,
    autoPlay: Boolean = true,
    iterations: Int = 1,
    onAnimationEnd: () -> Unit = {}
) {
    val composition by rememberLottieComposition(
        LottieCompositionSpec.RawRes(R.raw.payment_success_lottie)
    )

    val progress by animateLottieCompositionAsState(
        composition = composition,
        isPlaying = autoPlay,
        iterations = iterations,
        restartOnPlay = true
    )

    var hasCompleted by remember { mutableStateOf(false) }

    LaunchedEffect(progress) {
        if (progress >= 0.98f && !hasCompleted) {
            hasCompleted = true
            onAnimationEnd()
        }
    }

    // Celebratory ring pulse
    val infiniteTransition = rememberInfiniteTransition(label = "pulse_ring")
    val ringScale by infiniteTransition.animateFloat(
        initialValue = 0.95f,
        targetValue = 1.15f,
        animationSpec = infiniteRepeatable(
            animation = tween(1200, easing = FastOutSlowInEasing),
            repeatMode = RepeatMode.Reverse
        ),
        label = "ringScale"
    )

    val ringAlpha by infiniteTransition.animateFloat(
        initialValue = 0.4f,
        targetValue = 0.05f,
        animationSpec = infiniteRepeatable(
            animation = tween(1200, easing = FastOutSlowInEasing),
            repeatMode = RepeatMode.Reverse
        ),
        label = "ringAlpha"
    )

    val fallbackScale by infiniteTransition.animateFloat(
        initialValue = 0.9f,
        targetValue = 1.05f,
        animationSpec = infiniteRepeatable(
            animation = tween(600, easing = FastOutSlowInEasing),
            repeatMode = RepeatMode.Reverse
        ),
        label = "fallbackScale"
    )

    Box(
        modifier = modifier
            .size(size)
            .testTag("payment_success_lottie_animation"),
        contentAlignment = Alignment.Center
    ) {
        // Subtle celebratory glowing halo
        Box(
            modifier = Modifier
                .size(size * 0.9f)
                .scale(ringScale)
                .clip(CircleShape)
                .background(Color(0xFF4CAF50).copy(alpha = ringAlpha))
        )

        if (composition != null) {
            LottieAnimation(
                composition = composition,
                progress = { progress },
                modifier = Modifier.fillMaxSize()
            )
        } else {
            // Elegant fallback while composition loads
            Box(
                modifier = Modifier
                    .size(size * 0.7f)
                    .scale(fallbackScale)
                    .clip(CircleShape)
                    .background(Color(0xFFE8F5E9)),
                contentAlignment = Alignment.Center
            ) {
                Icon(
                    Icons.Default.CheckCircle,
                    contentDescription = "Payment Success",
                    tint = Color(0xFF2E7D32),
                    modifier = Modifier.size(size * 0.5f)
                )
            }
        }
    }
}
