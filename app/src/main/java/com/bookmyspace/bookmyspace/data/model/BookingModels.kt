package com.bookmyspace.bookmyspace.data.model

import com.bookmyspace.bookmyspace.data.model.LocationHierarchy

enum class BookingStatus {
    CONFIRMED,
    PENDING,
    PENDING_OWNER_APPROVAL,
    HELD,
    CANCELLED,
    REJECTED,
    COMPLETED
}

enum class OperationType {
    GET,
    LIST,
    CREATE,
    READ,
    UPDATE,
    DELETE,
    QUERY
}

enum class ClassDeliveryMode(val displayName: String, val shortBadge: String) {
    OFFLINE("Offline in Classroom", "Offline"),
    ONLINE("Live Online Interactive", "Online"),
    HYBRID("Hybrid (Offline + Online)", "Hybrid");

    val label: String get() = displayName
}

enum class DateAvailabilityStatus(val label: String) {
    AVAILABLE("Available"),
    PARTIALLY_AVAILABLE("Filling Fast"),
    FILLING_FAST("Filling Fast"),
    LIMITED("Few Slots Left"),
    SOLD_OUT("Sold Out"),
    FULLY_BOOKED("Fully Booked"),
    MAINTENANCE_BLOCKED("Blocked / Maintenance"),
    CLOSING_SOON("Closing Soon")
}

data class DateAvailabilityInfo(
    val date: String = "",
    val status: DateAvailabilityStatus = DateAvailabilityStatus.AVAILABLE,
    val availableSlotsCount: Int = 8,
    val totalSlotsCount: Int = 10
)

data class Booking(
    val id: String = "",
    val userId: String = "",
    val userName: String = "",
    val userEmail: String = "",
    val userPhone: String = "",
    val venueId: String = "",
    val venueName: String = "",
    val venueCoverUrl: String = "",
    val venueImageUrl: String = "",
    val date: String = "",
    val bookingDate: String = "",
    val startTime: String = "",
    val endTime: String = "",
    val slotLabel: String = "",
    val baseAmount: Double = 0.0,
    val taxAmount: Double = 0.0,
    val discountAmount: Double = 0.0,
    val totalAmount: Double = 0.0,
    val totalPrice: Double = 0.0,
    val couponCode: String = "",
    val paymentId: String = "",
    val status: BookingStatus = BookingStatus.CONFIRMED,
    val paymentStatus: String = "PAID",
    val paymentMethod: String = "UPI",
    val qrCodeToken: String = "",
    val createdAt: Long = System.currentTimeMillis(),
    val guestCount: Int = 1,
    val packageId: String? = null,
    val selectedAddonIds: List<String> = emptyList(),
    val customerNotes: String = "",
    val isPaid: Boolean = true,
    val isCheckedIn: Boolean = false,
    val bookingRef: String = "",
    val isHeld: Boolean = false,
    val holdExpiresAtMillis: Long = 0L,
    val checkInTime: String? = null,
    val isAdvancePayment: Boolean = false,
    val advanceAmountPaid: Double = 0.0,
    val remainingBalanceDue: Double = 0.0,
    val paymentPlan: String = "FULL", // "FULL", "ADVANCE_SPLIT", "PAY_AT_VENUE"
    val registrationDetails: Map<String, String> = emptyMap(),
    val rejectionReason: String? = null,
    val approvedAt: Long? = null,
    val rejectedAt: Long? = null,
    val refundId: String? = null,
    val finalOrderId: String? = null
)

data class InstituteProfile(
    val id: String = "",
    val name: String = "",
    val tagline: String = "",
    val description: String = "",
    val logoUrl: String = "",
    val coverImageUrl: String = "",
    val imageUrls: List<String> = emptyList(),
    val address: String = "",
    val city: String = "Hyderabad",
    val state: String = "Telangana",
    val phone: String = "",
    val whatsapp: String = "",
    val email: String = "",
    val websiteUrl: String = "",
    val category: String = "Academic Coaching",
    val locationHierarchy: LocationHierarchy = LocationHierarchy(),
    val latitude: Double = 15.5057,
    val longitude: Double = 80.0499,
    val categories: List<String> = emptyList(),
    val rating: Double = 4.8,
    val ratingCount: Int = 32,
    val isVerified: Boolean = true,
    val isPublished: Boolean = true,
    val establishedYear: String = "2019",
    val facultyMembers: List<FacultyMember> = emptyList(),
    val amenities: List<String> = emptyList()
)

