package com.bookmyspace.bookmyspace.data.payment

import android.content.Context
import android.content.SharedPreferences
import android.util.Log
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import org.json.JSONArray
import org.json.JSONObject

/**
 * Repository that manages Admin & Owner Payment Configurations,
 * Dynamic Gateways, Method master toggles, and per-venue policies.
 */
class PaymentConfigRepository private constructor(context: Context) {

    companion object {
        private const val TAG = "PaymentConfigRepo"
        private const val PREFS_NAME = "bms_payment_config_prefs"
        private const val KEY_ADMIN_SETTINGS = "admin_payment_settings_json"
        private const val KEY_OWNER_POLICIES = "owner_policies_json"

        @Volatile
        private var instance: PaymentConfigRepository? = null

        fun getInstance(context: Context): PaymentConfigRepository {
            return instance ?: synchronized(this) {
                instance ?: PaymentConfigRepository(context.applicationContext).also { instance = it }
            }
        }
    }

    private val prefs: SharedPreferences = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

    // Admin Payment Settings Flow
    private val _adminSettings = MutableStateFlow(loadAdminSettings())
    val adminSettings: StateFlow<AdminPaymentSettings> = _adminSettings.asStateFlow()

    // Owner Policies Map (venueId -> OwnerPaymentPolicy)
    private val _ownerPolicies = MutableStateFlow<Map<String, OwnerPaymentPolicy>>(loadOwnerPolicies())
    val ownerPolicies: StateFlow<Map<String, OwnerPaymentPolicy>> = _ownerPolicies.asStateFlow()

    private fun loadAdminSettings(): AdminPaymentSettings {
        val jsonStr = prefs.getString(KEY_ADMIN_SETTINGS, null)
        if (jsonStr.isNullOrBlank()) {
            return AdminPaymentSettings()
        }
        return try {
            val json = JSONObject(jsonStr)
            val methodsArr = json.optJSONArray("enabledGlobalMethods") ?: JSONArray()
            val methodsSet = mutableSetOf<String>()
            for (i in 0 until methodsArr.length()) {
                methodsSet.add(methodsArr.getString(i))
            }
            if (methodsSet.isEmpty()) {
                methodsSet.addAll(ConfigurablePaymentMethod.values().map { it.id })
            }

            AdminPaymentSettings(
                isSandboxMode = json.optBoolean("isSandboxMode", true),
                isSelfHealingAutoReconcileEnabled = json.optBoolean("isSelfHealingAutoReconcileEnabled", true),
                isAutoFailoverEnabled = json.optBoolean("isAutoFailoverEnabled", true),
                healthCheckIntervalSeconds = json.optInt("healthCheckIntervalSeconds", 15),
                maxPaymentRetries = json.optInt("maxPaymentRetries", 3),
                platformConvenienceFeePercent = json.optDouble("platformConvenienceFeePercent", 2.0),
                gstTaxPercent = json.optDouble("gstTaxPercent", 18.0),
                primaryGateway = try {
                    PaymentGatewayProvider.valueOf(json.optString("primaryGateway", "RAZORPAY"))
                } catch (e: Exception) {
                    PaymentGatewayProvider.RAZORPAY
                },
                fallbackGateway = try {
                    PaymentGatewayProvider.valueOf(json.optString("fallbackGateway", "CASHFREE"))
                } catch (e: Exception) {
                    PaymentGatewayProvider.CASHFREE
                },
                enabledGlobalMethods = methodsSet,
                razorpayKeyId = json.optString("razorpayKeyId", "rzp_test_bookmyspace_2026"),
                cashfreeAppId = json.optString("cashfreeAppId", "cf_test_app_bms_live"),
                simulatedNetworkDegradation = json.optBoolean("simulatedNetworkDegradation", false)
            )
        } catch (e: Exception) {
            Log.e(TAG, "Error loading admin settings: ${e.message}", e)
            AdminPaymentSettings()
        }
    }

