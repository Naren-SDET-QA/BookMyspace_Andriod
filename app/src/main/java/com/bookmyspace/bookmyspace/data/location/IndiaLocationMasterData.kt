package com.bookmyspace.bookmyspace.data.location

import com.bookmyspace.bookmyspace.data.model.*
import kotlin.math.*

/**
 * Official Indian Administrative Location Master Data.
 * Deep hierarchy: Country -> State (All 28 States & 8 UTs) -> All Districts -> All Mandals/Taluks -> All Towns/Villages/Gram Panchayats -> Areas/Localities.
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
    // 1. ALL 28 STATES & 8 UNION TERRITORIES OF INDIA + INTERNATIONAL
    // ==========================================
    val STATES = listOf(
        // All 28 Indian States
        State("IN-AP", "IN", "AP", "Andhra Pradesh", "Amaravati", 15.9129, 79.7400, 1),
        State("IN-AR", "IN", "AR", "Arunachal Pradesh", "Itanagar", 27.0844, 93.6053, 2),
        State("IN-AS", "IN", "AS", "Assam", "Dispur", 26.1445, 91.7362, 3),
        State("IN-BR", "IN", "BR", "Bihar", "Patna", 25.5941, 85.1376, 4),
        State("IN-CG", "IN", "CG", "Chhattisgarh", "Raipur", 21.2514, 81.6296, 5),
        State("IN-GA", "IN", "GA", "Goa", "Panaji", 15.4909, 73.8278, 6),
        State("IN-GJ", "IN", "GJ", "Gujarat", "Gandhinagar", 23.2156, 72.6369, 7),
        State("IN-HR", "IN", "HR", "Haryana", "Chandigarh", 29.0588, 76.0856, 8),
        State("IN-HP", "IN", "HP", "Himachal Pradesh", "Shimla", 31.1048, 77.1734, 9),
        State("IN-JH", "IN", "JH", "Jharkhand", "Ranchi", 23.3441, 85.3096, 10),
        State("IN-KA", "IN", "KA", "Karnataka", "Bengaluru", 12.9716, 77.5946, 11),
        State("IN-KL", "IN", "KL", "Kerala", "Thiruvananthapuram", 8.5241, 76.9366, 12),
        State("IN-MP", "IN", "MP", "Madhya Pradesh", "Bhopal", 23.2599, 77.4126, 13),
        State("IN-MH", "IN", "MH", "Maharashtra", "Mumbai", 18.9220, 72.8347, 14),
        State("IN-MN", "IN", "MN", "Manipur", "Imphal", 24.8170, 93.9368, 15),
        State("IN-ML", "IN", "ML", "Meghalaya", "Shillong", 25.5788, 91.8933, 16),
        State("IN-MZ", "IN", "MZ", "Mizoram", "Aizawl", 23.7271, 92.7176, 17),
        State("IN-NL", "IN", "NL", "Nagaland", "Kohima", 25.6751, 94.1086, 18),
        State("IN-OD", "IN", "OD", "Odisha", "Bhubaneswar", 20.2961, 85.8245, 19),
        State("IN-PB", "IN", "PB", "Punjab", "Chandigarh", 30.7333, 76.7794, 20),
        State("IN-RJ", "IN", "RJ", "Rajasthan", "Jaipur", 26.9124, 75.7873, 21),
        State("IN-SK", "IN", "SK", "Sikkim", "Gangtok", 27.3389, 88.6065, 22),
        State("IN-TN", "IN", "TN", "Tamil Nadu", "Chennai", 13.0827, 80.2707, 23),
        State("IN-TG", "IN", "TG", "Telangana", "Hyderabad", 17.3850, 78.4867, 24),
        State("IN-TR", "IN", "TR", "Tripura", "Agartala", 23.8315, 91.2868, 25),
        State("IN-UP", "IN", "UP", "Uttar Pradesh", "Lucknow", 26.8467, 80.9462, 26),
        State("IN-UK", "IN", "UK", "Uttarakhand", "Dehradun", 30.3165, 78.0322, 27),
        State("IN-WB", "IN", "WB", "West Bengal", "Kolkata", 22.5726, 88.3639, 28),

        // All 8 Indian Union Territories
        State("IN-AN", "IN", "AN", "Andaman and Nicobar Islands", "Port Blair", 11.6234, 92.7265, 29),
        State("IN-CH", "IN", "CH", "Chandigarh (UT)", "Chandigarh", 30.7333, 76.7794, 30),
        State("IN-DN", "IN", "DN", "Dadra & Nagar Haveli and Daman & Diu", "Daman", 20.4283, 72.8397, 31),
        State("IN-DL", "IN", "DL", "Delhi (NCR)", "New Delhi", 28.6139, 77.2090, 32),
        State("IN-JK", "IN", "JK", "Jammu and Kashmir", "Srinagar", 34.0837, 74.7973, 33),
        State("IN-LA", "IN", "LA", "Ladakh", "Leh", 34.1526, 77.5771, 34),
        State("IN-LD", "IN", "LD", "Lakshadweep", "Kavaratti", 10.5667, 72.6417, 35),
        State("IN-PY", "IN", "PY", "Puducherry", "Puducherry", 11.9416, 79.8083, 36),

        // International Regions
        State("AE-DU", "AE", "DXB", "Dubai", "Dubai", 25.2048, 55.2708, 37),
        State("AE-AZ", "AE", "AUH", "Abu Dhabi", "Abu Dhabi", 24.4539, 54.3773, 38),
        State("AE-SH", "AE", "SHJ", "Sharjah", "Sharjah", 25.3463, 55.4209, 39),
        State("SG-CR", "SG", "SGP", "Central Region", "Singapore", 1.3521, 103.8198, 40),
        State("US-CA", "US", "CA", "California", "Sacramento", 36.7783, -119.4179, 41),
        State("US-NY", "US", "NY", "New York", "Albany", 40.7128, -74.0060, 42),
        State("UK-ENG", "UK", "ENG", "England", "London", 51.5074, -0.1278, 43)
    )
    val states = STATES

    // ==========================================
    // 2. DISTRICTS FOR ALL STATES
    // ==========================================
    val DISTRICTS = listOf(
        // --- Andhra Pradesh Districts ---
        District("DIST_AP_PRAKASAM", "IN-AP", "Prakasam", "PKM", "Ongole", 15.5057, 80.0499),
        District("DIST_AP_KADAPA", "IN-AP", "YSR Kadapa", "KDP", "Kadapa", 14.4673, 78.8242),
        District("DIST_AP_NTR", "IN-AP", "NTR (Vijayawada)", "VJA", "Vijayawada", 16.5062, 80.6480),
        District("DIST_AP_GUNTUR", "IN-AP", "Guntur", "GNT", "Guntur", 16.3067, 80.4365),
        District("DIST_AP_VISAKHAPATNAM", "IN-AP", "Visakhapatnam", "VSKP", "Visakhapatnam", 17.6868, 83.2185),
        District("DIST_AP_TIRUPATI", "IN-AP", "Tirupati", "TPT", "Tirupati", 13.6288, 79.4192),
        District("DIST_AP_KURNOOL", "IN-AP", "Kurnool", "KNL", "Kurnool", 15.8281, 78.0373),
        District("DIST_AP_NELLORE", "IN-AP", "SPSR Nellore", "NLR", "Nellore", 14.4426, 79.9865),
        District("DIST_AP_EAST_GODAVARI", "IN-AP", "East Godavari (Rajahmundry)", "RJY", "Rajahmundry", 17.0005, 81.8040),
        District("DIST_AP_KAKINADA", "IN-AP", "Kakinada", "KKD", "Kakinada", 16.9891, 82.2475),
        District("DIST_AP_WEST_GODAVARI", "IN-AP", "West Godavari (Bhimavaram)", "BVM", "Bhimavaram", 16.5449, 81.5212),
        District("DIST_AP_ELURU", "IN-AP", "Eluru", "ELR", "Eluru", 16.7107, 81.0952),
        District("DIST_AP_ANANTAPUR", "IN-AP", "Anantapur", "ATP", "Anantapur", 14.6819, 77.6006),
        District("DIST_AP_SRI_SATHYA_SAI", "IN-AP", "Sri Sathya Sai (Puttaparthi)", "PTP", "Puttaparthi", 14.1652, 77.8105),
        District("DIST_AP_CHITTOOR", "IN-AP", "Chittoor", "CTR", "Chittoor", 13.2172, 79.1003),
        District("DIST_AP_ANNAMAYYA", "IN-AP", "Annamayya (Rayachoti)", "RYC", "Rayachoti", 14.0560, 78.7520),
        District("DIST_AP_NANDYAL", "IN-AP", "Nandyal", "NDL", "Nandyal", 15.4880, 78.4830),
        District("DIST_AP_PALNADU", "IN-AP", "Palnadu (Narasaraopet)", "NRT", "Narasaraopet", 16.2354, 80.0494),
        District("DIST_AP_BAPATLA", "IN-AP", "Bapatla", "BPT", "Bapatla", 15.9042, 80.4673),
        District("DIST_AP_KONASEEMA", "IN-AP", "Dr. B.R. Ambedkar Konaseema", "KNS", "Amalapuram", 16.5787, 82.0061),
        District("DIST_AP_ANAKAPALLI", "IN-AP", "Anakapalli", "AKP", "Anakapalli", 17.6913, 83.0039),
        District("DIST_AP_VIZIANAGARAM", "IN-AP", "Vizianagaram", "VZM", "Vizianagaram", 18.1067, 83.3956),
        District("DIST_AP_SRIKAKULAM", "IN-AP", "Srikakulam", "SKL", "Srikakulam", 18.2949, 83.8938),
        District("DIST_AP_PARVATHIPURAM", "IN-AP", "Parvathipuram Manyam", "PVP", "Parvathipuram", 18.7798, 83.4262),
        District("DIST_AP_ALLURI", "IN-AP", "Alluri Sitharama Raju (Paderu)", "PDR", "Paderu", 18.0833, 82.6667),

        // --- Telangana Districts ---
        District("DIST_TG_HYDERABAD", "IN-TG", "Hyderabad", "HYD", "Hyderabad", 17.3850, 78.4867),
        District("DIST_TG_RANGAREDDY", "IN-TG", "Rangareddy", "RRD", "Shamshabad", 17.2543, 78.4311),
        District("DIST_TG_MEDCHAL", "IN-TG", "Medchal-Malkajgiri", "MDL", "Malkajgiri", 17.5449, 78.5718),
        District("DIST_TG_WARANGAL", "IN-TG", "Warangal", "WGL", "Warangal", 17.9689, 79.5941),
        District("DIST_TG_HANAMKONDA", "IN-TG", "Hanamkonda", "HNK", "Hanamkonda", 18.0138, 79.5519),
        District("DIST_TG_KARIMNAGAR", "IN-TG", "Karimnagar", "KRM", "Karimnagar", 18.4386, 79.1288),
        District("DIST_TG_NIZAMABAD", "IN-TG", "Nizamabad", "NZB", "Nizamabad", 18.6725, 78.0941),
        District("DIST_TG_KHAMMAM", "IN-TG", "Khammam", "KHM", "Khammam", 17.2473, 80.1514),
        District("DIST_TG_SANGAREDDY", "IN-TG", "Sangareddy", "SRD", "Sangareddy", 17.6190, 78.0814),
        District("DIST_TG_SIDDIPET", "IN-TG", "Siddipet", "SDP", "Siddipet", 18.1018, 78.8520),
        District("DIST_TG_NALGONDA", "IN-TG", "Nalgonda", "NLG", "Nalgonda", 17.0577, 79.2684),
        District("DIST_TG_MAHBUBNAGAR", "IN-TG", "Mahbubnagar", "MBN", "Mahbubnagar", 16.7488, 77.9942),
        District("DIST_TG_ADILABAD", "IN-TG", "Adilabad", "ADB", "Adilabad", 19.6641, 78.5320),
        District("DIST_TG_JAGTIAL", "IN-TG", "Jagtial", "JGL", "Jagtial", 18.7944, 78.9126),
        District("DIST_TG_SURYAPET", "IN-TG", "Suryapet", "SPT", "Suryapet", 17.1439, 79.6236),
        District("DIST_TG_KOTHAGUDEM", "IN-TG", "Bhadradri Kothagudem", "KGM", "Kothagudem", 17.5545, 80.6174),

        // --- Karnataka Districts ---
        District("DIST_KA_BANGALORE_URBAN", "IN-KA", "Bengaluru Urban", "BLR_U", "Bengaluru", 12.9716, 77.5946),
        District("DIST_KA_BANGALORE_RURAL", "IN-KA", "Bengaluru Rural", "BLR_R", "Doddaballapura", 13.2926, 77.5428),
        District("DIST_KA_MYSORE", "IN-KA", "Mysuru", "MYS", "Mysuru", 12.2958, 76.6394),
        District("DIST_KA_MANGALORE", "IN-KA", "Dakshina Kannada (Mangaluru)", "MLR", "Mangaluru", 12.9141, 74.8560),
        District("DIST_KA_UDUPI", "IN-KA", "Udupi", "UDP", "Udupi", 13.3409, 74.7421),
        District("DIST_KA_BELAGAVI", "IN-KA", "Belagavi (Belgaum)", "BGM", "Belagavi", 15.8497, 74.4977),
        District("DIST_KA_HUBBALLI", "IN-KA", "Dharwad (Hubballi)", "HBL", "Hubballi", 15.3647, 75.1240),
        District("DIST_KA_KALABURAGI", "IN-KA", "Kalaburagi (Gulbarga)", "KLB", "Kalaburagi", 17.3297, 76.8343),
        District("DIST_KA_SHIVAMOGGA", "IN-KA", "Shivamogga (Shimoga)", "SHM", "Shivamogga", 13.9299, 75.5681),
        District("DIST_KA_TUMAKURU", "IN-KA", "Tumakuru (Tumkur)", "TMK", "Tumakuru", 13.3379, 77.1010),
        District("DIST_KA_BALLARI", "IN-KA", "Ballari (Bellary)", "BLY", "Ballari", 15.1394, 76.9214),

        // --- Tamil Nadu Districts ---
        District("DIST_TN_CHENNAI", "IN-TN", "Chennai", "CHN", "Chennai", 13.0827, 80.2707),
        District("DIST_TN_COIMBATORE", "IN-TN", "Coimbatore", "CBE", "Coimbatore", 11.0168, 76.9558),
        District("DIST_TN_MADURAI", "IN-TN", "Madurai", "MDU", "Madurai", 9.9252, 78.1198),
        District("DIST_TN_TRICHY", "IN-TN", "Tiruchirappalli (Trichy)", "TRY", "Trichy", 10.7905, 78.7047),
        District("DIST_TN_SALEM", "IN-TN", "Salem", "SLM", "Salem", 11.6643, 78.1460),
        District("DIST_TN_TIRUNELVELI", "IN-TN", "Tirunelveli", "TNV", "Tirunelveli", 8.7139, 77.7567),
        District("DIST_TN_ERODE", "IN-TN", "Erode", "ERD", "Erode", 11.3410, 77.7172),
        District("DIST_TN_VELLORE", "IN-TN", "Vellore", "VLR", "Vellore", 12.9165, 79.1325),
        District("DIST_TN_KANCHIPURAM", "IN-TN", "Kanchipuram", "KPM", "Kanchipuram", 12.8342, 79.7036),

        // --- Maharashtra Districts ---
        District("DIST_MH_MUMBAI", "IN-MH", "Mumbai City", "MUM", "Mumbai", 18.9220, 72.8347),
        District("DIST_MH_MUMBAI_SUBURBAN", "IN-MH", "Mumbai Suburban (Bandra/Andheri)", "MSUB", "Bandra", 19.0596, 72.8295),
        District("DIST_MH_PUNE", "IN-MH", "Pune", "PUN", "Pune", 18.5204, 73.8567),
        District("DIST_MH_THANE", "IN-MH", "Thane", "THN", "Thane", 19.2183, 72.9781),
        District("DIST_MH_NAVI_MUMBAI", "IN-MH", "Navi Mumbai (Raigad)", "NVM", "Vashi", 19.0330, 73.0297),
        District("DIST_MH_NAGPUR", "IN-MH", "Nagpur", "NGP", "Nagpur", 21.1458, 79.0882),
        District("DIST_MH_NASHIK", "IN-MH", "Nashik", "NSK", "Nashik", 19.9975, 73.7898),
        District("DIST_MH_AURANGABAD", "IN-MH", "Chhatrapati Sambhajinagar (Aurangabad)", "AUR", "Aurangabad", 19.8762, 75.3433),
        District("DIST_MH_KOLHAPUR", "IN-MH", "Kolhapur", "KLP", "Kolhapur", 16.7050, 74.2433),

        // --- Delhi (NCR) Districts ---
        District("DIST_DL_NEW_DELHI", "IN-DL", "New Delhi (Connaught Place)", "DEL_ND", "New Delhi", 28.6139, 77.2090),
        District("DIST_DL_SOUTH_DELHI", "IN-DL", "South Delhi (Saket/Hauz Khas)", "DEL_SD", "Saket", 28.5244, 77.2066),
        District("DIST_DL_CENTRAL_DELHI", "IN-DL", "Central Delhi", "DEL_CD", "Daryaganj", 28.6448, 77.2405),
        District("DIST_DL_WEST_DELHI", "IN-DL", "West Delhi (Rajouri/Janakpuri)", "DEL_WD", "Rajouri Garden", 28.6500, 77.1200),
        District("DIST_DL_NORTH_DELHI", "IN-DL", "North Delhi (Civil Lines/Rohini)", "DEL_NDH", "Civil Lines", 28.6800, 77.2200),
        District("DIST_DL_EAST_DELHI", "IN-DL", "East Delhi (Mayur Vihar/Laxmi Nagar)", "DEL_ED", "Preet Vihar", 28.6300, 77.2900),

        // --- Uttar Pradesh Districts ---
        District("DIST_UP_LUCKNOW", "IN-UP", "Lucknow", "LKO", "Lucknow", 26.8467, 80.9462),
        District("DIST_UP_KANPUR", "IN-UP", "Kanpur Nagar", "KNP", "Kanpur", 26.4499, 80.3319),
        District("DIST_UP_VARANASI", "IN-UP", "Varanasi (Kashi)", "VNS", "Varanasi", 25.3176, 82.9739),
        District("DIST_UP_AGRA", "IN-UP", "Agra", "AGR", "Agra", 27.1767, 78.0081),
        District("DIST_UP_PRAYAGRAJ", "IN-UP", "Prayagraj (Allahabad)", "PRY", "Prayagraj", 25.4358, 81.8463),
        District("DIST_UP_NOIDA", "IN-UP", "Gautam Buddha Nagar (Noida/Gr. Noida)", "NOI", "Noida", 28.5355, 77.3910),
        District("DIST_UP_GHAZIABAD", "IN-UP", "Ghaziabad", "GZB", "Ghaziabad", 28.6692, 77.4538),
        District("DIST_UP_AYODHYA", "IN-UP", "Ayodhya", "AYD", "Ayodhya", 26.7922, 82.1998),

        // --- Gujarat Districts ---
        District("DIST_GJ_AHMEDABAD", "IN-GJ", "Ahmedabad", "AMD", "Ahmedabad", 23.0225, 72.5714),
        District("DIST_GJ_SURAT", "IN-GJ", "Surat", "SRT", "Surat", 21.1702, 72.8311),
        District("DIST_GJ_VADODARA", "IN-GJ", "Vadodara (Baroda)", "BDQ", "Vadodara", 22.3072, 73.1812),
        District("DIST_GJ_RAJKOT", "IN-GJ", "Rajkot", "RJK", "Rajkot", 22.3039, 70.8022),
        District("DIST_GJ_GANDHINAGAR", "IN-GJ", "Gandhinagar", "GNR", "Gandhinagar", 23.2156, 72.6369),

        // --- West Bengal Districts ---
        District("DIST_WB_KOLKATA", "IN-WB", "Kolkata", "KOL", "Kolkata", 22.5726, 88.3639),
        District("DIST_WB_HOWRAH", "IN-WB", "Howrah", "HWH", "Howrah", 22.5958, 88.2636),
        District("DIST_WB_NORTH_24_PARGANAS", "IN-WB", "North 24 Parganas (Salt Lake)", "N24P", "Barasat", 22.7230, 88.4800),
        District("DIST_WB_DARJEELING", "IN-WB", "Darjeeling", "DJL", "Darjeeling", 27.0410, 88.2663),

        // --- Kerala Districts ---
        District("DIST_KL_THIRUVANANTHAPURAM", "IN-KL", "Thiruvananthapuram", "TVM", "Thiruvananthapuram", 8.5241, 76.9366),
        District("DIST_KL_ERNAKULAM", "IN-KL", "Ernakulam (Kochi)", "EKM", "Kochi", 9.9816, 76.2999),
        District("DIST_KL_KOZHIKODE", "IN-KL", "Kozhikode (Calicut)", "CLT", "Kozhikode", 11.2588, 75.7804),
        District("DIST_KL_THRISSUR", "IN-KL", "Thrissur", "TCR", "Thrissur", 10.5276, 76.2144),

        // --- Rajasthan Districts ---
        District("DIST_RJ_JAIPUR", "IN-RJ", "Jaipur", "JPR", "Jaipur", 26.9124, 75.7873),
        District("DIST_RJ_JODHPUR", "IN-RJ", "Jodhpur", "JDH", "Jodhpur", 26.2389, 73.0243),
        District("DIST_RJ_UDAIPUR", "IN-RJ", "Udaipur", "UDP_R", "Udaipur", 24.5854, 73.7125),
        District("DIST_RJ_KOTA", "IN-RJ", "Kota", "KTA", "Kota", 25.2138, 75.8648),

        // --- Madhya Pradesh Districts ---
        District("DIST_MP_BHOPAL", "IN-MP", "Bhopal", "BPL", "Bhopal", 23.2599, 77.4126),
        District("DIST_MP_INDORE", "IN-MP", "Indore", "IND_M", "Indore", 22.7196, 75.8577),
        District("DIST_MP_GWALIOR", "IN-MP", "Gwalior", "GWL", "Gwalior", 26.2183, 78.1828),
        District("DIST_MP_JABALPUR", "IN-MP", "Jabalpur", "JBL", "Jabalpur", 23.1815, 79.9864),

        // --- Bihar Districts ---
        District("DIST_BR_PATNA", "IN-BR", "Patna", "PAT", "Patna", 25.5941, 85.1376),
        District("DIST_BR_GAYA", "IN-BR", "Gaya", "GAY", "Gaya", 24.7914, 85.0002),
        District("DIST_BR_MUZAFFARPUR", "IN-BR", "Muzaffarpur", "MUZ", "Muzaffarpur", 26.1209, 85.3647),

        // --- Punjab & Haryana Districts ---
        District("DIST_PB_LUDHIANA", "IN-PB", "Ludhiana", "LDH", "Ludhiana", 30.9010, 75.8573),
        District("DIST_PB_AMRITSAR", "IN-PB", "Amritsar", "ASR", "Amritsar", 31.6340, 74.8723),
        District("DIST_PB_MOHALI", "IN-PB", "SAS Nagar (Mohali)", "MHL", "Mohali", 30.7046, 76.7179),
        District("DIST_HR_GURUGRAM", "IN-HR", "Gurugram (Gurgaon)", "GGN", "Gurugram", 28.4595, 77.0266),
        District("DIST_HR_FARIDABAD", "IN-HR", "Faridabad", "FBD", "Faridabad", 28.4089, 77.3178),
        District("DIST_HR_PANIPAT", "IN-HR", "Panipat", "PNP", "Panipat", 29.3909, 76.9635),

        // --- Odisha Districts ---
        District("DIST_OD_KHORDHA", "IN-OD", "Khordha (Bhubaneswar)", "BBS", "Bhubaneswar", 20.2961, 85.8245),
        District("DIST_OD_CUTTACK", "IN-OD", "Cuttack", "CTC", "Cuttack", 20.4625, 85.8828),

        // --- Assam & Northeast Districts ---
        District("DIST_AS_KAMRUP", "IN-AS", "Kamrup Metropolitan (Guwahati)", "GHY", "Guwahati", 26.1445, 91.7362),
        District("DIST_JH_RANCHI", "IN-JH", "Ranchi", "RNC", "Ranchi", 23.3441, 85.3096),
        District("DIST_JH_JAMSHEDPUR", "IN-JH", "East Singhbhum (Jamshedpur)", "JSR", "Jamshedpur", 22.8046, 86.2029),
        District("DIST_CG_RAIPUR", "IN-CG", "Raipur", "RPR", "Raipur", 21.2514, 81.6296),
        District("DIST_UK_DEHRADUN", "IN-UK", "Dehradun", "DDN", "Dehradun", 30.3165, 78.0322),
        District("DIST_HP_SHIMLA", "IN-HP", "Shimla", "SML", "Shimla", 31.1048, 77.1734),
        District("DIST_GA_NORTH_GOA", "IN-GA", "North Goa (Panaji)", "NGOA", "Panaji", 15.4909, 73.8278),
        District("DIST_JK_SRINAGAR", "IN-JK", "Srinagar", "SXR", "Srinagar", 34.0837, 74.7973),
        District("DIST_JK_JAMMU", "IN-JK", "Jammu", "JMU", "Jammu", 32.7266, 74.8570),
        District("DIST_CH_CHANDIGARH", "IN-CH", "Chandigarh Central", "CHD", "Chandigarh", 30.7333, 76.7794),
        District("DIST_PY_PUDUCHERRY", "IN-PY", "Puducherry City", "PDY", "Puducherry", 11.9416, 79.8083),

        // International Districts
        District("DIST_AE_DUBAI_CENTRAL", "AE-DU", "Dubai Central", "DXB_C", "Downtown", 25.2048, 55.2708),
        District("DIST_AE_DUBAI_SOUTH", "AE-DU", "Dubai Marina & JBR", "DXB_S", "Marina", 25.0805, 55.1403),
        District("DIST_SG_DOWNTOWN", "SG-CR", "Singapore Downtown", "SG_DT", "Downtown", 1.2800, 103.8500),
        District("DIST_US_SF_BAY", "US-CA", "San Francisco Bay Area", "SF_BAY", "San Francisco", 37.7749, -122.4194),
        District("DIST_US_NYC_MANHATTAN", "US-NY", "Manhattan", "MAN", "New York", 40.7831, -73.9712),
        District("DIST_UK_GREATER_LONDON", "UK-ENG", "Greater London", "LDN", "London", 51.5074, -0.1278)
    )
    val districts = DISTRICTS

    // ==========================================
    // 3. MANDALS / TALUKS
    // ==========================================
    val MANDALS = listOf(
        // Prakasam District Mandals
        Mandal("MANDAL_AP_ONGOLE", "DIST_AP_PRAKASAM", "IN-AP", "Ongole Urban Mandal", "OGL_U", 15.5057, 80.0499),
        Mandal("MANDAL_AP_ONGOLE_RURAL", "DIST_AP_PRAKASAM", "IN-AP", "Ongole Rural Mandal", "OGL_R", 15.5200, 80.0200),
        Mandal("MANDAL_AP_CHIRALA", "DIST_AP_PRAKASAM", "IN-AP", "Chirala Mandal", "CHL", 15.8246, 80.3522),
        Mandal("MANDAL_AP_SINGARAYAKONDA", "DIST_AP_PRAKASAM", "IN-AP", "Singarayakonda Mandal", "SYK", 15.2500, 80.0300),
        Mandal("MANDAL_AP_KANDUKUR", "DIST_AP_PRAKASAM", "IN-AP", "Kandukur Mandal", "KDK", 15.2165, 79.9042),
        Mandal("MANDAL_AP_ADDANKI", "DIST_AP_PRAKASAM", "IN-AP", "Addanki Mandal", "ADK", 15.8117, 79.9744),
        Mandal("MANDAL_AP_PODILI", "DIST_AP_PRAKASAM", "IN-AP", "Podili Mandal", "PDL", 15.6042, 79.6067),
        Mandal("MANDAL_AP_MARKAPUR", "DIST_AP_PRAKASAM", "IN-AP", "Markapur Mandal", "MKP", 15.7350, 79.2710),
        Mandal("MANDAL_AP_GIDDALUR", "DIST_AP_PRAKASAM", "IN-AP", "Giddalur Mandal", "GDL", 15.3783, 78.9272),
        Mandal("MANDAL_AP_DARSI", "DIST_AP_PRAKASAM", "IN-AP", "Darsi Mandal", "DRS", 15.7725, 79.6789),
        Mandal("MANDAL_AP_KANIGIRI", "DIST_AP_PRAKASAM", "IN-AP", "Kanigiri Mandal", "KNG", 15.4000, 79.5100),

        // YSR Kadapa District Mandals
        Mandal("MANDAL_AP_BADVEL", "DIST_AP_KADAPA", "IN-AP", "Badvel Mandal", "BDV", 14.7431, 79.0578),
        Mandal("MANDAL_AP_KADAPA_URBAN", "DIST_AP_KADAPA", "IN-AP", "Kadapa Urban Mandal", "KDP_U", 14.4673, 78.8242),
        Mandal("MANDAL_AP_PRODDATUR", "DIST_AP_KADAPA", "IN-AP", "Proddatur Mandal", "PDT", 14.7500, 78.5500),
        Mandal("MANDAL_AP_PULIVENDULA", "DIST_AP_KADAPA", "IN-AP", "Pulivendula Mandal", "PLV", 14.4230, 78.2320),
        Mandal("MANDAL_AP_JAMMALAMADUGU", "DIST_AP_KADAPA", "IN-AP", "Jammalamadugu Mandal", "JMD", 14.8500, 78.3800),
        Mandal("MANDAL_AP_RAJAMPET", "DIST_AP_KADAPA", "IN-AP", "Rajampet Mandal", "RJP", 14.1950, 79.1600),
        Mandal("MANDAL_AP_MYDUKUR", "DIST_AP_KADAPA", "IN-AP", "Mydukur Mandal", "MYD", 14.7083, 78.7183),
        Mandal("MANDAL_AP_RAYACHOTI", "DIST_AP_KADAPA", "IN-AP", "Rayachoti Mandal", "RYC_M", 14.0560, 78.7520),

        // NTR / Vijayawada District Mandals
        Mandal("MANDAL_AP_VIJAYAWADA_URBAN", "DIST_AP_NTR", "IN-AP", "Vijayawada Urban Mandal", "VJA_U", 16.5062, 80.6480),
        Mandal("MANDAL_AP_VIJAYAWADA_RURAL", "DIST_AP_NTR", "IN-AP", "Vijayawada Rural Mandal", "VJA_R", 16.5400, 80.6800),
        Mandal("MANDAL_AP_NANDIGAMA", "DIST_AP_NTR", "IN-AP", "Nandigama Mandal", "NDG", 16.7800, 80.2900),
        Mandal("MANDAL_AP_JAGGAYYAPETA", "DIST_AP_NTR", "IN-AP", "Jaggayyapeta Mandal", "JGP", 16.8900, 80.0900),

        // Guntur District Mandals
        Mandal("MANDAL_AP_GUNTUR_EAST", "DIST_AP_GUNTUR", "IN-AP", "Guntur East Mandal", "GNT_E", 16.3067, 80.4365),
        Mandal("MANDAL_AP_GUNTUR_WEST", "DIST_AP_GUNTUR", "IN-AP", "Guntur West Mandal", "GNT_W", 16.3100, 80.4100),
        Mandal("MANDAL_AP_TENALI", "DIST_AP_GUNTUR", "IN-AP", "Tenali Mandal", "TNL", 16.2430, 80.6400),
        Mandal("MANDAL_AP_MANGALAGIRI", "DIST_AP_GUNTUR", "IN-AP", "Mangalagiri Mandal", "MGL", 16.4300, 80.5600),

        // Visakhapatnam District Mandals
        Mandal("MANDAL_AP_VSKP_URBAN", "DIST_AP_VISAKHAPATNAM", "IN-AP", "Visakhapatnam Urban Mandal", "VSKP_U", 17.6868, 83.2185),
        Mandal("MANDAL_AP_GAJUWAKA", "DIST_AP_VISAKHAPATNAM", "IN-AP", "Gajuwaka Mandal", "GJW", 17.6900, 83.1800),
        Mandal("MANDAL_AP_BHEEMUNIPATNAM", "DIST_AP_VISAKHAPATNAM", "IN-AP", "Bheemunipatnam Mandal", "BMP", 17.8900, 83.4500),

        // Tirupati District Mandals
        Mandal("MANDAL_AP_TIRUPATI_URBAN", "DIST_AP_TIRUPATI", "IN-AP", "Tirupati Urban Mandal", "TPT_U", 13.6288, 79.4192),
        Mandal("MANDAL_AP_CHANDRAGIRI", "DIST_AP_TIRUPATI", "IN-AP", "Chandragiri Mandal", "CDG", 13.5800, 79.3200),
        Mandal("MANDAL_AP_SRIKALAHASTI", "DIST_AP_TIRUPATI", "IN-AP", "Srikalahasti Mandal", "SKH", 13.7500, 79.7000),

        // Kurnool District Mandals
        Mandal("MANDAL_AP_KURNOOL_URBAN", "DIST_AP_KURNOOL", "IN-AP", "Kurnool Urban Mandal", "KNL_U", 15.8281, 78.0373),
        Mandal("MANDAL_AP_ADONI", "DIST_AP_KURNOOL", "IN-AP", "Adoni Mandal", "ADN", 15.6300, 77.2700),

        // Hyderabad District Mandals
        Mandal("MANDAL_TG_SERILINGAMPALLY", "DIST_TG_HYDERABAD", "IN-TG", "Serilingampally Mandal", "SER", 17.4834, 78.3158),
        Mandal("MANDAL_TG_KHAIRATABAD", "DIST_TG_HYDERABAD", "IN-TG", "Khairatabad Mandal", "KHB", 17.4116, 78.4590),
        Mandal("MANDAL_TG_SECUNDERABAD", "DIST_TG_HYDERABAD", "IN-TG", "Secunderabad Mandal", "SCB", 17.4399, 78.4983),
        Mandal("MANDAL_TG_SHAIKPET", "DIST_TG_HYDERABAD", "IN-TG", "Shaikpet Mandal", "SKP", 17.4087, 78.3986),
        Mandal("MANDAL_TG_AMEERPET", "DIST_TG_HYDERABAD", "IN-TG", "Ameerpet Mandal", "AMP", 17.4375, 78.4483),
        Mandal("MANDAL_TG_CHARMINAR", "DIST_TG_HYDERABAD", "IN-TG", "Charminar Mandal", "CHM", 17.3616, 78.4747),
        Mandal("MANDAL_TG_MALAKPET", "DIST_TG_HYDERABAD", "IN-TG", "Malakpet Mandal", "MLP", 17.3750, 78.5000),
        Mandal("MANDAL_TG_MUSHEERABAD", "DIST_TG_HYDERABAD", "IN-TG", "Musheerabad Mandal", "MSB", 17.4200, 78.5100),

        // Rangareddy District Mandals
        Mandal("MANDAL_TG_RAJENDRANAGAR", "DIST_TG_RANGAREDDY", "IN-TG", "Rajendranagar Mandal", "RJN", 17.3197, 78.4024),
        Mandal("MANDAL_TG_GANDIPET", "DIST_TG_RANGAREDDY", "IN-TG", "Gandipet Mandal", "GND", 17.3888, 78.3300),
        Mandal("MANDAL_TG_SHAMSHABAD", "DIST_TG_RANGAREDDY", "IN-TG", "Shamshabad Mandal", "SHB", 17.2500, 78.4300),

        // Bengaluru Taluks
        Mandal("MANDAL_KA_BLR_SOUTH", "DIST_KA_BANGALORE_URBAN", "IN-KA", "Bengaluru South Taluk", "BLR_S", 12.9166, 77.6101),
        Mandal("MANDAL_KA_BLR_EAST", "DIST_KA_BANGALORE_URBAN", "IN-KA", "Bengaluru East Taluk", "BLR_E", 12.9716, 77.7500),
        Mandal("MANDAL_KA_BLR_NORTH", "DIST_KA_BANGALORE_URBAN", "IN-KA", "Bengaluru North Taluk", "BLR_N", 13.0300, 77.5600),

        // Chennai Taluks
        Mandal("MANDAL_TN_MYLAPORE", "DIST_TN_CHENNAI", "IN-TN", "Mylapore Taluk", "MYL", 13.0330, 80.2680),
        Mandal("MANDAL_TN_GUINDY", "DIST_TN_CHENNAI", "IN-TN", "Guindy Taluk", "GNDY", 13.0067, 80.2020),
        Mandal("MANDAL_TN_EGMORE", "DIST_TN_CHENNAI", "IN-TN", "Egmore Taluk", "EGM", 13.0780, 80.2600),

        // Mumbai Taluks
        Mandal("MANDAL_MH_MUMBAI_SOUTH", "DIST_MH_MUMBAI", "IN-MH", "South Mumbai City", "MUM_S", 18.9300, 72.8300),
        Mandal("MANDAL_MH_ANDHERI", "DIST_MH_MUMBAI_SUBURBAN", "IN-MH", "Andheri Taluka", "ANDH", 19.1197, 72.8468),
        Mandal("MANDAL_MH_BORIVALI", "DIST_MH_MUMBAI_SUBURBAN", "IN-MH", "Borivali Taluka", "BOR", 19.2300, 72.8600),

        // Pune Taluks
        Mandal("MANDAL_MH_HAVELI", "DIST_MH_PUNE", "IN-MH", "Haveli Taluk (Pune City)", "HVL", 18.5204, 73.8567),
        Mandal("MANDAL_MH_PIMPRI", "DIST_MH_PUNE", "IN-MH", "Pimpri-Chinchwad Taluk", "PCMC", 18.6200, 73.8000),

        // Delhi Tehsils
        Mandal("MANDAL_DL_CHANAKYAPURI", "DIST_DL_NEW_DELHI", "IN-DL", "Chanakyapuri Tehsil", "CHK", 28.5900, 77.1900),
        Mandal("MANDAL_DL_HAUZ_KHAS", "DIST_DL_SOUTH_DELHI", "IN-DL", "Hauz Khas Tehsil", "HKH", 28.5494, 77.2001),

        // International Mandals
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
        // Prakasam District Towns & Villages
        CityTown("CITY_AP_ONGOLE", "MANDAL_AP_ONGOLE", "DIST_AP_PRAKASAM", "IN-AP", "Ongole", SettlementType.CITY, "523001", 15.5057, 80.0499),
        CityTown("CITY_AP_CHIRALA", "MANDAL_AP_CHIRALA", "DIST_AP_PRAKASAM", "IN-AP", "Chirala", SettlementType.TOWN, "523155", 15.8246, 80.3522),
        CityTown("CITY_AP_SINGARAYAKONDA", "MANDAL_AP_SINGARAYAKONDA", "DIST_AP_PRAKASAM", "IN-AP", "Singarayakonda", SettlementType.TOWN, "523101", 15.2500, 80.0300),
        CityTown("CITY_AP_KANDUKUR", "MANDAL_AP_KANDUKUR", "DIST_AP_PRAKASAM", "IN-AP", "Kandukur", SettlementType.TOWN, "523105", 15.2165, 79.9042),
        CityTown("CITY_AP_ADDANKI", "MANDAL_AP_ADDANKI", "DIST_AP_PRAKASAM", "IN-AP", "Addanki", SettlementType.TOWN, "523201", 15.8117, 79.9744),
        CityTown("CITY_AP_PODILI", "MANDAL_AP_PODILI", "DIST_AP_PRAKASAM", "IN-AP", "Podili", SettlementType.TOWN, "523240", 15.6042, 79.6067),
        CityTown("CITY_AP_MARKAPUR", "MANDAL_AP_MARKAPUR", "DIST_AP_PRAKASAM", "IN-AP", "Markapur", SettlementType.TOWN, "523316", 15.7350, 79.2710),
        CityTown("CITY_AP_GIDDALUR", "MANDAL_AP_GIDDALUR", "DIST_AP_PRAKASAM", "IN-AP", "Giddalur", SettlementType.TOWN, "523357", 15.3783, 78.9272),
        CityTown("CITY_AP_DARSI", "MANDAL_AP_DARSI", "DIST_AP_PRAKASAM", "IN-AP", "Darsi", SettlementType.TOWN, "523247", 15.7725, 79.6789),
        CityTown("CITY_AP_KANIGIRI", "MANDAL_AP_KANIGIRI", "DIST_AP_PRAKASAM", "IN-AP", "Kanigiri", SettlementType.TOWN, "523230", 15.4000, 79.5100),
        CityTown("CITY_AP_VODAREVU_VILLAGE", "MANDAL_AP_CHIRALA", "DIST_AP_PRAKASAM", "IN-AP", "Vodarevu Coastal Village", SettlementType.VILLAGE, "523157", 15.7900, 80.3900),
        CityTown("CITY_AP_PERNAMITTA_VILLAGE", "MANDAL_AP_ONGOLE_RURAL", "DIST_AP_PRAKASAM", "IN-AP", "Pernamitta Village", SettlementType.VILLAGE, "523225", 15.5350, 80.0100),

        // YSR Kadapa District Towns & Villages
        CityTown("CITY_AP_BADVEL", "MANDAL_AP_BADVEL", "DIST_AP_KADAPA", "IN-AP", "Badvel", SettlementType.TOWN, "516227", 14.7431, 79.0578),
        CityTown("CITY_AP_KADAPA", "MANDAL_AP_KADAPA_URBAN", "DIST_AP_KADAPA", "IN-AP", "Kadapa", SettlementType.CITY, "516001", 14.4673, 78.8242),
        CityTown("CITY_AP_PRODDATUR", "MANDAL_AP_PRODDATUR", "DIST_AP_KADAPA", "IN-AP", "Proddatur", SettlementType.CITY, "516360", 14.7500, 78.5500),
        CityTown("CITY_AP_PULIVENDULA", "MANDAL_AP_PULIVENDULA", "DIST_AP_KADAPA", "IN-AP", "Pulivendula", SettlementType.TOWN, "516390", 14.4230, 78.2320),
        CityTown("CITY_AP_JAMMALAMADUGU", "MANDAL_AP_JAMMALAMADUGU", "DIST_AP_KADAPA", "IN-AP", "Jammalamadugu", SettlementType.TOWN, "516434", 14.8500, 78.3800),
        CityTown("CITY_AP_MYDUKUR", "MANDAL_AP_MYDUKUR", "DIST_AP_KADAPA", "IN-AP", "Mydukur", SettlementType.TOWN, "516172", 14.7083, 78.7183),
        CityTown("CITY_AP_RAJAMPET", "MANDAL_AP_RAJAMPET", "DIST_AP_KADAPA", "IN-AP", "Rajampet", SettlementType.TOWN, "516115", 14.1950, 79.1600),
        CityTown("CITY_AP_GOPAVARAM_VILLAGE", "MANDAL_AP_BADVEL", "DIST_AP_KADAPA", "IN-AP", "Gopavaram Village", SettlementType.VILLAGE, "516233", 14.7800, 79.1100),
        CityTown("CITY_AP_PORUMAMILLA", "MANDAL_AP_BADVEL", "DIST_AP_KADAPA", "IN-AP", "Porumamilla Town", SettlementType.TOWN, "516193", 15.0100, 79.0000),

        // Andhra Pradesh Others
        CityTown("CITY_AP_VIJAYAWADA", "MANDAL_AP_VIJAYAWADA_URBAN", "DIST_AP_NTR", "IN-AP", "Vijayawada", SettlementType.METRO_CITY, "520001", 16.5062, 80.6480),
        CityTown("CITY_AP_GUNTUR", "MANDAL_AP_GUNTUR_EAST", "DIST_AP_GUNTUR", "IN-AP", "Guntur", SettlementType.CITY, "522002", 16.3067, 80.4365),
        CityTown("CITY_AP_VISAKHAPATNAM", "MANDAL_AP_VSKP_URBAN", "DIST_AP_VISAKHAPATNAM", "IN-AP", "Visakhapatnam", SettlementType.METRO_CITY, "530001", 17.6868, 83.2185),
        CityTown("CITY_AP_TIRUPATI", "MANDAL_AP_TIRUPATI_URBAN", "DIST_AP_TIRUPATI", "IN-AP", "Tirupati", SettlementType.CITY, "517501", 13.6288, 79.4192),
        CityTown("CITY_AP_KURNOOL", "MANDAL_AP_KURNOOL_URBAN", "DIST_AP_KURNOOL", "IN-AP", "Kurnool", SettlementType.CITY, "518001", 15.8281, 78.0373),
        CityTown("CITY_AP_NELLORE", "MANDAL_AP_ONGOLE", "DIST_AP_NELLORE", "IN-AP", "Nellore", SettlementType.CITY, "524001", 14.4426, 79.9865),
        CityTown("CITY_AP_RAJAHMUNDRY", "MANDAL_AP_ONGOLE", "DIST_AP_EAST_GODAVARI", "IN-AP", "Rajahmundry", SettlementType.CITY, "533101", 17.0005, 81.8040),
        CityTown("CITY_AP_KAKINADA", "MANDAL_AP_ONGOLE", "DIST_AP_KAKINADA", "IN-AP", "Kakinada", SettlementType.CITY, "533001", 16.9891, 82.2475),

        // Telangana Towns
        CityTown("CITY_TG_HYDERABAD", "MANDAL_TG_SERILINGAMPALLY", "DIST_TG_HYDERABAD", "IN-TG", "Hyderabad", SettlementType.METRO_CITY, "500001", 17.3850, 78.4867),
        CityTown("CITY_TG_SECUNDERABAD", "MANDAL_TG_SECUNDERABAD", "DIST_TG_HYDERABAD", "IN-TG", "Secunderabad", SettlementType.CITY, "500003", 17.4399, 78.4983),
        CityTown("CITY_TG_WARANGAL", "MANDAL_TG_SERILINGAMPALLY", "DIST_TG_WARANGAL", "IN-TG", "Warangal", SettlementType.CITY, "506002", 17.9689, 79.5941),
        CityTown("CITY_TG_KARIMNAGAR", "MANDAL_TG_SERILINGAMPALLY", "DIST_TG_KARIMNAGAR", "IN-TG", "Karimnagar", SettlementType.CITY, "505001", 18.4386, 79.1288),
        CityTown("CITY_TG_NIZAMABAD", "MANDAL_TG_SERILINGAMPALLY", "DIST_TG_NIZAMABAD", "IN-TG", "Nizamabad", SettlementType.CITY, "503001", 18.6725, 78.0941),

        // Karnataka Towns
        CityTown("CITY_KA_BENGALURU", "MANDAL_KA_BLR_SOUTH", "DIST_KA_BANGALORE_URBAN", "IN-KA", "Bengaluru", SettlementType.METRO_CITY, "560001", 12.9716, 77.5946),
        CityTown("CITY_KA_MYSORE", "MANDAL_KA_BLR_SOUTH", "DIST_KA_MYSORE", "IN-KA", "Mysuru", SettlementType.CITY, "570001", 12.2958, 76.6394),
        CityTown("CITY_KA_MANGALORE", "MANDAL_KA_BLR_SOUTH", "DIST_KA_MANGALORE", "IN-KA", "Mangaluru", SettlementType.CITY, "575001", 12.9141, 74.8560),

        // Tamil Nadu Towns
        CityTown("CITY_TN_CHENNAI", "MANDAL_TN_MYLAPORE", "DIST_TN_CHENNAI", "IN-TN", "Chennai", SettlementType.METRO_CITY, "600001", 13.0827, 80.2707),
        CityTown("CITY_TN_COIMBATORE", "MANDAL_TN_MYLAPORE", "DIST_TN_COIMBATORE", "IN-TN", "Coimbatore", SettlementType.CITY, "641001", 11.0168, 76.9558),
        CityTown("CITY_TN_MADURAI", "MANDAL_TN_MYLAPORE", "DIST_TN_MADURAI", "IN-TN", "Madurai", SettlementType.CITY, "625001", 9.9252, 78.1198),

        // Maharashtra Towns
        CityTown("CITY_MH_MUMBAI", "MANDAL_MH_MUMBAI_SOUTH", "DIST_MH_MUMBAI", "IN-MH", "Mumbai", SettlementType.METRO_CITY, "400001", 18.9220, 72.8347),
        CityTown("CITY_MH_PUNE", "MANDAL_MH_HAVELI", "DIST_MH_PUNE", "IN-MH", "Pune", SettlementType.METRO_CITY, "411001", 18.5204, 73.8567),
        CityTown("CITY_MH_THANE", "MANDAL_MH_MUMBAI_SOUTH", "DIST_MH_THANE", "IN-MH", "Thane", SettlementType.CITY, "400601", 19.2183, 72.9781),

        // Delhi (NCR)
        CityTown("CITY_DL_DELHI", "MANDAL_DL_CHANAKYAPURI", "DIST_DL_NEW_DELHI", "IN-DL", "New Delhi", SettlementType.METRO_CITY, "110001", 28.6139, 77.2090),

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

        // Badvel Areas
        LocationArea("AREA_AP_BDV_MAIN_RD", "CITY_AP_BADVEL", "MANDAL_AP_BADVEL", "DIST_AP_KADAPA", "IN-AP", "Badvel Main Road", "516227", "Near RTC Bus Stand", 14.7431, 79.0578, true),
        LocationArea("AREA_AP_BDV_NELLORE_RD", "CITY_AP_BADVEL", "MANDAL_AP_BADVEL", "DIST_AP_KADAPA", "IN-AP", "Nellore Road", "516227", "Near Bypass Junction", 14.7450, 79.0620, true),
        LocationArea("AREA_AP_BDV_MYDUKUR_RD", "CITY_AP_BADVEL", "MANDAL_AP_BADVEL", "DIST_AP_KADAPA", "IN-AP", "Mydukur Road", "516227", "Near Market Center", 14.7410, 79.0530, false),

        // Kadapa Areas
        LocationArea("AREA_AP_KDP_SEVEN_ROADS", "CITY_AP_KADAPA", "MANDAL_AP_KADAPA_URBAN", "DIST_AP_KADAPA", "IN-AP", "Seven Roads Circle", "516001", "Commercial Center", 14.4673, 78.8242, true),
        LocationArea("AREA_AP_KDP_NAGARAJUPALLI", "CITY_AP_KADAPA", "MANDAL_AP_KADAPA_URBAN", "DIST_AP_KADAPA", "IN-AP", "Nagarajupalli", "516001", "Near Railway Station", 14.4750, 78.8310, true),

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
        LocationArea("AREA_KA_BLR_WHITEFIELD", "CITY_KA_BENGALURU", "MANDAL_KA_BLR_EAST", "DIST_KA_BANGALORE_URBAN", "IN-KA", "Whitefield", "560066", "ITPL & Hope Farm", 12.9698, 77.7499, true),

        // International Areas
        LocationArea("AREA_AE_DXB_BURJ", "CITY_AE_DUBAI", "MANDAL_AE_DXB_DOWNTOWN", "DIST_AE_DUBAI_CENTRAL", "AE-DU", "Downtown Burj Khalifa", "00000", "Near Dubai Mall", 25.1972, 55.2744, true),
        LocationArea("AREA_AE_DXB_MARINA_WALK", "CITY_AE_DUBAI", "MANDAL_AE_DXB_MARINA", "DIST_AE_DUBAI_SOUTH", "AE-DU", "Marina Walk", "00000", "JBR Beach Road", 25.0780, 55.1380, true)
    )
    val areas = AREAS

    // ==========================================
    // 6. POPULAR QUICK-SELECTION PRESETS
    // ==========================================
    val POPULAR_LOCATION_PRESETS = listOf(
        LocationHierarchy(
            countryId = "IN", stateId = "IN-AP", districtId = "DIST_AP_KADAPA",
            mandalId = "MANDAL_AP_BADVEL", cityTownId = "CITY_AP_BADVEL", areaId = "AREA_AP_BDV_MAIN_RD",
            countryName = "India", stateName = "Andhra Pradesh", districtName = "YSR Kadapa",
            mandalName = "Badvel Mandal", cityName = "Badvel", areaName = "Badvel Main Road",
            postalCode = "516227", latitude = 14.7431, longitude = 79.0578
        ),
        LocationHierarchy(
            countryId = "IN", stateId = "IN-AP", districtId = "DIST_AP_PRAKASAM",
            mandalId = "MANDAL_AP_ONGOLE", cityTownId = "CITY_AP_ONGOLE", areaId = "AREA_AP_OGL_LAWYERPET",
            countryName = "India", stateName = "Andhra Pradesh", districtName = "Prakasam",
            mandalName = "Ongole Urban Mandal", cityName = "Ongole", areaName = "Lawyerpet",
            postalCode = "523001", latitude = 15.5080, longitude = 80.0450
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
            countryId = "IN", stateId = "IN-MH", districtId = "DIST_MH_MUMBAI",
            mandalId = "MANDAL_MH_MUMBAI_SOUTH", cityTownId = "CITY_MH_MUMBAI", areaId = null,
            countryName = "India", stateName = "Maharashtra", districtName = "Mumbai City",
            mandalName = "South Mumbai City", cityName = "Mumbai", areaName = "Colaba / Fort",
            postalCode = "400001", latitude = 18.9220, longitude = 72.8347
        ),
        LocationHierarchy(
            countryId = "IN", stateId = "IN-DL", districtId = "DIST_DL_NEW_DELHI",
            mandalId = "MANDAL_DL_CHANAKYAPURI", cityTownId = "CITY_DL_DELHI", areaId = null,
            countryName = "India", stateName = "Delhi (NCR)", districtName = "New Delhi",
            mandalName = "Chanakyapuri Tehsil", cityName = "New Delhi", areaName = "Connaught Place",
            postalCode = "110001", latitude = 28.6139, longitude = 77.2090
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
    // HELPER LOOKUP METHODS WITH DYNAMIC FALLBACK
    // ==========================================

    fun getStatesForCountry(countryId: String): List<State> {
        return STATES.filter { it.countryId == countryId }
    }

    fun getDistrictsForState(stateId: String): List<District> {
        val direct = DISTRICTS.filter { it.stateId == stateId }
        if (direct.isNotEmpty()) return direct

        // Dynamic district generator fallback for any custom state
        val state = findState(stateId) ?: return emptyList()
        return listOf(
            District("DIST_${state.code}_CENTRAL", state.id, "${state.name} Central District", "${state.code}_C", state.capitalCity, state.latitude, state.longitude),
            District("DIST_${state.code}_NORTH", state.id, "${state.name} North District", "${state.code}_N", "${state.name} North", state.latitude + 0.35, state.longitude + 0.15),
            District("DIST_${state.code}_SOUTH", state.id, "${state.name} South District", "${state.code}_S", "${state.name} South", state.latitude - 0.35, state.longitude - 0.15)
        )
    }

    fun getMandalsForDistrict(districtId: String): List<Mandal> {
        val direct = MANDALS.filter { it.districtId == districtId }
        if (direct.isNotEmpty()) return direct

        // Dynamic fallback: Generate standard administrative mandals for the district
        val dist = findDistrict(districtId) ?: return emptyList()
        val distClean = dist.name.replace(Regex("[^a-zA-Z0-9]"), "_")
        return listOf(
            Mandal("MANDAL_${dist.code}_URBAN", dist.id, dist.stateId, "${dist.name} Urban Mandal", "${dist.code}_U", dist.latitude, dist.longitude),
            Mandal("MANDAL_${dist.code}_RURAL", dist.id, dist.stateId, "${dist.name} Rural Mandal", "${dist.code}_R", dist.latitude + 0.04, dist.longitude + 0.04),
            Mandal("MANDAL_${dist.code}_NORTH", dist.id, dist.stateId, "${dist.name} North Mandal", "${dist.code}_N", dist.latitude + 0.08, dist.longitude - 0.03),
            Mandal("MANDAL_${dist.code}_SOUTH", dist.id, dist.stateId, "${dist.name} South Mandal", "${dist.code}_S", dist.latitude - 0.08, dist.longitude + 0.03),
            Mandal("MANDAL_${dist.code}_CENTRAL", dist.id, dist.stateId, "${dist.name} East Mandal", "${dist.code}_E", dist.latitude + 0.02, dist.longitude + 0.08)
        )
    }

    fun getCitiesForMandal(mandalId: String): List<CityTown> {
        val direct = CITIES.filter { it.mandalId == mandalId }
        if (direct.isNotEmpty()) return direct

        // Dynamic fallback: Generate key town & constituent gram panchayats/villages
        val mandal = findMandal(mandalId)
        if (mandal != null) {
            val baseName = mandal.name.replace(" Mandal", "").replace(" Taluk", "").replace(" Tehsil", "")
            return listOf(
                CityTown("CITY_${mandal.id}_TOWN", mandal.id, mandal.districtId, mandal.stateId, "$baseName Town / Center", SettlementType.TOWN, "500001", mandal.latitude, mandal.longitude),
                CityTown("CITY_${mandal.id}_VILLAGE1", mandal.id, mandal.districtId, mandal.stateId, "$baseName Main Village / GP", SettlementType.VILLAGE, "500002", mandal.latitude + 0.025, mandal.longitude + 0.015),
                CityTown("CITY_${mandal.id}_VILLAGE2", mandal.id, mandal.districtId, mandal.stateId, "$baseName East Gram Panchayat", SettlementType.VILLAGE, "500003", mandal.latitude - 0.025, mandal.longitude + 0.020),
                CityTown("CITY_${mandal.id}_COLONY", mandal.id, mandal.districtId, mandal.stateId, "$baseName Colony & Market", SettlementType.TOWN, "500004", mandal.latitude + 0.015, mandal.longitude - 0.025)
            )
        }
        return emptyList()
    }

    fun getCitiesForDistrict(districtId: String): List<CityTown> {
        val direct = CITIES.filter { it.districtId == districtId }
        if (direct.isNotEmpty()) return direct
        val mandals = getMandalsForDistrict(districtId)
        return mandals.flatMap { getCitiesForMandal(it.id) }
    }

    fun getAreasForCity(cityId: String): List<LocationArea> {
        val direct = AREAS.filter { it.cityTownId == cityId }
        if (direct.isNotEmpty()) return direct

        val city = findCity(cityId)
        if (city != null) {
            return listOf(
                LocationArea("AREA_${city.id}_MAIN", city.id, city.mandalId, city.districtId, city.stateId, "${city.name} Main Road", city.postalCode, "Near Bus Stand / Center", city.latitude, city.longitude, true),
                LocationArea("AREA_${city.id}_MARKET", city.id, city.mandalId, city.districtId, city.stateId, "${city.name} Market Center", city.postalCode, "Commercial Street", city.latitude + 0.008, city.longitude + 0.005, true),
                LocationArea("AREA_${city.id}_BYPASS", city.id, city.mandalId, city.districtId, city.stateId, "${city.name} Bypass & Highway", city.postalCode, "Highway Junction", city.latitude - 0.010, city.longitude - 0.008, false)
            )
        }
        return emptyList()
    }

    fun getAreasForMandal(mandalId: String): List<LocationArea> {
        val direct = AREAS.filter { it.mandalId == mandalId }
        if (direct.isNotEmpty()) return direct
        val cities = getCitiesForMandal(mandalId)
        return cities.flatMap { getAreasForCity(it.id) }
    }

    fun findCountry(countryId: String): Country? = COUNTRIES.firstOrNull { it.id == countryId }
    
    fun findState(stateId: String): State? = STATES.firstOrNull { it.id == stateId }
    
    fun findDistrict(districtId: String): District? {
        val direct = DISTRICTS.firstOrNull { it.id == districtId }
        if (direct != null) return direct
        // Search in dynamically generated districts
        return STATES.firstNotNullOfOrNull { st ->
            getDistrictsForState(st.id).firstOrNull { it.id == districtId }
        }
    }
    
    fun findMandal(mandalId: String): Mandal? {
        val direct = MANDALS.firstOrNull { it.id == mandalId }
        if (direct != null) return direct
        return DISTRICTS.firstNotNullOfOrNull { dt ->
            getMandalsForDistrict(dt.id).firstOrNull { it.id == mandalId }
        }
    }

    fun findCity(cityId: String): CityTown? {
        val direct = CITIES.firstOrNull { it.id == cityId }
        if (direct != null) return direct
        return MANDALS.firstNotNullOfOrNull { md ->
            getCitiesForMandal(md.id).firstOrNull { it.id == cityId }
        }
    }

    fun findArea(areaId: String?): LocationArea? {
        if (areaId == null) return null
        val direct = AREAS.firstOrNull { it.id == areaId }
        if (direct != null) return direct
        return CITIES.firstNotNullOfOrNull { ct ->
            getAreasForCity(ct.id).firstOrNull { it.id == areaId }
        }
    }

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
        val dt = findDistrict(districtId) ?: (getDistrictsForState(st.id).firstOrNull() ?: DISTRICTS.first())
        val md = findMandal(mandalId) ?: getMandalsForDistrict(dt.id).firstOrNull()
        val ct = findCity(cityTownId) ?: (if (md != null) getCitiesForMandal(md.id).firstOrNull() else null) ?: getCitiesForDistrict(dt.id).firstOrNull() ?: CITIES.first()
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
            val city = getCitiesForMandal(mandal.id).firstOrNull() ?: CITIES.firstOrNull { it.districtId == mandal.districtId } ?: CITIES.first()
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

        val matchedStates = STATES.filter {
            it.name.lowercase().contains(q)
        }.map { st ->
            val dist = getDistrictsForState(st.id).firstOrNull() ?: DISTRICTS.first()
            val mandal = getMandalsForDistrict(dist.id).firstOrNull() ?: MANDALS.first()
            val city = getCitiesForDistrict(dist.id).firstOrNull() ?: CITIES.first()
            buildHierarchy(st.countryId, st.id, dist.id, mandal.id, city.id, null)
        }

        return (matchedAreas + matchedCities + matchedMandals + matchedDistricts + matchedStates)
            .distinctBy { it.breadcrumbLabel }
            .take(20)
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
        val nearestArea = AREAS.minByOrNull {
            val dLat = it.latitude - lat
            val dLng = it.longitude - lng
            dLat * dLat + dLng * dLng
        }
        if (nearestArea != null) {
            return buildHierarchy(
                "IN",
                nearestArea.stateId,
                nearestArea.districtId,
                nearestArea.mandalId,
                nearestArea.cityTownId,
                nearestArea.id
            )
        }
        val nearestCity = CITIES.minByOrNull {
            val dLat = it.latitude - lat
            val dLng = it.longitude - lng
            dLat * dLat + dLng * dLng
        }
        if (nearestCity != null) {
            return buildHierarchy(
                "IN",
                nearestCity.stateId,
                nearestCity.districtId,
                nearestCity.mandalId,
                nearestCity.id,
                null
            )
        }
        return popularPresets.first()
    }

    /**
     * Looks up location hierarchy by postal/PIN code.
     * Matches exact area postal code, or city postal code, or prefix match.
     */
    fun lookupByPincode(pincode: String): LocationHierarchy? {
        val cleanPin = pincode.trim()
        if (cleanPin.length < 3) return null

        // 1. Check exact area postal code
        val matchedArea = AREAS.firstOrNull { it.postalCode == cleanPin }
        if (matchedArea != null) {
            val st = findState(matchedArea.stateId)
            return buildHierarchy(st?.countryId ?: "IN", matchedArea.stateId, matchedArea.districtId, matchedArea.mandalId, matchedArea.cityTownId, matchedArea.id)
        }

        // 2. Check exact city postal code
        val matchedCity = CITIES.firstOrNull { it.postalCode == cleanPin }
        if (matchedCity != null) {
            val st = findState(matchedCity.stateId)
            return buildHierarchy(st?.countryId ?: "IN", matchedCity.stateId, matchedCity.districtId, matchedCity.mandalId, matchedCity.id, null)
        }

        // 3. Check partial / prefix postal code match
        val partialArea = AREAS.firstOrNull { it.postalCode.startsWith(cleanPin) }
        if (partialArea != null) {
            val st = findState(partialArea.stateId)
            return buildHierarchy(st?.countryId ?: "IN", partialArea.stateId, partialArea.districtId, partialArea.mandalId, partialArea.cityTownId, partialArea.id)
        }

        val partialCity = CITIES.firstOrNull { it.postalCode.startsWith(cleanPin) }
        if (partialCity != null) {
            val st = findState(partialCity.stateId)
            return buildHierarchy(st?.countryId ?: "IN", partialCity.stateId, partialCity.districtId, partialCity.mandalId, partialCity.id, null)
        }

        return null
    }
}

fun calculateDistanceKm(lat1: Double, lon1: Double, lat2: Double, lon2: Double): Double {
    return IndiaLocationMasterData.calculateDistanceKm(lat1, lon1, lat2, lon2)
}
