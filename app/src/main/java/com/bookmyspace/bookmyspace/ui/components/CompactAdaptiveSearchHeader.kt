package com.bookmyspace.bookmyspace.ui.components

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
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
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.window.Dialog
import java.text.SimpleDateFormat
import java.util.*

/**
 * Compact Adaptive Search Header that adapts fields automatically
 * based on selected category (Hotels, Function Halls, PG, Classes/Sports, All).
 */
@Composable
fun CompactAdaptiveSearchHeader(
    searchQuery: String,
    onSearchQueryChange: (String) -> Unit,
    categoryType: String, // "ALL", "HOTEL", "VENUE", "PG", "CLASS"
    locationText: String,
    onLocationClick: () -> Unit,
    checkInDate: String,
    checkOutDate: String?,
    onPickCheckInDate: () -> Unit,
    onPickCheckOutDate: () -> Unit,
    guestInfoText: String,
    onPickGuestInfo: () -> Unit,
    onSearchClick: () -> Unit,
    onVoiceClick: (() -> Unit)? = null,
    modifier: Modifier = Modifier
) {
    Card(
        modifier = modifier
            .fillMaxWidth()
            .testTag("compact_adaptive_search_header"),
        shape = RoundedCornerShape(16.dp),
        colors = CardDefaults.cardColors(
            containerColor = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.55f)
        ),
        border = BorderStroke(1.dp, MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.45f)),
        elevation = CardDefaults.cardElevation(defaultElevation = 2.dp)
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(12.dp),
            verticalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            // Row 1: Destination / Where to go input + Voice Button
            Row(
                modifier = Modifier.fillMaxWidth(),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                Surface(
                    modifier = Modifier
                        .weight(1f)
                        .height(46.dp),
                    shape = RoundedCornerShape(12.dp),
                    color = MaterialTheme.colorScheme.surface,
                    border = BorderStroke(1.dp, MaterialTheme.colorScheme.outline.copy(alpha = 0.25f))
                ) {
                    Row(
                        modifier = Modifier
                            .fillMaxSize()
                            .padding(horizontal = 10.dp),
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Icon(
                            imageVector = when (categoryType) {
                                "HOTEL" -> Icons.Default.Hotel
                                "VENUE" -> Icons.Default.Apartment
                                "PG" -> Icons.Default.Home
                                "CLASS" -> Icons.Default.School
                                else -> Icons.Default.Search
                            },
                            contentDescription = null,
                            tint = MaterialTheme.colorScheme.primary,
                            modifier = Modifier.size(18.dp)
                        )
                        Spacer(modifier = Modifier.width(8.dp))
                        androidx.compose.foundation.text.BasicTextField(
                            value = searchQuery,
                            onValueChange = onSearchQueryChange,
                            singleLine = true,
                            textStyle = MaterialTheme.typography.bodyMedium.copy(
                                color = MaterialTheme.colorScheme.onSurface,
                                fontSize = 13.5.sp,
                                fontWeight = FontWeight.Medium
                            ),
                            modifier = Modifier
                                .weight(1f)
                                .testTag("search_header_input"),
                            decorationBox = { innerTextField ->
                                if (searchQuery.isEmpty()) {
                                    val defaultPlaceholder = when (categoryType) {
                                        "HOTEL" -> "Where do you want to stay?"
                                        "VENUE" -> "Search halls, banquets, lawns..."
                                        "PG" -> "Search PG, co-living, hostel area..."
                                        "CLASS" -> "Search dance, music, sports, coaching..."
                                        else -> "Where do you want to go?"
                                    }
                                    val customPlaceholder = com.bookmyspace.bookmyspace.data.editor.DynamicElementManager.getPlaceholder("home_search_hint", defaultPlaceholder)
                                    Text(
                                        text = customPlaceholder,
                                        color = MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.7f),
                                        fontSize = 13.sp,
                                        maxLines = 1,
                                        overflow = TextOverflow.Ellipsis
                                    )
                                }
                                innerTextField()
                            }
                        )
                        if (searchQuery.isNotEmpty()) {
                            IconButton(
                                onClick = { onSearchQueryChange("") },
                                modifier = Modifier.size(24.dp)
                            ) {
                                Icon(
                                    imageVector = Icons.Default.Close,
                                    contentDescription = "Clear",
                                    tint = MaterialTheme.colorScheme.onSurfaceVariant,
                                    modifier = Modifier.size(14.dp)
                                )
                            }
                        }
                    }
                }

                // Quick Location Selector Button
                Surface(
                    onClick = onLocationClick,
                    shape = RoundedCornerShape(12.dp),
                    color = MaterialTheme.colorScheme.primaryContainer.copy(alpha = 0.7f),
                    modifier = Modifier
                        .height(46.dp)
                        .testTag("search_header_location_btn")
                ) {
                    Row(
                        modifier = Modifier.padding(horizontal = 10.dp),
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.spacedBy(4.dp)
                    ) {
                        Icon(
                            imageVector = Icons.Default.LocationOn,
                            contentDescription = "Location",
                            tint = MaterialTheme.colorScheme.primary,
                            modifier = Modifier.size(16.dp)
                        )
                        Text(
                            text = locationText,
                            fontSize = 12.sp,
                            fontWeight = FontWeight.Bold,
                            color = MaterialTheme.colorScheme.onPrimaryContainer,
                            maxLines = 1,
                            overflow = TextOverflow.Ellipsis,
                            modifier = Modifier.widthIn(max = 90.dp)
                        )
                    }
                }

                if (onVoiceClick != null) {
                    IconButton(
                        onClick = onVoiceClick,
                        modifier = Modifier
                            .size(46.dp)
                            .clip(RoundedCornerShape(12.dp))
                            .background(MaterialTheme.colorScheme.secondaryContainer)
                            .testTag("search_header_voice_btn")
                    ) {
                        Icon(
                            imageVector = Icons.Default.Mic,
                            contentDescription = "Voice Search",
                            tint = MaterialTheme.colorScheme.onSecondaryContainer,
                            modifier = Modifier.size(18.dp)
                        )
                    }
                }
            }

            // Row 2: Adaptive Dates & Guest Selectors
            when (categoryType) {
                "HOTEL" -> {
                    // Hotels: [ Check-in ] [ Check-out ]
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.spacedBy(8.dp)
                    ) {
                        SearchFilterMiniChip(
                            icon = Icons.Default.CalendarToday,
                            label = "Check-in",
                            value = checkInDate,
                            onClick = onPickCheckInDate,
                            modifier = Modifier.weight(1f)
                        )
                        SearchFilterMiniChip(
                            icon = Icons.Default.Event,
                            label = "Check-out",
                            value = checkOutDate ?: "Add Date",
                            onClick = onPickCheckOutDate,
                            modifier = Modifier.weight(1f)
                        )
                    }
                }
                "VENUE" -> {
                    // Function Hall: [ Event Date ] [ Guests Capacity ]
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.spacedBy(8.dp)
                    ) {
                        SearchFilterMiniChip(
                            icon = Icons.Default.EventAvailable,
                            label = "Event Date",
                            value = checkInDate,
                            onClick = onPickCheckInDate,
                            modifier = Modifier.weight(1f)
                        )
                        SearchFilterMiniChip(
                            icon = Icons.Default.Group,
                            label = "Guests",
                            value = guestInfoText,
                            onClick = onPickGuestInfo,
                            modifier = Modifier.weight(1f)
                        )
                    }
                }
                "PG" -> {
                    // PG: [ Move-in Date ] [ Sharing / Duration ]
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.spacedBy(8.dp)
                    ) {
                        SearchFilterMiniChip(
                            icon = Icons.Default.DateRange,
                            label = "Move-in Date",
                            value = checkInDate,
                            onClick = onPickCheckInDate,
                            modifier = Modifier.weight(1f)
                        )
                        SearchFilterMiniChip(
                            icon = Icons.Default.Bed,
                            label = "Room Sharing",
                            value = guestInfoText,
                            onClick = onPickGuestInfo,
                            modifier = Modifier.weight(1f)
                        )
                    }
                }
                "CLASS" -> {
                    // Classes/Sports: [ Date & Time ] [ Batch / Players ]
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.spacedBy(8.dp)
                    ) {
                        SearchFilterMiniChip(
                            icon = Icons.Default.Schedule,
                            label = "Date / Slot",
                            value = checkInDate,
                            onClick = onPickCheckInDate,
                            modifier = Modifier.weight(1f)
                        )
                        SearchFilterMiniChip(
                            icon = Icons.Default.Person,
                            label = "Attendees",
                            value = guestInfoText,
                            onClick = onPickGuestInfo,
                            modifier = Modifier.weight(1f)
                        )
                    }
                }
                else -> {
                    // ALL: [ Date ] [ Guests / Rooms ]
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.spacedBy(8.dp)
                    ) {
                        SearchFilterMiniChip(
                            icon = Icons.Default.CalendarToday,
                            label = "Date",
                            value = checkInDate,
                            onClick = onPickCheckInDate,
                            modifier = Modifier.weight(1f)
                        )
                        SearchFilterMiniChip(
                            icon = Icons.Default.Group,
                            label = "Guests",
                            value = guestInfoText,
                            onClick = onPickGuestInfo,
                            modifier = Modifier.weight(1f)
                        )
                    }
                }
            }

            // Row 3: For Hotels, guests/rooms row + Search Button
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(8.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                if (categoryType == "HOTEL") {
                    SearchFilterMiniChip(
                        icon = Icons.Default.People,
                        label = "Guests & Rooms",
                        value = guestInfoText,
                        onClick = onPickGuestInfo,
                        modifier = Modifier.weight(1f)
                    )
                }

                Button(
                    onClick = onSearchClick,
                    modifier = Modifier
                        .then(if (categoryType == "HOTEL") Modifier.weight(1f) else Modifier.fillMaxWidth())
                        .height(42.dp)
                        .testTag("search_header_cta_btn"),
                    shape = RoundedCornerShape(12.dp),
                    colors = ButtonDefaults.buttonColors(containerColor = MaterialTheme.colorScheme.primary),
                    contentPadding = PaddingValues(horizontal = 12.dp, vertical = 6.dp)
                ) {
                    Icon(
                        imageVector = Icons.Default.Search,
                        contentDescription = null,
                        modifier = Modifier.size(16.dp)
                    )
                    Spacer(modifier = Modifier.width(6.dp))
                    Text(
                        text = "Search Available",
                        fontSize = 13.sp,
                        fontWeight = FontWeight.Bold
                    )
                }
            }
        }
    }
}

