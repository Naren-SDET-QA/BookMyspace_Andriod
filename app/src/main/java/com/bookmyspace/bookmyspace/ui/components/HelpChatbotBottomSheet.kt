package com.bookmyspace.bookmyspace.ui.components

import android.content.Intent
import android.net.Uri
import androidx.compose.animation.*
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.gestures.detectDragGestures
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.Send
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.LocalConfiguration
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.IntOffset
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import java.text.SimpleDateFormat
import java.util.*
import kotlin.math.roundToInt

data class HelpChatMessage(
    val id: String = UUID.randomUUID().toString(),
    val text: String,
    val isBot: Boolean,
    val timestamp: String = SimpleDateFormat("hh:mm a", Locale.getDefault()).format(Date()),
    val actionRoute: String? = null,
    val actionLabel: String? = null,
    val externalUrl: String? = null
)

enum class ChatBotDisplayState {
    EXPANDED,
    MINIMIZED,
    CLOSED
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun HelpChatbotBottomSheet(
    currentRoute: String? = null,
    onDismiss: () -> Unit,
    onMinimize: (() -> Unit)? = null,
    onNavigateToRoute: ((String) -> Unit)? = null,
    modifier: Modifier = Modifier
) {
    val context = LocalContext.current
    val coroutineScope = rememberCoroutineScope()
    val listState = rememberLazyListState()

    val initialWelcomeText = remember(currentRoute) {
        when {
            currentRoute?.startsWith("venues/") == true ->
                "👋 Hello! I see you are checking venue details. Ask me about pricing, court time slots, cancellation rules, amenities, or directions!"
            currentRoute?.contains("/book") == true ->
                "👋 Need help booking? Pick your date, slot, and payment option. You can also apply promo codes like WELCOME10 for 10% off!"
            currentRoute?.contains("/pay") == true ->
                "👋 Need help with payment? We support instant UPI (GPay, PhonePe, Paytm), Credit/Debit cards, Net Banking, and Pay at Venue."
            currentRoute == "map" ->
                "👋 Need help finding venues on the map? Tap any marker to preview directions, facilities, and live slot availability."
            currentRoute == "bookings" ->
                "👋 Here are your bookings! You can view your QR Check-In pass, download PDF invoices, or cancel slots up to 2 hours before the session."
            else ->
                "👋 Hi there! I'm your BookMySpace AI Help Assistant. How can I help you today? Ask about bookings, refunds, venues, PGs, halls, or payments!"
        }
    }

    var messages by remember {
        mutableStateOf(
            listOf(
                HelpChatMessage(
                    text = initialWelcomeText,
                    isBot = true,
                    actionRoute = if (currentRoute != "bookings") "bookings" else null,
                    actionLabel = if (currentRoute != "bookings") "🎟️ View My Bookings" else null
                )
            )
        )
    }

    var inputText by remember { mutableStateOf("") }
    var isTyping by remember { mutableStateOf(false) }

    val quickQuestions = listOf(
        "Refund & Cancellation",
        "Wallet & Referrals",
        "How to book a slot?",
        "Active Promo Codes",
        "QR Pass for Check-In",
        "Payment Methods",
        "PG & Hostel rules",
        "List my Property / Hall",
        "Call Customer Care"
    )

    fun sendBotResponse(userQuery: String) {
        val q = userQuery.lowercase(Locale.getDefault()).trim()
        val botMessage: HelpChatMessage = when {
            q.contains("wallet") || q.contains("refer") || q.contains("credit") || q.contains("earn") || q.contains("reward") || q.contains("balance") -> {
                HelpChatMessage(
                    text = "💰 **BookMySpace Wallet & Rewards**:\n\n• **Wallet Balance**: 100% redeemable on all turf, hall, and room bookings.\n• **Refer & Earn**: Share your code with friends. You both receive **₹500 instant wallet credits** after their 1st booking!\n• Credits never expire.",
                    isBot = true,
                    actionRoute = "referral",
                    actionLabel = "👉 View Wallet & Referrals"
                )
            }
            q.contains("refund") || q.contains("cancel") || q.contains("money back") -> {
                HelpChatMessage(
                    text = "💵 **Refund & Cancellation Policy**:\n\n• You can cancel any confirmed booking up to **2 hours** before the slot start time from **My Bookings**.\n• A **90% refund** is immediately processed to your original payment method within 2-3 business days.\n• 10% standard platform cancellation fee applies.",
                    isBot = true,
                    actionRoute = "bookings",
                    actionLabel = "👉 Manage My Bookings"
                )
            }
            q.contains("promo") || q.contains("coupon") || q.contains("discount") || q.contains("code") || q.contains("offer") -> {
                HelpChatMessage(
                    text = "🎁 **Available Promo Codes**:\n\n• **WELCOME10**: 10% OFF on all sports turfs & function halls\n• **SPORTS100**: Flat ₹100 OFF on turf bookings\n• **FESTIVE500**: Flat ₹500 OFF on halls & banquet bookings\n• **FIRST50**: Flat ₹50 OFF on your first 1-Tap Quick Booking",
                    isBot = true,
                    actionRoute = "home",
                    actionLabel = "👉 Explore Spaces"
                )
            }
            q.contains("qr") || q.contains("pass") || q.contains("ticket") || q.contains("check in") || q.contains("entry") -> {
                HelpChatMessage(
                    text = "📱 **QR Check-In Pass**:\n\n• Go to the **'My Bookings'** tab.\n• Tap **'QR Pass'** on your confirmed booking.\n• Present the generated QR code to the venue front desk scanner for instant seamless entry.",
                    isBot = true,
                    actionRoute = "bookings",
                    actionLabel = "👉 Open My Bookings"
                )
            }
            q.contains("payment") || q.contains("upi") || q.contains("card") || q.contains("pay") || q.contains("gpay") || q.contains("phonepe") -> {
                HelpChatMessage(
                    text = "💳 **Payment Methods Supported**:\n\n• **Instant UPI**: Google Pay, PhonePe, Paytm, BHIM with 0 extra charges.\n• **Credit / Debit Cards**: Visa, MasterCard, RuPay (256-bit SSL secured).\n• **Net Banking**: 50+ major Indian banks supported.\n• **BMS Wallet**: Instant 1-tap checkout from wallet balance.\n• **Pay at Venue**: Book now and pay cash/UPI directly at the counter.",
                    isBot = true
                )
            }
            q.contains("pg") || q.contains("hostel") || q.contains("room") || q.contains("co-living") || q.contains("rent") -> {
                HelpChatMessage(
                    text = "🏡 **PG & Hostel Bookings**:\n\n• We offer Gents, Ladies, and Co-Living rooms.\n• Use our **PG Rent Calculator** to estimate monthly room rent + food/WiFi packages.\n• Secure reservation with an advance security token deposit.",
                    isBot = true,
                    actionRoute = "home",
                    actionLabel = "👉 Find PGs & Hostels"
                )
            }
            q.contains("list") || q.contains("owner") || q.contains("register") || q.contains("partner") || q.contains("hall") || q.contains("academy") -> {
                HelpChatMessage(
                    text = "🏢 **List Your Property on BookMySpace**:\n\n• Go to **Profile > Switch to Venue Owner Portal** or **Institute Owner Portal**.\n• Fill out basic venue info, upload photos, and set slot pricing.\n• Verification is completed within **24 hours** by our partner onboarding team.",
                    isBot = true,
                    actionRoute = "profile",
                    actionLabel = "👉 Go to Owner Portal"
                )
            }
            q.contains("call") || q.contains("support") || q.contains("agent") || q.contains("human") || q.contains("contact") || q.contains("phone") || q.contains("helpline") -> {
                HelpChatMessage(
                    text = "🎧 **Customer Care & Support**:\n\n• **Toll-Free Helpline**: +91 1800 200 8899 (24x7)\n• **Email Support**: support@bookmyspace.in\n• Average resolution time: Under 15 minutes.",
                    isBot = true,
                    externalUrl = "tel:+9118002008899",
                    actionLabel = "📞 Call Helpline Now"
                )
            }
            q.contains("book") || q.contains("slot") || q.contains("turf") || q.contains("how to") -> {
                HelpChatMessage(
                    text = "⚡ **How to Book a Space**:\n\n1. Select any Turf, Function Hall, Room, or Academy from Home or Search.\n2. Tap **'⚡ Book & Pay'**.\n3. Choose your preferred date and time slot.\n4. Apply any promo coupon and choose UPI or Card to confirm.",
                    isBot = true,
                    actionRoute = "home",
                    actionLabel = "👉 Browse Spaces"
                )
            }
            else -> {
                HelpChatMessage(
                    text = "🤖 I can help you with anything regarding BookMySpace! You can ask about:\n\n• Slot booking & availability\n• 90% instant cancellation refunds\n• BMS Wallet & ₹500 referral rewards\n• Payment modes (UPI/Cards/Pay at Venue)\n• QR Pass check-in at front desk\n• Listing your own venue or academy",
                    isBot = true
                )
            }
        }

        coroutineScope.launch {
            isTyping = true
            delay(350)
            isTyping = false
            messages = messages + botMessage
            delay(100)
            listState.animateScrollToItem(messages.size - 1)
        }
    }

    val sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)

