package com.bookmyspace.bookmyspace.ui.components

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.bookmyspace.bookmyspace.data.model.Venue

@Composable
fun VenueOptimizerDashboard(
    venues: List<Venue>,
    modifier: Modifier = Modifier
) {
    var selectedVenueId by remember { mutableStateOf(venues.firstOrNull()?.id ?: "") }
    val currentVenue = remember(selectedVenueId, venues) {
        venues.firstOrNull { it.id == selectedVenueId } ?: venues.firstOrNull()
    }

    var dynamicPricingEnabled by remember { mutableStateOf(true) }
    var offPeakDiscountPercent by remember { mutableFloatStateOf(15f) }
    var weekendSurchargePercent by remember { mutableFloatStateOf(20f) }

    Column(
        modifier = modifier
            .fillMaxWidth()
            .testTag("venue_optimizer_dashboard"),
        verticalArrangement = Arrangement.spacedBy(14.dp)
    ) {
        // Header Card
        Card(
            modifier = Modifier.fillMaxWidth(),
            shape = RoundedCornerShape(16.dp),
            colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.primaryContainer)
        ) {
            Column(modifier = Modifier.padding(16.dp)) {
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Column {
                        Text(
                            text = "⚡ AI Venue Yield Optimizer",
                            fontSize = 16.sp,
                            fontWeight = FontWeight.Bold,
                            color = MaterialTheme.colorScheme.onPrimaryContainer
                        )
                        Text(
                            text = "Real-time occupancy & dynamic revenue simulation",
                            fontSize = 11.sp,
                            color = MaterialTheme.colorScheme.onPrimaryContainer.copy(alpha = 0.8f)
                        )
                    }
                    Surface(
                        color = MaterialTheme.colorScheme.primary,
                        shape = RoundedCornerShape(8.dp)
                    ) {
                        Text(
                            text = "PRO ENGINE",
                            fontSize = 10.sp,
                            fontWeight = FontWeight.ExtraBold,
                            color = Color.White,
                            modifier = Modifier.padding(horizontal = 6.dp, vertical = 3.dp)
                        )
                    }
                }

                Spacer(modifier = Modifier.height(14.dp))

                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween
                ) {
                    Column {
                        Text("ESTIMATED OCCUPANCY", fontSize = 10.sp, fontWeight = FontWeight.Bold, color = MaterialTheme.colorScheme.onPrimaryContainer.copy(alpha = 0.7f))
                        Text("84.2%", fontSize = 18.sp, fontWeight = FontWeight.ExtraBold, color = MaterialTheme.colorScheme.onPrimaryContainer)
                    }
                    Column {
                        Text("YIELD REVENUE LIFT", fontSize = 10.sp, fontWeight = FontWeight.Bold, color = MaterialTheme.colorScheme.onPrimaryContainer.copy(alpha = 0.7f))
                        Text("+₹18,400/mo", fontSize = 18.sp, fontWeight = FontWeight.ExtraBold, color = MaterialTheme.colorScheme.primary)
                    }
                    Column {
                        Text("RECOMMENDATIONS", fontSize = 10.sp, fontWeight = FontWeight.Bold, color = MaterialTheme.colorScheme.onPrimaryContainer.copy(alpha = 0.7f))
                        Text("4 Active", fontSize = 18.sp, fontWeight = FontWeight.ExtraBold, color = MaterialTheme.colorScheme.onPrimaryContainer)
                    }
                }
            }
        }

        // Optimization Controls Card
        Card(
            modifier = Modifier.fillMaxWidth(),
            shape = RoundedCornerShape(16.dp),
            colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface)
        ) {
            Column(modifier = Modifier.padding(16.dp)) {
                Text("Dynamic Pricing Configuration", fontWeight = FontWeight.Bold, fontSize = 14.sp)
                Spacer(modifier = Modifier.height(10.dp))

                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Column(modifier = Modifier.weight(1f)) {
                        Text("Automated Peak / Off-Peak Yield", fontWeight = FontWeight.SemiBold, fontSize = 13.sp)
                        Text("Automatically discounts slow morning hours and adds prime surcharge to evening slots", fontSize = 11.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                    }
                    Switch(
                        checked = dynamicPricingEnabled,
                        onCheckedChange = { dynamicPricingEnabled = it }
                    )
                }

                if (dynamicPricingEnabled) {
                    Spacer(modifier = Modifier.height(12.dp))
                    Text("Off-Peak Slot Discount: ${offPeakDiscountPercent.toInt()}%", fontSize = 12.sp, fontWeight = FontWeight.Medium)
                    Slider(
                        value = offPeakDiscountPercent,
                        onValueChange = { offPeakDiscountPercent = it },
                        valueRange = 5f..40f,
                        steps = 6
                    )

                    Spacer(modifier = Modifier.height(6.dp))
                    Text("Weekend Prime Slot Surcharge: ${weekendSurchargePercent.toInt()}%", fontSize = 12.sp, fontWeight = FontWeight.Medium)
                    Slider(
                        value = weekendSurchargePercent,
                        onValueChange = { weekendSurchargePercent = it },
                        valueRange = 5f..50f,
                        steps = 8
                    )
                }
            }
        }

        // AI Slot Utilization Breakdown Card
        Card(
            modifier = Modifier.fillMaxWidth(),
            shape = RoundedCornerShape(16.dp),
            colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.5f))
        ) {
            Column(modifier = Modifier.padding(16.dp)) {
                Text("Simulated Slot Demand Heatmap", fontWeight = FontWeight.Bold, fontSize = 14.sp)
                Text("Weekly booking density across time windows", fontSize = 11.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                Spacer(modifier = Modifier.height(12.dp))

                val slots = listOf(
                    Triple("Morning (06:00 - 11:00)", 0.35f, "🟢 Best time for 15% discount promo"),
                    Triple("Afternoon (11:00 - 16:00)", 0.55f, "🟡 Moderate demand, standard pricing"),
                    Triple("Evening (16:00 - 21:00)", 0.92f, "🔥 High demand prime, apply +20% surge"),
                    Triple("Night (21:00 - 00:00)", 0.40f, "🟢 Steady late-night bookings")
                )

                slots.forEach { (label, ratio, tip) ->
                    Column(modifier = Modifier.padding(vertical = 4.dp)) {
                        Row(
                            modifier = Modifier.fillMaxWidth(),
                            horizontalArrangement = Arrangement.SpaceBetween
                        ) {
                            Text(label, fontSize = 12.sp, fontWeight = FontWeight.SemiBold)
                            Text("${(ratio * 100).toInt()}% fill", fontSize = 12.sp, fontWeight = FontWeight.Bold, color = MaterialTheme.colorScheme.primary)
                        }
                        Spacer(modifier = Modifier.height(4.dp))
                        LinearProgressIndicator(
                            progress = { ratio },
                            modifier = Modifier
                                .fillMaxWidth()
                                .height(8.dp)
                                .clip(RoundedCornerShape(4.dp)),
                            color = if (ratio > 0.8f) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.secondary
                        )
                        Spacer(modifier = Modifier.height(2.dp))
                        Text(tip, fontSize = 10.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                    }
                }
            }
        }
    }
}
