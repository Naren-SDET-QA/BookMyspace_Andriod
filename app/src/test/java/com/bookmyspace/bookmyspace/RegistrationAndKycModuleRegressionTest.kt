package com.bookmyspace.bookmyspace

import com.bookmyspace.bookmyspace.data.model.*
import com.bookmyspace.bookmyspace.data.repository.BookMySpaceRepository
import org.junit.Assert.*
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [33])
class RegistrationAndKycModuleRegressionTest {

    private val baseFields = BookMySpaceRepository.sampleRegistrationFields

    @Test
    fun testAllPresetDefinitionsValid() {
        RegistrationConfigPreset.entries.forEach { preset ->
            val fields = RegistrationConfigJsonEngine.getPresetFields(baseFields, preset)
            assertTrue("Preset ${preset.title} must have fields defined", fields.isNotEmpty())
            
            // Name and phone should always exist
            assertTrue("Preset ${preset.title} must contain full_name key", fields.any { it.key == "full_name" })
            assertTrue("Preset ${preset.title} must contain phone key", fields.any { it.key == "phone" })
        }
    }

    @Test
    fun testJsonExportAndImportRoundTrip() {
        val originalFields = RegistrationConfigJsonEngine.getPresetFields(baseFields, RegistrationConfigPreset.STANDARD)
        val exportedJson = RegistrationConfigJsonEngine.exportToJson(originalFields, presetName = "Standard Roundtrip Test", prettyPrint = true)
        
        assertNotNull(exportedJson)
        assertTrue(exportedJson.contains("schemaVersion"))
        assertTrue(exportedJson.contains("fields"))

        val importResult = RegistrationConfigJsonEngine.importFromJson(exportedJson)
        assertTrue("Import result must be success", importResult.isSuccess)
        
        val importedFields = importResult.getOrThrow()
        assertEquals("Field count must match after roundtrip", originalFields.size, importedFields.size)

        val nameField = importedFields.firstOrNull { it.key == "full_name" }
        assertNotNull(nameField)
        assertTrue("Full name field should be mandatory", nameField!!.required)
    }

    @Test
    fun testJsonValidationEngineWithInvalidPayloads() {
        // Invalid JSON syntax
        val (isValidSyntax, _) = RegistrationConfigJsonEngine.validateAndFormatJson("invalid-not-json")
        assertFalse("Malformed JSON should be rejected", isValidSyntax)

        // Missing fields array
        val (isValidEmptyObj, _) = RegistrationConfigJsonEngine.validateAndFormatJson("{\"foo\": \"bar\"}")
        assertFalse("JSON missing fields array should be rejected", isValidEmptyObj)

        // Valid JSON array directly
        val validJsonArray = """
            [
              {
                "id": "reg_name",
                "key": "full_name",
                "label": "Full Name",
                "fieldType": "TEXT",
                "required": true,
                "isEnabled": true
              }
            ]
        """.trimIndent()
        val (isValidArray, formatted) = RegistrationConfigJsonEngine.validateAndFormatJson(validJsonArray)
        assertTrue("Valid JSON array of fields should be accepted", isValidArray)
        assertTrue(formatted.contains("full_name"))
    }

    @Test
    fun testStrictKycPresetRequirements() {
        val strictFields = RegistrationConfigJsonEngine.getPresetFields(baseFields, RegistrationConfigPreset.STRICT_KYC)
        val aadhaarField = strictFields.firstOrNull { it.key == "aadhaar_number" }
        assertNotNull("Strict KYC must have aadhaar_number field", aadhaarField)
        assertTrue("Aadhaar must be mandatory in strict KYC mode", aadhaarField!!.required)

        val dobField = strictFields.firstOrNull { it.key == "dob" }
        assertNotNull("Strict KYC must have dob field", dobField)
        assertTrue("DOB must be mandatory in strict KYC mode", dobField!!.required)
    }

    @Test
    fun testModuleFilterIsolation() {
        val allFields = RegistrationConfigJsonEngine.getPresetFields(baseFields, RegistrationConfigPreset.STANDARD)
        
        val customerFields = allFields.filter { it.targetModule == RegistrationTargetModule.ALL || it.targetModule == RegistrationTargetModule.CUSTOMER }
        assertTrue("Customer module must have fields", customerFields.isNotEmpty())

        val hostFields = allFields.filter { it.targetModule == RegistrationTargetModule.ALL || it.targetModule == RegistrationTargetModule.VENUE_OWNER }
        assertTrue("Host module must have fields", hostFields.isNotEmpty())
    }
}
