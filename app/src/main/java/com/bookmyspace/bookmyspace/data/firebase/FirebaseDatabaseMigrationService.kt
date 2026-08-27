package com.bookmyspace.bookmyspace.data.firebase

import android.content.Context
import android.util.Log
import com.bookmyspace.bookmyspace.data.editor.DynamicElementManager
import com.bookmyspace.bookmyspace.data.local.PaymentTransactionEntity
import com.bookmyspace.bookmyspace.data.local.ReviewEntity
import com.bookmyspace.bookmyspace.data.model.*
import com.bookmyspace.bookmyspace.data.repository.BookMySpaceRepository
import com.google.firebase.auth.FirebaseAuth
import com.google.firebase.firestore.FirebaseFirestore
import com.google.firebase.firestore.SetOptions
import com.google.firebase.firestore.WriteBatch
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import kotlinx.coroutines.tasks.await
import kotlinx.coroutines.withContext

/**
 * Migration Status Data Classes
 */
sealed class MigrationStatus {
    object Idle : MigrationStatus()
    data class InProgress(
        val currentCollection: String,
        val processedCollections: Int,
        val totalCollections: Int,
        val currentProgressPercent: Float,
        val message: String
    ) : MigrationStatus()
    data class Completed(
        val totalCollectionsMigrated: Int,
        val totalDocumentsMigrated: Int,
        val summaryMessage: String,
        val timestamp: Long = System.currentTimeMillis()
    ) : MigrationStatus()
    data class Failed(
        val error: String,
        val failedCollection: String? = null,
        val timestamp: Long = System.currentTimeMillis()
    ) : MigrationStatus()
}

data class CollectionMigrationStats(
    val collectionName: String,
    val displayName: String,
    val icon: String,
    val localCount: Int = 0,
    val cloudCount: Int = 0,
    val isSynced: Boolean = false,
    val lastSyncStatus: String = "Pending",
    val lastSyncTimeMillis: Long = 0L
)

data class CloudDatabaseHealthReport(
    val isConnected: Boolean = false,
    val projectId: String = "bookmyspace-app",
    val latencyMs: Long = 0L,
    val totalCloudDocuments: Int = 0,
    val collectionStats: List<CollectionMigrationStats> = emptyList(),
    val isAuthActive: Boolean = false,
    val currentUserEmail: String? = null,
    val logs: List<String> = emptyList()
)

/**
 * Universal Firebase Database Migration & Real-Time Sync Service.
 * Allows migrating all local application datasets (Venues, Hotels, PGs, Coaching Institutes,
 * Batches, Events, Bookings, Reviews, Payment Transactions, Dynamic UI Elements, and App Flags)
 * to Cloud Firestore.
 */
object FirebaseDatabaseMigrationService {
    private const val TAG = "FirebaseMigrationService"

    private var appContext: Context? = null
    private var firestoreDb: FirebaseFirestore? = null
    private val scope = CoroutineScope(Dispatchers.IO)

    private val _migrationStatus = MutableStateFlow<MigrationStatus>(MigrationStatus.Idle)
    val migrationStatus: StateFlow<MigrationStatus> = _migrationStatus.asStateFlow()

    private val _healthReport = MutableStateFlow(CloudDatabaseHealthReport())
    val healthReport: StateFlow<CloudDatabaseHealthReport> = _healthReport.asStateFlow()

    private val _collectionStatsList = MutableStateFlow<List<CollectionMigrationStats>>(emptyList())
    val collectionStatsList: StateFlow<List<CollectionMigrationStats>> = _collectionStatsList.asStateFlow()

    private val _migrationLogs = MutableStateFlow<List<String>>(emptyList())
    val migrationLogs: StateFlow<List<String>> = _migrationLogs.asStateFlow()

