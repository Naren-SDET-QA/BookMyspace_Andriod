/// Common form-field validators. A null return value means the input is valid.
abstract final class AppValidators {
  static String? required(
    String? value, {
    String? fieldName,
    int minLength = 1,
    int? maxLength,
  }) {
    final text = value?.trim() ?? '';
    if (fieldName == null) {
      if (text.isEmpty) return 'This field is required';
      if (text.length < minLength) {
        return 'Must be at least $minLength characters';
      }
      if (maxLength != null && text.length > maxLength) {
        return 'Must be at most $maxLength characters';
      }
      return null;
    }
    if (text.isEmpty) return '$fieldName is required';
    if (text.length < minLength) {
      return '$fieldName must be at least $minLength characters';
    }
    if (maxLength != null && text.length > maxLength) {
      return '$fieldName must be at most $maxLength characters';
    }
    return null;
  }

  static String? email(String? value) {
    final requiredError = required(value);
    if (requiredError != null) return requiredError;
    final valid = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(value!.trim());
    return valid ? null : 'Enter a valid email address';
  }

  static String? phone(String? value) {
    final requiredError = required(value);
    if (requiredError != null) return requiredError;
    final valid = RegExp(r'^\+?[0-9]{10,13}$').hasMatch(value!.trim());
    return valid ? null : 'Enter a valid phone number';
  }

  static String? name(String? value) {
    final requiredError = required(value, minLength: 2);
    if (requiredError != null) return requiredError;
    final valid =
        RegExp(r"^[A-Za-z][A-Za-z' -]*[A-Za-z]$").hasMatch(value!.trim());
    return valid ? null : 'Enter a valid name';
  }

  static String? otp(String? value) {
    final text = value?.trim() ?? '';
    final valid = RegExp(r'^\d{4,6}$').hasMatch(text);
    return valid ? null : 'Enter a valid OTP';
  }

  static String? password(String? value) {
    if (value == null || value.isEmpty) {
      return 'Password is required';
    }
    if (value.length < 8) {
      return 'Password must be at least 8 characters';
    }
    if (!RegExp(r'[a-zA-Z]').hasMatch(value)) {
      return 'Password must contain at least one letter';
    }
    if (!RegExp(r'[0-9]').hasMatch(value)) {
      return 'Password must contain at least one number';
    }
    return null;
  }

  /// Ensures [confirmation] matches a valid [password].
  static String? confirmPassword(String? password, String? confirmation) {
    final error = AppValidators.password(password);
    if (error != null) return error;
    if (confirmation == null || confirmation != password) {
      return 'Passwords do not match';
    }
    return null;
  }

  /// Validates a description with optional min/max length.
  static String? description(String? value, {int minLength = 10, int maxLength = 1000}) {
    if (value == null || value.trim().isEmpty) {
      return 'Description is required';
    }
    if (value.trim().length < minLength) {
      return 'Description must be at least $minLength characters';
    }
    if (value.trim().length > maxLength) {
      return 'Description must be at most $maxLength characters';
    }
    return null;
  }

  /// Validates a subject/title with optional min/max length.
  static String? subject(String? value, {int minLength = 3, int maxLength = 100}) {
    if (value == null || value.trim().isEmpty) {
      return 'Subject is required';
    }
    if (value.trim().length < minLength) {
      return 'Subject must be at least $minLength characters';
    }
    if (value.trim().length > maxLength) {
      return 'Subject must be at most $maxLength characters';
    }
    return null;
  }
}
