class LocationHierarchyItem {
  const LocationHierarchyItem({
    required this.country,
    required this.state,
    required this.district,
    required this.city,
    required this.area,
    this.pincode = '500033',
  });

  final String country;
  final String state;
  final String district;
  final String city;
  final String area;
  final String pincode;

  String get formattedHierarchy => '$state → $district → $city → $area';

  LocationHierarchyItem copyWith({
    String? country,
    String? state,
    String? district,
    String? city,
    String? area,
    String? pincode,
  }) {
    return LocationHierarchyItem(
      country: country ?? this.country,
      state: state ?? this.state,
      district: district ?? this.district,
      city: city ?? this.city,
      area: area ?? this.area,
      pincode: pincode ?? this.pincode,
    );
  }
}

class IndiaLocationData {
  static const defaultItem = LocationHierarchyItem(
    country: 'India',
    state: 'Andhra Pradesh',
    district: 'YSR Kadapa',
    city: 'Badvel',
    area: 'Badvel Main Road',
    pincode: '516227',
  );

  static const List<LocationHierarchyItem> popularPresets = [
    LocationHierarchyItem(
      country: 'India',
      state: 'Andhra Pradesh',
      district: 'YSR Kadapa',
      city: 'Badvel',
      area: 'Badvel Main Road',
      pincode: '516227',
    ),
    LocationHierarchyItem(
      country: 'India',
      state: 'Telangana',
      district: 'Hyderabad',
      city: 'Hyderabad',
      area: 'Jubilee Hills Road No. 36',
      pincode: '500033',
    ),
    LocationHierarchyItem(
      country: 'India',
      state: 'Karnataka',
      district: 'Bengaluru Urban',
      city: 'Bengaluru',
      area: 'Indiranagar 100ft Road',
      pincode: '560038',
    ),
    LocationHierarchyItem(
      country: 'India',
      state: 'Tamil Nadu',
      district: 'Chennai',
      city: 'Chennai',
      area: 'T. Nagar Usman Road',
      pincode: '600017',
    ),
    LocationHierarchyItem(
      country: 'India',
      state: 'Maharashtra',
      district: 'Mumbai Suburban',
      city: 'Mumbai',
      area: 'Bandra West Linking Road',
      pincode: '400050',
    ),
  ];

  static const Map<String, List<String>> stateDistricts = {
    'Andhra Pradesh': [
      'YSR Kadapa',
      'Prakasam',
      'NTR (Vijayawada)',
      'Guntur',
      'Visakhapatnam',
      'Tirupati',
      'Kurnool',
      'Nellore',
    ],
    'Telangana': [
      'Hyderabad',
      'Rangareddy',
      'Medchal-Malkajgiri',
      'Warangal',
      'Karimnagar',
      'Nizamabad',
    ],
    'Karnataka': [
      'Bengaluru Urban',
      'Bengaluru Rural',
      'Mysuru',
      'Dakshina Kannada (Mangaluru)',
      'Belagavi',
      'Hubballi-Dharwad',
    ],
    'Tamil Nadu': [
      'Chennai',
      'Coimbatore',
      'Madurai',
      'Tiruchirappalli',
      'Salem',
    ],
    'Maharashtra': [
      'Mumbai Suburban',
      'Mumbai City',
      'Pune',
      'Thane',
      'Nagpur',
      'Nashik',
    ],
  };

  static const Map<String, List<String>> districtCities = {
    'YSR Kadapa': ['Badvel', 'Kadapa', 'Proddatur', 'Pulivendula', 'Rajampet', 'Jammalamadugu'],
    'Prakasam': ['Ongole', 'Chirala', 'Kandukur', 'Markapur', 'Giddalur'],
    'NTR (Vijayawada)': ['Vijayawada', 'Ibrahimpatnam', 'Mylavaram', 'Tiruvuru'],
    'Guntur': ['Guntur', 'Tenali', 'Mangalagiri', 'Ponnur'],
    'Visakhapatnam': ['Visakhapatnam', 'Gajuwaka', 'Anandapuram', 'Bheemunipatnam'],
    'Hyderabad': ['Jubilee Hills', 'Banjara Hills', 'Gachibowli', 'Madhapur', 'Kondapur', 'Secunderabad'],
    'Bengaluru Urban': ['Indiranagar', 'Koramangala', 'HSR Layout', 'Whitefield', 'Jayanagar', 'MG Road'],
    'Chennai': ['T. Nagar', 'Adyar', 'Velachery', 'Anna Nagar', 'Mylapore'],
    'Mumbai Suburban': ['Bandra West', 'Andheri West', 'Juhu', 'Powai', 'Malad', 'Borivali'],
  };
}
