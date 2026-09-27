import 'package:bookmyspace/core/widgets/category_icon_text.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('emoji pass through unchanged', () {
    expect(categoryIconText('🏸'), '🏸');
    expect(categoryIconText('🧑‍💼'), '🧑‍💼');
  });

  test('known Material icon names become emoji', () {
    expect(categoryIconText('groups'), '👥');
    expect(categoryIconText('menu_book'), '📖');
    expect(categoryIconText('computer'), '💻');
  });

  test('unknown names and blanks use the fallback, never the raw name', () {
    expect(categoryIconText('some_icon_name', fallback: '🏷️'), '🏷️');
    expect(categoryIconText('  ', fallback: '✨'), '✨');
    expect(categoryIconText(null), '');
    expect(categoryIconOrNull('unknown_name'), isNull);
  });
}
