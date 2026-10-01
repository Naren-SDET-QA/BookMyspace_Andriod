package com.bookmyspace.bookmyspace.ui.components

import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.Spring
import androidx.compose.animation.core.spring
import androidx.compose.foundation.clickable
import androidx.compose.foundation.gestures.detectDragGestures
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.drawWithContent
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.*
import androidx.compose.ui.input.pointer.PointerEventType
import androidx.compose.ui.input.pointer.pointerHoverIcon
import androidx.compose.ui.input.pointer.PointerIcon
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.layout.onSizeChanged
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.IntSize
import androidx.compose.ui.unit.dp
import kotlinx.coroutines.launch
import kotlin.math.cos
import kotlin.math.max
import kotlin.math.sin

/**
 * 4x4 Homogeneous Transformation Matrix (Matrix4).
 * Supports 3D projective geometry with perspective transform (setEntry(3, 2, factor)),
 * 3-axis rotation, translation, and scaling.
 */
class Matrix4(val storage: FloatArray = FloatArray(16)) {

    init {
        if (storage.all { it == 0f }) {
            setIdentity()
        }
    }

    fun setIdentity(): Matrix4 {
        for (i in 0 until 16) storage[i] = 0f
        storage[0] = 1f   // [0,0]
        storage[5] = 1f   // [1,1]
        storage[10] = 1f  // [2,2]
        storage[15] = 1f  // [3,3]
        rotXDegrees = 0f
        rotYDegrees = 0f
        rotZDegrees = 0f
        scaleFactorX = 1f
        scaleFactorY = 1f
        transX = 0f
        transY = 0f
        return this
    }

    /**
     * Sets value at [row, col] in 0-indexed homogeneous matrix.
     * Column-major index mapping: col * 4 + row.
     * In standard 3D perspective projection, row 3 col 2 defines the z-perspective divisor:
     * setEntry(3, 2, 0.0018f) gives authentic depth foreshortening.
     */
    fun setEntry(row: Int, col: Int, value: Float): Matrix4 {
        require(row in 0..3 && col in 0..3) { "Row and col must be in 0..3" }
        storage[col * 4 + row] = value
        return this
    }

    fun getEntry(row: Int, col: Int): Float {
        require(row in 0..3 && col in 0..3) { "Row and col must be in 0..3" }
        return storage[col * 4 + row]
    }

    fun setPerspective(factor: Float): Matrix4 {
        setEntry(3, 2, factor)
        return this
    }

    var rotXDegrees: Float = 0f
        private set
    var rotYDegrees: Float = 0f
        private set
    var rotZDegrees: Float = 0f
        private set
    var scaleFactorX: Float = 1f
        private set
    var scaleFactorY: Float = 1f
        private set
    var transX: Float = 0f
        private set
    var transY: Float = 0f
        private set

    fun rotateX(degrees: Float): Matrix4 {
        rotXDegrees += degrees
        val rad = Math.toRadians(degrees.toDouble()).toFloat()
        val c = cos(rad)
        val s = sin(rad)
        val m1 = storage[1] * c - storage[2] * s
        val m2 = storage[1] * s + storage[2] * c
        val m5 = storage[5] * c - storage[6] * s
        val m6 = storage[5] * s + storage[6] * c
        val m9 = storage[9] * c - storage[10] * s
        val m10 = storage[9] * s + storage[10] * c
        storage[1] = m1
        storage[2] = m2
        storage[5] = m5
        storage[6] = m6
        storage[9] = m9
        storage[10] = m10
        return this
    }

    fun rotateY(degrees: Float): Matrix4 {
        rotYDegrees += degrees
        val rad = Math.toRadians(degrees.toDouble()).toFloat()
        val c = cos(rad)
        val s = sin(rad)
        val m0 = storage[0] * c + storage[2] * s
        val m2 = -storage[0] * s + storage[2] * c
        val m4 = storage[4] * c + storage[6] * s
        val m6 = -storage[4] * s + storage[6] * c
        val m8 = storage[8] * c + storage[10] * s
        val m10 = -storage[8] * s + storage[10] * c
        storage[0] = m0
        storage[2] = m2
        storage[4] = m4
        storage[6] = m6
        storage[8] = m8
        storage[10] = m10
        return this
    }

    fun scale(sx: Float, sy: Float, sz: Float = 1f): Matrix4 {
        scaleFactorX *= sx
        scaleFactorY *= sy
        storage[0] *= sx
        storage[1] *= sx
        storage[2] *= sx
        storage[3] *= sx
        storage[4] *= sy
        storage[5] *= sy
        storage[6] *= sy
        storage[7] *= sy
        storage[8] *= sz
        storage[9] *= sz
        storage[10] *= sz
        storage[11] *= sz
        return this
    }

