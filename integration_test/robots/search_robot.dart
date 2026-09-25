import 'package:bookmyspace/core/widgets/test_id.dart';
import 'package:flutter/material.dart';

import 'base_robot.dart';

/// Home/search discovery.
class SearchRobot extends BaseRobot {
  SearchRobot(super.tester);

  Future<void> search(String query) async {
    await enterText(E2eIds.searchInput, query);
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await settle();
  }

  Future<void> expectVenueListed(String venueId) =>
      waitFor(E2eIds.venueCard(venueId));

  Future<void> openVenue(String venueId) => tap(E2eIds.venueCard(venueId));
}