@Composable
fun SearchFilterMiniChip(
    icon: ImageVector,
    label: String,
    value: String,
    onClick: () -> Unit,
    modifier: Modifier = Modifier
) {
    Surface(
        onClick = onClick,
        shape = RoundedCornerShape(12.dp),
        color = MaterialTheme.colorScheme.surface,
        border = BorderStroke(1.dp, MaterialTheme.colorScheme.outline.copy(alpha = 0.2f)),
        modifier = modifier.height(44.dp)
    ) {
        Row(
            modifier = Modifier
                .fillMaxSize()
                .padding(horizontal = 10.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Icon(
                imageVector = icon,
                contentDescription = label,
                tint = MaterialTheme.colorScheme.primary,
                modifier = Modifier.size(16.dp)
            )
            Spacer(modifier = Modifier.width(6.dp))
            Column(
                verticalArrangement = Arrangement.Center,
                modifier = Modifier.weight(1f)
            ) {
                Text(
                    text = label,
                    fontSize = 9.5.sp,
                    color = MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.75f),
                    lineHeight = 11.sp
                )
                Text(
                    text = value,
                    fontSize = 12.sp,
                    fontWeight = FontWeight.SemiBold,
                    color = MaterialTheme.colorScheme.onSurface,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                    lineHeight = 14.sp
                )
            }
        }
    }
}