    fun initialize(context: Context) {
        appContext = context.applicationContext
        try {
            val resId = context.resources.getIdentifier("firestore_database_id", "string", context.packageName)
            val dbId = if (resId != 0) context.getString(resId) else "(default)"
            firestoreDb = if (dbId.isNotEmpty() && dbId != "(default)") {
                FirebaseFirestore.getInstance(dbId)
            } else {
                FirebaseFirestore.getInstance()
            }
            refreshHealthReport()
        } catch (e: Exception) {
            Log.e(TAG, "Error initializing Firestore Migration Service: ${e.message}", e)
            addLog("⚠️ Firestore Init Warning: ${e.message}")
        }
    }

    private fun addLog(message: String) {
        val timestamp = java.text.SimpleDateFormat("HH:mm:ss", java.util.Locale.getDefault()).format(java.util.Date())
        val formatted = "[$timestamp] $message"
        _migrationLogs.value = listOf(formatted) + _migrationLogs.value.take(49)
    }

    fun getFirestore(): FirebaseFirestore? {
        if (firestoreDb == null && appContext != null) {
            firestoreDb = FirebaseFirestore.getInstance()
        }
        return firestoreDb
    }

    /**
     * Run a comprehensive Cloud Health & Database Status Diagnostic
     */
    fun refreshHealthReport() {
        scope.launch {
            val db = getFirestore()
            if (db == null) {
                _healthReport.value = CloudDatabaseHealthReport(
                    isConnected = false,
                    logs = listOf("Firebase Firestore instance not available.")
                )
                return@launch
            }

            val startTime = System.currentTimeMillis()
            val stats = mutableListOf<CollectionMigrationStats>()
            val logs = mutableListOf<String>()

            val collectionsToInspect = listOf(
                Triple("venues", "Venues & Accommodations (Turf, Hotel, PG)", "🏟️"),
                Triple("institutes", "Coaching Institutes & Academies", "🎓"),
                Triple("courses", "Courses & Curriculums", "📚"),
                Triple("institute_classes", "Batches & Class Timings", "⏰"),
                Triple("events", "Events, Tournaments & Conferences", "🏆"),
                Triple("bookings", "Bookings & Slot Passes", "🎟️"),
                Triple("reviews", "Customer Ratings & Reviews", "⭐"),
                Triple("payment_transactions", "Payment Ledger & Transactions", "💳"),
                Triple("dynamic_elements", "Live UI Dynamic Elements & Texts", "✏️"),
                Triple("app_sections", "App Sections & Domain Toggles", "📂"),
                Triple("feature_configs", "Feature Module Flags & Limits", "⚙️"),
                Triple("configurable_fields", "Custom Registration Fields", "📝")
            )

            var totalCloudDocs = 0

            for ((colName, displayName, icon) in collectionsToInspect) {
                val localCount = getLocalCount(colName)
                var cloudCount = 0
                var syncStatus = "Ready"

                try {
                    val snapshot = db.collection(colName).limit(100).get().await()
                    cloudCount = snapshot.size()
                    totalCloudDocs += cloudCount
                    syncStatus = if (cloudCount > 0) "Synced ($cloudCount items in cloud)" else "Empty in Cloud"
                } catch (e: Exception) {
                    syncStatus = "Error: ${e.message?.take(30)}"
                    logs.add("Could not query collection $colName: ${e.message}")
                }

                stats.add(
                    CollectionMigrationStats(
                        collectionName = colName,
                        displayName = displayName,
                        icon = icon,
                        localCount = localCount,
                        cloudCount = cloudCount,
                        isSynced = cloudCount > 0,
                        lastSyncStatus = syncStatus,
                        lastSyncTimeMillis = System.currentTimeMillis()
                    )
                )
            }

            val latency = System.currentTimeMillis() - startTime
            val currentUser = try { FirebaseAuth.getInstance().currentUser } catch (_: Exception) { null }

            _collectionStatsList.value = stats
            _healthReport.value = CloudDatabaseHealthReport(
                isConnected = true,
                projectId = "bookmyspace-app",
                latencyMs = latency,
                totalCloudDocuments = totalCloudDocs,
                collectionStats = stats,
                isAuthActive = currentUser != null || BookMySpaceRepository.authUser.value != null,
                currentUserEmail = currentUser?.email ?: BookMySpaceRepository.authUser.value?.email,
                logs = logs
            )
            addLog("Health scan completed in ${latency}ms. Total Cloud Docs: $totalCloudDocs")
        }
    }

