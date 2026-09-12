import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_exceptions.dart' as app_errors;
import '../domain/pin_code_location.dart';

class IndiaPostPinCodeRepository implements PinCodeRepository {
  IndiaPostPinCodeRepository({
    required SupabaseClient client,
    http.Client? httpClient,
    this.publicLookupUriBuilder,
  })  : _client = client,
        _http = httpClient ?? http.Client();

  final SupabaseClient _client;
  final http.Client _http;
  final Uri Function(String pincode)? publicLookupUriBuilder;

  static final Map<String, PinLookupResult> _cache = {};

  @override
  Future<PinLookupResult> lookup(String pincode) async {
    final validationError = validateIndianPin(pincode);
    if (validationError != null) {
      return PinLookupResult(
        status: PinLookupStatus.invalid,
        pincode: pincode.trim(),
        message: validationError,
      );
    }
    final pin = pincode.trim();
    final cached = _cache[pin];
    if (cached != null && cached.isSuccess) return cached;

    try {
      final viaFunction = await _lookupViaEdgeFunction(pin);
      if (viaFunction.status != PinLookupStatus.error) {
        if (viaFunction.isSuccess) _cache[pin] = viaFunction;
        return viaFunction;
      }
      final fallback = await _lookupViaPublicApi(pin);
      if (fallback.isSuccess) _cache[pin] = fallback;
      return fallback;
    } catch (error) {
      final mapped = app_errors.mapError(error);
      return PinLookupResult(
        status: PinLookupStatus.error,
        pincode: pin,
        message: mapped.message,
      );
    }
  }

  Future<PinLookupResult> _lookupViaEdgeFunction(String pin) async {
    try {
      final response = await _client.functions.invoke(
        'lookup-pincode',
        body: {'pincode': pin},
      ).timeout(const Duration(seconds: 10));
      final data = response.data;
      if (data is! Map) {
        return PinLookupResult(
          status: PinLookupStatus.error,
          pincode: pin,
          message: 'PIN lookup returned an unexpected response.',
        );
      }
      return parseLookupPayload(Map<String, dynamic>.from(data), pin);
    } on TimeoutException {
      return PinLookupResult(
        status: PinLookupStatus.error,
        pincode: pin,
        message: 'PIN lookup timed out. Try again.',
      );
    } on FunctionException catch (error) {
      if (error.status == 401) {
        return const PinLookupResult(
          status: PinLookupStatus.error,
          message: 'Sign in to look up a PIN code.',
        );
      }
      return PinLookupResult(
        status: PinLookupStatus.error,
        pincode: pin,
        message: 'PIN lookup service is unavailable.',
      );
    }
  }

  Future<PinLookupResult> _lookupViaPublicApi(String pin) async {
    final uri = publicLookupUriBuilder?.call(pin) ??
        Uri.parse('https://api.postalpincode.in/pincode/$pin');
    final response = await _http.get(uri, headers: {
      'Accept': 'application/json',
    }).timeout(const Duration(seconds: 15));
    if (response.statusCode >= 500) {
      return PinLookupResult(
        status: PinLookupStatus.error,
        pincode: pin,
        message: 'PIN code service is unavailable. Retry in a moment.',
      );
    }
    if (response.statusCode >= 400) {
      return PinLookupResult(
        status: PinLookupStatus.error,
        pincode: pin,
        message: 'PIN lookup failed (${response.statusCode}).',
      );
    }
    final decoded = jsonDecode(response.body);
    return parseIndiaPostBody(decoded, pin);
  }

  static PinLookupResult parseLookupPayload(
    Map<String, dynamic> data,
    String pin,
  ) {
    final status = data['status'] as String? ?? '';
    final officesRaw = data['offices'];
    final offices = officesRaw is List
        ? officesRaw
            .whereType<Map>()
            .map((row) => PinCodeOffice.fromJson(Map<String, dynamic>.from(row)))
            .where((office) => office.name.isNotEmpty || office.pincode.isNotEmpty)
            .toList()
        : const <PinCodeOffice>[];
    if (status == 'empty' || offices.isEmpty) {
      return PinLookupResult(
        status: PinLookupStatus.empty,
        pincode: pin,
        message: 'No postal records found for this PIN.',
      );
    }
    return PinLookupResult(
      status: PinLookupStatus.success,
      pincode: pin,
      offices: offices,
    );
  }

  static PinLookupResult parseIndiaPostBody(Object? decoded, String pin) {
    if (decoded is! List || decoded.isEmpty || decoded.first is! Map) {
      return PinLookupResult(
        status: PinLookupStatus.error,
        pincode: pin,
        message: 'PIN lookup returned an unexpected response.',
      );
    }
    final row = Map<String, dynamic>.from(decoded.first as Map);
    final officesRaw = row['PostOffice'];
    if (row['Status'] != 'Success' || officesRaw is! List || officesRaw.isEmpty) {
      return PinLookupResult(
        status: PinLookupStatus.empty,
        pincode: pin,
        message: 'No postal records found for this PIN.',
      );
    }
    final offices = officesRaw
        .whereType<Map>()
        .map((item) => PinCodeOffice.fromJson(Map<String, dynamic>.from(item)))
        .where((office) => office.name.isNotEmpty)
        .toList();
    if (offices.isEmpty) {
      return PinLookupResult(
        status: PinLookupStatus.empty,
        pincode: pin,
        message: 'No postal records found for this PIN.',
      );
    }
    return PinLookupResult(
      status: PinLookupStatus.success,
      pincode: pin,
      offices: offices,
    );
  }
}
