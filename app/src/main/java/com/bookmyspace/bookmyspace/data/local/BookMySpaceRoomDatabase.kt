package com.bookmyspace.bookmyspace.data.local

import android.content.Context
import android.util.Log
import androidx.room.Database
import androidx.room.Room
import androidx.room.RoomDatabase
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext

@Database(
    entities = [
        MapTileEntity::class,
        VenueMarkerEntity::class,
        ReviewEntity::class,
        RecentSearchEntity::class,
        PaymentTransactionEntity::class,
        BatchAlertEntity::class,
        DiscoveredPlaceEntity::class,
        LocationCacheEntity::class
    ],
    version = 5,
    exportSchema = false
)
abstract class BookMySpaceRoomDatabase : RoomDatabase() {

    abstract fun mapTileDao(): MapTileDao
    abstract fun venueMarkerDao(): VenueMarkerDao
    abstract fun reviewDao(): ReviewDao
    abstract fun recentSearchDao(): RecentSearchDao
    abstract fun paymentTransactionDao(): PaymentTransactionDao
    abstract fun batchAlertDao(): BatchAlertDao
    abstract fun discoveredPlaceDao(): DiscoveredPlaceDao
    abstract fun locationCacheDao(): LocationCacheDao

    companion object {
        @Volatile
        private var INSTANCE: BookMySpaceRoomDatabase? = null

        fun getDatabase(context: Context): BookMySpaceRoomDatabase {
            return INSTANCE ?: synchronized(this) {
                val instance = Room.databaseBuilder(
                    context.applicationContext,
                    BookMySpaceRoomDatabase::class.java,
                    "bookmyspace_local_db"
                )
                    .fallbackToDestructiveMigration()
                    .build()
                INSTANCE = instance
                instance
            }
        }

        /**
         * Prewarms the Room SQLite database on a background IO dispatcher.
         * Accessing writableDatabase forces SQLite driver initialization, schema verification,
         * and version checks ahead of time, ensuring subsequent UI queries never encounter
         * disk open delays or main-thread stalls during cold boot.
         */
        suspend fun prewarm(context: Context) = withContext(Dispatchers.IO) {
            try {
                val db = getDatabase(context)
                db.openHelper.writableDatabase
                Log.d("BookMySpaceRoomDB", "✅ Room Database prewarmed successfully in background")
            } catch (e: Exception) {
                Log.w("BookMySpaceRoomDB", "⚠️ Room Database prewarm notice: ${e.message}")
            }
        }
    }
}
