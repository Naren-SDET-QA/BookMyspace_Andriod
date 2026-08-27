package com.bookmyspace.bookmyspace.ui.screens

import androidx.compose.animation.*
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.text.input.VisualTransformation
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import coil.compose.AsyncImage
import com.bookmyspace.bookmyspace.data.location.IndiaLocationMasterData
import com.bookmyspace.bookmyspace.data.model.*
import com.bookmyspace.bookmyspace.data.repository.BookMySpaceRepository

val UNIFIED_AVATAR_PRESETS = listOf(
    "https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=300&auto=format&fit=crop&q=80",
    "https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=300&auto=format&fit=crop&q=80",
    "https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=300&auto=format&fit=crop&q=80",
    "https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=300&auto=format&fit=crop&q=80",
    "https://images.unsplash.com/photo-1438761681033-6461ffad8d80?w=300&auto=format&fit=crop&q=80",
    "https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?w=300&auto=format&fit=crop&q=80"
)

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun UnifiedRegistrationScreen(
    onNavigateBack: () -> Unit,
    onRegistrationSuccess: (UserRole) -> Unit,
    onNavigateToFieldsConfig: () -> Unit = {}
) {
    val allConfigFields by BookMySpaceRepository.registrationFields.collectAsState()
    val authUser by BookMySpaceRepository.authUser.collectAsState()
    val currentPresetLocation by BookMySpaceRepository.userLocationHierarchy.collectAsState()

    var selectedModule by remember { mutableStateOf(RegistrationTargetModule.CUSTOMER) }

    // Form Field States
    var photoUrl by remember { mutableStateOf(UNIFIED_AVATAR_PRESETS[0]) }
    var showAvatarPicker by remember { mutableStateOf(false) }
    var customPhotoUrlInput by remember { mutableStateOf("") }

    var fullName by remember { mutableStateOf("") }
    var email by remember { mutableStateOf("") }
    var phone by remember { mutableStateOf("") }
    var password by remember { mutableStateOf("") }
    var isPasswordVisible by remember { mutableStateOf(false) }

    var aadhaarNumber by remember { mutableStateOf("") }
    var govtIdNumber by remember { mutableStateOf("") }

    var addressLine1 by remember { mutableStateOf("") }
    var addressLine2 by remember { mutableStateOf("") }
    var pincode by remember { mutableStateOf("500033") }
    var selectedLocation by remember { mutableStateOf(currentPresetLocation) }
    var showLocationSelectorDialog by remember { mutableStateOf(false) }

    var gender by remember { mutableStateOf("Male") }
    var dob by remember { mutableStateOf("") }
    var emergencyContact by remember { mutableStateOf("") }

    var organizationName by remember { mutableStateOf("") }
    var gstin by remember { mutableStateOf("") }

    // Dynamic responses map for custom fields
    val customFieldResponses = remember { mutableStateMapOf<String, String>() }

    var acceptTerms by remember { mutableStateOf(true) }
    var isLoading by remember { mutableStateOf(false) }
    var errorMessage by remember { mutableStateOf<String?>(null) }
    var successNotice by remember { mutableStateOf<String?>(null) }

    // Active fields for the selected target module
    val activeFields = remember(allConfigFields, selectedModule) {
        allConfigFields.filter {
            it.isEnabled && (it.targetModule == RegistrationTargetModule.ALL || it.targetModule == selectedModule)
        }.sortedBy { it.displayOrder }
    }

    // Group active fields by category
    val fieldsByCategory = remember(activeFields) {
        activeFields.groupBy { it.category }
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = {
                    Column {
                        Text("Unified Registration", fontWeight = FontWeight.Bold, fontSize = 18.sp)
                        Text("Single configured profile for all modules", fontSize = 11.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                    }
                },
                navigationIcon = {
                    IconButton(onClick = onNavigateBack) {
                        Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "Back")
                    }
                },
                actions = {
                    // Quick admin link to configure fields
                    IconButton(
                        onClick = onNavigateToFieldsConfig,
                        modifier = Modifier.testTag("open_registration_fields_config_btn")
                    ) {
                        Icon(Icons.Default.Tune, contentDescription = "Configure Fields", tint = MaterialTheme.colorScheme.primary)
                    }
                }
            )
        }
    ) { paddingValues ->
        LazyColumn(
            modifier = Modifier
                .fillMaxSize()
                .padding(paddingValues)
                .testTag("unified_registration_screen"),
            contentPadding = PaddingValues(horizontal = 20.dp, vertical = 16.dp),
            verticalArrangement = Arrangement.spacedBy(16.dp)
        ) {
            // Module / Role Selection Header
            item {
                Card(
                    modifier = Modifier.fillMaxWidth(),
                    shape = RoundedCornerShape(16.dp),
                    colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.primaryContainer.copy(alpha = 0.6f))
                ) {
                    Column(modifier = Modifier.padding(16.dp)) {
                        Row(
                            modifier = Modifier.fillMaxWidth(),
                            horizontalArrangement = Arrangement.SpaceBetween,
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            Text("Select Registration Type", fontWeight = FontWeight.Bold, fontSize = 14.sp)
                            Surface(
                                color = MaterialTheme.colorScheme.primary,
                                shape = RoundedCornerShape(6.dp)
                            ) {
                                Text(
                                    text = "${activeFields.size} Configured Fields",
                                    fontSize = 10.sp,
                                    color = Color.White,
                                    fontWeight = FontWeight.Bold,
                                    modifier = Modifier.padding(horizontal = 6.dp, vertical = 2.dp)
                                )
                            }
                        }
                        Spacer(modifier = Modifier.height(4.dp))
                        Text(
                            "Each module dynamically adjusts required KYC, photo, address, and profile fields.",
                            fontSize = 11.sp,
                            color = MaterialTheme.colorScheme.onPrimaryContainer
                        )
                        Spacer(modifier = Modifier.height(12.dp))

                        // Target Module Filter Tabs
                        ScrollableTabRow(
                            selectedTabIndex = listOf(
                                RegistrationTargetModule.CUSTOMER,
                                RegistrationTargetModule.VENUE_OWNER,
                                RegistrationTargetModule.INSTITUTE_STUDENT,
                                RegistrationTargetModule.EVENT_ATTENDEE
                            ).indexOf(selectedModule).coerceAtLeast(0),
                            edgePadding = 0.dp,
                            modifier = Modifier.fillMaxWidth(),
                            containerColor = Color.Transparent
                        ) {
                            listOf(
                                RegistrationTargetModule.CUSTOMER,
                                RegistrationTargetModule.VENUE_OWNER,
                                RegistrationTargetModule.INSTITUTE_STUDENT,
                                RegistrationTargetModule.EVENT_ATTENDEE
                            ).forEach { mod ->
                                val isSelected = selectedModule == mod
                                Tab(
                                    selected = isSelected,
                                    onClick = { selectedModule = mod },
                                    text = {
                                        Text(
                                            text = mod.displayName,
                                            fontWeight = if (isSelected) FontWeight.Bold else FontWeight.Normal,
                                            fontSize = 12.sp
                                        )
                                    }
                                )
                            }
                        }
                    }
                }
            }

            // Error / Success Banners
            if (errorMessage != null) {
                item {
                    Card(
                        modifier = Modifier.fillMaxWidth(),
                        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.errorContainer),
                        shape = RoundedCornerShape(12.dp)
                    ) {
                        Row(
                            modifier = Modifier.padding(12.dp),
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            Icon(Icons.Default.ErrorOutline, contentDescription = null, tint = MaterialTheme.colorScheme.onErrorContainer)
                            Spacer(modifier = Modifier.width(8.dp))
                            Text(
                                text = errorMessage ?: "",
                                color = MaterialTheme.colorScheme.onErrorContainer,
                                fontSize = 12.sp,
                                fontWeight = FontWeight.Medium
                            )
                        }
                    }
                }
            }

            if (successNotice != null) {
                item {
                    Card(
                        modifier = Modifier.fillMaxWidth(),
                        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.tertiaryContainer),
                        shape = RoundedCornerShape(12.dp)
                    ) {
                        Row(
                            modifier = Modifier.padding(12.dp),
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            Icon(Icons.Default.CheckCircle, contentDescription = null, tint = MaterialTheme.colorScheme.onTertiaryContainer)
                            Spacer(modifier = Modifier.width(8.dp))
                            Text(
                                text = successNotice ?: "",
                                color = MaterialTheme.colorScheme.onTertiaryContainer,
                                fontSize = 12.sp,
                                fontWeight = FontWeight.Bold
                            )
                        }
                    }
                }
            }

            // Category: Personal Details
            if (fieldsByCategory.containsKey(RegistrationFieldCategory.PERSONAL)) {
                item {
                    RegistrationCategoryCard(
                        category = RegistrationFieldCategory.PERSONAL,
                        icon = Icons.Default.Person
                    ) {
                        val personalFields = fieldsByCategory[RegistrationFieldCategory.PERSONAL] ?: emptyList()

                        // Photo Field if present
                        val photoField = personalFields.firstOrNull { it.fieldType == RegistrationFieldType.PHOTO }
                        if (photoField != null) {
                            Column(
                                modifier = Modifier.fillMaxWidth(),
                                horizontalAlignment = Alignment.CenterHorizontally
                            ) {
                                Box(
                                    modifier = Modifier
                                        .size(80.dp)
                                        .clip(CircleShape)
                                        .background(MaterialTheme.colorScheme.primary)
                                        .border(2.dp, MaterialTheme.colorScheme.primary, CircleShape)
                                        .clickable { showAvatarPicker = true }
                                        .testTag("reg_photo_picker_avatar"),
                                    contentAlignment = Alignment.Center
                                ) {
                                    if (photoUrl.isNotBlank()) {
                                        AsyncImage(
                                            model = photoUrl,
                                            contentDescription = "Profile Photo",
                                            modifier = Modifier.fillMaxSize(),
                                            contentScale = ContentScale.Crop
                                        )
                                    } else {
                                        Icon(Icons.Default.AddAPhoto, contentDescription = "Add Photo", tint = Color.White)
                                    }
                                }
                                Spacer(modifier = Modifier.height(6.dp))
                                Text(
                                    text = "${photoField.label}${if (photoField.required) " *" else " (Tap to change)"}",
                                    fontSize = 11.sp,
                                    fontWeight = FontWeight.Bold,
                                    color = MaterialTheme.colorScheme.primary
                                )
                                Text(
                                    text = photoField.helpText,
                                    fontSize = 10.sp,
                                    color = MaterialTheme.colorScheme.onSurfaceVariant
                                )
                                Spacer(modifier = Modifier.height(12.dp))
                            }
                        }

                        // Full Name Field
                        val nameField = personalFields.firstOrNull { it.key == "full_name" }
                        if (nameField != null) {
                            OutlinedTextField(
                                value = fullName,
                                onValueChange = { fullName = it; errorMessage = null },
                                label = { Text("${nameField.label}${if (nameField.required) " *" else ""}") },
                                placeholder = { Text(nameField.placeholder.ifBlank { "e.g. Narendra Reddy" }) },
                                leadingIcon = { Icon(Icons.Default.Badge, contentDescription = null) },
                                singleLine = true,
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .testTag("reg_input_full_name")
                            )
                            Spacer(modifier = Modifier.height(10.dp))
                        }

                        // Mobile / Phone Field
                        val phoneField = personalFields.firstOrNull { it.key == "phone" }
                        if (phoneField != null) {
                            OutlinedTextField(
                                value = phone,
                                onValueChange = { phone = it; errorMessage = null },
                                label = { Text("${phoneField.label}${if (phoneField.required) " *" else ""}") },
                                placeholder = { Text(phoneField.placeholder.ifBlank { "+91 98765 43210" }) },
                                leadingIcon = { Icon(Icons.Default.Phone, contentDescription = null) },
                                keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Phone),
                                singleLine = true,
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .testTag("reg_input_phone")
                            )
                            Spacer(modifier = Modifier.height(10.dp))
                        }

                        // Email Field
                        val emailField = personalFields.firstOrNull { it.key == "email" }
                        if (emailField != null) {
                            OutlinedTextField(
                                value = email,
                                onValueChange = { email = it; errorMessage = null },
                                label = { Text("${emailField.label}${if (emailField.required) " *" else ""}") },
                                placeholder = { Text(emailField.placeholder.ifBlank { "user@example.com" }) },
                                leadingIcon = { Icon(Icons.Default.Email, contentDescription = null) },
                                keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Email),
                                singleLine = true,
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .testTag("reg_input_email")
                            )
                            Spacer(modifier = Modifier.height(10.dp))
                        }

                        // Password Field
                        OutlinedTextField(
                            value = password,
                            onValueChange = { password = it; errorMessage = null },
                            label = { Text("Account Password *") },
                            placeholder = { Text("Enter secure password") },
                            leadingIcon = { Icon(Icons.Default.Lock, contentDescription = null) },
                            trailingIcon = {
                                IconButton(onClick = { isPasswordVisible = !isPasswordVisible }) {
                                    Icon(
                                        imageVector = if (isPasswordVisible) Icons.Default.VisibilityOff else Icons.Default.Visibility,
                                        contentDescription = "Toggle password visibility"
                                    )
                                }
                            },
                            visualTransformation = if (isPasswordVisible) VisualTransformation.None else PasswordVisualTransformation(),
                            singleLine = true,
                            modifier = Modifier
                                .fillMaxWidth()
                                .testTag("reg_input_password")
                        )
                        Spacer(modifier = Modifier.height(10.dp))

                        // Gender Field
                        val genderField = personalFields.firstOrNull { it.key == "gender" }
                        if (genderField != null) {
                            Text(
                                text = "${genderField.label}${if (genderField.required) " *" else ""}",
                                fontWeight = FontWeight.Bold,
                                fontSize = 12.sp
                            )
                            Spacer(modifier = Modifier.height(4.dp))
                            Row(
                                modifier = Modifier.fillMaxWidth(),
                                horizontalArrangement = Arrangement.spacedBy(8.dp)
                            ) {
                                val opts = if (genderField.options.isNotEmpty()) genderField.options else listOf("Male", "Female", "Other")
                                opts.forEach { opt ->
                                    FilterChip(
                                        selected = gender == opt,
                                        onClick = { gender = opt },
                                        label = { Text(opt, fontSize = 11.sp) },
                                        modifier = Modifier.weight(1f)
                                    )
                                }
                            }
                            Spacer(modifier = Modifier.height(10.dp))
                        }

                        // Date of Birth Field
                        val dobField = personalFields.firstOrNull { it.key == "dob" }
                        if (dobField != null) {
                            OutlinedTextField(
                                value = dob,
                                onValueChange = { dob = it },
                                label = { Text("${dobField.label}${if (dobField.required) " *" else ""}") },
                                placeholder = { Text(dobField.placeholder.ifBlank { "DD/MM/YYYY" }) },
                                leadingIcon = { Icon(Icons.Default.CalendarToday, contentDescription = null) },
                                singleLine = true,
                                modifier = Modifier.fillMaxWidth()
                            )
                            Spacer(modifier = Modifier.height(10.dp))
                        }

                        // Emergency Contact Field
                        val emergencyField = personalFields.firstOrNull { it.key == "emergency_contact" }
                        if (emergencyField != null) {
                            OutlinedTextField(
                                value = emergencyContact,
                                onValueChange = { emergencyContact = it },
                                label = { Text("${emergencyField.label}${if (emergencyField.required) " *" else ""}") },
                                placeholder = { Text(emergencyField.placeholder.ifBlank { "+91 91234 56789" }) },
                                leadingIcon = { Icon(Icons.Default.ContactPhone, contentDescription = null) },
                                keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Phone),
                                singleLine = true,
                                modifier = Modifier.fillMaxWidth()
                            )
                        }
                    }
                }
            }

            // Category: Government ID & KYC
            if (fieldsByCategory.containsKey(RegistrationFieldCategory.IDENTITY_KYC)) {
                item {
                    RegistrationCategoryCard(
                        category = RegistrationFieldCategory.IDENTITY_KYC,
                        icon = Icons.Default.Badge
                    ) {
                        val kycFields = fieldsByCategory[RegistrationFieldCategory.IDENTITY_KYC] ?: emptyList()

                        // Aadhaar Field
                        val aadhaarField = kycFields.firstOrNull { it.fieldType == RegistrationFieldType.AADHAAR }
                        if (aadhaarField != null) {
                            Column {
                                OutlinedTextField(
                                    value = aadhaarNumber,
                                    onValueChange = { raw ->
                                        val digits = raw.filter { it.isDigit() }.take(12)
                                        // Format as XXXX XXXX XXXX
                                        val formatted = digits.chunked(4).joinToString(" ")
                                        aadhaarNumber = formatted
                                    },
                                    label = { Text("${aadhaarField.label}${if (aadhaarField.required) " *" else ""}") },
                                    placeholder = { Text("1234 5678 9012") },
                                    leadingIcon = { Icon(Icons.Default.Security, contentDescription = null, tint = MaterialTheme.colorScheme.primary) },
                                    trailingIcon = {
                                        val digitCount = aadhaarNumber.filter { it.isDigit() }.length
                                        if (digitCount == 12) {
                                            Icon(Icons.Default.CheckCircle, contentDescription = "Valid Aadhaar length", tint = MaterialTheme.colorScheme.primary)
                                        } else if (digitCount > 0) {
                                            Text("$digitCount/12", fontSize = 11.sp, color = MaterialTheme.colorScheme.onSurfaceVariant, modifier = Modifier.padding(end = 8.dp))
                                        }
                                    },
                                    keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number),
                                    singleLine = true,
                                    modifier = Modifier
                                        .fillMaxWidth()
                                        .testTag("reg_input_aadhaar")
                                )

                                Spacer(modifier = Modifier.height(4.dp))
                                Row(
                                    verticalAlignment = Alignment.CenterVertically,
                                    modifier = Modifier.padding(horizontal = 4.dp)
                                ) {
                                    Icon(Icons.Default.VerifiedUser, contentDescription = null, modifier = Modifier.size(12.dp), tint = MaterialTheme.colorScheme.primary)
                                    Spacer(modifier = Modifier.width(4.dp))
                                    Text(
                                        text = "UIDAI Compliant: Encrypted with masked audit trail (XXXX-XXXX-1234)",
                                        fontSize = 10.sp,
                                        color = MaterialTheme.colorScheme.onSurfaceVariant
                                    )
                                }
                                Spacer(modifier = Modifier.height(10.dp))
                            }
                        }

                        // Alternate Govt ID Field
                        val govtIdField = kycFields.firstOrNull { it.key == "govt_id_number" }
                        if (govtIdField != null) {
                            OutlinedTextField(
                                value = govtIdNumber,
                                onValueChange = { govtIdNumber = it },
                                label = { Text("${govtIdField.label}${if (govtIdField.required) " *" else ""}") },
                                placeholder = { Text(govtIdField.placeholder.ifBlank { "PAN / Voter ID / Passport" }) },
                                leadingIcon = { Icon(Icons.Default.CreditCard, contentDescription = null) },
                                singleLine = true,
                                modifier = Modifier.fillMaxWidth()
                            )
                        }
                    }
                }
            }

            // Category: Address & Location
            if (fieldsByCategory.containsKey(RegistrationFieldCategory.ADDRESS)) {
                item {
                    RegistrationCategoryCard(
                        category = RegistrationFieldCategory.ADDRESS,
                        icon = Icons.Default.LocationOn
                    ) {
                        val addressFields = fieldsByCategory[RegistrationFieldCategory.ADDRESS] ?: emptyList()

                        // Address Line 1
                        val addr1Field = addressFields.firstOrNull { it.key == "address_line_1" }
                        if (addr1Field != null) {
                            OutlinedTextField(
                                value = addressLine1,
                                onValueChange = { addressLine1 = it },
                                label = { Text("${addr1Field.label}${if (addr1Field.required) " *" else ""}") },
                                placeholder = { Text(addr1Field.placeholder.ifBlank { "Flat/House No, Building, Street" }) },
                                leadingIcon = { Icon(Icons.Default.Home, contentDescription = null) },
                                singleLine = true,
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .testTag("reg_input_address_line1")
                            )
                            Spacer(modifier = Modifier.height(10.dp))
                        }

                        // Address Line 2
                        val addr2Field = addressFields.firstOrNull { it.key == "address_line_2" }
                        if (addr2Field != null) {
                            OutlinedTextField(
                                value = addressLine2,
                                onValueChange = { addressLine2 = it },
                                label = { Text("${addr2Field.label}${if (addr2Field.required) " *" else ""}") },
                                placeholder = { Text(addr2Field.placeholder.ifBlank { "Landmark / Sector / Area" }) },
                                leadingIcon = { Icon(Icons.Default.Signpost, contentDescription = null) },
                                singleLine = true,
                                modifier = Modifier.fillMaxWidth()
                            )
                            Spacer(modifier = Modifier.height(10.dp))
                        }

                        // Location Hierarchy Selector
                        val locField = addressFields.firstOrNull { it.fieldType == RegistrationFieldType.LOCATION_HIERARCHY }
                        if (locField != null) {
                            Card(
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .clickable { showLocationSelectorDialog = true }
                                    .testTag("reg_location_hierarchy_card"),
                                shape = RoundedCornerShape(12.dp),
                                colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.5f)),
                                border = androidx.compose.foundation.BorderStroke(1.dp, MaterialTheme.colorScheme.outlineVariant)
                            ) {
                                Row(
                                    modifier = Modifier.padding(14.dp),
                                    verticalAlignment = Alignment.CenterVertically
                                ) {
                                    Icon(Icons.Default.Place, contentDescription = null, tint = MaterialTheme.colorScheme.primary)
                                    Spacer(modifier = Modifier.width(12.dp))
                                    Column(modifier = Modifier.weight(1f)) {
                                        Text(
                                            text = "${locField.label}${if (locField.required) " *" else ""}",
                                            fontSize = 11.sp,
                                            color = MaterialTheme.colorScheme.onSurfaceVariant
                                        )
                                        Text(
                                            text = selectedLocation.breadcrumbLabel,
                                            fontWeight = FontWeight.Bold,
                                            fontSize = 13.sp
                                        )
                                        Text(
                                            text = "Tap to change Country, State, District, City, or Area",
                                            fontSize = 10.sp,
                                            color = MaterialTheme.colorScheme.primary
                                        )
                                    }
                                    Icon(Icons.Default.ChevronRight, contentDescription = null, tint = MaterialTheme.colorScheme.primary)
                                }
                            }
                            Spacer(modifier = Modifier.height(10.dp))
                        }

                        // Pincode Field
                        val pincodeField = addressFields.firstOrNull { it.key == "pincode" }
                        if (pincodeField != null) {
                            OutlinedTextField(
                                value = pincode,
                                onValueChange = { raw -> pincode = raw.filter { it.isDigit() }.take(6) },
                                label = { Text("${pincodeField.label}${if (pincodeField.required) " *" else ""}") },
                                placeholder = { Text("500033") },
                                leadingIcon = { Icon(Icons.Default.Pin, contentDescription = null) },
                                keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number),
                                singleLine = true,
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .testTag("reg_input_pincode")
                            )
                        }
                    }
                }
            }

            // Category: Business & Academy Profile (For Venue Owners / Institutes)
            if (fieldsByCategory.containsKey(RegistrationFieldCategory.PROFESSIONAL_BUSINESS)) {
                item {
                    RegistrationCategoryCard(
                        category = RegistrationFieldCategory.PROFESSIONAL_BUSINESS,
                        icon = Icons.Default.Business
                    ) {
                        val busFields = fieldsByCategory[RegistrationFieldCategory.PROFESSIONAL_BUSINESS] ?: emptyList()

                        val orgField = busFields.firstOrNull { it.key == "organization_name" }
                        if (orgField != null) {
                            OutlinedTextField(
                                value = organizationName,
                                onValueChange = { organizationName = it },
                                label = { Text("${orgField.label}${if (orgField.required) " *" else ""}") },
                                placeholder = { Text(orgField.placeholder.ifBlank { "e.g. Smash Sports LLP" }) },
                                leadingIcon = { Icon(Icons.Default.Domain, contentDescription = null) },
                                singleLine = true,
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .testTag("reg_input_org_name")
                            )
                            Spacer(modifier = Modifier.height(10.dp))
                        }

                        val gstinField = busFields.firstOrNull { it.key == "gstin" }
                        if (gstinField != null) {
                            OutlinedTextField(
                                value = gstin,
                                onValueChange = { gstin = it.uppercase() },
                                label = { Text("${gstinField.label}${if (gstinField.required) " *" else ""}") },
                                placeholder = { Text("36AAAAA0000A1Z5") },
                                leadingIcon = { Icon(Icons.Default.Receipt, contentDescription = null) },
                                singleLine = true,
                                modifier = Modifier.fillMaxWidth()
                            )
                        }
                    }
                }
            }

            // Category: Custom & Additional Fields
            if (fieldsByCategory.containsKey(RegistrationFieldCategory.CUSTOM)) {
                item {
                    RegistrationCategoryCard(
                        category = RegistrationFieldCategory.CUSTOM,
                        icon = Icons.Default.Extension
                    ) {
                        val customFields = fieldsByCategory[RegistrationFieldCategory.CUSTOM] ?: emptyList()
                        customFields.forEach { field ->
                            val currentVal = customFieldResponses[field.key] ?: field.defaultValue

                            when (field.fieldType) {
                                RegistrationFieldType.DROPDOWN -> {
                                    var expanded by remember { mutableStateOf(false) }
                                    ExposedDropdownMenuBox(
                                        expanded = expanded,
                                        onExpandedChange = { expanded = it }
                                    ) {
                                        OutlinedTextField(
                                            value = currentVal.ifBlank { field.options.firstOrNull() ?: "" },
                                            onValueChange = {},
                                            readOnly = true,
                                            label = { Text("${field.label}${if (field.required) " *" else ""}") },
                                            trailingIcon = { ExposedDropdownMenuDefaults.TrailingIcon(expanded = expanded) },
                                            modifier = Modifier
                                                .fillMaxWidth()
                                                .menuAnchor()
                                        )
                                        ExposedDropdownMenu(
                                            expanded = expanded,
                                            onDismissRequest = { expanded = false }
                                        ) {
                                            field.options.forEach { opt ->
                                                DropdownMenuItem(
                                                    text = { Text(opt) },
                                                    onClick = {
                                                        customFieldResponses[field.key] = opt
                                                        expanded = false
                                                    }
                                                )
                                            }
                                        }
                                    }
                                }
                                RegistrationFieldType.TEXTAREA -> {
                                    OutlinedTextField(
                                        value = currentVal,
                                        onValueChange = { customFieldResponses[field.key] = it },
                                        label = { Text("${field.label}${if (field.required) " *" else ""}") },
                                        placeholder = { Text(field.placeholder) },
                                        minLines = 3,
                                        maxLines = 5,
                                        modifier = Modifier.fillMaxWidth()
                                    )
                                }
                                RegistrationFieldType.CHECKBOX -> {
                                    val isChecked = currentVal == "true"
                                    Row(
                                        modifier = Modifier.fillMaxWidth(),
                                        verticalAlignment = Alignment.CenterVertically
                                    ) {
                                        Checkbox(
                                            checked = isChecked,
                                            onCheckedChange = { customFieldResponses[field.key] = it.toString() }
                                        )
                                        Spacer(modifier = Modifier.width(8.dp))
                                        Text(field.label, fontSize = 13.sp)
                                    }
                                }
                                else -> {
                                    OutlinedTextField(
                                        value = currentVal,
                                        onValueChange = { customFieldResponses[field.key] = it },
                                        label = { Text("${field.label}${if (field.required) " *" else ""}") },
                                        placeholder = { Text(field.placeholder) },
                                        singleLine = true,
                                        modifier = Modifier.fillMaxWidth()
                                    )
                                }
                            }
                            Spacer(modifier = Modifier.height(10.dp))
                        }
                    }
                }
            }

            // Terms & Conditions Checkbox
            item {
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Checkbox(
                        checked = acceptTerms,
                        onCheckedChange = { acceptTerms = it },
                        modifier = Modifier.testTag("reg_accept_terms_checkbox")
                    )
                    Spacer(modifier = Modifier.width(6.dp))
                    Text(
                        text = "I accept the Terms of Service, Privacy Policy and KYC Verification Rules.",
                        fontSize = 11.sp,
                        lineHeight = 15.sp,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                }
            }

            // Submit Registration Button
            item {
                Button(
                    onClick = {
                        // Password is always mandatory for account creation
                        if (password.isBlank()) {
                            errorMessage = "Please create a password for your account."
                            return@Button
                        }

                        // Validate all dynamically configured mandatory fields
                        for (field in activeFields) {
                            if (field.required) {
                                val value = when (field.key) {
                                    "full_name" -> fullName
                                    "phone" -> phone
                                    "email" -> email
                                    "photo_url" -> photoUrl
                                    "aadhaar_number" -> aadhaarNumber
                                    "govt_id_number" -> govtIdNumber
                                    "address_line_1" -> addressLine1
                                    "address_line_2" -> addressLine2
                                    "pincode" -> pincode
                                    "dob" -> dob
                                    "gender" -> gender
                                    "emergency_contact" -> emergencyContact
                                    "organization_name" -> organizationName
                                    "gstin" -> gstin
                                    "location_hierarchy" -> if (selectedLocation != null) "selected" else ""
                                    else -> customFieldResponses[field.key] ?: ""
                                }
                                if (value.isBlank()) {
                                    errorMessage = "Please fill in mandatory field: ${field.label}"
                                    return@Button
                                }
                            }
                        }

                        if (!acceptTerms) {
                            errorMessage = "You must agree to the terms and KYC policy to register."
                            return@Button
                        }

                        isLoading = true
                        errorMessage = null

                        val profileData = UserProfileData(
                            fullName = fullName.trim(),
                            email = email.trim(),
                            phone = phone.trim(),
                            photoUrl = photoUrl.trim(),
                            aadhaarNumber = aadhaarNumber.trim(),
                            govtIdNumber = govtIdNumber.trim(),
                            addressLine1 = addressLine1.trim(),
                            addressLine2 = addressLine2.trim(),
                            pincode = pincode.trim(),
                            locationHierarchy = selectedLocation,
                            gender = gender,
                            dob = dob.trim(),
                            emergencyContact = emergencyContact.trim(),
                            organizationName = organizationName.trim(),
                            gstin = gstin.trim(),
                            role = when (selectedModule) {
                                RegistrationTargetModule.VENUE_OWNER -> UserRole.VENUE_OWNER
                                else -> UserRole.USER
                            },
                            targetModule = selectedModule,
                            customFields = customFieldResponses.toMap(),
                            isKycVerified = aadhaarNumber.isNotBlank()
                        )

                        val result = BookMySpaceRepository.registerUnifiedUser(profile = profileData, password = password)
                        isLoading = false

                        result.fold(
                            onSuccess = { user ->
                                successNotice = "Registration successful as ${user.fullName} (${user.role})!"
                                onRegistrationSuccess(user.role)
                            },
                            onFailure = { ex ->
                                errorMessage = ex.message ?: "Failed to complete registration."
                            }
                        )
                    },
                    enabled = !isLoading,
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(52.dp)
                        .testTag("submit_unified_registration_button"),
                    shape = RoundedCornerShape(14.dp)
                ) {
                    if (isLoading) {
                        CircularProgressIndicator(modifier = Modifier.size(24.dp), color = MaterialTheme.colorScheme.onPrimary)
                    } else {
                        Icon(Icons.Default.PersonAdd, contentDescription = null, modifier = Modifier.size(18.dp))
                        Spacer(modifier = Modifier.width(8.dp))
                        Text(
                            text = "Register & Create Profile (${selectedModule.displayName})",
                            fontWeight = FontWeight.Bold,
                            fontSize = 15.sp
                        )
                    }
                }
            }

            // Quick DEV test Fill-in Button
            item {
                OutlinedButton(
                    onClick = {
                        fullName = "Narendra Reddy"
                        phone = "+91 98765 43210"
                        email = "narenqe2@gmail.com"
                        password = "Password@123"
                        aadhaarNumber = "5489 1234 9876"
                        addressLine1 = "Plot 42, Road No. 36"
                        addressLine2 = "Jubilee Hills"
                        pincode = "500033"
                        dob = "15/08/1992"
                        organizationName = "Smash Arena Club"
                        gstin = "36AAAAA0000A1Z5"
                        errorMessage = null
                    },
                    modifier = Modifier.fillMaxWidth().testTag("auto_fill_dev_sample_data"),
                    shape = RoundedCornerShape(12.dp)
                ) {
                    Icon(Icons.Default.AutoFixHigh, contentDescription = null, modifier = Modifier.size(16.dp))
                    Spacer(modifier = Modifier.width(8.dp))
                    Text("Auto-Fill Sample Data (DEV Testing)", fontSize = 12.sp)
                }
                Spacer(modifier = Modifier.height(24.dp))
            }
        }
    }

    // Avatar Picker Modal
    if (showAvatarPicker) {
        AlertDialog(
            onDismissRequest = { showAvatarPicker = false },
            title = { Text("Select Profile Avatar / Photo", fontWeight = FontWeight.Bold) },
            text = {
                Column(
                    modifier = Modifier
                        .fillMaxWidth()
                        .verticalScroll(rememberScrollState()),
                    verticalArrangement = Arrangement.spacedBy(12.dp)
                ) {
                    Text("Preset Profile Avatars:", fontSize = 12.sp, fontWeight = FontWeight.Bold)
                    LazyRow(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.spacedBy(10.dp)
                    ) {
                        items(UNIFIED_AVATAR_PRESETS) { url ->
                            Box(
                                modifier = Modifier
                                    .size(60.dp)
                                    .clip(CircleShape)
                                    .border(
                                        width = if (photoUrl == url) 3.dp else 1.dp,
                                        color = if (photoUrl == url) MaterialTheme.colorScheme.primary else Color.Transparent,
                                        shape = CircleShape
                                    )
                                    .clickable {
                                        photoUrl = url
                                        showAvatarPicker = false
                                    }
                            ) {
                                AsyncImage(
                                    model = url,
                                    contentDescription = "Avatar preset",
                                    modifier = Modifier.fillMaxSize(),
                                    contentScale = ContentScale.Crop
                                )
                            }
                        }
                    }

                    Spacer(modifier = Modifier.height(8.dp))
                    Text("Or Enter Image / Photo URL:", fontSize = 12.sp, fontWeight = FontWeight.Bold)
                    OutlinedTextField(
                        value = customPhotoUrlInput,
                        onValueChange = { customPhotoUrlInput = it },
                        label = { Text("https://...") },
                        singleLine = true,
                        modifier = Modifier.fillMaxWidth()
                    )
                }
            },
            confirmButton = {
                Button(
                    onClick = {
                        if (customPhotoUrlInput.isNotBlank()) {
                            photoUrl = customPhotoUrlInput.trim()
                        }
                        showAvatarPicker = false
                    }
                ) {
                    Text("Done")
                }
            },
            dismissButton = {
                TextButton(onClick = { showAvatarPicker = false }) {
                    Text("Cancel")
                }
            }
        )
    }

    // Location Hierarchy Selector Modal
    if (showLocationSelectorDialog) {
        AlertDialog(
            onDismissRequest = { showLocationSelectorDialog = false },
            title = { Text("Select Location Hierarchy", fontWeight = FontWeight.Bold) },
            text = {
                Column(
                    modifier = Modifier
                        .fillMaxWidth()
                        .verticalScroll(rememberScrollState()),
                    verticalArrangement = Arrangement.spacedBy(10.dp)
                ) {
                    Text("Popular Regional Presets:", fontSize = 12.sp, fontWeight = FontWeight.Bold)
                    IndiaLocationMasterData.popularPresets.forEach { preset ->
                        val isSelected = selectedLocation.cityName == preset.cityName && selectedLocation.areaName == preset.areaName
                        Card(
                            modifier = Modifier
                                .fillMaxWidth()
                                .clickable {
                                    selectedLocation = preset
                                    pincode = preset.postalCode
                                    showLocationSelectorDialog = false
                                },
                            colors = CardDefaults.cardColors(
                                containerColor = if (isSelected)
                                    MaterialTheme.colorScheme.primaryContainer
                                else
                                    MaterialTheme.colorScheme.surfaceVariant
                            )
                        ) {
                            Column(modifier = Modifier.padding(12.dp)) {
                                Text(
                                    text = "🇮🇳 ${preset.areaName.ifBlank { preset.cityName }}, ${preset.cityName}",
                                    fontWeight = FontWeight.Bold,
                                    fontSize = 13.sp
                                )
                                Text(
                                    text = "${preset.mandalName}, ${preset.districtName}, ${preset.stateName} (${preset.postalCode})",
                                    fontSize = 11.sp,
                                    color = MaterialTheme.colorScheme.onSurfaceVariant
                                )
                            }
                        }
                    }
                }
            },
            confirmButton = {
                Button(onClick = { showLocationSelectorDialog = false }) {
                    Text("Close")
                }
            }
        )
    }
}

