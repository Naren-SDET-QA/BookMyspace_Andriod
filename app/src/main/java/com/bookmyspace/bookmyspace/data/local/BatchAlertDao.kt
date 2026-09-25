package com.bookmyspace.bookmyspace.data.local

import androidx.room.Dao
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.Query
import kotlinx.coroutines.flow.Flow

@Dao
interface BatchAlertDao {

    @Query("SELECT * FROM batch_availability_alerts ORDER BY subscribedAtEpochMs DESC")
    fun getAllAlerts(): Flow<List<BatchAlertEntity>>

    @Query("SELECT * FROM batch_availability_alerts WHERE classId = :classId LIMIT 1")
    suspend fun getAlertByClassId(classId: String): BatchAlertEntity?

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insertAlert(alert: BatchAlertEntity)

    @Query("DELETE FROM batch_availability_alerts WHERE classId = :classId")
    suspend fun deleteAlert(classId: String)

    @Query("UPDATE batch_availability_alerts SET isTriggered = 1, spotsAvailable = :spots WHERE classId = :classId")
    suspend fun markAlertTriggered(classId: String, spots: Int)

    @Query("DELETE FROM batch_availability_alerts")
    suspend fun clearAllAlerts()
}
