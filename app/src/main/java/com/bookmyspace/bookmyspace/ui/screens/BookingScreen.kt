package com.bookmyspace.bookmyspace.ui.screens

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.CalendarMonth
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.ChevronLeft
import androidx.compose.material.icons.filled.ChevronRight
import androidx.compose.material.icons.filled.ConfirmationNumber
import androidx.compose.material.icons.filled.EventBusy
import androidx.compose.material.icons.filled.Lightbulb
import androidx.compose.material.icons.filled.Lock
import androidx.compose.material.icons.filled.Warning
import androidx.compose.material.icons.filled.Bolt
import androidx.compose.material.icons.filled.CreditCard
import androidx.compose.material.icons.filled.AccountBalance
import androidx.compose.material.icons.filled.AccountBalanceWallet
import androidx.compose.material.icons.filled.Storefront
import androidx.compose.material.icons.filled.LocalOffer
import androidx.compose.material.icons.filled.Discount
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import androidx.compose.ui.platform.LocalHapticFeedback
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.bookmyspace.bookmyspace.data.model.Booking
import com.bookmyspace.bookmyspace.data.model.BookingStatus
import com.bookmyspace.bookmyspace.data.model.DateAvailabilityInfo
import com.bookmyspace.bookmyspace.data.model.DateAvailabilityStatus
import com.bookmyspace.bookmyspace.data.model.TimeSlot
import com.bookmyspace.bookmyspace.data.repository.BookMySpaceRepository
import java.time.LocalDate
import java.time.YearMonth
import java.time.format.DateTimeFormatter

