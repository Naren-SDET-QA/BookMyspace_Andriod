import 'package:bookmyspace/core/config/app_config.dart';
import 'package:bookmyspace/core/errors/app_exceptions.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('placeholder host is detected case-insensitively', () {
    expect(
      AppConfig.isPlaceholderSupabaseHostFor(
        'https://YOUR_PROJECT.supabase.co',
      ),
      isTrue,
    );
    expect(
      AppConfig.isPlaceholderSupabaseHostFor(
        'https://your_project.supabase.co/rest/v1/venues',
      ),
      isTrue,
    );
    expect(
      AppConfig.isPlaceholderSupabaseHostFor(
        'https://zykxneztahxbjduagutv.supabase.co',
      ),
      isFalse,
    );
  });

  test('mapError turns host lookup failures into a human-readable network error',
      () {
    final mapped = mapError(
      Exception(
        "ClientException with SocketException: Failed host lookup: 'your_project.supabase.co'",
      ),
    );
    expect(mapped, isA<NetworkException>());
    expect(mapped.message, contains('Unable to reach BookMySpace'));
    expect(mapped.message.toLowerCase(), isNot(contains('socketexception')));
  });
}