/**
 * Compact Guest and Room Picker Dialog
 */
@Composable
fun GuestAndRoomPickerDialog(
    adults: Int,
    children: Int,
    rooms: Int,
    categoryType: String,
    onDismiss: () -> Unit,
    onApply: (adults: Int, children: Int, rooms: Int) -> Unit
) {
    var curAdults by remember { mutableIntStateOf(adults) }
    var curChildren by remember { mutableIntStateOf(children) }
    var curRooms by remember { mutableIntStateOf(rooms) }

    Dialog(onDismissRequest = onDismiss) {
        Card(
            shape = RoundedCornerShape(20.dp),
            colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface),
            border = BorderStroke(1.dp, MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.5f)),
            modifier = Modifier
                .fillMaxWidth()
                .padding(16.dp)
        ) {
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(20.dp),
                verticalArrangement = Arrangement.spacedBy(16.dp)
            ) {
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Text(
                        text = when (categoryType) {
                            "HOTEL" -> "Guests & Rooms"
                            "VENUE" -> "Expected Guests"
                            "PG" -> "Sharing & Occupants"
                            else -> "Guests & Capacity"
                        },
                        fontSize = 17.sp,
                        fontWeight = FontWeight.Bold,
                        color = MaterialTheme.colorScheme.onSurface
                    )
                    IconButton(onClick = onDismiss, modifier = Modifier.size(28.dp)) {
                        Icon(Icons.Default.Close, contentDescription = "Close", modifier = Modifier.size(18.dp))
                    }
                }

                HorizontalDivider(color = MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.4f))

                // Adults / Main Guests
                CounterRow(
                    label = if (categoryType == "VENUE") "Guests / Attendees" else "Adults (18+ yrs)",
                    subLabel = if (categoryType == "VENUE") "Approximate count" else "Primary occupants",
                    count = curAdults,
                    minCount = 1,
                    maxCount = if (categoryType == "VENUE") 5000 else 30,
                    step = if (categoryType == "VENUE") 50 else 1,
                    onCountChange = { curAdults = it }
                )

                if (categoryType == "HOTEL" || categoryType == "ALL") {
                    CounterRow(
                        label = "Children (0-17 yrs)",
                        subLabel = "With or without extra bed",
                        count = curChildren,
                        minCount = 0,
                        maxCount = 10,
                        step = 1,
                        onCountChange = { curChildren = it }
                    )

                    CounterRow(
                        label = "Rooms",
                        subLabel = "Total rooms needed",
                        count = curRooms,
                        minCount = 1,
                        maxCount = 20,
                        step = 1,
                        onCountChange = { curRooms = it }
                    )
                }

                Button(
                    onClick = {
                        onApply(curAdults, curChildren, curRooms)
                        onDismiss()
                    },
                    shape = RoundedCornerShape(12.dp),
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(44.dp)
                ) {
                    Text("Apply & Continue", fontWeight = FontWeight.Bold)
                }
            }
        }
    }
}

