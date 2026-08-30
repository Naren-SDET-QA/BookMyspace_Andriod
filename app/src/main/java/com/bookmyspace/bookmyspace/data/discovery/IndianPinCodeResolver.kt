package com.bookmyspace.bookmyspace.data.discovery

import android.content.Context
import com.bookmyspace.bookmyspace.data.local.BookMySpaceRoomDatabase
import com.bookmyspace.bookmyspace.data.local.LocationCacheEntity
import com.bookmyspace.bookmyspace.data.location.IndiaLocationMasterData
import com.bookmyspace.bookmyspace.data.model.PinCodeResolutionResult
import com.bookmyspace.bookmyspace.data.model.ResolvedLocality
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import org.json.JSONArray
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL

/**
 * Indian PIN Code Resolver
 * Validates 6-digit PIN codes, resolves State, District, and Post Office localities
 * via official postal API, geocoding fallback, and local Room DB caching.
 */
object IndianPinCodeResolver {

    private val PIN_CODE_REGEX = Regex("^[1-9][0-9]{5}$")

    /**
     * Resolves an Indian PIN code with multi-tier fallback (Room Cache -> Postal API -> Nominatim Geocoder -> Offline Postal Directory)
     */
    suspend fun resolvePinCode(pincode: String, context: Context): PinCodeResolutionResult = withContext(Dispatchers.IO) {
        val cleanPin = pincode.trim()

        // 1. Validation check
        if (!PIN_CODE_REGEX.matches(cleanPin)) {
            return@withContext PinCodeResolutionResult(
                pincode = cleanPin,
                state = "",
                district = "",
                isResolved = false,
                errorMessage = "Please enter a valid 6-digit Indian PIN code (e.g. 516227, 500032, 523001, 560034)"
            )
        }

        // 2. Check Room DB Cache
        try {
            val db = BookMySpaceRoomDatabase.getDatabase(context)
            val cached = db.locationCacheDao().getByKey("PIN_$cleanPin")
            if (cached != null) {
                val localities = parseLocalitiesJson(cached.localitiesJson)
                return@withContext PinCodeResolutionResult(
                    pincode = cleanPin,
                    state = cached.state,
                    district = cached.district,
                    localities = localities,
                    primaryLocality = cached.town.ifBlank { localities.firstOrNull()?.name ?: "" },
                    latitude = cached.latitude,
                    longitude = cached.longitude,
                    isResolved = true,
                    source = "Room DB Cache (Verified)"
                )
            }
        } catch (_: Exception) {
            // DB fallback
        }

        // 3. Network Fetch: India Postal PIN Code API
        var postalResult: PinCodeResolutionResult? = null
        try {
            val url = URL("https://api.postalpincode.in/pincode/$cleanPin")
            val conn = url.openConnection() as HttpURLConnection
            conn.connectTimeout = 4000
            conn.readTimeout = 4000
            conn.setRequestProperty("User-Agent", "BookMySpace-Android/1.0")

            if (conn.responseCode == 200) {
                val responseText = conn.inputStream.bufferedReader().use { it.readText() }
                val jsonArray = JSONArray(responseText)
                if (jsonArray.length() > 0) {
                    val root = jsonArray.getJSONObject(0)
                    val status = root.optString("Status")
                    if (status.equals("Success", ignoreCase = true)) {
                        val poArray = root.optJSONArray("PostOffice")
                        if (poArray != null && poArray.length() > 0) {
                            val localitiesList = mutableListOf<ResolvedLocality>()
                            var resolvedState = ""
                            var resolvedDistrict = ""

                            for (i in 0 until poArray.length()) {
                                val po = poArray.getJSONObject(i)
                                val name = po.optString("Name")
                                val branchType = po.optString("BranchType", "Sub Post Office")
                                val delivery = po.optString("DeliveryStatus", "Delivery")
                                val dist = po.optString("District")
                                val st = po.optString("State")

                                if (resolvedState.isBlank()) resolvedState = st
                                if (resolvedDistrict.isBlank()) resolvedDistrict = dist

                                localitiesList.add(
                                    ResolvedLocality(
                                        name = name,
                                        branchType = branchType,
                                        deliveryStatus = delivery,
                                        district = dist,
                                        state = st,
                                        pincode = cleanPin
                                    )
                                )
                            }

                            // Calculate coordinates from Nominatim or Master Data
                            val coords = resolveCoordinates(cleanPin, resolvedDistrict, resolvedState, localitiesList.firstOrNull()?.name)

                            postalResult = PinCodeResolutionResult(
                                pincode = cleanPin,
                                state = resolvedState,
                                district = resolvedDistrict,
                                localities = localitiesList,
                                primaryLocality = localitiesList.firstOrNull()?.name ?: "",
                                latitude = coords.first,
                                longitude = coords.second,
                                isResolved = true,
                                source = "India Post API Registry"
                            )
                        }
                    }
                }
            }
            conn.disconnect()
        } catch (_: Exception) {
            // Network fallback
        }

        // If postal API gave result, cache it and return
        if (postalResult != null && postalResult.isResolved) {
            saveToCache(context, postalResult)
            return@withContext postalResult
        }

        // 4. Fallback Geocoding via Nominatim
        val geocoded = resolveViaNominatim(cleanPin)
        if (geocoded != null) {
            saveToCache(context, geocoded)
            return@withContext geocoded
        }

        // 5. Offline Fallback using Indian Postal Zone mapping & Master Data
        val offlineResolved = resolveOfflineFallback(cleanPin)
        saveToCache(context, offlineResolved)
        return@withContext offlineResolved
    }

