package com.bookmyspace.bookmyspace.data.location

import com.bookmyspace.bookmyspace.data.model.*
import kotlin.math.*

/**
 * Official Indian Administrative Location Master Data.
 * Deep hierarchy: Country -> State -> District -> Mandal/Taluk -> City/Town/Village -> Area/Locality.
 */
object IndiaLocationMasterData {

    val COUNTRIES = listOf(
        Country(id = "IN", code = "IND", name = "India", phoneCode = "+91", currency = "INR"),
        Country(id = "AE", code = "ARE", name = "United Arab Emirates", phoneCode = "+971", currency = "AED"),
        Country(id = "SG", code = "SGP", name = "Singapore", phoneCode = "+65", currency = "SGD"),
        Country(id = "US", code = "USA", name = "United States", phoneCode = "+1", currency = "USD"),
        Country(id = "UK", code = "GBR", name = "United Kingdom", phoneCode = "+44", currency = "GBP")
    )
    val countries = COUNTRIES

    val COUNTRY_INDIA = COUNTRIES.first()

    // ==========================================
    // 1. STATES & UNION TERRITORIES
    // ==========================================
    val STATES = listOf(
        // India States & UTs
        State("IN-AP", "IN", "AP", "Andhra Pradesh", "Amaravati", 15.9129, 79.7400, 1),
        State("IN-TG", "IN", "TG", "Telangana", "Hyderabad", 17.1232, 79.2088, 2),
        State("IN-KA", "IN", "KA", "Karnataka", "Bengaluru", 15.3173, 75.7139, 3),
        State("IN-TN", "IN", "TN", "Tamil Nadu", "Chennai", 11.1271, 78.6569, 4),
        State("IN-MH", "IN", "MH", "Maharashtra", "Mumbai", 19.7515, 75.7139, 5),
        State("IN-DL", "IN", "DL", "Delhi (NCR)", "New Delhi", 28.7041, 77.1025, 6),
        State("IN-KL", "IN", "KL", "Kerala", "Thiruvananthapuram", 10.8505, 76.2711, 7),
        State("IN-GJ", "IN", "GJ", "Gujarat", "Gandhinagar", 22.2587, 71.1924, 8),
        State("IN-UP", "IN", "UP", "Uttar Pradesh", "Lucknow", 26.8467, 80.9462, 9),
        State("IN-WB", "IN", "WB", "West Bengal", "Kolkata", 22.9868, 87.8550, 10),

        // UAE Emirates
        State("AE-DU", "AE", "DXB", "Dubai", "Dubai", 25.2048, 55.2708, 1),
        State("AE-AZ", "AE", "AUH", "Abu Dhabi", "Abu Dhabi", 24.4539, 54.3773, 2),
        State("AE-SH", "AE", "SHJ", "Sharjah", "Sharjah", 25.3463, 55.4209, 3),

        // Singapore Regions
        State("SG-CR", "SG", "SGP", "Central Region", "Singapore", 1.3521, 103.8198, 1),
        State("SG-ER", "SG", "ER", "East Region", "Tampines", 1.3521, 103.9400, 2),

        // US States
        State("US-CA", "US", "CA", "California", "Sacramento", 36.7783, -119.4179, 1),
        State("US-NY", "US", "NY", "New York", "Albany", 40.7128, -74.0060, 2),
        State("US-TX", "US", "TX", "Texas", "Austin", 31.9686, -99.9018, 3),

        // UK
        State("UK-ENG", "UK", "ENG", "England", "London", 51.5074, -0.1278, 1)
    )
    val states = STATES

