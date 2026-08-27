package com.bookmyspace.bookmyspace.ui.screens

import android.widget.Toast
import androidx.compose.animation.*
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalHapticFeedback
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.bookmyspace.bookmyspace.data.model.Booking
import com.bookmyspace.bookmyspace.data.model.BookingStatus
import com.bookmyspace.bookmyspace.data.model.DateAvailabilityInfo
import com.bookmyspace.bookmyspace.data.model.DateAvailabilityStatus
import com.bookmyspace.bookmyspace.data.model.RegistrationFieldCategory
import com.bookmyspace.bookmyspace.data.model.RegistrationFieldType
import com.bookmyspace.bookmyspace.data.model.RegistrationTargetModule
import com.bookmyspace.bookmyspace.data.model.TimeSlot
import com.bookmyspace.bookmyspace.data.model.UserRegistrationFieldDefinition
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

private fun getCategoryAdaptiveTimeSlots(venue: com.bookmyspace.bookmyspace.data.model.Venue): List<TimeSlot> {
    val categorySlug = venue.category?.slug?.lowercase() ?: ""
    val isPg = venue.pgDetails != null || categorySlug.contains("pg") || categorySlug.contains("hostel")
    val isHotel = venue.hotelDetails != null || categorySlug.contains("hotel") || categorySlug.contains("lodge")
    val isHall = categorySlug.contains("hall") || categorySlug.contains("banquet") || categorySlug.contains("wedding") || categorySlug.contains("venue")
    val isAcademy = categorySlug.contains("academy") || categorySlug.contains("institute") || categorySlug.contains("class")

    return when {
        isPg -> {
            val baseRent = venue.pricingBaseAmount
            listOf(
                TimeSlot(
                    id = "${venue.id}_pg_1",
                    venueId = venue.id,
                    label = "Monthly Bed + 3 Meals & WiFi",
                    startTime = "01st of Month",
                    endTime = "End of Month",
                    priceAmount = baseRent
                ),
                TimeSlot(
                    id = "${venue.id}_pg_2",
                    venueId = venue.id,
                    label = "2-Sharing Executive Room (Monthly)",
                    startTime = "01st of Month",
                    endTime = "End of Month",
                    priceAmount = (baseRent * 0.85).coerceAtLeast(4000.0)
                ),
                TimeSlot(
                    id = "${venue.id}_pg_3",
                    venueId = venue.id,
                    label = "Single Private Luxury Room (Monthly)",
                    startTime = "01st of Month",
                    endTime = "End of Month",
                    priceAmount = (baseRent * 1.35).coerceAtLeast(7000.0)
                ),
                TimeSlot(
                    id = "${venue.id}_pg_4",
                    venueId = venue.id,
                    label = "Daily Guest Trial Pass (24 Hours)",
                    startTime = "12:00 PM",
                    endTime = "11:00 AM Next Day",
                    priceAmount = 599.0
                )
            )
        }
        isHotel -> {
            val roomBase = venue.pricingBaseAmount
            listOf(
                TimeSlot(
                    id = "${venue.id}_ht_1",
                    venueId = venue.id,
                    label = "Deluxe Room (1 Night Stay)",
                    startTime = "12:00 PM",
                    endTime = "11:00 AM Next Day",
                    priceAmount = roomBase
                ),
                TimeSlot(
                    id = "${venue.id}_ht_2",
                    venueId = venue.id,
                    label = "Flexible Day Stay (9 AM - 5 PM)",
                    startTime = "09:00 AM",
                    endTime = "05:00 PM",
                    priceAmount = (roomBase * 0.60).coerceAtLeast(999.0)
                ),
                TimeSlot(
                    id = "${venue.id}_ht_3",
                    venueId = venue.id,
                    label = "Executive Business Suite (1 Night)",
                    startTime = "12:00 PM",
                    endTime = "11:00 AM Next Day",
                    priceAmount = (roomBase * 1.40).coerceAtLeast(2499.0)
                ),
                TimeSlot(
                    id = "${venue.id}_ht_4",
                    venueId = venue.id,
                    label = "24-Hour Express Flexi Check-In",
                    startTime = "Flexible Check-In",
                    endTime = "+24 Hours",
                    priceAmount = (roomBase * 1.15).coerceAtLeast(1499.0)
                )
            )
        }
        isHall -> {
            val hallBase = venue.pricingBaseAmount
            listOf(
                TimeSlot(
                    id = "${venue.id}_hl_1",
                    venueId = venue.id,
                    label = "Full Day Grand Event (06:00 AM - 11:30 PM)",
                    startTime = "06:00 AM",
                    endTime = "11:30 PM",
                    priceAmount = hallBase
                ),
                TimeSlot(
                    id = "${venue.id}_hl_2",
                    venueId = venue.id,
                    label = "Morning Muhurtham Slot (06:00 AM - 02:00 PM)",
                    startTime = "06:00 AM",
                    endTime = "02:00 PM",
                    priceAmount = (hallBase * 0.60).coerceAtLeast(15000.0)
                ),
                TimeSlot(
                    id = "${venue.id}_hl_3",
                    venueId = venue.id,
                    label = "Evening Reception Slot (04:00 PM - 11:30 PM)",
                    startTime = "04:00 PM",
                    endTime = "11:30 PM",
                    priceAmount = (hallBase * 0.70).coerceAtLeast(20000.0)
                ),
                TimeSlot(
                    id = "${venue.id}_hl_4",
                    venueId = venue.id,
                    label = "Sangeet & Party Night (06:00 PM - 01:00 AM)",
                    startTime = "06:00 PM",
                    endTime = "01:00 AM",
                    priceAmount = (hallBase * 0.55).coerceAtLeast(12000.0)
                )
            )
        }
        isAcademy -> {
            val classBase = venue.pricingBaseAmount
            listOf(
                TimeSlot(
                    id = "${venue.id}_ac_1",
                    venueId = venue.id,
                    label = "Morning Batch (07:00 AM - 09:00 AM)",
                    startTime = "07:00 AM",
                    endTime = "09:00 AM",
                    priceAmount = classBase
                ),
                TimeSlot(
                    id = "${venue.id}_ac_2",
                    venueId = venue.id,
                    label = "Evening Batch (05:00 PM - 07:00 PM)",
                    startTime = "05:00 PM",
                    endTime = "07:00 PM",
                    priceAmount = classBase
                ),
                TimeSlot(
                    id = "${venue.id}_ac_3",
                    venueId = venue.id,
                    label = "Weekend Masterclass (10:00 AM - 01:00 PM)",
                    startTime = "10:00 AM",
                    endTime = "01:00 PM",
                    priceAmount = (classBase * 1.25).coerceAtLeast(499.0)
                ),
                TimeSlot(
                    id = "${venue.id}_ac_4",
                    venueId = venue.id,
                    label = "Full Month All-Access Pass",
                    startTime = "01st of Month",
                    endTime = "End of Month",
                    priceAmount = (classBase * 3.5).coerceAtLeast(2499.0)
                )
            )
        }
        else -> {
            val turfBase = venue.pricingBaseAmount
            listOf(
                TimeSlot(
                    id = "${venue.id}_ts_1",
                    venueId = venue.id,
                    label = "Morning Prime Slot (06:00 AM - 08:00 AM)",
                    startTime = "06:00 AM",
                    endTime = "08:00 AM",
                    priceAmount = turfBase
                ),
                TimeSlot(
                    id = "${venue.id}_ts_2",
                    venueId = venue.id,
                    label = "Afternoon Saver Slot (02:00 PM - 04:00 PM)",
                    startTime = "02:00 PM",
                    endTime = "04:00 PM",
                    priceAmount = (turfBase * 0.8).coerceAtLeast(400.0)
                ),
                TimeSlot(
                    id = "${venue.id}_ts_3",
                    venueId = venue.id,
                    label = "Evening Prime Slot (06:00 PM - 08:00 PM)",
                    startTime = "06:00 PM",
                    endTime = "08:00 PM",
                    priceAmount = (turfBase * 1.15).coerceAtLeast(700.0)
                ),
                TimeSlot(
                    id = "${venue.id}_ts_4",
                    venueId = venue.id,
                    label = "Night Floodlight Slot (08:00 PM - 10:00 PM)",
                    startTime = "08:00 PM",
                    endTime = "10:00 PM",
                    priceAmount = (turfBase * 1.25).coerceAtLeast(800.0)
                )
            )
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun BookingScreen(
    venueId: String,
    onBack: () -> Unit,
    onProceedToPayment: (String) -> Unit
) {
    val context = LocalContext.current
    val haptic = LocalHapticFeedback.current
    val venues by BookMySpaceRepository.venues.collectAsState()
    val venue = venues.firstOrNull { it.id == venueId } ?: venues.first()
    val user by BookMySpaceRepository.authUser.collectAsState()
    val bookings by BookMySpaceRepository.bookings.collectAsState()

    var selectedDateStr by remember { mutableStateOf("2026-08-08") }
    
    val effectiveSlots = remember(venue) {
        if (venue.timeSlots.isNotEmpty()) venue.timeSlots else getCategoryAdaptiveTimeSlots(venue)
    }

    // Auto-select initial slot
    var selectedSlot by remember(venue, selectedDateStr, effectiveSlots) {
        val openSlots = effectiveSlots.filter { slot ->
            !BookMySpaceRepository.isSlotAlreadyBooked(venue.id, selectedDateStr, slot.label)
        }
        mutableStateOf<TimeSlot?>(openSlots.firstOrNull() ?: effectiveSlots.firstOrNull())
    }

    // Member count and attendee state
    var memberCount by remember { mutableIntStateOf(1) }
    var adultsCount by remember { mutableIntStateOf(1) }
    var childrenCount by remember { mutableIntStateOf(0) }
    var additionalMemberNames by remember { mutableStateOf(listOf<String>()) }

    // Primary Guest Registration state
    val allRegistrationFields by BookMySpaceRepository.registrationFields.collectAsState()
    val userProfile by BookMySpaceRepository.currentUserProfile.collectAsState()

    var primaryContactName by remember(userProfile, user) {
        mutableStateOf(userProfile?.fullName ?: user?.fullName ?: "Priya Sharma")
    }
    var primaryContactPhone by remember(userProfile, user) {
        mutableStateOf(userProfile?.phone ?: user?.phone ?: "+91 98765 43210")
    }
    var primaryContactEmail by remember(userProfile, user) {
        mutableStateOf(userProfile?.email ?: user?.email ?: "priya@example.com")
    }
    var govtIdType by remember { mutableStateOf("Aadhaar Card") }
    var govtIdNumber by remember(userProfile) {
        mutableStateOf(userProfile?.aadhaarNumber ?: "9876 5432 1098")
    }
    var emergencyContact by remember(userProfile) {
        mutableStateOf(userProfile?.emergencyContact ?: "+91 91234 56789")
    }
    var specialNotes by remember { mutableStateOf("") }
    var regIsKycVerified by remember { mutableStateOf(userProfile?.isKycVerified ?: true) }

    // Registration confirmation gate state
    var isRegistrationConfirmed by remember { mutableStateOf(false) }
    var registrationValidationErrors by remember { mutableStateOf<List<String>>(emptyList()) }
    var isEditingRegistrationAfterConfirm by remember { mutableStateOf(false) }

    val isCategoryUnifiedRegEnabled = remember(venue) {
        BookMySpaceRepository.isUnifiedRegistrationEnabledForCategory(venue.category?.slug ?: venue.category?.id)
    }

    val applicableRegFields = remember(allRegistrationFields) {
        BookMySpaceRepository.getFieldsForModule(RegistrationTargetModule.CUSTOMER)
    }

    // Dynamic field responses map initialized with user profile / standard values
    val registrationFieldResponses = remember(userProfile, applicableRegFields) {
        mutableStateMapOf<String, String>().apply {
            applicableRegFields.forEach { field ->
                val profileVal: String = when (field.key) {
                    "full_name" -> userProfile?.fullName ?: user?.fullName ?: "Priya Sharma"
                    "phone" -> userProfile?.phone ?: user?.phone ?: "+91 98765 43210"
                    "email" -> userProfile?.email ?: user?.email ?: "priya@example.com"
                    "aadhaar_number" -> userProfile?.aadhaarNumber ?: "9876 5432 1098"
                    "govt_id_number" -> userProfile?.govtIdNumber ?: "DL-042011001234"
                    "address_line_1" -> userProfile?.addressLine1 ?: "Banjara Hills, Road No. 12"
                    "address_line_2" -> userProfile?.addressLine2 ?: ""
                    "pincode" -> userProfile?.pincode ?: "500034"
                    "gender" -> userProfile?.gender ?: "Female"
                    "dob" -> userProfile?.dob ?: "1994-06-15"
                    "emergency_contact" -> userProfile?.emergencyContact ?: "+91 91234 56789"
                    else -> userProfile?.customFields?.get(field.key) ?: field.defaultValue
                }
                put(field.key, profileVal)
            }
        }
    }

    // Keep additional member list synchronized with memberCount
    LaunchedEffect(memberCount) {
        val neededAdditional = (memberCount - 1).coerceAtLeast(0)
        if (additionalMemberNames.size != neededAdditional) {
            val newList = additionalMemberNames.take(neededAdditional).toMutableList()
            while (newList.size < neededAdditional) {
                newList.add("Member ${newList.size + 2}")
            }
            additionalMemberNames = newList
        }
    }

    // Validation checker function
    fun validateRegistrationForm(): List<String> {
        val errors = mutableListOf<String>()
        if (primaryContactName.trim().isBlank()) {
            errors.add("Primary Contact Name is required.")
        }
        if (primaryContactPhone.trim().length < 8) {
            errors.add("Valid Contact Mobile Number (min 8-10 digits) is required.")
        }
        if (!primaryContactEmail.trim().contains("@") || !primaryContactEmail.trim().contains(".")) {
            errors.add("Valid Email address is required.")
        }
        if (govtIdNumber.trim().isBlank()) {
            errors.add("Government ID / Verification number is required.")
        }
        if (memberCount < 1) {
            errors.add("Member count must be at least 1.")
        }
        if (!regIsKycVerified) {
            errors.add("Please verify and accept the KYC & safety declaration.")
        }
        if (isCategoryUnifiedRegEnabled) {
            applicableRegFields.filter { it.required }.forEach { field ->
                val response = registrationFieldResponses[field.key]?.trim() ?: ""
                if (response.isBlank()) {
                    errors.add("${field.label} is mandatory.")
                }
            }
        }
        return errors
    }

    val areRequiredRegistrationFieldsFilled by remember(
        primaryContactName,
        primaryContactPhone,
        primaryContactEmail,
        govtIdNumber,
        memberCount,
        regIsKycVerified,
        isCategoryUnifiedRegEnabled,
        applicableRegFields,
        registrationFieldResponses
    ) {
        derivedStateOf {
            primaryContactName.trim().isNotBlank() &&
                    primaryContactPhone.trim().length >= 8 &&
                    primaryContactEmail.trim().contains("@") &&
                    govtIdNumber.trim().isNotBlank() &&
                    memberCount >= 1 &&
                    regIsKycVerified &&
                    (!isCategoryUnifiedRegEnabled || !applicableRegFields.filter { it.required }.any { field ->
                        (registrationFieldResponses[field.key]?.trim() ?: "").isEmpty()
                    })
        }
    }

    // Payment state
    var selectedPaymentMode by remember { mutableStateOf("UPI") }
    var isAdvanceTokenSelected by remember { mutableStateOf(false) }
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
    val advanceAmount by remember(grandTotal) {
        derivedStateOf { (grandTotal * 0.25).coerceAtLeast(500.0).coerceAtMost(grandTotal) }
    }
    val balanceDueAtVenue by remember(grandTotal, advanceAmount) {
        derivedStateOf { (grandTotal - advanceAmount).coerceAtLeast(0.0) }
    }

    com.bookmyspace.bookmyspace.util.TraceComposition("BookingScreen")

    Scaffold(
        topBar = {
            TopAppBar(
                title = {
                    Column {
                        Text("Book Court / Space", fontWeight = FontWeight.Bold, fontSize = 17.sp)
                        Text(
                            text = if (isRegistrationConfirmed) "Step 3/3: Payment & Checkout" else "Step 2/3: Member Registration Required",
                            fontSize = 11.sp,
                            color = if (isRegistrationConfirmed) Color(0xFF2E7D32) else MaterialTheme.colorScheme.primary
                        )
                    }
                },
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "Back")
                    }
                },
                colors = TopAppBarDefaults.topAppBarColors(containerColor = MaterialTheme.colorScheme.surface)
            )
        },
        bottomBar = {
            Surface(
                shadowElevation = 12.dp,
                color = MaterialTheme.colorScheme.surface,
                modifier = Modifier.fillMaxWidth()
            ) {
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(horizontal = 16.dp, vertical = 12.dp),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Column(modifier = Modifier.weight(1f)) {
                        Text(
                            text = when {
                                !isRegistrationConfirmed -> "👥 $memberCount Member(s) Selected"
                                selectedPaymentMode == "VENUE" -> "Pay at Venue"
                                isAdvanceTokenSelected -> "Advance Token"
                                else -> "Total Payable"
                            },
                            fontSize = 11.sp,
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            Text(
                                text = if (isAdvanceTokenSelected && selectedPaymentMode != "VENUE") "₹${advanceAmount.toInt()}" else "₹${grandTotal.toInt()}",
                                fontSize = 20.sp,
                                fontWeight = FontWeight.ExtraBold,
                                color = MaterialTheme.colorScheme.primary
                            )
                            if (isRegistrationConfirmed) {
                                Spacer(modifier = Modifier.width(6.dp))
                                Surface(
                                    shape = RoundedCornerShape(4.dp),
                                    color = Color(0xFF2E7D32).copy(alpha = 0.15f)
                                ) {
                                    Text(
                                        "REGISTERED",
                                        color = Color(0xFF2E7D32),
                                        fontWeight = FontWeight.Bold,
                                        fontSize = 9.sp,
                                        modifier = Modifier.padding(horizontal = 4.dp, vertical = 1.dp)
                                    )
                                }
                            }
                        }
                        if (isAdvanceTokenSelected && selectedPaymentMode != "VENUE" && balanceDueAtVenue > 0 && isRegistrationConfirmed) {
                            Text(
                                text = "₹${balanceDueAtVenue.toInt()} at venue",
                                fontSize = 10.sp,
                                fontWeight = FontWeight.SemiBold,
                                color = Color(0xFFFF9800)
                            )
                        }
                    }

                    Spacer(modifier = Modifier.width(10.dp))

                    if (!isRegistrationConfirmed) {
                        Button(
                            onClick = {
                                val errors = validateRegistrationForm()
                                registrationValidationErrors = errors
                                if (errors.isEmpty()) {
                                    haptic.performHapticFeedback(HapticFeedbackType.LongPress)
                                    isRegistrationConfirmed = true
                                    isEditingRegistrationAfterConfirm = false
                                    Toast.makeText(context, "✓ Registration verified for $memberCount member(s)! Payment section unlocked.", Toast.LENGTH_LONG).show()
                                } else {
                                    haptic.performHapticFeedback(HapticFeedbackType.TextHandleMove)
                                    Toast.makeText(context, "Please fill required registration fields below to unlock payment.", Toast.LENGTH_SHORT).show()
                                }
                            },
                            modifier = Modifier
                                .height(48.dp)
                                .testTag("register_and_unlock_payment_button"),
                            colors = ButtonDefaults.buttonColors(
                                containerColor = if (areRequiredRegistrationFieldsFilled) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.secondary
                            ),
                            shape = RoundedCornerShape(12.dp)
                        ) {
                            Row(verticalAlignment = Alignment.CenterVertically) {
                                Icon(Icons.Default.VerifiedUser, contentDescription = null, modifier = Modifier.size(16.dp))
                                Spacer(modifier = Modifier.width(6.dp))
                                Text(
                                    text = if (areRequiredRegistrationFieldsFilled) "Register & Pay 💳" else "Complete Registration",
                                    fontWeight = FontWeight.Bold,
                                    fontSize = 13.5.sp
                                )
                            }
                        }
                    } else {
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
                                    val isAdvance = isAdvanceTokenSelected && selectedPaymentMode != "VENUE"
                                    val finalCustomerName = primaryContactName.ifBlank { user?.fullName ?: "Customer" }
                                    val finalCustomerPhone = primaryContactPhone.ifBlank { user?.phone ?: "" }
                                    val finalCustomerEmail = primaryContactEmail.ifBlank { user?.email ?: "" }

                                    // Build enriched registration details map
                                    val fullRegDetails = registrationFieldResponses.toMutableMap().apply {
                                        put("full_name", finalCustomerName)
                                        put("phone", finalCustomerPhone)
                                        put("email", finalCustomerEmail)
                                        put("govt_id_type", govtIdType)
                                        put("govt_id_number", govtIdNumber)
                                        put("emergency_contact", emergencyContact)
                                        put("member_count", memberCount.toString())
                                        put("adults_count", adultsCount.toString())
                                        put("children_count", childrenCount.toString())
                                        put("additional_member_names", additionalMemberNames.joinToString(", "))
                                        put("special_notes", specialNotes)
                                        put("kyc_verified", regIsKycVerified.toString())
                                        put("registration_status", "CONFIRMED")
                                    }

                                    val newBooking = Booking(
                                        id = "bk_${System.currentTimeMillis()}",
                                        userId = user?.id ?: "guest",
                                        userName = finalCustomerName,
                                        userEmail = finalCustomerEmail,
                                        userPhone = finalCustomerPhone,
                                        venueId = venue.id,
                                        venueName = venue.name,
                                        venueImageUrl = venue.coverImageUrl,
                                        venueCoverUrl = venue.coverImageUrl,
                                        slotLabel = slot?.label ?: "Standard Slot",
                                        bookingDate = selectedDateStr,
                                        date = selectedDateStr,
                                        startTime = slot?.startTime ?: "09:00",
                                        endTime = slot?.endTime ?: "11:00",
                                        baseAmount = basePrice,
                                        taxAmount = taxAmount,
                                        discountAmount = discountAmount,
                                        totalAmount = grandTotal,
                                        totalPrice = grandTotal,
                                        couponCode = appliedCoupon ?: "",
                                        status = if (selectedPaymentMode == "VENUE") BookingStatus.CONFIRMED else BookingStatus.PENDING,
                                        isPaid = false,
                                        isAdvancePayment = isAdvance,
                                        advanceAmountPaid = if (isAdvance) advanceAmount else 0.0,
                                        remainingBalanceDue = if (isAdvance) balanceDueAtVenue else 0.0,
                                        paymentPlan = when {
                                            selectedPaymentMode == "VENUE" -> "PAY_AT_VENUE"
                                            isAdvance -> "ADVANCE_SPLIT"
                                            else -> "FULL"
                                        },
                                        guestCount = memberCount,
                                        customerNotes = specialNotes,
                                        registrationDetails = fullRegDetails
                                    )
                                    BookMySpaceRepository.addBooking(newBooking)
                                    onProceedToPayment(newBooking.id)
                                }
                            },
                            modifier = Modifier
                                .height(48.dp)
                                .testTag("confirm_and_pay_button"),
                            enabled = selectedSlot != null && !isDuplicate && dateAvailability.status != DateAvailabilityStatus.FULLY_BOOKED,
                            shape = RoundedCornerShape(12.dp)
                        ) {
                            Row(verticalAlignment = Alignment.CenterVertically) {
                                Icon(Icons.Default.Bolt, contentDescription = null, modifier = Modifier.size(18.dp))
                                Spacer(modifier = Modifier.width(4.dp))
                                Text(
                                    text = when {
                                        isDuplicate -> "Slot Unavailable"
                                        selectedPaymentMode == "VENUE" -> "Book & Pay at Venue"
                                        isAdvanceTokenSelected -> "⚡ Pay Advance ₹${advanceAmount.toInt()}"
                                        else -> "⚡ Book & Pay ₹${grandTotal.toInt()}"
                                    },
                                    fontWeight = FontWeight.Bold,
                                    fontSize = 13.5.sp
                                )
                            }
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
            contentPadding = PaddingValues(16.dp),
            verticalArrangement = Arrangement.spacedBy(14.dp)
        ) {
            // Visual 3-Step Flow Progress Header
            item {
                Card(
                    modifier = Modifier.fillMaxWidth(),
                    shape = RoundedCornerShape(16.dp),
                    colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.6f)),
                    border = BorderStroke(1.dp, MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.5f))
                ) {
                    Column(modifier = Modifier.padding(14.dp)) {
                        Row(
                            modifier = Modifier.fillMaxWidth(),
                            horizontalArrangement = Arrangement.SpaceBetween,
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            Text("Booking Progress", fontWeight = FontWeight.Bold, fontSize = 13.sp)
                            Surface(
                                shape = RoundedCornerShape(6.dp),
                                color = if (isRegistrationConfirmed) Color(0xFF2E7D32).copy(alpha = 0.15f) else MaterialTheme.colorScheme.primaryContainer
                            ) {
                                Text(
                                    text = if (isRegistrationConfirmed) "✓ Step 3 of 3: Ready to Pay" else "Step 2 of 3: Registration Pending",
                                    fontSize = 10.sp,
                                    fontWeight = FontWeight.Bold,
                                    color = if (isRegistrationConfirmed) Color(0xFF2E7D32) else MaterialTheme.colorScheme.primary,
                                    modifier = Modifier.padding(horizontal = 6.dp, vertical = 2.dp)
                                )
                            }
                        }
                        Spacer(modifier = Modifier.height(10.dp))
                        Row(
                            modifier = Modifier.fillMaxWidth(),
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            // Step 1
                            StepIndicatorChip(
                                stepNumber = "1",
                                title = "Dates & Slot",
                                isCompleted = selectedSlot != null,
                                isActive = false,
                                modifier = Modifier.weight(1f)
                            )
                            Box(modifier = Modifier.width(8.dp).height(2.dp).background(MaterialTheme.colorScheme.primary.copy(alpha = 0.5f)))
                            // Step 2
                            StepIndicatorChip(
                                stepNumber = "2",
                                title = "Members & Reg",
                                isCompleted = isRegistrationConfirmed,
                                isActive = !isRegistrationConfirmed,
                                modifier = Modifier.weight(1.2f)
                            )
                            Box(modifier = Modifier.width(8.dp).height(2.dp).background(if (isRegistrationConfirmed) MaterialTheme.colorScheme.primary.copy(alpha = 0.5f) else MaterialTheme.colorScheme.outlineVariant))
                            // Step 3
                            StepIndicatorChip(
                                stepNumber = "3",
                                title = "Payment",
                                isCompleted = false,
                                isActive = isRegistrationConfirmed,
                                isLocked = !isRegistrationConfirmed,
                                modifier = Modifier.weight(1f)
                            )
                        }
                    }
                }
            }

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
                                .size(54.dp)
                                .clip(RoundedCornerShape(12.dp))
                                .background(MaterialTheme.colorScheme.primary.copy(alpha = 0.2f)),
                            contentAlignment = Alignment.Center
                        ) {
                            Text("🏟️", fontSize = 24.sp)
                        }
                        Spacer(modifier = Modifier.width(12.dp))
                        Column {
                            Text(venue.name, fontWeight = FontWeight.Bold, fontSize = 15.sp)
                            Text(venue.fullAddress, fontSize = 11.5.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                        }
                    }
                }
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
                }
            }

            // Step 1: Interactive Calendar Date Picker
            item {
                Text("Step 1: Select Date & Availability Calendar", fontWeight = FontWeight.Bold, fontSize = 15.sp)
                Spacer(modifier = Modifier.height(8.dp))

                VenueInteractiveCalendar(
                    venueId = venue.id,
                    selectedDateStr = selectedDateStr,
                    onDateSelected = { date ->
                        selectedDateStr = date
                        duplicateErrorMsg = null
                        BookMySpaceRepository.notifySlotInteraction()
                    }
                )
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
            }

            // Time Slot Selection Header
            item {
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Column {
                        Text("Select Time Slot", fontWeight = FontWeight.Bold, fontSize = 15.sp)
                        Text(
                            text = "Showing slots for $selectedDateStr (${dateAvailability.availableSlotsCount} available)",
                            fontSize = 11.5.sp,
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                    }
                    if (dateAvailability.status == DateAvailabilityStatus.FULLY_BOOKED || dateAvailability.status == DateAvailabilityStatus.SOLD_OUT) {
                        Badge(containerColor = MaterialTheme.colorScheme.errorContainer) {
                            Text("FULLY BOOKED", fontSize = 10.sp, fontWeight = FontWeight.Bold, color = MaterialTheme.colorScheme.onErrorContainer)
                        }
                    }
                }
            }

            items(effectiveSlots) { slot ->
                val isSelected = selectedSlot?.id == slot.id
                val isBooked = BookMySpaceRepository.isSlotAlreadyBooked(venue.id, selectedDateStr, slot.label)

                Card(
                    modifier = Modifier
                        .fillMaxWidth()
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
                    border = if (isSelected && !isBooked) BorderStroke(2.dp, MaterialTheme.colorScheme.primary) else BorderStroke(0.5.dp, MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.5f))
                ) {
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(14.dp),
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

            // ====================================================================================
            // STEP 2: MANDATORY GUEST REGISTRATION & MEMBER COUNT DETAILS
            // ====================================================================================
            item {
                Card(
                    shape = RoundedCornerShape(18.dp),
                    colors = CardDefaults.cardColors(
                        containerColor = if (isRegistrationConfirmed) Color(0xFFE8F5E9).copy(alpha = 0.6f) else MaterialTheme.colorScheme.primaryContainer.copy(alpha = 0.35f)
                    ),
                    border = BorderStroke(
                        if (isRegistrationConfirmed) 2.dp else 1.5.dp,
                        if (isRegistrationConfirmed) Color(0xFF2E7D32) else MaterialTheme.colorScheme.primary
                    ),
                    modifier = Modifier
                        .fillMaxWidth()
                        .testTag("mandatory_registration_and_member_count_section")
                ) {
                    Column(modifier = Modifier.padding(16.dp)) {
                        // Section Header
                        Row(
                            modifier = Modifier.fillMaxWidth(),
                            horizontalArrangement = Arrangement.SpaceBetween,
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            Row(verticalAlignment = Alignment.CenterVertically) {
                                Icon(
                                    if (isRegistrationConfirmed) Icons.Default.CheckCircle else Icons.Default.Groups,
                                    contentDescription = null,
                                    tint = if (isRegistrationConfirmed) Color(0xFF2E7D32) else MaterialTheme.colorScheme.primary,
                                    modifier = Modifier.size(22.dp)
                                )
                                Spacer(modifier = Modifier.width(8.dp))
                                Column {
                                    Text(
                                        "Step 2: Guest Registration & Member Count",
                                        fontWeight = FontWeight.Bold,
                                        fontSize = 14.5.sp
                                    )
                                    Text(
                                        text = if (isRegistrationConfirmed) "Registration complete & verified for $memberCount member(s)" else "Mandatory details required to unlock payment",
                                        fontSize = 11.sp,
                                        color = if (isRegistrationConfirmed) Color(0xFF2E7D32) else MaterialTheme.colorScheme.onSurfaceVariant
                                    )
                                }
                            }

                            Surface(
                                color = if (isRegistrationConfirmed) Color(0xFF2E7D32) else Color(0xFFFF9800),
                                shape = RoundedCornerShape(6.dp)
                            ) {
                                Text(
                                    text = if (isRegistrationConfirmed) "VERIFIED ✓" else "REQUIRED",
                                    fontSize = 9.5.sp,
                                    fontWeight = FontWeight.ExtraBold,
                                    color = Color.White,
                                    modifier = Modifier.padding(horizontal = 6.dp, vertical = 2.dp)
                                )
                            }
                        }

                        Spacer(modifier = Modifier.height(14.dp))

                        // If confirmed and not currently in edit mode: show verified summary card with "Edit Details" option
                        if (isRegistrationConfirmed && !isEditingRegistrationAfterConfirm) {
                            Surface(
                                shape = RoundedCornerShape(12.dp),
                                color = Color.White,
                                border = BorderStroke(1.dp, Color(0xFF2E7D32).copy(alpha = 0.3f)),
                                modifier = Modifier.fillMaxWidth()
                            ) {
                                Column(modifier = Modifier.padding(14.dp)) {
                                    Row(
                                        modifier = Modifier.fillMaxWidth(),
                                        horizontalArrangement = Arrangement.SpaceBetween,
                                        verticalAlignment = Alignment.CenterVertically
                                    ) {
                                        Row(verticalAlignment = Alignment.CenterVertically) {
                                            Box(
                                                modifier = Modifier
                                                    .size(36.dp)
                                                    .clip(CircleShape)
                                                    .background(Color(0xFF2E7D32).copy(alpha = 0.15f)),
                                                contentAlignment = Alignment.Center
                                            ) {
                                                Icon(Icons.Default.Person, contentDescription = null, tint = Color(0xFF2E7D32), modifier = Modifier.size(20.dp))
                                            }
                                            Spacer(modifier = Modifier.width(10.dp))
                                            Column {
                                                Text(primaryContactName, fontWeight = FontWeight.Bold, fontSize = 14.sp)
                                                Text("Primary Contact • $primaryContactPhone", fontSize = 11.5.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                                            }
                                        }
                                        TextButton(
                                            onClick = { isEditingRegistrationAfterConfirm = true },
                                            modifier = Modifier.testTag("edit_registration_button")
                                        ) {
                                            Icon(Icons.Default.Edit, contentDescription = null, modifier = Modifier.size(14.dp))
                                            Spacer(modifier = Modifier.width(4.dp))
                                            Text("Edit Details", fontSize = 12.sp)
                                        }
                                    }

                                    HorizontalDivider(modifier = Modifier.padding(vertical = 10.dp))

                                    Row(
                                        modifier = Modifier.fillMaxWidth(),
                                        horizontalArrangement = Arrangement.SpaceBetween
                                    ) {
                                        Column {
                                            Text("Total Members / Players", fontSize = 10.5.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                                            Text("👥 $memberCount Person(s)", fontWeight = FontWeight.Bold, fontSize = 13.sp, color = MaterialTheme.colorScheme.primary)
                                        }
                                        Column(horizontalAlignment = Alignment.End) {
                                            Text("KYC Verification", fontSize = 10.5.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                                            Text("🆔 $govtIdType Verified", fontWeight = FontWeight.Bold, fontSize = 13.sp, color = Color(0xFF2E7D32))
                                        }
                                    }

                                    if (additionalMemberNames.isNotEmpty()) {
                                        Spacer(modifier = Modifier.height(8.dp))
                                        Text(
                                            "Additional Members: ${additionalMemberNames.joinToString(", ")}",
                                            fontSize = 11.sp,
                                            color = MaterialTheme.colorScheme.onSurfaceVariant
                                        )
                                    }
                                }
                            }
                        } else {
                            // MEMBER COUNT SELECTOR CARD
                            Surface(
                                shape = RoundedCornerShape(14.dp),
                                color = MaterialTheme.colorScheme.surface,
                                border = BorderStroke(1.dp, MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.5f)),
                                modifier = Modifier.fillMaxWidth()
                            ) {
                                Column(modifier = Modifier.padding(14.dp)) {
                                    Row(
                                        modifier = Modifier.fillMaxWidth(),
                                        horizontalArrangement = Arrangement.SpaceBetween,
                                        verticalAlignment = Alignment.CenterVertically
                                    ) {
                                        Column {
                                            Text("1. Number of Members / Players *", fontWeight = FontWeight.Bold, fontSize = 13.5.sp)
                                            Text("Specify total attendees for this booking", fontSize = 11.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                                        }

                                        // Stepper Controls
                                        Row(
                                            verticalAlignment = Alignment.CenterVertically,
                                            modifier = Modifier
                                                .background(MaterialTheme.colorScheme.surfaceVariant, shape = RoundedCornerShape(20.dp))
                                                .padding(horizontal = 4.dp, vertical = 2.dp)
                                        ) {
                                            IconButton(
                                                onClick = {
                                                    if (memberCount > 1) {
                                                        memberCount -= 1
                                                        adultsCount = memberCount
                                                    }
                                                },
                                                enabled = memberCount > 1,
                                                modifier = Modifier.size(32.dp).testTag("decrease_member_count_btn")
                                            ) {
                                                Icon(Icons.Default.Remove, contentDescription = "Decrease", modifier = Modifier.size(16.dp))
                                            }

                                            Text(
                                                text = memberCount.toString(),
                                                fontWeight = FontWeight.ExtraBold,
                                                fontSize = 16.sp,
                                                color = MaterialTheme.colorScheme.primary,
                                                modifier = Modifier.padding(horizontal = 8.dp).testTag("member_count_display")
                                            )

                                            IconButton(
                                                onClick = {
                                                    if (memberCount < 30) {
                                                        memberCount += 1
                                                        adultsCount = memberCount
                                                    }
                                                },
                                                modifier = Modifier.size(32.dp).testTag("increase_member_count_btn")
                                            ) {
                                                Icon(Icons.Default.Add, contentDescription = "Increase", modifier = Modifier.size(16.dp))
                                            }
                                        }
                                    }

                                    Spacer(modifier = Modifier.height(10.dp))

                                    // Quick Selection Preset Chips
                                    Text("Quick Presets:", fontSize = 11.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                                    Spacer(modifier = Modifier.height(4.dp))
                                    Row(
                                        modifier = Modifier.fillMaxWidth(),
                                        horizontalArrangement = Arrangement.spacedBy(6.dp)
                                    ) {
                                        val presets = listOf(
                                            1 to "1 (Solo)",
                                            2 to "2 (Duo)",
                                            4 to "4 (Team)",
                                            6 to "6 (Group)",
                                            10 to "10+ (Squad)"
                                        )
                                        presets.forEach { (count, label) ->
                                            val isSelected = memberCount == count
                                            FilterChip(
                                                selected = isSelected,
                                                onClick = {
                                                    memberCount = count
                                                    adultsCount = count
                                                },
                                                label = { Text(label, fontSize = 10.5.sp, fontWeight = if (isSelected) FontWeight.Bold else FontWeight.Normal) },
                                                modifier = Modifier.testTag("member_preset_chip_$count")
                                            )
                                        }
                                    }
                                }
                            }

                            Spacer(modifier = Modifier.height(12.dp))

                            // PRIMARY GUEST DETAILS FORM
                            Surface(
                                shape = RoundedCornerShape(14.dp),
                                color = MaterialTheme.colorScheme.surface,
                                border = BorderStroke(1.dp, MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.5f)),
                                modifier = Modifier.fillMaxWidth()
                            ) {
                                Column(modifier = Modifier.padding(14.dp)) {
                                    Text("2. Primary Registered Contact Details *", fontWeight = FontWeight.Bold, fontSize = 13.5.sp)
                                    Text("Official booking confirmation and access QR token will be issued to this person", fontSize = 11.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                                    Spacer(modifier = Modifier.height(12.dp))

                                    // Full Name
                                    OutlinedTextField(
                                        value = primaryContactName,
                                        onValueChange = {
                                            primaryContactName = it
                                            registrationFieldResponses["full_name"] = it
                                        },
                                        label = { Text("Primary Member Full Name *") },
                                        placeholder = { Text("e.g. Priya Sharma") },
                                        leadingIcon = { Icon(Icons.Default.Person, contentDescription = null) },
                                        modifier = Modifier.fillMaxWidth().testTag("primary_member_name_input"),
                                        singleLine = true
                                    )

                                    Spacer(modifier = Modifier.height(10.dp))

                                    // Phone Number
                                    OutlinedTextField(
                                        value = primaryContactPhone,
                                        onValueChange = {
                                            primaryContactPhone = it
                                            registrationFieldResponses["phone"] = it
                                        },
                                        label = { Text("Mobile / WhatsApp Number *") },
                                        placeholder = { Text("+91 98765 43210") },
                                        leadingIcon = { Icon(Icons.Default.Phone, contentDescription = null) },
                                        keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Phone),
                                        modifier = Modifier.fillMaxWidth().testTag("primary_member_phone_input"),
                                        singleLine = true
                                    )

                                    Spacer(modifier = Modifier.height(10.dp))

                                    // Email Address
                                    OutlinedTextField(
                                        value = primaryContactEmail,
                                        onValueChange = {
                                            primaryContactEmail = it
                                            registrationFieldResponses["email"] = it
                                        },
                                        label = { Text("Email Address (for Invoice & Pass) *") },
                                        placeholder = { Text("priya@example.com") },
                                        leadingIcon = { Icon(Icons.Default.Email, contentDescription = null) },
                                        keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Email),
                                        modifier = Modifier.fillMaxWidth().testTag("primary_member_email_input"),
                                        singleLine = true
                                    )

                                    Spacer(modifier = Modifier.height(10.dp))

                                    // Government ID & KYC
                                    Row(
                                        modifier = Modifier.fillMaxWidth(),
                                        horizontalArrangement = Arrangement.spacedBy(8.dp)
                                    ) {
                                        var idMenuExpanded by remember { mutableStateOf(false) }
                                        val idTypes = listOf("Aadhaar Card", "PAN Card", "Driving License", "Passport", "Member ID")

                                        ExposedDropdownMenuBox(
                                            expanded = idMenuExpanded,
                                            onExpandedChange = { idMenuExpanded = !idMenuExpanded },
                                            modifier = Modifier.weight(1.1f)
                                        ) {
                                            OutlinedTextField(
                                                value = govtIdType,
                                                onValueChange = {},
                                                readOnly = true,
                                                label = { Text("ID Type") },
                                                trailingIcon = { ExposedDropdownMenuDefaults.TrailingIcon(expanded = idMenuExpanded) },
                                                modifier = Modifier.menuAnchor().fillMaxWidth(),
                                                singleLine = true
                                            )
                                            ExposedDropdownMenu(
                                                expanded = idMenuExpanded,
                                                onDismissRequest = { idMenuExpanded = false }
                                            ) {
                                                idTypes.forEach { type ->
                                                    DropdownMenuItem(
                                                        text = { Text(type) },
                                                        onClick = {
                                                            govtIdType = type
                                                            idMenuExpanded = false
                                                        }
                                                    )
                                                }
                                            }
                                        }

                                        OutlinedTextField(
                                            value = govtIdNumber,
                                            onValueChange = {
                                                govtIdNumber = it
                                                registrationFieldResponses["aadhaar_number"] = it
                                                registrationFieldResponses["govt_id_number"] = it
                                            },
                                            label = { Text("ID Number *") },
                                            placeholder = { Text("XXXX-XXXX-9021") },
                                            modifier = Modifier.weight(1.3f).testTag("govt_id_number_input"),
                                            singleLine = true
                                        )
                                    }

                                    Spacer(modifier = Modifier.height(10.dp))

                                    // Emergency Contact
                                    OutlinedTextField(
                                        value = emergencyContact,
                                        onValueChange = {
                                            emergencyContact = it
                                            registrationFieldResponses["emergency_contact"] = it
                                        },
                                        label = { Text("Emergency Contact Number") },
                                        placeholder = { Text("+91 91234 56789") },
                                        keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Phone),
                                        modifier = Modifier.fillMaxWidth().testTag("emergency_contact_input"),
                                        singleLine = true
                                    )
                                }
                            }

                            // ADDITIONAL MEMBERS LIST (WHEN MEMBER COUNT > 1)
                            if (memberCount > 1) {
                                Spacer(modifier = Modifier.height(12.dp))
                                Surface(
                                    shape = RoundedCornerShape(14.dp),
                                    color = MaterialTheme.colorScheme.surface,
                                    border = BorderStroke(1.dp, MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.5f)),
                                    modifier = Modifier.fillMaxWidth()
                                ) {
                                    Column(modifier = Modifier.padding(14.dp)) {
                                        Row(
                                            modifier = Modifier.fillMaxWidth(),
                                            horizontalArrangement = Arrangement.SpaceBetween,
                                            verticalAlignment = Alignment.CenterVertically
                                        ) {
                                            Column {
                                                Text("3. Additional Co-Members / Teammates (${memberCount - 1})", fontWeight = FontWeight.Bold, fontSize = 13.5.sp)
                                                Text("Names of additional guests arriving with you", fontSize = 11.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                                            }
                                            TextButton(
                                                onClick = {
                                                    val sampleNames = listOf("Rahul Varma", "Sneha Reddy", "Arjun Kapoor", "Kavita Rao", "Amit Sharma", "Zoya Khan")
                                                    additionalMemberNames = (0 until (memberCount - 1)).map { idx ->
                                                        sampleNames.getOrElse(idx) { "Guest ${idx + 2}" }
                                                    }
                                                }
                                            ) {
                                                Text("Quick-Fill", fontSize = 11.5.sp)
                                            }
                                        }

                                        Spacer(modifier = Modifier.height(8.dp))

                                        additionalMemberNames.forEachIndexed { index, nameVal ->
                                            OutlinedTextField(
                                                value = nameVal,
                                                onValueChange = { newVal ->
                                                    val updatedList = additionalMemberNames.toMutableList()
                                                    if (index < updatedList.size) {
                                                        updatedList[index] = newVal
                                                        additionalMemberNames = updatedList
                                                    }
                                                },
                                                label = { Text("Member ${index + 2} Full Name") },
                                                placeholder = { Text("e.g. Rahul Varma") },
                                                modifier = Modifier
                                                    .fillMaxWidth()
                                                    .padding(vertical = 4.dp)
                                                    .testTag("additional_member_${index + 2}_input"),
                                                singleLine = true
                                            )
                                        }
                                    }
                                }
                            }

                            // Dynamic Plug-and-Play Registration Fields (if enabled for category)
                            if (isCategoryUnifiedRegEnabled && applicableRegFields.isNotEmpty()) {
                                Spacer(modifier = Modifier.height(12.dp))
                                Surface(
                                    shape = RoundedCornerShape(14.dp),
                                    color = MaterialTheme.colorScheme.surface,
                                    border = BorderStroke(1.dp, MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.5f)),
                                    modifier = Modifier.fillMaxWidth()
                                ) {
                                    Column(modifier = Modifier.padding(14.dp)) {
                                        Text("4. Category Specific Registration Fields", fontWeight = FontWeight.Bold, fontSize = 13.5.sp)
                                        Text("Configured by Venue Admin", fontSize = 11.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                                        Spacer(modifier = Modifier.height(10.dp))

                                        applicableRegFields.forEach { field ->
                                            if (field.key != "full_name" && field.key != "phone" && field.key != "email" && field.key != "aadhaar_number" && field.key != "govt_id_number" && field.key != "emergency_contact") {
                                                val currentValue = registrationFieldResponses[field.key] ?: field.defaultValue
                                                BookingDynamicRegistrationFieldItem(
                                                    field = field,
                                                    value = currentValue,
                                                    onValueChange = { newVal ->
                                                        registrationFieldResponses[field.key] = newVal
                                                    }
                                                )
                                                Spacer(modifier = Modifier.height(8.dp))
                                            }
                                        }
                                    }
                                }
                            }

                            Spacer(modifier = Modifier.height(10.dp))

                            // KYC & Safety Terms Checkbox
                            Row(
                                verticalAlignment = Alignment.CenterVertically,
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .clickable { regIsKycVerified = !regIsKycVerified }
                                    .padding(vertical = 4.dp)
                            ) {
                                Checkbox(
                                    checked = regIsKycVerified,
                                    onCheckedChange = { regIsKycVerified = it },
                                    modifier = Modifier.size(28.dp).testTag("booking_reg_kyc_checkbox")
                                )
                                Spacer(modifier = Modifier.width(8.dp))
                                Text(
                                    text = "I verify that all $memberCount member details are accurate and adhere to venue safety rules.",
                                    fontSize = 11.sp,
                                    color = MaterialTheme.colorScheme.onSurfaceVariant
                                )
                            }

                            // Validation errors notice if any
                            if (registrationValidationErrors.isNotEmpty()) {
                                Spacer(modifier = Modifier.height(8.dp))
                                Surface(
                                    color = MaterialTheme.colorScheme.errorContainer,
                                    shape = RoundedCornerShape(10.dp),
                                    modifier = Modifier.fillMaxWidth()
                                ) {
                                    Column(modifier = Modifier.padding(10.dp)) {
                                        Row(verticalAlignment = Alignment.CenterVertically) {
                                            Icon(Icons.Default.Warning, contentDescription = null, tint = MaterialTheme.colorScheme.onErrorContainer, modifier = Modifier.size(16.dp))
                                            Spacer(modifier = Modifier.width(6.dp))
                                            Text("Please fix the following to register:", fontWeight = FontWeight.Bold, fontSize = 11.5.sp, color = MaterialTheme.colorScheme.onErrorContainer)
                                        }
                                        registrationValidationErrors.forEach { err ->
                                            Text("• $err", fontSize = 11.sp, color = MaterialTheme.colorScheme.onErrorContainer)
                                        }
                                    }
                                }
                            }

                            Spacer(modifier = Modifier.height(12.dp))

                            // Submit & Confirm Registration Button
                            Button(
                                onClick = {
                                    val errors = validateRegistrationForm()
                                    registrationValidationErrors = errors
                                    if (errors.isEmpty()) {
                                        haptic.performHapticFeedback(HapticFeedbackType.LongPress)
                                        isRegistrationConfirmed = true
                                        isEditingRegistrationAfterConfirm = false
                                        Toast.makeText(context, "✓ Registration verified for $memberCount member(s)! Payment section unlocked.", Toast.LENGTH_SHORT).show()
                                    } else {
                                        haptic.performHapticFeedback(HapticFeedbackType.TextHandleMove)
                                    }
                                },
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .height(46.dp)
                                    .testTag("submit_registration_details_btn"),
                                colors = ButtonDefaults.buttonColors(
                                    containerColor = if (areRequiredRegistrationFieldsFilled) Color(0xFF2E7D32) else MaterialTheme.colorScheme.primary
                                ),
                                shape = RoundedCornerShape(12.dp)
                            ) {
                                Icon(Icons.Default.Check, contentDescription = null, modifier = Modifier.size(18.dp))
                                Spacer(modifier = Modifier.width(6.dp))
                                Text(
                                    "Confirm & Register $memberCount Member(s) 🔓",
                                    fontWeight = FontWeight.Bold,
                                    fontSize = 13.5.sp
                                )
                            }
                        }
                    }
                }
            }

            // ====================================================================================
            // STEP 3: PAYMENT SECTION (GATED / LOCKED UNTIL REGISTRATION IS COMPLETE)
            // ====================================================================================
            item {
                if (!isRegistrationConfirmed) {
                    // LOCKED PAYMENT CONTAINER
                    Card(
                        shape = RoundedCornerShape(18.dp),
                        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.5f)),
                        border = BorderStroke(1.dp, MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.6f)),
                        modifier = Modifier
                            .fillMaxWidth()
                            .testTag("locked_payment_section_notice")
                    ) {
                        Column(
                            modifier = Modifier
                                .fillMaxWidth()
                                .padding(20.dp),
                            horizontalAlignment = Alignment.CenterHorizontally
                        ) {
                            Box(
                                modifier = Modifier
                                    .size(54.dp)
                                    .clip(CircleShape)
                                    .background(MaterialTheme.colorScheme.surfaceVariant),
                                contentAlignment = Alignment.Center
                            ) {
                                Icon(
                                    Icons.Default.Lock,
                                    contentDescription = "Locked",
                                    tint = MaterialTheme.colorScheme.onSurfaceVariant,
                                    modifier = Modifier.size(28.dp)
                                )
                            }

                            Spacer(modifier = Modifier.height(10.dp))

                            Text(
                                "Step 3: Payment Section Locked 🔒",
                                fontWeight = FontWeight.Bold,
                                fontSize = 15.sp,
                                color = MaterialTheme.colorScheme.onSurface
                            )

                            Spacer(modifier = Modifier.height(6.dp))

                            Text(
                                text = "Please complete and submit the Guest Registration and Member Count details in Step 2 above. Once registered, all payment methods (UPI, Cards, NetBanking, BMS Wallet, Pay at Venue) will be unlocked and accepted.",
                                fontSize = 12.sp,
                                textAlign = TextAlign.Center,
                                color = MaterialTheme.colorScheme.onSurfaceVariant
                            )

                            Spacer(modifier = Modifier.height(14.dp))

                            OutlinedButton(
                                onClick = {
                                    val errors = validateRegistrationForm()
                                    registrationValidationErrors = errors
                                    if (errors.isEmpty()) {
                                        isRegistrationConfirmed = true
                                        isEditingRegistrationAfterConfirm = false
                                        Toast.makeText(context, "✓ Registration verified! Payment section unlocked.", Toast.LENGTH_SHORT).show()
                                    } else {
                                        Toast.makeText(context, "Please fill required registration fields above first.", Toast.LENGTH_SHORT).show()
                                    }
                                },
                                modifier = Modifier.testTag("prompt_complete_registration_btn")
                            ) {
                                Icon(Icons.Default.VerifiedUser, contentDescription = null, modifier = Modifier.size(16.dp))
                                Spacer(modifier = Modifier.width(6.dp))
                                Text("Complete Step 2 Registration", fontWeight = FontWeight.Bold, fontSize = 12.5.sp)
                            }
                        }
                    }
                } else {
                    // UNLOCKED ACTIVE PAYMENT SECTION
                    Column(verticalArrangement = Arrangement.spacedBy(14.dp)) {
                        // Section Header
                        Card(
                            shape = RoundedCornerShape(14.dp),
                            colors = CardDefaults.cardColors(containerColor = Color(0xFFE8F5E9).copy(alpha = 0.5f)),
                            border = BorderStroke(1.dp, Color(0xFF2E7D32).copy(alpha = 0.3f)),
                            modifier = Modifier.fillMaxWidth()
                        ) {
                            Row(
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .padding(12.dp),
                                verticalAlignment = Alignment.CenterVertically
                            ) {
                                Icon(Icons.Default.CheckCircle, contentDescription = null, tint = Color(0xFF2E7D32), modifier = Modifier.size(20.dp))
                                Spacer(modifier = Modifier.width(8.dp))
                                Column {
                                    Text("Step 3: Payment & Checkout Unlocked", fontWeight = FontWeight.Bold, fontSize = 13.5.sp, color = Color(0xFF1B5E20))
                                    Text("Registration complete for $primaryContactName ($memberCount Members). Select payment option below.", fontSize = 11.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                                }
                            }
                        }

                        // Apply Offers & Promo Code
                        Card(
                            shape = RoundedCornerShape(14.dp),
                            colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface),
                            border = BorderStroke(1.dp, MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.5f)),
                            modifier = Modifier.fillMaxWidth()
                        ) {
                            Column(modifier = Modifier.padding(14.dp)) {
                                Row(
                                    modifier = Modifier.fillMaxWidth(),
                                    horizontalArrangement = Arrangement.SpaceBetween,
                                    verticalAlignment = Alignment.CenterVertically
                                ) {
                                    Text("Apply Offers & Promo Code", fontWeight = FontWeight.Bold, fontSize = 14.5.sp)
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
                        }

                        // Payment Plan Option (Full Payment vs Advance Token)
                        Column {
                            Text("Payment Plan Option", fontWeight = FontWeight.Bold, fontSize = 14.5.sp)
                            Text(
                                text = "Choose to pay in full now or reserve with an advance token",
                                fontSize = 11.5.sp,
                                color = MaterialTheme.colorScheme.onSurfaceVariant
                            )
                            Spacer(modifier = Modifier.height(8.dp))

                            Row(
                                modifier = Modifier.fillMaxWidth(),
                                horizontalArrangement = Arrangement.spacedBy(10.dp)
                            ) {
                                // Full Payment Card
                                Card(
                                    onClick = { isAdvanceTokenSelected = false },
                                    modifier = Modifier
                                        .weight(1f)
                                        .testTag("plan_full_payment"),
                                    shape = RoundedCornerShape(12.dp),
                                    colors = CardDefaults.cardColors(
                                        containerColor = if (!isAdvanceTokenSelected) MaterialTheme.colorScheme.primaryContainer else MaterialTheme.colorScheme.surface
                                    ),
                                    border = if (!isAdvanceTokenSelected) BorderStroke(2.dp, MaterialTheme.colorScheme.primary) else BorderStroke(1.dp, MaterialTheme.colorScheme.outlineVariant)
                                ) {
                                    Column(modifier = Modifier.padding(12.dp)) {
                                        Row(
                                            verticalAlignment = Alignment.CenterVertically,
                                            horizontalArrangement = Arrangement.SpaceBetween,
                                            modifier = Modifier.fillMaxWidth()
                                        ) {
                                            Text("Full Payment", fontWeight = FontWeight.Bold, fontSize = 13.sp)
                                            RadioButton(selected = !isAdvanceTokenSelected, onClick = { isAdvanceTokenSelected = false })
                                        }
                                        Text("100% Upfront", fontSize = 11.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                                        Spacer(modifier = Modifier.height(4.dp))
                                        Text(
                                            "₹${grandTotal.toInt()}",
                                            fontWeight = FontWeight.ExtraBold,
                                            fontSize = 16.sp,
                                            color = MaterialTheme.colorScheme.primary
                                        )
                                        Text("Instant full receipt", fontSize = 10.sp, color = Color(0xFF2E7D32), fontWeight = FontWeight.Medium)
                                    }
                                }

                                // Advance Token Card
                                Card(
                                    onClick = { isAdvanceTokenSelected = true },
                                    modifier = Modifier
                                        .weight(1f)
                                        .testTag("plan_advance_token"),
                                    shape = RoundedCornerShape(12.dp),
                                    colors = CardDefaults.cardColors(
                                        containerColor = if (isAdvanceTokenSelected) MaterialTheme.colorScheme.primaryContainer else MaterialTheme.colorScheme.surface
                                    ),
                                    border = if (isAdvanceTokenSelected) BorderStroke(2.dp, MaterialTheme.colorScheme.primary) else BorderStroke(1.dp, MaterialTheme.colorScheme.outlineVariant)
                                ) {
                                    Column(modifier = Modifier.padding(12.dp)) {
                                        Row(
                                            verticalAlignment = Alignment.CenterVertically,
                                            horizontalArrangement = Arrangement.SpaceBetween,
                                            modifier = Modifier.fillMaxWidth()
                                        ) {
                                            Text("Advance Token", fontWeight = FontWeight.Bold, fontSize = 13.sp)
                                            RadioButton(selected = isAdvanceTokenSelected, onClick = { isAdvanceTokenSelected = true })
                                        }
                                        Text("25% Now to Lock", fontSize = 11.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                                        Spacer(modifier = Modifier.height(4.dp))
                                        Text(
                                            "₹${advanceAmount.toInt()}",
                                            fontWeight = FontWeight.ExtraBold,
                                            fontSize = 16.sp,
                                            color = MaterialTheme.colorScheme.primary
                                        )
                                        Text("₹${balanceDueAtVenue.toInt()} at venue", fontSize = 10.sp, color = Color(0xFFE65100), fontWeight = FontWeight.Bold)
                                    }
                                }
                            }
                        }

                        // Payment Methods
                        Column {
                            Text("Select Payment Mode", fontWeight = FontWeight.Bold, fontSize = 14.5.sp)
                            Text(
                                text = "Fast & secure checkout with 256-bit encryption",
                                fontSize = 11.5.sp,
                                color = MaterialTheme.colorScheme.onSurfaceVariant
                            )
                            Spacer(modifier = Modifier.height(8.dp))

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

                        // Price Breakdown Card
                        Card(
                            modifier = Modifier.fillMaxWidth(),
                            shape = RoundedCornerShape(16.dp),
                            colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.5f))
                        ) {
                            Column(modifier = Modifier.padding(16.dp)) {
                                Text("Price & Reservation Breakdown", fontWeight = FontWeight.Bold, fontSize = 14.sp)
                                Spacer(modifier = Modifier.height(8.dp))
                                Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                                    Text("Registered Members", fontSize = 13.sp)
                                    Text("$memberCount Member(s)", fontSize = 13.sp, fontWeight = FontWeight.SemiBold)
                                }
                                Spacer(modifier = Modifier.height(4.dp))
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
                                    Text("Total Booking Value", fontWeight = FontWeight.SemiBold, fontSize = 14.sp)
                                    Text("₹${grandTotal.toInt()}", fontWeight = FontWeight.Bold, fontSize = 14.sp)
                                }
                                if (isAdvanceTokenSelected && selectedPaymentMode != "VENUE") {
                                    Spacer(modifier = Modifier.height(4.dp))
                                    Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                                        Text("Advance Payable Today (25%)", fontWeight = FontWeight.Bold, fontSize = 14.sp, color = MaterialTheme.colorScheme.primary)
                                        Text("₹${advanceAmount.toInt()}", fontWeight = FontWeight.ExtraBold, fontSize = 15.sp, color = MaterialTheme.colorScheme.primary)
                                    }
                                    Spacer(modifier = Modifier.height(4.dp))
                                    Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                                        Text("Remaining Due on Check-in", fontSize = 13.sp, color = Color(0xFFE65100), fontWeight = FontWeight.SemiBold)
                                        Text("₹${balanceDueAtVenue.toInt()}", fontSize = 13.sp, color = Color(0xFFE65100), fontWeight = FontWeight.Bold)
                                    }
                                } else {
                                    Spacer(modifier = Modifier.height(4.dp))
                                    Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                                        Text("Amount Payable Now", fontWeight = FontWeight.Bold, fontSize = 15.sp)
                                        Text("₹${if (selectedPaymentMode == "VENUE") 0 else grandTotal.toInt()}", fontWeight = FontWeight.ExtraBold, fontSize = 16.sp, color = MaterialTheme.colorScheme.primary)
                                    }
                                }
                            }
                        }
                    }
                }
            }

            item {
                Spacer(modifier = Modifier.height(16.dp))
            }
        }
    }
}

