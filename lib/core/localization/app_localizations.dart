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
    'navAssistant': 'Assistant',
    'homeSpotlightTitle': 'Top-rated spaces',
    'homeCategoriesTitle': 'Listed categories',
    'homeLiveRadarTitle': 'Nearest spaces',
    'homeRecentBookingsTitle': 'Your recent bookings',
    'homeWatch': 'Watch',
    'homeVideoUnavailable': 'This video could not be opened.',
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

    // --- AI booking assistant ---
    'aiAssistantTitle': 'AI booking assistant',
    'aiAssistantSubtitle': 'Ask in your own words',
    'aiInputHint': 'Try: badminton court in Hyderabad under 1000',
    'aiSend': 'Ask',
    'aiQuickTitle': 'Or tap a quick ask',
    'aiOnDeviceNote':
        'Understood on your device. Nothing is booked until you confirm.',
    'aiQuick1': 'Badminton court in Hyderabad under 1000',
    'aiQuick2': 'Marriage hall in Gachibowli under 50k',
    'aiQuick3': 'Ladies PG near Hitec City',
    'aiQuick4': 'Football turf with lights',
    'aiQuick5': 'My bookings',
    'aiQuick6': 'Clear filters',
    'aiReplyGreeting':
        'Hi! Tell me what you want to book — a sport, a hall, a PG or a class.',
    'aiReplyDiscover':
        'Here is what I understood. Tap Show results to see matching spaces.',
    'aiReplyBookNow':
        'Got it. Open the results, pick a space, then choose a date and slot.',
    'aiReplyShowBookings': 'Opening your bookings.',
    'aiReplyCancelBooking':
        'Open the booking you want to cancel, then tap Cancel booking.',
    'aiReplyClearFilters': 'Cleared everything. Showing all verified spaces.',
    'aiReplyUnrecognised':
        'I did not catch a space, city or budget. Try "function hall in Gachibowli under 50k".',
    'aiShowResults': 'Show results',
    'aiOpenBookings': 'Open my bookings',
    'aiSlotCategory': 'Category',
    'aiSlotLocation': 'Location',
    'aiSlotBudget': 'Budget',
    'aiSlotSort': 'Sort',
    'aiSlotKeyword': 'Search',
    'aiCatBadminton': 'Badminton',
    'aiCatCricket': 'Cricket',
    'aiCatFootball': 'Football turf',
    'aiCatMarriageHall': 'Marriage hall',
    'aiCatFunctionHall': 'Function hall',
    'aiCatPg': 'PG & hostel',
    'aiCatGentsPg': 'Gents PG',
    'aiCatLadiesPg': 'Ladies PG',
    'aiCatLodge': 'Lodge / rooms',
    'aiCatClasses': 'Institutes / classes',
    'aiSortPriceLowToHigh': 'Cheapest first',
    'aiSortTopRated': 'Top rated',
    'aiCityHyderabad': 'Hyderabad',
    'aiCityBangalore': 'Bangalore',
    'aiCityMumbai': 'Mumbai',
    'aiCityDelhi': 'Delhi',
    'aiCityChennai': 'Chennai',
    'aiCityPune': 'Pune',
    'aiCityKolkata': 'Kolkata',
    'adminPaymentOperations': 'Payment Operations',
    'adminPaymentHealth': 'Payment Health',
    'adminTransactionLedger': 'Transaction Ledger',
    'paymentHealthHealthy': 'Healthy',
    'paymentHealthWarning': 'Warning',
    'paymentHealthAttention': 'Attention',
    'paymentHealthCritical': 'Critical',
    'paymentHealthUnavailable': 'No data',
    'totalTransactions': 'Total Transactions',
    'capturedPayments': 'Captured',
    'pendingPayments': 'Pending',
    'failedPayments': 'Failed',
    'refundedPayments': 'Refunded',
    'paymentSuccessRate': 'Success Rate',
    'reconciliationExceptions': 'Reconciliation Exceptions',
    'webhookMissing': 'Webhook Missing',
    'readOnlyLabel': 'Read-only',
    'noTransactionsInPeriod': 'No transactions in this period',
    'noTransactionsInPeriodMessage':
        'There is no payment activity for the selected filters.',
    'searchByReferenceOrOrderId':
        'Search by booking reference, order ID or payment ID',
    'filterByStatus': 'Filter by status',
    'filterByVenue': 'Filter by venue',
    'dateRangeLabel': 'Date range',
    'paymentStatusLabel': 'Payment status',
    'bookingStatusLabel': 'Booking status',
    'approvalStatusLabel': 'Approval status',
    'webhookStatusLabel': 'Webhook status',
    'permissionDeniedAdminPayments':
        "You don't have permission to view Admin Payment Operations.",
    'adminPaymentsLoadError': 'Payment operations data could not be loaded.',
    'columnReference': 'Reference',
    'columnVenue': 'Venue',
    'columnAmount': 'Amount',
    'columnCreatedAt': 'Created',
    'adminThemeTitle': 'Theme Customizer',
    'adminThemeSubtitle':
        'Configure the global customer app theme without replacing the BookMySpace design system.',
    'adminThemeColors': 'Colors',
    'adminThemeLight': 'Light',
    'adminThemeDark': 'Dark',
    'adminThemePrimary': 'Primary color',
    'adminThemeSecondary': 'Secondary color',
    'adminThemeBackground': 'Background color',
    'adminThemeSurface': 'Surface color',
    'adminThemeText': 'Text color',
    'adminThemeCard': 'Card color',
    'adminThemeShape': 'Shape & glass',
    'adminThemeCardRadius': 'Card corner radius',
    'adminThemeButtonRadius': 'Button corner radius',
    'adminThemeInputRadius': 'Input corner radius',
    'adminThemeElevation': 'Card elevation',
    'adminThemeGlassOpacity': 'Glass opacity',
    'adminThemeGlassBorderOpacity': 'Glass border opacity',
    'adminThemeBannerStyle': 'Banner style',
    'adminThemeButtonStyle': 'Button style',
    'adminThemeLivePreview': 'Live customer preview',
    'adminThemePreviewTitle': 'Explore verified spaces',
    'adminThemePreviewSubtitle': 'Find a trusted place for your next plan.',
    'adminThemePreviewAction': 'Explore spaces',
    'adminThemeSaveDraft': 'Save draft',
    'adminThemePublish': 'Publish',
    'adminThemeResetDefault': 'Reset to default',
    'adminThemeDraft': 'Draft',
    'adminThemePublishedVersion': 'Published version',
    'adminThemeUnsaved':
        'Unsaved local changes — save the draft or publish to continue.',
    'adminThemeDraftSaved': 'Theme draft saved.',
    'adminThemePublished': 'Theme published for customers.',
    'adminThemeSaveError': 'Could not save the theme draft',
    'adminThemePublishError': 'Could not publish the theme',
    'adminThemeLoadError': 'Could not load the theme configuration',
    'adminThemeDefaultRestored':
        'Defaults restored in preview. Save the draft to keep them.',
    'adminThemeStyleGradient': 'Gradient',
    'adminThemeStyleSolid': 'Solid',
    'adminThemeStyleMinimal': 'Minimal',
    'adminThemeStyleFilled': 'Filled',
    'adminThemeStyleSoft': 'Soft',
    'adminThemeStyleOutline': 'Outline',
    'adminThemeEmpty': 'No saved theme configuration',
    'adminThemeStartWithDefaults':
        'Start with the shipped defaults, preview them, then save a draft.',
  };

  static const Map<String, String> _te = {
    'appName': 'BookMySpace',
    'tagline': 'స్థలాలను సులభంగా కనుగొని బుక్ చేయండి',
    'navHome': 'హోమ్',
    'navSearch': 'శోధన',
    'navBookings': 'బుకింగ్‌లు',
    'navProfile': 'ప్రొఫైల్',
    'navAssistant': 'సహాయకుడు',
    'homeSpotlightTitle': 'అత్యుత్తమ రేటింగ్ ఉన్న స్థలాలు',
    'homeCategoriesTitle': 'జాబితా చేసిన వర్గాలు',
    'homeLiveRadarTitle': 'సమీపంలోని స్థలాలు',
    'homeRecentBookingsTitle': 'మీ ఇటీవలి బుకింగ్‌లు',
    'homeWatch': 'వీక్షించండి',
    'homeVideoUnavailable': 'ఈ వీడియోను తెరవలేకపోయాం.',
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

    // --- AI booking assistant ---
    'aiAssistantTitle': 'AI బుకింగ్ సహాయకుడు',
    'aiAssistantSubtitle': 'మీ మాటల్లోనే అడగండి',
    'aiInputHint': 'ఉదా: హైదరాబాద్‌లో 1000 లోపు బ్యాడ్మింటన్ కోర్టు',
    'aiSend': 'అడగండి',
    'aiQuickTitle': 'లేదా త్వరిత ప్రశ్నను నొక్కండి',
    'aiOnDeviceNote':
        'మీ పరికరంలోనే అర్థం చేసుకున్నాం. మీరు నిర్ధారించే వరకు ఏదీ బుక్ కాదు.',
    'aiQuick1': 'హైదరాబాద్‌లో 1000 లోపు బ్యాడ్మింటన్ కోర్టు',
    'aiQuick2': 'గచ్చిబౌలిలో 50 వేల లోపు మ్యారేజ్ హాల్',
    'aiQuick3': 'హైటెక్ సిటీ దగ్గర లేడీస్ పీజీ',
    'aiQuick4': 'లైట్లు ఉన్న ఫుట్‌బాల్ టర్ఫ్',
    'aiQuick5': 'నా బుకింగ్‌లు',
    'aiQuick6': 'ఫిల్టర్లు తీసివేయి',
    'aiReplyGreeting':
        'నమస్తే! మీరు ఏమి బుక్ చేయాలనుకుంటున్నారో చెప్పండి — క్రీడ, హాల్, పీజీ లేదా క్లాస్.',
    'aiReplyDiscover':
        'నేను ఇలా అర్థం చేసుకున్నాను. సరిపోలే ప్రదేశాలు చూడటానికి ఫలితాలు చూడండి నొక్కండి.',
    'aiReplyBookNow':
        'సరే. ఫలితాలు తెరిచి, ప్రదేశం ఎంచుకుని, తేదీ మరియు స్లాట్ ఎంచుకోండి.',
    'aiReplyShowBookings': 'మీ బుకింగ్‌లు తెరుస్తున్నాం.',
    'aiReplyCancelBooking':
        'రద్దు చేయాలనుకున్న బుకింగ్‌ను తెరిచి, బుకింగ్ రద్దు నొక్కండి.',
    'aiReplyClearFilters':
        'అన్నీ తీసివేశాం. ధృవీకరించిన ప్రదేశాలన్నీ చూపిస్తున్నాం.',
    'aiReplyUnrecognised':
        'ప్రదేశం, నగరం లేదా బడ్జెట్ అర్థం కాలేదు. "గచ్చిబౌలిలో 50 వేల లోపు ఫంక్షన్ హాల్" ప్రయత్నించండి.',
    'aiShowResults': 'ఫలితాలు చూడండి',
    'aiOpenBookings': 'నా బుకింగ్‌లు తెరవండి',
    'aiSlotCategory': 'వర్గం',
    'aiSlotLocation': 'ప్రదేశం',
    'aiSlotBudget': 'బడ్జెట్',
    'aiSlotSort': 'క్రమం',
    'aiSlotKeyword': 'శోధన',
    'aiCatBadminton': 'బ్యాడ్మింటన్',
    'aiCatCricket': 'క్రికెట్',
    'aiCatFootball': 'ఫుట్‌బాల్ టర్ఫ్',
    'aiCatMarriageHall': 'మ్యారేజ్ హాల్',
    'aiCatFunctionHall': 'ఫంక్షన్ హాల్',
    'aiCatPg': 'పీజీ & హాస్టల్',
    'aiCatGentsPg': 'జెంట్స్ పీజీ',
    'aiCatLadiesPg': 'లేడీస్ పీజీ',
    'aiCatLodge': 'లాడ్జ్ / గదులు',
    'aiCatClasses': 'ఇన్‌స్టిట్యూట్ / క్లాసులు',
    'aiSortPriceLowToHigh': 'చౌకైనవి ముందు',
    'aiSortTopRated': 'అత్యుత్తమ రేటింగ్',
    'aiCityHyderabad': 'హైదరాబాద్',
    'aiCityBangalore': 'బెంగళూరు',
    'aiCityMumbai': 'ముంబై',
    'aiCityDelhi': 'ఢిల్లీ',
    'aiCityChennai': 'చెన్నై',
    'aiCityPune': 'పూనే',
    'aiCityKolkata': 'కోల్‌కతా',
    'adminPaymentOperations': 'పేమెంట్ ఆపరేషన్స్',
    'adminPaymentHealth': 'పేమెంట్ హెల్త్',
    'adminTransactionLedger': 'ట్రాన్సాక్షన్ లెడ్జర్',
    'paymentHealthHealthy': 'ఆరోగ్యంగా ఉంది',
    'paymentHealthWarning': 'హెచ్చరిక',
    'paymentHealthAttention': 'దృష్టి అవసరం',
    'paymentHealthCritical': 'తీవ్రమైనది',
    'paymentHealthUnavailable': 'డేటా లేదు',
    'totalTransactions': 'మొత్తం లావాదేవీలు',
    'capturedPayments': 'క్యాప్చర్ అయినవి',
    'pendingPayments': 'పెండింగ్‌లో ఉన్నవి',
    'failedPayments': 'విఫలమైనవి',
    'refundedPayments': 'రీఫండ్ చేయబడినవి',
    'paymentSuccessRate': 'విజయ శాతం',
    'reconciliationExceptions': 'సరిపోలిక మినహాయింపులు',
    'webhookMissing': 'వెబ్‌హుక్ లేదు',
    'readOnlyLabel': 'చదవడానికి మాత్రమే',
    'noTransactionsInPeriod': 'ఈ కాలంలో లావాదేవీలు లేవు',
    'noTransactionsInPeriodMessage':
        'ఎంచుకున్న ఫిల్టర్‌లకు పేమెంట్ కార్యకలాపం లేదు.',
    'searchByReferenceOrOrderId':
        'బుకింగ్ రిఫరెన్స్, ఆర్డర్ ఐడీ లేదా పేమెంట్ ఐడీ ద్వారా వెతకండి',
    'filterByStatus': 'స్థితి ద్వారా ఫిల్టర్ చేయండి',
    'filterByVenue': 'వేదిక ద్వారా ఫిల్టర్ చేయండి',
    'dateRangeLabel': 'తేదీ పరిధి',
    'paymentStatusLabel': 'పేమెంట్ స్థితి',
    'bookingStatusLabel': 'బుకింగ్ స్థితి',
    'approvalStatusLabel': 'ఆమోద స్థితి',
    'webhookStatusLabel': 'వెబ్‌హుక్ స్థితి',
    'permissionDeniedAdminPayments':
        'అడ్మిన్ పేమెంట్ ఆపరేషన్స్ చూడటానికి మీకు అనుమతి లేదు.',
    'adminPaymentsLoadError': 'పేమెంట్ ఆపరేషన్స్ డేటా లోడ్ కాలేదు.',
    'columnReference': 'రిఫరెన్స్',
    'columnVenue': 'వేదిక',
    'columnAmount': 'మొత్తం',
    'columnCreatedAt': 'సృష్టించినది',
    'adminThemeTitle': 'థీమ్ అనుకూలీకరణ',
    'adminThemeSubtitle':
        'BookMySpace డిజైన్ వ్యవస్థను మార్చకుండా కస్టమర్ యాప్ గ్లోబల్ థీమ్‌ను మార్చండి.',
    'adminThemeColors': 'రంగులు',
    'adminThemeLight': 'లైట్',
    'adminThemeDark': 'డార్క్',
    'adminThemePrimary': 'ప్రధాన రంగు',
    'adminThemeSecondary': 'ద్వితీయ రంగు',
    'adminThemeBackground': 'నేపథ్య రంగు',
    'adminThemeSurface': 'సర్ఫేస్ రంగు',
    'adminThemeText': 'టెక్స్ట్ రంగు',
    'adminThemeCard': 'కార్డ్ రంగు',
    'adminThemeShape': 'ఆకారం & గ్లాస్',
    'adminThemeCardRadius': 'కార్డ్ మూలల వ్యాసార్థం',
    'adminThemeButtonRadius': 'బటన్ మూలల వ్యాసార్థం',
    'adminThemeInputRadius': 'ఇన్‌పుట్ మూలల వ్యాసార్థం',
    'adminThemeElevation': 'కార్డ్ ఎలివేషన్',
    'adminThemeGlassOpacity': 'గ్లాస్ అపాసిటీ',
    'adminThemeGlassBorderOpacity': 'గ్లాస్ బోర్డర్ అపాసిటీ',
    'adminThemeBannerStyle': 'బ్యానర్ శైలి',
    'adminThemeButtonStyle': 'బటన్ శైలి',
    'adminThemeLivePreview': 'కస్టమర్ లైవ్ ప్రివ్యూ',
    'adminThemePreviewTitle': 'ధృవీకరించిన స్థలాలను చూడండి',
    'adminThemePreviewSubtitle':
        'మీ తదుపరి ప్రణాళికకు నమ్మకమైన స్థలాన్ని కనుగొనండి.',
    'adminThemePreviewAction': 'స్థలాలను చూడండి',
    'adminThemeSaveDraft': 'డ్రాఫ్ట్ సేవ్ చేయండి',
    'adminThemePublish': 'ప్రచురించండి',
    'adminThemeResetDefault': 'డిఫాల్ట్‌కు రీసెట్ చేయండి',
    'adminThemeDraft': 'డ్రాఫ్ట్',
    'adminThemePublishedVersion': 'ప్రచురించిన వెర్షన్',
    'adminThemeUnsaved':
        'స్థానిక మార్పులు సేవ్ కాలేదు — డ్రాఫ్ట్ సేవ్ చేయండి లేదా ప్రచురించండి.',
    'adminThemeDraftSaved': 'థీమ్ డ్రాఫ్ట్ సేవ్ చేయబడింది.',
    'adminThemePublished': 'కస్టమర్ల కోసం థీమ్ ప్రచురించబడింది.',
    'adminThemeSaveError': 'థీమ్ డ్రాఫ్ట్‌ను సేవ్ చేయలేకపోయాం',
    'adminThemePublishError': 'థీమ్‌ను ప్రచురించలేకపోయాం',
    'adminThemeLoadError': 'థీమ్ కాన్ఫిగరేషన్‌ను లోడ్ చేయలేకపోయాం',
    'adminThemeDefaultRestored':
        'ప్రివ్యూలో డిఫాల్ట్‌లు పునరుద్ధరించబడ్డాయి. వాటిని ఉంచడానికి డ్రాఫ్ట్ సేవ్ చేయండి.',
    'adminThemeStyleGradient': 'గ్రేడియంట్',
    'adminThemeStyleSolid': 'సాలిడ్',
    'adminThemeStyleMinimal': 'మినిమల్',
    'adminThemeStyleFilled': 'ఫిల్డ్',
    'adminThemeStyleSoft': 'సాఫ్ట్',
    'adminThemeStyleOutline': 'అవుట్‌లైన్',
    'adminThemeEmpty': 'సేవ్ చేసిన థీమ్ కాన్ఫిగరేషన్ లేదు',
    'adminThemeStartWithDefaults':
        'డిఫాల్ట్‌లతో ప్రారంభించి, ప్రివ్యూ చేసి, తర్వాత డ్రాఫ్ట్ సేవ్ చేయండి.',
  };

  static const Map<String, String> _hi = {
    'appName': 'BookMySpace',
    'tagline': 'जगहें खोजें और आसानी से बुक करें',
    'navHome': 'होम',
    'navSearch': 'खोज',
    'navBookings': 'बुकिंग',
    'navProfile': 'प्रोफ़ाइल',
    'navAssistant': 'सहायक',
    'homeSpotlightTitle': 'सर्वाधिक रेटेड जगहें',
    'homeCategoriesTitle': 'सूचीबद्ध श्रेणियाँ',
    'homeLiveRadarTitle': 'आस-पास की जगहें',
    'homeRecentBookingsTitle': 'आपकी हाल की बुकिंग',
    'homeWatch': 'देखें',
    'homeVideoUnavailable': 'यह वीडियो खोला नहीं जा सका।',
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
    'cancelRegistrationConfirm':
        'क्या आप कार्यक्रम पंजीकरण रद्द करना चाहते हैं?',
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

    // --- AI booking assistant ---
    'aiAssistantTitle': 'AI बुकिंग सहायक',
    'aiAssistantSubtitle': 'अपने शब्दों में पूछें',
    'aiInputHint': 'जैसे: हैदराबाद में 1000 से कम का बैडमिंटन कोर्ट',
    'aiSend': 'पूछें',
    'aiQuickTitle': 'या कोई जल्दी सवाल चुनें',
    'aiOnDeviceNote':
        'आपके डिवाइस पर ही समझा गया। पुष्टि से पहले कुछ भी बुक नहीं होता।',
    'aiQuick1': 'हैदराबाद में 1000 से कम का बैडमिंटन कोर्ट',
    'aiQuick2': 'गच्चीबोवली में 50 हज़ार से कम का मैरिज हॉल',
    'aiQuick3': 'हाईटेक सिटी के पास लेडीज़ पीजी',
    'aiQuick4': 'लाइट वाला फुटबॉल टर्फ',
    'aiQuick5': 'मेरी बुकिंग',
    'aiQuick6': 'फ़िल्टर हटाएँ',
    'aiReplyGreeting':
        'नमस्ते! बताइए आप क्या बुक करना चाहते हैं — खेल, हॉल, पीजी या क्लास।',
    'aiReplyDiscover':
        'मैंने यह समझा। मिलते-जुलते स्थान देखने के लिए परिणाम देखें दबाएँ।',
    'aiReplyBookNow':
        'ठीक है। परिणाम खोलें, स्थान चुनें, फिर तारीख और समय चुनें।',
    'aiReplyShowBookings': 'आपकी बुकिंग खोल रहे हैं।',
    'aiReplyCancelBooking':
        'जिस बुकिंग को रद्द करना है उसे खोलें, फिर बुकिंग रद्द करें दबाएँ।',
    'aiReplyClearFilters': 'सब कुछ हटा दिया। सभी सत्यापित स्थान दिखा रहे हैं।',
    'aiReplyUnrecognised':
        'मुझे स्थान, शहर या बजट समझ नहीं आया। "गच्चीबोवली में 50 हज़ार से कम का फंक्शन हॉल" आज़माएँ।',
    'aiShowResults': 'परिणाम देखें',
    'aiOpenBookings': 'मेरी बुकिंग खोलें',
    'aiSlotCategory': 'श्रेणी',
    'aiSlotLocation': 'स्थान',
    'aiSlotBudget': 'बजट',
    'aiSlotSort': 'क्रम',
    'aiSlotKeyword': 'खोज',
    'aiCatBadminton': 'बैडमिंटन',
    'aiCatCricket': 'क्रिकेट',
    'aiCatFootball': 'फुटबॉल टर्फ',
    'aiCatMarriageHall': 'मैरिज हॉल',
    'aiCatFunctionHall': 'फंक्शन हॉल',
    'aiCatPg': 'पीजी और हॉस्टल',
    'aiCatGentsPg': 'जेंट्स पीजी',
    'aiCatLadiesPg': 'लेडीज़ पीजी',
    'aiCatLodge': 'लॉज / कमरे',
    'aiCatClasses': 'इंस्टीट्यूट / क्लास',
    'aiSortPriceLowToHigh': 'सबसे सस्ता पहले',
    'aiSortTopRated': 'उच्च रेटेड',
    'aiCityHyderabad': 'हैदराबाद',
    'aiCityBangalore': 'बेंगलुरु',
    'aiCityMumbai': 'मुंबई',
    'aiCityDelhi': 'दिल्ली',
    'aiCityChennai': 'चेन्नई',
    'aiCityPune': 'पुणे',
    'aiCityKolkata': 'कोलकाता',
    'adminPaymentOperations': 'भुगतान संचालन',
    'adminPaymentHealth': 'भुगतान स्वास्थ्य',
    'adminTransactionLedger': 'लेन-देन लेजर',
    'paymentHealthHealthy': 'स्वस्थ',
    'paymentHealthWarning': 'चेतावनी',
    'paymentHealthAttention': 'ध्यान देने योग्य',
    'paymentHealthCritical': 'गंभीर',
    'paymentHealthUnavailable': 'डेटा उपलब्ध नहीं',
    'totalTransactions': 'कुल लेन-देन',
    'capturedPayments': 'कैप्चर किए गए',
    'pendingPayments': 'लंबित',
    'failedPayments': 'विफल',
    'refundedPayments': 'रिफंड किए गए',
    'paymentSuccessRate': 'सफलता दर',
    'reconciliationExceptions': 'सुलह अपवाद',
    'webhookMissing': 'वेबहुक अनुपलब्ध',
    'readOnlyLabel': 'केवल पढ़ने के लिए',
    'noTransactionsInPeriod': 'इस अवधि में कोई लेन-देन नहीं',
    'noTransactionsInPeriodMessage':
        'चयनित फ़िल्टर के लिए कोई भुगतान गतिविधि नहीं है।',
    'searchByReferenceOrOrderId':
        'बुकिंग संदर्भ, ऑर्डर आईडी या भुगतान आईडी से खोजें',
    'filterByStatus': 'स्थिति के अनुसार फ़िल्टर करें',
    'filterByVenue': 'स्थान के अनुसार फ़िल्टर करें',
    'dateRangeLabel': 'दिनांक सीमा',
    'paymentStatusLabel': 'भुगतान स्थिति',
    'bookingStatusLabel': 'बुकिंग स्थिति',
    'approvalStatusLabel': 'अनुमोदन स्थिति',
    'webhookStatusLabel': 'वेबहुक स्थिति',
    'permissionDeniedAdminPayments':
        'आपको एडमिन भुगतान संचालन देखने की अनुमति नहीं है।',
    'adminPaymentsLoadError': 'भुगतान संचालन डेटा लोड नहीं हो सका।',
    'columnReference': 'संदर्भ',
    'columnVenue': 'स्थान',
    'columnAmount': 'राशि',
    'columnCreatedAt': 'बनाया गया',
    'adminThemeTitle': 'थीम कस्टमाइज़र',
    'adminThemeSubtitle':
        'BookMySpace डिज़ाइन सिस्टम बदले बिना ग्राहक ऐप की वैश्विक थीम कॉन्फ़िगर करें।',
    'adminThemeColors': 'रंग',
    'adminThemeLight': 'लाइट',
    'adminThemeDark': 'डार्क',
    'adminThemePrimary': 'प्राथमिक रंग',
    'adminThemeSecondary': 'द्वितीयक रंग',
    'adminThemeBackground': 'पृष्ठभूमि रंग',
    'adminThemeSurface': 'सर्फेस रंग',
    'adminThemeText': 'टेक्स्ट रंग',
    'adminThemeCard': 'कार्ड रंग',
    'adminThemeShape': 'आकार और ग्लास',
    'adminThemeCardRadius': 'कार्ड कोने का रेडियस',
    'adminThemeButtonRadius': 'बटन कोने का रेडियस',
    'adminThemeInputRadius': 'इनपुट कोने का रेडियस',
    'adminThemeElevation': 'कार्ड एलिवेशन',
    'adminThemeGlassOpacity': 'ग्लास अपारदर्शिता',
    'adminThemeGlassBorderOpacity': 'ग्लास बॉर्डर अपारदर्शिता',
    'adminThemeBannerStyle': 'बैनर शैली',
    'adminThemeButtonStyle': 'बटन शैली',
    'adminThemeLivePreview': 'लाइव ग्राहक प्रीव्यू',
    'adminThemePreviewTitle': 'सत्यापित स्थान खोजें',
    'adminThemePreviewSubtitle': 'अपनी अगली योजना के लिए भरोसेमंद जगह खोजें।',
    'adminThemePreviewAction': 'स्थान देखें',
    'adminThemeSaveDraft': 'ड्राफ्ट सेव करें',
    'adminThemePublish': 'प्रकाशित करें',
    'adminThemeResetDefault': 'डिफ़ॉल्ट पर रीसेट करें',
    'adminThemeDraft': 'ड्राफ्ट',
    'adminThemePublishedVersion': 'प्रकाशित संस्करण',
    'adminThemeUnsaved':
        'स्थानीय बदलाव सेव नहीं हुए — ड्राफ्ट सेव करें या प्रकाशित करें।',
    'adminThemeDraftSaved': 'थीम ड्राफ्ट सेव हो गया।',
    'adminThemePublished': 'ग्राहकों के लिए थीम प्रकाशित हो गई।',
    'adminThemeSaveError': 'थीम ड्राफ्ट सेव नहीं हो सका',
    'adminThemePublishError': 'थीम प्रकाशित नहीं हो सकी',
    'adminThemeLoadError': 'थीम कॉन्फ़िगरेशन लोड नहीं हो सका',
    'adminThemeDefaultRestored':
        'प्रीव्यू में डिफ़ॉल्ट बहाल हुए। उन्हें रखने के लिए ड्राफ्ट सेव करें।',
    'adminThemeStyleGradient': 'ग्रेडिएंट',
    'adminThemeStyleSolid': 'सॉलिड',
    'adminThemeStyleMinimal': 'मिनिमल',
    'adminThemeStyleFilled': 'फिल्ड',
    'adminThemeStyleSoft': 'सॉफ्ट',
    'adminThemeStyleOutline': 'आउटलाइन',
    'adminThemeEmpty': 'कोई सेव की गई थीम कॉन्फ़िगरेशन नहीं',
    'adminThemeStartWithDefaults':
        'डिफ़ॉल्ट से शुरू करें, प्रीव्यू देखें और फिर ड्राफ्ट सेव करें।',
  };

  static const Map<String, String> _kn = {
    'appName': 'BookMySpace',
    'tagline': 'ಸ್ಥಳಗಳನ್ನು ಸುಲಭವಾಗಿ ಕಂಡುಹಿಡಿದು ಬುಕ್ ಮಾಡಿ',
    'navHome': 'ಮುಖಪುಟ',
    'navSearch': 'ಹುಡುಕು',
    'navBookings': 'ಬುಕಿಂಗ್‌ಗಳು',
    'navProfile': 'ಪ್ರೊಫೈಲ್',
    'navAssistant': 'ಸಹಾಯಕ',
    'homeSpotlightTitle': 'ಅತ್ಯುತ್ತಮ ರೇಟಿಂಗ್ನ ಸ್ಥಳಗಳು',
    'homeCategoriesTitle': 'ಪಟ್ಟಿ ಮಾಡಿದ ವರ್ಗಗಳು',
    'homeLiveRadarTitle': 'ಹತ್ತಿರದ ಸ್ಥಳಗಳು',
    'homeRecentBookingsTitle': 'ನಿಮ್ಮ ಇತ್ತೀಚಿನ ಬುಕಿಂಗ್‌ಗಳು',
    'homeWatch': 'ವೀಕ್ಷಿಸಿ',
    'homeVideoUnavailable': 'ಈ ವೀಡಿಯೊವನ್ನು ತೆರೆಯಲಾಗಲಿಲ್ಲ.',
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

    // --- AI booking assistant ---
    'aiAssistantTitle': 'AI ಬುಕಿಂಗ್ ಸಹಾಯಕ',
    'aiAssistantSubtitle': 'ನಿಮ್ಮ ಮಾತಿನಲ್ಲೇ ಕೇಳಿ',
    'aiInputHint': 'ಉದಾ: ಹೈದರಾಬಾದ್‌ನಲ್ಲಿ 1000 ಒಳಗೆ ಬ್ಯಾಡ್ಮಿಂಟನ್ ಕೋರ್ಟ್',
    'aiSend': 'ಕೇಳಿ',
    'aiQuickTitle': 'ಅಥವಾ ತ್ವರಿತ ಪ್ರಶ್ನೆ ಒತ್ತಿ',
    'aiOnDeviceNote':
        'ನಿಮ್ಮ ಸಾಧನದಲ್ಲೇ ಅರ್ಥ ಮಾಡಿಕೊಳ್ಳಲಾಗಿದೆ. ನೀವು ದೃಢೀಕರಿಸುವವರೆಗೆ ಏನೂ ಬುಕ್ ಆಗುವುದಿಲ್ಲ.',
    'aiQuick1': 'ಹೈದರಾಬಾದ್‌ನಲ್ಲಿ 1000 ಒಳಗೆ ಬ್ಯಾಡ್ಮಿಂಟನ್ ಕೋರ್ಟ್',
    'aiQuick2': 'ಗಚ್ಚಿಬೌಳಿಯಲ್ಲಿ 50 ಸಾವಿರ ಒಳಗೆ ಮ್ಯಾರೇಜ್ ಹಾಲ್',
    'aiQuick3': 'ಹೈಟೆಕ್ ಸಿಟಿ ಹತ್ತಿರ ಲೇಡೀಸ್ ಪಿಜಿ',
    'aiQuick4': 'ಲೈಟ್ ಇರುವ ಫುಟ್‌ಬಾಲ್ ಟರ್ಫ್',
    'aiQuick5': 'ನನ್ನ ಬುಕಿಂಗ್‌ಗಳು',
    'aiQuick6': 'ಫಿಲ್ಟರ್ ತೆರವುಗೊಳಿಸಿ',
    'aiReplyGreeting':
        'ನಮಸ್ಕಾರ! ನೀವು ಏನು ಬುಕ್ ಮಾಡಬೇಕು ಎಂದು ಹೇಳಿ — ಕ್ರೀಡೆ, ಹಾಲ್, ಪಿಜಿ ಅಥವಾ ತರಗತಿ.',
    'aiReplyDiscover':
        'ನಾನು ಹೀಗೆ ಅರ್ಥ ಮಾಡಿಕೊಂಡೆ. ಹೊಂದುವ ಸ್ಥಳಗಳನ್ನು ನೋಡಲು ಫಲಿತಾಂಶ ನೋಡಿ ಒತ್ತಿ.',
    'aiReplyBookNow':
        'ಸರಿ. ಫಲಿತಾಂಶ ತೆರೆದು, ಸ್ಥಳ ಆಯ್ಕೆಮಾಡಿ, ನಂತರ ದಿನಾಂಕ ಮತ್ತು ಸ್ಲಾಟ್ ಆಯ್ಕೆಮಾಡಿ.',
    'aiReplyShowBookings': 'ನಿಮ್ಮ ಬುಕಿಂಗ್‌ಗಳನ್ನು ತೆರೆಯುತ್ತಿದ್ದೇವೆ.',
    'aiReplyCancelBooking':
        'ರದ್ದು ಮಾಡಬೇಕಾದ ಬುಕಿಂಗ್ ತೆರೆದು, ಬುಕಿಂಗ್ ರದ್ದು ಒತ್ತಿ.',
    'aiReplyClearFilters':
        'ಎಲ್ಲವನ್ನೂ ತೆರವುಗೊಳಿಸಲಾಗಿದೆ. ಪರಿಶೀಲಿತ ಸ್ಥಳಗಳೆಲ್ಲವನ್ನೂ ತೋರಿಸುತ್ತಿದ್ದೇವೆ.',
    'aiReplyUnrecognised':
        'ಸ್ಥಳ, ನಗರ ಅಥವಾ ಬಜೆಟ್ ಅರ್ಥವಾಗಲಿಲ್ಲ. "ಗಚ್ಚಿಬೌಳಿಯಲ್ಲಿ 50 ಸಾವಿರ ಒಳಗೆ ಫಂಕ್ಷನ್ ಹಾಲ್" ಪ್ರಯತ್ನಿಸಿ.',
    'aiShowResults': 'ಫಲಿತಾಂಶ ನೋಡಿ',
    'aiOpenBookings': 'ನನ್ನ ಬುಕಿಂಗ್ ತೆರೆಯಿರಿ',
    'aiSlotCategory': 'ವರ್ಗ',
    'aiSlotLocation': 'ಸ್ಥಳ',
    'aiSlotBudget': 'ಬಜೆಟ್',
    'aiSlotSort': 'ವಿಂಗಡಣೆ',
    'aiSlotKeyword': 'ಹುಡುಕು',
    'aiCatBadminton': 'ಬ್ಯಾಡ್ಮಿಂಟನ್',
    'aiCatCricket': 'ಕ್ರಿಕೆಟ್',
    'aiCatFootball': 'ಫುಟ್‌ಬಾಲ್ ಟರ್ಫ್',
    'aiCatMarriageHall': 'ಮ್ಯಾರೇಜ್ ಹಾಲ್',
    'aiCatFunctionHall': 'ಫಂಕ್ಷನ್ ಹಾಲ್',
    'aiCatPg': 'ಪಿಜಿ ಮತ್ತು ಹಾಸ್ಟೆಲ್',
    'aiCatGentsPg': 'ಜೆಂಟ್ಸ್ ಪಿಜಿ',
    'aiCatLadiesPg': 'ಲೇಡೀಸ್ ಪಿಜಿ',
    'aiCatLodge': 'ಲಾಡ್ಜ್ / ಕೊಠಡಿ',
    'aiCatClasses': 'ಸಂಸ್ಥೆ / ತರಗತಿ',
    'aiSortPriceLowToHigh': 'ಅಗ್ಗದ್ದು ಮೊದಲು',
    'aiSortTopRated': 'ಉನ್ನತ ರೇಟೆಡ್',
    'aiCityHyderabad': 'ಹೈದರಾಬಾದ್',
    'aiCityBangalore': 'ಬೆಂಗಳೂರು',
    'aiCityMumbai': 'ಮುಂಬೈ',
    'aiCityDelhi': 'ದೆಹಲಿ',
    'aiCityChennai': 'ಚೆನ್ನೈ',
    'aiCityPune': 'ಪುಣೆ',
    'aiCityKolkata': 'ಕೋಲ್ಕತ್ತಾ',
    'adminPaymentOperations': 'ಪಾವತಿ ಕಾರ್ಯಾಚರಣೆಗಳು',
    'adminPaymentHealth': 'ಪಾವತಿ ಆರೋಗ್ಯ',
    'adminTransactionLedger': 'ವಹಿವಾಟು ಲೆಡ್ಜರ್',
    'paymentHealthHealthy': 'ಆರೋಗ್ಯಕರ',
    'paymentHealthWarning': 'ಎಚ್ಚರಿಕೆ',
    'paymentHealthAttention': 'ಗಮನ ಅಗತ್ಯ',
    'paymentHealthCritical': 'ನಿರ್ಣಾಯಕ',
    'paymentHealthUnavailable': 'ಡೇಟಾ ಲಭ್ಯವಿಲ್ಲ',
    'totalTransactions': 'ಒಟ್ಟು ವಹಿವಾಟುಗಳು',
    'capturedPayments': 'ಸೆರೆಹಿಡಿಯಲಾಗಿದೆ',
    'pendingPayments': 'ಬಾಕಿ ಇದೆ',
    'failedPayments': 'ವಿಫಲವಾಗಿದೆ',
    'refundedPayments': 'ಮರುಪಾವತಿಸಲಾಗಿದೆ',
    'paymentSuccessRate': 'ಯಶಸ್ಸಿನ ದರ',
    'reconciliationExceptions': 'ಸಮನ್ವಯ ವಿನಾಯಿತಿಗಳು',
    'webhookMissing': 'ವೆಬ್‌ಹುಕ್ ಕಾಣೆಯಾಗಿದೆ',
    'readOnlyLabel': 'ಓದಲು ಮಾತ್ರ',
    'noTransactionsInPeriod': 'ಈ ಅವಧಿಯಲ್ಲಿ ವಹಿವಾಟುಗಳಿಲ್ಲ',
    'noTransactionsInPeriodMessage':
        'ಆಯ್ಕೆಮಾಡಿದ ಫಿಲ್ಟರ್‌ಗಳಿಗೆ ಯಾವುದೇ ಪಾವತಿ ಚಟುವಟಿಕೆ ಇಲ್ಲ.',
    'searchByReferenceOrOrderId':
        'ಬುಕಿಂಗ್ ಉಲ್ಲೇಖ, ಆರ್ಡರ್ ಐಡಿ ಅಥವಾ ಪಾವತಿ ಐಡಿ ಮೂಲಕ ಹುಡುಕಿ',
    'filterByStatus': 'ಸ್ಥಿತಿಯ ಪ್ರಕಾರ ಫಿಲ್ಟರ್ ಮಾಡಿ',
    'filterByVenue': 'ಸ್ಥಳದ ಪ್ರಕಾರ ಫಿಲ್ಟರ್ ಮಾಡಿ',
    'dateRangeLabel': 'ದಿನಾಂಕ ವ್ಯಾಪ್ತಿ',
    'paymentStatusLabel': 'ಪಾವತಿ ಸ್ಥಿತಿ',
    'bookingStatusLabel': 'ಬುಕಿಂಗ್ ಸ್ಥಿತಿ',
    'approvalStatusLabel': 'ಅನುಮೋದನೆ ಸ್ಥಿತಿ',
    'webhookStatusLabel': 'ವೆಬ್‌ಹುಕ್ ಸ್ಥಿತಿ',
    'permissionDeniedAdminPayments':
        'ಅಡ್ಮಿನ್ ಪಾವತಿ ಕಾರ್ಯಾಚರಣೆಗಳನ್ನು ವೀಕ್ಷಿಸಲು ನಿಮಗೆ ಅನುಮತಿ ಇಲ್ಲ.',
    'adminPaymentsLoadError': 'ಪಾವತಿ ಕಾರ್ಯಾಚರಣೆಗಳ ಡೇಟಾ ಲೋಡ್ ಆಗಲಿಲ್ಲ.',
    'columnReference': 'ಉಲ್ಲೇಖ',
    'columnVenue': 'ಸ್ಥಳ',
    'columnAmount': 'ಮೊತ್ತ',
    'columnCreatedAt': 'ರಚಿಸಲಾಗಿದೆ',
    'adminThemeTitle': 'ಥೀಮ್ ಕಸ್ಟಮೈಸರ್',
    'adminThemeSubtitle':
        'BookMySpace ವಿನ್ಯಾಸ ವ್ಯವಸ್ಥೆಯನ್ನು ಬದಲಾಯಿಸದೆ ಗ್ರಾಹಕ ಆ್ಯಪ್‌ನ ಜಾಗತಿಕ ಥೀಮ್ ಅನ್ನು ಹೊಂದಿಸಿ.',
    'adminThemeColors': 'ಬಣ್ಣಗಳು',
    'adminThemeLight': 'ಲೈಟ್',
    'adminThemeDark': 'ಡಾರ್ಕ್',
    'adminThemePrimary': 'ಪ್ರಾಥಮಿಕ ಬಣ್ಣ',
    'adminThemeSecondary': 'ದ್ವಿತೀಯ ಬಣ್ಣ',
    'adminThemeBackground': 'ಹಿನ್ನೆಲೆ ಬಣ್ಣ',
    'adminThemeSurface': 'ಸರ್ಫೇಸ್ ಬಣ್ಣ',
    'adminThemeText': 'ಪಠ್ಯ ಬಣ್ಣ',
    'adminThemeCard': 'ಕಾರ್ಡ್ ಬಣ್ಣ',
    'adminThemeShape': 'ಆಕಾರ ಮತ್ತು ಗ್ಲಾಸ್',
    'adminThemeCardRadius': 'ಕಾರ್ಡ್ ಮೂಲೆ ರೇಡಿಯಸ್',
    'adminThemeButtonRadius': 'ಬಟನ್ ಮೂಲೆ ರೇಡಿಯಸ್',
    'adminThemeInputRadius': 'ಇನ್‌ಪುಟ್ ಮೂಲೆ ರೇಡಿಯಸ್',
    'adminThemeElevation': 'ಕಾರ್ಡ್ ಎಲಿವೇಶನ್',
    'adminThemeGlassOpacity': 'ಗ್ಲಾಸ್ ಅಪಾಸಿಟಿ',
    'adminThemeGlassBorderOpacity': 'ಗ್ಲಾಸ್ ಬಾರ್ಡರ್ ಅಪಾಸಿಟಿ',
    'adminThemeBannerStyle': 'ಬ್ಯಾನರ್ ಶೈಲಿ',
    'adminThemeButtonStyle': 'ಬಟನ್ ಶೈಲಿ',
    'adminThemeLivePreview': 'ಲೈವ್ ಗ್ರಾಹಕ ಪೂರ್ವವೀಕ್ಷಣೆ',
    'adminThemePreviewTitle': 'ಪರಿಶೀಲಿತ ಸ್ಥಳಗಳನ್ನು ಕಂಡುಹಿಡಿಯಿರಿ',
    'adminThemePreviewSubtitle':
        'ನಿಮ್ಮ ಮುಂದಿನ ಯೋಜನೆಗೆ ನಂಬಲರ್ಹ ಸ್ಥಳವನ್ನು ಹುಡುಕಿ.',
    'adminThemePreviewAction': 'ಸ್ಥಳಗಳನ್ನು ವೀಕ್ಷಿಸಿ',
    'adminThemeSaveDraft': 'ಡ್ರಾಫ್ಟ್ ಉಳಿಸಿ',
    'adminThemePublish': 'ಪ್ರಕಟಿಸಿ',
    'adminThemeResetDefault': 'ಡೀಫಾಲ್ಟ್‌ಗೆ ಮರುಹೊಂದಿಸಿ',
    'adminThemeDraft': 'ಡ್ರಾಫ್ಟ್',
    'adminThemePublishedVersion': 'ಪ್ರಕಟಿತ ಆವೃತ್ತಿ',
    'adminThemeUnsaved':
        'ಉಳಿಸದ ಸ್ಥಳೀಯ ಬದಲಾವಣೆಗಳು — ಡ್ರಾಫ್ಟ್ ಉಳಿಸಿ ಅಥವಾ ಪ್ರಕಟಿಸಿ.',
    'adminThemeDraftSaved': 'ಥೀಮ್ ಡ್ರಾಫ್ಟ್ ಉಳಿಸಲಾಗಿದೆ.',
    'adminThemePublished': 'ಗ್ರಾಹಕರಿಗಾಗಿ ಥೀಮ್ ಪ್ರಕಟಿಸಲಾಗಿದೆ.',
    'adminThemeSaveError': 'ಥೀಮ್ ಡ್ರಾಫ್ಟ್ ಉಳಿಸಲಾಗಲಿಲ್ಲ',
    'adminThemePublishError': 'ಥೀಮ್ ಪ್ರಕಟಿಸಲಾಗಲಿಲ್ಲ',
    'adminThemeLoadError': 'ಥೀಮ್ ಕಾನ್ಫಿಗರೇಶನ್ ಲೋಡ್ ಮಾಡಲಾಗಲಿಲ್ಲ',
    'adminThemeDefaultRestored':
        'ಪೂರ್ವವೀಕ್ಷಣೆಯಲ್ಲಿ ಡೀಫಾಲ್ಟ್‌ಗಳನ್ನು ಮರುಸ್ಥಾಪಿಸಲಾಗಿದೆ. ಉಳಿಸಲು ಡ್ರಾಫ್ಟ್ ಉಳಿಸಿ.',
    'adminThemeStyleGradient': 'ಗ್ರೇಡಿಯಂಟ್',
    'adminThemeStyleSolid': 'ಸಾಲಿಡ್',
    'adminThemeStyleMinimal': 'ಮಿನಿಮಲ್',
    'adminThemeStyleFilled': 'ಫಿಲ್ಡ್',
    'adminThemeStyleSoft': 'ಸಾಫ್ಟ್',
    'adminThemeStyleOutline': 'ಔಟ್‌ಲೈನ್',
    'adminThemeEmpty': 'ಉಳಿಸಿದ ಥೀಮ್ ಕಾನ್ಫಿಗರೇಶನ್ ಇಲ್ಲ',
    'adminThemeStartWithDefaults':
        'ಡೀಫಾಲ್ಟ್‌ಗಳಿಂದ ಪ್ರಾರಂಭಿಸಿ, ಪೂರ್ವವೀಕ್ಷಿಸಿ, ನಂತರ ಡ್ರಾಫ್ಟ್ ಉಳಿಸಿ.',
  };

  static const Map<String, String> _ta = {
    'appName': 'BookMySpace',
    'tagline': 'இடங்களை எளிதாக கண்டுபிடித்து முன்பதிவு செய்யுங்கள்',
    'navHome': 'முகப்பு',
    'navSearch': 'தேடல்',
    'navBookings': 'முன்பதிவுகள்',
    'navProfile': 'சுயவிவரம்',
    'navAssistant': 'உதவியாளர்',
    'homeSpotlightTitle': 'சிறந்த மதிப்பீட்டு இடங்கள்',
    'homeCategoriesTitle': 'பட்டியலிடப்பட்ட பிரிவுகள்',
    'homeLiveRadarTitle': 'அருகிலுள்ள இடங்கள்',
    'homeRecentBookingsTitle': 'உங்கள் சமீபத்திய முன்பதிவுகள்',
    'homeWatch': 'பார்க்க',
    'homeVideoUnavailable': 'இந்த வீடியோவைத் திறக்க முடியவில்லை.',
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

    // --- AI booking assistant ---
    'aiAssistantTitle': 'AI முன்பதிவு உதவியாளர்',
    'aiAssistantSubtitle': 'உங்கள் வார்த்தைகளில் கேளுங்கள்',
    'aiInputHint': 'எ.கா: ஹைதராபாத்தில் 1000க்கு உள்ளே பேட்மிண்டன் கோர்ட்',
    'aiSend': 'கேள்',
    'aiQuickTitle': 'அல்லது விரைவு கேள்வியைத் தட்டுங்கள்',
    'aiOnDeviceNote':
        'உங்கள் சாதனத்திலேயே புரிந்துகொள்ளப்பட்டது. நீங்கள் உறுதிப்படுத்தும் வரை எதுவும் முன்பதிவு ஆகாது.',
    'aiQuick1': 'ஹைதராபாத்தில் 1000க்கு உள்ளே பேட்மிண்டன் கோர்ட்',
    'aiQuick2': 'கச்சிபவுலியில் 50 ஆயிரத்திற்கு உள்ளே திருமண மண்டபம்',
    'aiQuick3': 'ஹைடெக் சிட்டி அருகில் மகளிர் விடுதி',
    'aiQuick4': 'விளக்குகளுடன் கால்பந்து மைதானம்',
    'aiQuick5': 'என் முன்பதிவுகள்',
    'aiQuick6': 'வடிகட்டிகளை அழி',
    'aiReplyGreeting':
        'வணக்கம்! நீங்கள் என்ன முன்பதிவு செய்ய விரும்புகிறீர்கள் — விளையாட்டு, மண்டபம், விடுதி அல்லது வகுப்பு.',
    'aiReplyDiscover':
        'நான் இப்படிப் புரிந்துகொண்டேன். பொருந்தும் இடங்களைப் பார்க்க முடிவுகளைப் பார் தட்டுங்கள்.',
    'aiReplyBookNow':
        'சரி. முடிவுகளைத் திறந்து, இடத்தைத் தேர்ந்தெடுத்து, பிறகு தேதி மற்றும் நேரத்தைத் தேர்ந்தெடுங்கள்.',
    'aiReplyShowBookings': 'உங்கள் முன்பதிவுகளைத் திறக்கிறோம்.',
    'aiReplyCancelBooking':
        'ரத்து செய்ய வேண்டிய முன்பதிவைத் திறந்து, முன்பதிவை ரத்து செய் தட்டுங்கள்.',
    'aiReplyClearFilters':
        'எல்லாவற்றையும் அழித்துவிட்டோம். சரிபார்க்கப்பட்ட இடங்களைக் காட்டுகிறோம்.',
    'aiReplyUnrecognised':
        'இடம், நகரம் அல்லது பட்ஜெட் புரியவில்லை. "கச்சிபவுலியில் 50 ஆயிரத்திற்கு உள்ளே விழா மண்டபம்" முயற்சிக்கவும்.',
    'aiShowResults': 'முடிவுகளைப் பார்',
    'aiOpenBookings': 'என் முன்பதிவுகளைத் திற',
    'aiSlotCategory': 'வகை',
    'aiSlotLocation': 'இடம்',
    'aiSlotBudget': 'பட்ஜெட்',
    'aiSlotSort': 'வரிசை',
    'aiSlotKeyword': 'தேடல்',
    'aiCatBadminton': 'பேட்மிண்டன்',
    'aiCatCricket': 'கிரிக்கெட்',
    'aiCatFootball': 'கால்பந்து மைதானம்',
    'aiCatMarriageHall': 'திருமண மண்டபம்',
    'aiCatFunctionHall': 'விழா மண்டபம்',
    'aiCatPg': 'விடுதி & தங்கும் விடுதி',
    'aiCatGentsPg': 'ஆண்கள் விடுதி',
    'aiCatLadiesPg': 'மகளிர் விடுதி',
    'aiCatLodge': 'தங்கும் விடுதி / அறைகள்',
    'aiCatClasses': 'நிறுவனம் / வகுப்புகள்',
    'aiSortPriceLowToHigh': 'மலிவானது முதலில்',
    'aiSortTopRated': 'சிறந்த மதிப்பீடு',
    'aiCityHyderabad': 'ஹைதராபாத்',
    'aiCityBangalore': 'பெங்களூரு',
    'aiCityMumbai': 'மும்பை',
    'aiCityDelhi': 'டெல்லி',
    'aiCityChennai': 'சென்னை',
    'aiCityPune': 'புனே',
    'aiCityKolkata': 'கொல்கத்தா',
    'adminPaymentOperations': 'கட்டண செயல்பாடுகள்',
    'adminPaymentHealth': 'கட்டண ஆரோக்கியம்',
    'adminTransactionLedger': 'பரிவர்த்தனை பேரேடு',
    'paymentHealthHealthy': 'ஆரோக்கியமானது',
    'paymentHealthWarning': 'எச்சரிக்கை',
    'paymentHealthAttention': 'கவனம் தேவை',
    'paymentHealthCritical': 'மிக முக்கியமானது',
    'paymentHealthUnavailable': 'தரவு இல்லை',
    'totalTransactions': 'மொத்த பரிவர்த்தனைகள்',
    'capturedPayments': 'பிடிக்கப்பட்டவை',
    'pendingPayments': 'நிலுவையில் உள்ளவை',
    'failedPayments': 'தோல்வியடைந்தவை',
    'refundedPayments': 'திரும்பப் பெறப்பட்டவை',
    'paymentSuccessRate': 'வெற்றி விகிதம்',
    'reconciliationExceptions': 'சமரசம் விதிவிலக்குகள்',
    'webhookMissing': 'வெப்ஹுக் இல்லை',
    'readOnlyLabel': 'படிக்க மட்டும்',
    'noTransactionsInPeriod': 'இந்த காலகட்டத்தில் பரிவர்த்தனைகள் இல்லை',
    'noTransactionsInPeriodMessage':
        'தேர்ந்தெடுக்கப்பட்ட வடிப்பான்களுக்கு கட்டண செயல்பாடு இல்லை.',
    'searchByReferenceOrOrderId':
        'முன்பதிவு குறிப்பு, ஆர்டர் ஐடி அல்லது கட்டண ஐடி மூலம் தேடுங்கள்',
    'filterByStatus': 'நிலையின் அடிப்படையில் வடிகட்டவும்',
    'filterByVenue': 'இடத்தின் அடிப்படையில் வடிகட்டவும்',
    'dateRangeLabel': 'தேதி வரம்பு',
    'paymentStatusLabel': 'கட்டண நிலை',
    'bookingStatusLabel': 'முன்பதிவு நிலை',
    'approvalStatusLabel': 'ஒப்புதல் நிலை',
    'webhookStatusLabel': 'வெப்ஹுக் நிலை',
    'permissionDeniedAdminPayments':
        'நிர்வாக கட்டண செயல்பாடுகளை பார்க்க உங்களுக்கு அனுமதி இல்லை.',
    'adminPaymentsLoadError': 'கட்டண செயல்பாடு தரவை ஏற்ற முடியவில்லை.',
    'columnReference': 'குறிப்பு',
    'columnVenue': 'இடம்',
    'columnAmount': 'தொகை',
    'columnCreatedAt': 'உருவாக்கப்பட்டது',
    'adminThemeTitle': 'தீம் தனிப்பயனாக்கி',
    'adminThemeSubtitle':
        'BookMySpace வடிவமைப்பு அமைப்பை மாற்றாமல் வாடிக்கையாளர் பயன்பாட்டின் உலகளாவிய தீமை அமைக்கவும்.',
    'adminThemeColors': 'நிறங்கள்',
    'adminThemeLight': 'வெளிச்சம்',
    'adminThemeDark': 'இருள்',
    'adminThemePrimary': 'முதன்மை நிறம்',
    'adminThemeSecondary': 'இரண்டாம் நிலை நிறம்',
    'adminThemeBackground': 'பின்னணி நிறம்',
    'adminThemeSurface': 'சர்ஃபேஸ் நிறம்',
    'adminThemeText': 'உரை நிறம்',
    'adminThemeCard': 'கார்டு நிறம்',
    'adminThemeShape': 'வடிவம் & கிளாஸ்',
    'adminThemeCardRadius': 'கார்டு மூலை ஆரம்',
    'adminThemeButtonRadius': 'பட்டன் மூலை ஆரம்',
    'adminThemeInputRadius': 'உள்ளீட்டு மூலை ஆரம்',
    'adminThemeElevation': 'கார்டு உயர்வு',
    'adminThemeGlassOpacity': 'கிளாஸ் ஒளிபுகாநிலை',
    'adminThemeGlassBorderOpacity': 'கிளாஸ் பார்டர் ஒளிபுகாநிலை',
    'adminThemeBannerStyle': 'பேனர் பாணி',
    'adminThemeButtonStyle': 'பட்டன் பாணி',
    'adminThemeLivePreview': 'நேரடி வாடிக்கையாளர் முன்னோட்டம்',
    'adminThemePreviewTitle': 'சரிபார்க்கப்பட்ட இடங்களைத் தேடுங்கள்',
    'adminThemePreviewSubtitle':
        'உங்கள் அடுத்த திட்டத்திற்கு நம்பகமான இடத்தைக் கண்டறியுங்கள்.',
    'adminThemePreviewAction': 'இடங்களைப் பார்',
    'adminThemeSaveDraft': 'வரைவைச் சேமி',
    'adminThemePublish': 'வெளியிடு',
    'adminThemeResetDefault': 'இயல்புநிலைக்கு மீட்டமை',
    'adminThemeDraft': 'வரைவு',
    'adminThemePublishedVersion': 'வெளியிடப்பட்ட பதிப்பு',
    'adminThemeUnsaved':
        'சேமிக்கப்படாத உள்ளூர் மாற்றங்கள் — வரைவைச் சேமிக்கவும் அல்லது வெளியிடவும்.',
    'adminThemeDraftSaved': 'தீம் வரைவு சேமிக்கப்பட்டது.',
    'adminThemePublished': 'வாடிக்கையாளர்களுக்கான தீம் வெளியிடப்பட்டது.',
    'adminThemeSaveError': 'தீம் வரைவைச் சேமிக்க முடியவில்லை',
    'adminThemePublishError': 'தீமை வெளியிட முடியவில்லை',
    'adminThemeLoadError': 'தீம் அமைப்பை ஏற்ற முடியவில்லை',
    'adminThemeDefaultRestored':
        'முன்னோட்டத்தில் இயல்புநிலைகள் மீட்டமைக்கப்பட்டன. வைத்திருக்க வரைவைச் சேமிக்கவும்.',
    'adminThemeStyleGradient': 'கிரேடியண்ட்',
    'adminThemeStyleSolid': 'சாலிட்',
    'adminThemeStyleMinimal': 'மினிமல்',
    'adminThemeStyleFilled': 'நிரப்பப்பட்டது',
    'adminThemeStyleSoft': 'மென்மையானது',
    'adminThemeStyleOutline': 'அவுட்லைன்',
    'adminThemeEmpty': 'சேமிக்கப்பட்ட தீம் அமைப்பு இல்லை',
    'adminThemeStartWithDefaults':
        'இயல்புநிலைகளில் தொடங்கி, முன்னோட்டம் பார்த்து, பின்னர் வரைவைச் சேமிக்கவும்.',
  };

  String get adminPaymentOperations => _t('adminPaymentOperations');
  String get adminPaymentHealth => _t('adminPaymentHealth');
  String get adminTransactionLedger => _t('adminTransactionLedger');
  String get paymentHealthHealthy => _t('paymentHealthHealthy');
  String get paymentHealthWarning => _t('paymentHealthWarning');
  String get paymentHealthAttention => _t('paymentHealthAttention');
  String get paymentHealthCritical => _t('paymentHealthCritical');
  String get paymentHealthUnavailable => _t('paymentHealthUnavailable');
  String get totalTransactions => _t('totalTransactions');
  String get capturedPayments => _t('capturedPayments');
  String get pendingPayments => _t('pendingPayments');
  String get failedPayments => _t('failedPayments');
  String get refundedPayments => _t('refundedPayments');
  String get paymentSuccessRate => _t('paymentSuccessRate');
  String get reconciliationExceptions => _t('reconciliationExceptions');
  String get webhookMissing => _t('webhookMissing');
  String get readOnlyLabel => _t('readOnlyLabel');
  String get noTransactionsInPeriod => _t('noTransactionsInPeriod');
  String get noTransactionsInPeriodMessage =>
      _t('noTransactionsInPeriodMessage');
  String get searchByReferenceOrOrderId => _t('searchByReferenceOrOrderId');
  String get filterByStatus => _t('filterByStatus');
  String get filterByVenue => _t('filterByVenue');
  String get dateRangeLabel => _t('dateRangeLabel');
  String get paymentStatusLabel => _t('paymentStatusLabel');
  String get bookingStatusLabel => _t('bookingStatusLabel');
  String get approvalStatusLabel => _t('approvalStatusLabel');
  String get webhookStatusLabel => _t('webhookStatusLabel');
  String get permissionDeniedAdminPayments =>
      _t('permissionDeniedAdminPayments');
  String get adminPaymentsLoadError => _t('adminPaymentsLoadError');
  String get columnReference => _t('columnReference');
  String get columnVenue => _t('columnVenue');
  String get columnAmount => _t('columnAmount');
  String get columnCreatedAt => _t('columnCreatedAt');
  String get adminThemeTitle => _t('adminThemeTitle');
  String get adminThemeSubtitle => _t('adminThemeSubtitle');
  String get adminThemeColors => _t('adminThemeColors');
  String get adminThemeLight => _t('adminThemeLight');
  String get adminThemeDark => _t('adminThemeDark');
  String get adminThemePrimary => _t('adminThemePrimary');
  String get adminThemeSecondary => _t('adminThemeSecondary');
  String get adminThemeBackground => _t('adminThemeBackground');
  String get adminThemeSurface => _t('adminThemeSurface');
  String get adminThemeText => _t('adminThemeText');
  String get adminThemeCard => _t('adminThemeCard');
  String get adminThemeShape => _t('adminThemeShape');
  String get adminThemeCardRadius => _t('adminThemeCardRadius');
  String get adminThemeButtonRadius => _t('adminThemeButtonRadius');
  String get adminThemeInputRadius => _t('adminThemeInputRadius');
  String get adminThemeElevation => _t('adminThemeElevation');
  String get adminThemeGlassOpacity => _t('adminThemeGlassOpacity');
  String get adminThemeGlassBorderOpacity => _t('adminThemeGlassBorderOpacity');
  String get adminThemeBannerStyle => _t('adminThemeBannerStyle');
  String get adminThemeButtonStyle => _t('adminThemeButtonStyle');
  String get adminThemeLivePreview => _t('adminThemeLivePreview');
  String get adminThemePreviewTitle => _t('adminThemePreviewTitle');
  String get adminThemePreviewSubtitle => _t('adminThemePreviewSubtitle');
  String get adminThemePreviewAction => _t('adminThemePreviewAction');
  String get adminThemeSaveDraft => _t('adminThemeSaveDraft');
  String get adminThemePublish => _t('adminThemePublish');
  String get adminThemeResetDefault => _t('adminThemeResetDefault');
  String get adminThemeDraft => _t('adminThemeDraft');
  String get adminThemePublishedVersion => _t('adminThemePublishedVersion');
  String get adminThemeUnsaved => _t('adminThemeUnsaved');
  String get adminThemeDraftSaved => _t('adminThemeDraftSaved');
  String get adminThemePublished => _t('adminThemePublished');
  String get adminThemeSaveError => _t('adminThemeSaveError');
  String get adminThemePublishError => _t('adminThemePublishError');
  String get adminThemeLoadError => _t('adminThemeLoadError');
  String get adminThemeDefaultRestored => _t('adminThemeDefaultRestored');
  String get adminThemeStyleGradient => _t('adminThemeStyleGradient');
  String get adminThemeStyleSolid => _t('adminThemeStyleSolid');
  String get adminThemeStyleMinimal => _t('adminThemeStyleMinimal');
  String get adminThemeStyleFilled => _t('adminThemeStyleFilled');
  String get adminThemeStyleSoft => _t('adminThemeStyleSoft');
  String get adminThemeStyleOutline => _t('adminThemeStyleOutline');
  String get adminThemeEmpty => _t('adminThemeEmpty');
  String get adminThemeStartWithDefaults => _t('adminThemeStartWithDefaults');
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
  String get navAssistant => _t('navAssistant');

  // --- Home section defaults ---
  // Used when an admin leaves a section title empty, so the shipped Home reads
  // correctly in every language instead of falling back to English.
  String get homeSpotlightTitle => _t('homeSpotlightTitle');
  String get homeCategoriesTitle => _t('homeCategoriesTitle');
  String get homeLiveRadarTitle => _t('homeLiveRadarTitle');
  String get homeRecentBookingsTitle => _t('homeRecentBookingsTitle');
  String get homeWatch => _t('homeWatch');
  String get homeVideoUnavailable => _t('homeVideoUnavailable');
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

  // --- AI booking assistant ---
  String get aiAssistantTitle => _t('aiAssistantTitle');
  String get aiAssistantSubtitle => _t('aiAssistantSubtitle');
  String get aiInputHint => _t('aiInputHint');
  String get aiSend => _t('aiSend');
  String get aiQuickTitle => _t('aiQuickTitle');
  String get aiOnDeviceNote => _t('aiOnDeviceNote');
  String get aiReplyGreeting => _t('aiReplyGreeting');
  String get aiShowResults => _t('aiShowResults');
  String get aiOpenBookings => _t('aiOpenBookings');
  String get aiSlotCategory => _t('aiSlotCategory');
  String get aiSlotLocation => _t('aiSlotLocation');
  String get aiSlotBudget => _t('aiSlotBudget');
  String get aiSlotSort => _t('aiSlotSort');
  String get aiSlotKeyword => _t('aiSlotKeyword');

  /// Resolves an assistant reply, chip or suggestion key by name.
  ///
  /// The intent engine works in keys so it stays free of Flutter and of any
  /// single language; the UI resolves them here.
  String aiText(String key) => _t(key);

  /// The canonical English text for a key.
  ///
  /// Assistant suggestion chips are *displayed* in the active language but must
  /// be *submitted* in the vocabulary the deterministic parser understands, so
  /// the visible label and the value sent back are looked up separately.
  static String english(String key) => _en[key] ?? key;
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