    // ==========================================
    // 2. DISTRICTS
    // ==========================================
    val DISTRICTS = listOf(
        // Andhra Pradesh
        District("DIST_AP_PRAKASAM", "IN-AP", "Prakasam", "PKM", "Ongole", 15.5057, 80.0499),
        District("DIST_AP_NTR", "IN-AP", "NTR (Vijayawada)", "VJA", "Vijayawada", 16.5062, 80.6480),
        District("DIST_AP_GUNTUR", "IN-AP", "Guntur", "GNT", "Guntur", 16.3067, 80.4365),
        District("DIST_AP_VISAKHAPATNAM", "IN-AP", "Visakhapatnam", "VSKP", "Visakhapatnam", 17.6868, 83.2185),
        District("DIST_AP_TIRUPATI", "IN-AP", "Tirupati", "TPT", "Tirupati", 13.6288, 79.4192),
        District("DIST_AP_KURNOOL", "IN-AP", "Kurnool", "KNL", "Kurnool", 15.8281, 78.0373),
        District("DIST_AP_NELLORE", "IN-AP", "SPSR Nellore", "NLR", "Nellore", 14.4426, 79.9865),
        District("DIST_AP_EAST_GODAVARI", "IN-AP", "East Godavari (Rajahmundry)", "RJY", "Rajahmundry", 17.0005, 81.8040),
        District("DIST_AP_KAKINADA", "IN-AP", "Kakinada", "KKD", "Kakinada", 16.9891, 82.2475),
        District("DIST_AP_ANANTAPUR", "IN-AP", "Anantapur", "ATP", "Anantapur", 14.6819, 77.6006),
        District("DIST_AP_CHITTOOR", "IN-AP", "Chittoor", "CTR", "Chittoor", 13.2172, 79.1003),
        District("DIST_AP_KADAPA", "IN-AP", "YSR Kadapa", "KDP", "Kadapa", 14.4673, 78.8242),

        // Telangana
        District("DIST_TG_HYDERABAD", "IN-TG", "Hyderabad", "HYD", "Hyderabad", 17.3850, 78.4867),
        District("DIST_TG_RANGAREDDY", "IN-TG", "Rangareddy", "RRD", "Shamshabad", 17.2543, 78.4311),
        District("DIST_TG_MEDCHAL", "IN-TG", "Medchal-Malkajgiri", "MDL", "Malkajgiri", 17.5449, 78.5718),
        District("DIST_TG_WARANGAL", "IN-TG", "Warangal", "WGL", "Warangal", 17.9689, 79.5941),
        District("DIST_TG_KARIMNAGAR", "IN-TG", "Karimnagar", "KRM", "Karimnagar", 18.4386, 79.1288),
        District("DIST_TG_NIZAMABAD", "IN-TG", "Nizamabad", "NZB", "Nizamabad", 18.6725, 78.0941),
        District("DIST_TG_KHAMMAM", "IN-TG", "Khammam", "KHM", "Khammam", 17.2473, 80.1514),
        District("DIST_TG_SANGAREDDY", "IN-TG", "Sangareddy", "SRD", "Sangareddy", 17.6190, 78.0814),
        District("DIST_TG_SIDDIPET", "IN-TG", "Siddipet", "SDP", "Siddipet", 18.1018, 78.8520),

        // Karnataka
        District("DIST_KA_BANGALORE_URBAN", "IN-KA", "Bengaluru Urban", "BLR", "Bengaluru", 12.9716, 77.5946),
        District("DIST_KA_MYSORE", "IN-KA", "Mysuru", "MYS", "Mysuru", 12.2958, 76.6394),
        District("DIST_KA_MANGALORE", "IN-KA", "Dakshina Kannada (Mangaluru)", "MLR", "Mangaluru", 12.9141, 74.8560),

        // Tamil Nadu
        District("DIST_TN_CHENNAI", "IN-TN", "Chennai", "CHN", "Chennai", 13.0827, 80.2707),
        District("DIST_TN_COIMBATORE", "IN-TN", "Coimbatore", "CBE", "Coimbatore", 11.0168, 76.9558),
        District("DIST_TN_MADURAI", "IN-TN", "Madurai", "MDU", "Madurai", 9.9252, 78.1198),

        // Maharashtra
        District("DIST_MH_MUMBAI", "IN-MH", "Mumbai City", "MUM", "Mumbai", 18.9220, 72.8347),
        District("DIST_MH_PUNE", "IN-MH", "Pune", "PUN", "Pune", 18.5204, 73.8567),
        District("DIST_MH_THANE", "IN-MH", "Thane", "THN", "Thane", 19.2183, 72.9781),

        // Delhi
        District("DIST_DL_NEW_DELHI", "IN-DL", "New Delhi", "DEL", "New Delhi", 28.6139, 77.2090),
        District("DIST_DL_SOUTH_DELHI", "IN-DL", "South Delhi", "SDEL", "Saket", 28.5244, 77.2066),

        // International Districts
        District("DIST_AE_DUBAI_CENTRAL", "AE-DU", "Dubai Central", "DXB_C", "Downtown", 25.2048, 55.2708),
        District("DIST_AE_DUBAI_SOUTH", "AE-DU", "Dubai Marina & JBR", "DXB_S", "Marina", 25.0805, 55.1403),
        District("DIST_AE_AUH_CITY", "AE-AZ", "Abu Dhabi City", "AUH_C", "Corniche", 24.4539, 54.3773),
        District("DIST_SG_DOWNTOWN", "SG-CR", "Singapore Downtown", "SG_DT", "Downtown", 1.2800, 103.8500),
        District("DIST_US_SF_BAY", "US-CA", "San Francisco Bay Area", "SF_BAY", "San Francisco", 37.7749, -122.4194),
        District("DIST_US_LA", "US-CA", "Los Angeles County", "LA", "Los Angeles", 34.0522, -118.2437),
        District("DIST_US_NYC_MANHATTAN", "US-NY", "Manhattan", "MAN", "New York", 40.7831, -73.9712),
        District("DIST_UK_GREATER_LONDON", "UK-ENG", "Greater London", "LDN", "London", 51.5074, -0.1278)
    )
    val districts = DISTRICTS

