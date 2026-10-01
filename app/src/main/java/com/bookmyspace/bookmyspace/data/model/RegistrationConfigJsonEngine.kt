package com.bookmyspace.bookmyspace.data.model

import org.json.JSONArray
import org.json.JSONObject
import java.util.UUID

/**
 * Pre-defined configuration presets for instant 1-tap JSON application.
 */
enum class RegistrationConfigPreset(
    val code: String,
    val title: String,
    val description: String,
    val badge: String
) {
    STANDARD(
        "standard",
        "Standard Flexible",
        "Balanced KYC with mandatory Name, Phone, Email & Location. Aadhaar & DOB optional.",
        "DEFAULT"
    ),
    STRICT_KYC(
        "strict_kyc",
        "Strict KYC Compliance",
        "Government-compliant mode: Identity Proof (Aadhaar / Govt ID), Date of Birth, and Address are strictly MANDATORY.",
        "HIGH SECURITY"
    ),
    CORPORATE_B2B(
        "corporate_b2b",
        "Corporate & B2B Host",
        "Business onboarding mode: Company / Entity Name, GSTIN, Govt ID, and Commercial Address are strictly MANDATORY.",
        "B2B HOST"
    ),
    EXPRESS_CHECKOUT(
        "express",
        "Express 1-Tap Booking",
        "Maximum conversion flow: Only Full Name and Mobile Number are required. All KYC fields optional.",
        "FAST 1-TAP"
    ),
    STUDENT_ACADEMY(
        "student_academy",
        "Academy & Coaching Admission",
        "Institute mode: Date of Birth, Emergency / Parent Contact, and Skill Level are strictly MANDATORY.",
        "COACHING"
    );

    companion object {
        fun fromCode(code: String): RegistrationConfigPreset {
            return entries.find { it.code.equals(code, ignoreCase = true) } ?: STANDARD
        }
    }
}

/**
 * Flexible JSON Configuration Engine for BookMySpace User Registration & Booking KYC.
 * Allows administrators and systems to configure, export, validate, and import
 * registration field rules without hardcoding.
 */
object RegistrationConfigJsonEngine {

    const val SCHEMA_VERSION = "2.0"

    /**
     * Serializes a list of [UserRegistrationFieldDefinition] into a formatted JSON string.
     */
    fun exportToJson(
        fields: List<UserRegistrationFieldDefinition>,
        presetName: String = "Custom Admin Config",
        prettyPrint: Boolean = true
    ): String {
        val root = JSONObject()
        root.put("schemaVersion", SCHEMA_VERSION)
        root.put("preset", presetName)
        root.put("updatedAt", System.currentTimeMillis())
        root.put("description", "BookMySpace Dynamic Plug-and-Play Registration & KYC Field Schema")
        root.put("totalFields", fields.size)
        root.put("requiredCount", fields.count { it.required && it.isEnabled })

        val fieldsArray = JSONArray()
        fields.forEach { field ->
            fieldsArray.put(fieldToJsonObject(field))
        }
        root.put("fields", fieldsArray)

        return if (prettyPrint) root.toString(2) else root.toString()
    }

    /**
     * Converts a single [UserRegistrationFieldDefinition] to a [JSONObject].
     */
    fun fieldToJsonObject(field: UserRegistrationFieldDefinition): JSONObject {
        val obj = JSONObject()
        obj.put("id", field.id)
        obj.put("key", field.key)
        obj.put("label", field.label)
        obj.put("fieldType", field.fieldType.name)
        obj.put("category", field.category.name)
        obj.put("targetModule", field.targetModule.name)
        obj.put("required", field.required)
        obj.put("isEnabled", field.isEnabled)
        obj.put("placeholder", field.placeholder)
        obj.put("helpText", field.helpText)
        obj.put("defaultValue", field.defaultValue)
        
        val optionsArr = JSONArray()
        field.options.forEach { optionsArr.put(it) }
        obj.put("options", optionsArr)
        
        obj.put("displayOrder", field.displayOrder)
        obj.put("isSystemStandard", field.isSystemStandard)
        obj.put("validationRegex", field.validationRegex)
        return obj
    }

