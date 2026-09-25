package com.bookmyspace.bookmyspace.ui.screens

import android.content.Intent
import android.net.Uri
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.bookmyspace.bookmyspace.data.repository.BookMySpaceRepository
import com.bookmyspace.bookmyspace.ui.components.HelpChatbotBottomSheet

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun SupportScreen(
    onNavigateBack: (() -> Unit)? = null,
    modifier: Modifier = Modifier
) {
    val context = LocalContext.current
    var subject by remember { mutableStateOf("") }
    var message by remember { mutableStateOf("") }
    var isSubmitted by remember { mutableStateOf(false) }
    var showChatbot by remember { mutableStateOf(false) }

    val faqs = listOf(
        "How do I cancel my court booking and receive a refund?" to "You can cancel any confirmed booking up to 2 hours before the start time directly from the 'My Bookings' tab. 90% of the amount will be refunded to your original payment method within 2-3 business days.",
        "What should I show at the venue check-in?" to "Open your confirmed booking in 'My Bookings' and tap 'QR Pass'. Present this QR code to the venue front desk scanner for instant check-in.",
        "How do I list my property, sports arena, or coaching academy?" to "Go to Profile > Switch to Venue Owner Portal / Institute Owner Portal and submit your venue details. Our verification team approves listings within 24 hours.",
        "Is there a referral reward for inviting friends?" to "Yes! Share your unique referral code from the 'Refer & Earn' page. You and your friend both receive ₹500 in BookMySpace wallet credits after their first completed booking."
    )

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Help & Support 💬", fontWeight = FontWeight.Bold, fontSize = 18.sp) },
                navigationIcon = {
                    if (onNavigateBack != null) {
                        IconButton(
                            onClick = onNavigateBack,
                            modifier = Modifier.testTag("support_back_button")
                        ) {
                            Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "Close Support")
                        }
                    }
                },
                colors = TopAppBarDefaults.topAppBarColors(containerColor = MaterialTheme.colorScheme.surface)
            )
        },
        modifier = modifier.testTag("support_screen")
    ) { paddingValues ->
        LazyColumn(
            modifier = Modifier
                .fillMaxSize()
                .padding(paddingValues)
                .padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(16.dp)
        ) {
            // AI Chatbot Banner
            item {
                Card(
                    shape = RoundedCornerShape(16.dp),
                    colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.primaryContainer),
                    modifier = Modifier
                        .fillMaxWidth()
                        .clickable { showChatbot = true }
                        .testTag("open_ai_support_chatbot")
                ) {
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(16.dp),
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.SpaceBetween
                    ) {
                        Row(
                            verticalAlignment = Alignment.CenterVertically,
                            modifier = Modifier.weight(1f)
                        ) {
                            Icon(
                                Icons.Default.Chat,
                                contentDescription = null,
                                tint = MaterialTheme.colorScheme.primary,
                                modifier = Modifier.size(36.dp)
                            )
                            Spacer(modifier = Modifier.width(12.dp))
                            Column {
                                Text(
                                    "Chat with AI Help Assistant 🤖",
                                    fontWeight = FontWeight.Bold,
                                    fontSize = 15.sp,
                                    color = MaterialTheme.colorScheme.onPrimaryContainer
                                )
                                Text(
                                    "Instant answers for refunds, bookings & venues",
                                    fontSize = 12.sp,
                                    color = MaterialTheme.colorScheme.onPrimaryContainer.copy(alpha = 0.8f)
                                )
                            }
                        }
                        Button(
                            onClick = { showChatbot = true },
                            shape = RoundedCornerShape(10.dp)
                        ) {
                            Text("Open Chat", fontSize = 12.sp, fontWeight = FontWeight.Bold)
                        }
                    }
                }
            }

            item {
                Card(
                    shape = RoundedCornerShape(16.dp),
                    colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.4f)),
                    modifier = Modifier.fillMaxWidth()
                ) {
                    Column(modifier = Modifier.padding(16.dp)) {
                        Text("24x7 Customer Helpline 🎧", fontWeight = FontWeight.Bold, fontSize = 15.sp)
                        Text("We are always here to help you with booking disputes, refunds, and venue inquiries.", fontSize = 11.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                        Spacer(modifier = Modifier.height(12.dp))
                        Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                            Button(
                                onClick = {
                                    val dialIntent = Intent(Intent.ACTION_DIAL, Uri.parse("tel:+9118002008899"))
                                    context.startActivity(dialIntent)
                                },
                                shape = RoundedCornerShape(10.dp),
                                modifier = Modifier.weight(1f)
                            ) {
                                Icon(Icons.Default.Phone, contentDescription = null, modifier = Modifier.size(16.dp))
                                Spacer(modifier = Modifier.width(6.dp))
                                Text("Call Toll-Free", fontSize = 11.sp)
                            }

                            OutlinedButton(
                                onClick = {
                                    val emailIntent = Intent(Intent.ACTION_SENDTO, Uri.parse("mailto:support@bookmyspace.in?subject=Help%20Request"))
                                    context.startActivity(emailIntent)
                                },
                                shape = RoundedCornerShape(10.dp),
                                modifier = Modifier.weight(1f)
                            ) {
                                Icon(Icons.Default.Email, contentDescription = null, modifier = Modifier.size(16.dp))
                                Spacer(modifier = Modifier.width(6.dp))
                                Text("Email Us", fontSize = 11.sp)
                            }
                        }
                    }
                }
            }

            item {
                Text("Frequently Asked Questions ❓", fontWeight = FontWeight.Bold, fontSize = 15.sp)
            }

            items(faqs.size) { index ->
                val (q, a) = faqs[index]
                var expanded by remember { mutableStateOf(false) }
                Card(
                    shape = RoundedCornerShape(12.dp),
                    colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.5f)),
                    modifier = Modifier
                        .fillMaxWidth()
                        .clickable { expanded = !expanded }
                ) {
                    Column(modifier = Modifier.padding(14.dp)) {
                        Row(
                            modifier = Modifier.fillMaxWidth(),
                            verticalAlignment = Alignment.CenterVertically,
                            horizontalArrangement = Arrangement.SpaceBetween
                        ) {
                            Text(q, fontWeight = FontWeight.Bold, fontSize = 13.sp, modifier = Modifier.weight(1f))
                            Icon(if (expanded) Icons.Default.ExpandLess else Icons.Default.ExpandMore, contentDescription = null)
                        }
                        if (expanded) {
                            Spacer(modifier = Modifier.height(8.dp))
                            Text(a, fontSize = 12.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                        }
                    }
                }
            }

            item {
                Text("Submit a Support Ticket 📝", fontWeight = FontWeight.Bold, fontSize = 15.sp)
            }

            item {
                Card(
                    shape = RoundedCornerShape(14.dp),
                    colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface),
                    elevation = CardDefaults.cardElevation(2.dp),
                    modifier = Modifier.fillMaxWidth()
                ) {
                    Column(modifier = Modifier.padding(16.dp)) {
                        if (isSubmitted) {
                            Text("✅ Ticket #BMS-${System.currentTimeMillis().toString().takeLast(5)} Submitted!", fontWeight = FontWeight.Bold, color = Color(0xFF2E7D32))
                            Text("Our executive will respond to your registered email within 2 hours.", fontSize = 12.sp)
                        } else {
                            OutlinedTextField(
                                value = subject,
                                onValueChange = { subject = it },
                                label = { Text("Issue Subject") },
                                modifier = Modifier.fillMaxWidth(),
                                singleLine = true
                            )
                            Spacer(modifier = Modifier.height(10.dp))
                            OutlinedTextField(
                                value = message,
                                onValueChange = { message = it },
                                label = { Text("Describe the issue in detail...") },
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .height(100.dp),
                                maxLines = 4
                            )
                            Spacer(modifier = Modifier.height(14.dp))
                            Button(
                                onClick = {
                                    if (subject.isNotBlank() && message.isNotBlank()) {
                                        BookMySpaceRepository.logAnalyticsEvent("support_ticket_created", mapOf("subject" to subject), "support")
                                        isSubmitted = true
                                    }
                                },
                                shape = RoundedCornerShape(10.dp),
                                modifier = Modifier.fillMaxWidth()
                            ) {
                                Text("Send Ticket", fontWeight = FontWeight.Bold)
                            }
                        }
                    }
                }
            }
        }

        if (showChatbot) {
            HelpChatbotBottomSheet(
                currentRoute = "support",
                onDismiss = { showChatbot = false }
            )
        }
    }
}
