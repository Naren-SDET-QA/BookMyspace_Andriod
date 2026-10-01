import 'package:speech_to_text/speech_to_text.dart';

import '../../features/payments/domain/checkout_service.dart';
// Main-lineage Razorpay services (native SDK + Checkout.js); the
// release/v1.0 factory in features/payments/presentation is kept as well.
import '../../features/payments/infrastructure/checkout_service_factory.dart';
import 'plugin_kind.dart';
import 'plugins/flutter_map_plugin.dart';
import 'plugins/map_provider.dart';
import 'plugins/payment_checkout_plugin.dart';
import 'plugins/speech_voice_plugin.dart';
import 'plugins/voice_provider.dart';
import 'app_plugin.dart';
import 'provider_registry.dart';

/// Registers the real checkout, map, and speech factories. Factories are not
/// invoked until [ProviderRegistry.resolve].
void registerDefaultPlugins(
  ProviderRegistry registry, {
  CheckoutService Function()? checkoutFactory,
  SpeechToText Function()? speechFactory,
  MapProvider Function()? mapFactory,
  VoiceProvider Function()? voiceFactory,
  AppPlugin Function()? aiFactory,
}) {
  registry.register(
    PluginKind.payment,
    () => PaymentCheckoutPlugin(checkoutFactory ?? createCheckoutService),
  );
  registry.register(PluginKind.map, mapFactory ?? FlutterMapPlugin.new);
  registry.register(
    PluginKind.voice,
    voiceFactory ?? () => SpeechVoicePlugin(create: speechFactory),
  );
  if (aiFactory != null) {
    registry.register(PluginKind.ai, aiFactory);
  }
}
