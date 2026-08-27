package com.bookmyspace.bookmyspace.ui.components

import androidx.compose.animation.animateColorAsState
import androidx.compose.animation.core.*
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.interaction.collectIsPressedAsState
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.scale
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import kotlinx.coroutines.launch

/**
 * Premium interactive Category Pill featuring a physics-driven "pop" and "pulse" spring animation
 * on selection and touch, elevating the horizontal scroll experience.
 */
@Composable
fun PulsePopCategoryPill(
    selected: Boolean,
    onClick: () -> Unit,
    label: String,
    modifier: Modifier = Modifier,
    emoji: String? = null,
    iconVector: ImageVector? = null,
    badge: String? = null,
    isSpecialAddPill: Boolean = false,
    testTag: String = ""
) {
    val interactionSource = remember { MutableInteractionSource() }
    val isPressed by interactionSource.collectIsPressedAsState()

    // Interactive Pulse & Pop Spring Animation
    val pulseAnim = remember { Animatable(1f) }
    val coroutineScope = rememberCoroutineScope()

    // Trigger a single satisfying tactile pulse/pop every time the item becomes selected
    LaunchedEffect(selected) {
        if (selected) {
            try {
                pulseAnim.snapTo(0.92f)
                pulseAnim.animateTo(
                    targetValue = 1.08f,
                    animationSpec = spring(
                        dampingRatio = Spring.DampingRatioMediumBouncy,
                        stiffness = Spring.StiffnessMediumLow
                    )
                )
                pulseAnim.animateTo(
                    targetValue = 1f,
                    animationSpec = spring(
                        dampingRatio = Spring.DampingRatioNoBouncy,
                        stiffness = Spring.StiffnessMedium
                    )
                )
            } catch (_: Exception) {
                pulseAnim.snapTo(1f)
            }
        } else {
            pulseAnim.snapTo(1f)
        }
    }

    // Steady state spring scale
    val targetScale = when {
        isPressed -> 0.94f
        selected -> 1.04f
        else -> 1.0f
    }

    val baseScale by animateFloatAsState(
        targetValue = targetScale,
        animationSpec = spring(
            dampingRatio = Spring.DampingRatioMediumBouncy,
            stiffness = Spring.StiffnessLow
        ),
        label = "pill_base_scale"
    )

    val finalScale = baseScale * pulseAnim.value

    // Emoji/Icon micro-bounce
    val iconScale by animateFloatAsState(
        targetValue = if (selected) 1.20f else 1.0f,
        animationSpec = spring(
            dampingRatio = Spring.DampingRatioHighBouncy,
            stiffness = Spring.StiffnessMedium
        ),
        label = "pill_icon_scale"
    )

    // Animated container & content colors
    val containerColor by animateColorAsState(
        targetValue = when {
            selected -> MaterialTheme.colorScheme.primary
            isSpecialAddPill -> MaterialTheme.colorScheme.primaryContainer.copy(alpha = 0.38f)
            else -> MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.45f)
        },
        animationSpec = tween(durationMillis = 220),
        label = "pill_container_color"
    )

    val contentColor by animateColorAsState(
        targetValue = when {
            selected -> MaterialTheme.colorScheme.onPrimary
            isSpecialAddPill -> MaterialTheme.colorScheme.primary
            else -> MaterialTheme.colorScheme.onSurface
        },
        animationSpec = tween(durationMillis = 220),
        label = "pill_content_color"
    )

    val borderColor by animateColorAsState(
        targetValue = when {
            selected -> MaterialTheme.colorScheme.primary.copy(alpha = 0.9f)
            isSpecialAddPill -> MaterialTheme.colorScheme.primary.copy(alpha = 0.5f)
            else -> MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.4f)
        },
        animationSpec = tween(durationMillis = 220),
        label = "pill_border_color"
    )

    val elevation by animateDpAsState(
        targetValue = if (selected) 4.dp else 0.dp,
        animationSpec = spring(
            dampingRatio = Spring.DampingRatioMediumBouncy,
            stiffness = Spring.StiffnessLow
        ),
        label = "pill_elevation"
    )

    Surface(
        shape = RoundedCornerShape(16.dp),
        color = containerColor,
        border = BorderStroke(if (selected || isSpecialAddPill) 1.5.dp else 1.dp, borderColor),
        shadowElevation = elevation,
        modifier = modifier
            .graphicsLayer {
                scaleX = finalScale
                scaleY = finalScale
            }
            .clip(RoundedCornerShape(16.dp))
            .clickable(
                interactionSource = interactionSource,
                indication = ripple(bounded = true),
                onClick = onClick
            )
            .then(if (testTag.isNotBlank()) Modifier.testTag(testTag) else Modifier)
    ) {
        Row(
            modifier = Modifier
                .padding(horizontal = 14.dp, vertical = 8.dp)
                .defaultMinSize(minHeight = 36.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.Center
        ) {
            // Leading Emoji or Vector Icon
            if (emoji != null) {
                Text(
                    text = emoji,
                    fontSize = 13.5.sp,
                    modifier = Modifier.graphicsLayer {
                        scaleX = iconScale
                        scaleY = iconScale
                    }
                )
                Spacer(modifier = Modifier.width(6.dp))
            } else if (iconVector != null) {
                Icon(
                    imageVector = iconVector,
                    contentDescription = null,
                    tint = contentColor,
                    modifier = Modifier
                        .size(16.dp)
                        .graphicsLayer {
                            scaleX = iconScale
                            scaleY = iconScale
                        }
                )
                Spacer(modifier = Modifier.width(5.dp))
            }

            // Pill Title
            Text(
                text = label,
                fontSize = 12.5.sp,
                fontWeight = if (selected || isSpecialAddPill) FontWeight.Bold else FontWeight.Medium,
                color = contentColor,
                letterSpacing = (-0.1).sp
            )

            // Optional Badge (e.g., "✨ NEW", "LIVE")
            if (badge != null) {
                Spacer(modifier = Modifier.width(6.dp))
                Surface(
                    shape = CircleShape,
                    color = if (selected) MaterialTheme.colorScheme.onPrimary.copy(alpha = 0.2f) else MaterialTheme.colorScheme.primary.copy(alpha = 0.15f)
                ) {
                    Text(
                        text = badge,
                        fontSize = 9.5.sp,
                        fontWeight = FontWeight.Black,
                        color = if (selected) MaterialTheme.colorScheme.onPrimary else MaterialTheme.colorScheme.primary,
                        modifier = Modifier.padding(horizontal = 5.dp, vertical = 1.5.dp)
                    )
                }
            }
        }
    }
}
