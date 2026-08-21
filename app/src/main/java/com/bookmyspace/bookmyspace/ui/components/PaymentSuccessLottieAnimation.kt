package com.bookmyspace.bookmyspace.ui.components

import androidx.compose.animation.core.*
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
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import com.airbnb.lottie.compose.*
import com.bookmyspace.bookmyspace.R

/**
 * High-performance Lottie Animation component providing celebratory visual feedback
 * when a payment transaction is successfully verified.
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
        if (progress >= 0.99f && !hasCompleted) {
            hasCompleted = true
            onAnimationEnd()
        }
    }

    Box(
        modifier = modifier
            .size(size)
            .testTag("payment_success_lottie_animation"),
        contentAlignment = Alignment.Center
    ) {
        if (composition != null) {
            LottieAnimation(
                composition = composition,
                progress = { progress },
                modifier = Modifier.fillMaxSize()
            )
        } else {
            // Elegant fallback while composition loads
            val infiniteTransition = rememberInfiniteTransition(label = "pulse")
            val scale by infiniteTransition.animateFloat(
                initialValue = 0.9f,
                targetValue = 1.1f,
                animationSpec = infiniteRepeatable(
                    animation = tween(600, easing = FastOutSlowInEasing),
                    repeatMode = RepeatMode.Reverse
                ),
                label = "scale"
            )

            Box(
                modifier = Modifier
                    .size(size * 0.7f)
                    .scale(scale)
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
