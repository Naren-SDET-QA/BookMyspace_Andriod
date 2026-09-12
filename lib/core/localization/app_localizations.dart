import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Application localizations providing strings in English and Telugu/Hindi.
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
  ];

  String get appName => 'BookMySpace';
  String get tagline => 'Discover and book spaces with ease';
  String get navHome => 'Home';
  String get navSearch => 'Search';
  String get navBookings => 'Bookings';
  String get navProfile => 'Profile';
  String get notifications => 'Notifications';
  String get courses => 'Courses';
  String get venues => 'Venues';
  String get venueDetails => 'Venue Details';
  String get aboutThisVenue => 'About this venue';
  String get amenities => 'Amenities';
  String get operatingHours => 'Operating Hours';
  String get details => 'Details';
  String get foodOptions => 'Food Options';
  String get parking => 'Parking';
  String get taxRate => 'Tax Rate';
  String get address => 'Address';
  String get basePrice => 'Base Price';
  String get capacity => 'Capacity';
  String get pricing => 'Starting at';
  String get bookNow => 'Book Now';
  String get search => 'Search';
  String get searchHint => 'Search venues, cities or categories...';
  String get filters => 'Filters';
  String get clearFilters => 'Clear Filters';
  String get apply => 'Apply';
  String get allCategories => 'All Categories';
  String get minPrice => 'Min Price';
  String get maxPrice => 'Max Price';
  String get sortBy => 'Sort By';
  String get relevance => 'Relevance';
  String get priceLowToHigh => 'Price: Low to High';
  String get priceHighToLow => 'Price: High to Low';
  String get topRated => 'Top Rated';
  String get noResults => 'No results found';
  String get noResultsMessage =>
      'Try a different keyword, category or price range.';
  String get tryAgain => 'Try Again';
  String get loading => 'Loading...';
  String get cancel => 'Cancel';
  String get confirm => 'Confirm';
  String get delete => 'Delete';
  String get done => 'Done';
  String get keep => 'Keep';
  String get next => 'Next';
  String get skip => 'Skip';
  String get getStarted => 'Get Started';
  String get total => 'Total';
  String get selectDate => 'Select Date';
  String get selectTimeSlot => 'Select Time Slot';
  String get noSlotsForDate => 'No slots available for this date';
  String get confirmBooking => 'Confirm Booking';
  String get cancelBooking => 'Cancel Booking';
  String get cancelBookingConfirm =>
      'Are you sure you want to cancel this booking?';
  String get myBookings => 'My Bookings';
  String get noBookings => 'No bookings yet';
  String get noBookingsMessage =>
      'Your booked venues and passes will appear here.';
  String get requestRefund => 'Request Refund';
  String get requestRefundConfirm =>
      'Are you sure you want to request a refund?';
  String get refundRequested => 'Refund request submitted successfully';
  String get savedVenues => 'Saved Venues';
  String get upcomingEvents => 'Upcoming Events';
  String get noUpcomingEvents => 'No upcoming events';
  String get noUpcomingEventsMessage =>
      'Check back later for new workshops and events.';
  String get freeEvent => 'Free';
  String get seatsLeft => '{count} seats left';
  String get soldOut => 'Sold Out';
  String get registered => 'Registered';
  String get registerNow => 'Register Now';
  String get cancelRegistration => 'Cancel Registration';
  String get cancelRegistrationConfirm =>
      'Are you sure you want to cancel your event registration?';
  String get registrationCancelled => 'Registration cancelled successfully';
  String get noCourses => 'No courses available';
  String get noCoursesMessage => 'Explore new courses and batches coming soon.';
  String get courseFee => 'Course Fee';
  String get durationWeeks => '{weeks} weeks';
  String get instructor => 'Instructor';
  String get enrollInCourse => 'Choose a batch';
  String get enrollNow => 'Enroll Now';
  String get enrolled => 'Enrolled';
  String get dropEnrollment => 'Drop';
  String get dropEnrollmentConfirm =>
      'Drop this batch? Your seat will be released.';
  String get enrollmentDropped => 'Enrollment dropped';
  String get batchStartsOn => 'Starts';
  String get signInToEnroll => 'Sign in to enroll';
  String get modeOnline => 'Online';
  String get modeOffline => 'Offline';
  String get modeHybrid => 'Hybrid';
  String get settings => 'Settings';
  String get themeMode => 'Theme Mode';
  String get language => 'Language';
  String get support => 'Support';
  String get privacyPolicy => 'Privacy Policy';
  String get termsAndConditions => 'Terms & Conditions';
  String get deleteAccount => 'Delete Account';
  String get name => 'Name';
  String get email => 'Email';
  String get password => 'Password';
  String get errorInvalidEmail => 'Please enter a valid email address';
  String get signUp => 'Sign Up';
  String get priority => 'Priority';
  String get about => 'About';
  String get auditLog => 'Audit Log';
  String get analyticsLabel => 'Analytics';
  String get ownerDashboard => 'Owner Dashboard';
  String get myVenues => 'My Venues';
  String get onboardingTitle1 => 'Find Your Perfect Space';
  String get onboardingSubtitle1 =>
      'Discover convention halls, party venues, sports grounds, and classrooms near you.';
  String get onboardingTitle2 => 'Real-Time Availability';
  String get onboardingSubtitle2 =>
      'Check open slots, transparent pricing, and instant booking confirmations.';
  String get onboardingTitle3 => 'Seamless & Secure';
  String get onboardingSubtitle3 =>
      'Pay securely with instant tax invoices and easy booking management.';
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
