package com.bookmyspace.bookmyspace.data.invoice

import android.content.Context
import android.content.SharedPreferences
import android.util.Log
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import org.json.JSONObject

/**
 * Repository to persist and manage customizable Tax Invoice settings
 * for both Platform Admin and Space / Venue Owners.
 */
class TaxInvoiceRepository private constructor(context: Context) {

    companion object {
        private const val TAG = "TaxInvoiceRepository"
        private const val PREFS_NAME = "bms_tax_invoice_prefs"
        private const val KEY_ADMIN_INVOICE_SETTINGS = "admin_tax_invoice_settings"
        private const val KEY_VENUE_INVOICE_OVERRIDES = "venue_tax_invoice_overrides"

        @Volatile
        private var instance: TaxInvoiceRepository? = null

        fun getInstance(context: Context): TaxInvoiceRepository {
            return instance ?: synchronized(this) {
                instance ?: TaxInvoiceRepository(context.applicationContext).also { instance = it }
            }
        }
    }

    private val prefs: SharedPreferences = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

    private val _adminSettings = MutableStateFlow(loadAdminSettings())
    val adminSettings: StateFlow<TaxInvoiceSettings> = _adminSettings.asStateFlow()

    private val _venueOverrides = MutableStateFlow<Map<String, VenueTaxInvoiceOverride>>(loadVenueOverrides())
    val venueOverrides: StateFlow<Map<String, VenueTaxInvoiceOverride>> = _venueOverrides.asStateFlow()

    private fun loadAdminSettings(): TaxInvoiceSettings {
        val jsonStr = prefs.getString(KEY_ADMIN_INVOICE_SETTINGS, null) ?: return TaxInvoiceSettings()
        return try {
            val json = JSONObject(jsonStr)
            TaxInvoiceSettings(
                businessLegalName = json.optString("businessLegalName", "BookMySpace Technologies India Pvt Ltd"),
                tradeBrandName = json.optString("tradeBrandName", "BookMySpace"),
                invoiceTitle = json.optString("invoiceTitle", "OFFICIAL TAX INVOICE & RESERVATION RECEIPT"),
                invoiceSubtitle = json.optString("invoiceSubtitle", "ISSUED UNDER GOODS AND SERVICES TAX RULES, 2017"),
                gstin = json.optString("gstin", "36AAACB1234F1Z5"),
                panNumber = json.optString("panNumber", "AAACB1234F"),
                cinNumber = json.optString("cinNumber", "U72900TG2026PTC184920"),
                registeredAddress = json.optString("registeredAddress", "Cyber Towers, Hitec City, Hyderabad - 500081"),
                stateName = json.optString("stateName", "Telangana"),
                stateCode = json.optString("stateCode", "36"),
                supportEmail = json.optString("supportEmail", "support@bookmyspace.app"),
                supportPhone = json.optString("supportPhone", "+91 1800-419-SPACE"),
                defaultSacCode = json.optString("defaultSacCode", "997212"),
                sacDescription = json.optString("sacDescription", "Space Rental & Workstation / Sports Facility Booking"),
                gstTaxRatePercent = json.optDouble("gstTaxRatePercent", 18.0),
                isCgstSgstSplit = json.optBoolean("isCgstSgstSplit", true),
                platformConvenienceFeePercent = json.optDouble("platformConvenienceFeePercent", 0.0),
                invoiceNumberPrefix = json.optString("invoiceNumberPrefix", "INV-"),
                authorizedSignatoryName = json.optString("authorizedSignatoryName", "Narendra Reddy"),
                authorizedSignatoryDesignation = json.optString("authorizedSignatoryDesignation", "Head of Accounts & Finance"),
                showDigitalSignatureSeal = json.optBoolean("showDigitalSignatureSeal", true),
                showQrCheckinPass = json.optBoolean("showQrCheckinPass", true),
                showHmacVerificationBadge = json.optBoolean("showHmacVerificationBadge", true),
                accentColorHex = json.optString("accentColorHex", "#4338CA"),
                termsAndConditions = json.optString("termsAndConditions", "1. This is a computer-generated tax invoice issued under the Goods and Services Tax Rules, 2017.\n2. Cryptographic signature and settlement verified directly via Razorpay API with TLS 1.3 encryption.\n3. Cancellation and rescheduling are governed by BookMySpace Terms of Service."),
                customFooterNote = json.optString("customFooterNote", "BookMySpace Technologies India Pvt. Ltd. | For corporate booking enquiries, write to support@bookmyspace.app")
            )
        } catch (e: Exception) {
            Log.e(TAG, "Error parsing admin invoice settings: ${e.message}", e)
            TaxInvoiceSettings()
        }
    }

