import 'package:flutter_test/flutter_test.dart';
import 'package:bookmyspace/features/cms/domain/cms_media_asset.dart';

void main() {
  group('CmsMediaRules', () {
    test('accepts supported images within the limit', () {
      expect(CmsMediaRules.validateFile(name: 'hero.PNG', bytes: 12), isNull);
    });

    test('rejects unsupported types and oversized files', () {
      expect(CmsMediaRules.validateFile(name: 'script.svg', bytes: 12), isNotNull);
      expect(CmsMediaRules.validateFile(name: 'hero.jpg', bytes: CmsMediaRules.maxBytes + 1), isNotNull);
    });

    test('normalizes names and keeps uploads inside the CMS namespace', () {
      final path = CmsMediaRules.objectPath(fileName: r'..\unsafe name.png', stamp: 42);
      expect(path, 'cms/42-unsafe_name.png');
      expect(CmsMediaRules.isManagedPath(path), isTrue);
      expect(CmsMediaRules.isManagedPath('../other/file.png'), isFalse);
      expect(CmsMediaRules.isManagedPath('categories/1.png'), isFalse);
    });
  });
}