@Composable
private fun CounterRow(
    label: String,
    subLabel: String,
    count: Int,
    minCount: Int,
    maxCount: Int,
    step: Int,
    onCountChange: (Int) -> Unit
) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically
    ) {
        Column(modifier = Modifier.weight(1f)) {
            Text(text = label, fontWeight = FontWeight.SemiBold, fontSize = 14.sp)
            Text(text = subLabel, fontSize = 11.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
        }

        Row(
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            FilledTonalIconButton(
                onClick = { if (count > minCount) onCountChange(maxOf(minCount, count - step)) },
                enabled = count > minCount,
                shape = CircleShape,
                modifier = Modifier.size(34.dp)
            ) {
                Icon(Icons.Default.Remove, contentDescription = "Decrease", modifier = Modifier.size(16.dp))
            }

            Text(
                text = "$count",
                fontSize = 15.sp,
                fontWeight = FontWeight.Bold,
                color = MaterialTheme.colorScheme.onSurface,
                modifier = Modifier.widthIn(min = 28.dp),
                textAlign = androidx.compose.ui.text.style.TextAlign.Center
            )

            FilledTonalIconButton(
                onClick = { if (count < maxCount) onCountChange(minOf(maxCount, count + step)) },
                enabled = count < maxCount,
                shape = CircleShape,
                modifier = Modifier.size(34.dp)
            ) {
                Icon(Icons.Default.Add, contentDescription = "Increase", modifier = Modifier.size(16.dp))
            }
        }
    }
}

