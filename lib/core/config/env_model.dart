/// Immutable, non-secret runtime configuration for the active environment.
class EnvModel {
  const EnvModel({
    required this.name,
    required this.supabaseUrl,
    required this.supabaseAnonKey,
    required this.razorpayKeyId,
    required this.apiBaseUrl,
  });

  final String name;
  final String supabaseUrl;
  final String supabaseAnonKey;
  final String razorpayKeyId;
  final String apiBaseUrl;

  Map<String, dynamic> toSummaryMap() => {
        'name': name,
        'supabaseHost': Uri.tryParse(supabaseUrl)?.host ?? '',
        'supabaseUrlConfigured': supabaseUrl.isNotEmpty,
        'supabaseAnonKeyConfigured': supabaseAnonKey.isNotEmpty,
        'razorpayKeyConfigured': razorpayKeyId.isNotEmpty,
        'apiBaseUrlHost': Uri.tryParse(apiBaseUrl)?.host ?? '',
      };
}
