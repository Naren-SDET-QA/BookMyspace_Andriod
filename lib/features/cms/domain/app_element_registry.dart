/// Structured enum for UI element kinds.
enum UiElementType {
  text,
  image,
  field,
  color,
}

/// Rich definition of an editable element registered in the application.
class AppElementDefinition {
  const AppElementDefinition({
    required this.screenKey,
    required this.elementKey,
    required this.elementType,
    required this.label,
    required this.description,
    required this.fallback,
    this.editable = true,
    required this.category,
  });

  final String screenKey;
  final String elementKey;
  final UiElementType elementType;
  final String label;
  final String description;
  final String fallback;
  final bool editable;
  final String category;

  // Record accessor compatibility ($1 = elementKey, $2 = label, $3 = type string)
  String get $1 => elementKey;
  String get $2 => label;
  String get $3 => elementType.name;
}

/// Comprehensive registry of every screen and its editable UI elements.
///
/// This registry represents real customer and staff screens across the entire
/// application. Every registered element corresponds to a real UI placement
/// backed by fallback copy/image.
class AppElementRegistry {
  const AppElementRegistry._();

  static const List<AppElementDefinition> all = [
    // -------------------------------------------------------------
    // BRANDING
    // -------------------------------------------------------------
    AppElementDefinition(
      screenKey: 'branding',
      elementKey: 'app_name',
      elementType: UiElementType.text,
      label: 'App Name',
      description: 'Global application name displayed on headers, login, and splash',
      fallback: 'BookMySpace',
      category: 'Branding',
    ),
    AppElementDefinition(
      screenKey: 'branding',
      elementKey: 'tagline',
      elementType: UiElementType.text,
      label: 'Brand Tagline',
      description: 'Tagline displayed on splash and headers',
      fallback: 'Find your perfect space',
      category: 'Branding',
    ),
    AppElementDefinition(
      screenKey: 'branding',
      elementKey: 'logo_url',
      elementType: UiElementType.image,
      label: 'Light Logo Image',
      description: 'Primary logo image URL used on light backgrounds',
      fallback: '',
      category: 'Branding',
    ),
    AppElementDefinition(
      screenKey: 'branding',
      elementKey: 'logo_dark_url',
      elementType: UiElementType.image,
      label: 'Dark Logo Image',
      description: 'Logo image URL used in dark mode',
      fallback: '',
      category: 'Branding',
    ),
    AppElementDefinition(
      screenKey: 'branding',
      elementKey: 'splash_url',
      elementType: UiElementType.image,
      label: 'Splash Image',
      description: 'Brand artwork displayed during application launch',
      fallback: '',
      category: 'Branding',
    ),
    AppElementDefinition(
      screenKey: 'branding',
      elementKey: 'wordmark_first_color',
      elementType: UiElementType.color,
      label: 'Primary Wordmark Color',
      description: 'Accent color for brand wordmark (#3F51B5)',
      fallback: '#3F51B5',
      category: 'Branding',
    ),
    AppElementDefinition(
      screenKey: 'branding',
      elementKey: 'wordmark_rest_color',
      elementType: UiElementType.color,
      label: 'Secondary Wordmark Color',
      description: 'Secondary color for brand wordmark',
      fallback: '',
      category: 'Branding',
    ),

    // -------------------------------------------------------------
    // HOME
    // -------------------------------------------------------------
    AppElementDefinition(
      screenKey: 'home',
      elementKey: 'hero_title',
      elementType: UiElementType.text,
      label: 'Hero Title',
      description: 'Main promotional headline on the Home screen hero banner',
      fallback: 'Spaces for Every Moment',
      category: 'Home',
    ),
    AppElementDefinition(
      screenKey: 'home',
      elementKey: 'hero_subtitle',
      elementType: UiElementType.text,
      label: 'Hero Subtitle',
      description: 'Sub-headline on the Home screen hero banner',
      fallback: 'Function halls, education, stays and more.',
      category: 'Home',
    ),
    AppElementDefinition(
      screenKey: 'home',
      elementKey: 'hero_image',
      elementType: UiElementType.image,
      label: 'Hero Background Image',
      description: 'High-resolution hero banner background image URL',
      fallback: 'https://images.unsplash.com/photo-1519167758481-83f550bb49b3?auto=format&fit=crop&w=1200&q=80',
      category: 'Home',
    ),
    AppElementDefinition(
      screenKey: 'home',
      elementKey: 'search_placeholder',
      elementType: UiElementType.field,
      label: 'Search Field Hint',
      description: 'Search placeholder text in the Home intent search bar',
      fallback: 'What are you looking for?',
      category: 'Home',
    ),
    AppElementDefinition(
      screenKey: 'home',
      elementKey: 'search_button',
      elementType: UiElementType.text,
      label: 'Search CTA Button',
      description: 'Search action button text in the intent card',
      fallback: 'Search',
      category: 'Home',
    ),
    AppElementDefinition(
      screenKey: 'home',
      elementKey: 'tagline',
      elementType: UiElementType.text,
      label: 'Header Tagline',
      description: 'Header subtitle beneath the logo',
      fallback: 'Turfs • Halls • PGs • Studios',
      category: 'Home',
    ),
    AppElementDefinition(
      screenKey: 'home',
      elementKey: 'category_title',
      elementType: UiElementType.text,
      label: 'Category Section Title',
      description: 'Heading for popular category discovery blocks',
      fallback: 'Popular Categories',
      category: 'Home',
    ),
    AppElementDefinition(
      screenKey: 'home',
      elementKey: 'offer_title',
      elementType: UiElementType.text,
      label: 'Offer Banner Title',
      description: 'Heading for special discounts and promo code vouchers',
      fallback: 'Special Offers',
      category: 'Home',
    ),
    AppElementDefinition(
      screenKey: 'home',
      elementKey: 'banner_image',
      elementType: UiElementType.image,
      label: 'Offer Banner Artwork',
      description: 'Promotional voucher banner artwork URL',
      fallback: 'https://images.unsplash.com/photo-1519741497674-611481863552?auto=format&fit=crop&w=1200&q=80',
      category: 'Home',
    ),
    AppElementDefinition(
      screenKey: 'home',
      elementKey: 'view_all',
      elementType: UiElementType.text,
      label: 'View All Action',
      description: 'Action link for expanding category items',
      fallback: 'View all',
      category: 'Home',
    ),

    // -------------------------------------------------------------
    // LOCATION & DISCOVERY
    // -------------------------------------------------------------
    AppElementDefinition(
      screenKey: 'location',
      elementKey: 'title',
      elementType: UiElementType.text,
      label: 'Location Picker Title',
      description: 'Header title of the location selector sheet',
      fallback: 'Choose Location',
      category: 'Location',
    ),
    AppElementDefinition(
      screenKey: 'location',
      elementKey: 'subtitle',
      elementType: UiElementType.text,
      label: 'Location Subtitle',
      description: 'Guidance text for choosing your target city or area',
      fallback: 'Explore venues and stays in your preferred city',
      category: 'Location',
    ),
    AppElementDefinition(
      screenKey: 'location',
      elementKey: 'search_hint',
      elementType: UiElementType.field,
      label: 'Pincode / City Search Hint',
      description: 'Placeholder inside the location search textfield',
      fallback: 'Search city, state or pincode...',
      category: 'Location',
    ),
    AppElementDefinition(
      screenKey: 'location',
      elementKey: 'gps_button',
      elementType: UiElementType.text,
      label: 'GPS Auto-detect Button',
      description: 'Label on the button that triggers device GPS',
      fallback: 'Use Current Location',
      category: 'Location',
    ),
    AppElementDefinition(
      screenKey: 'location',
      elementKey: 'radius_label',
      elementType: UiElementType.text,
      label: 'Search Radius Label',
      description: 'Label for the geographic radius distance filter',
      fallback: 'Search radius',
      category: 'Location',
    ),

    // -------------------------------------------------------------
    // HOTELS & LODGES
    // -------------------------------------------------------------
    AppElementDefinition(
      screenKey: 'hotels',
      elementKey: 'heading',
      elementType: UiElementType.text,
      label: 'Hotels Heading',
      description: 'Title for daily stays, lodges, and hotel listings',
      fallback: 'Hotel Rooms & Lodges',
      category: 'Hotels',
    ),
    AppElementDefinition(
      screenKey: 'hotels',
      elementKey: 'subtitle',
      elementType: UiElementType.text,
      label: 'Hotels Subtitle',
      description: 'Subtitle for verified daily stay listings',
      fallback: 'Verified hotels, daily stays and premium suites',
      category: 'Hotels',
    ),
    AppElementDefinition(
      screenKey: 'hotels',
      elementKey: 'filter_label',
      elementType: UiElementType.text,
      label: 'Filter Button Label',
      description: 'Filter button text for amenities and room categories',
      fallback: 'Filters',
      category: 'Hotels',
    ),
    AppElementDefinition(
      screenKey: 'hotels',
      elementKey: 'book_cta',
      elementType: UiElementType.text,
      label: 'Book Room CTA',
      description: 'Primary button text on hotel room booking cards',
      fallback: 'Book Room',
      category: 'Hotels',
    ),
    AppElementDefinition(
      screenKey: 'hotels',
      elementKey: 'empty_title',
      elementType: UiElementType.text,
      label: 'Empty State Title',
      description: 'Message shown when no hotels match the search',
      fallback: 'No hotel rooms found',
      category: 'Hotels',
    ),

    // -------------------------------------------------------------
    // PG & HOSTELS
    // -------------------------------------------------------------
    AppElementDefinition(
      screenKey: 'pg',
      elementKey: 'heading',
      elementType: UiElementType.text,
      label: 'PG Heading',
      description: 'Title for PG and student co-living accommodations',
      fallback: 'PG & Co-living Spaces',
      category: 'PG',
    ),
    AppElementDefinition(
      screenKey: 'pg',
      elementKey: 'subtitle',
      elementType: UiElementType.text,
      label: 'PG Subtitle',
      description: 'Description for monthly shared and private rooms',
      fallback: 'Monthly stays, student hostels and co-living beds',
      category: 'PG',
    ),
    AppElementDefinition(
      screenKey: 'pg',
      elementKey: 'movein_label',
      elementType: UiElementType.text,
      label: 'Move-in Date Label',
      description: 'Date chip label for PG move-in scheduling',
      fallback: 'Move-in date',
      category: 'PG',
    ),
    AppElementDefinition(
      screenKey: 'pg',
      elementKey: 'book_cta',
      elementType: UiElementType.text,
      label: 'Reserve Bed CTA',
      description: 'Action button text on PG hostel booking cards',
      fallback: 'Reserve Bed',
      category: 'PG',
    ),
    AppElementDefinition(
      screenKey: 'pg',
      elementKey: 'empty_title',
      elementType: UiElementType.text,
      label: 'Empty State Title',
      description: 'Message shown when no PG stays match the area',
      fallback: 'No PG hostels found',
      category: 'PG',
    ),

    // -------------------------------------------------------------
    // FUNCTION HALLS
    // -------------------------------------------------------------
    AppElementDefinition(
      screenKey: 'function_halls',
      elementKey: 'heading',
      elementType: UiElementType.text,
      label: 'Function Halls Heading',
      description: 'Header for convention centers, banquets and marriage halls',
      fallback: 'Function Halls & Banquet Spaces',
      category: 'Function Halls',
    ),
    AppElementDefinition(
      screenKey: 'function_halls',
      elementKey: 'subtitle',
      elementType: UiElementType.text,
      label: 'Function Halls Subtitle',
      description: 'Subtitle for wedding, corporate and celebration spaces',
      fallback: 'Grand convention centers, wedding halls and party lawns',
      category: 'Function Halls',
    ),
    AppElementDefinition(
      screenKey: 'function_halls',
      elementKey: 'matrix_title',
      elementType: UiElementType.text,
      label: 'Event Matrix Title',
      description: '3D glass matrix heading for event categories',
      fallback: 'Event Types',
      category: 'Function Halls',
    ),
    AppElementDefinition(
      screenKey: 'function_halls',
      elementKey: 'book_cta',
      elementType: UiElementType.text,
      label: 'Request Booking CTA',
      description: 'Action button text for convention hall booking inquiries',
      fallback: 'Request Booking',
      category: 'Function Halls',
    ),
    AppElementDefinition(
      screenKey: 'function_halls',
      elementKey: 'promo_badge',
      elementType: UiElementType.text,
      label: 'Guarantee Badge Text',
      description: 'Promotional quality badge on function hall listings',
      fallback: 'Best Price Guaranteed',
      category: 'Function Halls',
    ),

    // -------------------------------------------------------------
    // VENUE DETAILS
    // -------------------------------------------------------------
    AppElementDefinition(
      screenKey: 'venue_details',
      elementKey: 'title',
      elementType: UiElementType.text,
      label: 'Screen Title',
      description: 'App bar header on the venue detail screen',
      fallback: 'Venue Details',
      category: 'Venues',
    ),
    AppElementDefinition(
      screenKey: 'venue_details',
      elementKey: 'book_button',
      elementType: UiElementType.text,
      label: 'Book CTA Button',
      description: 'Primary floating action button on venue detail screen',
      fallback: 'Book Space Now',
      category: 'Venues',
    ),
    AppElementDefinition(
      screenKey: 'venue_details',
      elementKey: 'amenities_title',
      elementType: UiElementType.text,
      label: 'Amenities Heading',
      description: 'Section title for facilities, parking, AC, WiFi',
      fallback: 'Facilities & Amenities',
      category: 'Venues',
    ),
    AppElementDefinition(
      screenKey: 'venue_details',
      elementKey: 'peace_of_mind_title',
      elementType: UiElementType.text,
      label: 'Peace of Mind Title',
      description: 'Trust and security guarantee title',
      fallback: 'Peace of Mind Guarantee',
      category: 'Venues',
    ),
    AppElementDefinition(
      screenKey: 'venue_details',
      elementKey: 'peace_of_mind_desc',
      elementType: UiElementType.text,
      label: 'Peace of Mind Description',
      description: 'Explanation of verified booking policy and refund safety',
      fallback: '100% verified space with instant confirmation',
      category: 'Venues',
    ),
    AppElementDefinition(
      screenKey: 'venue_details',
      elementKey: 'pricing_label',
      elementType: UiElementType.text,
      label: 'Pricing Label',
      description: 'Price tag prefix (Starting from, Per day, etc.)',
      fallback: 'Starting from',
      category: 'Venues',
    ),

    // -------------------------------------------------------------
    // MY BOOKINGS
    // -------------------------------------------------------------
    AppElementDefinition(
      screenKey: 'bookings',
      elementKey: 'title',
      elementType: UiElementType.text,
      label: 'Page Title',
      description: 'App bar header for customer booking history',
      fallback: 'My Bookings',
      category: 'My Bookings',
    ),
    AppElementDefinition(
      screenKey: 'bookings',
      elementKey: 'tab_upcoming',
      elementType: UiElementType.text,
      label: 'Upcoming Tab',
      description: 'Label on the active/upcoming bookings tab',
      fallback: 'Upcoming',
      category: 'My Bookings',
    ),
    AppElementDefinition(
      screenKey: 'bookings',
      elementKey: 'tab_completed',
      elementType: UiElementType.text,
      label: 'Completed Tab',
      description: 'Label on the past/completed bookings tab',
      fallback: 'Completed',
      category: 'My Bookings',
    ),
    AppElementDefinition(
      screenKey: 'bookings',
      elementKey: 'tab_cancelled',
      elementType: UiElementType.text,
      label: 'Cancelled Tab',
      description: 'Label on the cancelled/refunded bookings tab',
      fallback: 'Cancelled',
      category: 'My Bookings',
    ),
    AppElementDefinition(
      screenKey: 'bookings',
      elementKey: 'empty_title',
      elementType: UiElementType.text,
      label: 'Empty State Title',
      description: 'Message shown when the customer has no bookings',
      fallback: 'No bookings found',
      category: 'My Bookings',
    ),
    AppElementDefinition(
      screenKey: 'bookings',
      elementKey: 'empty_subtitle',
      elementType: UiElementType.text,
      label: 'Empty State Subtitle',
      description: 'Call to action message under empty bookings',
      fallback: 'Explore venues and make your first reservation',
      category: 'My Bookings',
    ),
    AppElementDefinition(
      screenKey: 'bookings',
      elementKey: 'explore_button',
      elementType: UiElementType.text,
      label: 'Explore Action CTA',
      description: 'Button taking user to explore from empty state',
      fallback: 'Explore Spaces',
      category: 'My Bookings',
    ),
    AppElementDefinition(
      screenKey: 'bookings',
      elementKey: 'pay_button',
      elementType: UiElementType.text,
      label: 'Pay Button',
      description: 'Action button for completing payment on pending bookings',
      fallback: 'Complete Payment',
      category: 'My Bookings',
    ),

    // -------------------------------------------------------------
    // REFER & EARN
    // -------------------------------------------------------------
    AppElementDefinition(
      screenKey: 'referral',
      elementKey: 'title',
      elementType: UiElementType.text,
      label: 'Screen Title',
      description: 'Header title for referral and rewards screen',
      fallback: 'Refer & Earn',
      category: 'Refer & Earn',
    ),
    AppElementDefinition(
      screenKey: 'referral',
      elementKey: 'program_headline',
      elementType: UiElementType.text,
      label: 'Reward Headline',
      description: 'Prominent headline for the referral cash bonus',
      fallback: 'Earn ₹500 for every friend who books',
      category: 'Refer & Earn',
    ),
    AppElementDefinition(
      screenKey: 'referral',
      elementKey: 'instructions',
      elementType: UiElementType.text,
      label: 'Referral Instructions',
      description: 'Explanation of how the referral credits work',
      fallback: 'Share your code, your friend gets 10% off and you get ₹500 wallet credit',
      category: 'Refer & Earn',
    ),
    AppElementDefinition(
      screenKey: 'referral',
      elementKey: 'share_button',
      elementType: UiElementType.text,
      label: 'Share CTA Button',
      description: 'Button that invokes the OS share sheet with invite code',
      fallback: 'Share Invite Code',
      category: 'Refer & Earn',
    ),
    AppElementDefinition(
      screenKey: 'referral',
      elementKey: 'history_title',
      elementType: UiElementType.text,
      label: 'Referral History Title',
      description: 'Section title for list of invited friends and payouts',
      fallback: 'Referral History',
      category: 'Refer & Earn',
    ),

    // -------------------------------------------------------------
    // FAVORITES / SAVED
    // -------------------------------------------------------------
    AppElementDefinition(
      screenKey: 'favorites',
      elementKey: 'title',
      elementType: UiElementType.text,
      label: 'Saved Spaces Title',
      description: 'App bar header on the wishlist/favorites screen',
      fallback: 'Saved Spaces',
      category: 'Favorites',
    ),
    AppElementDefinition(
      screenKey: 'favorites',
      elementKey: 'search_hint',
      elementType: UiElementType.field,
      label: 'Saved Search Hint',
      description: 'Placeholder inside wishlist search filter',
      fallback: 'Search saved venues...',
      category: 'Favorites',
    ),
    AppElementDefinition(
      screenKey: 'favorites',
      elementKey: 'empty_title',
      elementType: UiElementType.text,
      label: 'Empty State Title',
      description: 'Message shown when customer has not saved any venues',
      fallback: 'No saved spaces yet',
      category: 'Favorites',
    ),
    AppElementDefinition(
      screenKey: 'favorites',
      elementKey: 'empty_subtitle',
      elementType: UiElementType.text,
      label: 'Empty State Subtitle',
      description: 'Guidance to tap heart icon on venue cards',
      fallback: 'Tap the heart icon on any venue to save it here',
      category: 'Favorites',
    ),
    AppElementDefinition(
      screenKey: 'favorites',
      elementKey: 'explore_cta',
      elementType: UiElementType.text,
      label: 'Browse Venues CTA',
      description: 'Button directing user to search from empty favorites',
      fallback: 'Browse Venues',
      category: 'Favorites',
    ),

    // -------------------------------------------------------------
    // INSTITUTES & ACADEMIES
    // -------------------------------------------------------------
    AppElementDefinition(
      screenKey: 'institutes',
      elementKey: 'heading',
      elementType: UiElementType.text,
      label: 'Institutes Heading',
      description: 'Title for coaching centers, sports and music academies',
      fallback: 'Institutes & Academies',
      category: 'Institutes',
    ),
    AppElementDefinition(
      screenKey: 'institutes',
      elementKey: 'subtitle',
      elementType: UiElementType.text,
      label: 'Institutes Subtitle',
      description: 'Subtitle for verified education institutions',
      fallback: 'Classrooms, sports academies and training centers',
      category: 'Institutes',
    ),
    AppElementDefinition(
      screenKey: 'institutes',
      elementKey: 'filter_label',
      elementType: UiElementType.text,
      label: 'Filter Button Label',
      description: 'Filter chip for streams (Music, Dance, Sports, Coaching)',
      fallback: 'Filter by stream',
      category: 'Institutes',
    ),
    AppElementDefinition(
      screenKey: 'institutes',
      elementKey: 'enroll_cta',
      elementType: UiElementType.text,
      label: 'View Courses CTA',
      description: 'Button text on institute directory cards',
      fallback: 'View Courses',
      category: 'Institutes',
    ),
    AppElementDefinition(
      screenKey: 'institutes',
      elementKey: 'empty_title',
      elementType: UiElementType.text,
      label: 'Empty State Title',
      description: 'Message when no academies exist in the selected city',
      fallback: 'No institutes listed yet',
      category: 'Institutes',
    ),

    // -------------------------------------------------------------
    // COURSES & CLASSES
    // -------------------------------------------------------------
    AppElementDefinition(
      screenKey: 'courses',
      elementKey: 'heading',
      elementType: UiElementType.text,
      label: 'Courses Heading',
      description: 'Title for courses, batches and coaching classes',
      fallback: 'Courses & Batches',
      category: 'Courses',
    ),
    AppElementDefinition(
      screenKey: 'courses',
      elementKey: 'subtitle',
      elementType: UiElementType.text,
      label: 'Courses Subtitle',
      description: 'Subtitle for skill development and academy enrollments',
      fallback: 'Skill development, coaching and test prep batches',
      category: 'Courses',
    ),
    AppElementDefinition(
      screenKey: 'courses',
      elementKey: 'enroll_button',
      elementType: UiElementType.text,
      label: 'Enroll CTA Button',
      description: 'Action button text on course details and batch cards',
      fallback: 'Enroll Now',
      category: 'Courses',
    ),
    AppElementDefinition(
      screenKey: 'courses',
      elementKey: 'empty_title',
      elementType: UiElementType.text,
      label: 'Empty State Title',
      description: 'Message shown when no batches are actively enrolling',
      fallback: 'No active batches',
      category: 'Courses',
    ),

    // -------------------------------------------------------------
    // REGISTRATION & KYC
    // -------------------------------------------------------------
    AppElementDefinition(
      screenKey: 'kyc',
      elementKey: 'heading',
      elementType: UiElementType.text,
      label: 'KYC Form Heading',
      description: 'Header title for partner registration and identity verification',
      fallback: 'Partner Verification',
      category: 'Registration & KYC',
    ),
    AppElementDefinition(
      screenKey: 'kyc',
      elementKey: 'subtitle',
      elementType: UiElementType.text,
      label: 'KYC Subtitle',
      description: 'Instructions explaining document requirements',
      fallback: 'Submit business KYC to list and accept bookings',
      category: 'Registration & KYC',
    ),
    AppElementDefinition(
      screenKey: 'kyc',
      elementKey: 'field_pan',
      elementType: UiElementType.field,
      label: 'PAN Field Hint',
      description: 'Placeholder in PAN card input text field',
      fallback: 'Enter 10-digit PAN number',
      category: 'Registration & KYC',
    ),
    AppElementDefinition(
      screenKey: 'kyc',
      elementKey: 'field_gst',
      elementType: UiElementType.field,
      label: 'GST Field Hint',
      description: 'Placeholder in GSTIN text field',
      fallback: 'GSTIN (Optional)',
      category: 'Registration & KYC',
    ),
    AppElementDefinition(
      screenKey: 'kyc',
      elementKey: 'instructions',
      elementType: UiElementType.text,
      label: 'Verification Instructions',
      description: 'Notice regarding clear image capture and government ID validity',
      fallback: 'Ensure uploaded documents are clearly legible and valid.',
      category: 'Registration & KYC',
    ),
    AppElementDefinition(
      screenKey: 'kyc',
      elementKey: 'submit_button',
      elementType: UiElementType.text,
      label: 'Submit CTA Button',
      description: 'Action button submitting partner KYC documents',
      fallback: 'Submit KYC for Review',
      category: 'Registration & KYC',
    ),

    // -------------------------------------------------------------
    // PROFILE
    // -------------------------------------------------------------
    AppElementDefinition(
      screenKey: 'profile',
      elementKey: 'title',
      elementType: UiElementType.text,
      label: 'Profile Screen Title',
      description: 'App bar header on the customer account profile',
      fallback: 'My Profile',
      category: 'Profile',
    ),
    AppElementDefinition(
      screenKey: 'profile',
      elementKey: 'menu_bookings',
      elementType: UiElementType.text,
      label: 'My Bookings Menu Label',
      description: 'Navigation menu tile for customer bookings',
      fallback: 'My Bookings',
      category: 'Profile',
    ),
    AppElementDefinition(
      screenKey: 'profile',
      elementKey: 'menu_saved',
      elementType: UiElementType.text,
      label: 'Saved Places Menu Label',
      description: 'Navigation menu tile for favorites and wishlist',
      fallback: 'Saved Places',
      category: 'Profile',
    ),
    AppElementDefinition(
      screenKey: 'profile',
      elementKey: 'menu_wallet',
      elementType: UiElementType.text,
      label: 'Rewards & Wallet Label',
      description: 'Navigation menu tile for referral cash and credits',
      fallback: 'Rewards & Wallet',
      category: 'Profile',
    ),
    AppElementDefinition(
      screenKey: 'profile',
      elementKey: 'menu_settings',
      elementType: UiElementType.text,
      label: 'Settings Menu Label',
      description: 'Navigation menu tile for application settings',
      fallback: 'Settings',
      category: 'Profile',
    ),
    AppElementDefinition(
      screenKey: 'profile',
      elementKey: 'logout_label',
      elementType: UiElementType.text,
      label: 'Log out Label',
      description: 'Label on the sign out button',
      fallback: 'Log out',
      category: 'Profile',
    ),

    // -------------------------------------------------------------
    // SETTINGS
    // -------------------------------------------------------------
    AppElementDefinition(
      screenKey: 'settings',
      elementKey: 'heading',
      elementType: UiElementType.text,
      label: 'Settings Title',
      description: 'Header title of the settings screen',
      fallback: 'Settings',
      category: 'Settings',
    ),
    AppElementDefinition(
      screenKey: 'settings',
      elementKey: 'notifications_label',
      elementType: UiElementType.text,
      label: 'Notifications Setting Label',
      description: 'Title for push notification preference toggle',
      fallback: 'Push Notifications',
      category: 'Settings',
    ),
    AppElementDefinition(
      screenKey: 'settings',
      elementKey: 'dark_mode_label',
      elementType: UiElementType.text,
      label: 'Dark Mode Setting Label',
      description: 'Title for appearance / theme switcher',
      fallback: 'Dark Appearance',
      category: 'Settings',
    ),
    AppElementDefinition(
      screenKey: 'settings',
      elementKey: 'language_label',
      elementType: UiElementType.text,
      label: 'Language Setting Label',
      description: 'Title for language and localization preferences',
      fallback: 'Language & Locale',
      category: 'Settings',
    ),
    AppElementDefinition(
      screenKey: 'settings',
      elementKey: 'privacy_label',
      elementType: UiElementType.text,
      label: 'Privacy & Terms Label',
      description: 'Title for legal terms and privacy policy link',
      fallback: 'Privacy & Terms',
      category: 'Settings',
    ),

    // -------------------------------------------------------------
    // SEARCH
    // -------------------------------------------------------------
    AppElementDefinition(
      screenKey: 'search',
      elementKey: 'title',
      elementType: UiElementType.text,
      label: 'Search Screen Title',
      description: 'App bar header on the full search screen',
      fallback: 'Search Spaces',
      category: 'Search',
    ),
    AppElementDefinition(
      screenKey: 'search',
      elementKey: 'search_hint',
      elementType: UiElementType.field,
      label: 'Search Input Hint',
      description: 'Placeholder inside main discovery search bar',
      fallback: 'Search by venue name, city or amenity...',
      category: 'Search',
    ),
    AppElementDefinition(
      screenKey: 'search',
      elementKey: 'filter_button',
      elementType: UiElementType.text,
      label: 'Filter Button Label',
      description: 'Label on search filter controls button',
      fallback: 'Filters',
      category: 'Search',
    ),
    AppElementDefinition(
      screenKey: 'search',
      elementKey: 'empty_title',
      elementType: UiElementType.text,
      label: 'Empty Results Title',
      description: 'Headline when no venues match search terms',
      fallback: 'No spaces match your criteria',
      category: 'Search',
    ),
    AppElementDefinition(
      screenKey: 'search',
      elementKey: 'empty_subtitle',
      elementType: UiElementType.text,
      label: 'Empty Results Subtitle',
      description: 'Helpful advice under empty search results',
      fallback: 'Try adjusting your filters or search terms',
      category: 'Search',
    ),

    // -------------------------------------------------------------
    // NOTIFICATIONS
    // -------------------------------------------------------------
    AppElementDefinition(
      screenKey: 'notifications',
      elementKey: 'title',
      elementType: UiElementType.text,
      label: 'Notifications Title',
      description: 'App bar header on notification history screen',
      fallback: 'Notifications',
      category: 'Notifications',
    ),
    AppElementDefinition(
      screenKey: 'notifications',
      elementKey: 'empty_title',
      elementType: UiElementType.text,
      label: 'Empty Notifications Title',
      description: 'Message when the user has zero unread alerts',
      fallback: 'You are all caught up',
      category: 'Notifications',
    ),
    AppElementDefinition(
      screenKey: 'notifications',
      elementKey: 'empty_subtitle',
      elementType: UiElementType.text,
      label: 'Empty Notifications Subtitle',
      description: 'Informational message about booking updates and offers',
      fallback: 'Booking updates and promotional offers will appear here',
      category: 'Notifications',
    ),
    AppElementDefinition(
      screenKey: 'notifications',
      elementKey: 'clear_all',
      elementType: UiElementType.text,
      label: 'Clear All Action',
      description: 'Action link for dismissing notification history',
      fallback: 'Clear all',
      category: 'Notifications',
    ),

    // -------------------------------------------------------------
    // OWNER PORTAL
    // -------------------------------------------------------------
    AppElementDefinition(
      screenKey: 'owner_dashboard',
      elementKey: 'dashboard_title',
      elementType: UiElementType.text,
      label: 'Owner Portal Title',
      description: 'Header title of the venue host/owner dashboard',
      fallback: 'Partner Portal',
      category: 'Owner Portal',
    ),
    AppElementDefinition(
      screenKey: 'owner_dashboard',
      elementKey: 'revenue_label',
      elementType: UiElementType.text,
      label: 'Revenue Card Label',
      description: 'Metric title for total owner earnings',
      fallback: 'Gross Revenue',
      category: 'Owner Portal',
    ),
    AppElementDefinition(
      screenKey: 'owner_dashboard',
      elementKey: 'bookings_label',
      elementType: UiElementType.text,
      label: 'Bookings Metric Label',
      description: 'Metric title for total booking count',
      fallback: 'Total Bookings',
      category: 'Owner Portal',
    ),
    AppElementDefinition(
      screenKey: 'owner_dashboard',
      elementKey: 'manage_venues_label',
      elementType: UiElementType.text,
      label: 'Manage Spaces Label',
      description: 'Action card title for editing owner venues',
      fallback: 'Manage Venues',
      category: 'Owner Portal',
    ),
    AppElementDefinition(
      screenKey: 'owner_dashboard',
      elementKey: 'calendar_label',
      elementType: UiElementType.text,
      label: 'Calendar Action Label',
      description: 'Action card title for the booking schedule view',
      fallback: 'Booking Calendar',
      category: 'Owner Portal',
    ),
    AppElementDefinition(
      screenKey: 'owner_dashboard',
      elementKey: 'add_venue_cta',
      elementType: UiElementType.text,
      label: 'Add Space CTA Button',
      description: 'Button taking the owner to create a new space listing',
      fallback: '+ Add New Space',
      category: 'Owner Portal',
    ),

    // -------------------------------------------------------------
    // ADMIN PORTAL & STUDIO
    // -------------------------------------------------------------
    AppElementDefinition(
      screenKey: 'admin',
      elementKey: 'dashboard_title',
      elementType: UiElementType.text,
      label: 'Admin Operations Title',
      description: 'Header title on the administrative operations console',
      fallback: 'Super Admin Operations',
      category: 'Admin',
    ),
    AppElementDefinition(
      screenKey: 'admin',
      elementKey: 'content_label',
      elementType: UiElementType.text,
      label: 'Editorial Content Label',
      description: 'Menu link for managing legal and editorial pages',
      fallback: 'Editorial Content',
      category: 'Admin',
    ),
    AppElementDefinition(
      screenKey: 'admin',
      elementKey: 'cms_label',
      elementType: UiElementType.text,
      label: 'CMS Banners Label',
      description: 'Menu link for banner carousels and promotional slots',
      fallback: 'CMS Banners & Media',
      category: 'Admin',
    ),
    AppElementDefinition(
      screenKey: 'admin',
      elementKey: 'branding_label',
      elementType: UiElementType.text,
      label: 'Global Branding Label',
      description: 'Menu link for application logos and app identity',
      fallback: 'Global Branding',
      category: 'Admin',
    ),
    AppElementDefinition(
      screenKey: 'admin',
      elementKey: 'studio_label',
      elementType: UiElementType.text,
      label: 'Live App Studio Label',
      description: 'Menu link for the Universal UI Content Studio',
      fallback: 'Live App Studio',
      category: 'Admin',
    ),
  ];

  /// Fast lookup of all elements grouped by screenKey.
  static Map<String, List<AppElementDefinition>> get screens {
    final map = <String, List<AppElementDefinition>>{};
    for (final def in all) {
      map.putIfAbsent(def.screenKey, () => []).add(def);
    }
    return map;
  }

  /// List of unique screen keys registered.
  static List<String> get screenKeys => screens.keys.toList();

  /// Finds a specific element definition by screen and element key.
  static AppElementDefinition? find(String screenKey, String elementKey) {
    for (final def in all) {
      if (def.screenKey == screenKey && def.elementKey == elementKey) {
        return def;
      }
    }
    return null;
  }
}