/**
 * Clean Date Selection Dialog with Today, Tomorrow, Weekend & Custom Date buttons
 */
@Composable
fun SimpleQuickDateDialog(
    title: String,
    currentDate: String,
    onDismiss: () -> Unit,
    onDateSelected: (String) -> Unit
) {
    val sdf = remember { SimpleDateFormat("EEE, dd MMM", Locale.US) }
    val todayCal = remember { Calendar.getInstance() }
    
    val todayStr = remember { sdf.format(todayCal.time) }
    val tomorrowStr = remember {
        val c = Calendar.getInstance().apply { add(Calendar.DAY_OF_YEAR, 1) }
        sdf.format(c.time)
    }
    val weekendStr = remember {
        val c = Calendar.getInstance().apply {
            val dayOfWeek = get(Calendar.DAY_OF_WEEK)
            val daysUntilSat = (Calendar.SATURDAY - dayOfWeek + 7) % 7
            add(Calendar.DAY_OF_YEAR, if (daysUntilSat == 0) 7 else daysUntilSat)
        }
        sdf.format(c.time)
    }
    val nextWeekStr = remember {
        val c = Calendar.getInstance().apply { add(Calendar.DAY_OF_YEAR, 7) }
        sdf.format(c.time)
    }

    Dialog(onDismissRequest = onDismiss) {
        Card(
            shape = RoundedCornerShape(20.dp),
            colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface),
            border = BorderStroke(1.dp, MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.5f)),
            modifier = Modifier
                .fillMaxWidth()
                .padding(16.dp)
        ) {
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(20.dp),
                verticalArrangement = Arrangement.spacedBy(12.dp)
            ) {
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Text(text = title, fontSize = 16.sp, fontWeight = FontWeight.Bold)
                    IconButton(onClick = onDismiss, modifier = Modifier.size(28.dp)) {
                        Icon(Icons.Default.Close, contentDescription = "Close", modifier = Modifier.size(18.dp))
                    }
                }

                HorizontalDivider(color = MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.4f))

                listOf(
                    "📅 Today" to todayStr,
                    "🌅 Tomorrow" to tomorrowStr,
                    "🎉 This Weekend" to weekendStr,
                    "🗓️ Next Week" to nextWeekStr
                ).forEach { (label, dateVal) ->
                    Surface(
                        onClick = {
                            onDateSelected(dateVal)
                            onDismiss()
                        },
                        shape = RoundedCornerShape(12.dp),
                        color = if (currentDate == dateVal) MaterialTheme.colorScheme.primaryContainer else MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.4f),
                        border = BorderStroke(1.dp, if (currentDate == dateVal) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.outline.copy(alpha = 0.2f)),
                        modifier = Modifier.fillMaxWidth()
                    ) {
                        Row(
                            modifier = Modifier
                                .fillMaxWidth()
                                .padding(horizontal = 14.dp, vertical = 12.dp),
                            horizontalArrangement = Arrangement.SpaceBetween,
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            Text(text = label, fontWeight = FontWeight.Medium, fontSize = 13.5.sp)
                            Text(
                                text = dateVal,
                                fontWeight = FontWeight.Bold,
                                fontSize = 13.sp,
                                color = if (currentDate == dateVal) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.onSurfaceVariant
                            )
                        }
                    }
                }
            }
        }
    }
}
