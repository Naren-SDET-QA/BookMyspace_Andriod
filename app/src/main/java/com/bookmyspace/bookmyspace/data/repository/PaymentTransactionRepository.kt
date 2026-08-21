package com.bookmyspace.bookmyspace.data.repository

import android.content.Context
import com.bookmyspace.bookmyspace.data.local.BookMySpaceRoomDatabase
import com.bookmyspace.bookmyspace.data.local.PaymentTransactionDao
import com.bookmyspace.bookmyspace.data.local.PaymentTransactionEntity
import kotlinx.coroutines.flow.Flow

/**
 * Repository providing clean, reactive abstraction over Room-persisted
 * payment transaction history and records.
 */
class PaymentTransactionRepository(
    private val paymentTransactionDao: PaymentTransactionDao
) {
    /**
     * Observes all past booking payment transactions in real-time.
     */
    val allTransactions: Flow<List<PaymentTransactionEntity>> =
        paymentTransactionDao.getAllTransactions()

    /**
     * Observes payment transactions linked to a specific booking ID.
     */
    fun getTransactionsForBooking(bookingId: String): Flow<List<PaymentTransactionEntity>> =
        paymentTransactionDao.getTransactionsForBooking(bookingId)

    /**
     * Observes a single payment transaction by its transaction ID.
     */
    fun getTransactionById(transactionId: String): Flow<PaymentTransactionEntity?> =
        paymentTransactionDao.getTransactionById(transactionId)

    /**
     * Observes transactions filtered by their payment status ("SUCCESS", "FAILED", "CANCELLED", etc.).
     */
    fun getTransactionsByStatus(status: String): Flow<List<PaymentTransactionEntity>> =
        paymentTransactionDao.getTransactionsByStatus(status)

    /**
     * Inserts a new payment transaction record or replaces an existing one.
     */
    suspend fun recordTransaction(transaction: PaymentTransactionEntity) {
        paymentTransactionDao.insertTransaction(transaction)
    }

    /**
     * Updates the status of an existing transaction record.
     */
    suspend fun updateTransactionStatus(transactionId: String, status: String) {
        paymentTransactionDao.updateStatus(transactionId, status)
    }

    /**
     * Updates the status and attached notes/refund ID of an existing transaction record.
     */
    suspend fun updateTransactionStatusAndNotes(transactionId: String, status: String, notes: String) {
        paymentTransactionDao.updateStatusAndNotes(transactionId, status, notes)
    }

    /**
     * Deletes a transaction record by its transaction ID.
     */
    suspend fun deleteTransaction(transactionId: String) {
        paymentTransactionDao.deleteTransactionById(transactionId)
    }

    /**
     * Clears all local payment transaction records.
     */
    suspend fun clearTransactions() {
        paymentTransactionDao.clearAllTransactions()
    }

    companion object {
        @Volatile
        private var instance: PaymentTransactionRepository? = null

        fun getInstance(context: Context): PaymentTransactionRepository {
            return instance ?: synchronized(this) {
                instance ?: run {
                    val db = BookMySpaceRoomDatabase.getDatabase(context.applicationContext)
                    PaymentTransactionRepository(db.paymentTransactionDao()).also { instance = it }
                }
            }
        }
    }
}