    ModalBottomSheet(
        onDismissRequest = onDismiss,
        sheetState = sheetState,
        shape = RoundedCornerShape(topStart = 24.dp, topEnd = 24.dp),
        containerColor = MaterialTheme.colorScheme.surface,
        modifier = modifier.testTag("help_chatbot_bottom_sheet")
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .fillMaxHeight(0.85f)
                .imePadding()
                .padding(bottom = 12.dp)
        ) {
            // Top Bar with Clear Header and MANDATORY Prominent Close Button
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 16.dp, vertical = 8.dp),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.SpaceBetween
            ) {
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    modifier = Modifier.weight(1f)
                ) {
                    Box(
                        modifier = Modifier
                            .size(40.dp)
                            .clip(CircleShape)
                            .background(MaterialTheme.colorScheme.primaryContainer),
                        contentAlignment = Alignment.Center
                    ) {
                        Icon(
                            Icons.Default.Chat,
                            contentDescription = "AI Assistant",
                            tint = MaterialTheme.colorScheme.primary,
                            modifier = Modifier.size(22.dp)
                        )
                    }
                    Spacer(modifier = Modifier.width(10.dp))
                    Column {
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            Text(
                                text = "BMS AI Help Assistant",
                                fontWeight = FontWeight.Bold,
                                fontSize = 15.sp,
                                color = MaterialTheme.colorScheme.onSurface
                            )
                            Spacer(modifier = Modifier.width(6.dp))
                            Box(
                                modifier = Modifier
                                    .size(8.dp)
                                    .clip(CircleShape)
                                    .background(Color(0xFF2E7D32))
                            )
                        }
                        Text(
                            text = "Online • Instant 24x7 Support",
                            fontSize = 11.sp,
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                    }
                }

                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(4.dp)
                ) {
                    // Refresh / Reset Chat
                    IconButton(
                        onClick = {
                            messages = listOf(
                                HelpChatMessage(
                                    text = initialWelcomeText,
                                    isBot = true
                                )
                            )
                        },
                        modifier = Modifier.testTag("clear_chat_button")
                    ) {
                        Icon(
                            Icons.Default.Refresh,
                            contentDescription = "Reset Chat",
                            tint = MaterialTheme.colorScheme.onSurfaceVariant,
                            modifier = Modifier.size(20.dp)
                        )
                    }

                    // MINIMIZE BUTTON
                    if (onMinimize != null) {
                        IconButton(
                            onClick = onMinimize,
                            modifier = Modifier
                                .size(36.dp)
                                .testTag("minimize_chatbot_button")
                        ) {
                            Icon(
                                Icons.Default.Remove,
                                contentDescription = "Minimize Chatbot",
                                tint = MaterialTheme.colorScheme.onSurfaceVariant,
                                modifier = Modifier.size(20.dp)
                            )
                        }
                    }

                    // Prominent CLOSE BUTTON
                    FilledTonalIconButton(
                        onClick = onDismiss,
                        modifier = Modifier
                            .size(36.dp)
                            .testTag("close_chatbot_button"),
                        colors = IconButtonDefaults.filledTonalIconButtonColors(
                            containerColor = MaterialTheme.colorScheme.surfaceVariant,
                            contentColor = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                    ) {
                        Icon(
                            Icons.Default.Close,
                            contentDescription = "Close Chatbot",
                            modifier = Modifier.size(18.dp)
                        )
                    }
                }
            }

            HorizontalDivider(color = MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.5f))

            // Quick Topic Suggestion Chips
            LazyRow(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 16.dp, vertical = 8.dp),
                horizontalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                items(quickQuestions) { question ->
                    SuggestionChip(
                        onClick = {
                            val userMsg = HelpChatMessage(text = question, isBot = false)
                            messages = messages + userMsg
                            sendBotResponse(question)
                        },
                        label = { Text(question, fontSize = 11.sp, fontWeight = FontWeight.Medium) },
                        colors = SuggestionChipDefaults.suggestionChipColors(
                            containerColor = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.6f)
                        ),
                        border = BorderStroke(0.5.dp, MaterialTheme.colorScheme.outlineVariant)
                    )
                }
            }

            // Chat Messages List
            LazyColumn(
                state = listState,
                modifier = Modifier
                    .weight(1f)
                    .fillMaxWidth()
                    .padding(horizontal = 16.dp),
                verticalArrangement = Arrangement.spacedBy(10.dp)
            ) {
                items(messages, key = { it.id }) { msg ->
                    ChatBubbleItem(
                        message = msg,
                        onActionClick = { route ->
                            if (route != null) {
                                onDismiss()
                                onNavigateToRoute?.invoke(route)
                            }
                        },
                        onExternalClick = { url ->
                            if (url != null) {
                                try {
                                    val intent = Intent(Intent.ACTION_VIEW, Uri.parse(url))
                                    context.startActivity(intent)
                                } catch (_: Exception) {}
                            }
                        }
                    )
                }

                if (isTyping) {
                    item {
                        Row(
                            verticalAlignment = Alignment.CenterVertically,
                            modifier = Modifier.padding(start = 8.dp, top = 4.dp)
                        ) {
                            CircularProgressIndicator(
                                modifier = Modifier.size(14.dp),
                                strokeWidth = 2.dp,
                                color = MaterialTheme.colorScheme.primary
                            )
                            Spacer(modifier = Modifier.width(8.dp))
                            Text(
                                text = "Assistant is typing...",
                                fontSize = 11.sp,
                                color = MaterialTheme.colorScheme.onSurfaceVariant
                            )
                        }
                    }
                }
            }

            HorizontalDivider(
                color = MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.5f),
                modifier = Modifier.padding(vertical = 4.dp)
            )

            // Input Bar
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 16.dp, vertical = 6.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                OutlinedTextField(
                    value = inputText,
                    onValueChange = { inputText = it },
                    placeholder = { Text("Ask anything about BookMySpace...", fontSize = 13.sp) },
                    modifier = Modifier
                        .weight(1f)
                        .testTag("chatbot_input_field"),
                    shape = RoundedCornerShape(24.dp),
                    singleLine = true,
                    colors = OutlinedTextFieldDefaults.colors(
                        focusedBorderColor = MaterialTheme.colorScheme.primary,
                        unfocusedBorderColor = MaterialTheme.colorScheme.outlineVariant
                    )
                )

                Spacer(modifier = Modifier.width(8.dp))

                IconButton(
                    onClick = {
                        val text = inputText.trim()
                        if (text.isNotEmpty()) {
                            val userMsg = HelpChatMessage(text = text, isBot = false)
                            messages = messages + userMsg
                            inputText = ""
                            sendBotResponse(text)
                        }
                    },
                    modifier = Modifier
                        .size(46.dp)
                        .clip(CircleShape)
                        .background(if (inputText.isNotBlank()) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.surfaceVariant)
                        .testTag("chatbot_send_button"),
                    enabled = inputText.isNotBlank()
                ) {
                    Icon(
                        Icons.AutoMirrored.Filled.Send,
                        contentDescription = "Send Question",
                        tint = if (inputText.isNotBlank()) Color.White else MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.4f),
                        modifier = Modifier.size(20.dp)
                    )
                }
            }
        }
    }
}