    private fun getLocalCount(collectionName: String): Int {
        return when (collectionName) {
            "venues" -> BookMySpaceRepository.venues.value.size
            "institutes" -> BookMySpaceRepository.institutes.value.size
            "courses" -> BookMySpaceRepository.courses.value.size
            "institute_classes" -> BookMySpaceRepository.instituteClasses.value.size
            "events" -> BookMySpaceRepository.events.value.size
            "bookings" -> BookMySpaceRepository.bookings.value.size
            "reviews" -> BookMySpaceRepository.reviews.value.size
            "payment_transactions" -> BookMySpaceRepository.paymentTransactions.value.size
            "dynamic_elements" -> DynamicElementManager.customElements.value.size
            "app_sections" -> BookMySpaceRepository.appSections.value.size
            "feature_configs" -> BookMySpaceRepository.featureConfigs.value.size
            "configurable_fields" -> BookMySpaceRepository.configurableFields.value.size
            else -> 0
        }
    }

    /**
     * Migrate All Local Data into Firebase Firestore with Real-Time Progress Tracking
     */
    fun migrateAllToFirebase() {
        scope.launch {
            val db = getFirestore()
            if (db == null) {
                _migrationStatus.value = MigrationStatus.Failed("Firebase Firestore is not initialized.")
                addLog("❌ Migration Failed: Firestore is null")
                return@launch
            }

            try {
                addLog("🚀 Starting complete database migration to Firebase Firestore...")
                _migrationStatus.value = MigrationStatus.InProgress(
                    currentCollection = "Initializing",
                    processedCollections = 0,
                    totalCollections = 12,
                    currentProgressPercent = 0.05f,
                    message = "Connecting to Firebase Firestore (bookmyspace-app)..."
                )

                val collections = listOf(
                    "venues", "institutes", "courses", "institute_classes",
                    "events", "bookings", "reviews", "payment_transactions",
                    "dynamic_elements", "app_sections", "feature_configs", "configurable_fields"
                )

                var totalDocsMigrated = 0

                for ((index, colName) in collections.withIndex()) {
                    val progress = (index + 1).toFloat() / collections.size.toFloat()
                    _migrationStatus.value = MigrationStatus.InProgress(
                        currentCollection = colName,
                        processedCollections = index,
                        totalCollections = collections.size,
                        currentProgressPercent = progress,
                        message = "Migrating $colName (${index + 1}/${collections.size})..."
                    )

                    val docsUploaded = migrateSingleCollectionInternal(db, colName)
                    totalDocsMigrated += docsUploaded
                    addLog("✅ Migrated $docsUploaded documents to collection: $colName")
                }

                _migrationStatus.value = MigrationStatus.Completed(
                    totalCollectionsMigrated = collections.size,
                    totalDocumentsMigrated = totalDocsMigrated,
                    summaryMessage = "Successfully migrated all 12 collections ($totalDocsMigrated documents) to Firebase Firestore!"
                )
                addLog("🎉 Complete Migration Finished! Total $totalDocsMigrated documents uploaded.")

                // Refresh health report and trigger live listeners
                refreshHealthReport()
                BookMySpaceRepository.attachAllFirestoreListeners()

            } catch (e: Exception) {
                Log.e(TAG, "Migration failed with exception: ${e.message}", e)
                _migrationStatus.value = MigrationStatus.Failed("Migration error: ${e.message}")
                addLog("❌ Migration Error: ${e.message}")
            }
        }
    }

