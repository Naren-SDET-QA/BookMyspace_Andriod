import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Localization keys for BookMySpace.
///
/// Supported locales: English, Telugu, Hindi, Tamil, Kannada, Marathi,
/// Bengali, Gujarati, Malayalam, Spanish. Missing keys fall back to English.
class AppLocalizations {
  AppLocalizations(this.locale);

  final Locale locale;

  static const List<Locale> supportedLocales = [
    Locale('en'),
    Locale('te'),
    Locale('hi'),
    Locale('ta'),
    Locale('kn'),
    Locale('mr'),
    Locale('bn'),
    Locale('gu'),
    Locale('ml'),
    Locale('es'),
  ];

  static String languageLabel(Locale locale) => switch (locale.languageCode) {
    'en' => 'English',
    'te' => 'తెలుగు',
    'hi' => 'हिन्दी',
    'ta' => 'தமிழ்',
    'kn' => 'ಕನ್ನಡ',
    'mr' => 'मराठी',
    'bn' => 'বাংলা',
    'gu' => 'ગુજરાતી',
    'ml' => 'മലയാളം',
    'es' => 'Español',
    _ => locale.languageCode,
  };

  /// Resolves [locale] onto a supported language, falling back to English.
  static Locale resolve(Locale? locale) {
    if (locale == null) return supportedLocales.first;
    for (final supported in supportedLocales) {
      if (supported.languageCode == locale.languageCode) return supported;
    }
    return supportedLocales.first;
  }

