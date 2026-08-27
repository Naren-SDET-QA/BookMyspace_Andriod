package com.bookmyspace.bookmyspace.ui.components

import android.Manifest
import android.content.Context
import android.widget.Toast
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.animation.*
import androidx.compose.animation.core.*
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.scale
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.bookmyspace.bookmyspace.data.repository.BookMySpaceRepository
import com.bookmyspace.bookmyspace.util.*
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

/**
 * Suggested voice command presets for user discovery.
 */
data class VoiceCommandPrompt(
    val emoji: String,
    val phrase: String,
    val categoryLabel: String
)

val sampleVoicePrompts = listOf(
    VoiceCommandPrompt("🏰", "AC Banquet Hall in Hyderabad under 50k with parking", "Function Halls"),
    VoiceCommandPrompt("🏡", "Gents PG in Madhapur with Wi-Fi and 2 sharing", "PG & Hostels"),
    VoiceCommandPrompt("🏨", "5 Star Luxury Hotel with swimming pool", "Hotels & Stays"),
    VoiceCommandPrompt("🏏", "Cheapest Cricket Turf with night lights", "Sports Turf"),
    VoiceCommandPrompt("💼", "Meeting room with high speed internet", "Coworking"),
    VoiceCommandPrompt("🔄", "Reset and clear all filters", "Reset")
)

/**
 * Modern Material 3 Interactive Voice Search & Filter Bottom Sheet.
 * Directly interfaces with Android's SpeechRecognizer, captures live microphone audio,
 * animates audio waveform decibels, parses natural language into search & filter parameters,
 * and speaks back intelligent audio confirmations using TTS.
 */
