package com.bookmyspace.bookmyspace.ui.screens

import android.content.Context
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
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.bookmyspace.bookmyspace.data.auth.UserRoleProvider
import com.bookmyspace.bookmyspace.data.invoice.TaxInvoiceRepository
import com.bookmyspace.bookmyspace.data.invoice.TaxInvoiceSettings
import com.bookmyspace.bookmyspace.data.invoice.VenueTaxInvoiceOverride
import com.bookmyspace.bookmyspace.data.local.PaymentTransactionEntity
import com.bookmyspace.bookmyspace.data.model.UserRole
import com.bookmyspace.bookmyspace.data.model.Venue
import com.bookmyspace.bookmyspace.util.PdfInvoiceGenerator

enum class TaxInvoiceScope {
    PLATFORM_ADMIN,
    VENUE_OWNER
}

private val ACCENT_PALETTE = listOf(
    "#4338CA" to "Indigo",
    "#1D4ED8" to "Royal Blue",
    "#047857" to "Emerald",
    "#7C3AED" to "Purple",
    "#B91C1C" to "Crimson",
    "#0F172A" to "Slate Dark"
)

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun TaxInvoiceCustomizerTab(
    venues: List<Venue>,
    selectedVenueId: String? = null,
    modifier: Modifier = Modifier
) {
    val context = LocalContext.current
    val invoiceRepo = remember { TaxInvoiceRepository.getInstance(context) }
    val adminSettings by invoiceRepo.adminSettings.collectAsState()
    val venueOverrides by invoiceRepo.venueOverrides.collectAsState()
    val currentRole by UserRoleProvider.role.collectAsState()

    var activeScope by remember {
        mutableStateOf(if (currentRole == UserRole.ADMIN) TaxInvoiceScope.PLATFORM_ADMIN else TaxInvoiceScope.VENUE_OWNER)
    }

    var selectedVenue by remember(venues, selectedVenueId) {
        mutableStateOf(venues.firstOrNull { it.id == selectedVenueId } ?: venues.firstOrNull())
    }

    // Editable state for Admin
    var editLegalName by remember(adminSettings) { mutableStateOf(adminSettings.businessLegalName) }
    var editBrandName by remember(adminSettings) { mutableStateOf(adminSettings.tradeBrandName) }
    var editInvoiceTitle by remember(adminSettings) { mutableStateOf(adminSettings.invoiceTitle) }
    var editGstin by remember(adminSettings) { mutableStateOf(adminSettings.gstin) }
    var editPan by remember(adminSettings) { mutableStateOf(adminSettings.panNumber) }
    var editCin by remember(adminSettings) { mutableStateOf(adminSettings.cinNumber) }
    var editAddress by remember(adminSettings) { mutableStateOf(adminSettings.registeredAddress) }
    var editStateCode by remember(adminSettings) { mutableStateOf(adminSettings.stateCode) }
    var editEmail by remember(adminSettings) { mutableStateOf(adminSettings.supportEmail) }
    var editPhone by remember(adminSettings) { mutableStateOf(adminSettings.supportPhone) }
    var editSacCode by remember(adminSettings) { mutableStateOf(adminSettings.defaultSacCode) }
    var editSacDesc by remember(adminSettings) { mutableStateOf(adminSettings.sacDescription) }
    var editTaxRate by remember(adminSettings) { mutableStateOf(adminSettings.gstTaxRatePercent.toString()) }
    var editCgstSplit by remember(adminSettings) { mutableStateOf(adminSettings.isCgstSgstSplit) }
    var editInvoicePrefix by remember(adminSettings) { mutableStateOf(adminSettings.invoiceNumberPrefix) }
    var editSignatoryName by remember(adminSettings) { mutableStateOf(adminSettings.authorizedSignatoryName) }
    var editSignatoryRole by remember(adminSettings) { mutableStateOf(adminSettings.authorizedSignatoryDesignation) }
    var editShowSeal by remember(adminSettings) { mutableStateOf(adminSettings.showDigitalSignatureSeal) }
    var editShowQr by remember(adminSettings) { mutableStateOf(adminSettings.showQrCheckinPass) }
    var editShowHmac by remember(adminSettings) { mutableStateOf(adminSettings.showHmacVerificationBadge) }
    var editAccentColor by remember(adminSettings) { mutableStateOf(adminSettings.accentColorHex) }
    var editTerms by remember(adminSettings) { mutableStateOf(adminSettings.termsAndConditions) }
    var editFooter by remember(adminSettings) { mutableStateOf(adminSettings.customFooterNote) }

    // Editable state for Venue Owner
    val currentVenueOverride = remember(venueOverrides, selectedVenue) {
        selectedVenue?.let { invoiceRepo.getVenueOverride(it.id) } ?: VenueTaxInvoiceOverride(venueId = "")
    }

    var venueOverrideEnabled by remember(currentVenueOverride) { mutableStateOf(currentVenueOverride.isEnabled) }
    var venueLegalName by remember(currentVenueOverride, selectedVenue) {
        mutableStateOf(currentVenueOverride.venueBusinessName.ifBlank { selectedVenue?.name ?: "" })
    }
    var venueGstin by remember(currentVenueOverride) { mutableStateOf(currentVenueOverride.venueGstin) }
    var venuePan by remember(currentVenueOverride) { mutableStateOf(currentVenueOverride.venuePan) }
    var venueAddress by remember(currentVenueOverride, selectedVenue) {
        mutableStateOf(currentVenueOverride.venueAddress.ifBlank { 
            val addr = selectedVenue?.addressLine1 ?: ""
            val city = selectedVenue?.city ?: ""
            if (addr.isNotBlank() && city.isNotBlank()) "$addr, $city" else addr.ifBlank { city }
        })
    }
    var venueStateCode by remember(currentVenueOverride) { mutableStateOf(currentVenueOverride.venueStateCode) }
    var venuePhone by remember(currentVenueOverride, selectedVenue) {
        mutableStateOf(currentVenueOverride.venuePhone.ifBlank { selectedVenue?.contactPhone ?: "" })
    }
    var venueEmail by remember(currentVenueOverride) {
        mutableStateOf(currentVenueOverride.venueEmail)
    }
    var venueSacCode by remember(currentVenueOverride) { mutableStateOf(currentVenueOverride.venueSacCode) }
    var venueSignatoryName by remember(currentVenueOverride) { mutableStateOf(currentVenueOverride.signatoryName) }
    var venueSignatoryRole by remember(currentVenueOverride) { mutableStateOf(currentVenueOverride.signatoryRole) }
    var venueCustomTerms by remember(currentVenueOverride) { mutableStateOf(currentVenueOverride.customTerms) }
    var venueCustomFooter by remember(currentVenueOverride) { mutableStateOf(currentVenueOverride.customFooter) }
    var venueAccentColor by remember(currentVenueOverride) { mutableStateOf(currentVenueOverride.accentColorHex) }

    LazyColumn(
        modifier = modifier
            .fillMaxSize()
            .padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp)
    ) {
        // Top Header and Scope Switcher
        item {
            Card(
                shape = RoundedCornerShape(16.dp),
                colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.5f)),
                border = BorderStroke(1.dp, MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.5f))
            ) {
                Column(modifier = Modifier.padding(16.dp)) {
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.SpaceBetween,
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            Icon(
                                Icons.Default.ReceiptLong,
                                contentDescription = null,
                                tint = MaterialTheme.colorScheme.primary,
                                modifier = Modifier.size(24.dp)
                            )
                            Spacer(modifier = Modifier.width(10.dp))
                            Column {
                                Text("Tax Invoice Customizer", fontWeight = FontWeight.Bold, fontSize = 16.sp)
                                Text("Edit GSTIN, legal entities, SAC codes, and branding", fontSize = 11.5.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                            }
                        }
                    }

                    Spacer(modifier = Modifier.height(14.dp))

                    // Scope Switcher Pills (Admin Master vs Venue Owner)
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .background(MaterialTheme.colorScheme.surface, RoundedCornerShape(12.dp))
                            .padding(4.dp),
                        horizontalArrangement = Arrangement.spacedBy(6.dp)
                    ) {
                        Surface(
                            modifier = Modifier
                                .weight(1f)
                                .clickable { activeScope = TaxInvoiceScope.PLATFORM_ADMIN }
                                .testTag("invoice_scope_admin_btn"),
                            shape = RoundedCornerShape(10.dp),
                            color = if (activeScope == TaxInvoiceScope.PLATFORM_ADMIN) MaterialTheme.colorScheme.primary else Color.Transparent
                        ) {
                            Row(
                                modifier = Modifier.padding(vertical = 8.dp),
                                horizontalArrangement = Arrangement.Center,
                                verticalAlignment = Alignment.CenterVertically
                            ) {
                                Icon(
                                    Icons.Default.AdminPanelSettings,
                                    contentDescription = null,
                                    tint = if (activeScope == TaxInvoiceScope.PLATFORM_ADMIN) Color.White else MaterialTheme.colorScheme.onSurfaceVariant,
                                    modifier = Modifier.size(16.dp)
                                )
                                Spacer(modifier = Modifier.width(6.dp))
                                Text(
                                    "Platform Admin",
                                    fontSize = 12.sp,
                                    fontWeight = FontWeight.Bold,
                                    color = if (activeScope == TaxInvoiceScope.PLATFORM_ADMIN) Color.White else MaterialTheme.colorScheme.onSurfaceVariant
                                )
                            }
                        }

                        Surface(
                            modifier = Modifier
                                .weight(1f)
                                .clickable { activeScope = TaxInvoiceScope.VENUE_OWNER }
                                .testTag("invoice_scope_venue_btn"),
                            shape = RoundedCornerShape(10.dp),
                            color = if (activeScope == TaxInvoiceScope.VENUE_OWNER) MaterialTheme.colorScheme.primary else Color.Transparent
                        ) {
                            Row(
                                modifier = Modifier.padding(vertical = 8.dp),
                                horizontalArrangement = Arrangement.Center,
                                verticalAlignment = Alignment.CenterVertically
                            ) {
                                Icon(
                                    Icons.Default.Storefront,
                                    contentDescription = null,
                                    tint = if (activeScope == TaxInvoiceScope.VENUE_OWNER) Color.White else MaterialTheme.colorScheme.onSurfaceVariant,
                                    modifier = Modifier.size(16.dp)
                                )
                                Spacer(modifier = Modifier.width(6.dp))
                                Text(
                                    "Venue Owner",
                                    fontSize = 12.sp,
                                    fontWeight = FontWeight.Bold,
                                    color = if (activeScope == TaxInvoiceScope.VENUE_OWNER) Color.White else MaterialTheme.colorScheme.onSurfaceVariant
                                )
                            }
                        }
                    }
                }
            }
        }

        if (activeScope == TaxInvoiceScope.PLATFORM_ADMIN) {
            // ADMIN CONFIGURATION SECTION
            item {
                Card(
                    shape = RoundedCornerShape(16.dp),
                    colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface),
                    border = BorderStroke(1.dp, MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.5f))
                ) {
                    Column(modifier = Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
                        Text("1. Legal Entity & Brand Header", fontWeight = FontWeight.Bold, fontSize = 14.sp, color = MaterialTheme.colorScheme.primary)

                        OutlinedTextField(
                            value = editLegalName,
                            onValueChange = { editLegalName = it },
                            label = { Text("Business Legal Name (Registered)") },
                            modifier = Modifier.fillMaxWidth().testTag("admin_legal_name_input"),
                            singleLine = true
                        )

                        Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                            OutlinedTextField(
                                value = editBrandName,
                                onValueChange = { editBrandName = it },
                                label = { Text("Brand / Trade Name") },
                                modifier = Modifier.weight(1f).testTag("admin_brand_name_input"),
                                singleLine = true
                            )
                            OutlinedTextField(
                                value = editInvoicePrefix,
                                onValueChange = { editInvoicePrefix = it },
                                label = { Text("Invoice Prefix") },
                                modifier = Modifier.weight(0.7f).testTag("admin_prefix_input"),
                                singleLine = true
                            )
                        }

                        OutlinedTextField(
                            value = editInvoiceTitle,
                            onValueChange = { editInvoiceTitle = it },
                            label = { Text("Invoice Header Title") },
                            modifier = Modifier.fillMaxWidth().testTag("admin_title_input"),
                            singleLine = true
                        )
                    }
                }
            }

            item {
                Card(
                    shape = RoundedCornerShape(16.dp),
                    colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface),
                    border = BorderStroke(1.dp, MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.5f))
                ) {
                    Column(modifier = Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
                        Text("2. GSTIN & Statutory Compliance", fontWeight = FontWeight.Bold, fontSize = 14.sp, color = MaterialTheme.colorScheme.primary)

                        OutlinedTextField(
                            value = editGstin,
                            onValueChange = { editGstin = it.uppercase() },
                            label = { Text("Platform GSTIN (15 Digits)") },
                            modifier = Modifier.fillMaxWidth().testTag("admin_gstin_input"),
                            singleLine = true
                        )

                        Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                            OutlinedTextField(
                                value = editPan,
                                onValueChange = { editPan = it.uppercase() },
                                label = { Text("Company PAN") },
                                modifier = Modifier.weight(1f).testTag("admin_pan_input"),
                                singleLine = true
                            )
                            OutlinedTextField(
                                value = editCin,
                                onValueChange = { editCin = it.uppercase() },
                                label = { Text("CIN Number") },
                                modifier = Modifier.weight(1f).testTag("admin_cin_input"),
                                singleLine = true
                            )
                        }

                        OutlinedTextField(
                            value = editAddress,
                            onValueChange = { editAddress = it },
                            label = { Text("Registered Business Address") },
                            modifier = Modifier.fillMaxWidth().testTag("admin_address_input"),
                            maxLines = 2
                        )

                        Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                            OutlinedTextField(
                                value = editEmail,
                                onValueChange = { editEmail = it },
                                label = { Text("Support Email") },
                                modifier = Modifier.weight(1f).testTag("admin_email_input"),
                                singleLine = true
                            )
                            OutlinedTextField(
                                value = editPhone,
                                onValueChange = { editPhone = it },
                                label = { Text("Support Phone") },
                                modifier = Modifier.weight(1f).testTag("admin_phone_input"),
                                singleLine = true
                            )
                        }
                    }
                }
            }

            item {
                Card(
                    shape = RoundedCornerShape(16.dp),
                    colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface),
                    border = BorderStroke(1.dp, MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.5f))
                ) {
                    Column(modifier = Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
                        Text("3. SAC Code & GST Tax Split", fontWeight = FontWeight.Bold, fontSize = 14.sp, color = MaterialTheme.colorScheme.primary)

                        Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                            OutlinedTextField(
                                value = editSacCode,
                                onValueChange = { editSacCode = it },
                                label = { Text("Default SAC / HSN Code") },
                                modifier = Modifier.weight(1f).testTag("admin_sac_code_input"),
                                singleLine = true
                            )
                            OutlinedTextField(
                                value = editTaxRate,
                                onValueChange = { editTaxRate = it },
                                label = { Text("GST Rate (%)") },
                                modifier = Modifier.weight(0.7f).testTag("admin_tax_rate_input"),
                                singleLine = true
                            )
                        }

                        OutlinedTextField(
                            value = editSacDesc,
                            onValueChange = { editSacDesc = it },
                            label = { Text("SAC Service Description") },
                            modifier = Modifier.fillMaxWidth().testTag("admin_sac_desc_input"),
                            singleLine = true
                        )

                        Row(
                            modifier = Modifier.fillMaxWidth(),
                            horizontalArrangement = Arrangement.SpaceBetween,
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            Column(modifier = Modifier.weight(1f)) {
                                Text("Intra-State GST Split (CGST 50% + SGST 50%)", fontSize = 12.5.sp, fontWeight = FontWeight.Medium)
                                Text("Split GST evenly between CGST and SGST on invoice", fontSize = 11.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                            }
                            Switch(
                                checked = editCgstSplit,
                                onCheckedChange = { editCgstSplit = it },
                                modifier = Modifier.testTag("admin_cgst_split_switch")
                            )
                        }
                    }
                }
            }

            item {
                Card(
                    shape = RoundedCornerShape(16.dp),
                    colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface),
                    border = BorderStroke(1.dp, MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.5f))
                ) {
                    Column(modifier = Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
                        Text("4. Signatory, Security Seals & Branding", fontWeight = FontWeight.Bold, fontSize = 14.sp, color = MaterialTheme.colorScheme.primary)

                        Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                            OutlinedTextField(
                                value = editSignatoryName,
                                onValueChange = { editSignatoryName = it },
                                label = { Text("Signatory Name") },
                                modifier = Modifier.weight(1f).testTag("admin_signatory_name_input"),
                                singleLine = true
                            )
                            OutlinedTextField(
                                value = editSignatoryRole,
                                onValueChange = { editSignatoryRole = it },
                                label = { Text("Designation") },
                                modifier = Modifier.weight(1f).testTag("admin_signatory_role_input"),
                                singleLine = true
                            )
                        }

                        Row(
                            modifier = Modifier.fillMaxWidth(),
                            horizontalArrangement = Arrangement.SpaceBetween,
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            Text("Digital Signature Seal Stamp", fontSize = 12.5.sp)
                            Switch(
                                checked = editShowSeal,
                                onCheckedChange = { editShowSeal = it },
                                modifier = Modifier.testTag("admin_seal_switch")
                            )
                        }

                        Row(
                            modifier = Modifier.fillMaxWidth(),
                            horizontalArrangement = Arrangement.SpaceBetween,
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            Text("QR Code Check-in Pass Matrix", fontSize = 12.5.sp)
                            Switch(
                                checked = editShowQr,
                                onCheckedChange = { editShowQr = it },
                                modifier = Modifier.testTag("admin_qr_switch")
                            )
                        }

                        Row(
                            modifier = Modifier.fillMaxWidth(),
                            horizontalArrangement = Arrangement.SpaceBetween,
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            Text("HMAC-SHA256 Cryptographic Verification Badge", fontSize = 12.5.sp)
                            Switch(
                                checked = editShowHmac,
                                onCheckedChange = { editShowHmac = it },
                                modifier = Modifier.testTag("admin_hmac_switch")
                            )
                        }

                        Text("Invoice Accent Color Theme:", fontSize = 12.sp, fontWeight = FontWeight.SemiBold)
                        LazyRow(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                            items(ACCENT_PALETTE) { (hex, name) ->
                                val isSelected = editAccentColor.equals(hex, ignoreCase = true)
                                val colorVal = try { Color(android.graphics.Color.parseColor(hex)) } catch (e: Exception) { Color(0xFF4338CA) }
                                Surface(
                                    modifier = Modifier
                                        .size(36.dp)
                                        .clickable { editAccentColor = hex },
                                    shape = CircleShape,
                                    color = colorVal,
                                    border = BorderStroke(if (isSelected) 3.dp else 1.dp, if (isSelected) MaterialTheme.colorScheme.onSurface else Color.LightGray)
                                ) {
                                    if (isSelected) {
                                        Box(contentAlignment = Alignment.Center) {
                                            Icon(Icons.Default.Check, contentDescription = name, tint = Color.White, modifier = Modifier.size(18.dp))
                                        }
                                    }
                                }
                            }
                        }

                        OutlinedTextField(
                            value = editTerms,
                            onValueChange = { editTerms = it },
                            label = { Text("Custom Terms & Conditions (PDF Footer)") },
                            modifier = Modifier.fillMaxWidth().testTag("admin_terms_input"),
                            minLines = 3,
                            maxLines = 5
                        )

                        OutlinedTextField(
                            value = editFooter,
                            onValueChange = { editFooter = it },
                            label = { Text("Custom Bottom Disclaimer Note") },
                            modifier = Modifier.fillMaxWidth().testTag("admin_footer_input"),
                            singleLine = true
                        )
                    }
                }
            }

            // Save & Preview Admin Buttons
            item {
                Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                    Button(
                        onClick = {
                            val rateVal = editTaxRate.toDoubleOrNull() ?: 18.0
                            val updated = adminSettings.copy(
                                businessLegalName = editLegalName.trim(),
                                tradeBrandName = editBrandName.trim(),
                                invoiceTitle = editInvoiceTitle.trim(),
                                gstin = editGstin.trim(),
                                panNumber = editPan.trim(),
                                cinNumber = editCin.trim(),
                                registeredAddress = editAddress.trim(),
                                stateCode = editStateCode.trim(),
                                supportEmail = editEmail.trim(),
                                supportPhone = editPhone.trim(),
                                defaultSacCode = editSacCode.trim(),
                                sacDescription = editSacDesc.trim(),
                                gstTaxRatePercent = rateVal,
                                isCgstSgstSplit = editCgstSplit,
                                invoiceNumberPrefix = editInvoicePrefix.trim(),
                                authorizedSignatoryName = editSignatoryName.trim(),
                                authorizedSignatoryDesignation = editSignatoryRole.trim(),
                                showDigitalSignatureSeal = editShowSeal,
                                showQrCheckinPass = editShowQr,
                                showHmacVerificationBadge = editShowHmac,
                                accentColorHex = editAccentColor,
                                termsAndConditions = editTerms.trim(),
                                customFooterNote = editFooter.trim()
                            )
                            invoiceRepo.updateAdminSettings(updated)
                            Toast.makeText(context, "Admin Tax Invoice Configuration Saved! 💾", Toast.LENGTH_SHORT).show()
                        },
                        modifier = Modifier.weight(1.2f).height(48.dp).testTag("save_admin_invoice_config_btn"),
                        shape = RoundedCornerShape(12.dp)
                    ) {
                        Icon(Icons.Default.Save, contentDescription = null, modifier = Modifier.size(18.dp))
                        Spacer(modifier = Modifier.width(6.dp))
                        Text("Save Config", fontWeight = FontWeight.Bold, fontSize = 13.sp)
                    }

                    OutlinedButton(
                        onClick = {
                            val testTx = PaymentTransactionEntity(
                                transactionId = "pay_demo_${(100000..999999).random()}",
                                bookingId = "BMS-SAMPLE-99",
                                venueName = "Sample Space (Admin Preview)",
                                amount = 1499.0,
                                paymentStatus = "SUCCESS",
                                paymentMethod = "Razorpay UPI AutoPay",
                                isSignatureVerified = true
                            )
                            PdfInvoiceGenerator.exportInvoicePdf(context, testTx, null, openDirectly = true)
                        },
                        modifier = Modifier.weight(1f).height(48.dp).testTag("preview_admin_invoice_pdf_btn"),
                        shape = RoundedCornerShape(12.dp)
                    ) {
                        Icon(Icons.Default.PictureAsPdf, contentDescription = null, modifier = Modifier.size(18.dp))
                        Spacer(modifier = Modifier.width(6.dp))
                        Text("Test PDF", fontSize = 13.sp)
                    }
                }
            }
        } else {
            // VENUE OWNER OVERRIDES SECTION
            item {
                Card(
                    shape = RoundedCornerShape(16.dp),
                    colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface),
                    border = BorderStroke(1.dp, MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.5f))
                ) {
                    Column(modifier = Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
                        Text("Select Venue to Configure", fontWeight = FontWeight.Bold, fontSize = 14.sp, color = MaterialTheme.colorScheme.primary)

                        LazyRow(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                            items(venues) { v ->
                                val isSelected = selectedVenue?.id == v.id
                                FilterChip(
                                    selected = isSelected,
                                    onClick = { selectedVenue = v },
                                    label = { Text(v.name, fontSize = 12.sp) },
                                    leadingIcon = if (isSelected) {
                                        { Icon(Icons.Default.Check, contentDescription = null, modifier = Modifier.size(14.dp)) }
                                    } else null
                                )
                            }
                        }

                        HorizontalDivider(color = MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.4f))

                        Row(
                            modifier = Modifier.fillMaxWidth(),
                            horizontalArrangement = Arrangement.SpaceBetween,
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            Column(modifier = Modifier.weight(1f)) {
                                Text("Enable Venue-Specific Tax Invoice", fontWeight = FontWeight.Bold, fontSize = 13.sp)
                                Text("Overrides platform defaults with venue legal entity & GSTIN", fontSize = 11.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                            }
                            Switch(
                                checked = venueOverrideEnabled,
                                onCheckedChange = { venueOverrideEnabled = it },
                                modifier = Modifier.testTag("venue_override_toggle")
                            )
                        }

                        if (venueOverrideEnabled) {
                            OutlinedTextField(
                                value = venueLegalName,
                                onValueChange = { venueLegalName = it },
                                label = { Text("Venue Business Legal Name") },
                                modifier = Modifier.fillMaxWidth().testTag("venue_legal_name_input"),
                                singleLine = true
                            )

                            Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                                OutlinedTextField(
                                    value = venueGstin,
                                    onValueChange = { venueGstin = it.uppercase() },
                                    label = { Text("Venue GSTIN") },
                                    modifier = Modifier.weight(1f).testTag("venue_gstin_input"),
                                    singleLine = true
                                )
                                OutlinedTextField(
                                    value = venuePan,
                                    onValueChange = { venuePan = it.uppercase() },
                                    label = { Text("Venue PAN") },
                                    modifier = Modifier.weight(1f).testTag("venue_pan_input"),
                                    singleLine = true
                                )
                            }

                            OutlinedTextField(
                                value = venueAddress,
                                onValueChange = { venueAddress = it },
                                label = { Text("Venue Invoice Address") },
                                modifier = Modifier.fillMaxWidth().testTag("venue_address_input"),
                                maxLines = 2
                            )

                            Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                                OutlinedTextField(
                                    value = venueEmail,
                                    onValueChange = { venueEmail = it },
                                    label = { Text("Billing Email") },
                                    modifier = Modifier.weight(1f).testTag("venue_email_input"),
                                    singleLine = true
                                )
                                OutlinedTextField(
                                    value = venuePhone,
                                    onValueChange = { venuePhone = it },
                                    label = { Text("Billing Phone") },
                                    modifier = Modifier.weight(1f).testTag("venue_phone_input"),
                                    singleLine = true
                                )
                            }

                            Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                                OutlinedTextField(
                                    value = venueSignatoryName,
                                    onValueChange = { venueSignatoryName = it },
                                    label = { Text("Venue Manager / Signatory") },
                                    modifier = Modifier.weight(1f).testTag("venue_signatory_input"),
                                    singleLine = true
                                )
                                OutlinedTextField(
                                    value = venueSignatoryRole,
                                    onValueChange = { venueSignatoryRole = it },
                                    label = { Text("Role") },
                                    modifier = Modifier.weight(1f).testTag("venue_role_input"),
                                    singleLine = true
                                )
                            }

                            OutlinedTextField(
                                value = venueCustomTerms,
                                onValueChange = { venueCustomTerms = it },
                                label = { Text("Venue Special Terms & Policies") },
                                modifier = Modifier.fillMaxWidth().testTag("venue_terms_input"),
                                minLines = 2,
                                maxLines = 4
                            )
                        }
                    }
                }
            }

            item {
                Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                    Button(
                        onClick = {
                            val vId = selectedVenue?.id ?: return@Button
                            val override = VenueTaxInvoiceOverride(
                                venueId = vId,
                                isEnabled = venueOverrideEnabled,
                                venueBusinessName = venueLegalName.trim(),
                                venueGstin = venueGstin.trim(),
                                venuePan = venuePan.trim(),
                                venueAddress = venueAddress.trim(),
                                venueStateCode = venueStateCode.trim(),
                                venuePhone = venuePhone.trim(),
                                venueEmail = venueEmail.trim(),
                                venueSacCode = venueSacCode.trim(),
                                signatoryName = venueSignatoryName.trim(),
                                signatoryRole = venueSignatoryRole.trim(),
                                customTerms = venueCustomTerms.trim(),
                                customFooter = venueCustomFooter.trim(),
                                accentColorHex = venueAccentColor
                            )
                            invoiceRepo.updateVenueOverride(override)
                            Toast.makeText(context, "Venue Invoice Settings Saved for ${selectedVenue?.name}! 🏢", Toast.LENGTH_SHORT).show()
                        },
                        enabled = selectedVenue != null,
                        modifier = Modifier.weight(1.2f).height(48.dp).testTag("save_venue_invoice_override_btn"),
                        shape = RoundedCornerShape(12.dp)
                    ) {
                        Icon(Icons.Default.Save, contentDescription = null, modifier = Modifier.size(18.dp))
                        Spacer(modifier = Modifier.width(6.dp))
                        Text("Save Venue Override", fontWeight = FontWeight.Bold, fontSize = 13.sp)
                    }

                    OutlinedButton(
                        onClick = {
                            val v = selectedVenue ?: return@OutlinedButton
                            val testTx = PaymentTransactionEntity(
                                transactionId = "pay_venue_${(100000..999999).random()}",
                                bookingId = "BMS-${v.id.take(4).uppercase()}-101",
                                venueId = v.id,
                                venueName = v.name,
                                amount = 850.0,
                                paymentStatus = "SUCCESS",
                                paymentMethod = "Razorpay Direct UPI",
                                isSignatureVerified = true
                            )
                            PdfInvoiceGenerator.exportInvoicePdf(context, testTx, null, openDirectly = true)
                        },
                        enabled = selectedVenue != null,
                        modifier = Modifier.weight(1f).height(48.dp).testTag("preview_venue_invoice_pdf_btn"),
                        shape = RoundedCornerShape(12.dp)
                    ) {
                        Icon(Icons.Default.PictureAsPdf, contentDescription = null, modifier = Modifier.size(18.dp))
                        Spacer(modifier = Modifier.width(6.dp))
                        Text("Test Venue PDF", fontSize = 13.sp)
                    }
                }
            }
        }
    }
}