    // ==========================================
    // 3. MANDALS / TALUKS
    // ==========================================
    val MANDALS = listOf(
        // Prakasam District
        Mandal("MANDAL_AP_ONGOLE", "DIST_AP_PRAKASAM", "IN-AP", "Ongole Urban Mandal", "OGL_U", 15.5057, 80.0499),
        Mandal("MANDAL_AP_ONGOLE_RURAL", "DIST_AP_PRAKASAM", "IN-AP", "Ongole Rural Mandal", "OGL_R", 15.5200, 80.0200),
        Mandal("MANDAL_AP_CHIRALA", "DIST_AP_PRAKASAM", "IN-AP", "Chirala Mandal", "CHL", 15.8246, 80.3522),
        Mandal("MANDAL_AP_SINGARAYAKONDA", "DIST_AP_PRAKASAM", "IN-AP", "Singarayakonda Mandal", "SYK", 15.2500, 80.0300),
        Mandal("MANDAL_AP_KANDUKUR", "DIST_AP_PRAKASAM", "IN-AP", "Kandukur Mandal", "KDK", 15.2165, 79.9042),
        Mandal("MANDAL_AP_ADDANKI", "DIST_AP_PRAKASAM", "IN-AP", "Addanki Mandal", "ADK", 15.8117, 79.9744),
        Mandal("MANDAL_AP_PODILI", "DIST_AP_PRAKASAM", "IN-AP", "Podili Mandal", "PDL", 15.6042, 79.6067),
        Mandal("MANDAL_AP_MARKAPUR", "DIST_AP_PRAKASAM", "IN-AP", "Markapur Mandal", "MKP", 15.7350, 79.2710),

        // NTR / Vijayawada District
        Mandal("MANDAL_AP_VIJAYAWADA_URBAN", "DIST_AP_NTR", "IN-AP", "Vijayawada Urban Mandal", "VJA_U", 16.5062, 80.6480),
        Mandal("MANDAL_AP_VIJAYAWADA_RURAL", "DIST_AP_NTR", "IN-AP", "Vijayawada Rural Mandal", "VJA_R", 16.5400, 80.6800),

        // Guntur District
        Mandal("MANDAL_AP_GUNTUR_EAST", "DIST_AP_GUNTUR", "IN-AP", "Guntur East Mandal", "GNT_E", 16.3067, 80.4365),
        Mandal("MANDAL_AP_GUNTUR_WEST", "DIST_AP_GUNTUR", "IN-AP", "Guntur West Mandal", "GNT_W", 16.3100, 80.4100),

        // Visakhapatnam District
        Mandal("MANDAL_AP_VSKP_URBAN", "DIST_AP_VISAKHAPATNAM", "IN-AP", "Visakhapatnam Urban Mandal", "VSKP_U", 17.6868, 83.2185),

        // Hyderabad District
        Mandal("MANDAL_TG_SERILINGAMPALLY", "DIST_TG_HYDERABAD", "IN-TG", "Serilingampally Mandal", "SER", 17.4834, 78.3158),
        Mandal("MANDAL_TG_KHAIRATABAD", "DIST_TG_HYDERABAD", "IN-TG", "Khairatabad Mandal", "KHB", 17.4116, 78.4590),
        Mandal("MANDAL_TG_SECUNDERABAD", "DIST_TG_HYDERABAD", "IN-TG", "Secunderabad Mandal", "SCB", 17.4399, 78.4983),
        Mandal("MANDAL_TG_SHAIKPET", "DIST_TG_HYDERABAD", "IN-TG", "Shaikpet Mandal", "SKP", 17.4087, 78.3986),
        Mandal("MANDAL_TG_AMEERPET", "DIST_TG_HYDERABAD", "IN-TG", "Ameerpet Mandal", "AMP", 17.4375, 78.4483),
        Mandal("MANDAL_TG_CHARMINAR", "DIST_TG_HYDERABAD", "IN-TG", "Charminar Mandal", "CHM", 17.3616, 78.4747),

        // Rangareddy District
        Mandal("MANDAL_TG_RAJENDRANAGAR", "DIST_TG_RANGAREDDY", "IN-TG", "Rajendranagar Mandal", "RJN", 17.3197, 78.4024),
        Mandal("MANDAL_TG_GANDIPET", "DIST_TG_RANGAREDDY", "IN-TG", "Gandipet Mandal", "GND", 17.3888, 78.3300),

        // Bangalore
        Mandal("MANDAL_KA_BLR_SOUTH", "DIST_KA_BANGALORE_URBAN", "IN-KA", "Bengaluru South Taluk", "BLR_S", 12.9166, 77.6101),
        Mandal("MANDAL_KA_BLR_EAST", "DIST_KA_BANGALORE_URBAN", "IN-KA", "Bengaluru East Taluk", "BLR_E", 12.9716, 77.7500),
        // International Mandals & Cities & Areas
        Mandal("MANDAL_AE_DXB_DOWNTOWN", "DIST_AE_DUBAI_CENTRAL", "AE-DU", "Downtown Dubai", "DXB_DWN", 25.2048, 55.2708),
        Mandal("MANDAL_AE_DXB_MARINA", "DIST_AE_DUBAI_SOUTH", "AE-DU", "Dubai Marina", "DXB_MAR", 25.0805, 55.1403),
        Mandal("MANDAL_SG_CENTRAL", "DIST_SG_DOWNTOWN", "SG-CR", "Central Area", "SG_CEN", 1.2800, 103.8500),
        Mandal("MANDAL_US_SF_DOWNTOWN", "DIST_US_SF_BAY", "US-CA", "San Francisco Downtown", "SF_DT", 37.7749, -122.4194),
        Mandal("MANDAL_US_NYC_MIDTOWN", "DIST_US_NYC_MANHATTAN", "US-NY", "Midtown Manhattan", "NYC_MID", 40.7549, -73.9840),
        Mandal("MANDAL_UK_WESTMINSTER", "DIST_UK_GREATER_LONDON", "UK-ENG", "City of Westminster", "UK_WES", 51.4975, -0.1357)
    )
    val mandals = MANDALS