    fun translate(x: Float, y: Float, z: Float = 0f): Matrix4 {
        transX += x
        transY += y
        storage[12] += x
        storage[13] += y
        storage[14] += z
        return this
    }

    companion object {
        fun identity(): Matrix4 = Matrix4().setIdentity()
    }
}

/**
 * Transform Widget:
 * Renders child composable content through a 4x4 [Matrix4] perspective transform.
 * Directly hardware-accelerates 3D projective geometry onto the GPU RenderNode layer.
 */
@Composable
fun Transform(
    transform: Matrix4,
    modifier: Modifier = Modifier,
    origin: TransformOrigin = TransformOrigin.Center,
    content: @Composable () -> Unit
) {
    val density = LocalDensity.current
    val perspective = transform.getEntry(3, 2)
    // Convert perspective entry (e.g. 0.0018f) into cameraDistance points
    val camDistance = if (perspective > 0f) {
        val calculated = (1f / perspective) * 0.022f * density.density
        calculated.coerceIn(8f * density.density, 32f * density.density)
    } else {
        16f * density.density
    }

    Box(
        modifier = modifier.graphicsLayer {
            rotationX = transform.rotXDegrees
            rotationY = transform.rotYDegrees
            scaleX = transform.scaleFactorX
            scaleY = transform.scaleFactorY
            translationX = transform.transX
            translationY = transform.transY
            cameraDistance = camDistance
            transformOrigin = origin
        }
    ) {
        content()
    }
}

/**
 * Interactive Gesture Transform Container for Category Cards.
 * Delivers realistic glass-morphism matrix behavior based on user touches and gestures.
 * Calculates dynamic Matrix4 with perspective factor (setEntry(3, 2, perspectiveFactor))
 * and passes it to the [Transform] widget.
 */
