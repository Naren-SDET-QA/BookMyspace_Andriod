package com.bookmyspace.bookmyspace.data.local

import androidx.room.Dao
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.Query
import androidx.room.Update
import kotlinx.coroutines.flow.Flow

/**
 * Room Data Access Object (DAO) for querying and updating local payment transaction records.
 */
@Dao
interface PaymentTransactionDao {

    /**
     * Observes all past payment transactions ordered by timestamp (newest first).
     */
    @Query("SELECT * FROM payment_transactions ORDER BY timestamp DESC")
    fun getAllTransactions(): Flow<List<PaymentTransactionEntity>>

    /**
     * Observes transactions associated with a specific booking ID.
     */
    @Query("SELECT * FROM payment_transactions WHERE bookingId = :bookingId ORDER BY timestamp DESC")
    fun getTransactionsForBooking(bookingId: String): Flow<List<PaymentTransactionEntity>>

    /**
     * Observes a specific transaction by its transaction ID.
     */
    @Query("SELECT * FROM payment_transactions WHERE transactionId = :transactionId LIMIT 1")
    fun getTransactionById(transactionId: String): Flow<PaymentTransactionEntity?>

    /**
     * Observes transactions filtered by payment status (e.g., "SUCCESS", "FAILED", "CANCELLED").
     */
    @Query("SELECT * FROM payment_transactions WHERE paymentStatus = :status ORDER BY timestamp DESC")
    fun getTransactionsByStatus(status: String): Flow<List<PaymentTransactionEntity>>

    /**
     * Retrieves a one-time snapshot list of all payment transactions.
     */
    @Query("SELECT * FROM payment_transactions ORDER BY timestamp DESC")
    suspend fun getAllTransactionsSnapshot(): List<PaymentTransactionEntity>

    /**
     * Inserts or updates a payment transaction record.
     */
    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insertTransaction(transaction: PaymentTransactionEntity)

    /**
     * Inserts a batch of payment transactions.
     */
    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insertTransactions(transactions: List<PaymentTransactionEntity>)

    /**
     * Updates an existing payment transaction record.
     */
    @Update
    suspend fun updateTransaction(transaction: PaymentTransactionEntity)

    /**
     * Updates the status of a specific transaction.
     */
    @Query("UPDATE payment_transactions SET paymentStatus = :status WHERE transactionId = :transactionId")
    suspend fun updateStatus(transactionId: String, status: String)

    /**
     * Updates the status and notes of a specific transaction.
     */
    @Query("UPDATE payment_transactions SET paymentStatus = :status, notes = :notes WHERE transactionId = :transactionId")
    suspend fun updateStatusAndNotes(transactionId: String, status: String, notes: String)

    /**
     * Deletes a payment transaction record by its transaction ID.
     */
    @Query("DELETE FROM payment_transactions WHERE transactionId = :transactionId")
    suspend fun deleteTransactionById(transactionId: String)

    /**
     * Clears all local payment transaction records.
     */
    @Query("DELETE FROM payment_transactions")
    suspend fun clearAllTransactions()
}
