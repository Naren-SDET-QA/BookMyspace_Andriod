import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Shared, identifier-first interactions for every robot.
///
/// Robots find UI only through `E2eIds` (never visible text), wait with an
/// explicit timeout, and fail with the id that was missing.
class BaseRobot {
  BaseRobot(this.tester);

  final WidgetTester tester;

  static const _step = Duration(milliseconds: 100);

  Finder byId(String id) => find.byKey(ValueKey<String>(id));

  /// Pumps until no frame is scheduled (or [max] elapses). Unlike
  /// `pumpAndSettle`, this tolerates the app's periodic countdown timers
  /// (OTP resend, booking hold) instead of timing out on them.
  Future<void> settle({Duration max = const Duration(seconds: 3)}) async {
    final steps = max.inMilliseconds ~/ _step.inMilliseconds;
    for (var i = 0; i < steps; i++) {
      await tester.pump(_step);
      if (!tester.binding.hasScheduledFrame) return;
    }
  }

  /// Waits until [id] is in the widget tree.
  Future<Finder> waitFor(
    String id, {
    Duration timeout = const Duration(seconds: 15),
  }) async {
    final finder = byId(id);
    final steps = timeout.inMilliseconds ~/ _step.inMilliseconds;
    for (var i = 0; i < steps; i++) {
      if (finder.evaluate().isNotEmpty) return finder;
      await tester.pump(_step);
    }
    throw TestFailure('Timed out after $timeout waiting for id "$id".');
  }

  /// Waits until [id] is no longer in the widget tree.
  Future<void> waitForAbsence(
    String id, {
    Duration timeout = const Duration(seconds: 15),
  }) async {
    final finder = byId(id);
    final steps = timeout.inMilliseconds ~/ _step.inMilliseconds;
    for (var i = 0; i < steps; i++) {
      if (finder.evaluate().isEmpty) return;
      await tester.pump(_step);
    }
    throw TestFailure('Timed out after $timeout: id "$id" is still shown.');
  }

  /// Scrolls the first scrollable until [id] is built, then returns it.
  Future<Finder> reveal(String id) async {
    final finder = byId(id);
    if (finder.evaluate().isEmpty) {
      await tester.scrollUntilVisible(
        finder,
        300,
        scrollable: find.byType(Scrollable).first,
      );
    }
    return waitFor(id);
  }

  Future<void> tap(String id) async {
    final finder = (await waitFor(id)).first;
    await tester.ensureVisible(finder);
    await settle();
    await tester.tap(finder);
    await settle();
  }

  /// Taps [id] only if it appears within [within]; returns whether it did.
  Future<bool> tapIfShown(
    String id, {
    Duration within = const Duration(seconds: 2),
  }) async {
    try {
      await waitFor(id, timeout: within);
    } on TestFailure {
      return false;
    }
    await tap(id);
    return true;
  }

  /// Taps [id] and pumps briefly without settling, so a request started by
  /// the tap is still in flight afterwards (duplicate-submission checks).
  /// A disabled control simply ignores the tap.
  Future<void> tapWithoutSettling(String id) async {
    final finder = (await waitFor(id)).first;
    await tester.tap(finder, warnIfMissed: false);
    await tester.pump(const Duration(milliseconds: 200));
  }

  /// Pops the current route with the app bar back button.
  Future<void> back() async {
    await tester.pageBack();
    await settle();
  }

  Future<void> enterText(String id, String text) async {
    final field = find
        .descendant(of: await waitFor(id), matching: find.byType(EditableText))
        .first;
    await tester.ensureVisible(field);
    await tester.enterText(field, text);
    await settle();
  }

  void expectShown(String id) => expect(byId(id), findsWidgets);

  void expectNotShown(String id) => expect(byId(id), findsNothing);
}