@Composable
private fun StepIndicatorChip(
    stepNumber: String,
    title: String,
    isCompleted: Boolean,
    isActive: Boolean,
    isLocked: Boolean = false,
    modifier: Modifier = Modifier
) {
    val bgColor = when {
        isCompleted -> Color(0xFF2E7D32).copy(alpha = 0.15f)
        isActive -> MaterialTheme.colorScheme.primaryContainer
        isLocked -> MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.5f)
        else -> MaterialTheme.colorScheme.surface
    }
    val contentColor = when {
        isCompleted -> Color(0xFF2E7D32)
        isActive -> MaterialTheme.colorScheme.primary
        isLocked -> MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.5f)
        else -> MaterialTheme.colorScheme.onSurfaceVariant
    }

    Surface(
        shape = RoundedCornerShape(8.dp),
        color = bgColor,
        modifier = modifier.padding(horizontal = 2.dp)
    ) {
        Row(
            modifier = Modifier.padding(horizontal = 6.dp, vertical = 6.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.Center
        ) {
            Box(
                modifier = Modifier
                    .size(16.dp)
                    .clip(CircleShape)
                    .background(contentColor),
                contentAlignment = Alignment.Center
            ) {
                if (isCompleted) {
                    Icon(Icons.Default.Check, contentDescription = null, tint = Color.White, modifier = Modifier.size(10.dp))
                } else if (isLocked) {
                    Icon(Icons.Default.Lock, contentDescription = null, tint = Color.White, modifier = Modifier.size(9.dp))
                } else {
                    Text(stepNumber, fontSize = 9.sp, fontWeight = FontWeight.Bold, color = Color.White)
                }
            }
            Spacer(modifier = Modifier.width(4.dp))
            Text(
                text = title,
                fontSize = 10.sp,
                fontWeight = if (isActive || isCompleted) FontWeight.Bold else FontWeight.Medium,
                color = contentColor,
                maxLines = 1
            )
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

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun BookingDynamicRegistrationFieldItem(
    field: UserRegistrationFieldDefinition,
    value: String,
    onValueChange: (String) -> Unit
) {
    val fieldTag = "booking_reg_${field.key}_input"
    val fieldLabel = "${field.label}${if (field.required) " *" else ""}"

    when (field.fieldType) {
        RegistrationFieldType.DROPDOWN -> {
            var expanded by remember { mutableStateOf(false) }
            ExposedDropdownMenuBox(
                expanded = expanded,
                onExpandedChange = { expanded = !expanded },
                modifier = Modifier.fillMaxWidth()
            ) {
                OutlinedTextField(
                    value = value,
                    onValueChange = {},
                    readOnly = true,
                    label = { Text(fieldLabel) },
                    trailingIcon = { ExposedDropdownMenuDefaults.TrailingIcon(expanded = expanded) },
                    modifier = Modifier
                        .menuAnchor()
                        .fillMaxWidth()
                        .testTag(fieldTag),
                    singleLine = true
                )
                ExposedDropdownMenu(
                    expanded = expanded,
                    onDismissRequest = { expanded = false }
                ) {
                    field.options.forEach { option ->
                        DropdownMenuItem(
                            text = { Text(option) },
                            onClick = {
                                onValueChange(option)
                                expanded = false
                            }
                        )
                    }
                }
            }
        }
        RegistrationFieldType.CHECKBOX -> {
            Row(
                verticalAlignment = Alignment.CenterVertically,
                modifier = Modifier
                    .fillMaxWidth()
                    .clickable {
                        val isChecked = value.equals("true", ignoreCase = true)
                        onValueChange((!isChecked).toString())
                    }
                    .padding(vertical = 4.dp)
            ) {
                Checkbox(
                    checked = value.equals("true", ignoreCase = true),
                    onCheckedChange = { isChecked ->
                        onValueChange(isChecked.toString())
                    },
                    modifier = Modifier.testTag(fieldTag)
                )
                Spacer(modifier = Modifier.width(8.dp))
                Text(
                    text = fieldLabel,
                    fontSize = 13.sp,
                    fontWeight = FontWeight.Medium
                )
            }
        }
        RegistrationFieldType.NUMBER, RegistrationFieldType.PHONE, RegistrationFieldType.PINCODE -> {
            OutlinedTextField(
                value = value,
                onValueChange = onValueChange,
                label = { Text(fieldLabel) },
                placeholder = { if (field.placeholder.isNotBlank()) Text(field.placeholder) },
                modifier = Modifier
                    .fillMaxWidth()
                    .testTag(fieldTag),
                singleLine = true
            )
        }
        RegistrationFieldType.TEXTAREA -> {
            OutlinedTextField(
                value = value,
                onValueChange = onValueChange,
                label = { Text(fieldLabel) },
                placeholder = { if (field.placeholder.isNotBlank()) Text(field.placeholder) },
                modifier = Modifier
                    .fillMaxWidth()
                    .height(84.dp)
                    .testTag(fieldTag),
                maxLines = 3
            )
        }
        else -> {
            // TEXT, EMAIL, DATE_OF_BIRTH, AADHAAR, GOVT_ID, ADDRESS_LINE, LOCATION_HIERARCHY, PHOTO
            OutlinedTextField(
                value = value,
                onValueChange = onValueChange,
                label = { Text(fieldLabel) },
                placeholder = { if (field.placeholder.isNotBlank()) Text(field.placeholder) },
                modifier = Modifier
                    .fillMaxWidth()
                    .testTag(fieldTag),
                singleLine = true
            )
        }
    }
}

