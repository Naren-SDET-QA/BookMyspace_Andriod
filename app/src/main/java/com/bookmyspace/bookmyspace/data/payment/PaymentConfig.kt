package com.bookmyspace.bookmyspace.data.payment

import androidx.compose.ui.graphics.Color

/**
 * Supported payment gateway providers.
 */
enum class PaymentGatewayProvider(
    val id: String,
    val displayName: String,
    val description: String,
    val badgeIcon: String,
    val defaultPriority: Int
) {
    RAZORPAY("razorpay", "Razorpay Payment Suite", "Primary Gateway: Cards, UPI, NetBanking, Wallets", "⚡", 1),
    CASHFREE("cashfree", "Cashfree Payments", "Auto-Failover Gateway: Instant UPI & Cards", "🌊", 2),
    PAYU("payu", "PayU India Enterprise", "Secondary Backup: Cards, EMI & UPI", "🟣", 3),
    DIRECT_UPI("direct_upi", "Direct UPI DeepLink / VPA", "Zero-Fee Direct Bank P2M Transfer", "🇮🇳", 4),
    PAY_AT_VENUE("pay_at_venue", "Pay at Venue / Cash on Check-in", "Offline Handover at Venue Desk", "🏢", 5)
}

/**
 * Granular Payment Method Types that Admin and Owners can enable or disable.
 */
enum class ConfigurablePaymentMethod(
    val id: String,
    val title: String,
    val subtitle: String,
    val iconEmoji: String,
    val category: String,
    val isOnline: Boolean = true
) {
    UPI_GPAY("upi_gpay", "Google Pay UPI", "Fast 1-tap biometric UPI", "⚡", "UPI"),
    UPI_PHONEPE("upi_phonepe", "PhonePe UPI", "Instant zero fee UPI", "🟣", "UPI"),
    UPI_PAYTM("upi_paytm", "Paytm UPI / Wallet", "Paytm UPI & fast checkout", "🔵", "UPI"),
    UPI_BHIM_CUSTOM("upi_bhim", "BHIM & Any UPI ID", "Enter custom UPI VPA handle", "🇮🇳", "UPI"),
    CREDIT_DEBIT_CARDS("cards", "Credit & Debit Cards", "Visa, MasterCard, RuPay, Amex", "💳", "Cards"),
    NET_BANKING("net_banking", "Net Banking", "50+ Indian Banks (SBI, HDFC, ICICI, etc.)", "🏛️", "Banking"),
    BMS_WALLET("bms_wallet", "BookMySpace Wallet", "Cashback & Referral Rewards balance", "💰", "Wallet"),
    PAY_AT_VENUE("pay_at_venue", "Pay at Venue (Cash/Card)", "Reserve now, pay 100% on arrival", "🏢", "Offline", isOnline = false),
    SPLIT_ADVANCE_TOKEN("split_advance", "Split Payment (20% Advance)", "Pay 20% advance token now, 80% on check-in", "⏳", "Flexible"),
    EMI_PAYLATER("emi_paylater", "Zero-Cost EMI & PayLater", "3/6 month installments & Simpl/LazyPay", "📊", "Credit")
}

/**
 * Health status of payment infrastructure.
 */
enum class GatewayHealthStatus(val label: String, val colorHex: String) {
    OPTIMAL("Optimal (100%)", "#4CAF50"),
    DEGRADED("Degraded (High Latency)", "#FF9800"),
    OUTAGE("Outage (Auto-Failover Active)", "#F44336"),
    MAINTENANCE("Maintenance Mode", "#9C27B0")
}

/**
 * Self-healing transaction recovery action types.
 */
enum class HealingActionType {
    RECONCILED_SUCCESS,
    AUTO_FAILOVER_ROUTED,
    DUPLICATE_AUTO_REFUNDED,
    SIGNATURE_VERIFIED_CONFIRMED,
    WEBHOOK_REPAIRED,
    STUCK_SLOT_RELEASED
}

/**
 * Self-healing log item.
 */
data class SelfHealingLogEvent(
    val id: String,
    val timestamp: Long = System.currentTimeMillis(),
    val actionType: HealingActionType,
    val bookingId: String,
    val transactionId: String,
    val message: String,
    val latencyMs: Long = 120,
    val resolvedGateway: String = "Razorpay"
)

/**
 * Owner-specific payment preferences for a venue/institute.
 */
data class OwnerPaymentPolicy(
    val venueId: String,
    val allowPayAtVenue: Boolean = true,
    val allowSplitPayment: Boolean = true,
    val splitAdvancePercentage: Int = 20,
    val allowWalletRedemption: Boolean = true,
    val customUpiVpa: String = "bookmyspace.merchant@upi",
    val instantAutoRefunds: Boolean = true,
    val minimumAdvanceAmount: Double = 200.0,
    val disabledMethods: Set<String> = emptySet()
)

/**
 * Global Admin payment settings.
 */
data class AdminPaymentSettings(
    val isSandboxMode: Boolean = true,
    val isSelfHealingAutoReconcileEnabled: Boolean = true,
    val isAutoFailoverEnabled: Boolean = true,
    val healthCheckIntervalSeconds: Int = 15,
    val maxPaymentRetries: Int = 3,
    val platformConvenienceFeePercent: Double = 2.0,
    val gstTaxPercent: Double = 18.0,
    val primaryGateway: PaymentGatewayProvider = PaymentGatewayProvider.RAZORPAY,
    val fallbackGateway: PaymentGatewayProvider = PaymentGatewayProvider.CASHFREE,
    val enabledGlobalMethods: Set<String> = ConfigurablePaymentMethod.values().map { it.id }.toSet(),
    val razorpayKeyId: String = "rzp_test_bookmyspace_2026",
    val cashfreeAppId: String = "cf_test_app_bms_live",
    val simulatedNetworkDegradation: Boolean = false
)