    fun updateAdminSettings(settings: TaxInvoiceSettings) {
        try {
            val json = JSONObject().apply {
                put("businessLegalName", settings.businessLegalName)
                put("tradeBrandName", settings.tradeBrandName)
                put("invoiceTitle", settings.invoiceTitle)
                put("invoiceSubtitle", settings.invoiceSubtitle)
                put("gstin", settings.gstin)
                put("panNumber", settings.panNumber)
                put("cinNumber", settings.cinNumber)
                put("registeredAddress", settings.registeredAddress)
                put("stateName", settings.stateName)
                put("stateCode", settings.stateCode)
                put("supportEmail", settings.supportEmail)
                put("supportPhone", settings.supportPhone)
                put("defaultSacCode", settings.defaultSacCode)
                put("sacDescription", settings.sacDescription)
                put("gstTaxRatePercent", settings.gstTaxRatePercent)
                put("isCgstSgstSplit", settings.isCgstSgstSplit)
                put("platformConvenienceFeePercent", settings.platformConvenienceFeePercent)
                put("invoiceNumberPrefix", settings.invoiceNumberPrefix)
                put("authorizedSignatoryName", settings.authorizedSignatoryName)
                put("authorizedSignatoryDesignation", settings.authorizedSignatoryDesignation)
                put("showDigitalSignatureSeal", settings.showDigitalSignatureSeal)
                put("showQrCheckinPass", settings.showQrCheckinPass)
                put("showHmacVerificationBadge", settings.showHmacVerificationBadge)
                put("accentColorHex", settings.accentColorHex)
                put("termsAndConditions", settings.termsAndConditions)
                put("customFooterNote", settings.customFooterNote)
            }
            prefs.edit().putString(KEY_ADMIN_INVOICE_SETTINGS, json.toString()).apply()
            _adminSettings.value = settings
        } catch (e: Exception) {
            Log.e(TAG, "Error saving admin invoice settings: ${e.message}", e)
        }
    }

    private fun loadVenueOverrides(): Map<String, VenueTaxInvoiceOverride> {
        val jsonStr = prefs.getString(KEY_VENUE_INVOICE_OVERRIDES, null) ?: return emptyMap()
        return try {
            val root = JSONObject(jsonStr)
            val result = mutableMapOf<String, VenueTaxInvoiceOverride>()
            val keys = root.keys()
            while (keys.hasNext()) {
                val venueId = keys.next()
                val obj = root.getJSONObject(venueId)
                result[venueId] = VenueTaxInvoiceOverride(
                    venueId = venueId,
                    isEnabled = obj.optBoolean("isEnabled", false),
                    venueBusinessName = obj.optString("venueBusinessName", ""),
                    venueGstin = obj.optString("venueGstin", ""),
                    venuePan = obj.optString("venuePan", ""),
                    venueAddress = obj.optString("venueAddress", ""),
                    venueStateCode = obj.optString("venueStateCode", "36"),
                    venuePhone = obj.optString("venuePhone", ""),
                    venueEmail = obj.optString("venueEmail", ""),
                    venueSacCode = obj.optString("venueSacCode", "997212"),
                    customTerms = obj.optString("customTerms", ""),
                    customFooter = obj.optString("customFooter", ""),
                    signatoryName = obj.optString("signatoryName", ""),
                    signatoryRole = obj.optString("signatoryRole", "Venue General Manager"),
                    accentColorHex = obj.optString("accentColorHex", "#4338CA")
                )
            }
            result
        } catch (e: Exception) {
            Log.e(TAG, "Error loading venue invoice overrides: ${e.message}", e)
            emptyMap()
        }
    }

    fun updateVenueOverride(override: VenueTaxInvoiceOverride) {
        try {
            val updated = _venueOverrides.value.toMutableMap()
            updated[override.venueId] = override
            val root = JSONObject()
            updated.forEach { (venueId, item) ->
                val obj = JSONObject().apply {
                    put("venueId", item.venueId)
                    put("isEnabled", item.isEnabled)
                    put("venueBusinessName", item.venueBusinessName)
                    put("venueGstin", item.venueGstin)
                    put("venuePan", item.venuePan)
                    put("venueAddress", item.venueAddress)
                    put("venueStateCode", item.venueStateCode)
                    put("venuePhone", item.venuePhone)
                    put("venueEmail", item.venueEmail)
                    put("venueSacCode", item.venueSacCode)
                    put("customTerms", item.customTerms)
                    put("customFooter", item.customFooter)
                    put("signatoryName", item.signatoryName)
                    put("signatoryRole", item.signatoryRole)
                    put("accentColorHex", item.accentColorHex)
                }
                root.put(venueId, obj)
            }
            prefs.edit().putString(KEY_VENUE_INVOICE_OVERRIDES, root.toString()).apply()
            _venueOverrides.value = updated
        } catch (e: Exception) {
            Log.e(TAG, "Error saving venue invoice override: ${e.message}", e)
        }
    }