    // ==========================================
    // 4. CITIES / TOWNS / VILLAGES
    // ==========================================
    val CITIES = listOf(
        // Prakasam
        CityTown("CITY_AP_ONGOLE", "MANDAL_AP_ONGOLE", "DIST_AP_PRAKASAM", "IN-AP", "Ongole", SettlementType.CITY, "523001", 15.5057, 80.0499),
        CityTown("CITY_AP_CHIRALA", "MANDAL_AP_CHIRALA", "DIST_AP_PRAKASAM", "IN-AP", "Chirala", SettlementType.TOWN, "523155", 15.8246, 80.3522),
        CityTown("CITY_AP_SINGARAYAKONDA", "MANDAL_AP_SINGARAYAKONDA", "DIST_AP_PRAKASAM", "IN-AP", "Singarayakonda", SettlementType.TOWN, "523101", 15.2500, 80.0300),
        CityTown("CITY_AP_KANDUKUR", "MANDAL_AP_KANDUKUR", "DIST_AP_PRAKASAM", "IN-AP", "Kandukur", SettlementType.TOWN, "523105", 15.2165, 79.9042),
        CityTown("CITY_AP_ADDANKI", "MANDAL_AP_ADDANKI", "DIST_AP_PRAKASAM", "IN-AP", "Addanki", SettlementType.TOWN, "523201", 15.8117, 79.9744),
        CityTown("CITY_AP_PODILI", "MANDAL_AP_PODILI", "DIST_AP_PRAKASAM", "IN-AP", "Podili", SettlementType.TOWN, "523240", 15.6042, 79.6067),
        CityTown("CITY_AP_MARKAPUR", "MANDAL_AP_MARKAPUR", "DIST_AP_PRAKASAM", "IN-AP", "Markapur", SettlementType.TOWN, "523316", 15.7350, 79.2710),

        // Andhra Pradesh Others
        CityTown("CITY_AP_VIJAYAWADA", "MANDAL_AP_VIJAYAWADA_URBAN", "DIST_AP_NTR", "IN-AP", "Vijayawada", SettlementType.CITY, "520001", 16.5062, 80.6480),
        CityTown("CITY_AP_GUNTUR", "MANDAL_AP_GUNTUR_EAST", "DIST_AP_GUNTUR", "IN-AP", "Guntur", SettlementType.CITY, "522002", 16.3067, 80.4365),
        CityTown("CITY_AP_VISAKHAPATNAM", "MANDAL_AP_VSKP_URBAN", "DIST_AP_VISAKHAPATNAM", "IN-AP", "Visakhapatnam", SettlementType.METRO_CITY, "530001", 17.6868, 83.2185),
        CityTown("CITY_AP_TIRUPATI", "MANDAL_AP_ONGOLE", "DIST_AP_TIRUPATI", "IN-AP", "Tirupati", SettlementType.CITY, "517501", 13.6288, 79.4192),

        // Telangana
        CityTown("CITY_TG_HYDERABAD", "MANDAL_TG_SERILINGAMPALLY", "DIST_TG_HYDERABAD", "IN-TG", "Hyderabad", SettlementType.METRO_CITY, "500001", 17.3850, 78.4867),
        CityTown("CITY_TG_SECUNDERABAD", "MANDAL_TG_SECUNDERABAD", "DIST_TG_HYDERABAD", "IN-TG", "Secunderabad", SettlementType.CITY, "500003", 17.4399, 78.4983),
        CityTown("CITY_TG_WARANGAL", "MANDAL_TG_SERILINGAMPALLY", "DIST_TG_WARANGAL", "IN-TG", "Warangal", SettlementType.CITY, "506002", 17.9689, 79.5941),

        // Karnataka & Others
        CityTown("CITY_KA_BENGALURU", "MANDAL_KA_BLR_SOUTH", "DIST_KA_BANGALORE_URBAN", "IN-KA", "Bengaluru", SettlementType.METRO_CITY, "560001", 12.9716, 77.5946),
        CityTown("CITY_TN_CHENNAI", "MANDAL_KA_BLR_SOUTH", "DIST_TN_CHENNAI", "IN-TN", "Chennai", SettlementType.METRO_CITY, "600001", 13.0827, 80.2707),
        CityTown("CITY_MH_MUMBAI", "MANDAL_KA_BLR_SOUTH", "DIST_MH_MUMBAI", "IN-MH", "Mumbai", SettlementType.METRO_CITY, "400001", 18.9220, 72.8347),
        CityTown("CITY_DL_DELHI", "MANDAL_KA_BLR_SOUTH", "DIST_DL_NEW_DELHI", "IN-DL", "New Delhi", SettlementType.METRO_CITY, "110001", 28.6139, 77.2090),

        // International Cities
        CityTown("CITY_AE_DUBAI", "MANDAL_AE_DXB_DOWNTOWN", "DIST_AE_DUBAI_CENTRAL", "AE-DU", "Dubai", SettlementType.METRO_CITY, "00000", 25.2048, 55.2708),
        CityTown("CITY_SG_SINGAPORE", "MANDAL_SG_CENTRAL", "DIST_SG_DOWNTOWN", "SG-CR", "Singapore", SettlementType.METRO_CITY, "018956", 1.2800, 103.8500),
        CityTown("CITY_US_SF", "MANDAL_US_SF_DOWNTOWN", "DIST_US_SF_BAY", "US-CA", "San Francisco", SettlementType.METRO_CITY, "94102", 37.7749, -122.4194),
        CityTown("CITY_US_NYC", "MANDAL_US_NYC_MIDTOWN", "DIST_US_NYC_MANHATTAN", "US-NY", "New York City", SettlementType.METRO_CITY, "10001", 40.7128, -74.0060),
        CityTown("CITY_UK_LONDON", "MANDAL_UK_WESTMINSTER", "DIST_UK_GREATER_LONDON", "UK-ENG", "London", SettlementType.METRO_CITY, "SW1A", 51.5074, -0.1278)
    )
    val cities = CITIES