@Composable
fun RegistrationCategoryCard(
    category: RegistrationFieldCategory,
    icon: androidx.compose.ui.graphics.vector.ImageVector,
    content: @Composable ColumnScope.() -> Unit
) {
    Card(
        modifier = Modifier.fillMaxWidth(),
        shape = RoundedCornerShape(16.dp),
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface),
        elevation = CardDefaults.cardElevation(defaultElevation = 2.dp)
    ) {
        Column(modifier = Modifier.padding(16.dp)) {
            Row(
                verticalAlignment = Alignment.CenterVertically,
                modifier = Modifier.fillMaxWidth()
            ) {
                Box(
                    modifier = Modifier
                        .size(32.dp)
                        .clip(CircleShape)
                        .background(MaterialTheme.colorScheme.primary.copy(alpha = 0.15f)),
                    contentAlignment = Alignment.Center
                ) {
                    Icon(
                        imageVector = icon,
                        contentDescription = null,
                        tint = MaterialTheme.colorScheme.primary,
                        modifier = Modifier.size(18.dp)
                    )
                }
                Spacer(modifier = Modifier.width(10.dp))
                Text(
                    text = category.displayName,
                    fontWeight = FontWeight.Bold,
                    fontSize = 15.sp,
                    color = MaterialTheme.colorScheme.onSurface
                )
            }
            Spacer(modifier = Modifier.height(14.dp))
            HorizontalDivider(color = MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.4f))
            Spacer(modifier = Modifier.height(14.dp))

            content()
        }
    }
}