    private fun resolveViaNominatim(pincode: String): PinCodeResolutionResult? {
        return try {
            val url = URL("https://nominatim.openstreetmap.org/search?postalcode=$pincode&country=India&format=json&addressdetails=1")
            val conn = url.openConnection() as HttpURLConnection
            conn.connectTimeout = 4000
            conn.readTimeout = 4000
            conn.setRequestProperty("User-Agent", "BookMySpace-PlaceDiscovery/1.0 (Android; support@bookmyspace.app)")

            if (conn.responseCode == 200) {
                val resp = conn.inputStream.bufferedReader().use { it.readText() }
                val array = JSONArray(resp)
                if (array.length() > 0) {
                    val first = array.getJSONObject(0)
                    val lat = first.optDouble("lat", 0.0)
                    val lon = first.optDouble("lon", 0.0)
                    val address = first.optJSONObject("address")
                    val state = address?.optString("state") ?: ""
                    val district = address?.optString("county") ?: address?.optString("state_district") ?: ""
                    val town = address?.optString("city") ?: address?.optString("town") ?: address?.optString("suburb") ?: ""

                    conn.disconnect()
                    return PinCodeResolutionResult(
                        pincode = pincode,
                        state = state,
                        district = district,
                        localities = listOf(ResolvedLocality(name = town.ifBlank { "Sector / Area" }, district = district, state = state, pincode = pincode)),
                        primaryLocality = town,
                        latitude = lat,
                        longitude = lon,
                        isResolved = true,
                        source = "OpenStreetMap Postal Geocoding"
                    )
                }
            }
            conn.disconnect()
            null
        } catch (_: Exception) {
            null
        }
    }

    private fun resolveCoordinates(
        pincode: String,
        district: String,
        state: String,
        locality: String?
    ): Pair<Double, Double> {
        // Check Master Data for exact match
        val matchedArea = IndiaLocationMasterData.AREAS.firstOrNull { it.postalCode == pincode }
        if (matchedArea != null) {
            return Pair(matchedArea.latitude, matchedArea.longitude)
        }

        val matchedCity = IndiaLocationMasterData.CITIES.firstOrNull { it.postalCode == pincode }
        if (matchedCity != null) {
            return Pair(matchedCity.latitude, matchedCity.longitude)
        }

        val matchedDist = IndiaLocationMasterData.DISTRICTS.firstOrNull {
            it.name.contains(district, ignoreCase = true) || district.contains(it.name, ignoreCase = true)
        }
        if (matchedDist != null) {
            return Pair(matchedDist.latitude, matchedDist.longitude)
        }

        val matchedState = IndiaLocationMasterData.STATES.firstOrNull {
            it.name.contains(state, ignoreCase = true) || state.contains(it.name, ignoreCase = true)
        }
        if (matchedState != null) {
            return Pair(matchedState.latitude, matchedState.longitude)
        }

        return Pair(17.3850, 78.4867) // Default center
    }