@OptIn(ExperimentalMaterial3Api::class, ExperimentalLayoutApi::class)
@Composable
fun VoiceSearchFilterBottomSheet(
    onDismiss: () -> Unit,
    onApplyVoiceFilter: (VoiceFilterResult) -> Unit,
    modifier: Modifier = Modifier
) {
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    val speechHelper = remember { SpeechHelper.getInstance(context) }
    val voiceHelper = remember { VoiceRecognitionHelper(context) }
    val voiceState by voiceHelper.state.collectAsState()
    val rmsLevel by voiceHelper.rmsAudioLevel.collectAsState()

    var hasMicPermission by remember {
        mutableStateOf(VoiceRecognitionHelper.isPermissionGranted(context))
    }

    val permissionLauncher = rememberLauncherForActivityResult(
        contract = ActivityResultContracts.RequestPermission()
    ) { isGranted ->
        hasMicPermission = isGranted
        if (isGranted) {
            voiceHelper.startListening()
        } else {
            Toast.makeText(context, "Microphone permission is required for Voice Search", Toast.LENGTH_LONG).show()
        }
    }

    var recognizedQuery by remember { mutableStateOf<String?>(null) }
    var parsedResult by remember { mutableStateOf<VoiceFilterResult?>(null) }

    // Start listening automatically if permission is already granted
    LaunchedEffect(Unit) {
        if (hasMicPermission) {
            voiceHelper.startListening()
        } else {
            permissionLauncher.launch(Manifest.permission.RECORD_AUDIO)
        }
    }

    // React to speech state transitions
    LaunchedEffect(voiceState) {
        when (val state = voiceState) {
            is VoiceRecognitionState.Success -> {
                recognizedQuery = state.recognizedText
                val parsed = VoiceCommandFilterParser.parseVoiceCommand(state.recognizedText)
                parsedResult = parsed
                // Audio confirmation via TTS
                speechHelper.speak(parsed.spokenFeedbackMessage)
            }
            is VoiceRecognitionState.PermissionRequired -> {
                hasMicPermission = false
                permissionLauncher.launch(Manifest.permission.RECORD_AUDIO)
            }
            else -> {}
        }
    }

    DisposableEffect(Unit) {
        onDispose {
            voiceHelper.destroy()
            speechHelper.stop()
        }
    }

    ModalBottomSheet(
        onDismissRequest = {
            voiceHelper.cancel()
            speechHelper.stop()
            onDismiss()
        },
        shape = RoundedCornerShape(topStart = 28.dp, topEnd = 28.dp),
        dragHandle = { BottomSheetDefaults.DragHandle() },
        modifier = modifier.testTag("voice_search_bottom_sheet")
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 22.dp, vertical = 8.dp),
            horizontalAlignment = Alignment.CenterHorizontally
        ) {
            // Header Bar
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Surface(
                        shape = CircleShape,
                        color = MaterialTheme.colorScheme.primaryContainer,
                        modifier = Modifier.size(36.dp)
                    ) {
                        Box(contentAlignment = Alignment.Center) {
                            Text("🎙️", fontSize = 18.sp)
                        }
                    }
                    Spacer(modifier = Modifier.width(10.dp))
                    Column {
                        Text(
                            text = "Voice Search & Filter",
                            fontSize = 17.sp,
                            fontWeight = FontWeight.ExtraBold,
                            color = MaterialTheme.colorScheme.onSurface
                        )
                        Text(
                            text = "Speak venue name, type, budget or amenities",
                            fontSize = 11.sp,
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                    }
                }

                IconButton(
                    onClick = {
                        voiceHelper.cancel()
                        speechHelper.stop()
                        onDismiss()
                    },
                    modifier = Modifier.testTag("close_voice_search_sheet_btn")
                ) {
                    Icon(Icons.Default.Close, contentDescription = "Close Voice Search")
                }
            }

            Spacer(modifier = Modifier.height(16.dp))

            // Permission Request Banner if missing
            if (!hasMicPermission) {
                Card(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(vertical = 8.dp),
                    shape = RoundedCornerShape(16.dp),
                    colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.errorContainer.copy(alpha = 0.4f)),
                    border = BorderStroke(1.dp, MaterialTheme.colorScheme.error.copy(alpha = 0.5f))
                ) {
                    Column(
                        modifier = Modifier.padding(16.dp),
                        horizontalAlignment = Alignment.CenterHorizontally
                    ) {
                        Icon(Icons.Default.MicOff, contentDescription = null, tint = MaterialTheme.colorScheme.error, modifier = Modifier.size(32.dp))
                        Spacer(modifier = Modifier.height(8.dp))
                        Text(
                            text = "Microphone Access Required",
                            fontWeight = FontWeight.Bold,
                            fontSize = 14.sp,
                            color = MaterialTheme.colorScheme.error
                        )
                        Text(
                            text = "To search and filter spaces using voice commands, please grant BookMySpace microphone recording permission.",
                            fontSize = 12.sp,
                            textAlign = TextAlign.Center,
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                            modifier = Modifier.padding(vertical = 6.dp)
                        )
                        Button(
                            onClick = { permissionLauncher.launch(Manifest.permission.RECORD_AUDIO) },
                            shape = RoundedCornerShape(12.dp),
                            modifier = Modifier.testTag("grant_mic_permission_btn")
                        ) {
                            Text("Grant Microphone Access", fontWeight = FontWeight.Bold)
                        }
                    }
                }
            } else {
                // Interactive Voice Input Center View
                VoiceVisualizerSection(
                    voiceState = voiceState,
                    rmsLevel = rmsLevel,
                    onStartListening = {
                        recognizedQuery = null
                        parsedResult = null
                        voiceHelper.startListening()
                    },
                    onStopListening = {
                        voiceHelper.stopListening()
                    }
                )

                Spacer(modifier = Modifier.height(16.dp))

                // Recognized Speech & Extracted Filter Badges
                if (parsedResult != null) {
                    val result = parsedResult!!
                    Card(
                        modifier = Modifier
                            .fillMaxWidth()
                            .testTag("voice_recognition_result_card"),
                        shape = RoundedCornerShape(18.dp),
                        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.primaryContainer.copy(alpha = 0.35f)),
                        border = BorderStroke(1.5.dp, MaterialTheme.colorScheme.primary.copy(alpha = 0.5f))
                    ) {
                        Column(modifier = Modifier.padding(16.dp)) {
                            Row(
                                modifier = Modifier.fillMaxWidth(),
                                horizontalArrangement = Arrangement.SpaceBetween,
                                verticalAlignment = Alignment.CenterVertically
                            ) {
                                Row(verticalAlignment = Alignment.CenterVertically) {
                                    Icon(
                                        imageVector = Icons.Default.CheckCircle,
                                        contentDescription = null,
                                        tint = Color(0xFF2E7D32),
                                        modifier = Modifier.size(16.dp)
                                    )
                                    Spacer(modifier = Modifier.width(6.dp))
                                    Text(
                                        text = "Voice Command Understood",
                                        fontWeight = FontWeight.Bold,
                                        fontSize = 13.sp,
                                        color = MaterialTheme.colorScheme.primary
                                    )
                                }

                                IconButton(
                                    onClick = {
                                        speechHelper.speak(result.spokenFeedbackMessage)
                                    },
                                    modifier = Modifier.size(24.dp)
                                ) {
                                    Icon(
                                        imageVector = Icons.Default.VolumeUp,
                                        contentDescription = "Replay Audio",
                                        tint = MaterialTheme.colorScheme.primary,
                                        modifier = Modifier.size(18.dp)
                                    )
                                }
                            }

                            Spacer(modifier = Modifier.height(8.dp))
                            Text(
                                text = "\"${result.rawSpokenText}\"",
                                fontSize = 16.sp,
                                fontWeight = FontWeight.ExtraBold,
                                color = MaterialTheme.colorScheme.onSurface
                            )

                            if (result.badges.isNotEmpty()) {
                                Spacer(modifier = Modifier.height(12.dp))
                                Text(
                                    text = "PARSED FILTERS DETECTED:",
                                    fontSize = 10.sp,
                                    fontWeight = FontWeight.Black,
                                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                                    letterSpacing = 0.8.sp
                                )
                                Spacer(modifier = Modifier.height(6.dp))
                                FlowRow(
                                    modifier = Modifier.fillMaxWidth(),
                                    horizontalArrangement = Arrangement.spacedBy(6.dp),
                                    verticalArrangement = Arrangement.spacedBy(6.dp)
                                ) {
                                    result.badges.forEach { badge ->
                                        Surface(
                                            shape = RoundedCornerShape(8.dp),
                                            color = MaterialTheme.colorScheme.surface,
                                            border = BorderStroke(1.dp, MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.6f))
                                        ) {
                                            Row(
                                                modifier = Modifier.padding(horizontal = 8.dp, vertical = 4.dp),
                                                verticalAlignment = Alignment.CenterVertically
                                            ) {
                                                Text(badge.iconEmoji, fontSize = 12.sp)
                                                Spacer(modifier = Modifier.width(4.dp))
                                                Text(
                                                    text = "${badge.title}: ",
                                                    fontSize = 11.sp,
                                                    fontWeight = FontWeight.SemiBold,
                                                    color = MaterialTheme.colorScheme.onSurfaceVariant
                                                )
                                                Text(
                                                    text = badge.value,
                                                    fontSize = 11.sp,
                                                    fontWeight = FontWeight.Bold,
                                                    color = MaterialTheme.colorScheme.primary
                                                )
                                            }
                                        }
                                    }
                                }
                            }

                            Spacer(modifier = Modifier.height(16.dp))

                            // Main CTA to Apply Filters
                            Row(
                                modifier = Modifier.fillMaxWidth(),
                                horizontalArrangement = Arrangement.spacedBy(10.dp)
                            ) {
                                OutlinedButton(
                                    onClick = {
                                        recognizedQuery = null
                                        parsedResult = null
                                        voiceHelper.startListening()
                                    },
                                    shape = RoundedCornerShape(12.dp),
                                    modifier = Modifier
                                        .weight(1f)
                                        .testTag("speak_again_btn")
                                ) {
                                    Icon(Icons.Default.Refresh, contentDescription = null, modifier = Modifier.size(16.dp))
                                    Spacer(modifier = Modifier.width(6.dp))
                                    Text("Speak Again", fontSize = 12.sp, fontWeight = FontWeight.Bold)
                                }

                                Button(
                                    onClick = {
                                        onApplyVoiceFilter(result)
                                        voiceHelper.cancel()
                                        speechHelper.stop()
                                        onDismiss()
                                    },
                                    shape = RoundedCornerShape(12.dp),
                                    modifier = Modifier
                                        .weight(1.5f)
                                        .testTag("apply_voice_filters_btn")
                                ) {
                                    Icon(Icons.Default.FilterList, contentDescription = null, modifier = Modifier.size(16.dp))
                                    Spacer(modifier = Modifier.width(6.dp))
                                    Text("Apply & Search", fontSize = 12.sp, fontWeight = FontWeight.Bold)
                                }
                            }
                        }
                    }
                } else {
                    // Suggested Prompts / Discovery Carousel
                    Column(modifier = Modifier.fillMaxWidth()) {
                        Text(
                            text = "💡 TRY SAYING SOMETHING LIKE:",
                            fontSize = 10.5.sp,
                            fontWeight = FontWeight.Black,
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                            letterSpacing = 0.5.sp
                        )
                        Spacer(modifier = Modifier.height(8.dp))

                        LazyRow(
                            horizontalArrangement = Arrangement.spacedBy(8.dp),
                            modifier = Modifier.fillMaxWidth()
                        ) {
                            items(sampleVoicePrompts) { prompt ->
                                Card(
                                    shape = RoundedCornerShape(14.dp),
                                    colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.5f)),
                                    border = BorderStroke(1.dp, MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.5f)),
                                    modifier = Modifier
                                        .clickable {
                                            recognizedQuery = prompt.phrase
                                            val parsed = VoiceCommandFilterParser.parseVoiceCommand(prompt.phrase)
                                            parsedResult = parsed
                                            speechHelper.speak(parsed.spokenFeedbackMessage)
                                        }
                                        .testTag("voice_suggestion_${prompt.categoryLabel}")
                                ) {
                                    Column(
                                        modifier = Modifier
                                            .width(220.dp)
                                            .padding(12.dp)
                                    ) {
                                        Row(
                                            verticalAlignment = Alignment.CenterVertically,
                                            horizontalArrangement = Arrangement.SpaceBetween,
                                            modifier = Modifier.fillMaxWidth()
                                        ) {
                                            Text(prompt.emoji, fontSize = 18.sp)
                                            Surface(
                                                shape = RoundedCornerShape(6.dp),
                                                color = MaterialTheme.colorScheme.primary.copy(alpha = 0.12f)
                                            ) {
                                                Text(
                                                    text = prompt.categoryLabel,
                                                    fontSize = 9.5.sp,
                                                    fontWeight = FontWeight.Bold,
                                                    color = MaterialTheme.colorScheme.primary,
                                                    modifier = Modifier.padding(horizontal = 6.dp, vertical = 2.dp)
                                                )
                                            }
                                        }
                                        Spacer(modifier = Modifier.height(6.dp))
                                        Text(
                                            text = "\"${prompt.phrase}\"",
                                            fontSize = 12.sp,
                                            fontWeight = FontWeight.Medium,
                                            color = MaterialTheme.colorScheme.onSurface,
                                            maxLines = 2
                                        )
                                    }
                                }
                            }
                        }
                    }
                }
            }

            Spacer(modifier = Modifier.height(16.dp))
        }
    }
}