@Composable
fun TransformGestureGlassCard(
    modifier: Modifier = Modifier,
    baseTiltY: Float = 0f,
    maxTiltDegrees: Float = 11f,
    perspectiveFactor: Float = 0.0018f,
    elevation: Dp = 8.dp,
    shape: Shape = RoundedCornerShape(18.dp),
    isDark: Boolean = false,
    ambientGlowColor: Color = Color(0xFF06B6D4), // Cyan
    spotGlowColor: Color = Color(0xFF0D9488),   // Teal
    onClick: (() -> Unit)? = null,
    content: @Composable (
        matrix: Matrix4,
        isHovered: Boolean,
        isPressed: Boolean,
        currentTiltX: Float,
        currentTiltY: Float
    ) -> Unit
) {
    val isSafeMode by com.bookmyspace.bookmyspace.data.healing.AppHangSelfHealingWatchdog.isSafePerformanceMode.collectAsState()
    val is3dEnabled by com.bookmyspace.bookmyspace.data.repository.BookMySpaceRepository.is3dInteractiveModeEnabled.collectAsState()
    val effective3d = is3dEnabled && !isSafeMode

    var componentSize by remember { mutableStateOf(IntSize.Zero) }
    var isHoveredState by remember { mutableStateOf(false) }
    var isPressedState by remember { mutableStateOf(false) }

    val rotX = remember { Animatable(0f) }
    val rotY = remember { Animatable(0f) }
    val scale = remember { Animatable(1f) }
    val glareX = remember { Animatable(0f) }
    val glareY = remember { Animatable(0f) }

    val coroutineScope = rememberCoroutineScope()
    var activeAnimJob by remember { mutableStateOf<kotlinx.coroutines.Job?>(null) }

    val springSpec = remember {
        spring<Float>(
            dampingRatio = Spring.DampingRatioMediumBouncy,
            stiffness = 650f
        )
    }
    val returnSpringSpec = remember {
        spring<Float>(
            dampingRatio = 0.82f,
            stiffness = Spring.StiffnessLow
        )
    }

    val density = LocalDensity.current
    val camDistance = remember(perspectiveFactor, density.density) {
        if (perspectiveFactor > 0f) {
            val calculated = (1f / perspectiveFactor) * 0.022f * density.density
            calculated.coerceIn(8f * density.density, 32f * density.density)
        } else {
            16f * density.density
        }
    }

    // Static identity or base matrix - does not trigger continuous recomposition
    val staticMatrix = remember(baseTiltY, effective3d) {
        if (!effective3d) {
            Matrix4.identity()
        } else {
            Matrix4.identity().apply {
                setEntry(3, 2, perspectiveFactor)
                rotateY(baseTiltY)
            }
        }
    }

    val shadowElevation = if (isHoveredState && effective3d) elevation + 4.dp else elevation

    val cardModifier = if (effective3d) {
        modifier
            .onSizeChanged { componentSize = it }
            .shadow(
                elevation = shadowElevation,
                shape = shape,
                ambientColor = ambientGlowColor.copy(alpha = if (isHoveredState) 0.35f else 0.18f),
                spotColor = spotGlowColor.copy(alpha = if (isHoveredState) 0.45f else 0.22f)
            )
            .pointerHoverIcon(PointerIcon.Hand)
            .pointerInput(effective3d) {
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
                                    val normX = ((pos.x - centerX) / centerX).coerceIn(-1.1f, 1.1f)
                                    val normY = ((pos.y - centerY) / centerY).coerceIn(-1.1f, 1.1f)

                                    val targetRotX = -normY * maxTiltDegrees
                                    val targetRotY = normX * maxTiltDegrees

                                    // Direct GPU snap during drag avoids scheduling heavy spring animations on every touch
                                    activeAnimJob?.cancel()
                                    coroutineScope.launch {
                                        rotX.snapTo(targetRotX)
                                        rotY.snapTo(targetRotY)
                                        glareX.snapTo(pos.x)
                                        glareY.snapTo(pos.y)
                                        if (!isPressedState && scale.value != 1.02f) {
                                            scale.snapTo(1.02f)
                                        }
                                    }
                                }
                            }
                            PointerEventType.Enter -> {
                                isHoveredState = true
                                activeAnimJob?.cancel()
                                activeAnimJob = coroutineScope.launch { scale.animateTo(1.02f, springSpec) }
                            }
                            PointerEventType.Exit -> {
                                isHoveredState = false
                                isPressedState = false
                                activeAnimJob?.cancel()
                                activeAnimJob = coroutineScope.launch {
                                    launch { rotX.animateTo(0f, returnSpringSpec) }
                                    launch { rotY.animateTo(0f, returnSpringSpec) }
                                    launch { scale.animateTo(1f, returnSpringSpec) }
                                }
                            }
                            PointerEventType.Press -> {
                                isPressedState = true
                                activeAnimJob?.cancel()
                                activeAnimJob = coroutineScope.launch { scale.animateTo(0.97f, springSpec) }
                            }
                            PointerEventType.Release -> {
                                isPressedState = false
                                activeAnimJob?.cancel()
                                activeAnimJob = coroutineScope.launch {
                                    scale.animateTo(if (isHoveredState) 1.02f else 1f, springSpec)
                                }
                            }
                        }
                    }
                }
            }
            .then(
                if (onClick != null) {
                    Modifier.clickable(
                        interactionSource = remember { MutableInteractionSource() },
                        indication = null,
                        onClick = onClick
                    )
                } else Modifier
            )
    } else {
        // High-Performance Safe Mode: zero coroutines, zero gesture capture, standard M3 shadow & click
        modifier
            .shadow(
                elevation = elevation,
                shape = shape,
                ambientColor = ambientGlowColor.copy(alpha = 0.12f),
                spotColor = spotGlowColor.copy(alpha = 0.15f)
            )
            .then(
                if (onClick != null) {
                    Modifier.clickable(
                        interactionSource = remember { MutableInteractionSource() },
                        indication = null,
                        onClick = onClick
                    )
                } else Modifier
            )
    }

    Box(modifier = cardModifier) {
        if (effective3d) {
            Box(
                modifier = Modifier
                    .graphicsLayer {
                        rotationX = rotX.value
                        rotationY = rotY.value + baseTiltY
                        scaleX = scale.value
                        scaleY = scale.value
                        cameraDistance = camDistance
                    }
                    .clip(shape)
                    .drawWithContent {
                        drawContent()
                        if (isHoveredState || isPressedState) {
                            val glareRadius = max(size.width, size.height) * 0.75f
                            drawRect(
                                brush = Brush.radialGradient(
                                    colors = listOf(
                                        Color.White.copy(alpha = if (isDark) 0.15f else 0.28f),
                                        Color.White.copy(alpha = 0.04f),
                                        Color.Transparent
                                    ),
                                    center = Offset(glareX.value, glareY.value),
                                    radius = glareRadius
                                ),
                                blendMode = BlendMode.Screen
                            )
                        }
                    }
            ) {
                content(staticMatrix, isHoveredState, isPressedState, 0f, baseTiltY)
            }
        } else {
            Box(modifier = Modifier.clip(shape)) {
                content(staticMatrix, false, false, 0f, baseTiltY)
            }
        }
    }
}
