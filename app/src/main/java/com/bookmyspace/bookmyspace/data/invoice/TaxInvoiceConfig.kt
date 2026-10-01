package com.bookmyspace.bookmyspace.data.invoice

/**
 * Data model for global Admin Tax Invoice Settings
 */
data class TaxInvoiceSettings(
    val businessLegalName: String = "BookMySpace Technologies India Pvt Ltd",
    val tradeBrandName: String = "BookMySpace",
    val invoiceTitle: String = "OFFICIAL TAX INVOICE & RESERVATION RECEIPT",
    val invoiceSubtitle: String = "ISSUED UNDER GOODS AND SERVICES TAX RULES, 2017",
    val gstin: String = "36AAACB1234F1Z5",
    val panNumber: String = "AAACB1234F",
    val cinNumber: String = "U72900TG2026PTC184920",
    val registeredAddress: String = "Cyber Towers, Hitec City, Hyderabad - 500081",
    val stateName: String = "Telangana",
    val stateCode: String = "36",
    val supportEmail: String = "support@bookmyspace.app",
    val supportPhone: String = "+91 1800-419-SPACE",
    val defaultSacCode: String = "997212",
    val sacDescription: String = "Space Rental & Workstation / Sports Facility Booking",
    val gstTaxRatePercent: Double = 18.0,
    val isCgstSgstSplit: Boolean = true,
    val platformConvenienceFeePercent: Double = 0.0,
    val invoiceNumberPrefix: String = "INV-",
    val authorizedSignatoryName: String = "Narendra Reddy",
    val authorizedSignatoryDesignation: String = "Head of Accounts & Finance",
    val showDigitalSignatureSeal: Boolean = true,
    val showQrCheckinPass: Boolean = true,
    val showHmacVerificationBadge: Boolean = true,
    val accentColorHex: String = "#4338CA", // Indigo 700
    val termsAndConditions: String = "1. This is a computer-generated tax invoice issued under the Goods and Services Tax Rules, 2017.\n2. Cryptographic signature and settlement verified directly via Razorpay API with TLS 1.3 encryption.\n3. Cancellation and rescheduling are governed by BookMySpace Terms of Service.",
    val customFooterNote: String = "BookMySpace Technologies India Pvt. Ltd. | For corporate booking enquiries, write to support@bookmyspace.app"
)

/**
 * Data model for per-venue Owner overrides on Tax Invoice
 */
data class VenueTaxInvoiceOverride(
    val venueId: String,
    val isEnabled: Boolean = false,
    val venueBusinessName: String = "",
    val venueGstin: String = "",
    val venuePan: String = "",
    val venueAddress: String = "",
    val venueStateCode: String = "36",
    val venuePhone: String = "",
    val venueEmail: String = "",
    val venueSacCode: String = "997212",
    val customTerms: String = "",
    val customFooter: String = "",
    val signatoryName: String = "",
    val signatoryRole: String = "Venue General Manager",
    val accentColorHex: String = "#4338CA"
)

/**
 * Resolved effective tax invoice details for rendering invoice PDF or summary modal
 */
data class EffectiveTaxInvoiceDetails(
    val businessLegalName: String,
    val tradeBrandName: String,
    val invoiceTitle: String,
    val gstin: String,
    val panNumber: String,
    val cinNumber: String,
    val registeredAddress: String,
    val stateCode: String,
    val supportEmail: String,
    val supportPhone: String,
    val sacCode: String,
    val sacDescription: String,
    val gstTaxRatePercent: Double,
    val isCgstSgstSplit: Boolean,
    val invoiceNumberPrefix: String,
    val authorizedSignatoryName: String,
    val authorizedSignatoryDesignation: String,
    val showDigitalSignatureSeal: Boolean,
    val showQrCheckinPass: Boolean,
    val showHmacVerificationBadge: Boolean,
    val accentColorHex: String,
    val termsAndConditions: String,
    val footerNote: String,
    val isVenueCustomized: Boolean
)