    // ==========================================
    // 5. AREAS / LOCALITIES
    // ==========================================
    val AREAS = listOf(
        // Ongole Areas
        LocationArea("AREA_AP_OGL_LAWYERPET", "CITY_AP_ONGOLE", "MANDAL_AP_ONGOLE", "DIST_AP_PRAKASAM", "IN-AP", "Lawyerpet", "523001", "Near Old Bus Stand", 15.5080, 80.0450, true),
        LocationArea("AREA_AP_OGL_KURNOOL_RD", "CITY_AP_ONGOLE", "MANDAL_AP_ONGOLE", "DIST_AP_PRAKASAM", "IN-AP", "Kurnool Road", "523002", "Near Flyover Junction", 15.5120, 80.0380, true),
        LocationArea("AREA_AP_OGL_TRUNK_RD", "CITY_AP_ONGOLE", "MANDAL_AP_ONGOLE", "DIST_AP_PRAKASAM", "IN-AP", "Trunk Road", "523001", "Opp. RTC Complex", 15.5040, 80.0510, true),
        LocationArea("AREA_AP_OGL_SANTHAPETA", "CITY_AP_ONGOLE", "MANDAL_AP_ONGOLE", "DIST_AP_PRAKASAM", "IN-AP", "Santhapeta", "523001", "Near Clock Tower", 15.5010, 80.0470, true),
        LocationArea("AREA_AP_OGL_RAMNAGAR", "CITY_AP_ONGOLE", "MANDAL_AP_ONGOLE", "DIST_AP_PRAKASAM", "IN-AP", "Ramnagar", "523002", "Near RIMS Hospital", 15.5190, 80.0320, false),
        LocationArea("AREA_AP_OGL_MANGAMUR_RD", "CITY_AP_ONGOLE", "MANDAL_AP_ONGOLE", "DIST_AP_PRAKASAM", "IN-AP", "Mangamur Road", "523002", "Near Ring Road", 15.5160, 80.0270, false),
        LocationArea("AREA_AP_OGL_BHAGYANAGAR", "CITY_AP_ONGOLE", "MANDAL_AP_ONGOLE", "DIST_AP_PRAKASAM", "IN-AP", "Bhagyanagar", "523001", "Near Collector Office", 15.5090, 80.0550, false),

        // Chirala Areas
        LocationArea("AREA_AP_CHL_VODAREVU", "CITY_AP_CHIRALA", "MANDAL_AP_CHIRALA", "DIST_AP_PRAKASAM", "IN-AP", "Vodarevu Beach Road", "523157", "Beach Resort Strip", 15.7900, 80.3900, true),
        LocationArea("AREA_AP_CHL_CLOCK_TOWER", "CITY_AP_CHIRALA", "MANDAL_AP_CHIRALA", "DIST_AP_PRAKASAM", "IN-AP", "Clock Tower Centre", "523155", "Handloom Bazaar", 15.8246, 80.3522, true),

        // Hyderabad Areas
        LocationArea("AREA_TG_HYD_GACHIBOWLI", "CITY_TG_HYDERABAD", "MANDAL_TG_SERILINGAMPALLY", "DIST_TG_HYDERABAD", "IN-TG", "Gachibowli", "500032", "Near Financial District & Stadium", 17.4401, 78.3489, true),
        LocationArea("AREA_TG_HYD_HITEC_CITY", "CITY_TG_HYDERABAD", "MANDAL_TG_SERILINGAMPALLY", "DIST_TG_HYDERABAD", "IN-TG", "HITEC City", "500081", "Near Cyber Towers & Mindspace", 17.4435, 78.3772, true),
        LocationArea("AREA_TG_HYD_MADHAPUR", "CITY_TG_HYDERABAD", "MANDAL_TG_SERILINGAMPALLY", "DIST_TG_HYDERABAD", "IN-TG", "Madhapur", "500081", "Near Inorbit Mall", 17.4483, 78.3915, true),
        LocationArea("AREA_TG_HYD_BANJARA_HILLS", "CITY_TG_HYDERABAD", "MANDAL_TG_KHAIRATABAD", "DIST_TG_HYDERABAD", "IN-TG", "Banjara Hills", "500034", "Road No. 12 & 1", 17.4156, 78.4350, true),
        LocationArea("AREA_TG_HYD_JUBILEE_HILLS", "CITY_TG_HYDERABAD", "MANDAL_TG_SHAIKPET", "DIST_TG_HYDERABAD", "IN-TG", "Jubilee Hills", "500033", "Road No. 36 & Checkpost", 17.4319, 78.4073, true),
        LocationArea("AREA_TG_HYD_KONDAPUR", "CITY_TG_HYDERABAD", "MANDAL_TG_SERILINGAMPALLY", "DIST_TG_HYDERABAD", "IN-TG", "Kondapur", "500084", "Near Botanical Garden", 17.4699, 78.3578, true),
        LocationArea("AREA_TG_HYD_KUKATPALLY", "CITY_TG_HYDERABAD", "MANDAL_TG_SERILINGAMPALLY", "DIST_TG_HYDERABAD", "IN-TG", "Kukatpally", "500072", "KPHB Colony Phase 1-9", 17.4947, 78.3996, true),
        LocationArea("AREA_TG_HYD_SECUNDERABAD", "CITY_TG_SECUNDERABAD", "MANDAL_TG_SECUNDERABAD", "DIST_TG_HYDERABAD", "IN-TG", "Secunderabad Cantonment", "500003", "Near Clock Tower & Club", 17.4399, 78.4983, true),

        // Vijayawada Areas
        LocationArea("AREA_AP_VJA_BENZ_CIRCLE", "CITY_AP_VIJAYAWADA", "MANDAL_AP_VIJAYAWADA_URBAN", "DIST_AP_NTR", "IN-AP", "Benz Circle", "520010", "MG Road Commercial Hub", 16.4980, 80.6550, true),
        LocationArea("AREA_AP_VJA_GOVERNORPET", "CITY_AP_VIJAYAWADA", "MANDAL_AP_VIJAYAWADA_URBAN", "DIST_AP_NTR", "IN-AP", "Governorpet", "520002", "Near Railway Station", 16.5100, 80.6300, true),

        // Bengaluru Areas
        LocationArea("AREA_KA_BLR_KORAMANGALA", "CITY_KA_BENGALURU", "MANDAL_KA_BLR_SOUTH", "DIST_KA_BANGALORE_URBAN", "IN-KA", "Koramangala", "560034", "Sony World Signal", 12.9352, 77.6245, true),
        LocationArea("AREA_KA_BLR_INDIRANAGAR", "CITY_KA_BENGALURU", "MANDAL_KA_BLR_EAST", "DIST_KA_BANGALORE_URBAN", "IN-KA", "Indiranagar", "560038", "100ft Road Hub", 12.9784, 77.6408, true),

        // International Areas
        LocationArea("AREA_AE_DXB_BURJ", "CITY_AE_DUBAI", "MANDAL_AE_DXB_DOWNTOWN", "DIST_AE_DUBAI_CENTRAL", "AE-DU", "Downtown Burj Khalifa", "00000", "Near Dubai Mall", 25.1972, 55.2744, true),
        LocationArea("AREA_AE_DXB_MARINA_WALK", "CITY_AE_DUBAI", "MANDAL_AE_DXB_MARINA", "DIST_AE_DUBAI_SOUTH", "AE-DU", "Marina Walk", "00000", "JBR Beach Road", 25.0780, 55.1380, true),
        LocationArea("AREA_SG_MARINA_BAY", "CITY_SG_SINGAPORE", "MANDAL_SG_CENTRAL", "DIST_SG_DOWNTOWN", "SG-CR", "Marina Bay Sands", "018956", "Bayfront Ave", 1.2834, 103.8607, true),
        LocationArea("AREA_US_SF_SOMA", "CITY_US_SF", "MANDAL_US_SF_DOWNTOWN", "DIST_US_SF_BAY", "US-CA", "SoMa (South of Market)", "94103", "Moscone Center", 37.7785, -122.4056, true),
        LocationArea("AREA_US_NYC_TIMES_SQ", "CITY_US_NYC", "MANDAL_US_NYC_MIDTOWN", "DIST_US_NYC_MANHATTAN", "US-NY", "Times Square", "10036", "Broadway & 42nd St", 40.7580, -73.9855, true),
        LocationArea("AREA_UK_LONDON_COVENT", "CITY_UK_LONDON", "MANDAL_UK_WESTMINSTER", "DIST_UK_GREATER_LONDON", "UK-ENG", "Covent Garden", "WC2E", "West End", 51.5117, -0.1240, true)
    )
    val areas = AREAS

