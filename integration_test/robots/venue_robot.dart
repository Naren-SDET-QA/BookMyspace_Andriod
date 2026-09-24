import 'package:bookmyspace/core/widgets/test_id.dart';

import 'base_robot.dart';

class VenueRobot extends BaseRobot {
  VenueRobot(super.tester);

  Future<void> expectDetails() => waitFor(E2eIds.bookNow);

  Future<void> toggleFavorite() => tap(E2eIds.venueFavorite);

  Future<void> startBooking() => tap(E2eIds.bookNow);
}