    /**
     * Migrate an individual collection
     */
    fun migrateCollection(collectionName: String) {
        scope.launch {
            val db = getFirestore() ?: return@launch
            try {
                _migrationStatus.value = MigrationStatus.InProgress(
                    currentCollection = collectionName,
                    processedCollections = 0,
                    totalCollections = 1,
                    currentProgressPercent = 0.5f,
                    message = "Migrating $collectionName to Firebase..."
                )
                val count = migrateSingleCollectionInternal(db, collectionName)
                _migrationStatus.value = MigrationStatus.Completed(
                    totalCollectionsMigrated = 1,
                    totalDocumentsMigrated = count,
                    summaryMessage = "Successfully migrated $count documents in $collectionName."
                )
                addLog("✅ Single collection migration finished: $collectionName ($count docs)")
                refreshHealthReport()
            } catch (e: Exception) {
                _migrationStatus.value = MigrationStatus.Failed(e.message ?: "Unknown error", collectionName)
                addLog("❌ Error migrating $collectionName: ${e.message}")
            }
        }
    }

    private suspend fun migrateSingleCollectionInternal(db: FirebaseFirestore, collectionName: String): Int = withContext(Dispatchers.IO) {
        var count = 0
        when (collectionName) {
            "venues" -> {
                val venuesList = BookMySpaceRepository.venues.value
                val batch = db.batch()
                for (venue in venuesList) {
                    val docRef = db.collection("venues").document(venue.id)
                    val data = mapOf(
                        "id" to venue.id,
                        "name" to venue.name,
                        "slug" to venue.slug,
                        "description" to venue.description,
                        "addressLine1" to venue.addressLine1,
                        "city" to venue.city,
                        "state" to venue.state,
                        "latitude" to venue.latitude,
                        "longitude" to venue.longitude,
                        "capacity" to venue.capacity,
                        "pricingBaseAmount" to venue.pricingBaseAmount,
                        "taxRate" to venue.taxRate,
                        "parkingCapacity" to venue.parkingCapacity,
                        "foodOptions" to venue.foodOptions,
                        "rules" to venue.rules,
                        "isVerified" to venue.isVerified,
                        "isActive" to venue.isActive,
                        "avgRating" to venue.avgRating,
                        "ratingCount" to venue.ratingCount,
                        "featuredImageUrl" to venue.featuredImageUrl,
                        "coverImageUrl" to venue.coverImageUrl,
                        "contactPhone" to venue.contactPhone,
                        "contactWhatsapp" to venue.contactWhatsapp,
                        "categorySlug" to (venue.category?.slug ?: "sports"),
                        "categoryName" to (venue.category?.name ?: "Sports Turf"),
                        "facilities" to venue.facilities.map { it.facility },
                        "updatedAt" to System.currentTimeMillis()
                    )
                    batch.set(docRef, data, SetOptions.merge())
                    count++
                }
                batch.commit().await()
            }

            "institutes" -> {
                val institutes = BookMySpaceRepository.institutes.value
                val batch = db.batch()
                for (inst in institutes) {
                    val docRef = db.collection("institutes").document(inst.id)
                    val data = mapOf(
                        "id" to inst.id,
                        "name" to inst.name,
                        "tagline" to inst.tagline,
                        "description" to inst.description,
                        "logoUrl" to inst.logoUrl,
                        "coverImageUrl" to inst.coverImageUrl,
                        "category" to inst.category,
                        "city" to inst.city,
                        "state" to inst.state,
                        "address" to inst.address,
                        "rating" to inst.rating,
                        "ratingCount" to inst.ratingCount,
                        "isVerified" to inst.isVerified,
                        "isPublished" to inst.isPublished,
                        "amenities" to inst.amenities,
                        "email" to inst.email,
                        "phone" to inst.phone,
                        "whatsapp" to inst.whatsapp,
                        "updatedAt" to System.currentTimeMillis()
                    )
                    batch.set(docRef, data, SetOptions.merge())
                    count++
                }
                batch.commit().await()
            }

            "courses" -> {
                val courses = BookMySpaceRepository.courses.value
                val batch = db.batch()
                for (course in courses) {
                    val docRef = db.collection("courses").document(course.id)
                    val data = mapOf(
                        "id" to course.id,
                        "title" to course.title,
                        "academyName" to course.academyName,
                        "coachName" to course.coachName,
                        "description" to course.description,
                        "imageUrl" to course.imageUrl,
                        "durationWeeks" to course.durationWeeks,
                        "price" to course.price,
                        "level" to course.level,
                        "schedule" to course.schedule,
                        "rating" to course.rating,
                        "totalEnrolled" to course.totalEnrolled,
                        "updatedAt" to System.currentTimeMillis()
                    )
                    batch.set(docRef, data, SetOptions.merge())
                    count++
                }
                batch.commit().await()
            }

            "institute_classes" -> {
                val classes = BookMySpaceRepository.instituteClasses.value
                val batch = db.batch()
                for (cls in classes) {
                    val docRef = db.collection("institute_classes").document(cls.id)
                    val data = mapOf(
                        "id" to cls.id,
                        "instituteId" to cls.instituteId,
                        "instituteName" to cls.instituteName,
                        "title" to cls.title,
                        "category" to cls.category,
                        "description" to cls.description,
                        "deliveryMode" to cls.deliveryMode.name,
                        "ageGroup" to cls.ageGroup,
                        "feeAmount" to cls.feeAmount,
                        "monthlyFee" to cls.monthlyFee,
                        "durationText" to cls.durationText,
                        "rating" to cls.rating,
                        "coverImageUrl" to cls.coverImageUrl,
                        "isPublished" to cls.isPublished,
                        "contactPhone" to cls.contactPhone,
                        "contactWhatsapp" to cls.contactWhatsapp,
                        "updatedAt" to System.currentTimeMillis()
                    )
                    batch.set(docRef, data, SetOptions.merge())
                    count++
                }
                batch.commit().await()
            }

            "events" -> {
                val events = BookMySpaceRepository.events.value
                val batch = db.batch()
                for (event in events) {
                    val docRef = db.collection("events").document(event.id)
                    val data = mapOf(
                        "id" to event.id,
                        "title" to event.title,
                        "description" to event.description,
                        "venueName" to event.venueName,
                        "imageUrl" to event.imageUrl,
                        "eventDate" to event.eventDate,
                        "timeSlot" to event.timeSlot,
                        "ticketPrice" to event.ticketPrice,
                        "totalSeats" to event.totalSeats,
                        "seatsBooked" to event.seatsBooked,
                        "category" to event.category,
                        "updatedAt" to System.currentTimeMillis()
                    )
                    batch.set(docRef, data, SetOptions.merge())
                    count++
                }
                batch.commit().await()
            }

            "bookings" -> {
                val bookings = BookMySpaceRepository.bookings.value
                val batch = db.batch()
                for (b in bookings) {
                    val docRef = db.collection("bookings").document(b.id)
                    val data = mapOf(
                        "id" to b.id,
                        "bookingId" to b.id,
                        "userId" to b.userId,
                        "userName" to b.userName,
                        "userEmail" to b.userEmail,
                        "userPhone" to b.userPhone,
                        "venueId" to b.venueId,
                        "venueName" to b.venueName,
                        "bookingDate" to (b.bookingDate.ifBlank { b.date }),
                        "slotTime" to "${b.startTime} - ${b.endTime}",
                        "startTime" to b.startTime,
                        "endTime" to b.endTime,
                        "baseAmount" to b.baseAmount,
                        "taxAmount" to b.taxAmount,
                        "totalPrice" to b.totalPrice,
                        "totalAmount" to b.totalAmount,
                        "status" to b.status.name,
                        "paymentStatus" to b.paymentStatus,
                        "paymentMethod" to b.paymentMethod,
                        "qrCodeToken" to b.qrCodeToken,
                        "createdAt" to b.createdAt,
                        "updatedAt" to System.currentTimeMillis()
                    )
                    batch.set(docRef, data, SetOptions.merge())
                    count++
                }
                batch.commit().await()
            }

            "reviews" -> {
                val reviews = BookMySpaceRepository.reviews.value
                val batch = db.batch()
                for (r in reviews) {
                    val docRef = db.collection("reviews").document(r.id)
                    val data = mapOf(
                        "id" to r.id,
                        "reviewId" to r.id,
                        "venueId" to r.venueId,
                        "userName" to r.userName,
                        "rating" to r.rating,
                        "comment" to r.comment,
                        "date" to r.date,
                        "createdAt" to System.currentTimeMillis()
                    )
                    batch.set(docRef, data, SetOptions.merge())
                    count++
                }
                batch.commit().await()
            }

            "payment_transactions" -> {
                val txs = BookMySpaceRepository.paymentTransactions.value
                val batch = db.batch()
                for (t in txs) {
                    val docRef = db.collection("payment_transactions").document(t.transactionId)
                    val data = mapOf(
                        "transactionId" to t.transactionId,
                        "bookingId" to t.bookingId,
                        "venueId" to t.venueId,
                        "venueName" to t.venueName,
                        "amount" to t.amount,
                        "currency" to t.currency,
                        "paymentStatus" to t.paymentStatus,
                        "paymentMethod" to t.paymentMethod,
                        "razorpayOrderId" to (t.razorpayOrderId ?: ""),
                        "razorpaySignature" to (t.razorpaySignature ?: ""),
                        "customerName" to t.customerName,
                        "customerEmail" to t.customerEmail,
                        "customerPhone" to t.customerPhone,
                        "timestamp" to t.timestamp,
                        "notes" to t.notes
                    )
                    batch.set(docRef, data, SetOptions.merge())
                    count++
                }
                batch.commit().await()
            }

            "dynamic_elements" -> {
                val elements = DynamicElementManager.customElements.value
                val batch = db.batch()
                for ((key, elem) in elements) {
                    val docRef = db.collection("dynamic_elements").document(key)
                    val data = mapOf(
                        "key" to elem.key,
                        "screenName" to elem.screenName,
                        "elementType" to elem.elementType.name,
                        "displayName" to elem.displayName,
                        "description" to elem.description,
                        "currentValue" to elem.currentValue,
                        "defaultValue" to elem.defaultValue,
                        "placeholder" to (elem.placeholder ?: ""),
                        "defaultPlaceholder" to (elem.defaultPlaceholder ?: ""),
                        "colorHex" to (elem.colorHex ?: 0L),
                        "fontSizeSp" to (elem.fontSizeSp ?: 14f),
                        "fontWeightName" to elem.fontWeightName,
                        "isVisible" to elem.isVisible,
                        "updatedAt" to System.currentTimeMillis()
                    )
                    batch.set(docRef, data, SetOptions.merge())
                    count++
                }
                batch.commit().await()
            }

            "app_sections" -> {
                val sections = BookMySpaceRepository.appSections.value
                val batch = db.batch()
                for (sec in sections) {
                    val docRef = db.collection("app_sections").document(sec.sectionId)
                    val data = mapOf(
                        "sectionId" to sec.sectionId,
                        "title" to sec.title,
                        "subtitle" to sec.subtitle,
                        "emoji" to sec.emoji,
                        "iconName" to sec.iconName,
                        "isEnabled" to sec.isEnabled,
                        "displayOrder" to sec.displayOrder,
                        "subCategories" to sec.subCategories,
                        "quickOptions" to sec.quickOptions,
                        "updatedAt" to System.currentTimeMillis()
                    )
                    batch.set(docRef, data, SetOptions.merge())
                    count++
                }
                batch.commit().await()
            }

            "feature_configs" -> {
                val configs = BookMySpaceRepository.featureConfigs.value
                val batch = db.batch()
                for (fc in configs) {
                    val docRef = db.collection("feature_configs").document(fc.key.id)
                    val data = mapOf(
                        "id" to fc.key.id,
                        "keyName" to fc.key.name,
                        "displayName" to fc.title,
                        "category" to fc.key.category.name,
                        "summary" to fc.description,
                        "isEnabled" to fc.isEnabled,
                        "customTitle" to fc.customTitle,
                        "customDescription" to fc.customDescription,
                        "parameters" to fc.parameters,
                        "updatedAt" to System.currentTimeMillis()
                    )
                    batch.set(docRef, data, SetOptions.merge())
                    count++
                }
                batch.commit().await()
            }

            "configurable_fields" -> {
                val fields = BookMySpaceRepository.configurableFields.value
                val batch = db.batch()
                for (cf in fields) {
                    val docRef = db.collection("configurable_fields").document(cf.id)
                    val data = mapOf(
                        "id" to cf.id,
                        "name" to cf.name,
                        "label" to cf.label,
                        "fieldType" to cf.fieldType.name,
                        "required" to cf.required,
                        "targetCategory" to cf.targetCategory.name,
                        "placeholder" to cf.placeholder,
                        "defaultValue" to cf.defaultValue,
                        "options" to cf.options,
                        "displayOrder" to cf.displayOrder,
                        "isActive" to cf.isActive,
                        "updatedAt" to System.currentTimeMillis()
                    )
                    batch.set(docRef, data, SetOptions.merge())
                    count++
                }
                batch.commit().await()
            }
        }
        count
    }