    // ==========================================
    // 6. POPULAR QUICK-SELECTION PRESETS
    // ==========================================
    val POPULAR_LOCATION_PRESETS = listOf(
        LocationHierarchy(
            countryId = "IN", stateId = "IN-AP", districtId = "DIST_AP_PRAKASAM",
            mandalId = "MANDAL_AP_ONGOLE", cityTownId = "CITY_AP_ONGOLE", areaId = "AREA_AP_OGL_LAWYERPET",
            countryName = "India", stateName = "Andhra Pradesh", districtName = "Prakasam",
            mandalName = "Ongole Urban Mandal", cityName = "Ongole", areaName = "Lawyerpet",
            postalCode = "523001", latitude = 15.5080, longitude = 80.0450
        ),
        LocationHierarchy(
            countryId = "IN", stateId = "IN-AP", districtId = "DIST_AP_PRAKASAM",
            mandalId = "MANDAL_AP_ONGOLE", cityTownId = "CITY_AP_ONGOLE", areaId = "AREA_AP_OGL_KURNOOL_RD",
            countryName = "India", stateName = "Andhra Pradesh", districtName = "Prakasam",
            mandalName = "Ongole Urban Mandal", cityName = "Ongole", areaName = "Kurnool Road",
            postalCode = "523002", latitude = 15.5120, longitude = 80.0380
        ),
        LocationHierarchy(
            countryId = "IN", stateId = "IN-AP", districtId = "DIST_AP_PRAKASAM",
            mandalId = "MANDAL_AP_CHIRALA", cityTownId = "CITY_AP_CHIRALA", areaId = "AREA_AP_CHL_VODAREVU",
            countryName = "India", stateName = "Andhra Pradesh", districtName = "Prakasam",
            mandalName = "Chirala Mandal", cityName = "Chirala", areaName = "Vodarevu Beach",
            postalCode = "523157", latitude = 15.7900, longitude = 80.3900
        ),
        LocationHierarchy(
            countryId = "IN", stateId = "IN-TG", districtId = "DIST_TG_HYDERABAD",
            mandalId = "MANDAL_TG_SERILINGAMPALLY", cityTownId = "CITY_TG_HYDERABAD", areaId = "AREA_TG_HYD_GACHIBOWLI",
            countryName = "India", stateName = "Telangana", districtName = "Hyderabad",
            mandalName = "Serilingampally", cityName = "Hyderabad", areaName = "Gachibowli",
            postalCode = "500032", latitude = 17.4401, longitude = 78.3489
        ),
        LocationHierarchy(
            countryId = "IN", stateId = "IN-TG", districtId = "DIST_TG_HYDERABAD",
            mandalId = "MANDAL_TG_KHAIRATABAD", cityTownId = "CITY_TG_HYDERABAD", areaId = "AREA_TG_HYD_BANJARA_HILLS",
            countryName = "India", stateName = "Telangana", districtName = "Hyderabad",
            mandalName = "Khairatabad", cityName = "Hyderabad", areaName = "Banjara Hills",
            postalCode = "500034", latitude = 17.4156, longitude = 78.4350
        ),
        LocationHierarchy(
            countryId = "IN", stateId = "IN-TG", districtId = "DIST_TG_HYDERABAD",
            mandalId = "MANDAL_TG_SHAIKPET", cityTownId = "CITY_TG_HYDERABAD", areaId = "AREA_TG_HYD_JUBILEE_HILLS",
            countryName = "India", stateName = "Telangana", districtName = "Hyderabad",
            mandalName = "Shaikpet", cityName = "Hyderabad", areaName = "Jubilee Hills",
            postalCode = "500033", latitude = 17.4319, longitude = 78.4073
        ),
        LocationHierarchy(
            countryId = "IN", stateId = "IN-AP", districtId = "DIST_AP_NTR",
            mandalId = "MANDAL_AP_VIJAYAWADA_URBAN", cityTownId = "CITY_AP_VIJAYAWADA", areaId = "AREA_AP_VJA_BENZ_CIRCLE",
            countryName = "India", stateName = "Andhra Pradesh", districtName = "NTR (Vijayawada)",
            mandalName = "Vijayawada Urban", cityName = "Vijayawada", areaName = "Benz Circle",
            postalCode = "520010", latitude = 16.4980, longitude = 80.6550
        ),
        LocationHierarchy(
            countryId = "IN", stateId = "IN-KA", districtId = "DIST_KA_BANGALORE_URBAN",
            mandalId = "MANDAL_KA_BLR_SOUTH", cityTownId = "CITY_KA_BENGALURU", areaId = "AREA_KA_BLR_KORAMANGALA",
            countryName = "India", stateName = "Karnataka", districtName = "Bengaluru Urban",
            mandalName = "Bengaluru South", cityName = "Bengaluru", areaName = "Koramangala",
            postalCode = "560034", latitude = 12.9352, longitude = 77.6245
        ),
        LocationHierarchy(
            countryId = "AE", stateId = "AE-DU", districtId = "DIST_AE_DUBAI_CENTRAL",
            mandalId = "MANDAL_AE_DXB_DOWNTOWN", cityTownId = "CITY_AE_DUBAI", areaId = "AREA_AE_DXB_BURJ",
            countryName = "United Arab Emirates", stateName = "Dubai", districtName = "Dubai Central",
            mandalName = "Downtown Dubai", cityName = "Dubai", areaName = "Downtown Burj Khalifa",
            postalCode = "00000", latitude = 25.1972, longitude = 55.2744
        )
    )
    val popularPresets = POPULAR_LOCATION_PRESETS

