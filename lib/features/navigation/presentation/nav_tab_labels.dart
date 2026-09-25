import '../../../core/localization/app_localizations.dart';
import '../domain/nav_tabs.dart';

/// The name shown for one bar destination.
///
/// An admin override wins. Otherwise the shipped localized name is used, which
/// is what keeps the bar translated in every language unless someone
/// deliberately opts out. Shared by the customer shell and the admin editor so
/// an admin always previews exactly what a customer will read.
String navTabLabel(
  NavTabConfig entry,
  AppLocalizations l10n, {
  bool isCompact = false,
}) {
  if (entry.label.isNotEmpty) return entry.label;
  return switch (entry.tab) {
    NavTab.home => l10n.navHome,
    // A narrow phone bar truncates "Notifications", so the short form is kept
    // for compact layouts only.
    NavTab.alerts => isCompact ? 'Alerts' : l10n.notifications,
    NavTab.search => l10n.navSearch,
    NavTab.bookings => l10n.navBookings,
    NavTab.courses => l10n.courses,
    NavTab.profile => l10n.navProfile,
    NavTab.assistant => l10n.navAssistant,
    NavTab.map => l10n.navMap,
    NavTab.saved => l10n.navSaved,
    NavTab.chat => l10n.navChat,
  };
}
