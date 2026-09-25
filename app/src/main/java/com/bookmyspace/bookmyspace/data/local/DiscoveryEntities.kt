package com.bookmyspace.bookmyspace.data.local

import androidx.room.*
import kotlinx.coroutines.flow.Flow

/**
 * Cached Discovered Place in Room Database
 */
@Entity(tableName = "discovered_places")
data class DiscoveredPlaceEntity(
    @PrimaryKey
    val id: String,
    val name: String,
    val category: String,
    val categorySlug: String,
    val address: String,
    val state: String,
    val district: String,
    val mandal: String,
    val town: String,
    val pincode: String,
    val latitude: Double,
    val longitude: Double,
    val phone: String,
    val website: String,
    val openingHours: String,
    val rating: Double,
    val reviewCount: Int,
    val photoUrl: String,
    val source: String,
    val sourcePlaceId: String,
    val isRegisteredInBookMySpace: Boolean,
    val bookMySpaceVenueId: String?,
    val claimStatus: String,
    val pricingEstimate: String,
    val facilitiesJson: String,
    val searchLatitude: Double,
    val searchLongitude: Double,
    val searchRadiusKm: Double,
    val cachedAt: Long = System.currentTimeMillis()
)

/**
 * Cached Geocoded / Indian Postal PIN Location
 */
@Entity(tableName = "location_cache")
data class LocationCacheEntity(
    @PrimaryKey
    val queryKey: String, // e.g. "PIN_516227" or "LOC_14.74_79.05"
    val pincode: String,
    val state: String,
    val district: String,
    val mandal: String,
    val town: String,
    val localitiesJson: String,
    val latitude: Double,
    val longitude: Double,
    val cachedAt: Long = System.currentTimeMillis()
)

@Dao
interface DiscoveredPlaceDao {
    @Query("SELECT * FROM discovered_places WHERE isRegisteredInBookMySpace = :onlyRegistered ORDER BY cachedAt DESC")
    fun getDiscoveredPlaces(onlyRegistered: Boolean): Flow<List<DiscoveredPlaceEntity>>

    @Query("SELECT * FROM discovered_places ORDER BY cachedAt DESC LIMIT 200")
    fun getAllDiscoveredPlaces(): Flow<List<DiscoveredPlaceEntity>>

    @Query("SELECT * FROM discovered_places ORDER BY cachedAt DESC LIMIT 200")
    suspend fun getDiscoveredPlacesList(): List<DiscoveredPlaceEntity>

    @Query("SELECT COUNT(*) FROM discovered_places")
    suspend fun getCachedCount(): Int

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insertPlaces(places: List<DiscoveredPlaceEntity>)

    @Query("DELETE FROM discovered_places WHERE cachedAt < :expiryTimestamp")
    suspend fun clearOldPlaces(expiryTimestamp: Long)

    @Query("DELETE FROM discovered_places WHERE cachedAt < :expiryTimestamp")
    suspend fun deleteOlderThan(expiryTimestamp: Long): Int

    @Query("DELETE FROM discovered_places")
    suspend fun clearAll()
}

@Dao
interface LocationCacheDao {
    @Query("SELECT * FROM location_cache WHERE queryKey = :key LIMIT 1")
    suspend fun getByKey(key: String): LocationCacheEntity?

    @Query("SELECT COUNT(*) FROM location_cache")
    suspend fun getCachedCount(): Int

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insertCache(cache: LocationCacheEntity)

    @Query("DELETE FROM location_cache WHERE cachedAt < :expiryTimestamp")
    suspend fun clearOldCache(expiryTimestamp: Long)

    @Query("DELETE FROM location_cache WHERE cachedAt < :expiryTimestamp")
    suspend fun deleteOlderThan(expiryTimestamp: Long): Int

    @Query("DELETE FROM location_cache")
    suspend fun clearAll()
}