    // ==========================================
    // HELPER LOOKUP METHODS
    // ==========================================

    fun getStatesForCountry(countryId: String): List<State> {
        return STATES.filter { it.countryId == countryId }
    }

    fun getDistrictsForState(stateId: String): List<District> {
        return DISTRICTS.filter { it.stateId == stateId }
    }

    fun getMandalsForDistrict(districtId: String): List<Mandal> {
        return MANDALS.filter { it.districtId == districtId }
    }

    fun getCitiesForMandal(mandalId: String): List<CityTown> {
        return CITIES.filter { it.mandalId == mandalId }
    }

    fun getCitiesForDistrict(districtId: String): List<CityTown> {
        return CITIES.filter { it.districtId == districtId }
    }

    fun getAreasForCity(cityId: String): List<LocationArea> {
        return AREAS.filter { it.cityTownId == cityId }
    }

    fun getAreasForMandal(mandalId: String): List<LocationArea> {
        return AREAS.filter { it.mandalId == mandalId }
    }

    fun findCountry(countryId: String): Country? = COUNTRIES.firstOrNull { it.id == countryId }
    fun findState(stateId: String): State? = STATES.firstOrNull { it.id == stateId }
    fun findDistrict(districtId: String): District? = DISTRICTS.firstOrNull { it.id == districtId }
    fun findMandal(mandalId: String): Mandal? = MANDALS.firstOrNull { it.id == mandalId }
    fun findCity(cityId: String): CityTown? = CITIES.firstOrNull { it.id == cityId }
    fun findArea(areaId: String?): LocationArea? = if (areaId != null) AREAS.firstOrNull { it.id == areaId } else null

