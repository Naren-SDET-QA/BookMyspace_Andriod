import 'app_localizations.dart';

/// Marketplace copy is kept out of widgets. Other locales use English until
/// their catalog has translations, matching the application's fallback policy.
extension MarketplaceStrings on AppLocalizations {
  String marketplaceText(String key) =>
      (locale.languageCode == 'te' ? _te[key] : null) ?? _en[key] ?? key;
}

const _en = {
  'marketplace': 'Discover & book',
  'marketplaceIntro': 'Make room for your next great plan.',
  'marketplaceSubtitle':
      'Events, spaces, sports, dining, experiences and learning — together in BookMySpace.',
  'marketplaceSearch': 'Search events, spaces and courses',
  'marketplaceLocation': 'Choose city',
  'marketplaceAllCities': 'All cities',
  'marketplaceResults': 'Explore your next plan',
  'marketplaceEmpty': 'No plans found',
  'marketplaceEmptyMessage':
      'Try another city or adjust your search and filters.',
  'marketplaceError': 'We couldn’t load these plans. Please try again.',
  'marketplaceRetry': 'Try again',
  'marketplaceReset': 'Clear filters',
  'marketplaceNext': 'Next page',
  'marketplacePrevious': 'Previous page',
  'marketplaceDate': 'Choose dates',
  'marketplaceAnyPrice': 'Any price',
  'marketplaceUpTo': 'Up to {price}',
  'marketplaceFrom': 'From {price}',
  'marketplaceFree': 'Free',
  'marketplaceOpen': 'View details',
  'marketplaceAll': 'All plans',
  'marketplaceEvents': 'Events',
  'marketplaceVenues': 'Spaces',
  'marketplaceSports': 'Sports',
  'marketplaceRestaurants': 'Dining',
  'marketplaceExperiences': 'Experiences',
  'marketplaceCourses': 'Classes & courses',
  'marketplaceRelevance': 'Recommended',
  'marketplacePriceLow': 'Price: low to high',
  'marketplacePriceHigh': 'Price: high to low',
  'marketplaceRating': 'Top rated',
  'marketplaceSoonest': 'Starting soon',
  'marketplaceSort': 'Sort plans',
  'marketplacePrice': 'Price filter',
  'marketplaceDateHint': 'Dates show scheduled events and course batches.',
  'marketplaceEntry': 'Events, experiences & more',
};

const _te = {
  'marketplace': 'కనుగొనండి & బుక్ చేయండి',
  'marketplaceIntro': 'మీ తదుపరి గొప్ప అనుభవాన్ని ఎంచుకోండి.',
  'marketplaceSubtitle':
      'ఈవెంట్లు, ప్రదేశాలు, క్రీడలు, భోజనం, అనుభవాలు మరియు అభ్యాసం — BookMySpaceలో.',
  'marketplaceSearch': 'ఈవెంట్లు, ప్రదేశాలు, కోర్సులు వెతకండి',
  'marketplaceLocation': 'నగరాన్ని ఎంచుకోండి',
  'marketplaceAllCities': 'అన్ని నగరాలు',
  'marketplaceResults': 'మీ తదుపరి అనుభవాన్ని కనుగొనండి',
  'marketplaceEmpty': 'ఫలితాలు కనుగొనబడలేదు',
  'marketplaceEmptyMessage':
      'మరొక నగరాన్ని ఎంచుకోండి లేదా ఫిల్టర్లను మార్చండి.',
  'marketplaceError': 'ఫలితాలను లోడ్ చేయలేకపోయాము. మళ్లీ ప్రయత్నించండి.',
  'marketplaceRetry': 'మళ్లీ ప్రయత్నించండి',
  'marketplaceReset': 'ఫిల్టర్లను తొలగించండి',
  'marketplaceNext': 'తదుపరి పేజీ',
  'marketplacePrevious': 'మునుపటి పేజీ',
  'marketplaceDate': 'తేదీలను ఎంచుకోండి',
  'marketplaceAnyPrice': 'ఏ ధర అయినా',
  'marketplaceUpTo': '{price} వరకు',
  'marketplaceFrom': '{price} నుండి',
  'marketplaceFree': 'ఉచితం',
  'marketplaceOpen': 'వివరాలు చూడండి',
  'marketplaceAll': 'అన్ని అనుభవాలు',
  'marketplaceEvents': 'ఈవెంట్లు',
  'marketplaceVenues': 'ప్రదేశాలు',
  'marketplaceSports': 'క్రీడలు',
  'marketplaceRestaurants': 'భోజనం',
  'marketplaceExperiences': 'అనుభవాలు',
  'marketplaceCourses': 'తరగతులు & కోర్సులు',
  'marketplaceRelevance': 'సిఫార్సులు',
  'marketplacePriceLow': 'ధర: తక్కువ నుండి ఎక్కువ',
  'marketplacePriceHigh': 'ధర: ఎక్కువ నుండి తక్కువ',
  'marketplaceRating': 'అత్యుత్తమ రేటింగ్',
  'marketplaceSoonest': 'త్వరలో ప్రారంభం',
  'marketplaceSort': 'క్రమాన్ని ఎంచుకోండి',
  'marketplacePrice': 'ధర ఫిల్టర్',
  'marketplaceDateHint': 'తేదీలు ఈవెంట్లు మరియు కోర్సు బ్యాచ్‌లను చూపుతాయి.',
  'marketplaceEntry': 'ఈవెంట్లు, అనుభవాలు & మరిన్ని',
};