data class FacultyMember(
    val id: String = "",
    val name: String = "",
    val designation: String = "",
    val qualification: String = "",
    val experienceYears: Int = 5,
    val photoUrl: String = "",
    val bio: String = "",
    val specialties: List<String> = emptyList(),
    val certifications: List<String> = emptyList(),
    val achievements: List<String> = emptyList(),
    val studentsTrainedCount: Int = 850,
    val rating: Double = 4.9,
    val reviewsCount: Int = 42,
    val education: String = "",
    val teachingPhilosophy: String = "",
    val subjectOrSpecialization: String = ""
)

data class InstituteClass(
    val id: String = "",
    val instituteId: String = "",
    val instituteName: String = "",
    val title: String = "",
    val category: String = "",
    val subject: String = "",
    val subjectOrSpecialization: String = "",
    val targetAudience: String = "All Ages",
    val ageGroup: String = "10-18 yrs",
    val skillLevel: String = "All Levels",
    val facultyName: String = "",
    val instructorName: String = "",
    val facultyMemberId: String? = null,
    val facultyPhotoUrl: String = "",
    val facultyDesignation: String = "Senior Faculty",
    val facultyQualification: String = "Certified Master Coach / Specialist",
    val facultyExperienceYears: Int = 8,
    val description: String = "",
    val coverImageUrl: String = "",
    val imageUrls: List<String> = emptyList(),
    val batchType: String = "Regular",
    val isNewBatch: Boolean = false,
    val isUpcomingBatch: Boolean = false,
    val batchStartDate: String = "Starting Soon",
    val batchHighlightTag: String = "",
    val deliveryMode: ClassDeliveryMode = ClassDeliveryMode.OFFLINE,
    val daysOfWeek: List<String> = listOf("Mon", "Wed", "Fri"),
    val startTime: String = "06:00 PM",
    val endTime: String = "07:30 PM",
    val classTimings: String = "06:00 PM - 07:30 PM",
    val durationText: String = "3 Months",
    val location: String = "",
    val city: String = "Hyderabad",
    val locationHierarchy: LocationHierarchy = LocationHierarchy(),
    val feeAmount: Double = 2500.0,
    val monthlyFee: Double = 2500.0,
    val courseFee: Double = 6500.0,
    val discountPercent: Int = 0,
    val feeBillingCycle: String = "month",
    val availableSeats: Int = 12,
    val totalSeats: Int = 25,
    val seatsTotal: Int = 25,
    val seatsAvailable: Int = 12,
    val rating: Double = 4.8,
    val ratingCount: Int = 24,
    val contactPhone: String = "",
    val contactWhatsapp: String = "",
    val isPublished: Boolean = true,
    val enrollmentOpen: Boolean = true,
    val isTodayOngoing: Boolean = false,
    val todayLiveStatus: String = "TODAY BATCH",
    val todayBatchSlot: String = "06:00 PM - 07:30 PM",
    val todayTopic: String = "Interactive Theory & Practical Exercises"
)

data class NotificationItem(
    val id: String = "",
    val title: String = "",
    val message: String = "",
    val timestamp: String = "",
    val isRead: Boolean = false,
    val type: String = "general",
    val actionUrl: String? = null,
    val time: String = timestamp.ifBlank { "Just now" }
) {
    constructor(
        id: String,
        title: String,
        message: String,
        time: String,
        isRead: Boolean,
        type: String
    ) : this(
        id = id,
        title = title,
        message = message,
        timestamp = time,
        isRead = isRead,
        type = type,
        time = time
    )
}

data class AppAuditLog(
    val id: String = "",
    val action: String = "",
    val actorEmail: String = "",
    val targetType: String = "",
    val targetId: String = "",
    val timestamp: String = "",
    val details: String = ""
)