/**
 * Animated Microphone & Live Audio Waveform Decibel Visualizer.
 */
@Composable
private fun VoiceVisualizerSection(
    voiceState: VoiceRecognitionState,
    rmsLevel: Float,
    onStartListening: () -> Unit,
    onStopListening: () -> Unit
) {
    val isListening = voiceState is VoiceRecognitionState.Listening || voiceState is VoiceRecognitionState.Initializing || voiceState is VoiceRecognitionState.ReadyToSpeak

    val infiniteTransition = rememberInfiniteTransition()
    val pulseScale by infiniteTransition.animateFloat(
        initialValue = 1.0f,
        targetValue = if (isListening) 1.22f else 1.0f,
        animationSpec = infiniteRepeatable(
            animation = tween(900, easing = FastOutSlowInEasing),
            repeatMode = RepeatMode.Reverse
        )
    )

    Column(
        horizontalAlignment = Alignment.CenterHorizontally,
        modifier = Modifier.fillMaxWidth()
    ) {
        Box(
            contentAlignment = Alignment.Center,
            modifier = Modifier.size(130.dp)
        ) {
            // Concentric Ripple Ring 2
            if (isListening) {
                Box(
                    modifier = Modifier
                        .size((110 * (1f + rmsLevel * 0.45f)).dp)
                        .scale(pulseScale)
                        .clip(CircleShape)
                        .background(MaterialTheme.colorScheme.primary.copy(alpha = 0.12f))
                )
                // Concentric Ripple Ring 1
                Box(
                    modifier = Modifier
                        .size((90 * (1f + rmsLevel * 0.3f)).dp)
                        .clip(CircleShape)
                        .background(MaterialTheme.colorScheme.primary.copy(alpha = 0.22f))
                )
            }

            // Central Mic Button
            Surface(
                shape = CircleShape,
                color = if (isListening) Color(0xFFD32F2F) else MaterialTheme.colorScheme.primary,
                shadowElevation = 6.dp,
                modifier = Modifier
                    .size(72.dp)
                    .clickable {
                        if (isListening) onStopListening() else onStartListening()
                    }
                    .testTag("voice_record_mic_button")
            ) {
                Box(contentAlignment = Alignment.Center) {
                    Icon(
                        imageVector = if (isListening) Icons.Default.GraphicEq else Icons.Default.Mic,
                        contentDescription = "Voice Input Button",
                        tint = Color.White,
                        modifier = Modifier.size(36.dp)
                    )
                }
            }
        }

        Spacer(modifier = Modifier.height(10.dp))

        // State indicator text
        val statusText = when (voiceState) {
            is VoiceRecognitionState.Initializing -> "Initializing voice engine..."
            is VoiceRecognitionState.ReadyToSpeak -> "Listening... Speak now!"
            is VoiceRecognitionState.Listening -> {
                if (voiceState.partialText.isNotBlank()) "\"${voiceState.partialText}\""
                else "Listening... Speak your requirement"
            }
            is VoiceRecognitionState.Success -> "Understood! Processing filters..."
            is VoiceRecognitionState.Error -> voiceState.message
            is VoiceRecognitionState.PermissionRequired -> "Permission needed to listen"
            VoiceRecognitionState.Idle -> "Tap microphone to speak"
        }

        Text(
            text = statusText,
            fontSize = 13.sp,
            fontWeight = if (isListening) FontWeight.Bold else FontWeight.Medium,
            color = if (voiceState is VoiceRecognitionState.Error) MaterialTheme.colorScheme.error
            else if (isListening) MaterialTheme.colorScheme.primary
            else MaterialTheme.colorScheme.onSurfaceVariant,
            textAlign = TextAlign.Center,
            modifier = Modifier.padding(horizontal = 20.dp)
        )

        // Live Audio Equalizer Waveform Bars
        if (isListening) {
            Spacer(modifier = Modifier.height(12.dp))
            Row(
                horizontalArrangement = Arrangement.spacedBy(4.dp),
                verticalAlignment = Alignment.CenterVertically,
                modifier = Modifier.height(26.dp)
            ) {
                val barMultipliers = listOf(0.4f, 0.7f, 1.0f, 1.4f, 1.0f, 0.7f, 0.4f)
                barMultipliers.forEachIndexed { index, mult ->
                    val barHeight = (6 + (rmsLevel * 20 * mult)).coerceIn(4f, 24f).dp
                    Box(
                        modifier = Modifier
                            .width(4.dp)
                            .height(barHeight)
                            .clip(RoundedCornerShape(2.dp))
                            .background(
                                Brush.verticalGradient(
                                    colors = listOf(
                                        MaterialTheme.colorScheme.primary,
                                        MaterialTheme.colorScheme.tertiary
                                    )
                                )
                            )
                    )
                }
            }
        }
    }
}
