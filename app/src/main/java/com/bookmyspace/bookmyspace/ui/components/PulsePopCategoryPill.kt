package com.bookmyspace.bookmyspace.ui.components

import androidx.compose.animation.animateColorAsState
import androidx.compose.animation.core.*
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.hoverable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.interaction.collectIsHoveredAsState
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
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.input.pointer.PointerIcon
import androidx.compose.ui.input.pointer.pointerHoverIcon
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
    val isHovered by interactionSource.collectIsHoveredAsState()
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

    // Steady state fast hover & press scale
    val targetScale = when {
        isPressed -> 0.94f
        isHovered -> 1.07f
        selected -> 1.04f
        else -> 1.0f
    }

    val baseScale by animateFloatAsState(
        targetValue = targetScale,
        animationSpec = tween(durationMillis = 120, easing = FastOutSlowInEasing),
        label = "pill_base_scale"
    )

    val finalScale = baseScale * pulseAnim.value

    // Emoji/Icon micro-bounce
    val iconScale by animateFloatAsState(
        targetValue = if (selected || isHovered) 1.18f else 1.0f,
        animationSpec = tween(durationMillis = 120, easing = FastOutSlowInEasing),
        label = "pill_icon_scale"
    )

    // Animated container & content colors
    val containerColor by animateColorAsState(
        targetValue = when {
            selected -> MaterialTheme.colorScheme.primary
            isHovered -> MaterialTheme.colorScheme.primaryContainer.copy(alpha = 0.45f)
            isSpecialAddPill -> MaterialTheme.colorScheme.primaryContainer.copy(alpha = 0.38f)
            else -> MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.45f)
        },
        animationSpec = tween(durationMillis = 120),
        label = "pill_container_color"
    )

    val contentColor by animateColorAsState(
        targetValue = when {
            selected -> MaterialTheme.colorScheme.onPrimary
            isHovered -> MaterialTheme.colorScheme.onPrimaryContainer
            isSpecialAddPill -> MaterialTheme.colorScheme.primary
            else -> MaterialTheme.colorScheme.onSurface
        },
        animationSpec = tween(durationMillis = 120),
        label = "pill_content_color"
    )

    val borderColor by animateColorAsState(
        targetValue = when {
            selected -> MaterialTheme.colorScheme.primary.copy(alpha = 0.9f)
            isHovered -> MaterialTheme.colorScheme.primary.copy(alpha = 0.8f)
            isSpecialAddPill -> MaterialTheme.colorScheme.primary.copy(alpha = 0.5f)
            else -> MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.4f)
        },
        animationSpec = tween(durationMillis = 120),
        label = "pill_border_color"
    )

    // 1. Subtle 3D Tilt Animation on Hover
    val tiltX by animateFloatAsState(
        targetValue = when {
            isPressed -> 2.0f
            isHovered -> -4.2f
            selected -> -1.5f
            else -> 0f
        },
        animationSpec = tween(durationMillis = 150, easing = FastOutSlowInEasing),
        label = "pill_tilt_x"
    )
    val tiltY by animateFloatAsState(
        targetValue = when {
            isPressed -> -1.2f
            isHovered -> 3.2f
            selected -> 1.0f
            else -> 0f
        },
        animationSpec = tween(durationMillis = 150, easing = FastOutSlowInEasing),
        label = "pill_tilt_y"
    )
    val liftY by animateFloatAsState(
        targetValue = when {
            isPressed -> 1.5f
            isHovered -> -5f
            selected -> -1.5f
            else -> 0f
        },
        animationSpec = tween(durationMillis = 150, easing = FastOutSlowInEasing),
        label = "pill_lift_y"
    )

    val elevation by animateDpAsState(
        targetValue = when {
            isPressed -> 1.dp
            isHovered -> 14.dp
            selected -> 6.dp
            else -> 1.dp
        },
        animationSpec = tween(durationMillis = 150),
        label = "pill_elevation"
    )

    Surface(
        shape = RoundedCornerShape(16.dp),
        color = containerColor,
        // Top-illuminated directional light-source border
        border = BorderStroke(
            width = if (selected || isHovered || isSpecialAddPill) 1.6.dp else 1.dp,
            brush = if (selected || isHovered) {
                Brush.verticalGradient(
                    listOf(
                        Color.White.copy(alpha = 0.95f),
                        borderColor.copy(alpha = 0.85f),
                        borderColor.copy(alpha = 0.35f),
                        Color.Transparent
                    )
                )
            } else {
                Brush.verticalGradient(
                    listOf(
                        Color.White.copy(alpha = 0.55f),
                        borderColor.copy(alpha = 0.35f),
                        Color.Transparent
                    )
                )
            }
        ),
        modifier = modifier
            .hoverable(interactionSource = interactionSource)
            .pointerHoverIcon(PointerIcon.Hand)
            .shadow(
                elevation = elevation,
                shape = RoundedCornerShape(16.dp),
                ambientColor = (if (selected || isHovered) borderColor else Color.Black).copy(alpha = if (isHovered) 0.42f else 0.16f),
                spotColor = (if (selected || isHovered) borderColor else Color.Black).copy(alpha = if (isHovered) 0.65f else 0.28f)
            )
            .graphicsLayer {
                scaleX = finalScale
                scaleY = finalScale
                rotationX = tiltX
                rotationY = tiltY
                translationY = liftY
                cameraDistance = 14f * density
            }
            .clip(RoundedCornerShape(16.dp))
            .clickable(
                interactionSource = interactionSource,
                indication = ripple(bounded = true),
                onClick = onClick
            )
            .then(if (testTag.isNotBlank()) Modifier.testTag(testTag) else Modifier)
    ) {
        // Restructured layout: Top edge highlight bar + content
        Box(modifier = Modifier.fillMaxWidth()) {
            // Directional Light-Source Highlight on Top Edge
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .height(2.5.dp)
                    .align(Alignment.TopCenter)
                    .background(
                        Brush.horizontalGradient(
                            listOf(
                                borderColor.copy(alpha = 0.2f),
                                borderColor.copy(alpha = if (isHovered) 0.95f else 0.80f),
                                Color.White.copy(alpha = if (isHovered) 1.0f else 0.92f),
                                borderColor.copy(alpha = if (isHovered) 0.95f else 0.80f),
                                borderColor.copy(alpha = 0.2f)
                            )
                        )
                    )
            )

            // Secondary subtle glow
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .height(8.dp)
                    .align(Alignment.TopCenter)
                    .background(
                        Brush.verticalGradient(
                            listOf(
                                borderColor.copy(alpha = if (isHovered) 0.20f else 0.10f),
                                Color.Transparent
                            )
                        )
                    )
            )

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
}