@Composable
private fun ChatBubbleItem(
    message: HelpChatMessage,
    onActionClick: (String?) -> Unit,
    onExternalClick: (String?) -> Unit
) {
    val isBot = message.isBot

    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = if (isBot) Arrangement.Start else Arrangement.End,
        verticalAlignment = Alignment.Top
    ) {
        if (isBot) {
            Box(
                modifier = Modifier
                    .size(30.dp)
                    .clip(CircleShape)
                    .background(MaterialTheme.colorScheme.primaryContainer),
                contentAlignment = Alignment.Center
            ) {
                Icon(
                    Icons.Default.Chat,
                    contentDescription = null,
                    tint = MaterialTheme.colorScheme.primary,
                    modifier = Modifier.size(16.dp)
                )
            }
            Spacer(modifier = Modifier.width(8.dp))
        }

        Column(
            horizontalAlignment = if (isBot) Alignment.Start else Alignment.End,
            modifier = Modifier.widthIn(max = 280.dp)
        ) {
            Surface(
                shape = RoundedCornerShape(
                    topStart = 16.dp,
                    topEnd = 16.dp,
                    bottomStart = if (isBot) 4.dp else 16.dp,
                    bottomEnd = if (isBot) 16.dp else 4.dp
                ),
                color = if (isBot) MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.7f) else MaterialTheme.colorScheme.primary,
                border = if (isBot) BorderStroke(0.5.dp, MaterialTheme.colorScheme.outlineVariant) else null
            ) {
                Column(modifier = Modifier.padding(horizontal = 14.dp, vertical = 10.dp)) {
                    Text(
                        text = message.text,
                        fontSize = 13.sp,
                        color = if (isBot) MaterialTheme.colorScheme.onSurface else Color.White,
                        lineHeight = 18.sp
                    )

                    if (message.actionLabel != null) {
                        Spacer(modifier = Modifier.height(8.dp))
                        if (message.actionRoute != null) {
                            Button(
                                onClick = { onActionClick(message.actionRoute) },
                                shape = RoundedCornerShape(8.dp),
                                contentPadding = PaddingValues(horizontal = 12.dp, vertical = 6.dp),
                                colors = ButtonDefaults.buttonColors(containerColor = MaterialTheme.colorScheme.primary)
                            ) {
                                Text(message.actionLabel, fontSize = 11.sp, fontWeight = FontWeight.Bold)
                            }
                        } else if (message.externalUrl != null) {
                            Button(
                                onClick = { onExternalClick(message.externalUrl) },
                                shape = RoundedCornerShape(8.dp),
                                contentPadding = PaddingValues(horizontal = 12.dp, vertical = 6.dp),
                                colors = ButtonDefaults.buttonColors(containerColor = Color(0xFF2E7D32))
                            ) {
                                Text(message.actionLabel, fontSize = 11.sp, fontWeight = FontWeight.Bold, color = Color.White)
                            }
                        }
                    }
                }
            }

            Text(
                text = message.timestamp,
                fontSize = 10.sp,
                color = MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.7f),
                modifier = Modifier.padding(top = 2.dp, start = 4.dp, end = 4.dp)
            )
        }
    }
}