    /**
     * Parses a JSON string (either root object containing "fields" array or direct array)
     * into a list of [UserRegistrationFieldDefinition].
     */
    fun importFromJson(jsonString: String): Result<List<UserRegistrationFieldDefinition>> {
        return try {
            val trimmed = jsonString.trim()
            val fieldsArray: JSONArray = if (trimmed.startsWith("{")) {
                val root = JSONObject(trimmed)
                if (root.has("fields")) {
                    root.getJSONArray("fields")
                } else {
                    return Result.failure(IllegalArgumentException("JSON object must contain a 'fields' array."))
                }
            } else if (trimmed.startsWith("[")) {
                JSONArray(trimmed)
            } else {
                return Result.failure(IllegalArgumentException("Invalid JSON format. Expected '{' or '['."))
            }

            val list = mutableListOf<UserRegistrationFieldDefinition>()
            for (i in 0 until fieldsArray.length()) {
                val obj = fieldsArray.getJSONObject(i)
                val field = parseFieldFromJsonObject(obj, defaultOrder = i + 1)
                list.add(field)
            }

            if (list.isEmpty()) {
                return Result.failure(IllegalArgumentException("No valid registration fields found in JSON."))
            }

            Result.success(list.sortedBy { it.displayOrder })
        } catch (e: Exception) {
            Result.failure(e)
        }
    }

    /**
     * Parses a single [JSONObject] into a [UserRegistrationFieldDefinition].
     */
    fun parseFieldFromJsonObject(obj: JSONObject, defaultOrder: Int = 0): UserRegistrationFieldDefinition {
        val id = obj.optString("id").ifBlank { "reg_custom_${UUID.randomUUID().toString().take(8)}" }
        val key = obj.optString("key").ifBlank { id.replace("reg_", "").lowercase() }
        val label = obj.optString("label").ifBlank { key.replace("_", " ").replaceFirstChar { it.uppercase() } }
        
        val fieldTypeStr = obj.optString("fieldType", "TEXT")
        val fieldType = try {
            RegistrationFieldType.valueOf(fieldTypeStr.uppercase())
        } catch (_: Exception) {
            RegistrationFieldType.TEXT
        }

        val categoryStr = obj.optString("category", "PERSONAL")
        val category = try {
            RegistrationFieldCategory.valueOf(categoryStr.uppercase())
        } catch (_: Exception) {
            RegistrationFieldCategory.PERSONAL
        }

        val targetModuleStr = obj.optString("targetModule", "ALL")
        val targetModule = try {
            RegistrationTargetModule.valueOf(targetModuleStr.uppercase())
        } catch (_: Exception) {
            RegistrationTargetModule.ALL
        }

        val required = obj.optBoolean("required", false)
        val isEnabled = obj.optBoolean("isEnabled", true)
        val placeholder = obj.optString("placeholder", "")
        val helpText = obj.optString("helpText", "")
        val defaultValue = obj.optString("defaultValue", "")

        val options = mutableListOf<String>()
        val optArr = obj.optJSONArray("options")
        if (optArr != null) {
            for (j in 0 until optArr.length()) {
                options.add(optArr.getString(j))
            }
        }

        val displayOrder = if (obj.has("displayOrder")) obj.getInt("displayOrder") else defaultOrder
        val isSystemStandard = obj.optBoolean("isSystemStandard", false)
        val validationRegex = obj.optString("validationRegex", "")

        return UserRegistrationFieldDefinition(
            id = id,
            key = key,
            label = label,
            fieldType = fieldType,
            category = category,
            targetModule = targetModule,
            required = required,
            isEnabled = isEnabled,
            placeholder = placeholder,
            helpText = helpText,
            defaultValue = defaultValue,
            options = options,
            displayOrder = displayOrder,
            isSystemStandard = isSystemStandard,
            validationRegex = validationRegex
        )
    }