  static AppLocalizations of(BuildContext context) {
    final l10n = Localizations.of<AppLocalizations>(context, AppLocalizations);
    return l10n ?? AppLocalizations(const Locale('en'));
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();


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
    'courseSearchHint': 'Search courses or institutes...',
    'seeAll': 'See all',
    'linkCopied': 'Link copied to clipboard',
    'share': 'Share',
    'downloadBrochure': 'Download brochure',
    'whatYouLearn': 'What you\'ll learn',
    'faq': 'Frequently asked questions',
    'off': 'OFF',
    'featuredInstitutes': 'Featured Institutes',
    'popularCourses': 'Popular Courses',
    'upcomingBatches': 'Upcoming Batches',
    'watchDemoClass': 'Watch Demo Class',
    'typeAllInstitutes': 'All',
    'typePrivate': 'Private',
    'typeStateGovernment': 'State Government',
    'typeCentralGovernment': 'Central Government',
    'typeUniversity': 'University',
    'typeNgo': 'NGO',
    'typeOther': 'Other',
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
    'filterAllCourses': 'All',
    'home3dEffects': 'Color & 3D effects',
    'home3dEffectsSubtitle': 'Depth and color effects on Home spotlight cards',
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

    // Education / institutes
    'education': 'Education',
    'institutes': 'Institutes',
    'noInstitutes': 'No institutes yet',
    'noInstitutesMessage': 'Institutes and courses are coming soon.',
    'instituteDetails': 'Institute Details',
    'coursesByInstitute': 'Courses offered',
    'aboutInstitute': 'About',
    'faculty': 'Faculty',
    'contactInstitute': 'Contact Institute',
    'location': 'Location',
    'timings': 'Timings',
    'viewOnMap': 'View on map',
    'myCourses': 'My Courses',
    'noMyCourses': 'No enrollments yet',
    'noMyCoursesMessage':
        'Courses you enroll in will appear here with batch and invoice details.',
    'discount': 'Discount',
    'totalPayable': 'Total payable',
    'feeBreakdown': 'Fee breakdown',
    'demoAndRegistration': 'Demo & registration',
    'registerForDemo': 'Register for Demo',
    'demoRequestSubmitted': 'Demo request submitted.',
    'studentName': 'Student name',
    'mobileNumber': 'Mobile number',
    'preferredBatch': 'Preferred batch',
    'note': 'Note',
    'submit': 'Submit',
    'feedback': 'Feedback',
    'noFeedback': 'No feedback yet',
    'writeFeedback': 'Write feedback',
    'feedbackSubmitted': 'Thanks for your feedback.',
    'yourRating': 'Your rating',
    'invoice': 'Invoice',
    'viewInvoice': 'View invoice',
    'invoiceNumber': 'Invoice',
    'issuedOn': 'Issued on',
    'netAmount': 'Net amount',
    'educationUnavailable': 'Education is unavailable',
    'educationUnavailableMessage':
        'This optional module is currently disabled by the administrator.',

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
    'courseSearchHint': 'కోర్సులు లేదా సంస్థలను వెతకండి...',
    'seeAll': 'అన్నీ చూడండి',
    'linkCopied': 'లింక్ కాపీ చేయబడింది',
    'share': 'షేర్ చేయండి',
    'downloadBrochure': 'బ్రోచర్ డౌన్‌లోడ్ చేయండి',
    'whatYouLearn': 'మీరు నేర్చుకునేవి',
    'faq': 'తరచుగా అడిగే ప్రశ్నలు',
    'off': 'తగ్గింపు',
    'featuredInstitutes': 'ప్రత్యేక సంస్థలు',
    'popularCourses': 'ప్రసిద్ధ కోర్సులు',
    'upcomingBatches': 'రాబోయే బ్యాచ్‌లు',
    'watchDemoClass': 'డెమో క్లాస్ చూడండి',
    'typeAllInstitutes': 'అన్నీ',
    'typePrivate': 'ప్రైవేట్',
    'typeStateGovernment': 'రాష్ట్ర ప్రభుత్వం',
    'typeCentralGovernment': 'కేంద్ర ప్రభుత్వం',
    'typeUniversity': 'విశ్వవిద్యాలయం',
    'typeNgo': 'ఎన్జీవో',
    'typeOther': 'ఇతర',
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
    'filterAllCourses': 'అన్నీ',
    'home3dEffects': 'రంగు & 3D ప్రభావాలు',
    'home3dEffectsSubtitle':
        'హోమ్ స్పాట్‌లైట్ కార్డులపై లోతు మరియు రంగు ప్రభావాలు',
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
    'courseSearchHint': 'कोर्स या संस्थान खोजें...',
    'seeAll': 'सभी देखें',
    'linkCopied': 'लिंक कॉपी हो गया',
    'share': 'शेयर करें',
    'downloadBrochure': 'ब्रोशर डाउनलोड करें',
    'whatYouLearn': 'आप क्या सीखेंगे',
    'faq': 'अक्सर पूछे जाने वाले प्रश्न',
    'off': 'छूट',
    'featuredInstitutes': 'प्रमुख संस्थान',
    'popularCourses': 'लोकप्रिय कोर्स',
    'upcomingBatches': 'आगामी बैच',
    'watchDemoClass': 'डेमो क्लास देखें',
    'typeAllInstitutes': 'सभी',
    'typePrivate': 'निजी',
    'typeStateGovernment': 'राज्य सरकार',
    'typeCentralGovernment': 'केंद्र सरकार',
    'typeUniversity': 'विश्वविद्यालय',
    'typeNgo': 'एनजीओ',
    'typeOther': 'अन्य',
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
    'filterAllCourses': 'सभी',
    'home3dEffects': 'रंग और 3D प्रभाव',
    'home3dEffectsSubtitle': 'होम स्पॉटलाइट कार्ड पर गहराई और रंग प्रभाव',
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
    'courseSearchHint': 'ಕೋರ್ಸ್‌ಗಳು ಅಥವಾ ಸಂಸ್ಥೆಗಳನ್ನು ಹುಡುಕಿ...',
    'seeAll': 'ಎಲ್ಲವನ್ನೂ ನೋಡಿ',
    'linkCopied': 'ಲಿಂಕ್ ನಕಲಿಸಲಾಗಿದೆ',
    'share': 'ಹಂಚಿಕೊಳ್ಳಿ',
    'downloadBrochure': 'ಬ್ರೋಷರ್ ಡೌನ್‌ಲೋಡ್ ಮಾಡಿ',
    'whatYouLearn': 'ನೀವು ಕಲಿಯುವುದು',
    'faq': 'ಪದೇ ಪದೇ ಕೇಳಲಾಗುವ ಪ್ರಶ್ನೆಗಳು',
    'off': 'ರಿಯಾಯಿತಿ',
    'featuredInstitutes': 'ಪ್ರಮುಖ ಸಂಸ್ಥೆಗಳು',
    'popularCourses': 'ಜನಪ್ರಿಯ ಕೋರ್ಸ್‌ಗಳು',
    'upcomingBatches': 'ಮುಂಬರುವ ಬ್ಯಾಚ್‌ಗಳು',
    'watchDemoClass': 'ಡೆಮೊ ತರಗತಿ ವೀಕ್ಷಿಸಿ',
    'typeAllInstitutes': 'ಎಲ್ಲಾ',
    'typePrivate': 'ಖಾಸಗಿ',
    'typeStateGovernment': 'ರಾಜ್ಯ ಸರ್ಕಾರ',
    'typeCentralGovernment': 'ಕೇಂದ್ರ ಸರ್ಕಾರ',
    'typeUniversity': 'ವಿಶ್ವವಿದ್ಯಾಲಯ',
    'typeNgo': 'ಎನ್‌ಜಿಒ',
    'typeOther': 'ಇತರೆ',
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
    'filterAllCourses': 'ಎಲ್ಲಾ',
    'home3dEffects': 'ಬಣ್ಣ ಮತ್ತು 3D ಪರಿಣಾಮಗಳು',
    'home3dEffectsSubtitle':
        'ಹೋಮ್ ಸ್ಪಾಟ್‌ಲೈಟ್ ಕಾರ್ಡ್‌ಗಳ ಮೇಲೆ ಆಳ ಮತ್ತು ಬಣ್ಣ ಪರಿಣಾಮಗಳು',
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
    'courseSearchHint': 'பாடநெறிகள் அல்லது நிறுவனங்களைத் தேடுங்கள்...',
    'seeAll': 'அனைத்தையும் காண்க',
    'linkCopied': 'இணைப்பு நகலெடுக்கப்பட்டது',
    'share': 'பகிர்',
    'downloadBrochure': 'சுற்றறிக்கையைப் பதிவிறக்கு',
    'whatYouLearn': 'நீங்கள் கற்பவை',
    'faq': 'அடிக்கடி கேட்கப்படும் கேள்விகள்',
    'off': 'தள்ளுபடி',
    'featuredInstitutes': 'சிறப்பு நிறுவனங்கள்',
    'popularCourses': 'பிரபலமான பாடநெறிகள்',
    'upcomingBatches': 'வரவிருக்கும் தொகுப்புகள்',
    'watchDemoClass': 'டெமோ வகுப்பைப் பார்க்க',
    'typeAllInstitutes': 'அனைத்தும்',
    'typePrivate': 'தனியார்',
    'typeStateGovernment': 'மாநில அரசு',
    'typeCentralGovernment': 'மத்திய அரசு',
    'typeUniversity': 'பல்கலைக்கழகம்',
    'typeNgo': 'தன்னார்வ தொண்டு நிறுவனம்',
    'typeOther': 'மற்றவை',
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
    'filterAllCourses': 'அனைத்தும்',
    'home3dEffects': 'நிறம் & 3D விளைவுகள்',
    'home3dEffectsSubtitle':
        'ஹோம் ஸ்பாட்லைட் கார்டுகளில் ஆழம் மற்றும் நிற விளைவுகள்',
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
  // Getters kept from release/v1.0.
  String get retry => _t('retry');
  String get save => _t('save');
  String get edit => _t('edit');
  String get viewAll => _t('viewAll');
  String get offline => _t('offline');
  String get unknownError => _t('unknownError');
  String get somethingWentWrong => _t('somethingWentWrong');

  String _t(String key) {
    final lang = locale.languageCode;
    // Main-lineage tables first, then the release/v1.0 translations (which
    // add Marathi, Bengali, Gujarati, Malayalam and Spanish), then English.
    return _tables[lang]?[key] ??
        _translations[lang]?[key] ??
        _tables['en']?[key] ??
        _translations['en']?[key] ??
        key;
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
  String get courseSearchHint => _t('courseSearchHint');
  String get seeAll => _t('seeAll');
  String get linkCopied => _t('linkCopied');
  String get share => _t('share');
  String get downloadBrochure => _t('downloadBrochure');
  String get whatYouLearn => _t('whatYouLearn');
  String get faq => _t('faq');
  String get off => _t('off');
  String get featuredInstitutes => _t('featuredInstitutes');
  String get popularCourses => _t('popularCourses');
  String get upcomingBatches => _t('upcomingBatches');
  String get watchDemoClass => _t('watchDemoClass');
  String get typeAllInstitutes => _t('typeAllInstitutes');
  String get typePrivate => _t('typePrivate');
  String get typeStateGovernment => _t('typeStateGovernment');
  String get typeCentralGovernment => _t('typeCentralGovernment');
  String get typeUniversity => _t('typeUniversity');
  String get typeNgo => _t('typeNgo');
  String get typeOther => _t('typeOther');
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
  String get filterAllCourses => _t('filterAllCourses');
  String get home3dEffects => _t('home3dEffects');
  String get home3dEffectsSubtitle => _t('home3dEffectsSubtitle');
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

  // Education / institutes
  String get education => _t('education');
  String get institutes => _t('institutes');
  String get noInstitutes => _t('noInstitutes');
  String get noInstitutesMessage => _t('noInstitutesMessage');
  String get instituteDetails => _t('instituteDetails');
  String get coursesByInstitute => _t('coursesByInstitute');
  String get aboutInstitute => _t('aboutInstitute');
  String get faculty => _t('faculty');
  String get contactInstitute => _t('contactInstitute');
  String get location => _t('location');
  String get timings => _t('timings');
  String get viewOnMap => _t('viewOnMap');
  String get myCourses => _t('myCourses');
  String get noMyCourses => _t('noMyCourses');
  String get noMyCoursesMessage => _t('noMyCoursesMessage');
  String get discount => _t('discount');
  String get totalPayable => _t('totalPayable');
  String get feeBreakdown => _t('feeBreakdown');
  String get demoAndRegistration => _t('demoAndRegistration');
  String get registerForDemo => _t('registerForDemo');
  String get demoRequestSubmitted => _t('demoRequestSubmitted');
  String get studentName => _t('studentName');
  String get mobileNumber => _t('mobileNumber');
  String get preferredBatch => _t('preferredBatch');
  String get note => _t('note');
  String get submit => _t('submit');
  String get feedback => _t('feedback');
  String get noFeedback => _t('noFeedback');
  String get writeFeedback => _t('writeFeedback');
  String get feedbackSubmitted => _t('feedbackSubmitted');
  String get yourRating => _t('yourRating');
  String get invoice => _t('invoice');
  String get viewInvoice => _t('viewInvoice');
  String get invoiceNumber => _t('invoiceNumber');
  String get issuedOn => _t('issuedOn');
  String get netAmount => _t('netAmount');
  String get educationUnavailable => _t('educationUnavailable');
  String get educationUnavailableMessage => _t('educationUnavailableMessage');
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
  // Navigation / bottom bar
  String get navMap => _t('navMap');
  String get navSaved => _t('navSaved');
  String get navExplore => _t('navExplore');
  String get navChat => _t('navChat');

  // Venues
  String get ratings => _t('ratings');
  String get reviews => _t('reviews');
  String get checkAvailability => _t('checkAvailability');
  String get nearbyVenues => _t('nearbyVenues');
  String get popularVenues => _t('popularVenues');

  // Home
  String get homeGreeting => _t('homeGreeting');
  String get findYourSpace => _t('findYourSpace');
  String get whatAreYouLookingFor => _t('whatAreYouLookingFor');
  String get saveVenue => _t('saveVenue');
  String get noSavedVenues => _t('noSavedVenues');
  String get noSavedVenuesMessage => _t('noSavedVenuesMessage');
  String get nearest => _t('nearest');
  String get useMyLocation => _t('useMyLocation');
  String get resultsCount => _t('resultsCount');
  String get openNow => _t('openNow');
  String get closedNow => _t('closedNow');
  String get rules => _t('rules');
  String get gallery => _t('gallery');
  String get explore => _t('explore');
  String get events => _t('events');
  String get recentSearches => _t('recentSearches');
  String get clearRecentSearches => _t('clearRecentSearches');
  String get noRecentSearches => _t('noRecentSearches');
  String get servingCachedData => _t('servingCachedData');
  String get holdExpired => _t('holdExpired');
  String holdExpiresIn(String time) =>
      _t('holdExpiresIn').replaceFirst('{time}', time);
  String get venueOptimizer => _t('venueOptimizer');
  String get contextualHelp => _t('contextualHelp');

  // Events
  String get yourTicket => _t('yourTicket');
  String get searchEvents => _t('searchEvents');
  String get allEvents => _t('allEvents');
  String get paidEvent => _t('paidEvent');

  // Courses
  String get searchCourses => _t('searchCourses');
  String get allModes => _t('allModes');
  String get demoSession => _t('demoSession');
  String get paidCourse => _t('paidCourse');
  String get searchInstitutes => _t('searchInstitutes');
  String get institutesAndClasses => _t('institutesAndClasses');
  String get verifiedOnly => _t('verifiedOnly');
  String get unifiedRegistration => _t('unifiedRegistration');
  String get unifiedRegistrationHint => _t('unifiedRegistrationHint');

  // Booking
  String get availability => _t('availability');
  String get bookingSummary => _t('bookingSummary');
  String get bookingDetails => _t('bookingDetails');
  String get eventType => _t('eventType');
  String get guestName => _t('guestName');
  String get tenantName => _t('tenantName');
  String get idNumber => _t('idNumber');
  String get payment => _t('payment');
  String get payNow => _t('payNow');
  String get bookAgain => _t('bookAgain');
  String get paymentSuccess => _t('paymentSuccess');
  String get paymentFailed => _t('paymentFailed');
  String get paymentPending => _t('paymentPending');
  String get paymentCancelled => _t('paymentCancelled');
  String get verifyingPayment => _t('verifyingPayment');
  String get paymentPendingMessage => _t('paymentPendingMessage');
  String get promoCode => _t('promoCode');
  String get promoCodeHint => _t('promoCodeHint');
  String get promoCodeApplied => _t('promoCodeApplied');
  String get remove => _t('remove');
  String get paymentMethod => _t('paymentMethod');
  String get payAtVenue => _t('payAtVenue');
  String get bookingSuccessTitle => _t('bookingSuccessTitle');
  String get copy => _t('copy');
  String get copiedToClipboard => _t('copiedToClipboard');
  String get exploreMoreSpaces => _t('exploreMoreSpaces');

  // Booking details / invoice
  String get invoiceFor => _t('invoiceFor');
  String get invoiceEmailQueued => _t('invoiceEmailQueued');
  String get invoiceEmailNotQueued => _t('invoiceEmailNotQueued');
  String get bookingRef => _t('bookingRef');
  String get bookingStatus => _t('bookingStatus');
  String get dateOfBooking => _t('dateOfBooking');
  String get customer => _t('customer');
  String get guestCount => _t('guestCount');
  String get checkIn => _t('checkIn');
  String get checkOut => _t('checkOut');
  String get moveIn => _t('moveIn');
  String get sharingOption => _t('sharingOption');
  String get rent => _t('rent');
  String get deposit => _t('deposit');
  String get changeSharing => _t('changeSharing');
  String get monthlyRentCalculator => _t('monthlyRentCalculator');
  String get selectRoomSharing => _t('selectRoomSharing');
  String get stayDuration => _t('stayDuration');
  String get perMonth => _t('perMonth');
  String get monthlyPayable => _t('monthlyPayable');
  String get refundableSecurityDeposit => _t('refundableSecurityDeposit');
  String get estimatedTotalMoveIn => _t('estimatedTotalMoveIn');
  String monthsLabel(int count) => _t(
    count == 1 ? 'monthCount' : 'monthsCount',
  ).replaceFirst('{count}', '$count');
  String totalRentForTenure(int count) =>
      _t('totalRentForTenure').replaceFirst('{count}', '$count');
  String maintenanceCharges(int count) =>
      _t('maintenanceCharges').replaceFirst('{count}', '$count');
  String get slotHeld => _t('slotHeld');
  String get payMethod => _t('payMethod');
  String get onlinePayment => _t('onlinePayment');
  String get offlinePayment => _t('offlinePayment');
  String get paidOn => _t('paidOn');
  String get paymentRef => _t('paymentRef');
  String get paymentHistory => _t('paymentHistory');
  String get noPaymentHistory => _t('noPaymentHistory');
  String get noPaymentHistoryMessage => _t('noPaymentHistoryMessage');
  String get transactionSummary => _t('transactionSummary');
  String get razorpayTransactionId => _t('razorpayTransactionId');
  String get razorpayOrderId => _t('razorpayOrderId');
  String get bookingId => _t('bookingId');
  String get walkIn => _t('walkIn');
  String get statusHeld => _t('statusHeld');
  String get statusPending => _t('statusPending');
  String get statusConfirmed => _t('statusConfirmed');
  String get statusCompleted => _t('statusCompleted');
  String get statusCancelled => _t('statusCancelled');
  String get statusRefunded => _t('statusRefunded');
  String get statusNoShow => _t('statusNoShow');
  String get statusPendingOwnerApproval => _t('statusPendingOwnerApproval');
  String get statusRejected => _t('statusRejected');
  String get slotBooked => _t('slotBooked');
  String get slotUnavailable => _t('slotUnavailable');
  String get slotBlocked => _t('slotBlocked');
  String get slotClosed => _t('slotClosed');
  String get listingOnly => _t('listingOnly');
  String get listingOnlyMessage => _t('listingOnlyMessage');
  String get call => _t('call');
  String get whatsapp => _t('whatsapp');
  String get callingVenue => _t('callingVenue');
  String get openingWhatsApp => _t('openingWhatsApp');
  String get digitalEntryPass => _t('digitalEntryPass');
  String get viewEntryPass => _t('viewEntryPass');
  String get entryPassHint => _t('entryPassHint');
  String get openInGoogleMaps => _t('openInGoogleMaps');

  // Owner bookings / offline
  String get ownerBookings => _t('ownerBookings');
  String get newOfflineBooking => _t('newOfflineBooking');
  String get offlineBooking => _t('offlineBooking');
  String get createOfflineBooking => _t('createOfflineBooking');
  String get customerName => _t('customerName');
  String get customerPhone => _t('customerPhone');
  String get selectVenue => _t('selectVenue');
  String get noOwnerBookings => _t('noOwnerBookings');
  String get noOwnerVenuesMessage => _t('noOwnerVenuesMessage');
  String get completeBooking => _t('completeBooking');
  String get markNoShow => _t('markNoShow');
  String get approveBooking => _t('approveBooking');
  String get rejectBooking => _t('rejectBooking');
  String get approveBookingConfirm => _t('approveBookingConfirm');
  String get rejectBookingConfirm => _t('rejectBookingConfirm');
  String get bookingApproved => _t('bookingApproved');
  String get bookingRejected => _t('bookingRejected');
  String get bookingRejectedRefundRequested =>
      _t('bookingRejectedRefundRequested');

  // Profile / Auth
  String get login => _t('login');
  String get logout => _t('logout');
  String get phone => _t('phone');
  String get continueWithGoogle => _t('continueWithGoogle');
  String get continueWithApple => _t('continueWithApple');
  String get myProfile => _t('myProfile');
  String get signInWithEmailOtp => _t('signInWithEmailOtp');
  String get signInWithPhoneOtp => _t('signInWithPhoneOtp');
  String get otpPlaceholder => _t('otpPlaceholder');
  String get verifyOtp => _t('verifyOtp');
  String get sendOtp => _t('sendOtp');
  String get resendOtp => _t('resendOtp');
  String get otpSent => _t('otpSent');
  String get authFailed => _t('authFailed');
  String get forgotPassword => _t('forgotPassword');
  String get resetPassword => _t('resetPassword');
  String get sendResetLink => _t('sendResetLink');
  String get resetEmailPrompt => _t('resetEmailPrompt');
  String get resetEmailSent => _t('resetEmailSent');
  String get resetEmailSentMessage => _t('resetEmailSentMessage');
  String get resetPasswordPrompt => _t('resetPasswordPrompt');
  String get newPassword => _t('newPassword');
  String get confirmPassword => _t('confirmPassword');
  String get passwordsDoNotMatch => _t('passwordsDoNotMatch');
  String get passwordUpdated => _t('passwordUpdated');
  String get passwordUpdatedMessage => _t('passwordUpdatedMessage');
  String get invalidResetLink => _t('invalidResetLink');
  String get backToLogin => _t('backToLogin');
  String get authUnavailable => _t('authUnavailable');
  String get signInHint => _t('signInHint');
  String get signInToContinue => _t('signInToContinue');
  String get signInRequiredForBooking =>
      _t('signInRequiredForBooking');
  String get orDivider => _t('orDivider');
  String get createProfile => _t('createProfile');
  String get quickBookingMode => _t('quickBookingMode');
  String get bookingDisabledForCategory => _t('bookingDisabledForCategory');
  String get availabilityDisabledForCategory =>
      _t('availabilityDisabledForCategory');
  String get notAnOwner => _t('notAnOwner');
  String get registerAsOwnerHint => _t('registerAsOwnerHint');
  String get instituteOwnerPortal => _t('instituteOwnerPortal');
  String get createInstitute => _t('createInstitute');
  String get addClass => _t('addClass');
  String get addFaculty => _t('addFaculty');
  String get plans => _t('plans');
  String get classes => _t('classes');
  String get verifiedInstitute => _t('verifiedInstitute');
  String get noGalleryYet => _t('noGalleryYet');
  String get facultyPlaceholder => _t('facultyPlaceholder');
  String get noPublishedClasses => _t('noPublishedClasses');
  String get saveDraft => _t('saveDraft');
  String get allFilters => _t('allFilters');
  String get verifiedResults => _t('verifiedResults');
  String get recommended => _t('recommended');
  String get clearDate => _t('clearDate');
  String get clearDates => _t('clearDates');
  String get add => _t('add');
  String get filtersHint => _t('filtersHint');
  String otpSentResendIn(int seconds) =>
      _t('otpSentResendIn').replaceFirst('{seconds}', '$seconds');
  String otpResendIn(int seconds) =>
      _t('otpResendIn').replaceFirst('{seconds}', '$seconds');
  String get qrCheckIn => _t('qrCheckIn');
  String get locationSubmissions => _t('locationSubmissions');
  String get institutePortal => _t('institutePortal');
  String get noInstituteProfile => _t('noInstituteProfile');
  String get createInstituteHint => _t('createInstituteHint');
  String get editInstitute => _t('editInstitute');
  String get description => _t('description');
  String get specialization => _t('specialization');
  String get classTitle => _t('classTitle');
  String get fee => _t('fee');
  String get deliveryMode => _t('deliveryMode');
  String get classesAndCourses => _t('classesAndCourses');
  String get hotels => _t('hotels');
  String get functionHalls => _t('functionHalls');
  String inArea(String title, String area) =>
      _t('inArea').replaceFirst('{title}', title).replaceFirst('{area}', area);
  String verifiedResultsCount(int count) =>
      _t('verifiedResultsCount').replaceFirst('{count}', '$count');
  String get priceLow => _t('priceLow');
  String get priceHigh => _t('priceHigh');
  String fieldsRequired(String fields) =>
      _t('fieldsRequired').replaceFirst('{fields}', fields);
  String get verified => _t('verified');
  String get unverified => _t('unverified');
  String get justNow => _t('justNow');
  String minutesAgo(int count) =>
      _t('minutesAgo').replaceFirst('{count}', '$count');
  String hoursAgo(int count) =>
      _t('hoursAgo').replaceFirst('{count}', '$count');
  String daysAgo(int count) => _t('daysAgo').replaceFirst('{count}', '$count');
  String get noActiveAdvertisingPlan => _t('noActiveAdvertisingPlan');
  String listingActiveUntil(String date) =>
      _t('listingActiveUntil').replaceFirst('{date}', date);
  String get plansPaymentHint => _t('plansPaymentHint');

  // Owner
  String get createVenue => _t('createVenue');
  String get ownerVenues => _t('ownerVenues');
  String get ownerRequests => _t('ownerRequests');
  String get ownerCalendar => _t('ownerCalendar');
  String get earnings => _t('earnings');
  String get addVenue => _t('addVenue');

  // Settings
  String get analytics => _t('analytics');
  String get noNotifications => _t('noNotifications');
  String get noNotificationsMessage => _t('noNotificationsMessage');
  String get markAllRead => _t('markAllRead');
  String get unread => _t('unread');
  String get noAnalyticsData => _t('noAnalyticsData');
  String get noSupportTickets => _t('noSupportTickets');
  String get newTicket => _t('newTicket');
  String get resolved => _t('resolved');
  String get open => _t('open');
  String get inProgress => _t('inProgress');
  String get closed => _t('closed');
  String get adminReply => _t('adminReply');
  String get noAdminReply => _t('noAdminReply');
  String get ticketCreated => _t('ticketCreated');
  String get ticketUpdated => _t('ticketUpdated');
  String get admin => _t('admin');
  String get noAuditLogs => _t('noAuditLogs');

  // Errors
  String get errorNoInternet => _t('errorNoInternet');
  String get errorInvalidPhone => _t('errorInvalidPhone');
  String get errorRequired => _t('errorRequired');
  String get errorInvalidAmount => _t('errorInvalidAmount');


  static const Map<String, Map<String, String>> _translations = {
    'en': {
      'appName': 'BookMySpace',
      'tagline': 'Find and book your perfect space',
      'retry': 'Retry',
      'cancel': 'Cancel',
      'confirm': 'Confirm',
      'save': 'Save',
      'delete': 'Delete',
      'search': 'Search',
      'loading': 'Loading…',
      'next': 'Next',
      'back': 'Back',
      'done': 'Done',
      'edit': 'Edit',
      'viewAll': 'View all',
      'noResults': 'No results found',
      'noResultsMessage': 'Try adjusting your filters or search term.',
      'offline': 'You are offline',
      'offlineMessage': 'Check your internet connection and try again.',
      'unknownError': 'Something went wrong',
      'somethingWentWrong': 'An unexpected error occurred. Please try again.',
      'tryAgain': 'Try again',
      'onboardingTitle1': 'Discover venues',
      'onboardingSubtitle1':
          'Find function halls, marriage halls, meeting rooms and more near you.',
      'onboardingTitle2': 'Book in seconds',
      'onboardingSubtitle2':
          'Check live availability, pick your slot and pay securely.',
      'onboardingTitle3': 'Manage everything',
      'onboardingSubtitle3':
          'Track bookings, get notifications and manage your calendar.',
      'getStarted': 'Get started',
      'skip': 'Skip',
      'navHome': 'Home',
      'navMap': 'Map',
      'navSearch': 'Search',
      'navBookings': 'Bookings',
      'navSaved': 'Saved',
      'navExplore': 'Explore',
      'navChat': 'Chat',
      'navProfile': 'Profile',
      'venues': 'Venues',
      'venueDetails': 'Venue details',
      'amenities': 'Amenities',
      'capacity': 'Capacity',
      'operatingHours': 'Operating hours',
      'pricing': 'Pricing',
      'ratings': 'Ratings',
      'reviews': 'Reviews',
      'checkAvailability': 'Check availability',
      'bookNow': 'Book now',
      'nearbyVenues': 'Nearby venues',
      'popularVenues': 'Popular venues',
      'homeGreeting': 'Hello',
      'findYourSpace': 'Find your perfect space',
      'whatAreYouLookingFor': 'What are you looking for?',
      'saveVenue': 'Save venue',
      'savedVenues': 'Saved venues',
      'noSavedVenues': 'No saved venues yet',
      'noSavedVenuesMessage': 'Tap the heart on any venue to keep it here.',
      'filters': 'Filters',
      'clearFilters': 'Clear all',
      'sortBy': 'Sort by',
      'relevance': 'Relevance',
      'priceLowToHigh': 'Price: low to high',
      'priceHighToLow': 'Price: high to low',
      'topRated': 'Top rated',
      'minPrice': 'Min price',
      'maxPrice': 'Max price',
      'allCategories': 'All categories',
      'apply': 'Apply',
      'nearest': 'Nearest',
      'useMyLocation': 'Use my location',
      'resultsCount': '{count} venues found',
      'aboutThisVenue': 'About this venue',
      'details': 'Details',
      'address': 'Address',
      'openNow': 'Open now',
      'closedNow': 'Closed',
      'foodOptions': 'Food options',
      'rules': 'House rules',
      'parking': 'Parking',
      'taxRate': 'GST',
      'basePrice': 'Base price',
      'discount': 'Discount',
      'viewOnMap': 'View on map',
      'gallery': 'Gallery',
      'explore': 'Explore',
      'events': 'Events',
      'courses': 'Courses',
      'searchHint': 'Search venues, areas, categories…',
      'recentSearches': 'Recent searches',
      'clearRecentSearches': 'Clear all',
      'noRecentSearches': 'No recent searches',
      'servingCachedData': 'Showing saved data while you are offline',
      'holdExpired': 'This hold has expired. Pick the slot again.',
      'holdExpiresIn': 'Hold expires in {time}',
      'venueOptimizer': 'Venue Optimizer',
      'contextualHelp': 'Help',
      'upcomingEvents': 'Upcoming events',
      'noUpcomingEvents': 'No upcoming events',
      'noUpcomingEventsMessage':
          'New events will appear here as organisations publish them.',
      'freeEvent': 'Free',
      'registerNow': 'Register now',
      'registered': 'Registered',
      'seatsLeft': '{count} seats left',
      'soldOut': 'Sold out',
      'yourTicket': 'Your ticket',
      'cancelRegistration': 'Cancel registration',
      'cancelRegistrationConfirm':
          'Cancel your registration for this event? Your seat will be released.',
      'registrationCancelled': 'Registration cancelled',
      'searchEvents': 'Search events, venues, categories…',
      'allEvents': 'All',
      'paidEvent': 'Paid',
      'noCourses': 'No courses yet',
      'noCoursesMessage':
          'Courses from verified institutes will appear here when published.',
      'enrollNow': 'Enroll now',
      'enrolled': 'Enrolled',
      'enrollInCourse': 'Enroll in course',
      'courseFee': 'Course fee',
      'durationWeeks': '{weeks} weeks',
      'instructor': 'Instructor',
      'batchStartsOn': 'Starts',
      'modeOnline': 'Online',
      'modeOffline': 'Offline',
      'modeHybrid': 'Hybrid',
      'dropEnrollment': 'Drop enrollment',
      'dropEnrollmentConfirm':
          'Drop your enrollment in this batch? Your seat will be released.',
      'enrollmentDropped': 'Enrollment dropped',
      'searchCourses': 'Search courses, institutes, instructors…',
      'allModes': 'All',
      'demoSession': 'Demo',
      'paidCourse': 'Paid',
      'searchInstitutes': 'Search institutes and classes…',
      'institutesAndClasses': 'Institutes & Classes',
      'noInstitutes': 'No institutes yet',
      'noInstitutesMessage':
          'Verified institutes appear here when owners publish them.',
      'verifiedOnly': 'Verified only',
      'unifiedRegistration': 'Unified registration',
      'unifiedRegistrationHint':
          'One registration entry for every module. Fields come from admin-configured forms in Supabase, not from a local field list.',
      'selectDate': 'Select a date',
      'selectTimeSlot': 'Select a time slot',
      'availability': 'Availability',
      'confirmBooking': 'Confirm booking',
      'bookingSummary': 'Booking summary',
      'bookingDetails': 'Your details for this booking',
      'eventType': 'Event type (wedding, birthday, meeting…)',
      'guestName': 'Guest name',
      'tenantName': 'Tenant name',
      'idNumber': 'ID number (Aadhaar / Passport)',
      'payment': 'Payment',
      'payNow': 'Pay now',
      'paymentMethod': 'Payment method',
      'payAtVenue': 'Pay at venue',
      'bookAgain': 'Book again',
      'paymentSuccess': 'Payment successful',
      'paymentFailed': 'Payment failed',
      'paymentPending': 'Payment pending',
      'paymentCancelled': 'Payment was cancelled. You can try again.',
      'verifyingPayment': 'Verifying your payment…',
      'paymentPendingMessage':
          'Payment received. We are confirming your booking.',
      'requestRefund': 'Request refund',
      'requestRefundConfirm':
          'Request a full refund for this booking? This cannot be undone.',
      'refundRequested': 'Refund requested — it will be processed shortly.',
      'myBookings': 'My bookings',
      'noSlotsForDate': 'No slots available on this date',
      'total': 'Total',
      'promoCode': 'Promo code',
      'promoCodeHint': 'Enter promo code',
      'promoCodeApplied': 'Promo applied',
      'remove': 'Remove',
      'bookingConfirmed': 'Booking confirmed —',
      'bookingSuccessTitle': 'Booking Confirmed!',
      'copy': 'Copy',
      'copiedToClipboard': 'Copied to clipboard',
      'exploreMoreSpaces': 'Explore more spaces',
      'noBookings': 'No bookings yet',
      'noBookingsMessage': 'When you book a venue, it will show up here.',
      'cancelBooking': 'Cancel booking',
      'cancelBookingConfirm': 'Are you sure you want to cancel this booking?',
      'keep': 'Keep booking',
      'invoice': 'Invoice',
      'viewInvoice': 'View invoice',
      'invoiceFor': 'Booking invoice',
      'invoiceEmailQueued':
          'Invoice email queued to your account email. Delivery is handled by the server outbox, not by this device.',
      'invoiceEmailNotQueued':
          'No account email is on file, so nothing was queued. Download the PDF instead.',
      'bookingRef': 'Booking reference',
      'bookingStatus': 'Status',
      'dateOfBooking': 'Booking date',
      'customer': 'Customer',
      'guestCount': 'Guests',
      'checkIn': 'Check-in',
      'checkOut': 'Check-out',
      'moveIn': 'Move-in',
      'sharingOption': 'Sharing option',
      'rent': 'Rent',
      'deposit': 'Deposit',
      'changeSharing': 'Change sharing',
      'monthlyRentCalculator': 'Monthly rent calculator',
      'selectRoomSharing': 'Select room sharing',
      'stayDuration': 'Stay duration',
      'perMonth': '/mo',
      'monthlyPayable': 'Monthly payable',
      'refundableSecurityDeposit': 'Refundable security deposit',
      'estimatedTotalMoveIn': 'Estimated total move-in payable',
      'monthCount': '{count} month',
      'monthsCount': '{count} months',
      'totalRentForTenure': 'Total rent ({count} mo)',
      'maintenanceCharges': 'Maintenance ({count} mo)',
      'slotHeld': 'Slot held for 10 minutes. Complete the payment to confirm.',
      'payMethod': 'Payment method',
      'onlinePayment': 'Online (Razorpay)',
      'offlinePayment': 'Offline (walk-in)',
      'paidOn': 'Paid on',
      'paymentRef': 'Payment reference',
      'paymentHistory': 'Payment history',
      'noPaymentHistory': 'No completed payments',
      'noPaymentHistoryMessage':
          'Your successful transactions will appear here.',
      'transactionSummary': 'Transaction summary',
      'razorpayTransactionId': 'Razorpay transaction ID',
      'razorpayOrderId': 'Razorpay order ID',
      'bookingId': 'Booking ID',
      'walkIn': 'Walk-in',
      'statusHeld': 'Held',
      'statusPending': 'Pending',
      'statusConfirmed': 'Confirmed',
      'statusCompleted': 'Completed',
      'statusCancelled': 'Cancelled',
      'statusRefunded': 'Refunded',
      'statusNoShow': 'No show',
      'statusPendingOwnerApproval': 'Awaiting approval',
      'statusRejected': 'Rejected',
      'slotBooked': 'Booked',
      'slotUnavailable': 'Unavailable',
      'slotBlocked': 'Blocked',
      'slotClosed': 'Closed',
      'listingOnly': 'Listing only',
      'listingOnlyMessage':
          'Institutes and classes are advertising listings. Use Call or WhatsApp from the details page.',
      'call': 'Call',
      'whatsapp': 'WhatsApp',
      'callingVenue': 'Calling {name}…',
      'openingWhatsApp': 'Opening WhatsApp for {name}…',
      'digitalEntryPass': 'Digital Entry Pass',
      'viewEntryPass': 'View Entry Pass / QR',
      'entryPassHint':
          'Show this QR pass at the venue entrance gate for instant check-in verification.',
      'openInGoogleMaps': 'Open in Google Maps',
      'ownerBookings': 'Owner bookings',
      'newOfflineBooking': 'New offline booking',
      'offlineBooking': 'Offline booking',
      'createOfflineBooking': 'Create offline booking',
      'customerName': 'Customer name',
      'customerPhone': 'Customer phone',
      'selectVenue': 'Select venue',
      'noOwnerBookings': 'No bookings for your venues yet',
      'noOwnerVenuesMessage':
          'You need at least one venue before managing bookings.',
      'completeBooking': 'Mark completed',
      'markNoShow': 'Mark no-show',
      'approveBooking': 'Approve',
      'rejectBooking': 'Reject',
      'approveBookingConfirm':
          'Approve this booking? The customer will be notified and the booking confirmed.',
      'rejectBookingConfirm':
          "Reject this booking? If the customer paid online, a refund will be requested automatically.",
      'bookingApproved': 'Booking approved',
      'bookingRejected': 'Booking rejected',
      'bookingRejectedRefundRequested': 'Booking rejected. Refund requested.',
      'login': 'Log in',
      'signUp': 'Sign up',
      'logout': 'Log out',
      'email': 'Email',
      'phone': 'Phone',
      'name': 'Name',
      'password': 'Password',
      'continueWithGoogle': 'Continue with Google',
      'continueWithApple': 'Continue with Apple',
      'myProfile': 'My profile',
      'signInWithEmailOtp': 'Log in with email OTP',
      'signInWithPhoneOtp': 'Log in with phone OTP',
      'otpPlaceholder': '6-digit code',
      'verifyOtp': 'Verify & log in',
      'sendOtp': 'Send code',
      'resendOtp': 'Resend code',
      'otpSent': 'We sent you a verification code.',
      'forgotPassword': 'Forgot password?',
      'resetPassword': 'Reset password',
      'sendResetLink': 'Send reset link',
      'resetEmailPrompt':
          'Enter the email on your account. We will send a reset link if it exists.',
      'resetEmailSent': 'Check your email',
      'resetEmailSentMessage':
          'If an account exists for that address, a reset link is on its way. Open it on this device to choose a new password.',
      'resetPasswordPrompt': 'Choose a new password for your account.',
      'newPassword': 'New password',
      'confirmPassword': 'Confirm password',
      'passwordsDoNotMatch': 'Passwords do not match',
      'passwordUpdated': 'Password updated',
      'passwordUpdatedMessage': 'Sign in with your new password to continue.',
      'invalidResetLink':
          'This reset link is invalid or has expired. Request a new one from the login screen.',
      'backToLogin': 'Back to login',
      'authUnavailable': 'Authentication is currently unavailable.',
      'signInHint':
          'Sign in with email or phone. Extra details are asked only when you book.',
      'signInToContinue': 'Sign in to continue',
      'signInRequiredForBooking':
          'Sign in required to confirm this booking. Your selections are saved.',
      'orDivider': 'OR',
      'createProfile': 'Create a profile',
      'quickBookingMode': 'Quick booking mode',
      'bookingDisabledForCategory': 'Booking is disabled for this category',
      'availabilityDisabledForCategory':
          'Availability is disabled for this category',
      'notAnOwner': 'Not an owner',
      'registerAsOwnerHint': 'Register as an owner to access the dashboard.',
      'instituteOwnerPortal': 'Institute owner portal',
      'createInstitute': 'Create institute',
      'addClass': 'Add class',
      'addFaculty': 'Add faculty',
      'plans': 'Plans',
      'faculty': 'Faculty',
      'classes': 'Classes',
      'verifiedInstitute': 'Verified institute',
      'noGalleryYet': 'No gallery images yet.',
      'facultyPlaceholder': 'Faculty profiles will appear here.',
      'noPublishedClasses': 'No published classes yet.',
      'saveDraft': 'Save draft',
      'allFilters': 'All filters',
      'verifiedResults': 'verified results',
      'recommended': 'Recommended',
      'clearDate': 'Clear date',
      'clearDates': 'Clear dates',
      'add': 'Add',
      'filtersHint': 'Location, price, rating, capacity and amenities',
      'otpSentResendIn': 'A verification code was sent. Resend in {seconds}s',
      'otpResendIn': 'Resend in {seconds}s',
      'qrCheckIn': 'QR check-in',
      'locationSubmissions': 'Location submissions',
      'institutePortal': 'Institute portal',
      'noInstituteProfile': 'No institute profile',
      'createInstituteHint':
          'Create an institute to publish classes, faculty and a gallery.',
      'editInstitute': 'Edit institute',
      'description': 'Description',
      'city': 'City',
      'specialization': 'Specialization',
      'classTitle': 'Title',
      'fee': 'Fee',
      'deliveryMode': 'Delivery mode',
      'classesAndCourses': 'Classes & courses',
      'hotels': 'Hotels',
      'functionHalls': 'Function Halls',
      'inArea': '{title} in {area}',
      'verifiedResultsCount': '{count} verified results',
      'priceLow': 'Price: low',
      'priceHigh': 'Price: high',
      'fieldsRequired': 'Need: {fields}',
      'verified': 'Verified',
      'unverified': 'Unverified',
      'justNow': 'now',
      'minutesAgo': '{count}m ago',
      'hoursAgo': '{count}h ago',
      'daysAgo': '{count}d ago',
      'noActiveAdvertisingPlan': 'No active advertising plan',
      'listingActiveUntil': 'Listing active until {date}',
      'plansPaymentHint':
          'Plans are purchased through the existing payment flow.',
      'authFailed': 'Authentication failed. Please try again.',
      'ownerDashboard': 'Owner dashboard',
      'myVenues': 'My Venues',
      'createVenue': 'Create Venue',
      'ownerVenues': 'Owner Venues',
      'ownerRequests': 'Booking requests',
      'ownerCalendar': 'Calendar',
      'earnings': 'Earnings',
      'addVenue': 'Add venue',
      'settings': 'Settings',
      'language': 'Language',
      'themeMode': 'Theme',
      'notifications': 'Notifications',
      'analytics': 'Analytics',
      'support': 'Support',
      'auditLog': 'Audit Log',
      'priority': 'Priority',
      'noNotifications': 'No notifications',
      'noNotificationsMessage':
          'You will see notifications here when they arrive.',
      'markAllRead': 'Mark all read',
      'unread': 'Unread',
      'noAnalyticsData': 'No analytics data',
      'noSupportTickets': 'No support tickets',
      'newTicket': 'New Ticket',
      'resolved': 'Resolved',
      'open': 'Open',
      'inProgress': 'In Progress',
      'closed': 'Closed',
      'adminReply': 'Admin Reply',
      'noAdminReply': 'No admin reply yet',
      'ticketCreated': 'Ticket created',
      'ticketUpdated': 'Ticket updated',
      'admin': 'Admin',
      'noAuditLogs': 'No audit logs',
      'privacyPolicy': 'Privacy policy',
      'termsAndConditions': 'Terms & conditions',
      'deleteAccount': 'Delete account',
      'about': 'About',
      'errorNoInternet': 'No internet connection',
      'errorInvalidEmail': 'Enter a valid email address',
      'errorInvalidPhone': 'Enter a valid phone number',
      'errorRequired': 'This field is required',
      'errorInvalidAmount': 'Enter a valid amount',
    },
    'te': {
      'appName': 'బుక్‌మైస్‌పేస్',
      'tagline': 'మీ స్థలాన్ని కనుగొని బుక్ చేసుకోండి',
      'retry': 'తిరిగి ప్రయత్నించండి',
      'cancel': 'రద్దు చేయండి',
      'confirm': 'నిర్ధారించండి',
      'save': 'సేవ్ చేయండి',
      'delete': 'తొలగించండి',
      'search': 'వెతకండి',
      'loading': 'లోడ్ అవుతోంది…',
      'next': 'తరువాత',
      'back': 'వెనుకకు',
      'done': 'పూర్తయింది',
      'edit': 'సవరించండి',
      'viewAll': 'అన్నీ చూడండి',
      'noResults': 'ఫలితాలు లేవు',
      'noResultsMessage': 'మీ ఫిల్టర్లు లేదా శోధన పదాన్ని మార్చండి.',
      'offline': 'మీరు ఆఫ్‌లైన్‌లో ఉన్నారు',
      'offlineMessage': 'ఇంటర్నెట్ కనెక్షన్ తనిఖీ చేసి మళ్లీ ప్రయత్నించండి.',
      'unknownError': 'ఏదో తప్పు జరిగింది',
      'somethingWentWrong':
          'ఊహించని లోపం సంభవించింది. దయచేసి మళ్లీ ప్రయత్నించండి.',
      'tryAgain': 'మళ్లీ ప్రయత్నించండి',
      'onboardingTitle1': 'వేదికలను కనుగొనండి',
      'onboardingSubtitle1':
          'మీ సమీపంలో ఫంక్షన్ హాల్స్, మ్యారేజ్ హాల్స్, మీటింగ్ రూమ్స్ కనుగొనండి.',
      'onboardingTitle2': 'సెకన్లలో బుక్ చేయండి',
      'onboardingSubtitle2':
          'లైవ్ అందుబాటును తనిఖీ చేసి, స్లాట్ ఎంచుకుని సురక్షితంగా చెల్లించండి.',
      'onboardingTitle3': 'అన్నింటినీ నిర్వహించండి',
      'onboardingSubtitle3':
          'బుకింగ్‌లను ట్రాక్ చేయండి, నోటిఫికేషన్లు పొందండి.',
      'getStarted': 'ప్రారంభించండి',
      'skip': 'దాటవేయి',
      'navHome': 'హోమ్',
      'navSearch': 'శోధన',
      'navBookings': 'బుకింగ్స్',
      'navSaved': 'సేవ్డ్',
      'navExplore': 'అన్వేషించండి',
      'navChat': 'చాట్',
      'navProfile': 'ప్రొఫైల్',
      'venues': 'వేదికలు',
      'venueDetails': 'వేదిక వివరాలు',
      'amenities': 'సౌకర్యాలు',
      'capacity': 'సామర్థ్యం',
      'operatingHours': 'పని వేళలు',
      'pricing': 'ధర',
      'ratings': 'రేటింగ్స్',
      'reviews': 'సమీక్షలు',
      'checkAvailability': 'అందుబాటు తనిఖీ',
      'bookNow': 'ఇప్పుడే బుక్ చేయండి',
      'nearbyVenues': 'సమీప వేదికలు',
      'popularVenues': 'ప్రసిద్ధ వేదికలు',
      'homeGreeting': 'నమస్తే',
      'findYourSpace': 'మీ స్థలాన్ని కనుగొనండి',
      'whatAreYouLookingFor': 'మీరు ఏమి వెతుకుతున్నారు?',
      'saveVenue': 'వేదికను సేవ్ చేయండి',
      'savedVenues': 'సేవ్ చేసిన వేదికలు',
      'noSavedVenues': 'ఇంకా సేవ్ చేసిన వేదికలు లేవు',
      'noSavedVenuesMessage':
          'ఏదైనా వేదికపై హార్ట్‌పై నొక్కితే ఇక్కడ కనిపిస్తుంది.',
      'filters': 'ఫిల్టర్లు',
      'clearFilters': 'అన్నీ క్లియర్ చేయండి',
      'sortBy': 'క్రమబద్ధీకరించండి',
      'relevance': 'ఔచిత్యం',
      'priceLowToHigh': 'ధర: తక్కువ నుండి ఎక్కువ',
      'priceHighToLow': 'ధర: ఎక్కువ నుండి తక్కువ',
      'topRated': 'అత్యధిక రేటింగ్',
      'minPrice': 'కనిష్ట ధర',
      'maxPrice': 'గరిష్ట ధర',
      'allCategories': 'అన్ని వర్గాలు',
      'apply': 'వర్తించు',
      'nearest': 'దగ్గరి',
      'useMyLocation': 'నా లొకేషన్ ఉపయోగించండి',
      'resultsCount': '{count} వేదికలు దొరికాయి',
      'aboutThisVenue': 'ఈ వేదిక గురించి',
      'details': 'వివరాలు',
      'address': 'చిరునామా',
      'openNow': 'ఇప్పుడు తెరిచి ఉంది',
      'closedNow': 'మూసివేయబడింది',
      'foodOptions': 'ఆహార ఎంపికలు',
      'rules': 'నిబంధనలు',
      'parking': 'పార్కింగ్',
      'taxRate': 'GST',
      'basePrice': 'ప్రాథమిక ధర',
      'discount': 'తగ్గింపు',
      'viewOnMap': 'మ్యాప్‌లో చూడండి',
      'gallery': 'గ్యాలరీ',
      'explore': 'అన్వేషించండి',
      'events': 'ఈవెంట్స్',
      'courses': 'కోర్సులు',
      'searchHint': 'వేదికలు, ప్రాంతాలు, వర్గాలను వెతకండి…',
      'upcomingEvents': 'రాబోయే ఈవెంట్స్',
      'noUpcomingEvents': 'రాబోయే ఈవెంట్స్ లేవు',
      'noUpcomingEventsMessage':
          'సంస్థలు ప్రచురించిన కొత్త ఈవెంట్స్ ఇక్కడ కనిపిస్తాయి.',
      'freeEvent': 'ఉచితం',
      'registerNow': 'ఇప్పుడే నమోదు చేయండి',
      'registered': 'నమోదు చేయబడింది',
      'seatsLeft': '{count} సీట్లు మిగిలి ఉన్నాయి',
      'soldOut': 'అన్నీ అమ్ముడయ్యాయి',
      'yourTicket': 'మీ టికెట్',
      'cancelRegistration': 'నమోదు రద్దు చేయండి',
      'cancelRegistrationConfirm':
          'ఈ ఈవెంట్‌కు మీ నమోదును రద్దు చేయాలా? మీ సీటు విడుదల అవుతుంది.',
      'registrationCancelled': 'నమోదు రద్దు చేయబడింది',
      'searchEvents': 'ఈవెంట్లు, వేదికలు, వర్గాలు శోధించండి…',
      'allEvents': 'అన్నీ',
      'paidEvent': 'చెల్లింపు',
      'noCourses': 'ఇంకా కోర్సులు లేవు',
      'noCoursesMessage':
          'ధృవీకరించబడిన సంస్థల నుండి కోర్సులు ప్రచురించినప్పుడు ఇక్కడ కనిపిస్తాయి.',
      'enrollNow': 'ఇప్పుడే చేరండి',
      'enrolled': 'చేరారు',
      'enrollInCourse': 'కోర్సులో చేరండి',
      'courseFee': 'కోర్సు ఫీజు',
      'durationWeeks': '{weeks} వారాలు',
      'instructor': 'బోధకుడు',
      'batchStartsOn': 'ప్రారంభం',
      'modeOnline': 'ఆన్‌లైన్',
      'modeOffline': 'ఆఫ్‌లైన్',
      'modeHybrid': 'హైబ్రిడ్',
      'dropEnrollment': 'చేరికను వదిలివేయండి',
      'dropEnrollmentConfirm':
          'ఈ బ్యాచ్‌లో మీ చేరికను వదిలివేయాలా? మీ సీటు విడుదల అవుతుంది.',
      'enrollmentDropped': 'చేరిక విడిచిపెట్టబడింది',
      'searchCourses': 'కోర్సులు, సంస్థలు, బోధకులు శోధించండి…',
      'allModes': 'అన్నీ',
      'demoSession': 'డెమో',
      'paidCourse': 'చెల్లింపు',
      'searchInstitutes': 'సంస్థలు మరియు తరగతులు శోధించండి…',
      'institutesAndClasses': 'సంస్థలు & తరగతులు',
      'noInstitutes': 'ఇంకా సంస్థలు లేవు',
      'noInstitutesMessage':
          'యజమానులు ప్రచురించినప్పుడు ధృవీకరించిన సంస్థలు ఇక్కడ కనిపిస్తాయి.',
      'verifiedOnly': 'ధృవీకరించినవి మాత్రమే',
      'unifiedRegistration': 'ఏకీకృత నమోదు',
      'unifiedRegistrationHint':
          'ప్రతి మాడ్యూల్‌కు ఒక నమోదు ప్రవేశం. ఫీల్డ్‌లు స్థానిక జాబితా నుండి కాకుండా సుపాబేస్‌లోని నిర్వాహక ఫారమ్‌ల నుండి వస్తాయి.',
      'selectDate': 'తేదీని ఎంచుకోండి',
      'selectTimeSlot': 'టైమ్ స్లాట్ ఎంచుకోండి',
      'availability': 'అందుబాటు',
      'confirmBooking': 'బుకింగ్ నిర్ధారించండి',
      'bookingSummary': 'బుకింగ్ సారాంశం',
      'bookingDetails': 'ఈ బుకింగ్ కోసం మీ వివరాలు',
      'eventType': 'ఈవెంట్ రకం',
      'guestName': 'అతిథి పేరు',
      'tenantName': 'అద్దెదారు పేరు',
      'idNumber': 'ఐడి నంబర్ (ఆధార్ / పాస్‌పోర్ట్)',
      'payment': 'చెల్లింపు',
      'payNow': 'ఇప్పుడే చెల్లించండి',
      'paymentMethod': 'చెల్లింపు విధానం',
      'payAtVenue': 'వేదిక వద్ద చెల్లించండి',
      'bookAgain': 'మళ్లీ బుక్ చేయండి',
      'paymentSuccess': 'చెల్లింపు విజయవంతమైంది',
      'paymentFailed': 'చెల్లింపు విఫలమైంది',
      'paymentPending': 'చెల్లింపు పెండింగ్‌లో ఉంది',
      'paymentCancelled':
          'చెల్లింపు రద్దు చేయబడింది. మీరు మళ్లీ ప్రయత్నించవచ్చు.',
      'verifyingPayment': 'మీ చెల్లింపు ధృవీకరిస్తోంది…',
      'paymentPendingMessage':
          'చెల్లింపు అందింది. మీ బుకింగ్‌ను నిర్ధారిస్తున్నాము.',
      'requestRefund': 'వాపసు అభ్యర్థించండి',
      'requestRefundConfirm':
          'ఈ బుకింగ్‌కు పూర్తి వాపసు అభ్యర్థించాలా? దీన్ని రద్దు చేయలేము.',
      'refundRequested':
          'వాపసు అభ్యర్థించబడింది — త్వరలో ప్రాసెస్ చేయబడుతుంది.',
      'myBookings': 'నా బుకింగ్స్',
      'noSlotsForDate': 'ఈ తేదీన స్లాట్‌లు అందుబాటులో లేవు',
      'total': 'మొత్తం',
      'promoCode': 'ప్రోమో కోడ్',
      'promoCodeHint': 'ప్రోమో కోడ్ నమోదు చేయండి',
      'promoCodeApplied': 'ప్రోమో వర్తించబడింది',
      'remove': 'తీసివేయి',
      'bookingConfirmed': 'బుకింగ్ నిర్ధారించబడింది —',
      'noBookings': 'ఇంకా బుకింగ్స్ లేవు',
      'noBookingsMessage':
          'మీరు వేదికను బుక్ చేసినప్పుడు అది ఇక్కడ కనిపిస్తుంది.',
      'cancelBooking': 'బుకింగ్ రద్దు చేయండి',
      'cancelBookingConfirm': 'మీరు ఈ బుకింగ్‌ను రద్దు చేయాలనుకుంటున్నారా?',
      'keep': 'బుకింగ్ ఉంచండి',
      'invoice': 'ఇన్వాయిస్',
      'viewInvoice': 'ఇన్వాయిస్ చూడండి',
      'invoiceFor': 'బుకింగ్ ఇన్వాయిస్',
      'invoiceEmailQueued':
          'మీ ఖాతా ఇమెయిల్‌కు ఇన్వాయిస్ ఇమెయిల్ క్యూ చేయబడింది. డెలివరీ సర్వర్ అవుట్‌బాక్స్ నిర్వహిస్తుంది.',
      'invoiceEmailNotQueued':
          'ఖాతా ఇమెయిల్ లేదు, కాబట్టి ఏమీ క్యూ కాలేదు. PDF డౌన్‌లోడ్ చేయండి.',
      'bookingRef': 'బుకింగ్ రిఫరెన్స్',
      'bookingStatus': 'స్థితి',
      'dateOfBooking': 'బుకింగ్ తేదీ',
      'customer': 'కస్టమర్',
      'guestCount': 'అతిథులు',
      'checkIn': 'చెక్-ఇన్',
      'checkOut': 'చెక్-అవుట్',
      'moveIn': 'మూవ్-ఇన్',
      'sharingOption': 'షేరింగ్ ఎంపిక',
      'rent': 'అద్దె',
      'deposit': 'డిపాజిట్',
      'changeSharing': 'షేరింగ్ మార్చండి',
      'monthlyRentCalculator': 'నెలవారీ అద్దె కాలిక్యులేటర్',
      'selectRoomSharing': 'రూమ్ షేరింగ్ ఎంచుకోండి',
      'stayDuration': 'బస వ్యవధి',
      'perMonth': '/నెల',
      'monthlyPayable': 'నెలవారీ చెల్లింపు',
      'refundableSecurityDeposit': 'వాపసు అయ్యే డిపాజిట్',
      'estimatedTotalMoveIn': 'అంచనా మూవ్-ఇన్ మొత్తం',
      'monthCount': '{count} నెల',
      'monthsCount': '{count} నెలలు',
      'totalRentForTenure': 'మొత్తం అద్దె ({count} నెల)',
      'maintenanceCharges': 'నిర్వహణ ({count} నెల)',
      'slotHeld':
          'స్లాట్ 10 నిమిషాలు రిజర్వ్ చేయబడింది. నిర్ధారించడానికి చెల్లించండి.',
      'payMethod': 'చెల్లింపు విధానం',
      'onlinePayment': 'ఆన్‌లైన్ (Razorpay)',
      'offlinePayment': 'ఆఫ్‌లైన్ (వాక్-ఇన్)',
      'paidOn': 'చెల్లించిన తేదీ',
      'paymentRef': 'చెల్లింపు రిఫరెన్స్',
      'paymentHistory': 'చెల్లింపు చరిత్ర',
      'noPaymentHistory': 'పూర్తయిన చెల్లింపులు లేవు',
      'noPaymentHistoryMessage': 'మీ విజయవంతమైన లావాదేవీలు ఇక్కడ కనిపిస్తాయి.',
      'transactionSummary': 'లావాదేవీ సారాంశం',
      'razorpayTransactionId': 'రేజర్‌పే లావాదేవీ ID',
      'razorpayOrderId': 'రేజర్‌పే ఆర్డర్ ID',
      'bookingId': 'బుకింగ్ ID',
      'walkIn': 'వాక్-ఇన్',
      'statusHeld': 'రిజర్వ్ చేయబడింది',
      'statusPending': 'పెండింగ్',
      'statusConfirmed': 'నిర్ధారించబడింది',
      'statusCompleted': 'పూర్తయింది',
      'statusCancelled': 'రద్దు చేయబడింది',
      'statusRefunded': 'వాపసు చేయబడింది',
      'statusNoShow': 'నో-షో',
      'statusPendingOwnerApproval': 'ఆమోదం కోసం వేచి ఉంది',
      'statusRejected': 'తిరస్కరించబడింది',
      'slotBooked': 'బుక్ చేయబడింది',
      'slotUnavailable': 'అందుబాటులో లేదు',
      'slotBlocked': 'బ్లాక్ చేయబడింది',
      'slotClosed': 'మూసివేయబడింది',
      'listingOnly': 'లిస్టింగ్ మాత్రమే',
      'listingOnlyMessage':
          'ఇన్‌స్టిట్యూట్లు మరియు క్లాసులు ప్రకటనల లిస్టింగ్‌లు. వివరాల పేజీ నుండి కాల్ లేదా వాట్సాప్ ఉపయోగించండి.',
      'call': 'కాల్',
      'whatsapp': 'వాట్సాప్',
      'callingVenue': '{name} కు కాల్ చేస్తోంది…',
      'openingWhatsApp': '{name} కోసం వాట్సాప్ తెరుస్తోంది…',
      'digitalEntryPass': 'డిజిటల్ ఎంట్రీ పాస్',
      'viewEntryPass': 'ఎంట్రీ పాస్ / QR చూడండి',
      'entryPassHint':
          'తక్షణ చెక్-ఇన్ ధృవీకరణ కోసం వేదిక ప్రవేశ ద్వారం వద్ద ఈ QR పాస్ చూపించండి.',
      'openInGoogleMaps': 'Google మ్యాప్స్‌లో తెరవండి',
      'ownerBookings': 'యజమాని బుకింగ్స్',
      'newOfflineBooking': 'కొత్త ఆఫ్‌లైన్ బుకింగ్',
      'offlineBooking': 'ఆఫ్‌లైన్ బుకింగ్',
      'createOfflineBooking': 'ఆఫ్‌లైన్ బుకింగ్ సృష్టించండి',
      'customerName': 'కస్టమర్ పేరు',
      'customerPhone': 'కస్టమర్ ఫోన్',
      'selectVenue': 'వేదికను ఎంచుకోండి',
      'noOwnerBookings': 'మీ వేదికలకు ఇంకా బుకింగ్స్ లేవు',
      'noOwnerVenuesMessage':
          'బుకింగ్స్ నిర్వహించడానికి మీకు కనీసం ఒక వేదిక అవసరం.',
      'completeBooking': 'పూర్తి చేసినట్లు గుర్తించండి',
      'markNoShow': 'నో-షో గుర్తించండి',
      'approveBooking': 'ఆమోదించండి',
      'rejectBooking': 'తిరస్కరించండి',
      'approveBookingConfirm':
          'ఈ బుకింగ్‌ను ఆమోదించాలా? కస్టమర్‌కు తెలియజేయబడుతుంది మరియు బుకింగ్ నిర్ధారించబడుతుంది.',
      'rejectBookingConfirm':
          'ఈ బుకింగ్‌ను తిరస్కరించాలా? కస్టమర్ ఆన్‌లైన్‌లో చెల్లించి ఉంటే, రీఫండ్ స్వయంచాలకంగా అభ్యర్థించబడుతుంది.',
      'bookingApproved': 'బుకింగ్ ఆమోదించబడింది',
      'bookingRejected': 'బుకింగ్ తిరస్కరించబడింది',
      'bookingRejectedRefundRequested':
          'బుకింగ్ తిరస్కరించబడింది. రీఫండ్ అభ్యర్థించబడింది.',
      'login': 'లాగిన్',
      'signUp': 'సైన్ అప్',
      'logout': 'లాగ్ అవుట్',
      'email': 'ఇమెయిల్',
      'phone': 'ఫోన్',
      'name': 'పేరు',
      'password': 'పాస్‌వర్డ్',
      'continueWithGoogle': 'Google తో కొనసాగండి',
      'continueWithApple': 'Apple తో కొనసాగండి',
      'myProfile': 'నా ప్రొఫైల్',
      'signInWithEmailOtp': 'ఇమెయిల్ OTP తో లాగిన్ అవ్వండి',
      'signInWithPhoneOtp': 'ఫోన్ OTP తో లాగిన్ అవ్వండి',
      'otpPlaceholder': '6 అంకెల కోడ్',
      'verifyOtp': 'ధృవీకరించి లాగిన్ అవ్వండి',
      'sendOtp': 'కోడ్ పంపండి',
      'resendOtp': 'కోడ్ మళ్లీ పంపండి',
      'otpSent': 'మేము మీకు ధృవీకరణ కోడ్ పంపాము.',
      'authFailed': 'ప్రమాణీకరణ విఫలమైంది. దయచేసి మళ్లీ ప్రయత్నించండి.',
      'ownerDashboard': 'యజమాని డాష్‌బోర్డ్',
      'myVenues': 'నా వేదికలు',
      'createVenue': 'వేదికను సృష్టించండి',
      'ownerVenues': 'యజమాని వేదికలు',
      'ownerRequests': 'బుకింగ్ అభ్యర్థనలు',
      'ownerCalendar': 'క్యాలెండర్',
      'earnings': 'ఆదాయాలు',
      'addVenue': 'వేదికను జోడించండి',
      'settings': 'సెట్టింగ్స్',
      'language': 'భాష',
      'themeMode': 'థీమ్',
      'notifications': 'నోటిఫికేషన్లు',
      'analytics': 'విశ్లేషణ',
      'support': 'సహాయం',
      'auditLog': 'ఆడిట్ లాగ్',
      'priority': 'ప్రాధాన్యత',
      'noNotifications': 'నోటిఫికేషన్లు లేవు',
      'noNotificationsMessage': 'నోటిఫికేషన్లు వచ్చినప్పుడు ఇక్కడ కనిపిస్తాయి.',
      'markAllRead': 'అన్నీ చదివినట్లు గుర్తించండి',
      'unread': 'చదలపడలేదు',
      'noAnalyticsData': 'విశ్లేషణ డేటా లేదు',
      'noSupportTickets': 'సహాయ టికెట్లు లేవు',
      'newTicket': 'కొత్త టికెట్',
      'resolved': 'పరిష్కరించబడింది',
      'open': 'తెరగింది',
      'inProgress': 'ప్రక్రియలో',
      'closed': 'మూసివేయబడింది',
      'adminReply': 'నిర్వాహక స్పందన',
      'noAdminReply': 'ఇంకా నిర్వాహక స్పందన లేదు',
      'ticketCreated': 'టికెట్ సృష్టించబడింది',
      'ticketUpdated': 'టికెట్ నవీకరించబడింది',
      'admin': 'నిర్వాహకుడు',
      'noAuditLogs': 'ఆడిట్ లాగ్లు లేవు',
      'privacyPolicy': 'గోప్యతా విధానం',
      'termsAndConditions': 'నిబంధనలు & షరతులు',
      'deleteAccount': 'ఖాతాను తొలగించండి',
      'about': 'గురించి',
      'errorNoInternet': 'ఇంటర్నెట్ కనెక్షన్ లేదు',
      'errorInvalidEmail': 'చెల్లుబాటు అయ్యే ఇమెయిల్ నమోదు చేయండి',
      'errorInvalidPhone': 'చెల్లుబాటు అయ్యే ఫోన్ నంబర్ నమోదు చేయండి',
      'errorRequired': 'ఈ ఫీల్డ్ అవసరం',
      'errorInvalidAmount': 'చెల్లుబాటు అయ్యే మొత్తం నమోదు చేయండి',
      'authUnavailable': 'ప్రమాణీకరణ ప్రస్తుతం అందుబాటులో లేదు.',
      'signInHint':
          'ఇమెయిల్ లేదా ఫోన్‌తో సైన్ ఇన్ చేయండి. అదనపు వివరాలు మీరు బుక్ చేసినప్పుడు మాత్రమే అడుగుతాము.',
      'orDivider': 'లేదా',
      'createProfile': 'ప్రొఫైల్ సృష్టించండి',
      'quickBookingMode': 'క్విక్ బుకింగ్ మోడ్',
      'bookingDisabledForCategory': 'ఈ వర్గానికి బుకింగ్ నిలిపివేయబడింది',
      'availabilityDisabledForCategory': 'ఈ వర్గానికి అందుబాటు నిలిపివేయబడింది',
      'notAnOwner': 'యజమాని కాదు',
      'registerAsOwnerHint':
          'డాష్‌బోర్డ్‌ను యాక్సెస్ చేయడానికి యజమానిగా నమోదు చేసుకోండి.',
      'instituteOwnerPortal': 'ఇన్‌స్టిట్యూట్ యజమాని పోర్టల్',
      'createInstitute': 'ఇన్‌స్టిట్యూట్ సృష్టించండి',
      'addClass': 'క్లాస్ జోడించండి',
      'addFaculty': 'ఫ్యాకల్టీ జోడించండి',
      'plans': 'ప్లాన్లు',
      'faculty': 'ఫ్యాకల్టీ',
      'classes': 'క్లాసులు',
      'verifiedInstitute': 'ధృవీకరించబడిన ఇన్‌స్టిట్యూట్',
      'noGalleryYet': 'ఇంకా గ్యాలరీ చిత్రాలు లేవు.',
      'facultyPlaceholder': 'ఫ్యాకల్టీ ప్రొఫైల్స్ ఇక్కడ కనిపిస్తాయి.',
      'noPublishedClasses': 'ఇంకా ప్రచురించిన క్లాసులు లేవు.',
      'saveDraft': 'డ్రాఫ్ట్ సేవ్ చేయండి',
      'allFilters': 'అన్ని ఫిల్టర్లు',
      'verifiedResults': 'ధృవీకరించిన ఫలితాలు',
      'recommended': 'సిఫార్సు',
      'clearDate': 'తేదీ క్లియర్ చేయండి',
      'clearDates': 'తేదీలు క్లియర్ చేయండి',
      'add': 'జోడించండి',
      'filtersHint': 'ప్రాంతం, ధర, రేటింగ్, సామర్థ్యం మరియు సౌకర్యాలు',
      'otpSentResendIn': 'ధృవీకరణ కోడ్ పంపబడింది. {seconds}సెలో మళ్లీ పంపండి',
      'otpResendIn': '{seconds}సెలో మళ్లీ పంపండి',
      'qrCheckIn': 'QR చెక్-ఇన్',
      'locationSubmissions': 'లొకేషన్ సమర్పణలు',
      'institutePortal': 'ఇన్‌స్టిట్యూట్ పోర్టల్',
      'noInstituteProfile': 'ఇన్‌స్టిట్యూట్ ప్రొఫైల్ లేదు',
      'createInstituteHint':
          'క్లాసులు, ఫ్యాకల్టీ మరియు గ్యాలరీ ప్రచురించడానికి ఇన్‌స్టిట్యూట్ సృష్టించండి.',
      'editInstitute': 'ఇన్‌స్టిట్యూట్‌ను సవరించండి',
      'description': 'వివరణ',
      'city': 'నగరం',
      'specialization': 'ప్రత్యేకత',
      'classTitle': 'శీర్షిక',
      'fee': 'ఫీజు',
      'deliveryMode': 'డెలివరీ మోడ్',
      'classesAndCourses': 'క్లాసులు & కోర్సులు',
      'hotels': 'హోటళ్లు',
      'functionHalls': 'ఫంక్షన్ హాళ్లు',
      'inArea': '{area}లో {title}',
      'verifiedResultsCount': '{count} ధృవీకరించిన ఫలితాలు',
      'priceLow': 'ధర: తక్కువ',
      'priceHigh': 'ధర: ఎక్కువ',
      'fieldsRequired': 'అవసరం: {fields}',
      'verified': 'ధృవీకరించబడింది',
      'unverified': 'ధృవీకరించబడలేదు',
      'justNow': 'ఇప్పుడు',
      'minutesAgo': '{count}ని క్రితం',
      'hoursAgo': '{count}గం క్రితం',
      'daysAgo': '{count}రో క్రితం',
    },
    'hi': {
      'appName': 'बुकमाईस्पेस',
      'tagline': 'अपनी जगह खोजें और बुक करें',
      'retry': 'फिर कोशिश करें',
      'cancel': 'रद्द करें',
      'confirm': 'पुष्टि करें',
      'save': 'सहेजें',
      'search': 'खोजें',
      'loading': 'लोड हो रहा है…',
      'navHome': 'होम',
      'navSearch': 'खोज',
      'navBookings': 'बुकिंग',
      'navSaved': 'सेव्ड',
      'navExplore': 'एक्सप्लोर',
      'navChat': 'चैट',
      'navProfile': 'प्रोफ़ाइल',
      'bookNow': 'अभी बुक करें',
      'nearbyVenues': 'नज़दीकी स्थान',
      'myBookings': 'मेरी बुकिंग',
      'login': 'लॉग इन',
      'logout': 'लॉग आउट',
      'settings': 'सेटिंग्स',
      'language': 'भाषा',
      'notifications': 'सूचनाएँ',
      'ownerDashboard': 'मालिक डैशबोर्ड',
      'venues': 'स्थान',
      'payment': 'भुगतान',
      'payNow': 'अभी भुगतान करें',
      'paymentMethod': 'भुगतान का तरीका',
      'onlinePayment': 'ऑनलाइन भुगतान (Razorpay)',
      'payAtVenue': 'स्थान पर भुगतान करें',
      'confirmBooking': 'बुकिंग की पुष्टि करें',
      'bookAgain': 'फिर बुक करें',
      'checkIn': 'चेक-इन',
      'courses': 'कोर्स',
      'events': 'इवेंट्स',
      'support': 'सहायता',
      'admin': 'एडमिन',
      'searchEvents': 'इवेंट, स्थान, श्रेणियाँ खोजें…',
      'allEvents': 'सभी',
      'paidEvent': 'सशुल्क',
      'searchCourses': 'कोर्स, संस्थान, प्रशिक्षक खोजें…',
      'allModes': 'सभी',
      'demoSession': 'डेमो',
      'paidCourse': 'सशुल्क',
      'searchInstitutes': 'संस्थान और कक्षाएँ खोजें…',
      'institutesAndClasses': 'संस्थान और कक्षाएँ',
      'noInstitutes': 'अभी संस्थान नहीं हैं',
      'noInstitutesMessage':
          'मालिक प्रकाशित करने पर सत्यापित संस्थान यहाँ दिखते हैं।',
      'verifiedOnly': 'केवल सत्यापित',
      'unifiedRegistration': 'एकीकृत पंजीकरण',
      'unifiedRegistrationHint':
          'हर मॉड्यूल के लिए एक पंजीकरण प्रवेश। फ़ील्ड सुपाबेस में एडमिन फ़ॉर्म से आते हैं, स्थानीय सूची से नहीं।',
      'invoiceEmailQueued':
          'आपके खाता ईमेल पर इनवॉइस ईमेल कतार में है। डिलीवरी सर्वर आउटबॉक्स करता है।',
      'invoiceEmailNotQueued':
          'खाता ईमेल नहीं है, इसलिए कुछ कतार में नहीं गया। PDF डाउनलोड करें।',
      'viewOnMap': 'मानचित्र पर देखें',
      'noResults': 'कोई परिणाम नहीं',
      'noResultsMessage': 'फ़िल्टर या खोज शब्द बदलकर देखें।',
      'freeEvent': 'मुफ़्त',
      'modeOnline': 'ऑनलाइन',
      'modeOffline': 'ऑफ़लाइन',
      'modeHybrid': 'हाइब्रिड',
      'authUnavailable': 'प्रमाणीकरण अभी उपलब्ध नहीं है।',
      'signInHint':
          'ईमेल या फ़ोन से साइन इन करें। अतिरिक्त विवरण बुकिंग के समय ही मांगे जाते हैं।',
      'orDivider': 'या',
      'createProfile': 'प्रोफ़ाइल बनाएँ',
      'quickBookingMode': 'त्वरित बुकिंग मोड',
      'bookingDisabledForCategory': 'इस श्रेणी के लिए बुकिंग बंद है',
      'availabilityDisabledForCategory': 'इस श्रेणी के लिए उपलब्धता बंद है',
      'notAnOwner': 'मालिक नहीं हैं',
      'registerAsOwnerHint':
          'डैशबोर्ड इस्तेमाल करने के लिए मालिक के रूप में पंजीकरण करें।',
      'instituteOwnerPortal': 'संस्थान मालिक पोर्टल',
      'createInstitute': 'संस्थान बनाएँ',
      'addClass': 'कक्षा जोड़ें',
      'addFaculty': 'फैकल्टी जोड़ें',
      'plans': 'प्लान',
      'faculty': 'फैकल्टी',
      'classes': 'कक्षाएँ',
      'verifiedInstitute': 'सत्यापित संस्थान',
      'noGalleryYet': 'अभी गैलरी चित्र नहीं हैं।',
      'facultyPlaceholder': 'फैकल्टी प्रोफ़ाइल यहाँ दिखेंगी।',
      'noPublishedClasses': 'अभी प्रकाशित कक्षाएँ नहीं हैं।',
      'saveDraft': 'ड्राफ़्ट सहेजें',
      'allFilters': 'सभी फ़िल्टर',
      'verifiedResults': 'सत्यापित परिणाम',
      'recommended': 'अनुशंसित',
      'clearDate': 'तारीख हटाएँ',
      'clearDates': 'तारीखें हटाएँ',
      'add': 'जोड़ें',
      'filtersHint': 'स्थान, कीमत, रेटिंग, क्षमता और सुविधाएँ',
      'otpSentResendIn': 'सत्यापन कोड भेजा गया। {seconds}से में फिर भेजें',
      'otpResendIn': '{seconds}से में फिर भेजें',
      'qrCheckIn': 'QR चेक-इन',
      'locationSubmissions': 'स्थान सबमिशन',
      'institutePortal': 'संस्थान पोर्टल',
      'noInstituteProfile': 'संस्थान प्रोफ़ाइल नहीं',
      'createInstituteHint':
          'कक्षाएँ, फैकल्टी और गैलरी प्रकाशित करने के लिए संस्थान बनाएँ।',
      'editInstitute': 'संस्थान संपादित करें',
      'description': 'विवरण',
      'city': 'शहर',
      'specialization': 'विशेषज्ञता',
      'classTitle': 'शीर्षक',
      'fee': 'शुल्क',
      'deliveryMode': 'डिलीवरी मोड',
      'classesAndCourses': 'कक्षाएँ और कोर्स',
      'hotels': 'होटल',
      'functionHalls': 'फ़ंक्शन हॉल',
      'inArea': '{area} में {title}',
      'verifiedResultsCount': '{count} सत्यापित परिणाम',
      'priceLow': 'कीमत: कम',
      'priceHigh': 'कीमत: अधिक',
      'fieldsRequired': 'आवश्यक: {fields}',
      'verified': 'सत्यापित',
      'unverified': 'असत्यापित',
      'justNow': 'अभी',
      'minutesAgo': '{count}मि पहले',
      'hoursAgo': '{count}घं पहले',
      'daysAgo': '{count}दि पहले',
    },
    'ta': {
      'appName': 'புக் மை ஸ்பேஸ்',
      'searchHint': 'மண்டபம், பிஜி, ஹோட்டல் தேடுக...',
      'search': 'தேடல்',
      'bookNow': 'இப்போது முன்பதிவு செய்',
      'cancel': 'ரத்துசெய்',
      'confirm': 'உறுதிசெய்',
      'save': 'சேமி',
      'navHome': 'முகப்பு',
      'navSearch': 'தேடல்',
      'navBookings': 'என் பதிவுகள்',
      'navSaved': 'சேமித்தவை',
      'navProfile': 'சுயவிவரம்',
      'reviews': 'விமர்சனங்கள்',
      'amenities': 'வசதிகள்',
      'capacity': 'கொள்திறன்',
      'pricing': 'விலை',
      'recentSearches': 'சமீபத்திய தேடல்கள்',
      'clearRecentSearches': 'அழி',
      'venueOptimizer': 'வென்யூ ஆப்டிமைசர்',
      'offline': 'நீங்கள் ஆஃப்லைனில் உள்ளீர்கள்',
      'language': 'மொழி',
      'login': 'உள்நுழை',
      'password': 'கடவுச்சொல்',
      'payNow': 'பணம் செலுத்து',
      'notifications': 'அறிவிப்புகள்',
      'call': 'அழை',
      'whatsapp': 'வாட்ஸ்அப்',
      'ownerDashboard': 'உரிமையாளர் தளம்',
      'createProfile': 'சுயவிவரம் உருவாக்கு',
      'orDivider': 'அல்லது',
      'notAnOwner': 'உரிமையாளர் அல்ல',
      'instituteOwnerPortal': 'நிறுவன உரிமையாளர் தளம்',
      'createInstitute': 'நிறுவனம் உருவாக்கு',
      'addClass': 'வகுப்பு சேர்',
      'allFilters': 'அனைத்து வடிகட்டிகள்',
      'recommended': 'பரிந்துரைக்கப்பட்டவை',
      'noResults': 'முடிவுகள் இல்லை',
      'filters': 'வடிகட்டி',
      'verified': 'சரிபார்க்கப்பட்டது',
      'hotels': 'ஹோட்டல்கள்',
      'functionHalls': 'மண்டபங்கள்',
      'qrCheckIn': 'QR செக்-இன்',
      'quickBookingMode': 'விரைவு புக்கிங்',
    },
    'kn': {
      'appName': 'ಬುಕ್ ಮೈ ಸ್ಪೇಸ್',
      'searchHint': 'ಫಂಕ್ಷನ್ ಹಾಲ್, ಪಿಜಿ, ಹೋಟೆಲ್ ಹುಡುಕಿ...',
      'search': 'ಹುಡುಕಿ',
      'bookNow': 'ಈಗಲೇ ಬುಕ್ ಮಾಡಿ',
      'cancel': 'ರದ್ದುಮಾಡಿ',
      'confirm': 'ಖಚಿತಪಡಿಸಿ',
      'save': 'ಉಳಿಸಿ',
      'navHome': 'ಹೋಮ್',
      'navSearch': 'ಹುಡುಕಿ',
      'navBookings': 'ನನ್ನ ಬುಕಿಂಗ್‌ಗಳು',
      'navSaved': 'ಉಳಿಸಿದವು',
      'navProfile': 'ಪ್ರೊಫೈಲ್',
      'reviews': 'ವಿಮರ್ಶೆಗಳು',
      'amenities': 'ಸೌಲಭ್ಯಗಳು',
      'capacity': 'ಸಾಮರ್ಥ್ಯ',
      'pricing': 'ಬೆಲೆ',
      'recentSearches': 'ಇತ್ತೀಚಿನ ಹುಡುಕಾಟಗಳು',
      'clearRecentSearches': 'ತೆರವುಗೊಳಿಸಿ',
      'venueOptimizer': 'ವೆನ್ಯೂ ಆಪ್ಟಿಮೈಜರ್',
      'offline': 'ನೀವು ಆಫ್‌ಲೈನ್‌ನಲ್ಲಿದ್ದೀರಿ',
      'language': 'ಭಾಷೆ',
      'login': 'ಲಾಗಿನ್',
      'password': 'ಪಾಸ್‌ವರ್ಡ್',
      'payNow': 'ಈಗ ಪಾವತಿಸಿ',
      'notifications': 'ಅಧಿಸೂಚನೆಗಳು',
      'call': 'ಕರೆ',
      'whatsapp': 'ವಾಟ್ಸಾಪ್',
      'ownerDashboard': 'ಮಾಲೀಕರ ಡ್ಯಾಶ್‌ಬೋರ್ಡ್',
      'createProfile': 'ಪ್ರೊಫೈಲ್ ರಚಿಸಿ',
      'orDivider': 'ಅಥವಾ',
      'notAnOwner': 'ಮಾಲೀಕರಲ್ಲ',
      'instituteOwnerPortal': 'ಸಂಸ್ಥೆ ಮಾಲೀಕರ ಪೋರ್ಟಲ್',
      'createInstitute': 'ಸಂಸ್ಥೆ ರಚಿಸಿ',
      'addClass': 'ತರಗತಿ ಸೇರಿಸಿ',
      'allFilters': 'ಎಲ್ಲಾ ಫಿಲ್ಟರ್‌ಗಳು',
      'recommended': 'ಶಿಫಾರಸು',
      'noResults': 'ಫಲಿತಾಂಶಗಳಿಲ್ಲ',
      'filters': 'ಫಿಲ್ಟರ್',
      'verified': 'ಪರಿಶೀಲಿಸಲಾಗಿದೆ',
      'hotels': 'ಹೋಟೆಲ್‌ಗಳು',
      'functionHalls': 'ಫಂಕ್ಷನ್ ಹಾಲ್‌ಗಳು',
      'qrCheckIn': 'QR ಚೆಕ್-ಇನ್',
      'quickBookingMode': 'ಕ್ವಿಕ್ ಬುಕಿಂಗ್',
    },
    'mr': {
      'appName': 'बुक माय स्पेस',
      'searchHint': 'हॉल, पीजी, हॉटेल शोधा...',
      'search': 'शोधा',
      'bookNow': 'आत्ताच बुक करा',
      'cancel': 'रद्द करा',
      'confirm': 'नक्की करा',
      'save': 'सेव्ह करा',
      'navHome': 'होम',
      'navSearch': 'शोधा',
      'navBookings': 'माझ्या बुकिंग्स',
      'navSaved': 'सेव्ह केलेले',
      'navProfile': 'प्रोफाइल',
      'reviews': 'समीक्षा',
      'amenities': 'सुविधा',
      'capacity': 'क्षमता',
      'pricing': 'किंमत',
      'recentSearches': 'अलीकडील शोध',
      'clearRecentSearches': 'साफ करा',
      'venueOptimizer': 'Venue Optimizer',
      'offline': 'तुम्ही ऑफलाइन आहात',
      'language': 'भाषा',
      'login': 'लॉग इन',
      'password': 'पासवर्ड',
      'payNow': 'आत्ताच पैसे द्या',
      'notifications': 'सूचना',
      'call': 'कॉल',
      'whatsapp': 'व्हॉट्सॲप',
      'ownerDashboard': 'मालक डॅशबोर्ड',
      'createProfile': 'प्रोफाइल तयार करा',
      'orDivider': 'किंवा',
      'notAnOwner': 'मालक नाही',
      'instituteOwnerPortal': 'संस्था मालक पोर्टल',
      'createInstitute': 'संस्था तयार करा',
      'addClass': 'क्लास जोडा',
      'allFilters': 'सर्व फिल्टर',
      'recommended': 'शिफारस',
      'noResults': 'निकाल नाहीत',
      'filters': 'फिल्टर',
      'verified': 'सत्यापित',
      'hotels': 'हॉटेल्स',
      'functionHalls': 'फंक्शन हॉल',
      'qrCheckIn': 'QR चेक-इन',
      'quickBookingMode': 'क्विक बुकिंग',
    },
    'bn': {
      'appName': 'বুক মাই স্পেস',
      'searchHint': 'ভেন্যু, পিজি, হোটেল খুঁজুন...',
      'search': 'খুঁজুন',
      'bookNow': 'এখনই বুক করুন',
      'cancel': 'বাতিল করুন',
      'confirm': 'নিশ্চিত করুন',
      'save': 'সংরক্ষণ করুন',
      'navHome': 'হোম',
      'navSearch': 'খুঁজুন',
      'navBookings': 'আমার বুকিং',
      'navSaved': 'সংরক্ষিত',
      'navProfile': 'প্রোফাইল',
      'reviews': 'রিভিউ',
      'amenities': 'সুযোগ-সুবিধা',
      'capacity': 'ক্ষমতা',
      'pricing': 'মূল্য',
      'recentSearches': 'সাম্প্রতিক অনুসন্ধান',
      'clearRecentSearches': 'মুছুন',
      'venueOptimizer': 'Venue Optimizer',
      'offline': 'আপনি অফলাইন আছেন',
      'language': 'ভাষা',
      'login': 'লগ ইন',
      'password': 'পাসওয়ার্ড',
      'payNow': 'পেমেন্ট করুন',
      'notifications': 'বিজ্ঞপ্তি',
      'call': 'কল',
      'whatsapp': 'হোয়াটসঅ্যাপ',
      'ownerDashboard': 'মালিক ড্যাশবোর্ড',
      'createProfile': 'প্রোফাইল তৈরি করুন',
      'orDivider': 'অথবা',
      'notAnOwner': 'মালিক নন',
      'instituteOwnerPortal': 'ইনস্টিটিউট ওনার পোর্টাল',
      'createInstitute': 'ইনস্টিটিউট তৈরি করুন',
      'addClass': 'ক্লাস যোগ করুন',
      'allFilters': 'সব ফিল্টার',
      'recommended': 'সুপারিশকৃত',
      'noResults': 'কোনো ফলাফল নেই',
      'filters': 'ফিল্টার',
      'verified': 'যাচাইকৃত',
      'hotels': 'হোটেল',
      'functionHalls': 'ফাংশন হল',
      'qrCheckIn': 'QR চেক-ইন',
      'quickBookingMode': 'কুইক বুকিং',
    },
    'gu': {
      'appName': 'બુક માય સ્પેસ',
      'searchHint': 'હોલ, પીજી, હોટેલ શોધો...',
      'search': 'શોધો',
      'bookNow': 'હમણાં બુક કરો',
      'cancel': 'રદ કરો',
      'confirm': 'કન્ફર્મ કરો',
      'save': 'સેવ કરો',
      'navHome': 'હોમ',
      'navSearch': 'શોધો',
      'navBookings': 'મારી બુકિંગ',
      'navSaved': 'સેવ કરેલ',
      'navProfile': 'પ્રોફાઈલ',
      'reviews': 'રિવ્યુ',
      'amenities': 'સુવિધાઓ',
      'capacity': 'ક્ષમતા',
      'pricing': 'કિંમત',
      'recentSearches': 'તાજેતરની શોધ',
      'clearRecentSearches': 'સાફ કરો',
      'venueOptimizer': 'Venue Optimizer',
      'offline': 'તમે ઑફલાઇન છો',
      'language': 'ભાષા',
      'login': 'લોગિન',
      'password': 'પાસવર્ડ',
      'payNow': 'હમણાં ચૂકવો',
      'notifications': 'સૂચનાઓ',
      'call': 'કોલ',
      'whatsapp': 'વોટ્સએપ',
      'ownerDashboard': 'માલિક ડેશબોર્ડ',
      'createProfile': 'પ્રોફાઈલ બનાવો',
      'orDivider': 'અથવા',
      'notAnOwner': 'માલિક નથી',
      'instituteOwnerPortal': 'સંસ્થા માલિક પોર્ટલ',
      'createInstitute': 'સંસ્થા બનાવો',
      'addClass': 'ક્લાસ ઉમેરો',
      'allFilters': 'બધા ફિલ્ટર',
      'recommended': 'ભલામણ',
      'noResults': 'પરિણામ નથી',
      'filters': 'ફિલ્ટર',
      'verified': 'ચકાસાયેલ',
      'hotels': 'હોટેલ્સ',
      'functionHalls': 'ફંક્શન હોલ',
      'qrCheckIn': 'QR ચેક-ઇન',
      'quickBookingMode': 'ક્વિક બુકિંગ',
    },
    'ml': {
      'appName': 'ബുക്ക് മൈ സ്‌പേസ്',
      'searchHint': 'ഹാൾ, പിജി, ഹോട്ടൽ തിരയുക...',
      'search': 'തിരയുക',
      'bookNow': 'ഇപ്പോൾ ബുക്ക് ചെയ്യുക',
      'cancel': 'റദ്ദാക്കുക',
      'confirm': 'ഉറപ്പാക്കുക',
      'save': 'സേവ് ചെയ്യുക',
      'navHome': 'ഹോം',
      'navSearch': 'തിരയുക',
      'navBookings': 'എന്റെ ബുക്കിംഗുകൾ',
      'navSaved': 'സേവ് ചെയ്‌തവ',
      'navProfile': 'പ്രൊഫൈൽ',
      'reviews': 'അഭിപ്രായങ്ങൾ',
      'amenities': 'സൗകര്യങ്ങൾ',
      'capacity': 'ശേഷി',
      'pricing': 'വില',
      'recentSearches': 'സമീപകാല തിരച്ചിലുകൾ',
      'clearRecentSearches': 'മായ്ക്കുക',
      'venueOptimizer': 'Venue Optimizer',
      'offline': 'നിങ്ങൾ ഓഫ്‌ലൈനാണ്',
      'language': 'ഭാഷ',
      'login': 'ലോഗിൻ',
      'password': 'പാസ്‌വേഡ്',
      'payNow': 'ഇപ്പോൾ പണമടയ്ക്കുക',
      'notifications': 'അറിയിപ്പുകൾ',
      'call': 'വിളിക്കുക',
      'whatsapp': 'വാട്ട്‌സ്ആപ്പ്',
      'ownerDashboard': 'ഉടമ ഡാഷ്‌ബോർഡ്',
      'createProfile': 'പ്രൊഫൈൽ സൃഷ്ടിക്കുക',
      'orDivider': 'അല്ലെങ്കിൽ',
      'notAnOwner': 'ഉടമയല്ല',
      'instituteOwnerPortal': 'ഇൻസ്റ്റിറ്റ്യൂട്ട് ഉടമ പോർട്ടൽ',
      'createInstitute': 'ഇൻസ്റ്റിറ്റ്യൂട്ട് സൃഷ്ടിക്കുക',
      'addClass': 'ക്ലാസ് ചേർക്കുക',
      'allFilters': 'എല്ലാ ഫിൽട്ടറുകളും',
      'recommended': 'ശുപാർശ',
      'noResults': 'ഫലങ്ങളില്ല',
      'filters': 'ഫിൽട്ടർ',
      'verified': 'സ്ഥിരീകരിച്ചത്',
      'hotels': 'ഹോട്ടലുകൾ',
      'functionHalls': 'ഫംഗ്ഷൻ ഹാളുകൾ',
      'qrCheckIn': 'QR ചെക്ക്-ഇൻ',
      'quickBookingMode': 'ക്വിക്ക് ബുക്കിംഗ്',
    },
    'es': {
      'appName': 'BookMySpace',
      'searchHint': 'Buscar local, PG, hotel...',
      'search': 'Buscar',
      'bookNow': 'Reservar ahora',
      'cancel': 'Cancelar',
      'confirm': 'Confirmar',
      'save': 'Guardar',
      'navHome': 'Inicio',
      'navSearch': 'Buscar',
      'navBookings': 'Mis reservas',
      'navSaved': 'Guardados',
      'navProfile': 'Perfil',
      'reviews': 'Reseñas',
      'amenities': 'Comodidades',
      'capacity': 'Capacidad',
      'pricing': 'Precio',
      'recentSearches': 'Búsquedas recientes',
      'clearRecentSearches': 'Borrar',
      'venueOptimizer': 'Optimizador de locales',
      'offline': 'Estás sin conexión',
      'language': 'Idioma',
      'login': 'Iniciar sesión',
      'password': 'Contraseña',
      'payNow': 'Pagar ahora',
      'notifications': 'Notificaciones',
      'call': 'Llamar',
      'whatsapp': 'WhatsApp',
      'ownerDashboard': 'Panel del propietario',
      'createProfile': 'Crear un perfil',
      'orDivider': 'O',
      'notAnOwner': 'No es propietario',
      'instituteOwnerPortal': 'Portal del instituto',
      'createInstitute': 'Crear instituto',
      'addClass': 'Añadir clase',
      'allFilters': 'Todos los filtros',
      'recommended': 'Recomendados',
      'noResults': 'Sin resultados',
      'filters': 'Filtros',
      'verified': 'Verificado',
      'hotels': 'Hoteles',
      'functionHalls': 'Salones',
      'qrCheckIn': 'Check-in QR',
      'quickBookingMode': 'Reserva rápida',
    },
  };
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
