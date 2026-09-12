import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Application localizations. Add a language by inserting a table; UI code
/// continues to call the same getters.
class AppLocalizations {
  AppLocalizations(this.locale);

  final Locale locale;

  static AppLocalizations of(BuildContext context) {
    final l10n = Localizations.of<AppLocalizations>(context, AppLocalizations);
    return l10n ?? AppLocalizations(const Locale('en'));
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  static const List<Locale> supportedLocales = [
    Locale('en'),
    Locale('te'),
    Locale('hi'),
    Locale('kn'),
    Locale('ta'),
  ];

  static const Map<String, Map<String, String>> _tables = {
    'en': _en,
    'te': _te,
    'hi': _hi,
    'kn': _kn,
    'ta': _ta,
  };

  static const Map<String, String> _en = {
    'appName': 'BookMySpace',
    'tagline': 'Discover and book spaces with ease',
    'navHome': 'Home',
    'navSearch': 'Search',
    'navBookings': 'Bookings',
    'navProfile': 'Profile',
    'notifications': 'Notifications',
    'courses': 'Courses',
    'venues': 'Venues',
    'venueDetails': 'Venue Details',
    'aboutThisVenue': 'About this venue',
    'amenities': 'Amenities',
    'operatingHours': 'Operating Hours',
    'details': 'Details',
    'foodOptions': 'Food Options',
    'parking': 'Parking',
    'taxRate': 'Tax Rate',
    'address': 'Address',
    'basePrice': 'Base Price',
    'capacity': 'Capacity',
    'pricing': 'Starting at',
    'bookNow': 'Book Now',
    'search': 'Search',
    'searchHint': 'Search venues, cities or categories...',
    'filters': 'Filters',
    'clearFilters': 'Clear Filters',
    'apply': 'Apply',
    'close': 'Close',
    'back': 'Back',
    'allCategories': 'All Categories',
    'minPrice': 'Min Price',
    'maxPrice': 'Max Price',
    'sortBy': 'Sort By',
    'relevance': 'Relevance',
    'priceLowToHigh': 'Price: Low to High',
    'priceHighToLow': 'Price: High to Low',
    'topRated': 'Top Rated',
    'noResults': 'No results found',
    'noResultsMessage': 'Try a different keyword, category or price range.',
    'tryAgain': 'Try Again',
    'loading': 'Loading...',
    'cancel': 'Cancel',
    'confirm': 'Confirm',
    'delete': 'Delete',
    'done': 'Done',
    'keep': 'Keep',
    'next': 'Next',
    'skip': 'Skip',
    'getStarted': 'Get Started',
    'total': 'Total',
    'selectDate': 'Select Date',
    'selectTimeSlot': 'Select Time Slot',
    'noSlotsForDate': 'No slots available for this date',
    'confirmBooking': 'Confirm Booking',
    'cancelBooking': 'Cancel Booking',
    'cancelBookingConfirm': 'Are you sure you want to cancel this booking?',
    'myBookings': 'My Bookings',
    'noBookings': 'No bookings yet',
    'noBookingsMessage': 'Your booked venues and passes will appear here.',
    'requestRefund': 'Request Refund',
    'requestRefundConfirm': 'Are you sure you want to request a refund?',
    'refundRequested': 'Refund request submitted successfully',
    'savedVenues': 'Saved Venues',
    'upcomingEvents': 'Upcoming Events',
    'noUpcomingEvents': 'No upcoming events',
    'noUpcomingEventsMessage': 'Check back later for new workshops and events.',
    'freeEvent': 'Free',
    'seatsLeft': '{count} seats left',
    'durationWeeks': '{weeks} weeks',
    'soldOut': 'Sold Out',
    'registered': 'Registered',
    'registerNow': 'Register Now',
    'cancelRegistration': 'Cancel Registration',
    'cancelRegistrationConfirm':
        'Are you sure you want to cancel your event registration?',
    'registrationCancelled': 'Registration cancelled successfully',
    'noCourses': 'No courses available',
    'noCoursesMessage': 'Explore new courses and batches coming soon.',
    'courseFee': 'Course Fee',
    'instructor': 'Instructor',
    'enrollInCourse': 'Choose a batch',
    'enrollNow': 'Enroll Now',
    'enrolled': 'Enrolled',
    'dropEnrollment': 'Drop',
    'dropEnrollmentConfirm': 'Drop this batch? Your seat will be released.',
    'enrollmentDropped': 'Enrollment dropped',
    'batchStartsOn': 'Starts',
    'signInToEnroll': 'Sign in to enroll',
    'modeOnline': 'Online',
    'modeOffline': 'Offline',
    'modeHybrid': 'Hybrid',
    'settings': 'Settings',
    'themeMode': 'Theme Mode',
    'language': 'Language',
    'support': 'Support',
    'privacyPolicy': 'Privacy Policy',
    'termsAndConditions': 'Terms & Conditions',
    'deleteAccount': 'Delete Account',
    'name': 'Name',
    'email': 'Email',
    'password': 'Password',
    'errorInvalidEmail': 'Please enter a valid email address',
    'signUp': 'Sign Up',
    'signIn': 'Sign In',
    'priority': 'Priority',
    'about': 'About',
    'auditLog': 'Audit Log',
    'analyticsLabel': 'Analytics',
    'ownerDashboard': 'Owner Dashboard',
    'myVenues': 'My Venues',
    'guest': 'Guest',
    'notSignedIn': 'Not signed in',
    'featuresHub': 'Features',
    'featuresHubSubtitle':
        'Modules can be switched off in configuration. Authorization still comes from backend roles and RLS.',
    'featureEnabled': 'Available in this build',
    'featureDisabledUntilBackend': 'Disabled until a backend exists',
    'onLabel': 'On',
    'offLabel': 'Off',
    'offlineMessage':
        'You appear to be offline. Showing last-known safe data where available.',
    'bookingConfirmed': 'Booking confirmed',
    'awaitingConfirmation': 'Awaiting confirmation',
    'viewBookings': 'View bookings',
    'backToHome': 'Back to Home',
    'legalName': 'Legal business name',
    'gstin': 'GSTIN',
    'pan': 'PAN',
    'city': 'City',
    'state': 'State',
    'verificationPending': 'Verification pending',
    'verificationSubmitted': 'Submitted for review',
    'ownerRegistrationSubtitle':
        'Create a venue-owner account. Roles are granted by BookMySpace after this form is saved.',
    'lightTheme': 'Light',
    'darkTheme': 'Dark',
    'systemTheme': 'System',
    'onboardingTitle1': 'Find Your Perfect Space',
    'onboardingSubtitle1':
        'Discover convention halls, party venues, sports grounds, and classrooms near you.',
    'onboardingTitle2': 'Real-Time Availability',
    'onboardingSubtitle2':
        'Check open slots, transparent pricing, and instant booking confirmations.',
    'onboardingTitle3': 'Seamless & Secure',
    'onboardingSubtitle3':
        'Pay securely with instant tax invoices and easy booking management.',
  };

  static const Map<String, String> _te = {
    'appName': 'BookMySpace',
    'tagline': 'స్థలాలను సులభంగా కనుగొని బుక్ చేయండి',
    'navHome': 'హోమ్',
    'navSearch': 'శోధన',
    'navBookings': 'బుకింగ్‌లు',
    'navProfile': 'ప్రొఫైల్',
    'notifications': 'నోటిఫికేషన్లు',
    'courses': 'కోర్సులు',
    'venues': 'వేదికలు',
    'venueDetails': 'వేదిక వివరాలు',
    'aboutThisVenue': 'ఈ వేదిక గురించి',
    'amenities': 'సౌకర్యాలు',
    'operatingHours': 'పని గంటలు',
    'details': 'వివరాలు',
    'foodOptions': 'ఆహార ఎంపికలు',
    'parking': 'పార్కింగ్',
    'taxRate': 'పన్ను రేటు',
    'address': 'చిరునామా',
    'basePrice': 'ప్రాథమిక ధర',
    'capacity': 'సామర్థ్యం',
    'pricing': 'ప్రారంభ ధర',
    'bookNow': 'ఇప్పుడు బుక్ చేయండి',
    'search': 'శోధన',
    'searchHint': 'వేదికలు, నగరాలు లేదా వర్గాలను వెతకండి...',
    'filters': 'ఫిల్టర్లు',
    'clearFilters': 'ఫిల్టర్లు తీసివేయి',
    'apply': 'వర్తింపజేయి',
    'close': 'మూసివేయి',
    'back': 'వెనుకకు',
    'allCategories': 'అన్ని వర్గాలు',
    'minPrice': 'కనిష్ట ధర',
    'maxPrice': 'గరిష్ట ధర',
    'sortBy': 'క్రమం',
    'relevance': 'సంబంధం',
    'priceLowToHigh': 'ధర: తక్కువ నుండి ఎక్కువ',
    'priceHighToLow': 'ధర: ఎక్కువ నుండి తక్కువ',
    'topRated': 'అత్యుత్తమ రేటింగ్',
    'noResults': 'ఫలితాలు లేవు',
    'noResultsMessage': 'వేరే పదం, వర్గం లేదా ధర పరిధిని ప్రయత్నించండి.',
    'tryAgain': 'మళ్లీ ప్రయత్నించండి',
    'loading': 'లోడ్ అవుతోంది...',
    'cancel': 'రద్దు',
    'confirm': 'నిర్ధారించు',
    'delete': 'తొలగించు',
    'done': 'పూర్తి',
    'keep': 'ఉంచు',
    'next': 'తర్వాత',
    'skip': 'దాటవేయి',
    'getStarted': 'ప్రారంభించండి',
    'total': 'మొత్తం',
    'selectDate': 'తేదీ ఎంచుకోండి',
    'selectTimeSlot': 'సమయం ఎంచుకోండి',
    'noSlotsForDate': 'ఈ తేదీకి స్లాట్లు లేవు',
    'confirmBooking': 'బుకింగ్ నిర్ధారించండి',
    'cancelBooking': 'బుకింగ్ రద్దు',
    'cancelBookingConfirm': 'ఈ బుకింగ్‌ను రద్దు చేయాలా?',
    'myBookings': 'నా బుకింగ్‌లు',
    'noBookings': 'ఇంకా బుకింగ్‌లు లేవు',
    'noBookingsMessage': 'మీ బుక్ చేసిన వేదికలు ఇక్కడ కనిపిస్తాయి.',
    'requestRefund': 'రీఫండ్ అభ్యర్థించండి',
    'requestRefundConfirm': 'రీఫండ్ అభ్యర్థించాలా?',
    'refundRequested': 'రీఫండ్ అభ్యర్థన పంపబడింది',
    'savedVenues': 'సేవ్ చేసిన వేదికలు',
    'upcomingEvents': 'రాబోయే ఈవెంట్‌లు',
    'noUpcomingEvents': 'రాబోయే ఈవెంట్‌లు లేవు',
    'noUpcomingEventsMessage': 'కొత్త వర్క్‌షాప్‌ల కోసం తర్వాత చూడండి.',
    'freeEvent': 'ఉచితం',
    'seatsLeft': '{count} సీట్లు మిగిలాయి',
    'durationWeeks': '{weeks} వారాలు',
    'soldOut': 'అమ్ముడయ్యాయి',
    'registered': 'నమోదైంది',
    'registerNow': 'ఇప్పుడు నమోదు',
    'cancelRegistration': 'నమోదు రద్దు',
    'cancelRegistrationConfirm': 'ఈవెంట్ నమోదును రద్దు చేయాలా?',
    'registrationCancelled': 'నమోదు రద్దు చేయబడింది',
    'noCourses': 'కోర్సులు లేవు',
    'noCoursesMessage': 'కొత్త కోర్సులు త్వరలో.',
    'courseFee': 'కోర్సు రుసుము',
    'instructor': 'బోధకుడు',
    'enrollInCourse': 'బ్యాచ్ ఎంచుకోండి',
    'enrollNow': 'ఇప్పుడు నమోదు',
    'enrolled': 'నమోదయ్యారు',
    'dropEnrollment': 'తొలగించు',
    'dropEnrollmentConfirm': 'ఈ బ్యాచ్‌ను వదలాలా?',
    'enrollmentDropped': 'నమోదు తొలగించబడింది',
    'batchStartsOn': 'ప్రారంభం',
    'signInToEnroll': 'నమోదు చేయడానికి సైన్ ఇన్',
    'modeOnline': 'ఆన్‌లైన్',
    'modeOffline': 'ఆఫ్‌లైన్',
    'modeHybrid': 'హైబ్రిడ్',
    'settings': 'సెట్టింగ్‌లు',
    'themeMode': 'థీమ్',
    'language': 'భాష',
    'support': 'సహాయం',
    'privacyPolicy': 'గోప్యతా విధానం',
    'termsAndConditions': 'నిబంధనలు',
    'deleteAccount': 'ఖాతా తొలగించు',
    'name': 'పేరు',
    'email': 'ఇమెయిల్',
    'password': 'పాస్‌వర్డ్',
    'errorInvalidEmail': 'సరైన ఇమెయిల్ ఇవ్వండి',
    'signUp': 'నమోదు',
    'signIn': 'సైన్ ఇన్',
    'priority': 'ప్రాధాన్యత',
    'about': 'గురించి',
    'auditLog': 'ఆడిట్ లాగ్',
    'analyticsLabel': 'విశ్లేషణలు',
    'ownerDashboard': 'యజమాని డాష్‌బోర్డ్',
    'myVenues': 'నా వేదికలు',
    'guest': 'అతిథి',
    'notSignedIn': 'సైన్ ఇన్ కాలేదు',
    'featuresHub': 'ఫీచర్లు',
    'featuresHubSubtitle':
        'మాడ్యూల్స్ కాన్ఫిగరేషన్‌లో ఆఫ్ చేయవచ్చు. అధికారం బ్యాకెండ్ రోల్స్ మరియు RLS నుండే వస్తుంది.',
    'featureEnabled': 'ఈ బిల్డ్‌లో అందుబాటులో ఉంది',
    'featureDisabledUntilBackend': 'బ్యాకెండ్ లేనంతవరకు నిలిపివేయబడింది',
    'onLabel': 'ఆన్',
    'offLabel': 'ఆఫ్',
    'offlineMessage':
        'మీరు ఆఫ్‌లైన్‌లో ఉన్నట్లున్నారు. సురక్షితమైన చివరి డేటా చూపిస్తున్నాం.',
    'bookingConfirmed': 'బుకింగ్ నిర్ధారించబడింది',
    'awaitingConfirmation': 'నిర్ధారణ కోసం వేచి ఉంది',
    'viewBookings': 'బుకింగ్‌లు చూడండి',
    'backToHome': 'హోమ్‌కు వెళ్లండి',
    'legalName': 'చట్టపరమైన వ్యాపార పేరు',
    'gstin': 'GSTIN',
    'pan': 'PAN',
    'city': 'నగరం',
    'state': 'రాష్ట్రం',
    'verificationPending': 'ధృవీకరణ పెండింగ్‌లో ఉంది',
    'verificationSubmitted': 'సమీక్ష కోసం సమర్పించబడింది',
    'ownerRegistrationSubtitle':
        'వేదిక యజమాని ఖాతాను సృష్టించండి. రోల్స్ ఈ ఫారమ్ సేవ్ అయిన తర్వాత మంజూరు అవుతాయి.',
    'lightTheme': 'లైట్',
    'darkTheme': 'డార్క్',
    'systemTheme': 'సిస్టమ్',
    'onboardingTitle1': 'మీ సరైన స్థలాన్ని కనుగొనండి',
    'onboardingSubtitle1':
        'మీ దగ్గర కన్వెన్షన్ హాల్స్, పార్టీ వేదికలు, క్రీడా మైదానాలు మరియు తరగతి గదులు.',
    'onboardingTitle2': 'రియల్-టైమ్ లభ్యత',
    'onboardingSubtitle2':
        'ఓపెన్ స్లాట్లు, స్పష్టమైన ధరలు మరియు తక్షణ బుకింగ్ నిర్ధారణలు.',
    'onboardingTitle3': 'సురక్షితం మరియు సులభం',
    'onboardingSubtitle3':
        'సురక్షితంగా చెల్లించి టాక్స్ ఇన్‌వాయిస్‌లు మరియు బుకింగ్ నిర్వహణ పొందండి.',
  };

  static const Map<String, String> _hi = {
    'appName': 'BookMySpace',
    'tagline': 'जगहें खोजें और आसानी से बुक करें',
    'navHome': 'होम',
    'navSearch': 'खोज',
    'navBookings': 'बुकिंग',
    'navProfile': 'प्रोफ़ाइल',
    'notifications': 'सूचनाएँ',
    'courses': 'कोर्स',
    'venues': 'स्थान',
    'venueDetails': 'स्थान विवरण',
    'aboutThisVenue': 'इस स्थान के बारे में',
    'amenities': 'सुविधाएँ',
    'operatingHours': 'समय',
    'details': 'विवरण',
    'foodOptions': 'भोजन विकल्प',
    'parking': 'पार्किंग',
    'taxRate': 'कर दर',
    'address': 'पता',
    'basePrice': 'आधार मूल्य',
    'capacity': 'क्षमता',
    'pricing': 'शुरुआती कीमत',
    'bookNow': 'अभी बुक करें',
    'search': 'खोज',
    'searchHint': 'स्थान, शहर या श्रेणियाँ खोजें...',
    'filters': 'फ़िल्टर',
    'clearFilters': 'फ़िल्टर हटाएँ',
    'apply': 'लागू करें',
    'close': 'बंद करें',
    'back': 'वापस',
    'allCategories': 'सभी श्रेणियाँ',
    'minPrice': 'न्यूनतम मूल्य',
    'maxPrice': 'अधिकतम मूल्य',
    'sortBy': 'क्रम',
    'relevance': 'प्रासंगिकता',
    'priceLowToHigh': 'कीमत: कम से अधिक',
    'priceHighToLow': 'कीमत: अधिक से कम',
    'topRated': 'उच्च रेटेड',
    'noResults': 'कोई परिणाम नहीं',
    'noResultsMessage': 'कोई अन्य शब्द, श्रेणी या मूल्य सीमा आज़माएँ.',
    'tryAgain': 'फिर कोशिश करें',
    'loading': 'लोड हो रहा है...',
    'cancel': 'रद्द',
    'confirm': 'पुष्टि',
    'delete': 'हटाएँ',
    'done': 'हो गया',
    'keep': 'रखें',
    'next': 'आगे',
    'skip': 'छोड़ें',
    'getStarted': 'शुरू करें',
    'total': 'कुल',
    'selectDate': 'तारीख चुनें',
    'selectTimeSlot': 'समय चुनें',
    'noSlotsForDate': 'इस तारीख पर स्लॉट नहीं हैं',
    'confirmBooking': 'बुकिंग की पुष्टि करें',
    'cancelBooking': 'बुकिंग रद्द करें',
    'cancelBookingConfirm': 'क्या आप यह बुकिंग रद्द करना चाहते हैं?',
    'myBookings': 'मेरी बुकिंग',
    'noBookings': 'अभी कोई बुकिंग नहीं',
    'noBookingsMessage': 'आपकी बुक की गई जगहें यहाँ दिखेंगी.',
    'requestRefund': 'रिफंड माँगें',
    'requestRefundConfirm': 'क्या आप रिफंड माँगना चाहते हैं?',
    'refundRequested': 'रिफंड अनुरोध भेज दिया गया',
    'savedVenues': 'सहेजे स्थान',
    'upcomingEvents': 'आगामी कार्यक्रम',
    'noUpcomingEvents': 'कोई आगामी कार्यक्रम नहीं',
    'noUpcomingEventsMessage': 'नए वर्कशॉप के लिए बाद में देखें.',
    'freeEvent': 'मुफ़्त',
    'seatsLeft': '{count} सीटें शेष',
    'durationWeeks': '{weeks} सप्ताह',
    'soldOut': 'बिक गया',
    'registered': 'पंजीकृत',
    'registerNow': 'अभी पंजीकरण करें',
    'cancelRegistration': 'पंजीकरण रद्द करें',
    'cancelRegistrationConfirm': 'क्या आप कार्यक्रम पंजीकरण रद्द करना चाहते हैं?',
    'registrationCancelled': 'पंजीकरण रद्द हो गया',
    'noCourses': 'कोई कोर्स नहीं',
    'noCoursesMessage': 'नए कोर्स जल्द आ रहे हैं.',
    'courseFee': 'कोर्स शुल्क',
    'instructor': 'प्रशिक्षक',
    'enrollInCourse': 'बैच चुनें',
    'enrollNow': 'अभी नामांकन',
    'enrolled': 'नामांकित',
    'dropEnrollment': 'छोड़ें',
    'dropEnrollmentConfirm': 'यह बैच छोड़ें? आपकी सीट खाली हो जाएगी.',
    'enrollmentDropped': 'नामांकन हटाया गया',
    'batchStartsOn': 'शुरुआत',
    'signInToEnroll': 'नामांकन के लिए साइन इन करें',
    'modeOnline': 'ऑनलाइन',
    'modeOffline': 'ऑफ़लाइन',
    'modeHybrid': 'हाइब्रिड',
    'settings': 'सेटिंग्स',
    'themeMode': 'थीम',
    'language': 'भाषा',
    'support': 'सहायता',
    'privacyPolicy': 'गोपनीयता नीति',
    'termsAndConditions': 'नियम और शर्तें',
    'deleteAccount': 'खाता हटाएँ',
    'name': 'नाम',
    'email': 'ईमेल',
    'password': 'पासवर्ड',
    'errorInvalidEmail': 'कृपया मान्य ईमेल दर्ज करें',
    'signUp': 'साइन अप',
    'signIn': 'साइन इन',
    'priority': 'प्राथमिकता',
    'about': 'परिचय',
    'auditLog': 'ऑडिट लॉग',
    'analyticsLabel': 'विश्लेषण',
    'ownerDashboard': 'मालिक डैशबोर्ड',
    'myVenues': 'मेरे स्थान',
    'guest': 'अतिथि',
    'notSignedIn': 'साइन इन नहीं',
    'featuresHub': 'सुविधाएँ',
    'featuresHubSubtitle':
        'मॉड्यूल कॉन्फ़िगरेशन से बंद हो सकते हैं. अधिकार बैकएंड भूमिकाओं और RLS से ही मिलते हैं.',
    'featureEnabled': 'इस बिल्ड में उपलब्ध',
    'featureDisabledUntilBackend': 'बैकएंड होने तक बंद',
    'onLabel': 'चालू',
    'offLabel': 'बंद',
    'offlineMessage':
        'आप ऑफ़लाइन लग रहे हैं. जहाँ सुरक्षित है, पिछला डेटा दिखाया जा रहा है.',
    'bookingConfirmed': 'बुकिंग पुष्टि हुई',
    'awaitingConfirmation': 'पुष्टि की प्रतीक्षा',
    'viewBookings': 'बुकिंग देखें',
    'backToHome': 'होम पर जाएँ',
    'legalName': 'कानूनी व्यवसाय नाम',
    'gstin': 'GSTIN',
    'pan': 'PAN',
    'city': 'शहर',
    'state': 'राज्य',
    'verificationPending': 'सत्यापन लंबित',
    'verificationSubmitted': 'समीक्षा के लिए जमा',
    'ownerRegistrationSubtitle':
        'स्थान-मालिक खाता बनाएँ. भूमिकाएँ फ़ॉर्म सहेजने के बाद मिलती हैं.',
    'lightTheme': 'लाइट',
    'darkTheme': 'डार्क',
    'systemTheme': 'सिस्टम',
    'onboardingTitle1': 'अपनी सही जगह खोजें',
    'onboardingSubtitle1':
        'कन्वेंशन हॉल, पार्टी स्थल, खेल मैदान और कक्षाएँ अपने पास खोजें.',
    'onboardingTitle2': 'रियल-टाइम उपलब्धता',
    'onboardingSubtitle2':
        'खुले स्लॉट, स्पष्ट कीमत और तुरंत बुकिंग पुष्टि देखें.',
    'onboardingTitle3': 'सरल और सुरक्षित',
    'onboardingSubtitle3':
        'सुरक्षित भुगतान, टैक्स इनवॉइस और आसान बुकिंग प्रबंधन.',
  };

  static const Map<String, String> _kn = {
    'appName': 'BookMySpace',
    'tagline': 'ಸ್ಥಳಗಳನ್ನು ಸುಲಭವಾಗಿ ಕಂಡುಹಿಡಿದು ಬುಕ್ ಮಾಡಿ',
    'navHome': 'ಮುಖಪುಟ',
    'navSearch': 'ಹುಡುಕು',
    'navBookings': 'ಬುಕಿಂಗ್‌ಗಳು',
    'navProfile': 'ಪ್ರೊಫೈಲ್',
    'notifications': 'ಅಧಿಸೂಚನೆಗಳು',
    'courses': 'ಕೋರ್ಸ್‌ಗಳು',
    'venues': 'ಸ್ಥಳಗಳು',
    'venueDetails': 'ಸ್ಥಳದ ವಿವರ',
    'aboutThisVenue': 'ಈ ಸ್ಥಳದ ಬಗ್ಗೆ',
    'amenities': 'ಸೌಲಭ್ಯಗಳು',
    'operatingHours': 'ಕಾರ್ಯಾಚರಣೆ ಸಮಯ',
    'details': 'ವಿವರಗಳು',
    'foodOptions': 'ಆಹಾರ ಆಯ್ಕೆಗಳು',
    'parking': 'ಪಾರ್ಕಿಂಗ್',
    'taxRate': 'ತೆರಿಗೆ ದರ',
    'address': 'ವಿಳಾಸ',
    'basePrice': 'ಮೂಲ ಬೆಲೆ',
    'capacity': 'ಸಾಮರ್ಥ್ಯ',
    'pricing': 'ಆರಂಭಿಕ ಬೆಲೆ',
    'bookNow': 'ಈಗ ಬುಕ್ ಮಾಡಿ',
    'search': 'ಹುಡುಕು',
    'searchHint': 'ಸ್ಥಳ, ನಗರ ಅಥವಾ ವರ್ಗ ಹುಡುಕಿ...',
    'filters': 'ಫಿಲ್ಟರ್‌ಗಳು',
    'clearFilters': 'ಫಿಲ್ಟರ್ ತೆರವುಗೊಳಿಸಿ',
    'apply': 'ಅನ್ವಯಿಸಿ',
    'close': 'ಮುಚ್ಚಿ',
    'back': 'ಹಿಂದೆ',
    'allCategories': 'ಎಲ್ಲಾ ವರ್ಗಗಳು',
    'minPrice': 'ಕನಿಷ್ಠ ಬೆಲೆ',
    'maxPrice': 'ಗರಿಷ್ಠ ಬೆಲೆ',
    'sortBy': 'ವಿಂಗಡಿಸಿ',
    'relevance': 'ಸಂಬಂಧ',
    'priceLowToHigh': 'ಬೆಲೆ: ಕಡಿಮೆಯಿಂದ ಹೆಚ್ಚು',
    'priceHighToLow': 'ಬೆಲೆ: ಹೆಚ್ಚಿನಿಂದ ಕಡಿಮೆ',
    'topRated': 'ಉನ್ನತ ರೇಟೆಡ್',
    'noResults': 'ಫಲಿತಾಂಶಗಳಿಲ್ಲ',
    'noResultsMessage': 'ಬೇರೆ ಪದ, ವರ್ಗ ಅಥವಾ ಬೆಲೆ ವ್ಯಾಪ್ತಿ ಪ್ರಯತ್ನಿಸಿ.',
    'tryAgain': 'ಮತ್ತೆ ಪ್ರಯತ್ನಿಸಿ',
    'loading': 'ಲೋಡ್ ಆಗುತ್ತಿದೆ...',
    'cancel': 'ರದ್ದು',
    'confirm': 'ದೃಢೀಕರಿಸಿ',
    'delete': 'ಅಳಿಸಿ',
    'done': 'ಮುಗಿಯಿತು',
    'keep': 'ಇರಿಸಿ',
    'next': 'ಮುಂದೆ',
    'skip': 'ಬಿಟ್ಟುಬಿಡಿ',
    'getStarted': 'ಪ್ರಾರಂಭಿಸಿ',
    'total': 'ಒಟ್ಟು',
    'selectDate': 'ದಿನಾಂಕ ಆಯ್ಕೆಮಾಡಿ',
    'selectTimeSlot': 'ಸಮಯ ಆಯ್ಕೆಮಾಡಿ',
    'noSlotsForDate': 'ಈ ದಿನಕ್ಕೆ ಸ್ಲಾಟ್‌ಗಳಿಲ್ಲ',
    'confirmBooking': 'ಬುಕಿಂಗ್ ದೃಢೀಕರಿಸಿ',
    'cancelBooking': 'ಬುಕಿಂಗ್ ರದ್ದು',
    'cancelBookingConfirm': 'ಈ ಬುಕಿಂಗ್ ರದ್ದು ಮಾಡಬೇಕೇ?',
    'myBookings': 'ನನ್ನ ಬುಕಿಂಗ್‌ಗಳು',
    'noBookings': 'ಇನ್ನೂ ಬುಕಿಂಗ್ ಇಲ್ಲ',
    'noBookingsMessage': 'ನೀವು ಬುಕ್ ಮಾಡಿದ ಸ್ಥಳಗಳು ಇಲ್ಲಿ ಕಾಣಿಸುತ್ತವೆ.',
    'requestRefund': 'ರಿಫಂಡ್ ವಿನಂತಿಸಿ',
    'requestRefundConfirm': 'ರಿಫಂಡ್ ವಿನಂತಿಸಬೇಕೇ?',
    'refundRequested': 'ರಿಫಂಡ್ ವಿನಂತಿ ಕಳುಹಿಸಲಾಗಿದೆ',
    'savedVenues': 'ಉಳಿಸಿದ ಸ್ಥಳಗಳು',
    'upcomingEvents': 'ಮುಂಬರುವ ಕಾರ್ಯಕ್ರಮಗಳು',
    'noUpcomingEvents': 'ಮುಂಬರುವ ಕಾರ್ಯಕ್ರಮಗಳಿಲ್ಲ',
    'noUpcomingEventsMessage': 'ಹೊಸ ವರ್ಕ್‌ಶಾಪ್‌ಗಳಿಗಾಗಿ ನಂತರ ನೋಡಿ.',
    'freeEvent': 'ಉಚಿತ',
    'seatsLeft': '{count} ಆಸನಗಳು ಉಳಿದಿವೆ',
    'durationWeeks': '{weeks} ವಾರಗಳು',
    'soldOut': 'ಮಾರಾಟವಾಗಿದೆ',
    'registered': 'ನೋಂದಾಯಿತ',
    'registerNow': 'ಈಗ ನೋಂದಾಯಿಸಿ',
    'cancelRegistration': 'ನೋಂದಣಿ ರದ್ದು',
    'cancelRegistrationConfirm': 'ಕಾರ್ಯಕ್ರಮ ನೋಂದಣಿ ರದ್ದು ಮಾಡಬೇಕೇ?',
    'registrationCancelled': 'ನೋಂದಣಿ ರದ್ದುಗೊಂಡಿದೆ',
    'noCourses': 'ಕೋರ್ಸ್‌ಗಳಿಲ್ಲ',
    'noCoursesMessage': 'ಹೊಸ ಕೋರ್ಸ್‌ಗಳು ಶೀಘ್ರದಲ್ಲೇ.',
    'courseFee': 'ಕೋರ್ಸ್ ಶುಲ್ಕ',
    'instructor': 'ಬೋಧಕ',
    'enrollInCourse': 'ಬ್ಯಾಚ್ ಆಯ್ಕೆಮಾಡಿ',
    'enrollNow': 'ಈಗ ನೋಂದಾಯಿಸಿ',
    'enrolled': 'ನೋಂದಾಯಿಸಲಾಗಿದೆ',
    'dropEnrollment': 'ತೆಗೆದುಹಾಕಿ',
    'dropEnrollmentConfirm': 'ಈ ಬ್ಯಾಚ್ ಬಿಡಬೇಕೇ?',
    'enrollmentDropped': 'ನೋಂದಣಿ ತೆಗೆದುಹಾಕಲಾಗಿದೆ',
    'batchStartsOn': 'ಪ್ರಾರಂಭ',
    'signInToEnroll': 'ನೋಂದಣಿಗೆ ಸೈನ್ ಇನ್',
    'modeOnline': 'ಆನ್‌ಲೈನ್',
    'modeOffline': 'ಆಫ್‌ಲೈನ್',
    'modeHybrid': 'ಹೈಬ್ರಿಡ್',
    'settings': 'ಸೆಟ್ಟಿಂಗ್‌ಗಳು',
    'themeMode': 'ಥೀಮ್',
    'language': 'ಭಾಷೆ',
    'support': 'ಸಹಾಯ',
    'privacyPolicy': 'ಗೌಪ್ಯತಾ ನೀತಿ',
    'termsAndConditions': 'ನಿಯಮಗಳು',
    'deleteAccount': 'ಖಾತೆ ಅಳಿಸಿ',
    'name': 'ಹೆಸರು',
    'email': 'ಇಮೇಲ್',
    'password': 'ಪಾಸ್‌ವರ್ಡ್',
    'errorInvalidEmail': 'ಸರಿಯಾದ ಇಮೇಲ್ ನಮೂದಿಸಿ',
    'signUp': 'ಸೈನ್ ಅಪ್',
    'signIn': 'ಸೈನ್ ಇನ್',
    'priority': 'ಆದ್ಯತೆ',
    'about': 'ಬಗ್ಗೆ',
    'auditLog': 'ಆಡಿಟ್ ಲಾಗ್',
    'analyticsLabel': 'ವಿಶ್ಲೇಷಣೆ',
    'ownerDashboard': 'ಮಾಲೀಕ ಡ್ಯಾಶ್‌ಬೋರ್ಡ್',
    'myVenues': 'ನನ್ನ ಸ್ಥಳಗಳು',
    'guest': 'ಅತಿಥಿ',
    'notSignedIn': 'ಸೈನ್ ಇನ್ ಆಗಿಲ್ಲ',
    'featuresHub': 'ವೈಶಿಷ್ಟ್ಯಗಳು',
    'featuresHubSubtitle':
        'ಮಾಡ್ಯೂಲ್‌ಗಳನ್ನು ಕಾನ್ಫಿಗರೇಶನ್‌ನಲ್ಲಿ ಆಫ್ ಮಾಡಬಹುದು. ಅಧಿಕಾರ ಬ್ಯಾಕೆಂಡ್ ರೋಲ್ ಮತ್ತು RLS ನಿಂದಲೇ ಬರುತ್ತದೆ.',
    'featureEnabled': 'ಈ ಬಿಲ್ಡ್‌ನಲ್ಲಿ ಲಭ್ಯ',
    'featureDisabledUntilBackend': 'ಬ್ಯಾಕೆಂಡ್ ಇಲ್ಲದ ತನಕ ನಿಷ್ಕ್ರಿಯ',
    'onLabel': 'ಆನ್',
    'offLabel': 'ಆಫ್',
    'offlineMessage':
        'ನೀವು ಆಫ್‌ಲೈನ್‌ನಲ್ಲಿರುವಂತೆ ತೋರುತ್ತಿದೆ. ಸುರಕ್ಷಿತ ಕೊನೆಯ ಡೇಟಾ ತೋರಿಸಲಾಗುತ್ತಿದೆ.',
    'bookingConfirmed': 'ಬುಕಿಂಗ್ ದೃಢೀಕೃತ',
    'awaitingConfirmation': 'ದೃಢೀಕರಣಕ್ಕಾಗಿ ಕಾಯುತ್ತಿದೆ',
    'viewBookings': 'ಬುಕಿಂಗ್‌ಗಳನ್ನು ನೋಡಿ',
    'backToHome': 'ಮುಖಪುಟಕ್ಕೆ',
    'legalName': 'ಕಾನೂನು ವ್ಯಾಪಾರ ಹೆಸರು',
    'gstin': 'GSTIN',
    'pan': 'PAN',
    'city': 'ನಗರ',
    'state': 'ರಾಜ್ಯ',
    'verificationPending': 'ಪರಿಶೀಲನೆ ಬಾಕಿ',
    'verificationSubmitted': 'ಪರಿಶೀಲನೆಗೆ ಸಲ್ಲಿಸಲಾಗಿದೆ',
    'ownerRegistrationSubtitle':
        'ಸ್ಥಳ ಮಾಲೀಕ ಖಾತೆ ರಚಿಸಿ. ಈ ಫಾರ್ಮ್ ಉಳಿಸಿದ ನಂತರ ರೋಲ್‌ಗಳು ಸಿಗುತ್ತವೆ.',
    'lightTheme': 'ಲೈಟ್',
    'darkTheme': 'ಡಾರ್ಕ್',
    'systemTheme': 'ಸಿಸ್ಟಮ್',
    'onboardingTitle1': 'ನಿಮ್ಮ ಸರಿಯಾದ ಸ್ಥಳವನ್ನು ಹುಡುಕಿ',
    'onboardingSubtitle1':
        'ಕನ್ವೆನ್ಷನ್ ಹಾಲ್, ಪಾರ್ಟಿ ಸ್ಥಳ, ಕ್ರೀಡಾಂಗಣ ಮತ್ತು ತರಗತಿ ಕೋಣೆಗಳನ್ನು ಹತ್ತಿರದಲ್ಲಿ ಕಂಡುಹಿಡಿಯಿರಿ.',
    'onboardingTitle2': 'ರಿಯಲ್-ಟೈಮ್ ಲಭ್ಯತೆ',
    'onboardingSubtitle2':
        'ತೆರೆದ ಸ್ಲಾಟ್, ಸ್ಪಷ್ಟ ಬೆಲೆ ಮತ್ತು ತಕ್ಷಣದ ಬುಕಿಂಗ್ ದೃಢೀಕರಣ.',
    'onboardingTitle3': 'ಸುಲಭ ಮತ್ತು ಸುರಕ್ಷಿತ',
    'onboardingSubtitle3':
        'ಸುರಕ್ಷಿತ ಪಾವತಿ, ತೆರಿಗೆ ಇನ್‌ವಾಯ್ಸ್ ಮತ್ತು ಸುಲಭ ಬುಕಿಂಗ್ ನಿರ್ವಹಣೆ.',
  };

  static const Map<String, String> _ta = {
    'appName': 'BookMySpace',
    'tagline': 'இடங்களை எளிதாக கண்டுபிடித்து முன்பதிவு செய்யுங்கள்',
    'navHome': 'முகப்பு',
    'navSearch': 'தேடல்',
    'navBookings': 'முன்பதிவுகள்',
    'navProfile': 'சுயவிவரம்',
    'notifications': 'அறிவிப்புகள்',
    'courses': 'பாடநெறிகள்',
    'venues': 'இடங்கள்',
    'venueDetails': 'இட விவரங்கள்',
    'aboutThisVenue': 'இந்த இடம் பற்றி',
    'amenities': 'வசதிகள்',
    'operatingHours': 'வேலை நேரம்',
    'details': 'விவரங்கள்',
    'foodOptions': 'உணவு விருப்பங்கள்',
    'parking': 'பார்க்கிங்',
    'taxRate': 'வரி விகிதம்',
    'address': 'முகவரி',
    'basePrice': 'அடிப்படை விலை',
    'capacity': 'கொள்ளளவு',
    'pricing': 'தொடக்க விலை',
    'bookNow': 'இப்போது முன்பதிவு',
    'search': 'தேடல்',
    'searchHint': 'இடங்கள், நகரங்கள் அல்லது வகைகளைத் தேடுங்கள்...',
    'filters': 'வடிகட்டிகள்',
    'clearFilters': 'வடிகட்டிகளை அழி',
    'apply': 'பயன்படுத்து',
    'close': 'மூடு',
    'back': 'பின்',
    'allCategories': 'அனைத்து வகைகள்',
    'minPrice': 'குறைந்த விலை',
    'maxPrice': 'அதிக விலை',
    'sortBy': 'வரிசை',
    'relevance': 'பொருத்தம்',
    'priceLowToHigh': 'விலை: குறைவிலிருந்து அதிகம்',
    'priceHighToLow': 'விலை: அதிகத்திலிருந்து குறைவு',
    'topRated': 'சிறந்த மதிப்பீடு',
    'noResults': 'முடிவுகள் இல்லை',
    'noResultsMessage': 'வேறு சொல், வகை அல்லது விலை வரம்பை முயற்சிக்கவும்.',
    'tryAgain': 'மீண்டும் முயல்க',
    'loading': 'ஏற்றுகிறது...',
    'cancel': 'ரத்து',
    'confirm': 'உறுதிப்படுத்து',
    'delete': 'நீக்கு',
    'done': 'முடிந்தது',
    'keep': 'வைத்திரு',
    'next': 'அடுத்து',
    'skip': 'தவிர்',
    'getStarted': 'தொடங்கு',
    'total': 'மொத்தம்',
    'selectDate': 'தேதியைத் தேர்ந்தெடு',
    'selectTimeSlot': 'நேரத்தைத் தேர்ந்தெடு',
    'noSlotsForDate': 'இந்த தேதிக்கு ஸ்லாட் இல்லை',
    'confirmBooking': 'முன்பதிவை உறுதிப்படுத்து',
    'cancelBooking': 'முன்பதிவை ரத்து செய்',
    'cancelBookingConfirm': 'இந்த முன்பதிவை ரத்து செய்யவா?',
    'myBookings': 'என் முன்பதிவுகள்',
    'noBookings': 'இன்னும் முன்பதிவு இல்லை',
    'noBookingsMessage': 'நீங்கள் முன்பதிவு செய்த இடங்கள் இங்கே தோன்றும்.',
    'requestRefund': 'பணத்தைத் திரும்பக் கேள்',
    'requestRefundConfirm': 'பணத்தைத் திரும்பக் கேட்கவா?',
    'refundRequested': 'பணத்திருப்பக் கோரிக்கை அனுப்பப்பட்டது',
    'savedVenues': 'சேமித்த இடங்கள்',
    'upcomingEvents': 'வரவிருக்கும் நிகழ்வுகள்',
    'noUpcomingEvents': 'வரவிருக்கும் நிகழ்வுகள் இல்லை',
    'noUpcomingEventsMessage': 'புதிய பட்டறைகளுக்கு பின்னர் பாருங்கள்.',
    'freeEvent': 'இலவசம்',
    'seatsLeft': '{count} இருக்கைகள் உள்ளன',
    'durationWeeks': '{weeks} வாரங்கள்',
    'soldOut': 'விற்றுத் தீர்ந்தது',
    'registered': 'பதிவு செய்யப்பட்டது',
    'registerNow': 'இப்போது பதிவு செய்',
    'cancelRegistration': 'பதிவை ரத்து செய்',
    'cancelRegistrationConfirm': 'நிகழ்வு பதிவை ரத்து செய்யவா?',
    'registrationCancelled': 'பதிவு ரத்து செய்யப்பட்டது',
    'noCourses': 'பாடநெறிகள் இல்லை',
    'noCoursesMessage': 'புதிய பாடநெறிகள் விரைவில்.',
    'courseFee': 'பாடநெறி கட்டணம்',
    'instructor': 'பயிற்றுநர்',
    'enrollInCourse': 'தொகுப்பைத் தேர்ந்தெடு',
    'enrollNow': 'இப்போது சேர்',
    'enrolled': 'சேர்க்கப்பட்டது',
    'dropEnrollment': 'நீக்கு',
    'dropEnrollmentConfirm': 'இந்த தொகுப்பை விடவா?',
    'enrollmentDropped': 'சேர்க்கை நீக்கப்பட்டது',
    'batchStartsOn': 'தொடக்கம்',
    'signInToEnroll': 'சேர உள்நுழைக',
    'modeOnline': 'ஆன்லைன்',
    'modeOffline': 'ஆஃப்லைன்',
    'modeHybrid': 'ஹைப்ரிட்',
    'settings': 'அமைப்புகள்',
    'themeMode': 'தீம்',
    'language': 'மொழி',
    'support': 'உதவி',
    'privacyPolicy': 'தனியுரிமைக் கொள்கை',
    'termsAndConditions': 'விதிமுறைகள்',
    'deleteAccount': 'கணக்கை நீக்கு',
    'name': 'பெயர்',
    'email': 'மின்னஞ்சல்',
    'password': 'கடவுச்சொல்',
    'errorInvalidEmail': 'சரியான மின்னஞ்சலை உள்ளிடவும்',
    'signUp': 'பதிவு',
    'signIn': 'உள்நுழை',
    'priority': 'முன்னுரிமை',
    'about': 'பற்றி',
    'auditLog': 'ஆடிட் பதிவு',
    'analyticsLabel': 'பகுப்பாய்வு',
    'ownerDashboard': 'உரிமையாளர் டாஷ்போர்டு',
    'myVenues': 'என் இடங்கள்',
    'guest': 'விருந்தினர்',
    'notSignedIn': 'உள்நுழையவில்லை',
    'featuresHub': 'அம்சங்கள்',
    'featuresHubSubtitle':
        'தொகுதிகளை கட்டமைப்பில் அணைக்கலாம். அங்கீகாரம் பின்புலப் பாத்திரங்கள் மற்றும் RLS இலிருந்தே வரும்.',
    'featureEnabled': 'இந்த கட்டமைப்பில் உள்ளது',
    'featureDisabledUntilBackend': 'பின்புலம் இல்லாத வரை முடக்கப்பட்டுள்ளது',
    'onLabel': 'ஆன்',
    'offLabel': 'ஆஃப்',
    'offlineMessage':
        'நீங்கள் ஆஃப்லைனில் இருப்பது போல் தெரிகிறது. பாதுகாப்பான கடைசி தரவு காட்டப்படுகிறது.',
    'bookingConfirmed': 'முன்பதிவு உறுதி',
    'awaitingConfirmation': 'உறுதிப்பாட்டிற்காக காத்திருக்கிறது',
    'viewBookings': 'முன்பதிவுகளைப் பார்',
    'backToHome': 'முகப்புக்கு',
    'legalName': 'சட்ட வணிகப் பெயர்',
    'gstin': 'GSTIN',
    'pan': 'PAN',
    'city': 'நகரம்',
    'state': 'மாநிலம்',
    'verificationPending': 'சரிபார்ப்பு நிலுவையில்',
    'verificationSubmitted': 'மதிப்பாய்வுக்கு சமர்ப்பிக்கப்பட்டது',
    'ownerRegistrationSubtitle':
        'இட உரிமையாளர் கணக்கை உருவாக்கவும். இந்த படிவம் சேமிக்கப்பட்ட பிறகு பாத்திரங்கள் வழங்கப்படும்.',
    'lightTheme': 'லைட்',
    'darkTheme': 'டார்க்',
    'systemTheme': 'சிஸ்டம்',
    'onboardingTitle1': 'உங்களுக்கான இடத்தைக் கண்டுபிடிக்கவும்',
    'onboardingSubtitle1':
        'மாநாட்டு மண்டபங்கள், விருந்து இடங்கள், விளையாட்டு மைதானங்கள் மற்றும் வகுப்பறைகளை அருகில் கண்டறியுங்கள்.',
    'onboardingTitle2': 'நேரடி கிடைக்கும் தன்மை',
    'onboardingSubtitle2':
        'திறந்த நேரங்கள், தெளிவான விலை மற்றும் உடனடி முன்பதிவு உறுதிப்பாடு.',
    'onboardingTitle3': 'எளிதானதும் பாதுகாப்பானதும்',
    'onboardingSubtitle3':
        'பாதுகாப்பான கட்டணம், வரி விலைப்பட்டியல் மற்றும் எளிய முன்பதிவு நிர்வாகம்.',
  };

  String _t(String key) {
    final lang = locale.languageCode;
    return _tables[lang]?[key] ?? _tables['en']?[key] ?? key;
  }

  String get appName => _t('appName');
  String get tagline => _t('tagline');
  String get navHome => _t('navHome');
  String get navSearch => _t('navSearch');
  String get navBookings => _t('navBookings');
  String get navProfile => _t('navProfile');
  String get notifications => _t('notifications');
  String get courses => _t('courses');
  String get venues => _t('venues');
  String get venueDetails => _t('venueDetails');
  String get aboutThisVenue => _t('aboutThisVenue');
  String get amenities => _t('amenities');
  String get operatingHours => _t('operatingHours');
  String get details => _t('details');
  String get foodOptions => _t('foodOptions');
  String get parking => _t('parking');
  String get taxRate => _t('taxRate');
  String get address => _t('address');
  String get basePrice => _t('basePrice');
  String get capacity => _t('capacity');
  String get pricing => _t('pricing');
  String get bookNow => _t('bookNow');
  String get search => _t('search');
  String get searchHint => _t('searchHint');
  String get filters => _t('filters');
  String get clearFilters => _t('clearFilters');
  String get apply => _t('apply');
  String get close => _t('close');
  String get back => _t('back');
  String get allCategories => _t('allCategories');
  String get minPrice => _t('minPrice');
  String get maxPrice => _t('maxPrice');
  String get sortBy => _t('sortBy');
  String get relevance => _t('relevance');
  String get priceLowToHigh => _t('priceLowToHigh');
  String get priceHighToLow => _t('priceHighToLow');
  String get topRated => _t('topRated');
  String get noResults => _t('noResults');
  String get noResultsMessage => _t('noResultsMessage');
  String get tryAgain => _t('tryAgain');
  String get loading => _t('loading');
  String get cancel => _t('cancel');
  String get confirm => _t('confirm');
  String get delete => _t('delete');
  String get done => _t('done');
  String get keep => _t('keep');
  String get next => _t('next');
  String get skip => _t('skip');
  String get getStarted => _t('getStarted');
  String get total => _t('total');
  String get selectDate => _t('selectDate');
  String get selectTimeSlot => _t('selectTimeSlot');
  String get noSlotsForDate => _t('noSlotsForDate');
  String get confirmBooking => _t('confirmBooking');
  String get cancelBooking => _t('cancelBooking');
  String get cancelBookingConfirm => _t('cancelBookingConfirm');
  String get myBookings => _t('myBookings');
  String get noBookings => _t('noBookings');
  String get noBookingsMessage => _t('noBookingsMessage');
  String get requestRefund => _t('requestRefund');
  String get requestRefundConfirm => _t('requestRefundConfirm');
  String get refundRequested => _t('refundRequested');
  String get savedVenues => _t('savedVenues');
  String get upcomingEvents => _t('upcomingEvents');
  String get noUpcomingEvents => _t('noUpcomingEvents');
  String get noUpcomingEventsMessage => _t('noUpcomingEventsMessage');
  String get freeEvent => _t('freeEvent');
  String get seatsLeft => _t('seatsLeft');
  String get soldOut => _t('soldOut');
  String get registered => _t('registered');
  String get registerNow => _t('registerNow');
  String get cancelRegistration => _t('cancelRegistration');
  String get cancelRegistrationConfirm => _t('cancelRegistrationConfirm');
  String get registrationCancelled => _t('registrationCancelled');
  String get noCourses => _t('noCourses');
  String get noCoursesMessage => _t('noCoursesMessage');
  String get courseFee => _t('courseFee');
  String get durationWeeks => _t('durationWeeks');
  String get instructor => _t('instructor');
  String get enrollInCourse => _t('enrollInCourse');
  String get enrollNow => _t('enrollNow');
  String get enrolled => _t('enrolled');
  String get dropEnrollment => _t('dropEnrollment');
  String get dropEnrollmentConfirm => _t('dropEnrollmentConfirm');
  String get enrollmentDropped => _t('enrollmentDropped');
  String get batchStartsOn => _t('batchStartsOn');
  String get signInToEnroll => _t('signInToEnroll');
  String get modeOnline => _t('modeOnline');
  String get modeOffline => _t('modeOffline');
  String get modeHybrid => _t('modeHybrid');
  String get settings => _t('settings');
  String get themeMode => _t('themeMode');
  String get language => _t('language');
  String get support => _t('support');
  String get privacyPolicy => _t('privacyPolicy');
  String get termsAndConditions => _t('termsAndConditions');
  String get deleteAccount => _t('deleteAccount');
  String get name => _t('name');
  String get email => _t('email');
  String get password => _t('password');
  String get errorInvalidEmail => _t('errorInvalidEmail');
  String get signUp => _t('signUp');
  String get signIn => _t('signIn');
  String get priority => _t('priority');
  String get about => _t('about');
  String get auditLog => _t('auditLog');
  String get analyticsLabel => _t('analyticsLabel');
  String get ownerDashboard => _t('ownerDashboard');
  String get myVenues => _t('myVenues');
  String get guest => _t('guest');
  String get notSignedIn => _t('notSignedIn');
  String get featuresHub => _t('featuresHub');
  String get featuresHubSubtitle => _t('featuresHubSubtitle');
  String get featureEnabled => _t('featureEnabled');
  String get featureDisabledUntilBackend => _t('featureDisabledUntilBackend');
  String get onLabel => _t('onLabel');
  String get offLabel => _t('offLabel');
  String get offlineMessage => _t('offlineMessage');
  String get bookingConfirmed => _t('bookingConfirmed');
  String get awaitingConfirmation => _t('awaitingConfirmation');
  String get viewBookings => _t('viewBookings');
  String get backToHome => _t('backToHome');
  String get legalName => _t('legalName');
  String get gstin => _t('gstin');
  String get pan => _t('pan');
  String get city => _t('city');
  String get state => _t('state');
  String get verificationPending => _t('verificationPending');
  String get verificationSubmitted => _t('verificationSubmitted');
  String get ownerRegistrationSubtitle => _t('ownerRegistrationSubtitle');
  String get lightTheme => _t('lightTheme');
  String get darkTheme => _t('darkTheme');
  String get systemTheme => _t('systemTheme');
  String get onboardingTitle1 => _t('onboardingTitle1');
  String get onboardingSubtitle1 => _t('onboardingSubtitle1');
  String get onboardingTitle2 => _t('onboardingTitle2');
  String get onboardingSubtitle2 => _t('onboardingSubtitle2');
  String get onboardingTitle3 => _t('onboardingTitle3');
  String get onboardingSubtitle3 => _t('onboardingSubtitle3');
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => AppLocalizations.supportedLocales
      .map((l) => l.languageCode)
      .contains(locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) =>
      SynchronousFuture<AppLocalizations>(AppLocalizations(locale));

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}
