import 'package:flutter/material.dart';

/// Bottom sheet on phones, centered panel on tablet and desktop.
///
/// The same widget tree is used on iOS, web, and Android. Width and height
/// follow the window so tabs and forms stay inside the screen.
Future<T?> showAcademicSheet<T>(
  BuildContext context, {
  required Widget child,
  Color? backgroundColor,
}) {
  return showModalBottomSheet<T>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (sheetContext) {
      final media = MediaQuery.of(sheetContext);
      final width = media.size.width;
      final wide = width >= 840;
      final height = (media.size.height * (wide ? 0.86 : 0.92)) -
          media.viewInsets.bottom;
      return Padding(
        padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
        child: Align(
          alignment: Alignment.bottomCenter,
          child: SizedBox(
            width: wide ? 760 : width,
            height: height.clamp(280, media.size.height),
            child: Material(
              color: backgroundColor ??
                  Theme.of(sheetContext).colorScheme.surface,
              child: child,
            ),
          ),
        ),
      );
    },
  );
}

/// Closes the current sheet, then opens the next one from the context that
/// opened it. The root navigator's own context has no Navigator ancestor, so
/// a follow-up sheet opened from that context never appears.
void showAfterAcademicSheet(
  BuildContext sheetContext,
  BuildContext opener,
  void Function(BuildContext host) open,
) {
  Navigator.of(sheetContext).pop();
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!opener.mounted) return;
    open(opener);
  });
}