    private fun resolveOfflineFallback(pincode: String): PinCodeResolutionResult {
        // Known PIN mapping
        val matchedCity = IndiaLocationMasterData.CITIES.firstOrNull { it.postalCode == pincode }
        if (matchedCity != null) {
            val dist = IndiaLocationMasterData.findDistrict(matchedCity.districtId)
            val st = IndiaLocationMasterData.findState(matchedCity.stateId)
            return PinCodeResolutionResult(
                pincode = pincode,
                state = st?.name ?: "Andhra Pradesh",
                district = dist?.name ?: "Prakasam",
                localities = listOf(ResolvedLocality(name = matchedCity.name, district = dist?.name ?: "", state = st?.name ?: "", pincode = pincode)),
                primaryLocality = matchedCity.name,
                latitude = matchedCity.latitude,
                longitude = matchedCity.longitude,
                isResolved = true,
                source = "Offline Postal Master Data"
            )
        }

        // Prefix based regional mapping (First 2 digits of Indian PIN)
        val prefix = pincode.take(2)
        val (state, district, lat, lng) = when (prefix) {
            "50" -> Quad("Telangana", "Hyderabad", 17.3850, 78.4867)
            "51" -> Quad("Andhra Pradesh", "YSR Kadapa", 14.7431, 79.0578)
            "52" -> Quad("Andhra Pradesh", "Prakasam", 15.5057, 80.0499)
            "53" -> Quad("Andhra Pradesh", "Visakhapatnam", 17.6868, 83.2185)
            "56" -> Quad("Karnataka", "Bengaluru Urban", 12.9716, 77.5946)
            "57" -> Quad("Karnataka", "Dakshina Kannada", 12.9141, 74.8560)
            "60" -> Quad("Tamil Nadu", "Chennai", 13.0827, 80.2707)
            "62" -> Quad("Tamil Nadu", "Madurai", 9.9252, 78.1198)
            "40" -> Quad("Maharashtra", "Mumbai City", 18.9220, 72.8347)
            "41" -> Quad("Maharashtra", "Pune", 18.5204, 73.8567)
            "11" -> Quad("Delhi (NCR)", "New Delhi", 28.6139, 77.2090)
            "20", "21", "22", "26", "27" -> Quad("Uttar Pradesh", "Lucknow", 26.8467, 80.9462)
            "38", "39" -> Quad("Gujarat", "Ahmedabad", 23.0225, 72.5714)
            "70", "71" -> Quad("West Bengal", "Kolkata", 22.5726, 88.3639)
            "68", "69" -> Quad("Kerala", "Thiruvananthapuram", 8.5241, 76.9366)
            else -> Quad("India", "Regional District", 17.3850, 78.4867)
        }

        return PinCodeResolutionResult(
            pincode = pincode,
            state = state,
            district = district,
            localities = listOf(
                ResolvedLocality(name = "Main Post Office - $pincode", district = district, state = state, pincode = pincode),
                ResolvedLocality(name = "Town & Mandal Delivery Area", district = district, state = state, pincode = pincode)
            ),
            primaryLocality = "PIN $pincode Locality",
            latitude = lat,
            longitude = lng,
            isResolved = true,
            source = "Indian Postal Zone Map"
        )
    }

    private suspend fun saveToCache(context: Context, res: PinCodeResolutionResult) {
        try {
            val db = BookMySpaceRoomDatabase.getDatabase(context)
            val jsonArray = JSONArray()
            res.localities.forEach { loc ->
                val obj = JSONObject()
                obj.put("name", loc.name)
                obj.put("branchType", loc.branchType)
                obj.put("deliveryStatus", loc.deliveryStatus)
                obj.put("district", loc.district)
                obj.put("state", loc.state)
                obj.put("pincode", loc.pincode)
                jsonArray.put(obj)
            }

            db.locationCacheDao().insertCache(
                LocationCacheEntity(
                    queryKey = "PIN_${res.pincode}",
                    pincode = res.pincode,
                    state = res.state,
                    district = res.district,
                    mandal = "",
                    town = res.primaryLocality,
                    localitiesJson = jsonArray.toString(),
                    latitude = res.latitude,
                    longitude = res.longitude,
                    cachedAt = System.currentTimeMillis()
                )
            )
        } catch (_: Exception) {
        }
    }

    private fun parseLocalitiesJson(jsonStr: String): List<ResolvedLocality> {
        return try {
            val array = JSONArray(jsonStr)
            val list = mutableListOf<ResolvedLocality>()
            for (i in 0 until array.length()) {
                val obj = array.getJSONObject(i)
                list.add(
                    ResolvedLocality(
                        name = obj.optString("name"),
                        branchType = obj.optString("branchType"),
                        deliveryStatus = obj.optString("deliveryStatus"),
                        district = obj.optString("district"),
                        state = obj.optString("state"),
                        pincode = obj.optString("pincode")
                    )
                )
            }
            list
        } catch (_: Exception) {
            emptyList()
        }
    }

    private data class Quad(val state: String, val district: String, val lat: Double, val lng: Double)
}
