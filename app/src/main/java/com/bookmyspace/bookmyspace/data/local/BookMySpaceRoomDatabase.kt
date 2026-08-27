package com.bookmyspace.bookmyspace.data.local

import android.content.Context
import androidx.room.Database
import androidx.room.Room
import androidx.room.RoomDatabase

@Database(
    entities = [
        MapTileEntity::class,
        VenueMarkerEntity::class,
        ReviewEntity::class,
        RecentSearchEntity::class,
        PaymentTransactionEntity::class,
        BatchAlertEntity::class
    ],
    version = 4,
    exportSchema = false
)
abstract class BookMySpaceRoomDatabase : RoomDatabase() {

    abstract fun mapTileDao(): MapTileDao
    abstract fun venueMarkerDao(): VenueMarkerDao
    abstract fun reviewDao(): ReviewDao
    abstract fun recentSearchDao(): RecentSearchDao
    abstract fun paymentTransactionDao(): PaymentTransactionDao
    abstract fun batchAlertDao(): BatchAlertDao

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
    }
}
