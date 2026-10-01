package com.bookmyspace.bookmyspace.data.local

import androidx.room.Entity
import androidx.room.PrimaryKey

@Entity(tableName = "batch_availability_alerts")
data class BatchAlertEntity(
    @PrimaryKey
    val classId: String,
    val className: String,
    val instituteName: String,
    val category: String,
    val batchType: String,
    val batchStartDate: String,
    val timings: String,
    val feeAmount: Double,
    val userEmail: String = "",
    val userPhone: String = "",
    val subscribedAtEpochMs: Long = System.currentTimeMillis(),
    val isTriggered: Boolean = false,
    val spotsAvailable: Int = 0
)
