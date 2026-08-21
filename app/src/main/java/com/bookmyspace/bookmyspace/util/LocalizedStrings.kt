package com.bookmyspace.bookmyspace.util

import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import java.util.Locale

enum class AppLanguage(
    val code: String,
    val displayName: String,
    val nativeName: String,
    val flagEmoji: String,
    val speechLocale: String,
    val locale: Locale
) {
    ENGLISH("en", "English", "English", "🇮🇳", "en-IN", Locale("en", "IN")),
    TELUGU("te", "Telugu", "తెలుగు", "🇮🇳", "te-IN", Locale("te", "IN")),
    HINDI("hi", "Hindi", "हिन्दी", "🇮🇳", "hi-IN", Locale("hi", "IN")),
    TAMIL("ta", "Tamil", "தமிழ்", "🇮🇳", "ta-IN", Locale("ta", "IN")),
    KANNADA("kn", "Kannada", "ಕನ್ನಡ", "🇮🇳", "kn-IN", Locale("kn", "IN")),
    MARATHI("mr", "Marathi", "मराठी", "🇮🇳", "mr-IN", Locale("mr", "IN")),
    GUJARATI("gu", "Gujarati", "ગુજરાતી", "🇮🇳", "gu-IN", Locale("gu", "IN")),
    BENGALI("bn", "Bengali", "বাংলা", "🇮🇳", "bn-IN", Locale("bn", "IN")),
    MALAYALAM("ml", "Malayalam", "മലയാളം", "🇮🇳", "ml-IN", Locale("ml", "IN"));

    companion object {
        fun fromCode(code: String): AppLanguage {
            return entries.firstOrNull { it.code.equals(code, ignoreCase = true) } ?: ENGLISH
        }
    }
}

object LocalizedStrings {
    private val _currentLanguage = MutableStateFlow(AppLanguage.ENGLISH)
    val currentLanguage: StateFlow<AppLanguage> = _currentLanguage.asStateFlow()

    private val translations: Map<String, Map<String, String>> = mapOf(
        "select_language" to mapOf(
            "en" to "Select Language",
            "te" to "భాషను ఎంచుకోండి",
            "hi" to "भाषा चुनें",
            "ta" to "மொழியைத் தேர்ந்தெடுக்கவும்",
            "kn" to "ಭಾಷೆಯನ್ನು ಆಯ್ಕೆಮಾಡಿ",
            "mr" to "भाषा निवडा",
            "gu" to "ભાષા પસંદ કરો",
            "bn" to "ভাষা নির্বাচন করুন",
            "ml" to "ഭാഷ തിരഞ്ഞെടുക്കുക"
        ),
        "explore" to mapOf(
            "en" to "Explore Venues",
            "te" to "వేదికలను అన్వేషించండి",
            "hi" to "स्थान खोजें",
            "ta" to "இடங்களை ஆராயுங்கள்",
            "kn" to "ಸ್ಥಳಗಳನ್ನು ಅನ್ವೇಷಿಸಿ",
            "mr" to "ठिकाणे शोधा"
        ),
        "book_now" to mapOf(
            "en" to "Book Now",
            "te" to "ఇప్పుడే బుక్ చేయండి",
            "hi" to "अभी बुक करें",
            "ta" to "இப்போது முன்பதிவு செய்யுங்கள்",
            "kn" to "ಈಗ ಕಾಯ್ದಿರಿಸಿ",
            "mr" to "आत्ताच बुक करा"
        ),
        "search_hint" to mapOf(
            "en" to "Search venues, halls, turfs, PGs...",
            "te" to "వేదికలు, హాళ్ళు, టర్ఫ్‌లు, పీజీలు శోధించండి...",
            "hi" to "स्थान, हॉल, टर्फ, पीजी खोजें...",
            "ta" to "இடங்கள், அரங்குகள், தங்குமிடங்களைத் தேடுங்கள்...",
            "kn" to "ಸ್ಥಳಗಳು, ಹಾಲ್‌ಗಳು, ಪಿಜಿಗಳನ್ನು ಹುಡುಕಿ..."
        ),
        "voice_assistant" to mapOf(
            "en" to "Easy Voice Booking",
            "te" to "వాయిస్ బుకింగ్ అసిస్టెంట్",
            "hi" to "आवाज बुकिंग सहायक",
            "ta" to "குரல் முன்பதிவு உதவியாளர்"
        ),
        "categories" to mapOf(
            "en" to "Categories",
            "te" to "వర్గాలు",
            "hi" to "श्रेणियाँ",
            "ta" to "வகைகள்"
        ),
        "all" to mapOf(
            "en" to "All",
            "te" to "అన్నీ",
            "hi" to "सभी",
            "ta" to "அனைத்தும்"
        )
    )

    fun setLanguage(language: AppLanguage) {
        _currentLanguage.value = language
    }

    fun getDirect(key: String, lang: AppLanguage, vararg args: Any): String {
        val langCode = lang.code
        val template = translations[key]?.get(langCode)
            ?: translations[key]?.get("en")
            ?: key.replace("_", " ").replaceFirstChar { if (it.isLowerCase()) it.titlecase(Locale.ROOT) else it.toString() }

        return if (args.isNotEmpty()) {
            try {
                String.format(template, *args)
            } catch (e: Exception) {
                template
            }
        } else {
            template
        }
    }

    fun get(key: String, vararg args: Any): String {
        val langCode = _currentLanguage.value.code
        val template = translations[key]?.get(langCode)
            ?: translations[key]?.get("en")
            ?: key.replace("_", " ").replaceFirstChar { if (it.isLowerCase()) it.titlecase(Locale.ROOT) else it.toString() }

        return if (args.isNotEmpty()) {
            try {
                String.format(template, *args)
            } catch (e: Exception) {
                template
            }
        } else {
            template
        }
    }
}
