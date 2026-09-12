import 'package:flutter/foundation.dart';

/// Base class for all application exceptions.
abstract class AppException implements Exception {
  const AppException(this.message, {this.code, this.statusCode});

  final String message;
  final String? code;
  final int? statusCode;

  @override
  String toString() => '[$code] $message';
}

/// A generic, catch-all application error with no further semantics.
class AppError extends AppException {
  const AppError(super.message, {super.code});
}

/// Network / connectivity failures.
class NetworkException extends AppException {
  const NetworkException(super.message, {super.code});
}

/// Timeout failures.
class TimeoutException extends AppException {
  const TimeoutException(super.message, {super.code});
}

/// Server returned an error status (4xx/5xx).
class ServerException extends AppException {
  const ServerException(super.message, {super.code, super.statusCode});
}

/// Invalid / missing data mapping.
class SerializationException extends AppException {
  const SerializationException(super.message, {super.code});
}

/// Unauthorised or expired session.
class AuthException extends AppException {
  const AuthException(super.message, {super.code, super.statusCode});
}

/// The user dismissed an OAuth prompt without completing sign-in.
class AuthCancelledException extends AppException {
  const AuthCancelledException(super.message, {super.code = 'cancelled'});
}

/// Business rule violation (e.g. venue already booked).
class BusinessException extends AppException {
  const BusinessException(super.message, {super.code, super.statusCode});
}

class ValidationException extends AppException {
  const ValidationException(super.message, {super.code, super.statusCode});
}

/// A requested resource was not found.
class NotFoundException extends AppException {
  const NotFoundException(super.message, {super.code, super.statusCode});
}

/// The requested slot is already held or booked by someone else.
class BookingConflictException extends AppException {
  const BookingConflictException(super.message, {super.code, super.statusCode});
}

/// A booking hold expired before it could be confirmed.
class HoldExpiredException extends AppException {
  const HoldExpiredException(super.message, {super.code});
}

/// Thrown when a configuration value is missing or is still a placeholder.
class ConfigurationException extends AppException {
  const ConfigurationException(super.message, {super.code});
}

/// Convert a raw error into a typed [AppException] for presentation.
AppException mapError(Object error) {
  if (error is AppException) return error;
  if (error is ArgumentError) {
    return const BusinessException('Invalid argument passed to repository.');
  }
  final text = error.toString().toLowerCase();
  if (text.contains('socketexception') ||
      text.contains('failed host lookup') ||
      text.contains('connection refused') ||
      text.contains('network is unreachable') ||
      text.contains('clientexception') ||
      text.contains('connection reset') ||
      text.contains('nodename nor servname')) {
    return const NetworkException(
      'Unable to reach BookMySpace right now. Check your connection and try again.',
      code: 'network',
    );
  }
  if (text.contains('timeout') || text.contains('timed out')) {
    return const TimeoutException(
      'The request took too long. Please try again.',
      code: 'timeout',
    );
  }
  if (kDebugMode) {
    final compact = error.toString();
    if (compact.length > 160) {
      return const AppError(
        'Something went wrong. Please try again.',
        code: 'unknown',
      );
    }
    return AppError('Unexpected error: $compact', code: 'unknown');
  }
  return const AppError('Something went wrong. Please try again.');
}
