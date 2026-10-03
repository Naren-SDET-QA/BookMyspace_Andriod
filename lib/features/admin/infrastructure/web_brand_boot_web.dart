import 'dart:js_interop';

@JS('bookMySpaceBrandBoot')
external JSObject? get _brandBoot;

@JS('bookMySpaceBrandBoot.save')
external void _jsSave(JSString json);

/// Hands the published global branding to `window.bookMySpaceBrandBoot` in
/// web/index.html so the pre-Flutter boot loader shows the same logo and
/// loading animation on the next start / refresh.
class WebBrandBoot {
  const WebBrandBoot._();

  static void save(String json) {
    try {
      if (_brandBoot == null) return;
      _jsSave(json.toJS);
    } catch (_) {
      // Boot-loader cache is best effort; never break the app over it.
    }
  }
}
