package com.bookmyspace.bookmyspace.ui.components

import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.Spring
import androidx.compose.animation.core.spring
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.composed
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.drawWithContent
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.BlendMode
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Shape
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.input.pointer.PointerEventType
import androidx.compose.ui.input.pointer.PointerIcon
import androidx.compose.ui.input.pointer.pointerHoverIcon
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.layout.onSizeChanged
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.IntSize
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.bookmyspace.bookmyspace.data.repository.BookMySpaceRepository
import kotlinx.coroutines.launch
import kotlin.math.max

/**
 * Ultra-responsive 3D Live Interactive Action Mode modifier.
 * Delivers hardware-accelerated 3D perspective tilt on mouse hover & pointer drag.
 * Features real-time dynamic specular holographic lighting sheen.
 * Runs on GPU RenderNode layer with 0 recomposition lag.
 */
fun Modifier.interactive3dHover(
    enabled: Boolean = true,
    shape: Shape = RoundedCornerShape(16.dp),
    maxTiltDegrees: Float = 12f,
    scaleOnHover: Float = 1.025f,
    elevationOnHover: Dp = 12.dp,
    defaultElevation: Dp = 2.dp,
    enableSpecularGlare: Boolean = true
): Modifier = composed {
    val isGlobal3dEnabled by BookMySpaceRepository.is3dInteractiveModeEnabled.collectAsState()
    val isSafeMode by com.bookmyspace.bookmyspace.data.healing.AppHangSelfHealingWatchdog.isSafePerformanceMode.collectAsState()
    val sensitivity by BookMySpaceRepository.interactive3dTiltSensitivity.collectAsState()
    val effectiveEnabled = enabled && isGlobal3dEnabled && !isSafeMode

    if (!effectiveEnabled) {
        return@composed this
    }

    var componentSize by remember { mutableStateOf(IntSize.Zero) }
    var isHoveredState by remember { mutableStateOf(false) }
    var isPressedState by remember { mutableStateOf(false) }

    val rotX = remember { Animatable(0f) }
    val rotY = remember { Animatable(0f) }
    val scale = remember { Animatable(1f) }
    val elevation = remember { Animatable(defaultElevation.value) }
    val glareCenterX = remember { Animatable(0f) }
    val glareCenterY = remember { Animatable(0f) }

    val coroutineScope = rememberCoroutineScope()
    var activeAnimJob by remember { mutableStateOf<kotlinx.coroutines.Job?>(null) }
    val density = LocalDensity.current

    val springSpec = remember {
        spring<Float>(
            dampingRatio = Spring.DampingRatioMediumBouncy,
            stiffness = 500f
        )
    }
    val returnSpringSpec = remember {
        spring<Float>(
            dampingRatio = 0.8f,
            stiffness = Spring.StiffnessLow
        )
    }

    this
        .onSizeChanged { componentSize = it }
        .pointerHoverIcon(PointerIcon.Hand)
        .pointerInput(effectiveEnabled, sensitivity) {
            awaitPointerEventScope {
                while (true) {
                    val event = awaitPointerEvent()
                    val change = event.changes.firstOrNull() ?: continue
                    val pos = change.position
                    val width = size.width.toFloat()
                    val height = size.height.toFloat()

                    when (event.type) {
                        PointerEventType.Move -> {
                            if (width > 0f && height > 0f) {
                                isHoveredState = true
                                val centerX = width / 2f
                                val centerY = height / 2f
                                val normX = ((pos.x - centerX) / centerX).coerceIn(-1.2f, 1.2f)
                                val normY = ((pos.y - centerY) / centerY).coerceIn(-1.2f, 1.2f)

                                val tiltAmount = maxTiltDegrees * sensitivity
                                val targetRotX = -normY * tiltAmount
                                val targetRotY = normX * tiltAmount

                                activeAnimJob?.cancel()
                                coroutineScope.launch {
                                    rotX.snapTo(targetRotX)
                                    rotY.snapTo(targetRotY)
                                    glareCenterX.snapTo(pos.x)
                                    glareCenterY.snapTo(pos.y)
                                    if (!isPressedState && scale.value != scaleOnHover) {
                                        scale.snapTo(scaleOnHover)
                                        elevation.snapTo(elevationOnHover.value)
                                    }
                                }
                            }
                        }
                        PointerEventType.Enter -> {
                            isHoveredState = true
                            activeAnimJob?.cancel()
                            activeAnimJob = coroutineScope.launch {
                                scale.animateTo(scaleOnHover, springSpec)
                                elevation.animateTo(elevationOnHover.value, springSpec)
                            }
                        }
                        PointerEventType.Exit -> {
                            isHoveredState = false
                            isPressedState = false
                            activeAnimJob?.cancel()
                            activeAnimJob = coroutineScope.launch {
                                launch { rotX.animateTo(0f, returnSpringSpec) }
                                launch { rotY.animateTo(0f, returnSpringSpec) }
                                launch { scale.animateTo(1f, returnSpringSpec) }
                                launch { elevation.animateTo(defaultElevation.value, returnSpringSpec) }
                            }
                        }
                        PointerEventType.Press -> {
                            isPressedState = true
                            activeAnimJob?.cancel()
                            activeAnimJob = coroutineScope.launch {
                                scale.animateTo(0.98f, springSpec)
                            }
                        }
                        PointerEventType.Release -> {
                            isPressedState = false
                            activeAnimJob?.cancel()
                            activeAnimJob = coroutineScope.launch {
                                scale.animateTo(if (isHoveredState) scaleOnHover else 1f, springSpec)
                            }
                        }
                    }
                }
            }
        }
        .graphicsLayer {
            if (effectiveEnabled) {
                rotationX = rotX.value
                rotationY = rotY.value
                scaleX = scale.value
                scaleY = scale.value
                cameraDistance = 16f * density.density
                shadowElevation = elevation.value.dp.toPx()
                this.shape = shape
                this.clip = true
            }
        }
        .drawWithContent {
            drawContent()
            if (effectiveEnabled && isHoveredState && enableSpecularGlare && componentSize.width > 0) {
                val radius = max(size.width, size.height) * 0.8f
                drawRect(
                    brush = Brush.radialGradient(
                        colors = listOf(
                            Color.White.copy(alpha = 0.18f),
                            Color.White.copy(alpha = 0.05f),
                            Color.Transparent
                        ),
                        center = Offset(glareCenterX.value, glareCenterY.value),
                        radius = radius
                    ),
                    blendMode = BlendMode.Screen
                )
            }
        }
}