private data class BookingPaymentOption(
    val key: String,
    val title: String,
    val subtitle: String,
    val icon: androidx.compose.ui.graphics.vector.ImageVector
)

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun BookingScreen(
    venueId: String,
    onBack: () -> Unit,
    onProceedToPayment: (String) -> Unit
) {
    val haptic = LocalHapticFeedback.current
    val venues by BookMySpaceRepository.venues.collectAsState()
    val venue = venues.firstOrNull { it.id == venueId } ?: venues.first()
    val user by BookMySpaceRepository.authUser.collectAsState()
    val bookings by BookMySpaceRepository.bookings.collectAsState()

    var selectedDateStr by remember { mutableStateOf("2026-08-08") }
    
    // Auto-select initial slot
    var selectedSlot by remember(venue, selectedDateStr) {
        val openSlots = venue.timeSlots.filter { slot ->
            !BookMySpaceRepository.isSlotAlreadyBooked(venue.id, selectedDateStr, slot.label)
        }
        mutableStateOf<TimeSlot?>(openSlots.firstOrNull() ?: venue.timeSlots.firstOrNull())
    }

    var selectedPaymentMode by remember { mutableStateOf("UPI") }
    var couponCode by remember { mutableStateOf("") }
    var appliedCoupon by remember { mutableStateOf<String?>(null) }
    var discountAmount by remember { mutableStateOf(0.0) }
    var duplicateErrorMsg by remember { mutableStateOf<String?>(null) }

    val currentSlotLabel = selectedSlot?.label ?: "Standard Slot"

    // Check real-time if current slot on current date is booked
    val isDuplicate = remember(venue.id, selectedDateStr, currentSlotLabel, bookings) {
        BookMySpaceRepository.isSlotAlreadyBooked(venue.id, selectedDateStr, currentSlotLabel)
    }

    val dateAvailability = remember(venue.id, selectedDateStr, bookings) {
        BookMySpaceRepository.getDateAvailability(venue.id, selectedDateStr)
    }

    val alternativeSlots: List<TimeSlot> = remember(venue.id, selectedDateStr, currentSlotLabel, isDuplicate, bookings) {
        if (isDuplicate) {
            BookMySpaceRepository.getAlternativeSlots(venue.id, selectedDateStr, currentSlotLabel)
        } else emptyList()
    }

    val basePrice by remember(selectedSlot, venue) {
        derivedStateOf { selectedSlot?.priceAmount ?: venue.pricingBaseAmount }
    }
    val taxAmount by remember(basePrice, venue.taxRate) {
        derivedStateOf { basePrice * (venue.taxRate / 100.0) }
    }
    val grandTotal by remember(basePrice, taxAmount, discountAmount) {
        derivedStateOf { (basePrice + taxAmount - discountAmount).coerceAtLeast(0.0) }
    }

    com.bookmyspace.bookmyspace.util.TraceComposition("BookingScreen")

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Book Court / Slot", fontWeight = FontWeight.Bold) },
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "Back")
                    }
                }
            )
        },
        bottomBar = {
            Surface(tonalElevation = 8.dp) {
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(horizontal = 20.dp, vertical = 14.dp),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Column {
                        Text(
                            text = if (selectedPaymentMode == "VENUE") "Pay at Venue" else "Grand Total",
                            fontSize = 11.sp,
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                        Text(
                            text = "₹${grandTotal.toInt()}",
                            fontSize = 22.sp,
                            fontWeight = FontWeight.ExtraBold,
                            color = MaterialTheme.colorScheme.primary
                        )
                    }
                    Button(
                        onClick = {
                            com.bookmyspace.bookmyspace.util.PerformanceTracer.traceBlock("booking_hold_workflow") {
                                haptic.performHapticFeedback(HapticFeedbackType.LongPress)
                                
                                // Real-time atomic recheck
                                val freshDuplicate = BookMySpaceRepository.isSlotAlreadyBooked(venue.id, selectedDateStr, currentSlotLabel)
                                if (freshDuplicate) {
                                    duplicateErrorMsg = "Slot '$currentSlotLabel' on $selectedDateStr was just booked by another customer! Double booking prevented."
                                    return@traceBlock
                                }

                                val slot = selectedSlot
                                val newBooking = Booking(
                                    id = "bk_${System.currentTimeMillis()}",
                                    userId = user?.id ?: "guest",
                                    venueId = venue.id,
                                    venueName = venue.name,
                                    venueImageUrl = venue.coverImageUrl,
                                    slotLabel = slot?.label ?: "Standard Slot",
                                    bookingDate = selectedDateStr,
                                    startTime = slot?.startTime ?: "09:00",
                                    endTime = slot?.endTime ?: "11:00",
                                    baseAmount = basePrice,
                                    taxAmount = taxAmount,
                                    discountAmount = discountAmount,
                                    totalAmount = grandTotal,
                                    couponCode = appliedCoupon ?: "",
                                    status = if (selectedPaymentMode == "VENUE") BookingStatus.CONFIRMED else BookingStatus.PENDING,
                                    isPaid = false
                                )
                                BookMySpaceRepository.addBooking(newBooking)
                                onProceedToPayment(newBooking.id)
                            }
                        },
                        modifier = Modifier
                            .height(48.dp)
                            .testTag("confirm_and_pay_button"),
                        enabled = selectedSlot != null && !isDuplicate && dateAvailability.status != com.bookmyspace.bookmyspace.data.model.DateAvailabilityStatus.FULLY_BOOKED,
                        shape = RoundedCornerShape(12.dp)
                    ) {
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            Icon(Icons.Default.Bolt, contentDescription = null, modifier = Modifier.size(18.dp))
                            Spacer(modifier = Modifier.width(4.dp))
                            Text(
                                text = when {
                                    isDuplicate -> "Slot Unavailable"
                                    selectedPaymentMode == "VENUE" -> "Book & Pay at Venue"
                                    else -> "⚡ Book & Pay ₹${grandTotal.toInt()}"
                                },
                                fontWeight = FontWeight.Bold,
                                fontSize = 14.sp
                            )
                        }
                    }
                }
            }
        }
    ) { innerPadding ->
        LazyColumn(
            modifier = Modifier
                .fillMaxSize()
                .padding(innerPadding),
            contentPadding = PaddingValues(20.dp)
        ) {
            // Venue Summary Header
            item {
                Card(
                    modifier = Modifier.fillMaxWidth(),
                    shape = RoundedCornerShape(16.dp),
                    colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant)
                ) {
                    Row(
                        modifier = Modifier.padding(16.dp),
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Box(
                            modifier = Modifier
                                .size(60.dp)
                                .clip(RoundedCornerShape(12.dp))
                                .background(MaterialTheme.colorScheme.primary.copy(alpha = 0.2f)),
                            contentAlignment = Alignment.Center
                        ) {
                            Text("🏟️", fontSize = 24.sp)
                        }
                        Spacer(modifier = Modifier.width(12.dp))
                        Column {
                            Text(venue.name, fontWeight = FontWeight.Bold, fontSize = 16.sp)
                            Text(venue.fullAddress, fontSize = 12.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                        }
                    }
                }
                Spacer(modifier = Modifier.height(20.dp))
            }

            // DUPLICATE & SMART ALTERNATIVE SLOTS SUGGESTIONS
            if (isDuplicate || duplicateErrorMsg != null) {
                item {
                    Card(
                        modifier = Modifier.fillMaxWidth().testTag("duplicate_booking_alert"),
                        shape = RoundedCornerShape(14.dp),
                        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.errorContainer)
                    ) {
                        Column(modifier = Modifier.padding(14.dp)) {
                            Row(verticalAlignment = Alignment.CenterVertically) {
                                Icon(Icons.Default.Warning, contentDescription = null, tint = MaterialTheme.colorScheme.onErrorContainer)
                                Spacer(modifier = Modifier.width(8.dp))
                                Text(
                                    text = "Selected Slot Unavailable!",
                                    fontWeight = FontWeight.Bold,
                                    color = MaterialTheme.colorScheme.onErrorContainer,
                                    fontSize = 14.sp
                                )
                            }
                            Spacer(modifier = Modifier.height(4.dp))
                            Text(
                                text = duplicateErrorMsg ?: "Another user recently confirmed '$currentSlotLabel' on $selectedDateStr. Prevent duplicate double-booking by selecting an alternative below.",
                                fontSize = 11.sp,
                                color = MaterialTheme.colorScheme.onErrorContainer
                            )
                        }
                    }
                    Spacer(modifier = Modifier.height(14.dp))
                }
            }

            if (alternativeSlots.isNotEmpty()) {
                item {
                    Card(
                        modifier = Modifier.fillMaxWidth().testTag("smart_alternative_slots_card"),
                        shape = RoundedCornerShape(14.dp),
                        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.tertiaryContainer)
                    ) {
                        Column(modifier = Modifier.padding(14.dp)) {
                            Row(verticalAlignment = Alignment.CenterVertically) {
                                Icon(Icons.Default.Lightbulb, contentDescription = null, tint = MaterialTheme.colorScheme.onTertiaryContainer)
                                Spacer(modifier = Modifier.width(8.dp))
                                Text(
                                    text = "Smart Availability Suggestions",
                                    fontWeight = FontWeight.Bold,
                                    color = MaterialTheme.colorScheme.onTertiaryContainer,
                                    fontSize = 13.sp
                                )
                            }
                            Spacer(modifier = Modifier.height(6.dp))
                            Text(
                                text = "Recommended alternative open slots for your venue booking:",
                                fontSize = 11.sp,
                                color = MaterialTheme.colorScheme.onTertiaryContainer
                            )
                            Spacer(modifier = Modifier.height(10.dp))
                            Row(
                                modifier = Modifier.fillMaxWidth(),
                                horizontalArrangement = Arrangement.spacedBy(8.dp)
                            ) {
                                alternativeSlots.forEach { alt ->
                                    FilterChip(
                                        selected = false,
                                        onClick = {
                                            haptic.performHapticFeedback(HapticFeedbackType.TextHandleMove)
                                            selectedSlot = alt
                                            duplicateErrorMsg = null
                                        },
                                        label = { Text(alt.label.ifBlank { "${alt.startTime} - ${alt.endTime}" }, fontSize = 11.sp, fontWeight = FontWeight.Bold) },
                                        leadingIcon = { Icon(Icons.Default.Check, contentDescription = null, modifier = Modifier.size(12.dp)) }
                                    )
                                }
                            }
                        }
                    }
                    Spacer(modifier = Modifier.height(20.dp))
                }
            }

            // Step 1: Interactive Calendar Date Picker
            item {
                Text("Select Date & Availability Calendar", fontWeight = FontWeight.Bold, fontSize = 16.sp)
                Spacer(modifier = Modifier.height(10.dp))

                VenueInteractiveCalendar(
                    venueId = venue.id,
                    selectedDateStr = selectedDateStr,
                    onDateSelected = { date ->
                        selectedDateStr = date
                        duplicateErrorMsg = null
                        BookMySpaceRepository.notifySlotInteraction()
                    }
                )

                Spacer(modifier = Modifier.height(20.dp))
            }

            // Quick Shortcut Date Chips
            item {
                val quickDates = listOf(
                    "2026-08-08" to "Today, Aug 08",
                    "2026-08-09" to "Tomorrow, Aug 09",
                    "2026-08-10" to "Sun, Aug 10",
                    "2026-08-11" to "Mon, Aug 11",
                    "2026-08-15" to "Sat, Aug 15"
                )
                LazyRow(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    items(quickDates) { (dateCode, label) ->
                        val isSelected = selectedDateStr == dateCode
                        val avail = BookMySpaceRepository.getDateAvailability(venue.id, dateCode)
                        val isBlocked = avail.status == DateAvailabilityStatus.FULLY_BOOKED ||
                                avail.status == DateAvailabilityStatus.SOLD_OUT ||
                                avail.status == DateAvailabilityStatus.MAINTENANCE_BLOCKED

                        FilterChip(
                            selected = isSelected,
                            enabled = !isBlocked,
                            onClick = {
                                selectedDateStr = dateCode
                                duplicateErrorMsg = null
                            },
                            label = {
                                Row(verticalAlignment = Alignment.CenterVertically) {
                                    Text(label, fontSize = 12.sp, fontWeight = if (isSelected) FontWeight.Bold else FontWeight.Normal)
                                    if (avail.status == DateAvailabilityStatus.PARTIALLY_AVAILABLE || avail.status == DateAvailabilityStatus.FILLING_FAST || avail.status == DateAvailabilityStatus.LIMITED) {
                                        Spacer(modifier = Modifier.width(4.dp))
                                        Text("• ${avail.availableSlotsCount} open", fontSize = 10.sp, color = Color(0xFFE65100))
                                    }
                                }
                            }
                        )
                    }
                }
                Spacer(modifier = Modifier.height(24.dp))
            }

            // Step 2: Time Slot Selection Header & List
            item {
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Column {
                        Text("Available Time Slots", fontWeight = FontWeight.Bold, fontSize = 16.sp)
                        Text(
                            text = "Showing slots for $selectedDateStr (${dateAvailability.availableSlotsCount} available)",
                            fontSize = 12.sp,
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                    }
                    if (dateAvailability.status == DateAvailabilityStatus.FULLY_BOOKED || dateAvailability.status == DateAvailabilityStatus.SOLD_OUT) {
                        Badge(containerColor = MaterialTheme.colorScheme.errorContainer) {
                            Text("FULLY BOOKED", fontSize = 10.sp, fontWeight = FontWeight.Bold, color = MaterialTheme.colorScheme.onErrorContainer)
                        }
                    }
                }
                Spacer(modifier = Modifier.height(12.dp))
            }

            items(venue.timeSlots) { slot ->
                val isSelected = selectedSlot?.id == slot.id
                val isBooked = BookMySpaceRepository.isSlotAlreadyBooked(venue.id, selectedDateStr, slot.label)

                Card(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(vertical = 4.dp)
                        .clickable(enabled = !isBooked) {
                            selectedSlot = slot
                            duplicateErrorMsg = null
                            BookMySpaceRepository.notifySlotInteraction()
                        },
                    shape = RoundedCornerShape(14.dp),
                    colors = CardDefaults.cardColors(
                        containerColor = when {
                            isBooked -> MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.5f)
                            isSelected -> MaterialTheme.colorScheme.primaryContainer
                            else -> MaterialTheme.colorScheme.surface
                        }
                    ),
                    border = if (isSelected && !isBooked) BorderStroke(2.dp, MaterialTheme.colorScheme.primary) else null
                ) {
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(16.dp),
                        horizontalArrangement = Arrangement.SpaceBetween,
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            if (isBooked) {
                                Icon(Icons.Default.Lock, contentDescription = "Booked", tint = MaterialTheme.colorScheme.error, modifier = Modifier.size(20.dp))
                            } else if (isSelected) {
                                Icon(Icons.Default.Check, contentDescription = "Selected", tint = MaterialTheme.colorScheme.primary, modifier = Modifier.size(20.dp))
                            } else {
                                Icon(Icons.Default.CalendarMonth, contentDescription = null, tint = MaterialTheme.colorScheme.onSurfaceVariant, modifier = Modifier.size(20.dp))
                            }
                            Spacer(modifier = Modifier.width(12.dp))
                            Column {
                                Text(
                                    text = slot.label,
                                    fontWeight = FontWeight.Bold,
                                    fontSize = 14.sp,
                                    color = if (isBooked) MaterialTheme.colorScheme.onSurface.copy(alpha = 0.4f) else MaterialTheme.colorScheme.onSurface
                                )
                                Text(
                                    text = "${slot.startTime} - ${slot.endTime}",
                                    fontSize = 12.sp,
                                    color = MaterialTheme.colorScheme.onSurfaceVariant
                                )
                            }
                        }

                        Column(horizontalAlignment = Alignment.End) {
                            if (isBooked) {
                                Badge(containerColor = MaterialTheme.colorScheme.errorContainer) {
                                    Text("RESERVED", fontSize = 10.sp, fontWeight = FontWeight.Bold, color = MaterialTheme.colorScheme.onErrorContainer)
                                }
                            } else {
                                Text(
                                    "₹${slot.priceAmount.toInt()}",
                                    fontWeight = FontWeight.ExtraBold,
                                    color = MaterialTheme.colorScheme.primary,
                                    fontSize = 16.sp
                                )
                                Text(
                                    "Available",
                                    fontSize = 10.sp,
                                    fontWeight = FontWeight.Medium,
                                    color = Color(0xFF2E7D32)
                                )
                            }
                        }
                    }
                }
            }

            // Step 3: Coupon Discount Box & Fast Offers
            item {
                Spacer(modifier = Modifier.height(20.dp))
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Text("Apply Offers & Promo Code", fontWeight = FontWeight.Bold, fontSize = 16.sp)
                    if (appliedCoupon != null) {
                        TextButton(
                            onClick = {
                                appliedCoupon = null
                                couponCode = ""
                                discountAmount = 0.0
                            },
                            contentPadding = PaddingValues(0.dp)
                        ) {
                            Text("Remove", fontSize = 12.sp, color = MaterialTheme.colorScheme.error)
                        }
                    }
                }
                Spacer(modifier = Modifier.height(8.dp))

                // Quick 1-Tap Coupon Chips
                val quickCoupons = listOf(
                    Triple("WELCOME10", "10% OFF", basePrice * 0.10),
                    Triple("SPORTS100", "₹100 OFF", 100.0),
                    Triple("FESTIVE500", "₹500 OFF", 500.0)
                )
                LazyRow(
                    horizontalArrangement = Arrangement.spacedBy(8.dp),
                    modifier = Modifier.padding(bottom = 8.dp)
                ) {
                    items(quickCoupons) { (code, discountLabel, calcDiscount) ->
                        val isApplied = appliedCoupon == code
                        FilterChip(
                            selected = isApplied,
                            onClick = {
                                if (isApplied) {
                                    appliedCoupon = null
                                    couponCode = ""
                                    discountAmount = 0.0
                                } else {
                                    appliedCoupon = code
                                    couponCode = code
                                    discountAmount = calcDiscount.coerceAtMost(basePrice)
                                }
                            },
                            leadingIcon = {
                                Icon(Icons.Default.Discount, contentDescription = null, modifier = Modifier.size(14.dp))
                            },
                            label = {
                                Text("$code ($discountLabel)", fontSize = 11.sp, fontWeight = FontWeight.SemiBold)
                            }
                        )
                    }
                }

                Row(
                    modifier = Modifier.fillMaxWidth(),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    OutlinedTextField(
                        value = couponCode,
                        onValueChange = { couponCode = it.uppercase() },
                        modifier = Modifier.weight(1f),
                        placeholder = { Text("Enter coupon code") },
                        singleLine = true,
                        leadingIcon = { Icon(Icons.Default.ConfirmationNumber, contentDescription = null) }
                    )
                    Spacer(modifier = Modifier.width(8.dp))
                    Button(
                        onClick = {
                            when (couponCode) {
                                "WELCOME10" -> {
                                    appliedCoupon = "WELCOME10"
                                    discountAmount = basePrice * 0.10
                                }
                                "FESTIVE500" -> {
                                    appliedCoupon = "FESTIVE500"
                                    discountAmount = 500.0.coerceAtMost(basePrice)
                                }
                                "SPORTS100" -> {
                                    appliedCoupon = "SPORTS100"
                                    discountAmount = 100.0.coerceAtMost(basePrice)
                                }
                                else -> {
                                    if (couponCode.isNotBlank()) {
                                        appliedCoupon = couponCode
                                        discountAmount = (basePrice * 0.05).coerceAtLeast(50.0).coerceAtMost(basePrice)
                                    }
                                }
                            }
                        }
                    ) {
                        Text("Apply")
                    }
                }
                if (appliedCoupon != null) {
                    Text(
                        "✓ Promo code '$appliedCoupon' applied! You saved ₹${discountAmount.toInt()}",
                        color = MaterialTheme.colorScheme.primary,
                        fontSize = 12.sp,
                        fontWeight = FontWeight.Bold,
                        modifier = Modifier.padding(top = 6.dp)
                    )
                }
            }

            // Step 4: Payment Method Selection
            item {
                Spacer(modifier = Modifier.height(20.dp))
                Text("Select Preferred Payment Option", fontWeight = FontWeight.Bold, fontSize = 16.sp)
                Text(
                    text = "Fast & secure instant checkout with 256-bit encryption",
                    fontSize = 12.sp,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
                Spacer(modifier = Modifier.height(10.dp))

                val paymentOptions = listOf(
                    BookingPaymentOption("UPI", "Instant UPI Apps", "Google Pay, PhonePe, Paytm, BHIM", Icons.Default.Bolt),
                    BookingPaymentOption("CARD", "Credit / Debit Cards", "Visa, MasterCard, RuPay (0% surcharge)", Icons.Default.CreditCard),
                    BookingPaymentOption("NETBANKING", "Net Banking", "SBI, HDFC, ICICI, Axis & 50+ Banks", Icons.Default.AccountBalance),
                    BookingPaymentOption("WALLET", "BMS Wallet", "Fast 1-tap checkout from account balance", Icons.Default.AccountBalanceWallet),
                    BookingPaymentOption("VENUE", "Pay at Venue", "Reserve slot now, pay cash/UPI at counter", Icons.Default.Storefront)
                )

                paymentOptions.forEach { (key, title, subtitle, icon) ->
                    val isSelected = selectedPaymentMode == key
                    Card(
                        onClick = { selectedPaymentMode = key },
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(vertical = 3.dp),
                        shape = RoundedCornerShape(12.dp),
                        colors = CardDefaults.cardColors(
                            containerColor = if (isSelected) MaterialTheme.colorScheme.primaryContainer else MaterialTheme.colorScheme.surface
                        ),
                        border = if (isSelected) BorderStroke(1.5.dp, MaterialTheme.colorScheme.primary) else BorderStroke(0.5.dp, MaterialTheme.colorScheme.outlineVariant)
                    ) {
                        Row(
                            modifier = Modifier
                                .fillMaxWidth()
                                .padding(horizontal = 14.dp, vertical = 12.dp),
                            verticalAlignment = Alignment.CenterVertically,
                            horizontalArrangement = Arrangement.SpaceBetween
                        ) {
                            Row(
                                verticalAlignment = Alignment.CenterVertically,
                                modifier = Modifier.weight(1f)
                            ) {
                                RadioButton(
                                    selected = isSelected,
                                    onClick = { selectedPaymentMode = key }
                                )
                                Spacer(modifier = Modifier.width(8.dp))
                                Column {
                                    Row(verticalAlignment = Alignment.CenterVertically) {
                                        Icon(
                                            icon,
                                            contentDescription = null,
                                            modifier = Modifier.size(16.dp),
                                            tint = if (isSelected) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.onSurfaceVariant
                                        )
                                        Spacer(modifier = Modifier.width(6.dp))
                                        Text(
                                            text = title,
                                            fontWeight = FontWeight.Bold,
                                            fontSize = 13.5.sp,
                                            color = MaterialTheme.colorScheme.onSurface
                                        )
                                    }
                                    Text(
                                        text = subtitle,
                                        fontSize = 11.sp,
                                        color = MaterialTheme.colorScheme.onSurfaceVariant
                                    )
                                }
                            }
                        }
                    }
                }
            }

            // Step 5: Price Breakdown
            item {
                Spacer(modifier = Modifier.height(20.dp))
                Card(
                    modifier = Modifier.fillMaxWidth(),
                    shape = RoundedCornerShape(16.dp),
                    colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.5f))
                ) {
                    Column(modifier = Modifier.padding(16.dp)) {
                        Text("Price Breakdown", fontWeight = FontWeight.Bold, fontSize = 14.sp)
                        Spacer(modifier = Modifier.height(8.dp))
                        Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                            Text("Court / Slot Base Fare", fontSize = 13.sp)
                            Text("₹${basePrice.toInt()}", fontSize = 13.sp)
                        }
                        Spacer(modifier = Modifier.height(4.dp))
                        Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                            Text("GST & Taxes (18%)", fontSize = 13.sp)
                            Text("₹${taxAmount.toInt()}", fontSize = 13.sp)
                        }
                        if (discountAmount > 0) {
                            Spacer(modifier = Modifier.height(4.dp))
                            Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                                Text("Discount ($appliedCoupon)", fontSize = 13.sp, color = MaterialTheme.colorScheme.primary)
                                Text("-₹${discountAmount.toInt()}", fontSize = 13.sp, color = MaterialTheme.colorScheme.primary, fontWeight = FontWeight.Bold)
                            }
                        }
                        HorizontalDivider(modifier = Modifier.padding(vertical = 8.dp))
                        Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                            Text("Grand Total Payable", fontWeight = FontWeight.Bold, fontSize = 15.sp)
                            Text("₹${grandTotal.toInt()}", fontWeight = FontWeight.ExtraBold, fontSize = 16.sp, color = MaterialTheme.colorScheme.primary)
                        }
                    }
                }
            }
        }
    }
}