    private fun saveAdminSettings(settings: AdminPaymentSettings) {
        try {
            val json = JSONObject().apply {
                put("isSandboxMode", settings.isSandboxMode)
                put("isSelfHealingAutoReconcileEnabled", settings.isSelfHealingAutoReconcileEnabled)
                put("isAutoFailoverEnabled", settings.isAutoFailoverEnabled)
                put("healthCheckIntervalSeconds", settings.healthCheckIntervalSeconds)
                put("maxPaymentRetries", settings.maxPaymentRetries)
                put("platformConvenienceFeePercent", settings.platformConvenienceFeePercent)
                put("gstTaxPercent", settings.gstTaxPercent)
                put("primaryGateway", settings.primaryGateway.name)
                put("fallbackGateway", settings.fallbackGateway.name)
                put("enabledGlobalMethods", JSONArray(settings.enabledGlobalMethods.toList()))
                put("razorpayKeyId", settings.razorpayKeyId)
                put("cashfreeAppId", settings.cashfreeAppId)
                put("simulatedNetworkDegradation", settings.simulatedNetworkDegradation)
            }
            prefs.edit().putString(KEY_ADMIN_SETTINGS, json.toString()).apply()
            _adminSettings.value = settings
        } catch (e: Exception) {
            Log.e(TAG, "Error saving admin settings: ${e.message}", e)
        }
    }

    private fun loadOwnerPolicies(): Map<String, OwnerPaymentPolicy> {
        val jsonStr = prefs.getString(KEY_OWNER_POLICIES, null)
        if (jsonStr.isNullOrBlank()) {
            return emptyMap()
        }
        return try {
            val root = JSONObject(jsonStr)
            val result = mutableMapOf<String, OwnerPaymentPolicy>()
            val keys = root.keys()
            while (keys.hasNext()) {
                val venueId = keys.next()
                val obj = root.getJSONObject(venueId)
                val disabledArr = obj.optJSONArray("disabledMethods") ?: JSONArray()
                val disabledSet = mutableSetOf<String>()
                for (i in 0 until disabledArr.length()) {
                    disabledSet.add(disabledArr.getString(i))
                }

                result[venueId] = OwnerPaymentPolicy(
                    venueId = venueId,
                    allowPayAtVenue = obj.optBoolean("allowPayAtVenue", true),
                    allowSplitPayment = obj.optBoolean("allowSplitPayment", true),
                    splitAdvancePercentage = obj.optInt("splitAdvancePercentage", 20),
                    allowWalletRedemption = obj.optBoolean("allowWalletRedemption", true),
                    customUpiVpa = obj.optString("customUpiVpa", "bookmyspace.merchant@upi"),
                    instantAutoRefunds = obj.optBoolean("instantAutoRefunds", true),
                    minimumAdvanceAmount = obj.optDouble("minimumAdvanceAmount", 200.0),
                    disabledMethods = disabledSet
                )
            }
            result
        } catch (e: Exception) {
            Log.e(TAG, "Error loading owner policies: ${e.message}", e)
            emptyMap()
        }
    }

    private fun saveOwnerPolicies(policies: Map<String, OwnerPaymentPolicy>) {
        try {
            val root = JSONObject()
            policies.forEach { (venueId, policy) ->
                val obj = JSONObject().apply {
                    put("venueId", policy.venueId)
                    put("allowPayAtVenue", policy.allowPayAtVenue)
                    put("allowSplitPayment", policy.allowSplitPayment)
                    put("splitAdvancePercentage", policy.splitAdvancePercentage)
                    put("allowWalletRedemption", policy.allowWalletRedemption)
                    put("customUpiVpa", policy.customUpiVpa)
                    put("instantAutoRefunds", policy.instantAutoRefunds)
                    put("minimumAdvanceAmount", policy.minimumAdvanceAmount)
                    put("disabledMethods", JSONArray(policy.disabledMethods.toList()))
                }
                root.put(venueId, obj)
            }
            prefs.edit().putString(KEY_OWNER_POLICIES, root.toString()).apply()
            _ownerPolicies.value = policies
        } catch (e: Exception) {
            Log.e(TAG, "Error saving owner policies: ${e.message}", e)
        }
    }