/**
 * Full interactive Draggable Floating ChatBot component.
 * Allows user to:
 * 1. Drag & drop the bubble or window to any location on the screen.
 * 2. Minimize into a sleek floating interactive bubble.
 * 3. Maximize/Expand to full interactive assistant window.
 * 4. Close the bot with clear exit affordance.
 */
@Composable
fun DraggableFloatingChatBot(
    currentRoute: String? = null,
    onNavigateToRoute: ((String) -> Unit)? = null,
    initialState: ChatBotDisplayState = ChatBotDisplayState.MINIMIZED,
    onClose: (() -> Unit)? = null,
    modifier: Modifier = Modifier
) {
    val context = LocalContext.current
    val configuration = LocalConfiguration.current
    val density = LocalDensity.current

    var displayState by remember { mutableStateOf(initialState) }
    
    // Drag offsets in pixels
    var offsetX by remember { mutableStateOf(0f) }
    var offsetY by remember { mutableStateOf(0f) }

    val coroutineScope = rememberCoroutineScope()
    val listState = rememberLazyListState()

    val initialWelcomeText = remember(currentRoute) {
        when {
            currentRoute?.startsWith("venues/") == true ->
                "👋 Checking venue details? Ask me about pricing, court time slots, amenities, or directions!"
            currentRoute?.contains("/book") == true ->
                "👋 Ready to book? Pick your date, slot, and payment option. Try WELCOME10 for 10% off!"
            currentRoute?.contains("/pay") == true ->
                "👋 Payment help: Instant UPI (GPay/PhonePe), Cards, Net Banking, and Pay at Venue supported."
            currentRoute == "bookings" ->
                "👋 Manage your bookings! View QR Check-In pass or cancel slots up to 2 hours in advance."
            else ->
                "👋 Hi! I'm your BMS Assistant. Ask about bookings, refunds, venues, PGs, or payments!"
        }
    }

    var messages by remember {
        mutableStateOf(
            listOf(
                HelpChatMessage(
                    text = initialWelcomeText,
                    isBot = true,
                    actionRoute = if (currentRoute != "bookings") "bookings" else null,
                    actionLabel = if (currentRoute != "bookings") "🎟️ View My Bookings" else null
                )
            )
        )
    }

    var inputText by remember { mutableStateOf("") }
    var isTyping by remember { mutableStateOf(false) }

    val quickQuestions = listOf(
        "Refund & Cancellation",
        "Wallet & Referrals",
        "How to book a slot?",
        "Active Promo Codes",
        "QR Pass for Check-In",
        "Payment Methods",
        "Call Customer Care"
    )

    fun sendBotResponse(userQuery: String) {
        val q = userQuery.lowercase(Locale.getDefault()).trim()
        val botMessage: HelpChatMessage = when {
            q.contains("wallet") || q.contains("refer") || q.contains("credit") || q.contains("earn") || q.contains("reward") || q.contains("balance") -> {
                HelpChatMessage(
                    text = "💰 **BookMySpace Wallet & Rewards**:\n• **Wallet Balance**: 100% redeemable on all bookings.\n• **Refer & Earn**: You both get **₹500 credits** on 1st booking!",
                    isBot = true,
                    actionRoute = "referral",
                    actionLabel = "👉 View Wallet"
                )
            }
            q.contains("refund") || q.contains("cancel") || q.contains("money back") -> {
                HelpChatMessage(
                    text = "💵 **Refund & Cancellation**:\n• Cancel up to **2 hours** before slot time.\n• **90% instant refund** processed to original payment mode.",
                    isBot = true,
                    actionRoute = "bookings",
                    actionLabel = "👉 Manage Bookings"
                )
            }
            q.contains("promo") || q.contains("coupon") || q.contains("discount") || q.contains("code") -> {
                HelpChatMessage(
                    text = "🎁 **Active Offers**:\n• **WELCOME10**: 10% OFF\n• **SPORTS100**: ₹100 OFF on turfs\n• **FESTIVE500**: ₹500 OFF on halls\n• **FIRST50**: ₹50 OFF quick booking",
                    isBot = true
                )
            }
            q.contains("qr") || q.contains("pass") || q.contains("ticket") || q.contains("check in") -> {
                HelpChatMessage(
                    text = "📱 **QR Check-In Pass**:\n• Go to **My Bookings**.\n• Tap **QR Pass** for instant contactless entry at front desk.",
                    isBot = true,
                    actionRoute = "bookings",
                    actionLabel = "👉 Open QR Pass"
                )
            }
            q.contains("payment") || q.contains("upi") || q.contains("card") || q.contains("pay") -> {
                HelpChatMessage(
                    text = "💳 **Payment Methods**:\n• UPI (GPay, PhonePe, Paytm, BHIM)\n• Cards (Visa, Master, RuPay)\n• Net Banking & BMS Wallet\n• Pay at Venue (Cash/UPI)",
                    isBot = true
                )
            }
            q.contains("call") || q.contains("support") || q.contains("agent") || q.contains("phone") -> {
                HelpChatMessage(
                    text = "🎧 **24x7 Helpline**:\n• Call: +91 1800 200 8899\n• Email: support@bookmyspace.in",
                    isBot = true,
                    externalUrl = "tel:+9118002008899",
                    actionLabel = "📞 Call Helpline"
                )
            }
            else -> {
                HelpChatMessage(
                    text = "🤖 I can help with:\n• Slot bookings & pricing\n• 90% instant refund policy\n• UPI & Card payments\n• QR check-in pass\n• Listing your own venue",
                    isBot = true
                )
            }
        }

        coroutineScope.launch {
            isTyping = true
            delay(300)
            isTyping = false
            messages = messages + botMessage
            delay(100)
            listState.animateScrollToItem(messages.size - 1)
        }
    }

    if (displayState == ChatBotDisplayState.CLOSED) {
        return
    }

    Box(
        modifier = modifier
            .offset { IntOffset(offsetX.roundToInt(), offsetY.roundToInt()) }
            .testTag("draggable_chatbot_container")
    ) {
        if (displayState == ChatBotDisplayState.MINIMIZED) {
            // Minimized Floating Pill / Bubble with Touch Drag Handle
            Surface(
                onClick = { displayState = ChatBotDisplayState.EXPANDED },
                shape = RoundedCornerShape(24.dp),
                color = MaterialTheme.colorScheme.primaryContainer,
                shadowElevation = 8.dp,
                border = BorderStroke(1.dp, MaterialTheme.colorScheme.primary.copy(alpha = 0.5f)),
                modifier = Modifier
                    .pointerInput(Unit) {
                        detectDragGestures { change, dragAmount ->
                            change.consume()
                            offsetX += dragAmount.x
                            offsetY += dragAmount.y
                        }
                    }
                    .testTag("minimized_draggable_chatbot_bubble")
            ) {
                Row(
                    modifier = Modifier.padding(horizontal = 12.dp, vertical = 8.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Icon(
                        Icons.Default.DragIndicator,
                        contentDescription = "Drag indicator",
                        tint = MaterialTheme.colorScheme.onPrimaryContainer.copy(alpha = 0.6f),
                        modifier = Modifier.size(16.dp)
                    )
                    Spacer(modifier = Modifier.width(4.dp))
                    Box(
                        modifier = Modifier
                            .size(28.dp)
                            .clip(CircleShape)
                            .background(MaterialTheme.colorScheme.primary),
                        contentAlignment = Alignment.Center
                    ) {
                        Icon(
                            Icons.Default.SmartToy,
                            contentDescription = "AI Help",
                            tint = Color.White,
                            modifier = Modifier.size(16.dp)
                        )
                    }
                    Spacer(modifier = Modifier.width(8.dp))
                    Column {
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            Text(
                                text = "BMS AI",
                                fontSize = 12.sp,
                                fontWeight = FontWeight.Bold,
                                color = MaterialTheme.colorScheme.onPrimaryContainer
                            )
                            Spacer(modifier = Modifier.width(4.dp))
                            Box(
                                modifier = Modifier
                                    .size(6.dp)
                                    .clip(CircleShape)
                                    .background(Color(0xFF2E7D32))
                            )
                        }
                        Text(
                            text = "Tap to Chat",
                            fontSize = 10.sp,
                            color = MaterialTheme.colorScheme.onPrimaryContainer.copy(alpha = 0.8f)
                        )
                    }
                    Spacer(modifier = Modifier.width(6.dp))
                    IconButton(
                        onClick = {
                            displayState = ChatBotDisplayState.CLOSED
                            onClose?.invoke()
                        },
                        modifier = Modifier.size(20.dp)
                    ) {
                        Icon(
                            Icons.Default.Close,
                            contentDescription = "Close",
                            tint = MaterialTheme.colorScheme.onPrimaryContainer.copy(alpha = 0.7f),
                            modifier = Modifier.size(14.dp)
                        )
                    }
                }
            }
        } else {
            // Expanded Floating Dialog / Window with Drag Bar, Minimize, and Close
            Card(
                shape = RoundedCornerShape(20.dp),
                colors = CardDefaults.cardColors(
                    containerColor = MaterialTheme.colorScheme.surface
                ),
                elevation = CardDefaults.cardElevation(defaultElevation = 12.dp),
                border = BorderStroke(1.dp, MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.8f)),
                modifier = Modifier
                    .widthIn(min = 280.dp, max = 340.dp)
                    .heightIn(min = 340.dp, max = 460.dp)
                    .testTag("expanded_draggable_chatbot_window")
            ) {
                Column(
                    modifier = Modifier.fillMaxSize()
                ) {
                    // Top Drag & Header Bar
                    Surface(
                        color = MaterialTheme.colorScheme.primaryContainer,
                        modifier = Modifier
                            .fillMaxWidth()
                            .pointerInput(Unit) {
                                detectDragGestures { change, dragAmount ->
                                    change.consume()
                                    offsetX += dragAmount.x
                                    offsetY += dragAmount.y
                                }
                            }
                    ) {
                        Column {
                            // Visual Drag Pill Bar
                            Box(
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .padding(top = 6.dp),
                                contentAlignment = Alignment.Center
                            ) {
                                Box(
                                    modifier = Modifier
                                        .size(36.dp, 4.dp)
                                        .clip(RoundedCornerShape(2.dp))
                                        .background(MaterialTheme.colorScheme.onPrimaryContainer.copy(alpha = 0.3f))
                                )
                            }
                            Row(
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .padding(horizontal = 12.dp, vertical = 6.dp),
                                verticalAlignment = Alignment.CenterVertically,
                                horizontalArrangement = Arrangement.SpaceBetween
                            ) {
                                Row(
                                    verticalAlignment = Alignment.CenterVertically,
                                    modifier = Modifier.weight(1f)
                                ) {
                                    Icon(
                                        Icons.Default.DragHandle,
                                        contentDescription = "Drag handle",
                                        tint = MaterialTheme.colorScheme.onPrimaryContainer.copy(alpha = 0.7f),
                                        modifier = Modifier.size(18.dp)
                                    )
                                    Spacer(modifier = Modifier.width(6.dp))
                                    Text(
                                        text = "BMS AI Assistant",
                                        fontWeight = FontWeight.Bold,
                                        fontSize = 13.sp,
                                        color = MaterialTheme.colorScheme.onPrimaryContainer
                                    )
                                }

                                Row(
                                    verticalAlignment = Alignment.CenterVertically,
                                    horizontalArrangement = Arrangement.spacedBy(2.dp)
                                ) {
                                    // Minimize Button
                                    IconButton(
                                        onClick = { displayState = ChatBotDisplayState.MINIMIZED },
                                        modifier = Modifier.size(28.dp)
                                    ) {
                                        Icon(
                                            Icons.Default.Remove,
                                            contentDescription = "Minimize",
                                            tint = MaterialTheme.colorScheme.onPrimaryContainer,
                                            modifier = Modifier.size(16.dp)
                                        )
                                    }

                                    // Close Button
                                    IconButton(
                                        onClick = {
                                            displayState = ChatBotDisplayState.CLOSED
                                            onClose?.invoke()
                                        },
                                        modifier = Modifier.size(28.dp)
                                    ) {
                                        Icon(
                                            Icons.Default.Close,
                                            contentDescription = "Close",
                                            tint = MaterialTheme.colorScheme.onPrimaryContainer,
                                            modifier = Modifier.size(16.dp)
                                        )
                                    }
                                }
                            }
                        }
                    }

                    // Quick Chips
                    LazyRow(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(horizontal = 8.dp, vertical = 4.dp),
                        horizontalArrangement = Arrangement.spacedBy(4.dp)
                    ) {
                        items(quickQuestions) { question ->
                            SuggestionChip(
                                onClick = {
                                    val userMsg = HelpChatMessage(text = question, isBot = false)
                                    messages = messages + userMsg
                                    sendBotResponse(question)
                                },
                                label = { Text(question, fontSize = 10.sp) },
                                colors = SuggestionChipDefaults.suggestionChipColors(
                                    containerColor = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.5f)
                                ),
                                border = BorderStroke(0.5.dp, MaterialTheme.colorScheme.outlineVariant)
                            )
                        }
                    }

                    // Messages List
                    LazyColumn(
                        state = listState,
                        modifier = Modifier
                            .weight(1f)
                            .fillMaxWidth()
                            .padding(horizontal = 8.dp),
                        verticalArrangement = Arrangement.spacedBy(6.dp),
                        contentPadding = PaddingValues(vertical = 4.dp)
                    ) {
                        items(messages, key = { it.id }) { message ->
                            ChatBubbleItem(
                                message = message,
                                onActionClick = { route: String? ->
                                    displayState = ChatBotDisplayState.MINIMIZED
                                    if (route != null) {
                                        onNavigateToRoute?.invoke(route)
                                    }
                                },
                                onExternalClick = { url: String? ->
                                    if (url != null) {
                                        val intent = Intent(Intent.ACTION_VIEW, Uri.parse(url))
                                        context.startActivity(intent)
                                    }
                                }
                            )
                        }

                        if (isTyping) {
                            item {
                                Row(
                                    verticalAlignment = Alignment.CenterVertically,
                                    modifier = Modifier.padding(start = 6.dp, top = 2.dp)
                                ) {
                                    CircularProgressIndicator(
                                        modifier = Modifier.size(12.dp),
                                        strokeWidth = 1.5.dp,
                                        color = MaterialTheme.colorScheme.primary
                                    )
                                    Spacer(modifier = Modifier.width(6.dp))
                                    Text(
                                        text = "Typing...",
                                        fontSize = 11.sp,
                                        color = MaterialTheme.colorScheme.onSurfaceVariant
                                    )
                                }
                            }
                        }
                    }

                    HorizontalDivider(color = MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.3f))

                    // Input Field
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(horizontal = 8.dp, vertical = 6.dp),
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        OutlinedTextField(
                            value = inputText,
                            onValueChange = { inputText = it },
                            placeholder = { Text("Ask BMS AI...", fontSize = 11.sp) },
                            modifier = Modifier
                                .weight(1f)
                                .heightIn(min = 40.dp),
                            shape = RoundedCornerShape(20.dp),
                            maxLines = 2,
                            colors = OutlinedTextFieldDefaults.colors(
                                focusedBorderColor = MaterialTheme.colorScheme.primary,
                                unfocusedBorderColor = MaterialTheme.colorScheme.outlineVariant
                            )
                        )
                        Spacer(modifier = Modifier.width(4.dp))
                        FilledIconButton(
                            onClick = {
                                if (inputText.isNotBlank()) {
                                    val userText = inputText.trim()
                                    inputText = ""
                                    messages = messages + HelpChatMessage(text = userText, isBot = false)
                                    sendBotResponse(userText)
                                }
                            },
                            modifier = Modifier.size(38.dp),
                            enabled = inputText.isNotBlank()
                        ) {
                            Icon(
                                Icons.AutoMirrored.Filled.Send,
                                contentDescription = "Send",
                                modifier = Modifier.size(16.dp)
                            )
                        }
                    }
                }
            }
        }
    }
}
