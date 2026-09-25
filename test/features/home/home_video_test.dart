import 'package:bookmyspace/core/localization/app_localizations.dart';
import 'package:bookmyspace/features/home/domain/home_appearance.dart';
import 'package:bookmyspace/features/home/presentation/widgets/home_video_pill.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _app(Widget child) {
  return MaterialApp(
    home: Scaffold(body: child),
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
  );
}

void main() {
  group('HomeVideoPill.isPlayable', () {
    test('accepts ordinary http and https links', () {
      for (final url in const [
        'https://cdn.example/tour.mp4',
        'http://cdn.example/tour.mp4',
        'https://www.youtube.com/watch?v=abc123',
        'https://vimeo.com/12345',
      ]) {
        expect(HomeVideoPill.isPlayable(url), isTrue, reason: url);
      }
    });

    test('rejects anything that is not a web link', () {
      // A stored value must never become a file disclosure or an execution
      // primitive on the device that renders it.
      for (final hostile in const [
        'javascript:alert(1)',
        'file:///etc/passwd',
        'intent://scan/#Intent;scheme=zxing;end',
        'data:text/html;base64,PHNjcmlwdD4=',
        'ftp://example.com/x.mp4',
        '/etc/passwd',
        'not a url',
        '',
        '   ',
      ]) {
        expect(HomeVideoPill.isPlayable(hostile), isFalse, reason: hostile);
      }
    });

    test('rejects a link with no host', () {
      expect(HomeVideoPill.isPlayable('https://'), isFalse);
      expect(HomeVideoPill.isPlayable('http:///path'), isFalse);
    });

    test('playable() keeps only the safe links, in order', () {
      expect(
        HomeVideoPill.playable(const [
          'javascript:alert(1)',
          'https://ok.example/a.mp4',
          'file:///etc/passwd',
          'https://ok.example/b.mp4',
        ]),
        ['https://ok.example/a.mp4', 'https://ok.example/b.mp4'],
      );
    });
  });

  group('HomeBlockConfig videos', () {
    test('round-trips through JSON', () {
      const block = HomeBlockConfig(
        kind: HomeBlockKind.spotlight,
        videos: ['https://cdn.example/a.mp4'],
      );
      final restored = HomeBlockConfig.fromJson(block.toJson(), block.kind);
      expect(restored.videos, ['https://cdn.example/a.mp4']);
    });

    test('drops blank entries instead of storing broken references', () {
      final block = HomeBlockConfig.fromJson(const {
        'kind': 'spotlight',
        'videos': ['https://a.mp4', '', '   ', 'https://b.mp4'],
      }, HomeBlockKind.spotlight);
      expect(block.videos, ['https://a.mp4', 'https://b.mp4']);
    });

    test('an absent or malformed list yields no videos', () {
      expect(
        HomeBlockConfig.fromJson(
                const {'kind': 'spotlight'}, HomeBlockKind.spotlight)
            .videos,
        isEmpty,
      );
      expect(
        HomeBlockConfig.fromJson(const {'kind': 'spotlight', 'videos': 'nope'},
                HomeBlockKind.spotlight)
            .videos,
        isEmpty,
      );
    });

    test('copyWith replaces the list', () {
      const block = HomeBlockConfig(kind: HomeBlockKind.spotlight);
      final updated = block.copyWith(videos: const ['https://a.mp4']);
      expect(updated.videos, ['https://a.mp4']);
      // The original is untouched.
      expect(block.videos, isEmpty);
    });

    test('images and videos stay independent', () {
      const block = HomeBlockConfig(
        kind: HomeBlockKind.spotlight,
        images: ['https://a.jpg'],
        videos: ['https://a.mp4'],
      );
      final restored = HomeBlockConfig.fromJson(block.toJson(), block.kind);
      expect(restored.images, ['https://a.jpg']);
      expect(restored.videos, ['https://a.mp4']);
    });
  });

  group('HomeVideoPill', () {
    testWidgets('renders nothing when the section has no videos',
        (tester) async {
      await tester.pumpWidget(_app(const HomeVideoPill(videos: [])));
      expect(find.text('Watch'), findsNothing);
    });

    testWidgets('shows the count when a section has several videos',
        (tester) async {
      await tester.pumpWidget(
        _app(const HomeVideoPill(videos: ['https://a.mp4', 'https://b.mp4'])),
      );
      expect(find.text('Watch · 2'), findsOneWidget);
    });

    testWidgets('opens the first link the platform can handle', (tester) async {
      Uri? opened;
      await tester.pumpWidget(
        _app(
          HomeVideoPill(
            videos: const ['https://cdn.example/tour.mp4'],
            onOpen: (uri) async {
              opened = uri;
              return true;
            },
          ),
        ),
      );

      await tester.tap(find.text('Watch'));
      await tester.pumpAndSettle();

      expect(opened, Uri.parse('https://cdn.example/tour.mp4'));
    });

    testWidgets('skips a hostile link and opens the next safe one',
        (tester) async {
      Uri? opened;
      await tester.pumpWidget(
        _app(
          HomeVideoPill(
            videos: const ['javascript:alert(1)', 'https://cdn.example/ok.mp4'],
            onOpen: (uri) async {
              opened = uri;
              return true;
            },
          ),
        ),
      );

      await tester.tap(find.byType(ActionChip));
      await tester.pumpAndSettle();

      expect(opened, Uri.parse('https://cdn.example/ok.mp4'));
    });

    testWidgets('reports rather than opening when no link is usable',
        (tester) async {
      var attempted = false;
      await tester.pumpWidget(
        _app(
          HomeVideoPill(
            videos: const ['javascript:alert(1)'],
            onOpen: (uri) async {
              attempted = true;
              return true;
            },
          ),
        ),
      );

      await tester.tap(find.text('Watch'));
      await tester.pumpAndSettle();

      expect(attempted, isFalse);
      expect(find.text('This video could not be opened.'), findsOneWidget);
    });

    testWidgets('reports when the platform refuses to open the link',
        (tester) async {
      await tester.pumpWidget(
        _app(
          HomeVideoPill(
            videos: const ['https://cdn.example/tour.mp4'],
            onOpen: (uri) async => false,
          ),
        ),
      );

      await tester.tap(find.text('Watch'));
      await tester.pumpAndSettle();

      expect(find.text('This video could not be opened.'), findsOneWidget);
    });
  });
}
