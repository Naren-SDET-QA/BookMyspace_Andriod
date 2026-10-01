import '../../../core/router/app_router.dart';

/// Topics the in-app help assistant and the support FAQ know about.
enum HelpTopic {
  refundPolicy,
  walletReferral,
  qrCheckIn,
  promoCodes,
  paymentMethods,
  pgHostel,
  listProperty,
  contactSupport,
}

/// A canned FAQ answer with an optional deep link into an existing route.
///
/// Answers describe the app's real rules (e.g. the standard tiered
/// cancellation policy `standard_tiered_v1` in
/// `20260914180000_cancellation_policy_lifecycle.sql`), never invented
/// numbers.
class HelpAnswer {
  const HelpAnswer({
    required this.topic,
    required this.question,
    required this.answer,
    required this.keywords,
    this.actionLabel,
    this.actionRoute,
  });

  final HelpTopic topic;
  final String question;
  final String answer;
  final List<String> keywords;
  final String? actionLabel;
  final String? actionRoute;

  bool get hasAction => actionLabel != null && actionRoute != null;
}

abstract final class HelpFaqCatalog {
  /// Ordered by priority: on a tie in keyword hits the earlier entry wins.
  static const List<HelpAnswer> answers = [
    HelpAnswer(
      topic: HelpTopic.refundPolicy,
      question: 'How do cancellations and refunds work?',
      answer:
          'Cancel a confirmed booking from My Bookings. The refund follows '
          'the cancellation policy the venue had when you booked. Under the '
          'standard policy you get a 100% refund when you cancel 48 hours or '
          'more before the start time, 50% between 24 and 48 hours, and no '
          'refund within 24 hours. Taxes are refunded in the same proportion. '
          'If the venue cancels your booking, you always get a full refund. '
          'Refunds go back to your original payment method.',
      keywords: [
        'refund',
        'cancel',
        'money back',
        'return money',
        'cancellation',
      ],
      actionLabel: 'Manage my bookings',
      actionRoute: AppRoutes.bookings,
    ),
    HelpAnswer(
      topic: HelpTopic.walletReferral,
      question: 'How do the wallet and Refer & Earn work?',
      answer:
          'Share your referral code from Refer & Earn. When a friend '
          'signs up with your code and the referral qualifies, reward credits '
          'are posted to both of your wallets. The current reward amounts are '
          'shown on the Refer & Earn screen. You cannot use your own code.',
      keywords: [
        'wallet',
        'refer',
        'credit',
        'earn',
        'reward',
        'balance',
        'cashback',
      ],
      actionLabel: 'View wallet & referrals',
      actionRoute: AppRoutes.referrals,
    ),
    HelpAnswer(
      topic: HelpTopic.qrCheckIn,
      question: 'Where is my QR pass for check-in?',
      answer:
          'Open My Bookings and tap the QR pass on a confirmed booking. '
          'Show the QR code at the venue desk. Staff scan it to check you in.',
      keywords: ['qr', 'pass', 'check in', 'check-in', 'checkin', 'entry'],
      actionLabel: 'Open my bookings',
      actionRoute: AppRoutes.bookings,
    ),
    HelpAnswer(
      topic: HelpTopic.promoCodes,
      question: 'How do I use a promo code?',
      answer:
          'Enter the coupon code on the booking screen before you pay. A '
          'valid code reduces the total straight away. Each code has its own '
          'validity dates, minimum amount and usage limits. Current offers '
          'appear on the home screen.',
      keywords: ['promo', 'coupon', 'discount', 'offer', 'voucher', 'code'],
      actionLabel: 'Explore spaces',
      actionRoute: AppRoutes.home,
    ),
    HelpAnswer(
      topic: HelpTopic.paymentMethods,
      question: 'Which payment methods can I use?',
      answer:
          'Online payments go through the secure Razorpay checkout, which '
          'supports UPI, credit and debit cards, and net banking. Some venues '
          'also let you pay at the venue. All your receipts are in Payment '
          'history.',
      keywords: [
        'payment',
        'pay',
        'upi',
        'card',
        'gpay',
        'phonepe',
        'paytm',
        'net banking',
        'razorpay',
        'receipt',
      ],
      actionLabel: 'Payment history',
      actionRoute: AppRoutes.paymentHistory,
    ),
    HelpAnswer(
      topic: HelpTopic.pgHostel,
      question: 'How do I find a PG or hostel?',
      answer:
          'Open PGs & Hostels to browse by location. Compare rent, sharing '
          'type, food and amenities on each listing, then contact the owner '
          'or book from the listing page.',
      keywords: [
        'pg',
        'hostel',
        'co-living',
        'coliving',
        'rent',
        'paying guest',
      ],
      actionLabel: 'Find PGs & hostels',
      actionRoute: AppRoutes.pgList,
    ),
    HelpAnswer(
      topic: HelpTopic.listProperty,
      question: 'How do I list my venue, PG or institute?',
      answer:
          'Start a listing registration and choose what you want to list. '
          'Add the details and photos, then submit it. Your listing goes live '
          'after the BookMySpace team verifies it.',
      keywords: [
        'list',
        'owner',
        'register',
        'partner',
        'my property',
        'my venue',
        'institute',
        'academy',
      ],
      actionLabel: 'List your property',
      actionRoute: AppRoutes.unifiedRegistration,
    ),
    HelpAnswer(
      topic: HelpTopic.contactSupport,
      question: 'How do I contact support?',
      answer:
          'Raise a support ticket from the Support screen. Our team replies '
          'on the ticket, and you can track its status under My tickets.',
      keywords: [
        'support',
        'call',
        'agent',
        'human',
        'contact',
        'phone',
        'helpline',
        'ticket',
        'complaint',
        'email',
      ],
      actionLabel: 'Raise a ticket',
      actionRoute: AppRoutes.support,
    ),
  ];

  /// Starter prompts shown as chips in the assistant.
  static const List<String> suggestions = [
    'Refund policy',
    'Wallet & referral',
    'Promo codes',
    'QR check-in pass',
    'Payment methods',
    'PG & hostels',
    'List my property',
    'Contact support',
  ];

  static HelpAnswer forTopic(HelpTopic topic) =>
      answers.firstWhere((a) => a.topic == topic);

  /// Returns the best keyword match for [query], or `null` when nothing
  /// matches. Keywords match at the start of a word (so "refunds" matches
  /// "refund" and "pay" matches "payment"); the answer with the most hits
  /// wins and ties go to the earlier entry.
  static HelpAnswer? match(String query) {
    final text = query.toLowerCase().trim();
    if (text.isEmpty) return null;
    HelpAnswer? best;
    var bestScore = 0;
    for (final answer in answers) {
      var score = 0;
      for (final keyword in answer.keywords) {
        if (RegExp('\\b${RegExp.escape(keyword)}').hasMatch(text)) score++;
      }
      if (score > bestScore) {
        best = answer;
        bestScore = score;
      }
    }
    return best;
  }
}

/// Support phone / email shown on the Support screen. No backend or tenant
/// configuration carries these yet, so the default is empty and the call /
/// email buttons stay hidden until a value is provided.
class SupportContact {
  const SupportContact({this.phone = '', this.email = ''});

  final String phone;
  final String email;

  bool get hasPhone => phone.trim().isNotEmpty;
  bool get hasEmail => email.trim().isNotEmpty;
  bool get isEmpty => !hasPhone && !hasEmail;
}
