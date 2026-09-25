import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:bookmyspace/features/map/presentation/widgets/osm_tile_layer.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

void main() {
  // Install a blank-tile HTTP mock before every test so that
  // NetworkTileProvider never opens a real socket.  Production OSM URLs are
  // intentionally left unchanged; the mock operates only at the dart:io
  // HttpClient layer, invisible to the widget under test.
  setUp(() => HttpOverrides.global = _BlankTileOverrides());
  tearDown(() => HttpOverrides.global = null);

  test('OSM tiles are used on every platform – no API key required', () {
    expect(OsmMapTiles.urlTemplate, OsmMapTiles.osmUrl);
    expect(OsmMapTiles.fallbackUrl, isNull);
    expect(OsmMapTiles.osmUrl.contains('{s}'), isFalse);
    expect(OsmMapTiles.attributionLabel, '© OpenStreetMap');
  });

  test('CARTO URL constants are retained for reference', () {
    expect(OsmMapTiles.cartoLightUrl.contains('{s}'), isTrue);
    expect(OsmMapTiles.cartoVoyagerUrl.contains('{s}'), isTrue);
    expect(OsmMapTiles.cartoSubdomains, ['a', 'b', 'c', 'd']);
  });

  testWidgets('OsmTileLayer wires OSM URL and attribution', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: FlutterMap(
          options: MapOptions(
            initialCenter: LatLng(17.3850, 78.4867),
            initialZoom: 12,
          ),
          children: [
            OsmTileLayer(),
            OsmAttribution(),
          ],
        ),
      ),
    );

    final tileLayer = tester.widget<TileLayer>(find.byType(TileLayer));
    expect(tileLayer.urlTemplate, OsmMapTiles.urlTemplate);
    expect(tileLayer.urlTemplate, OsmMapTiles.osmUrl);
    expect(tileLayer.fallbackUrl, isNull);
    expect(tileLayer.subdomains, OsmMapTiles.cartoSubdomains);
    // flutter_map 7.0.2 does not store userAgentPackageName as a field; it is
    // applied to the tile provider's User-Agent header on native platforms.
    if (!kIsWeb) {
      expect(
        tileLayer.tileProvider.headers['User-Agent'],
        'flutter_map (${OsmMapTiles.userAgentPackageName})',
      );
    }
    expect(
      find.textContaining(OsmMapTiles.attributionLabel),
      findsOneWidget,
    );
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// Blank-tile HTTP mock
//
// Intercepts dart:io HttpClient creation (which the http package's IOClient,
// used internally by NetworkTileProvider, ultimately calls) and returns a
// 200 OK response whose body is a 1×1 transparent PNG.  This prevents any
// real OSM tile requests during widget tests while leaving OsmTileLayer's URL
// configuration fully verifiable.
// ─────────────────────────────────────────────────────────────────────────────

// 1×1 transparent PNG – 68 bytes, smallest valid PNG.
final Uint8List _kBlankTile = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJ'
  'AAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==',
);

class _BlankTileOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) =>
      _BlankTileHttpClient();
}

/// Minimal [HttpClient] that answers every GET / openUrl with a blank PNG 200.
class _BlankTileHttpClient implements HttpClient {
  @override bool autoUncompress = true;
  @override Duration? connectionTimeout;
  @override Duration idleTimeout = const Duration(seconds: 15);
  @override int? maxConnectionsPerHost;
  @override String? userAgent;

  @override
  Future<HttpClientRequest> getUrl(Uri url) async => _BlankTileRequest();

  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) async =>
      _BlankTileRequest();

  // ── Stubs for interface completeness ──────────────────────────────────────

  @override void addCredentials(Uri u, String r, HttpClientCredentials c) {}
  @override void addProxyCredentials(
      String h, int p, String r, HttpClientCredentials c) {}
  @override set authenticate(Future<bool> Function(Uri, String, String?)? f) {}
  @override set authenticateProxy(
      Future<bool> Function(String, int, String, String?)? f) {}
  @override set badCertificateCallback(
      bool Function(X509Certificate, String, int)? cb) {}
  @override set keyLog(Function(String)? cb) {}
  @override void close({bool force = false}) {}
  @override set findProxy(String Function(Uri)? f) {}
  @override set connectionFactory(
      Future<ConnectionTask<Socket>> Function(Uri, String?, int?)? f) {}

  Uri _u(String h, int p, String path) =>
      Uri(scheme: 'https', host: h, port: p, path: path);

  @override
  Future<HttpClientRequest> delete(String h, int p, String path) =>
      openUrl('DELETE', _u(h, p, path));
  @override
  Future<HttpClientRequest> deleteUrl(Uri u) => openUrl('DELETE', u);
  @override
  Future<HttpClientRequest> get(String h, int p, String path) =>
      openUrl('GET', _u(h, p, path));
  @override
  Future<HttpClientRequest> head(String h, int p, String path) =>
      openUrl('HEAD', _u(h, p, path));
  @override
  Future<HttpClientRequest> headUrl(Uri u) => openUrl('HEAD', u);
  @override
  Future<HttpClientRequest> open(
          String method, String h, int p, String path) =>
      openUrl(method, _u(h, p, path));
  @override
  Future<HttpClientRequest> patch(String h, int p, String path) =>
      openUrl('PATCH', _u(h, p, path));
  @override
  Future<HttpClientRequest> patchUrl(Uri u) => openUrl('PATCH', u);
  @override
  Future<HttpClientRequest> post(String h, int p, String path) =>
      openUrl('POST', _u(h, p, path));
  @override
  Future<HttpClientRequest> postUrl(Uri u) => openUrl('POST', u);
  @override
  Future<HttpClientRequest> put(String h, int p, String path) =>
      openUrl('PUT', _u(h, p, path));
  @override
  Future<HttpClientRequest> putUrl(Uri u) => openUrl('PUT', u);
}

