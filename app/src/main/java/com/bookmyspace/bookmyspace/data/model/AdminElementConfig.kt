package com.bookmyspace.bookmyspace.data.model

import org.json.JSONObject

/**
 * Types of editable elements supported in the Admin Live Element Customizer.
 */
enum class AdminElementType(val label: String, val emoji: String) {
    TEXT("Text / Heading", "🔤"),
    EDIT_BOX("EditBox / Input", "📝"),
    BUTTON("Button / CTA", "🔘"),
    BADGE("Badge / Chip", "🏷️"),
    BANNER("Banner / Card", "🖼️"),
    OBJECT_JSON("Object / Key-Value", "📦")
}

/**
 * Configuration model for any editable text, input box, button, badge, banner, or object element.
 */
data class AdminElementConfig(
    val key: String,
    val screenName: String,
    val elementType: AdminElementType,
    val displayName: String,
    val description: String = "",
    val currentValue: String,
    val defaultValue: String,
    val placeholder: String? = null,
    val defaultPlaceholder: String? = null,
    val helperText: String? = null,
    val defaultHelperText: String? = null,
    val iconName: String? = null,
    val colorHex: Long? = null,
    val fontSizeSp: Float? = null,
    val fontWeightName: String = "Normal", // Normal, Medium, SemiBold, Bold
    val isVisible: Boolean = true,
    val isCustom: Boolean = false,
    val lastModifiedTimestamp: Long = System.currentTimeMillis(),
    val customAttributes: Map<String, String> = emptyMap()
) {
    val isModified: Boolean
        get() = currentValue != defaultValue ||
                (placeholder != null && placeholder != defaultPlaceholder) ||
                (helperText != null && helperText != defaultHelperText) ||
                !isVisible ||
                colorHex != null ||
                fontSizeSp != null ||
                customAttributes.isNotEmpty()

    fun toJson(): JSONObject {
        val json = JSONObject()
        json.put("key", key)
        json.put("screenName", screenName)
        json.put("elementType", elementType.name)
        json.put("displayName", displayName)
        json.put("description", description)
        json.put("currentValue", currentValue)
        json.put("defaultValue", defaultValue)
        if (placeholder != null) json.put("placeholder", placeholder)
        if (defaultPlaceholder != null) json.put("defaultPlaceholder", defaultPlaceholder)
        if (helperText != null) json.put("helperText", helperText)
        if (defaultHelperText != null) json.put("defaultHelperText", defaultHelperText)
        if (iconName != null) json.put("iconName", iconName)
        if (colorHex != null) json.put("colorHex", colorHex)
        if (fontSizeSp != null) json.put("fontSizeSp", fontSizeSp.toDouble())
        json.put("fontWeightName", fontWeightName)
        json.put("isVisible", isVisible)
        json.put("isCustom", isCustom)
        json.put("lastModifiedTimestamp", lastModifiedTimestamp)

        val attrObj = JSONObject()
        customAttributes.forEach { (k, v) -> attrObj.put(k, v) }
        json.put("customAttributes", attrObj)
        return json
    }

    companion object {
        fun fromJson(json: JSONObject): AdminElementConfig {
            val key = json.optString("key", "")
            val screenName = json.optString("screenName", "Global")
            val typeStr = json.optString("elementType", AdminElementType.TEXT.name)
            val elementType = try { AdminElementType.valueOf(typeStr) } catch (e: Exception) { AdminElementType.TEXT }
            val displayName = json.optString("displayName", key)
            val description = json.optString("description", "")
            val defaultValue = json.optString("defaultValue", "")
            val currentValue = json.optString("currentValue", defaultValue)
            val placeholder = if (json.has("placeholder")) json.getString("placeholder") else null
            val defaultPlaceholder = if (json.has("defaultPlaceholder")) json.getString("defaultPlaceholder") else null
            val helperText = if (json.has("helperText")) json.getString("helperText") else null
            val defaultHelperText = if (json.has("defaultHelperText")) json.getString("defaultHelperText") else null
            val iconName = if (json.has("iconName")) json.getString("iconName") else null
            val colorHex = if (json.has("colorHex")) json.getLong("colorHex") else null
            val fontSizeSp = if (json.has("fontSizeSp")) json.getDouble("fontSizeSp").toFloat() else null
            val fontWeightName = json.optString("fontWeightName", "Normal")
            val isVisible = json.optBoolean("isVisible", true)
            val isCustom = json.optBoolean("isCustom", false)
            val lastModified = json.optLong("lastModifiedTimestamp", System.currentTimeMillis())

            val customAttributes = mutableMapOf<String, String>()
            if (json.has("customAttributes")) {
                val attrObj = json.getJSONObject("customAttributes")
                attrObj.keys().forEach { k ->
                    customAttributes[k] = attrObj.getString(k)
                }
            }

            return AdminElementConfig(
                key = key,
                screenName = screenName,
                elementType = elementType,
                displayName = displayName,
                description = description,
                currentValue = currentValue,
                defaultValue = defaultValue,
                placeholder = placeholder,
                defaultPlaceholder = defaultPlaceholder,
                helperText = helperText,
                defaultHelperText = defaultHelperText,
                iconName = iconName,
                colorHex = colorHex,
                fontSizeSp = fontSizeSp,
                fontWeightName = fontWeightName,
                isVisible = isVisible,
                isCustom = isCustom,
                lastModifiedTimestamp = lastModified,
                customAttributes = customAttributes
            )
        }
    }
}