/**
 * Compact HUD badge showing live 3D Action Mode status with quick toggle.
 */
@Composable
fun Live3dInteractiveStatusBadge(
    onOpenStudio: () -> Unit,
    modifier: Modifier = Modifier
) {
    val is3dEnabled by BookMySpaceRepository.is3dInteractiveModeEnabled.collectAsState()
    val sensitivity by BookMySpaceRepository.interactive3dTiltSensitivity.collectAsState()

    Surface(
        onClick = onOpenStudio,
        shape = RoundedCornerShape(20.dp),
        color = if (is3dEnabled) MaterialTheme.colorScheme.primaryContainer.copy(alpha = 0.7f) else MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.6f),
        border = BorderStroke(
            1.dp,
            if (is3dEnabled) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.outlineVariant
        ),
        modifier = modifier
            .testTag("live_3d_mode_hud_badge")
            .interactive3dHover(
                enabled = true,
                maxTiltDegrees = 8f,
                scaleOnHover = 1.05f,
                shape = RoundedCornerShape(20.dp)
            )
    ) {
        Row(
            modifier = Modifier.padding(horizontal = 10.dp, vertical = 6.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(6.dp)
        ) {
            Box(
                modifier = Modifier
                    .size(8.dp)
                    .clip(CircleShape)
                    .background(if (is3dEnabled) Color(0xFF10B981) else Color(0xFF94A3B8))
            )
            Icon(
                imageVector = if (is3dEnabled) Icons.Default.ViewInAr else Icons.Default.Layers,
                contentDescription = null,
                tint = if (is3dEnabled) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.onSurfaceVariant,
                modifier = Modifier.size(16.dp)
            )
            Text(
                text = if (is3dEnabled) "3D Tilt Active" else "3D Off",
                fontSize = 12.sp,
                fontWeight = FontWeight.Bold,
                color = if (is3dEnabled) MaterialTheme.colorScheme.onPrimaryContainer else MaterialTheme.colorScheme.onSurfaceVariant
            )
            if (is3dEnabled && sensitivity > 1.1f) {
                Surface(
                    shape = RoundedCornerShape(4.dp),
                    color = MaterialTheme.colorScheme.primary,
                    modifier = Modifier.padding(start = 2.dp)
                ) {
                    Text(
                        text = "MAX",
                        fontSize = 9.sp,
                        fontWeight = FontWeight.Black,
                        color = MaterialTheme.colorScheme.onPrimary,
                        modifier = Modifier.padding(horizontal = 3.dp, vertical = 1.dp)
                    )
                }
            }
        }
    }
}
