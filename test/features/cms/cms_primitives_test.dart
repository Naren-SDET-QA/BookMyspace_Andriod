import 'package:bookmyspace/features/cms/domain/cms_icon.dart';
import 'package:bookmyspace/features/cms/domain/cms_localized_text.dart';
import 'package:bookmyspace/features/cms/domain/cms_media_ref.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CmsIcon', () {
    test('resolves every known id to a real glyph', () {
      for (final id in CmsIcon.knownIds) {
        expect(CmsIcon.resolve(id), isA<IconData>());
        expect(CmsIcon.isKnown(id), isTrue);
      }
    });

    test('unknown, empty and non-string ids fall back instead of throwing', () {
      expect(CmsIcon.resolve('no_such_icon'), CmsIcon.fallback);
      expect(CmsIcon.resolve(''), CmsIcon.fallback);
      expect(CmsIcon.resolve(null), CmsIcon.fallback);
      expect(CmsIcon.resolve(42), CmsIcon.fallback);
      expect(CmsIcon.resolve(const {'a': 1}), CmsIcon.fallback);
    });

    test('normalize collapses anything unrenderable to the fallback id', () {
      expect(CmsIcon.normalize('hall'), 'hall');
      expect(CmsIcon.normalize('  hall  '), 'hall');
      expect(CmsIcon.normalize('no_such_icon'), CmsIcon.fallbackId);
      expect(CmsIcon.normalize(null), CmsIcon.fallbackId);
      expect(CmsIcon.normalize(7), CmsIcon.fallbackId);
    });

    test('the fallback id is itself resolvable', () {
      expect(CmsIcon.isKnown(CmsIcon.fallbackId), isTrue);
      expect(CmsIcon.resolve(CmsIcon.fallbackId), CmsIcon.fallback);
    });

    test('ids used by the shipped catalogue defaults all exist', () {
      // Guards against a default referencing an id nobody added to the
      // registry, which would silently repaint a section as a generic box.
      const used = [
        'hall',
        'turf',
        'home',
        'school',
        'hotel',
        'ring',
        'banquet',
        'convention',
        'party',
        'celebration',
        'toast',
        'crown',
        'garden',
        'gym',
        'desk',
        'camera',
        'person',
        'backpack',
        'sofa',
        'book',
        'pencil',
        'computer',
        'music',
        'clock',
        'bed',
        'palm',
      ];
      for (final id in used) {
        expect(CmsIcon.isKnown(id), isTrue, reason: 'missing icon id: $id');
      }
    });
  });

  group('CmsLocalizedText', () {
    test('resolves an override, then the base', () {
      const text = CmsLocalizedText(
        base: 'Function Halls',
        overrides: {'te': 'ఫంక్షన్ హాల్స్'},
      );
      expect(text.resolve('te'), 'ఫంక్షన్ హాల్స్');
      expect(text.resolve('en'), 'Function Halls');
      expect(text.resolve('zz'), 'Function Halls');
    });

    test('a blank override never wins over the base', () {
      const text = CmsLocalizedText(
        base: 'Sports',
        overrides: {'hi': '   '},
      );
      expect(text.resolve('hi'), 'Sports');
    });

    test('resolveOr falls back to the caller-supplied l10n string', () {
      const empty = CmsLocalizedText();
      expect(empty.resolveOr('en', 'Shipped title'), 'Shipped title');

      const withBase = CmsLocalizedText(base: 'CMS title');
      expect(withBase.resolveOr('en', 'Shipped title'), 'CMS title');
    });

    test('withLanguage clears an override instead of storing an empty string',
        () {
      const text = CmsLocalizedText(base: 'Base', overrides: {'ta': 'தமிழ்'});
      final cleared = text.withLanguage('ta', '  ');
      expect(cleared.overrides.containsKey('ta'), isFalse);
      expect(cleared.resolve('ta'), 'Base');

      final set = text.withLanguage('kn', 'ಕನ್ನಡ');
      expect(set.resolve('kn'), 'ಕನ್ನಡ');
      expect(set.resolve('ta'), 'தமிழ்', reason: 'other languages untouched');
    });

    test('parses a bare string, an envelope, and a bare map', () {
      expect(CmsLocalizedText.fromJson('Hello').base, 'Hello');

      final envelope = CmsLocalizedText.fromJson(const {
        'base': 'Hello',
        'i18n': {'hi': 'नमस्ते'},
      });
      expect(envelope.base, 'Hello');
      expect(envelope.resolve('hi'), 'नमस्ते');

      final bare = CmsLocalizedText.fromJson(const {'hi': 'नमस्ते'});
      expect(bare.base, '');
      expect(bare.resolve('hi'), 'नमस्ते');
    });

    test('malformed input yields empty rather than throwing', () {
      expect(CmsLocalizedText.fromJson(null), CmsLocalizedText.empty);
      expect(CmsLocalizedText.fromJson(42), CmsLocalizedText.empty);
      expect(CmsLocalizedText.fromJson(const []), CmsLocalizedText.empty);
    });

    test('drops non-string and blank override values', () {
      final text = CmsLocalizedText.fromJson(const {
        'base': 'Base',
        'i18n': {'te': 'ok', 'hi': 7, 'kn': '', 'ta': '   '},
      });
      expect(text.overrides.keys, ['te']);
    });

    test('round-trips through toJson', () {
      const text = CmsLocalizedText(
        base: 'Education',
        overrides: {'te': 'విద్య'},
      );
      expect(CmsLocalizedText.fromJson(text.toJson()), text);
    });

    test('an all-empty value serializes to an empty map', () {
      expect(CmsLocalizedText.empty.toJson(), isEmpty);
    });
  });

  group('CmsMediaRef', () {
    test('accepts absolute http and https urls', () {
      expect(CmsMediaRef.fromJson('https://cdn.example/a.jpg').url,
          'https://cdn.example/a.jpg');
      expect(
          CmsMediaRef.fromJson('http://cdn.example/a.jpg').isNotEmpty, isTrue);
    });

    test('rejects non-http schemes and malformed values', () {
      expect(CmsMediaRef.fromJson('javascript:alert(1)'), CmsMediaRef.none);
      expect(CmsMediaRef.fromJson('file:///etc/passwd'), CmsMediaRef.none);
      expect(CmsMediaRef.fromJson('not a url'), CmsMediaRef.none);
      expect(CmsMediaRef.fromJson(''), CmsMediaRef.none);
      expect(CmsMediaRef.fromJson(null), CmsMediaRef.none);
      expect(CmsMediaRef.fromJson(42), CmsMediaRef.none);
      expect(CmsMediaRef.fromJson(const {'url': 'javascript:x'}),
          CmsMediaRef.none);
      expect(
          CmsMediaRef.fromJson(const {'path': 'home/a.jpg'}), CmsMediaRef.none,
          reason: 'a path without a usable url is not a reference');
    });

    test('keeps the storage path alongside the url', () {
      final ref = CmsMediaRef.fromJson(const {
        'url': 'https://cdn.example/home/a.jpg',
        'path': 'home/category_matrix/1.jpg',
      });
      expect(ref.path, 'home/category_matrix/1.jpg');
      expect(CmsMediaRef.fromJson(ref.toJson()), ref);
    });

    test('omits an empty path when serializing', () {
      const ref = CmsMediaRef(url: 'https://cdn.example/a.jpg');
      expect(ref.toJson().containsKey('path'), isFalse);
    });
  });
}
