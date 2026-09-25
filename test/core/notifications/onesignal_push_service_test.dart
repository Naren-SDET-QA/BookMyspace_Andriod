import 'package:bookmyspace/core/notifications/onesignal_push_service.dart';
import 'package:bookmyspace/features/admin/domain/admin_settings.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../features/notifications/mock_device_token_repository.dart';

const _appId = '00000000-0000-4000-8000-000000000000';

/// Records every OneSignal SDK call the service makes.
class FakePushSdk implements PushSdk {
  final List<String> calls = [];
  String? initializedWith;
  String? currentSubscriptionId = 'sub-1';
  final List<void Function(String?)> observers = [];

  @override
  Future<void> initialize(String appId) async {
    initializedWith = appId;
    calls.add('initialize');
  }

  @override
  Future<void> requestPermission() async => calls.add('requestPermission');

  @override
  void login(String externalId) => calls.add('login:$externalId');

  @override
  void logout() => calls.add('logout');

  @override
  void optIn() => calls.add('optIn');

  @override
  void optOut() => calls.add('optOut');

  @override
  String? get subscriptionId => currentSubscriptionId;

  @override
  void addSubscriptionObserver(void Function(String? id) observer) =>
      observers.add(observer);

  @override
  void removeSubscriptionObserver(void Function(String? id) observer) =>
      observers.remove(observer);
}

void main() {
  group('AdminSettings push switch', () {
    test('defaults to OFF', () {
      expect(AdminSettings.defaults.pushNotificationsEnabled, isFalse);
      expect(const AdminSettings().pushNotificationsEnabled, isFalse);
    });

    test('reads the push_notifications section', () {
      const on = AdminSettings(push: {AdminSettings.pushEnabledKey: true});
      const off = AdminSettings(push: {AdminSettings.pushEnabledKey: false});
      const junk = AdminSettings(push: {AdminSettings.pushEnabledKey: 'yes'});
      expect(on.pushNotificationsEnabled, isTrue);
      expect(off.pushNotificationsEnabled, isFalse);
      expect(junk.pushNotificationsEnabled, isFalse);
    });
  });

  group('OneSignalPushService -- admin DISABLED', () {
    test('never initialises OneSignal or registers the user', () async {
      final sdk = FakePushSdk();
      final repo = MockDeviceTokenRepository();
      final service = OneSignalPushService.forTesting(sdk: sdk, appId: _appId);

      await service.setEnabled(false);
      await service.onSignedIn(repo, 'user-1');
      await service.onSignedOut();

      expect(service.isActive, isFalse);
      expect(service.isSdkInitialized, isFalse);
      expect(sdk.calls, isEmpty);
      expect(repo.registered, isEmpty);
      expect(repo.deregistered, isEmpty);
    });

    test('ON with a missing/invalid App ID stays off', () async {
      for (final badId in ['', 'env-not-a-uuid']) {
        final sdk = FakePushSdk();
        final repo = MockDeviceTokenRepository();
        final service = OneSignalPushService.forTesting(sdk: sdk, appId: badId);

        await service.onSignedIn(repo, 'user-1');
        await service.setEnabled(true);

        expect(service.isActive, isFalse, reason: badId);
        expect(sdk.calls, isEmpty, reason: badId);
        expect(repo.registered, isEmpty, reason: badId);
      }
    });
  });

  group('OneSignalPushService -- admin ENABLED', () {
    test('initialises with the configured App ID exactly once', () async {
      final sdk = FakePushSdk();
      final service = OneSignalPushService.forTesting(sdk: sdk, appId: _appId);

      await service.setEnabled(true);
      await service.setEnabled(true);

      expect(service.isActive, isTrue);
      expect(sdk.initializedWith, _appId);
      expect(sdk.calls.where((c) => c == 'initialize'), hasLength(1));
    });

    test('registers a user who signed in before push was enabled', () async {
      final sdk = FakePushSdk();
      final repo = MockDeviceTokenRepository();
      final service = OneSignalPushService.forTesting(sdk: sdk, appId: _appId);

      await service.onSignedIn(repo, 'user-1');
      expect(sdk.calls, isEmpty);

      await service.setEnabled(true);
      expect(sdk.calls, ['initialize', 'requestPermission', 'login:user-1']);
      expect(repo.registered, {'sub-1': anything});
    });

    test('sign in / sign out while enabled registers and cleans up', () async {
      final sdk = FakePushSdk();
      final repo = MockDeviceTokenRepository();
      final service = OneSignalPushService.forTesting(sdk: sdk, appId: _appId);

      await service.setEnabled(true);
      await service.onSignedIn(repo, 'user-1');
      expect(repo.registered.keys, ['sub-1']);
      expect(sdk.observers, hasLength(1));

      await service.onSignedOut();
      expect(repo.deregistered, ['sub-1']);
      expect(sdk.calls.last, 'logout');
      expect(sdk.observers, isEmpty);
    });

    test('turning push OFF deregisters, logs out and opts out', () async {
      final sdk = FakePushSdk();
      final repo = MockDeviceTokenRepository();
      final service = OneSignalPushService.forTesting(sdk: sdk, appId: _appId);

      await service.setEnabled(true);
      await service.onSignedIn(repo, 'user-1');
      await service.setEnabled(false);

      expect(service.isActive, isFalse);
      expect(repo.deregistered, ['sub-1']);
      expect(sdk.calls, containsAllInOrder(['logout', 'optOut']));

      // Later sign-ins while OFF touch nothing.
      sdk.calls.clear();
      await service.onSignedIn(repo, 'user-2');
      expect(sdk.calls, isEmpty);

      // Re-enabling opts back in without re-initialising.
      await service.setEnabled(true);
      expect(sdk.calls.first, 'optIn');
      expect(sdk.calls, isNot(contains('initialize')));
      expect(sdk.calls, contains('login:user-2'));
    });
  });

  group('OneSignalPushService.instance (never enabled in flutter test)', () {
    test('sign in/out are safe no-ops', () async {
      final repo = MockDeviceTokenRepository();
      await OneSignalPushService.instance.onSignedIn(repo, 'user-a');
      await OneSignalPushService.instance.onSignedOut();
      await OneSignalPushService.instance.onSignedIn(repo, '');
      expect(OneSignalPushService.instance.isActive, isFalse);
      expect(repo.registered, isEmpty);
      expect(repo.deregistered, isEmpty);
    });

    test('setEnabled(false) is a safe no-op', () async {
      await expectLater(
        OneSignalPushService.instance.setEnabled(false),
        completes,
      );
      expect(OneSignalPushService.instance.isSdkInitialized, isFalse);
    });
  });
}