    fun buildHierarchy(
        countryId: String = "IN",
        stateId: String,
        districtId: String,
        mandalId: String = "",
        cityTownId: String = "",
        areaId: String? = null
    ): LocationHierarchy {
        val cntry = findCountry(countryId) ?: (COUNTRIES.firstOrNull { it.id == countryId } ?: COUNTRY_INDIA)
        val st = findState(stateId) ?: (STATES.firstOrNull { it.countryId == cntry.id } ?: STATES.first())
        val dt = findDistrict(districtId) ?: (DISTRICTS.firstOrNull { it.stateId == st.id } ?: DISTRICTS.first())
        val md = findMandal(mandalId) ?: MANDALS.firstOrNull { it.districtId == dt.id }
        val ct = findCity(cityTownId) ?: CITIES.firstOrNull { it.districtId == dt.id } ?: CITIES.first()
        val ar = findArea(areaId)

        return LocationHierarchy(
            countryId = cntry.id,
            stateId = st.id,
            districtId = dt.id,
            mandalId = md?.id ?: "",
            cityTownId = ct.id,
            areaId = ar?.id,
            countryName = cntry.name,
            stateName = st.name,
            districtName = dt.name,
            mandalName = md?.name ?: "",
            cityName = ct.name,
            areaName = ar?.name ?: "",
            postalCode = ar?.postalCode?.ifBlank { ct.postalCode } ?: ct.postalCode,
            latitude = ar?.latitude ?: ct.latitude,
            longitude = ar?.longitude ?: ct.longitude
        )
    }

    fun searchLocations(query: String): List<LocationHierarchy> {
        val q = query.trim().lowercase()
        if (q.isBlank()) return emptyList()

        val matchedAreas = AREAS.filter {
            it.name.lowercase().contains(q) ||
            it.landmark.lowercase().contains(q) ||
            it.postalCode.contains(q)
        }.map { area ->
            val st = findState(area.stateId)
            buildHierarchy(st?.countryId ?: "IN", area.stateId, area.districtId, area.mandalId, area.cityTownId, area.id)
        }

        val matchedCities = CITIES.filter {
            it.name.lowercase().contains(q) || it.postalCode.contains(q)
        }.map { city ->
            val st = findState(city.stateId)
            buildHierarchy(st?.countryId ?: "IN", city.stateId, city.districtId, city.mandalId, city.id, null)
        }

        val matchedMandals = MANDALS.filter {
            it.name.lowercase().contains(q)
        }.map { mandal ->
            val st = findState(mandal.stateId)
            val city = getCitiesForMandal(mandal.id).firstOrNull() ?: CITIES.first { it.districtId == mandal.districtId }
            buildHierarchy(st?.countryId ?: "IN", mandal.stateId, mandal.districtId, mandal.id, city.id, null)
        }

        val matchedDistricts = DISTRICTS.filter {
            it.name.lowercase().contains(q)
        }.map { dist ->
            val st = findState(dist.stateId)
            val mandal = getMandalsForDistrict(dist.id).firstOrNull() ?: MANDALS.first()
            val city = getCitiesForDistrict(dist.id).firstOrNull() ?: CITIES.first()
            buildHierarchy(st?.countryId ?: "IN", dist.stateId, dist.id, mandal.id, city.id, null)
        }

        return (matchedAreas + matchedCities + matchedMandals + matchedDistricts)
            .distinctBy { it.breadcrumbLabel }
            .take(15)
    }

    fun calculateDistanceKm(lat1: Double, lon1: Double, lat2: Double, lon2: Double): Double {
        val r = 6371.0 // Earth radius in km
        val dLat = Math.toRadians(lat2 - lat1)
        val dLon = Math.toRadians(lon2 - lon1)
        val a = sin(dLat / 2) * sin(dLat / 2) +
                cos(Math.toRadians(lat1)) * cos(Math.toRadians(lat2)) *
                sin(dLon / 2) * sin(dLon / 2)
        val c = 2 * atan2(sqrt(a), sqrt(1 - a))
        return (r * c * 10.0).roundToInt() / 10.0
    }

    fun findNearestLocation(lat: Double, lng: Double): LocationHierarchy {
        // Find nearest city or preset
        val nearestArea = AREAS.minByOrNull {
            val dLat = it.latitude - lat
            val dLng = it.longitude - lng
            dLat * dLat + dLng * dLng
        }
        if (nearestArea != null) {
            return buildHierarchy(
                nearestArea.stateId,
                nearestArea.districtId,
                nearestArea.mandalId,
                nearestArea.cityTownId,
                nearestArea.id
            )
        }
        return popularPresets.first()
    }
}

fun calculateDistanceKm(lat1: Double, lon1: Double, lat2: Double, lon2: Double): Double {
    return IndiaLocationMasterData.calculateDistanceKm(lat1, lon1, lat2, lon2)
}