    /**
     * Validates JSON and returns formatted JSON string with pretty printing,
     * or an error string if invalid.
     */
    fun validateAndFormatJson(jsonString: String): Pair<Boolean, String> {
        return try {
            val result = importFromJson(jsonString)
            if (result.isSuccess) {
                val fields = result.getOrNull() ?: emptyList()
                val formatted = exportToJson(fields, presetName = "Validated Configuration", prettyPrint = true)
                Pair(true, formatted)
            } else {
                Pair(false, result.exceptionOrNull()?.localizedMessage ?: "Invalid JSON schema structure")
            }
        } catch (e: Exception) {
            Pair(false, e.localizedMessage ?: "Syntax error in JSON")
        }
    }

    /**
     * Generates standard JSON for any of the pre-configured presets.
     */
    fun getPresetFields(
        baseFields: List<UserRegistrationFieldDefinition>,
        preset: RegistrationConfigPreset
    ): List<UserRegistrationFieldDefinition> {
        return when (preset) {
            RegistrationConfigPreset.STANDARD -> {
                baseFields.map { field ->
                    when (field.key) {
                        "full_name", "phone", "email", "address_line_1", "pincode", "location_hierarchy" ->
                            field.copy(required = true, isEnabled = true)
                        "organization_name" ->
                            field.copy(required = true, isEnabled = true, targetModule = RegistrationTargetModule.VENUE_OWNER)
                        "dob", "aadhaar_number", "govt_id_number", "gender", "photo_url", "emergency_contact", "gstin" ->
                            field.copy(required = false, isEnabled = true)
                        else -> field
                    }
                }
            }
            RegistrationConfigPreset.STRICT_KYC -> {
                baseFields.map { field ->
                    when (field.key) {
                        "full_name", "phone", "email", "dob", "aadhaar_number", "govt_id_number",
                        "address_line_1", "pincode", "location_hierarchy", "photo_url" ->
                            field.copy(required = true, isEnabled = true)
                        "organization_name", "gstin" ->
                            field.copy(required = true, isEnabled = true, targetModule = RegistrationTargetModule.VENUE_OWNER)
                        "emergency_contact", "gender" ->
                            field.copy(required = true, isEnabled = true)
                        else -> field
                    }
                }
            }
            RegistrationConfigPreset.CORPORATE_B2B -> {
                baseFields.map { field ->
                    when (field.key) {
                        "full_name", "phone", "email", "organization_name", "gstin", "govt_id_number",
                        "address_line_1", "pincode", "location_hierarchy" ->
                            field.copy(required = true, isEnabled = true)
                        "aadhaar_number", "dob", "photo_url", "emergency_contact" ->
                            field.copy(required = false, isEnabled = true)
                        else -> field
                    }
                }
            }
            RegistrationConfigPreset.EXPRESS_CHECKOUT -> {
                baseFields.map { field ->
                    when (field.key) {
                        "full_name", "phone" ->
                            field.copy(required = true, isEnabled = true)
                        "email", "address_line_1", "location_hierarchy", "pincode", "dob",
                        "aadhaar_number", "govt_id_number", "organization_name", "gstin",
                        "photo_url", "emergency_contact", "gender" ->
                            field.copy(required = false, isEnabled = true)
                        else -> field.copy(required = false)
                    }
                }
            }
            RegistrationConfigPreset.STUDENT_ACADEMY -> {
                baseFields.map { field ->
                    when (field.key) {
                        "full_name", "phone", "email", "dob", "emergency_contact", "skill_level",
                        "location_hierarchy" ->
                            field.copy(required = true, isEnabled = true)
                        "aadhaar_number", "photo_url", "address_line_1", "pincode" ->
                            field.copy(required = false, isEnabled = true)
                        else -> field
                    }
                }
            }
        }
    }
}
