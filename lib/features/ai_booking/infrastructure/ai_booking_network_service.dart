import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

class AiBookingNetworkException implements Exception {
  const AiBookingNetworkException(this.code, this.message);
  final String code;
  final String message;
  @override String toString() => message;
}

/// Thin client for the authenticated AI edge function. It carries no secrets
/// and never creates bookings locally; booking creation still requires the
/// explicit confirmation flag and server-side booking RPC.
class AiBookingNetworkService {
  const AiBookingNetworkService(this._client);
  final SupabaseClient _client;

  Future<Map<String, dynamic>> send(String message) async {
    final value = message.trim();
    if (value.isEmpty || value.length > 1000) {
      throw const AiBookingNetworkException('invalid_message', 'Enter a valid request.');
    }
    try {
      final response = await _client.functions
          .invoke('ai-booking-assistant', body: {'message': value})
          .timeout(const Duration(seconds: 20));
      final data = response.data;
      if (data is! Map<String, dynamic>) {
        throw const AiBookingNetworkException('invalid_response', 'Assistant response was invalid.');
      }
      if (data['error'] is String) {
        throw AiBookingNetworkException(data['error'] as String, data['fallback'] as String? ?? 'Assistant is unavailable.');
      }
      return data;
    } on FunctionException {
      throw AiBookingNetworkException('assistant_unavailable', 'Assistant is unavailable. Please use search and booking directly.');
    } on TimeoutException {
      throw const AiBookingNetworkException('assistant_timeout', 'Assistant took too long to respond. Please use search and booking directly.');
    }
  }
}