    fun getVenueOverride(venueId: String): VenueTaxInvoiceOverride {
        return _venueOverrides.value[venueId] ?: VenueTaxInvoiceOverride(venueId = venueId)
    }

    fun resetToDefaults() {
        val defaultSettings = TaxInvoiceSettings()
        updateAdminSettings(defaultSettings)
    }

    /**
     * Resolves the effective invoice configuration for a specific venue transaction.
     * Takes into account owner overrides if enabled, else falls back to Admin configuration.
     */
    fun getEffectiveInvoiceConfig(venueId: String?): EffectiveTaxInvoiceDetails {
        val admin = _adminSettings.value
        val venueOverride = if (venueId != null) _venueOverrides.value[venueId] else null

        if (venueOverride != null && venueOverride.isEnabled) {
            return EffectiveTaxInvoiceDetails(
                businessLegalName = venueOverride.venueBusinessName.ifBlank { admin.businessLegalName },
                tradeBrandName = admin.tradeBrandName,
                invoiceTitle = admin.invoiceTitle,
                gstin = venueOverride.venueGstin.ifBlank { admin.gstin },
                panNumber = venueOverride.venuePan.ifBlank { admin.panNumber },
                cinNumber = admin.cinNumber,
                registeredAddress = venueOverride.venueAddress.ifBlank { admin.registeredAddress },
                stateCode = venueOverride.venueStateCode.ifBlank { admin.stateCode },
                supportEmail = venueOverride.venueEmail.ifBlank { admin.supportEmail },
                supportPhone = venueOverride.venuePhone.ifBlank { admin.supportPhone },
                sacCode = venueOverride.venueSacCode.ifBlank { admin.defaultSacCode },
                sacDescription = admin.sacDescription,
                gstTaxRatePercent = admin.gstTaxRatePercent,
                isCgstSgstSplit = admin.isCgstSgstSplit,
                invoiceNumberPrefix = admin.invoiceNumberPrefix,
                authorizedSignatoryName = venueOverride.signatoryName.ifBlank { admin.authorizedSignatoryName },
                authorizedSignatoryDesignation = venueOverride.signatoryRole.ifBlank { admin.authorizedSignatoryDesignation },
                showDigitalSignatureSeal = admin.showDigitalSignatureSeal,
                showQrCheckinPass = admin.showQrCheckinPass,
                showHmacVerificationBadge = admin.showHmacVerificationBadge,
                accentColorHex = venueOverride.accentColorHex.ifBlank { admin.accentColorHex },
                termsAndConditions = venueOverride.customTerms.ifBlank { admin.termsAndConditions },
                footerNote = venueOverride.customFooter.ifBlank { admin.customFooterNote },
                isVenueCustomized = true
            )
        }

        return EffectiveTaxInvoiceDetails(
            businessLegalName = admin.businessLegalName,
            tradeBrandName = admin.tradeBrandName,
            invoiceTitle = admin.invoiceTitle,
            gstin = admin.gstin,
            panNumber = admin.panNumber,
            cinNumber = admin.cinNumber,
            registeredAddress = admin.registeredAddress,
            stateCode = admin.stateCode,
            supportEmail = admin.supportEmail,
            supportPhone = admin.supportPhone,
            sacCode = admin.defaultSacCode,
            sacDescription = admin.sacDescription,
            gstTaxRatePercent = admin.gstTaxRatePercent,
            isCgstSgstSplit = admin.isCgstSgstSplit,
            invoiceNumberPrefix = admin.invoiceNumberPrefix,
            authorizedSignatoryName = admin.authorizedSignatoryName,
            authorizedSignatoryDesignation = admin.authorizedSignatoryDesignation,
            showDigitalSignatureSeal = admin.showDigitalSignatureSeal,
            showQrCheckinPass = admin.showQrCheckinPass,
            showHmacVerificationBadge = admin.showHmacVerificationBadge,
            accentColorHex = admin.accentColorHex,
            termsAndConditions = admin.termsAndConditions,
            footerNote = admin.customFooterNote,
            isVenueCustomized = false
        )
    }
}
