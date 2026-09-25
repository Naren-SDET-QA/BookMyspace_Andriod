import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../errors/app_exceptions.dart';

enum ConnectivityStatus { unknown, online, offline }

/// Last-known connectivity inferred from request outcomes.
///
/// This is not a live radio probe. It never treats a failed write as success
/// and never presents stale booking availability as live.
class ConnectivityNotifier extends Notifier<ConnectivityStatus> {
  @override
  ConnectivityStatus build() => ConnectivityStatus.unknown;

  void reportSuccess() {
    if (state != ConnectivityStatus.online) {
      state = ConnectivityStatus.online;
    }
  }

  void reportFailure(Object error) {
    if (isRetryableReadError(error) || error is NetworkException) {
      state = ConnectivityStatus.offline;
      return;
    }
    if (state == ConnectivityStatus.unknown) {
      state = ConnectivityStatus.online;
    }
  }
}

final connectivityStatusProvider =
    NotifierProvider<ConnectivityNotifier, ConnectivityStatus>(
  ConnectivityNotifier.new,
);