    /**
     * Pull remote cloud documents from Firestore into local application memory
     */
    fun pullAllFromFirebase() {
        scope.launch {
            val db = getFirestore() ?: return@launch
            try {
                addLog("📥 Pulling remote records from Firebase Firestore...")
                _migrationStatus.value = MigrationStatus.InProgress(
                    currentCollection = "venues",
                    processedCollections = 0,
                    totalCollections = 6,
                    currentProgressPercent = 0.2f,
                    message = "Fetching venues from Firebase..."
                )

                // 1. Venues
                val venueSnap = db.collection("venues").get().await()
                if (!venueSnap.isEmpty) {
                    val cloudVenues = venueSnap.documents.mapNotNull { doc ->
                        val id = doc.getString("id") ?: doc.id
                        val name = doc.getString("name") ?: return@mapNotNull null
                        Venue(
                            id = id,
                            name = name,
                            slug = doc.getString("slug") ?: "",
                            description = doc.getString("description") ?: "",
                            addressLine1 = doc.getString("addressLine1") ?: "",
                            city = doc.getString("city") ?: "Hyderabad",
                            state = doc.getString("state") ?: "Telangana",
                            latitude = doc.getDouble("latitude") ?: 17.3850,
                            longitude = doc.getDouble("longitude") ?: 78.4866,
                            capacity = doc.getLong("capacity")?.toInt() ?: 500,
                            pricingBaseAmount = doc.getDouble("pricingBaseAmount") ?: 75000.0,
                            taxRate = doc.getDouble("taxRate") ?: 18.0,
                            parkingCapacity = doc.getLong("parkingCapacity")?.toInt() ?: 100,
                            foodOptions = doc.getString("foodOptions") ?: "In-house Catering",
                            rules = doc.getString("rules") ?: "Standard policy",
                            isVerified = doc.getBoolean("isVerified") ?: true,
                            isActive = doc.getBoolean("isActive") ?: true,
                            avgRating = doc.getDouble("avgRating") ?: 4.8,
                            ratingCount = doc.getLong("ratingCount")?.toInt() ?: 120,
                            featuredImageUrl = doc.getString("featuredImageUrl") ?: "",
                            contactPhone = doc.getString("contactPhone") ?: "98765-43210",
                            contactWhatsapp = doc.getString("contactWhatsapp") ?: "919876543210"
                        )
                    }
                    if (cloudVenues.isNotEmpty()) {
                        BookMySpaceRepository.setCloudVenues(cloudVenues)
                        addLog("📥 Pulled ${cloudVenues.size} venues from Firestore")
                    }
                }

                // 2. Institutes
                val instSnap = db.collection("institutes").get().await()
                if (!instSnap.isEmpty) {
                    val cloudInstitutes = instSnap.documents.mapNotNull { doc ->
                        val id = doc.getString("id") ?: doc.id
                        val name = doc.getString("name") ?: return@mapNotNull null
                        InstituteProfile(
                            id = id,
                            name = name,
                            tagline = doc.getString("tagline") ?: "",
                            description = doc.getString("description") ?: "",
                            logoUrl = doc.getString("logoUrl") ?: "",
                            coverImageUrl = doc.getString("coverImageUrl") ?: "",
                            category = doc.getString("category") ?: "Sports Coaching",
                            city = doc.getString("city") ?: "Hyderabad",
                            state = doc.getString("state") ?: "Telangana",
                            address = doc.getString("address") ?: "",
                            phone = doc.getString("phone") ?: "",
                            whatsapp = doc.getString("whatsapp") ?: "",
                            email = doc.getString("email") ?: "",
                            rating = doc.getDouble("rating") ?: 4.9,
                            ratingCount = doc.getLong("ratingCount")?.toInt() ?: 80,
                            isVerified = doc.getBoolean("isVerified") ?: true,
                            isPublished = doc.getBoolean("isPublished") ?: true,
                            amenities = (doc.get("amenities") as? List<*>)?.mapNotNull { it?.toString() } ?: emptyList()
                        )
                    }
                    if (cloudInstitutes.isNotEmpty()) {
                        BookMySpaceRepository.setCloudInstitutes(cloudInstitutes)
                        addLog("📥 Pulled ${cloudInstitutes.size} institutes from Firestore")
                    }
                }

                // 3. Dynamic Elements
                val elemSnap = db.collection("dynamic_elements").get().await()
                if (!elemSnap.isEmpty) {
                    val map = mutableMapOf<String, AdminElementConfig>()
                    for (doc in elemSnap.documents) {
                        val key = doc.getString("key") ?: doc.id
                        val typeStr = doc.getString("elementType") ?: "TEXT"
                        val type = try { AdminElementType.valueOf(typeStr) } catch (_: Exception) { AdminElementType.TEXT }
                        map[key] = AdminElementConfig(
                            key = key,
                            screenName = doc.getString("screenName") ?: "Home",
                            elementType = type,
                            displayName = doc.getString("displayName") ?: key,
                            description = doc.getString("description") ?: "",
                            currentValue = doc.getString("currentValue") ?: "",
                            defaultValue = doc.getString("defaultValue") ?: "",
                            placeholder = doc.getString("placeholder"),
                            defaultPlaceholder = doc.getString("defaultPlaceholder"),
                            colorHex = doc.getLong("colorHex"),
                            fontSizeSp = doc.getDouble("fontSizeSp")?.toFloat(),
                            fontWeightName = doc.getString("fontWeightName") ?: "Normal",
                            isVisible = doc.getBoolean("isVisible") ?: true
                        )
                    }
                    if (map.isNotEmpty()) {
                        DynamicElementManager.applyCloudElements(map)
                        addLog("📥 Pulled ${map.size} live dynamic elements from Firestore")
                    }
                }

                _migrationStatus.value = MigrationStatus.Completed(
                    totalCollectionsMigrated = 3,
                    totalDocumentsMigrated = venueSnap.size() + instSnap.size() + elemSnap.size(),
                    summaryMessage = "Cloud sync pull completed successfully!"
                )
                refreshHealthReport()
            } catch (e: Exception) {
                _migrationStatus.value = MigrationStatus.Failed(e.message ?: "Sync pull failed")
                addLog("❌ Sync pull error: ${e.message}")
            }
        }
    }

    fun resetMigrationStatus() {
        _migrationStatus.value = MigrationStatus.Idle
    }
}
