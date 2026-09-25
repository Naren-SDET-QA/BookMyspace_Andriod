package com.bookmyspace.bookmyspace.data.model

/**
 * Target module to which a user registration field applies.
 */
enum class RegistrationTargetModule(val code: String, val displayName: String, val description: String) {
    ALL("all", "All User Types", "Applicable to all registrations across all modules"),
    CUSTOMER("customer", "Customer / Member", "Regular booking customers & members"),
    VENUE_OWNER("venue_owner", "Venue & Space Owner", "Property, court, and hall owners / hosts"),
    INSTITUTE_STUDENT("institute_student", "Institute Student / Coach", "Academy students, trainees & coaches"),
    EVENT_ATTENDEE("event_attendee", "Event / Tournament Attendee", "Tournament & workshop participants");

    companion object {
        fun fromCode(code: String): RegistrationTargetModule {
            return entries.find { it.code.equals(code, ignoreCase = true) } ?: ALL
        }
    }
}

/**
 * Category grouping for registration fields to create clean sectioned forms.
 */
enum class RegistrationFieldCategory(val displayName: String, val iconName: String) {
    PERSONAL("Personal Information", "Person"),
    IDENTITY_KYC("Government ID & KYC", "Badge"),
    ADDRESS("Address & Location", "LocationOn"),
    PROFESSIONAL_BUSINESS("Business & Academy Details", "Business"),
    CUSTOM("Custom & Additional Fields", "Extension")
}

/**
 * Data input types supported for configurable user registration fields.
 */
enum class RegistrationFieldType(val displayName: String, val hasOptions: Boolean = false) {
    PHOTO("Profile Photo / Selfie", false),
    TEXT("Single Line Text", false),
    PHONE("Mobile / WhatsApp Number", false),
    EMAIL("Email Address", false),
    AADHAAR("Aadhaar Number (12 Digits)", false),
    GOVT_ID("Govt ID / PAN / Driving License", false),
    ADDRESS_LINE("Street / House / Building Address", false),
    LOCATION_HIERARCHY("Location Hierarchy (Country → State → City → Area)", false),
    PINCODE("Postal PIN Code (6 Digits)", false),
    DATE_OF_BIRTH("Date of Birth", false),
    DROPDOWN("Dropdown Selection", true),
    RADIO_GROUP("Radio Options", true),
    CHECKBOX("Toggle / Agreement Checkbox", false),
    NUMBER("Numeric Input", false),
    TEXTAREA("Multi-line Text Area", false)
}

/**
 * Centralized dynamic user registration field definition.
 */
data class UserRegistrationFieldDefinition(
    val id: String,
    val key: String, // Internal unique identifier (e.g., "photo_url", "full_name", "aadhaar_number", "address_line_1")
    val label: String, // UI Display label (e.g., "Full Name (as per Govt ID)", "Aadhaar Card Number")
    val fieldType: RegistrationFieldType,
    val category: RegistrationFieldCategory = RegistrationFieldCategory.PERSONAL,
    val targetModule: RegistrationTargetModule = RegistrationTargetModule.ALL,
    val required: Boolean = false,
    val isEnabled: Boolean = true,
    val placeholder: String = "",
    val helpText: String = "",
    val defaultValue: String = "",
    val options: List<String> = emptyList(), // For DROPDOWN and RADIO_GROUP
    val displayOrder: Int = 0,
    val isSystemStandard: Boolean = false, // Built-in standard fields cannot be deleted but can be toggled
    val validationRegex: String = "",
    val createdAt: Long = System.currentTimeMillis()
)

/**
 * Unified user registration & profile data including dynamic custom fields.
 */
data class UserProfileData(
    val userId: String = "",
    val fullName: String = "",
    val email: String = "",
    val phone: String = "",
    val photoUrl: String = "",
    val aadhaarNumber: String = "",
    val govtIdType: String = "Aadhaar",
    val govtIdNumber: String = "",
    val addressLine1: String = "",
    val addressLine2: String = "",
    val pincode: String = "",
    val locationHierarchy: LocationHierarchy? = null,
    val gender: String = "Not Specified",
    val dob: String = "",
    val emergencyContact: String = "",
    val organizationName: String = "",
    val gstin: String = "",
    val role: UserRole = UserRole.USER,
    val targetModule: RegistrationTargetModule = RegistrationTargetModule.CUSTOMER,
    val customFields: Map<String, String> = emptyMap(),
    val isKycVerified: Boolean = false,
    val registeredAt: Long = System.currentTimeMillis()
)
