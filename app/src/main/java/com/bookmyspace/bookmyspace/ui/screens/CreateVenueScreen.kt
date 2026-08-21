package com.bookmyspace.bookmyspace.ui.screens

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.bookmyspace.bookmyspace.data.model.TimeSlot
import com.bookmyspace.bookmyspace.data.model.Venue
import com.bookmyspace.bookmyspace.data.model.VenueCategory
import com.bookmyspace.bookmyspace.data.model.VenueImage
import com.bookmyspace.bookmyspace.data.repository.BookMySpaceRepository
import java.util.UUID

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun CreateVenueScreen(
    onVenueCreated: () -> Unit,
    onBack: () -> Unit,
    modifier: Modifier = Modifier
) {
    val categories by BookMySpaceRepository.categories.collectAsState()

    var venueName by remember { mutableStateOf("") }
    var description by remember { mutableStateOf("") }
    var address by remember { mutableStateOf("") }
    var city by remember { mutableStateOf("Hyderabad") }
    var priceStr by remember { mutableStateOf("1500") }
    var capacityStr by remember { mutableStateOf("100") }
    var selectedCategory by remember { mutableStateOf(categories.firstOrNull()) }
    var isSaving by remember { mutableStateOf(false) }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("List New Space 🏛️", fontWeight = FontWeight.Bold, fontSize = 18.sp) },
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(Icons.Default.ArrowBack, contentDescription = "Back")
                    }
                },
                colors = TopAppBarDefaults.topAppBarColors(containerColor = MaterialTheme.colorScheme.surface)
            )
        },
        bottomBar = {
            Surface(shadowElevation = 8.dp) {
                Button(
                    onClick = {
                        if (venueName.isNotBlank()) {
                            isSaving = true
                            val newVenue = Venue(
                                id = "v_${UUID.randomUUID().toString().take(6)}",
                                name = venueName.trim(),
                                description = description.trim(),
                                addressLine1 = address.trim(),
                                city = city.trim(),
                                pricingBaseAmount = priceStr.toDoubleOrNull() ?: 1000.0,
                                capacity = capacityStr.toIntOrNull() ?: 100,
                                category = selectedCategory,
                                images = listOf(VenueImage(id = "img_1", url = "https://images.unsplash.com/photo-1519167758481-83f550bb49b3", altText = "Front View", isCover = true)),
                                timeSlots = listOf(
                                    TimeSlot("sl_1", "06:00 AM - 07:00 AM", "06:00", "07:00", priceStr.toDoubleOrNull() ?: 1000.0),
                                    TimeSlot("sl_2", "07:00 AM - 08:00 AM", "07:00", "08:00", priceStr.toDoubleOrNull() ?: 1000.0),
                                    TimeSlot("sl_3", "08:00 AM - 09:00 AM", "08:00", "09:00", priceStr.toDoubleOrNull() ?: 1000.0),
                                    TimeSlot("sl_4", "06:00 PM - 07:00 PM", "18:00", "19:00", priceStr.toDoubleOrNull() ?: 1000.0)
                                )
                            )
                            BookMySpaceRepository.saveVenue(newVenue)
                            onVenueCreated()
                        }
                    },
                    enabled = venueName.isNotBlank() && !isSaving,
                    shape = RoundedCornerShape(12.dp),
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(16.dp)
                ) {
                    Text("Publish Space Listing 🚀", fontWeight = FontWeight.Bold)
                }
            }
        },
        modifier = modifier.testTag("create_venue_screen")
    ) { paddingValues ->
        LazyColumn(
            modifier = Modifier
                .fillMaxSize()
                .padding(paddingValues)
                .padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(14.dp)
        ) {
            item {
                OutlinedTextField(
                    value = venueName,
                    onValueChange = { venueName = it },
                    label = { Text("Venue / Court Name *") },
                    placeholder = { Text("e.g. Smash Pro Badminton Arena") },
                    modifier = Modifier.fillMaxWidth(),
                    singleLine = true
                )
            }

            item {
                OutlinedTextField(
                    value = description,
                    onValueChange = { description = it },
                    label = { Text("Overview & Features") },
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(90.dp),
                    maxLines = 3
                )
            }

            item {
                Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                    OutlinedTextField(
                        value = priceStr,
                        onValueChange = { priceStr = it },
                        label = { Text("Base Price (₹) *") },
                        modifier = Modifier.weight(1f),
                        singleLine = true
                    )
                    OutlinedTextField(
                        value = capacityStr,
                        onValueChange = { capacityStr = it },
                        label = { Text("Capacity") },
                        modifier = Modifier.weight(1f),
                        singleLine = true
                    )
                }
            }

            item {
                OutlinedTextField(
                    value = address,
                    onValueChange = { address = it },
                    label = { Text("Address / Landmark") },
                    modifier = Modifier.fillMaxWidth(),
                    singleLine = true
                )
            }

            item {
                OutlinedTextField(
                    value = city,
                    onValueChange = { city = it },
                    label = { Text("City") },
                    modifier = Modifier.fillMaxWidth(),
                    singleLine = true
                )
            }
        }
    }
}