    // --- Admin Mutation Actions ---
    fun updateAdminSettings(settings: AdminPaymentSettings) {
        saveAdminSettings(settings)
    }

    fun toggleGlobalPaymentMethod(methodId: String, enable: Boolean) {
        val current = _adminSettings.value
        val updatedMethods = current.enabledGlobalMethods.toMutableSet()
        if (enable) {
            updatedMethods.add(methodId)
        } else {
            updatedMethods.remove(methodId)
        }
        saveAdminSettings(current.copy(enabledGlobalMethods = updatedMethods))
    }

    fun setPrimaryGateway(gateway: PaymentGatewayProvider) {
        val current = _adminSettings.value
        saveAdminSettings(current.copy(primaryGateway = gateway))
    }

    fun setFallbackGateway(gateway: PaymentGatewayProvider) {
        val current = _adminSettings.value
        saveAdminSettings(current.copy(fallbackGateway = gateway))
    }

    fun setSandboxMode(isSandbox: Boolean) {
        val current = _adminSettings.value
        saveAdminSettings(current.copy(isSandboxMode = isSandbox))
    }

    fun setSelfHealingAutoReconcile(enabled: Boolean) {
        val current = _adminSettings.value
        saveAdminSettings(current.copy(isSelfHealingAutoReconcileEnabled = enabled))
    }

    fun setAutoFailoverEnabled(enabled: Boolean) {
        val current = _adminSettings.value
        saveAdminSettings(current.copy(isAutoFailoverEnabled = enabled))
    }

    fun setSimulatedNetworkDegradation(degraded: Boolean) {
        val current = _adminSettings.value
        saveAdminSettings(current.copy(simulatedNetworkDegradation = degraded))
    }

    // --- Owner Mutation Actions ---
    fun getPolicyForVenue(venueId: String): OwnerPaymentPolicy {
        return _ownerPolicies.value[venueId] ?: OwnerPaymentPolicy(venueId = venueId)
    }

    fun updateOwnerPolicy(policy: OwnerPaymentPolicy) {
        val updated = _ownerPolicies.value.toMutableMap()
        updated[policy.venueId] = policy
        saveOwnerPolicies(updated)
    }

    fun toggleOwnerPaymentMethod(venueId: String, methodId: String, allow: Boolean) {
        val current = getPolicyForVenue(venueId)
        val disabled = current.disabledMethods.toMutableSet()
        if (allow) {
            disabled.remove(methodId)
        } else {
            disabled.add(methodId)
        }
        updateOwnerPolicy(current.copy(disabledMethods = disabled))
    }

    /**
     * Helper to compute active allowable payment methods for a given checkout session.
     * Takes into account Admin global toggles AND venue-specific owner overrides.
     */
    fun getActivePaymentMethodsForVenue(venueId: String?): List<ConfigurablePaymentMethod> {
        val admin = _adminSettings.value
        val policy = if (venueId != null) getPolicyForVenue(venueId) else null

        return ConfigurablePaymentMethod.values().filter { method ->
            // Must be enabled globally by admin
            val isGloballyEnabled = admin.enabledGlobalMethods.contains(method.id)
            if (!isGloballyEnabled) return@filter false

            // Check owner overrides
            if (policy != null) {
                if (method == ConfigurablePaymentMethod.PAY_AT_VENUE && !policy.allowPayAtVenue) return@filter false
                if (method == ConfigurablePaymentMethod.SPLIT_ADVANCE_TOKEN && !policy.allowSplitPayment) return@filter false
                if (method == ConfigurablePaymentMethod.BMS_WALLET && !policy.allowWalletRedemption) return@filter false
                if (policy.disabledMethods.contains(method.id)) return@filter false
            }
            true
        }
    }
}