/**
 * Interactive Calendar Component for Customer Booking Flow
 */
@Composable
fun VenueInteractiveCalendar(
    venueId: String,
    selectedDateStr: String,
    onDateSelected: (String) -> Unit
) {
    val initialDate = remember(selectedDateStr) {
        try {
            LocalDate.parse(selectedDateStr)
        } catch (e: Exception) {
            LocalDate.of(2026, 8, 8)
        }
    }

    var currentYearMonth by remember { mutableStateOf(YearMonth.from(initialDate)) }
    val today = remember {
        try { LocalDate.of(2026, 8, 8) } catch (e: Exception) { LocalDate.now() }
    }

    Card(
        modifier = Modifier
            .fillMaxWidth()
            .testTag("interactive_calendar_card"),
        shape = RoundedCornerShape(20.dp),
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface),
        elevation = CardDefaults.cardElevation(defaultElevation = 2.dp),
        border = BorderStroke(1.dp, MaterialTheme.colorScheme.outlineVariant)
    ) {
        Column(modifier = Modifier.padding(16.dp)) {
            // Calendar Header: Month/Year title + Navigation Controls
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Icon(
                        Icons.Default.CalendarMonth,
                        contentDescription = null,
                        tint = MaterialTheme.colorScheme.primary,
                        modifier = Modifier.size(22.dp)
                    )
                    Spacer(modifier = Modifier.width(8.dp))
                    Text(
                        text = currentYearMonth.format(DateTimeFormatter.ofPattern("MMMM yyyy")),
                        fontWeight = FontWeight.Bold,
                        fontSize = 17.sp,
                        color = MaterialTheme.colorScheme.onSurface
                    )
                }

                Row {
                    IconButton(
                        onClick = { currentYearMonth = currentYearMonth.minusMonths(1) },
                        enabled = currentYearMonth.isAfter(YearMonth.from(today).minusMonths(1))
                    ) {
                        Icon(Icons.Default.ChevronLeft, contentDescription = "Previous Month")
                    }
                    IconButton(
                        onClick = { currentYearMonth = currentYearMonth.plusMonths(1) },
                        enabled = currentYearMonth.isBefore(YearMonth.from(today).plusMonths(6))
                    ) {
                        Icon(Icons.Default.ChevronRight, contentDescription = "Next Month")
                    }
                }
            }

            Spacer(modifier = Modifier.height(8.dp))

            // Legend Bar
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .background(
                        MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.5f),
                        shape = RoundedCornerShape(10.dp)
                    )
                    .padding(horizontal = 10.dp, vertical = 6.dp),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                CalendarLegendItem(color = Color(0xFF2E7D32), label = "Available")
                CalendarLegendItem(color = Color(0xFFE65100), label = "Partial")
                CalendarLegendItem(color = Color(0xFFC62828), label = "Full/Blocked")
                CalendarLegendItem(color = MaterialTheme.colorScheme.primary, label = "Selected")
            }

            Spacer(modifier = Modifier.height(14.dp))

            // Days of Week Header
            Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                val weekDays = listOf("Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat")
                weekDays.forEach { dayName ->
                    Text(
                        text = dayName,
                        modifier = Modifier.weight(1f),
                        textAlign = TextAlign.Center,
                        fontWeight = FontWeight.SemiBold,
                        fontSize = 12.sp,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                }
            }

            Spacer(modifier = Modifier.height(8.dp))

            // Days Grid
            val firstDayOfMonth = currentYearMonth.atDay(1)
            val daysInMonth = currentYearMonth.lengthOfMonth()
            val firstDayOfWeekOffset = firstDayOfMonth.dayOfWeek.value % 7 // Sunday = 0
            val totalCells = firstDayOfWeekOffset + daysInMonth
            val totalRows = (totalCells + 6) / 7

            Column {
                for (rowIndex in 0 until totalRows) {
                    Row(
                        modifier = Modifier.fillMaxWidth().padding(vertical = 3.dp),
                        horizontalArrangement = Arrangement.SpaceBetween
                    ) {
                        for (colIndex in 0..6) {
                            val cellIndex = rowIndex * 7 + colIndex
                            val dayNumber = cellIndex - firstDayOfWeekOffset + 1

                            if (cellIndex < firstDayOfWeekOffset || dayNumber > daysInMonth) {
                                Box(modifier = Modifier.weight(1f).aspectRatio(1f))
                            } else {
                                val cellDate = currentYearMonth.atDay(dayNumber)
                                val cellDateStr = cellDate.toString()
                                val isToday = cellDate == today
                                val isSelected = cellDateStr == selectedDateStr

                                val availabilityInfo = BookMySpaceRepository.getDateAvailability(venueId, cellDateStr)
                                val status = availabilityInfo.status

                                CalendarDayCell(
                                    modifier = Modifier.weight(1f),
                                    dayNumber = dayNumber,
                                    isToday = isToday,
                                    isSelected = isSelected,
                                    availabilityInfo = availabilityInfo,
                                    onClick = {
                                        if (status != DateAvailabilityStatus.FULLY_BOOKED &&
                                            status != DateAvailabilityStatus.SOLD_OUT &&
                                            status != DateAvailabilityStatus.MAINTENANCE_BLOCKED
                                        ) {
                                            onDateSelected(cellDateStr)
                                        }
                                    }
                                )
                            }
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun CalendarLegendItem(color: Color, label: String) {
    Row(verticalAlignment = Alignment.CenterVertically) {
        Box(
            modifier = Modifier
                .size(8.dp)
                .clip(RoundedCornerShape(50))
                .background(color)
        )
        Spacer(modifier = Modifier.width(4.dp))
        Text(label, fontSize = 10.sp, fontWeight = FontWeight.Medium, color = MaterialTheme.colorScheme.onSurfaceVariant)
    }
}

@Composable
private fun CalendarDayCell(
    modifier: Modifier,
    dayNumber: Int,
    isToday: Boolean,
    isSelected: Boolean,
    availabilityInfo: DateAvailabilityInfo,
    onClick: () -> Unit
) {
    val haptic = LocalHapticFeedback.current
    val status = availabilityInfo.status

    val isClickable = status != DateAvailabilityStatus.FULLY_BOOKED &&
            status != DateAvailabilityStatus.SOLD_OUT &&
            status != DateAvailabilityStatus.MAINTENANCE_BLOCKED

    val backgroundColor = when {
        isSelected -> MaterialTheme.colorScheme.primary
        status == DateAvailabilityStatus.AVAILABLE -> Color(0xFFE8F5E9)
        status == DateAvailabilityStatus.PARTIALLY_AVAILABLE || status == DateAvailabilityStatus.FILLING_FAST || status == DateAvailabilityStatus.LIMITED -> Color(0xFFFFF3E0)
        status == DateAvailabilityStatus.FULLY_BOOKED || status == DateAvailabilityStatus.SOLD_OUT -> Color(0xFFFFEBEE)
        status == DateAvailabilityStatus.MAINTENANCE_BLOCKED -> Color(0xFFF5F5F5)
        else -> Color.Transparent
    }

    val textColor = when {
        isSelected -> MaterialTheme.colorScheme.onPrimary
        !isClickable -> MaterialTheme.colorScheme.onSurface.copy(alpha = 0.38f)
        status == DateAvailabilityStatus.AVAILABLE -> Color(0xFF1B5E20)
        status == DateAvailabilityStatus.PARTIALLY_AVAILABLE || status == DateAvailabilityStatus.FILLING_FAST || status == DateAvailabilityStatus.LIMITED -> Color(0xFFE65100)
        else -> MaterialTheme.colorScheme.onSurface
    }

    val badgeColor = when (status) {
        DateAvailabilityStatus.AVAILABLE -> Color(0xFF2E7D32)
        DateAvailabilityStatus.PARTIALLY_AVAILABLE, DateAvailabilityStatus.FILLING_FAST, DateAvailabilityStatus.LIMITED -> Color(0xFFEF6C00)
        DateAvailabilityStatus.FULLY_BOOKED, DateAvailabilityStatus.SOLD_OUT -> Color(0xFFC62828)
        DateAvailabilityStatus.MAINTENANCE_BLOCKED -> Color(0xFF616161)
        else -> Color.Transparent
    }

    val borderStroke = when {
        isSelected -> BorderStroke(2.dp, MaterialTheme.colorScheme.primaryContainer)
        isToday -> BorderStroke(2.dp, MaterialTheme.colorScheme.primary)
        else -> null
    }

    Box(
        modifier = modifier
            .padding(2.dp)
            .aspectRatio(1f)
            .clip(RoundedCornerShape(10.dp))
            .background(backgroundColor)
            .then(if (borderStroke != null) Modifier.border(borderStroke, RoundedCornerShape(10.dp)) else Modifier)
            .clickable(enabled = true) {
                if (isClickable) {
                    haptic.performHapticFeedback(HapticFeedbackType.TextHandleMove)
                    onClick()
                } else {
                    haptic.performHapticFeedback(HapticFeedbackType.LongPress)
                }
            },
        contentAlignment = Alignment.Center
    ) {
        Column(
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.Center
        ) {
            Text(
                text = dayNumber.toString(),
                fontWeight = if (isSelected || isToday) FontWeight.Bold else FontWeight.Medium,
                fontSize = 13.sp,
                color = textColor
            )

            if (isSelected) {
                Text("SELECTED", fontSize = 6.sp, fontWeight = FontWeight.Bold, color = MaterialTheme.colorScheme.onPrimary)
            } else if (isToday && isClickable) {
                Text("TODAY", fontSize = 6.sp, fontWeight = FontWeight.Bold, color = MaterialTheme.colorScheme.primary)
            } else when (status) {
                DateAvailabilityStatus.PARTIALLY_AVAILABLE, DateAvailabilityStatus.FILLING_FAST, DateAvailabilityStatus.LIMITED -> {
                    Text(
                        "${availabilityInfo.availableSlotsCount} open",
                        fontSize = 6.sp,
                        fontWeight = FontWeight.Bold,
                        color = Color(0xFFE65100)
                    )
                }
                DateAvailabilityStatus.FULLY_BOOKED, DateAvailabilityStatus.SOLD_OUT -> {
                    Text("FULL", fontSize = 6.sp, fontWeight = FontWeight.Bold, color = Color(0xFFC62828))
                }
                DateAvailabilityStatus.MAINTENANCE_BLOCKED -> {
                    Text("BLOCK", fontSize = 6.sp, fontWeight = FontWeight.Bold, color = Color(0xFF616161))
                }
                DateAvailabilityStatus.AVAILABLE -> {
                    Box(
                        modifier = Modifier
                            .size(4.dp)
                            .clip(RoundedCornerShape(50))
                            .background(badgeColor)
                    )
                }
                else -> {}
            }
        }
    }
}

