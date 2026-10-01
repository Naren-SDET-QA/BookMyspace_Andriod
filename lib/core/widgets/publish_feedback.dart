import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Shows [snackBar] on [messenger] once the current frame has finished.
///
/// Admin "Publish" actions invalidate shared configuration providers, which
/// rebuilds parts of the app (shell, home, navigation) around the screen that
/// published. For the rest of that frame some of those Scaffolds are
/// deactivated but still registered with the root [ScaffoldMessenger];
/// showing a SnackBar then makes the messenger look up their ancestors and
/// Flutter throws "Looking up a deactivated widget's ancestor is unsafe".
///
/// That exception used to be caught by the publish handler and reported as
/// "Could not publish" even though the write had already succeeded. Deferring
/// the SnackBar to after the frame (when deactivated elements are gone) and
/// never letting a feedback failure escape keeps the reported outcome equal to
/// the real outcome of the save.
///
/// Capture [messenger] with `ScaffoldMessenger.maybeOf(context)` before the
/// first `await`, so no context lookup happens after the screen may have
/// rebuilt.
void showSnackBarAfterFrame(
  ScaffoldMessengerState? messenger,
  SnackBar snackBar,
) {
  if (messenger == null) return;
  final binding = WidgetsBinding.instance;
  binding.addPostFrameCallback((_) {
    if (!messenger.mounted) return;
    try {
      messenger.showSnackBar(snackBar);
    } catch (error, stack) {
      // Feedback only: the action's result has already been decided.
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stack,
          library: 'publish_feedback',
          context: ErrorDescription('while showing publish feedback'),
        ),
      );
    }
  });
  binding.scheduleFrame();
}
