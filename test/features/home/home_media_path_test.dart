import 'package:bookmyspace/features/home/infrastructure/home_media_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('HomeMediaPath', () {
    test('writes to the bucket whose policies are already admin-gated', () {
      // This is load-bearing: `category-media` is the only existing bucket whose
      // insert/update/delete policies gate through private.is_category_manager()
      // (administrator / super_administrator only) while still allowing public
      // read. Pointing this at a bucket without those policies would either
      // break admin uploads or widen who can write media.
      expect(HomeMediaPath.bucket, 'category-media');
    });

    test('namespaces artwork under home/<block>', () {
      final path = HomeMediaPath.objectPath(
        blockKindId: 'spotlight',
        extension: 'png',
        stamp: 123,
      );
      expect(path, 'home/spotlight/123.png');
    });

    test('cannot be made to traverse out of its namespace', () {
      for (final hostile in const [
        '../../etc/passwd',
        'home/../../secret',
        r'..\..\windows',
        'spot light',
        'offer_banner/../x',
      ]) {
        final path = HomeMediaPath.objectPath(
          blockKindId: hostile,
          extension: 'jpg',
          stamp: 1,
        );
        expect(path.startsWith('home/'), isTrue, reason: hostile);
        expect(path.contains('..'), isFalse, reason: hostile);
        expect(path.split('/').length, 3, reason: hostile);
      }
    });

    test('falls back to a plain namespace when the block id is unusable', () {
      expect(
        HomeMediaPath.objectPath(
          blockKindId: '',
          extension: 'jpg',
          stamp: 9,
        ),
        'home/block/9.jpg',
      );
      expect(
        HomeMediaPath.objectPath(
          blockKindId: '!!!',
          extension: 'jpg',
          stamp: 9,
        ),
        'home/block/9.jpg',
      );
    });

    test('never writes an unvetted extension into a public bucket', () {
      for (final hostile in const ['php', 'html', 'svg', 'exe', '', '  ']) {
        final path = HomeMediaPath.objectPath(
          blockKindId: 'spotlight',
          extension: hostile,
          stamp: 5,
        );
        expect(path, 'home/spotlight/5.jpg', reason: 'extension "$hostile"');
      }
    });

    test('accepts only image extensions', () {
      for (final allowed in const ['jpg', 'jpeg', 'png', 'webp', 'gif']) {
        expect(HomeMediaPath.isAllowedExtension(allowed), isTrue, reason: allowed);
      }
      // Case and surrounding noise are normalised away first.
      expect(HomeMediaPath.isAllowedExtension('PNG'), isTrue);
      expect(HomeMediaPath.isAllowedExtension('.jpg'), isTrue);

      for (final rejected in const ['svg', 'heic', 'pdf', 'exe', '']) {
        expect(HomeMediaPath.isAllowedExtension(rejected), isFalse,
            reason: rejected);
      }
    });

    test('maps each extension to the right content type', () {
      expect(HomeMediaPath.contentType('png'), 'image/png');
      expect(HomeMediaPath.contentType('webp'), 'image/webp');
      expect(HomeMediaPath.contentType('gif'), 'image/gif');
      expect(HomeMediaPath.contentType('jpg'), 'image/jpeg');
      expect(HomeMediaPath.contentType('jpeg'), 'image/jpeg');
      // Anything unrecognised must not be served as a generic binary.
      expect(HomeMediaPath.contentType('svg'), 'image/jpeg');
    });

    test('caps uploads at 10 MB', () {
      expect(HomeMediaPath.maxBytes, 10 * 1024 * 1024);
    });

    test('two uploads of the same block never share a path', () {
      final a = HomeMediaPath.objectPath(
        blockKindId: 'spotlight',
        extension: 'jpg',
        stamp: 1,
      );
      final b = HomeMediaPath.objectPath(
        blockKindId: 'spotlight',
        extension: 'jpg',
        stamp: 2,
      );
      expect(a, isNot(b));
    });
  });

  group('HomeMediaPath video rules', () {
    test('accepts exactly the containers every platform can play', () {
      expect(HomeMediaPath.allowedVideoExtensions, ['mp4', 'webm', 'mov']);
      for (final allowed in const ['mp4', 'webm', 'mov']) {
        expect(HomeMediaPath.isAllowedVideoExtension(allowed), isTrue,
            reason: allowed);
      }
      // Case and surrounding noise are normalised away first.
      expect(HomeMediaPath.isAllowedVideoExtension('MP4'), isTrue);
      expect(HomeMediaPath.isAllowedVideoExtension('.webm'), isTrue);
    });

    test('does not let an image extension pass as a video', () {
      for (final rejected in const ['jpg', 'png', 'gif', 'svg', 'exe', '']) {
        expect(HomeMediaPath.isAllowedVideoExtension(rejected), isFalse,
            reason: rejected);
      }
    });

    test('maps each video extension to the right content type', () {
      expect(HomeMediaPath.videoContentType('mp4'), 'video/mp4');
      expect(HomeMediaPath.videoContentType('webm'), 'video/webm');
      expect(HomeMediaPath.videoContentType('mov'), 'video/quicktime');
    });

    test('refuses a content type for anything that is not a video', () {
      // Null rather than an image fallback: a caller that skipped validation
      // must fail loudly instead of storing a clip the browser would reject
      // because it was served as image/jpeg.
      for (final notVideo in const ['jpg', 'png', 'svg', 'exe', '', '  ']) {
        expect(HomeMediaPath.videoContentType(notVideo), isNull,
            reason: notVideo);
      }
    });

    test('preserves a video extension in the stored path', () {
      for (final extension in const ['mp4', 'webm', 'mov']) {
        expect(
          HomeMediaPath.objectPath(
            blockKindId: 'spotlight',
            extension: extension,
            stamp: 7,
          ),
          'home/spotlight/7.$extension',
        );
      }
    });

    test('still refuses an unvetted extension on the video path', () {
      for (final hostile in const ['php', 'html', 'svg', 'exe', '']) {
        expect(
          HomeMediaPath.objectPath(
            blockKindId: 'spotlight',
            extension: hostile,
            stamp: 7,
          ),
          'home/spotlight/7.jpg',
          reason: hostile,
        );
      }
    });

    test('gives clips a larger ceiling than artwork', () {
      expect(HomeMediaPath.maxVideoBytes, 25 * 1024 * 1024);
      expect(HomeMediaPath.maxVideoBytes, greaterThan(HomeMediaPath.maxBytes));
    });
  });
}