/// Fake [HttpClientRequest] – accepts header writes, returns [_BlankTileResponse].
class _BlankTileRequest implements HttpClientRequest {
  @override final HttpHeaders headers = _StubHeaders();
  @override String get method => 'GET';
  @override Uri get uri => Uri.parse('https://tile.example.test/0/0/0.png');
  @override List<Cookie> get cookies => const [];
  @override bool bufferOutput = true;
  @override int contentLength = -1;
  @override Encoding encoding = utf8;
  @override bool followRedirects = true;
  @override int maxRedirects = 5;
  @override bool persistentConnection = true;
  @override HttpConnectionInfo? get connectionInfo => null;
  @override Future<HttpClientResponse> get done => close();
  @override Future<HttpClientResponse> close() async => _BlankTileResponse();
  @override void add(List<int> data) {}
  @override void addError(Object e, [StackTrace? t]) {}
  @override Future<void> addStream(Stream<List<int>> s) async {}
  @override void write(Object? o) {}
  @override void writeAll(Iterable<dynamic> o, [String sep = '']) {}
  @override void writeCharCode(int c) {}
  @override void writeln([Object? o = '']) {}
  @override Future<void> flush() async {}
  @override void abort([Object? e, StackTrace? t]) {}
}

/// Fake [HttpClientResponse] – 200 OK, body = blank 1×1 PNG.
class _BlankTileResponse extends Stream<List<int>>
    implements HttpClientResponse {
  @override int get statusCode => HttpStatus.ok;
  @override String get reasonPhrase => 'OK';
  @override int get contentLength => _kBlankTile.length;
  @override HttpClientResponseCompressionState get compressionState =>
      HttpClientResponseCompressionState.notCompressed;
  @override bool get isRedirect => false;
  @override bool get persistentConnection => false;
  @override List<Cookie> get cookies => const [];
  @override List<RedirectInfo> get redirects => const [];
  @override HttpConnectionInfo? get connectionInfo => null;
  @override final HttpHeaders headers = _StubHeaders();
  @override X509Certificate? get certificate => null;

  @override
  Future<Socket> detachSocket() {
    throw UnsupportedError('Blank tile responses have no socket');
  }

  @override
  Future<HttpClientResponse> redirect([
    String? method,
    Uri? url,
    bool? followLoops,
  ]) =>
      Future.value(this);

  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int>)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) =>
      Stream.value(List<int>.from(_kBlankTile)).listen(
        onData,
        onError: onError,
        onDone: onDone,
        cancelOnError: cancelOnError,
      );
}

/// Minimal [HttpHeaders] that stores and serves written values.
class _StubHeaders implements HttpHeaders {
  final _store = <String, List<String>>{};

  @override
  List<String>? operator [](String name) => _store[name.toLowerCase()];

  @override
  void add(String name, Object value, {bool preserveHeaderCase = false}) =>
      (_store[name.toLowerCase()] ??= []).add(value.toString());

  @override
  void set(String name, Object value, {bool preserveHeaderCase = false}) =>
      _store[name.toLowerCase()] = [value.toString()];

  @override
  void remove(String name, Object value) =>
      _store[name.toLowerCase()]?.remove(value.toString());

  @override void removeAll(String name) => _store.remove(name.toLowerCase());
  @override void clear() => _store.clear();
  @override void noFolding(String name) {}

  @override
  void forEach(void Function(String name, List<String> values) f) =>
      _store.forEach(f);

  @override
  String? value(String name) => _store[name.toLowerCase()]?.firstOrNull;

  @override bool chunkedTransferEncoding = false;
  @override int contentLength = -1;
  @override ContentType? contentType;
  @override DateTime? date;
  @override DateTime? expires;
  @override DateTime? ifModifiedSince;
  @override bool persistentConnection = false;
  @override String? host;
  @override int? port;
}
