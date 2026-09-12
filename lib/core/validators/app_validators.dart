/// Common form-field validators. A null return value means the input is valid.
abstract final class AppValidators {
  static String? required(String? value, {int minLength = 1}) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'This field is required';
    if (text.length < minLength)
      return 'Must be at least $minLength characters';
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
    final text = value ?? '';
    if (text.length < 8) return 'Password must be at least 8 characters';
    if (!RegExp(r'[A-Za-z]').hasMatch(text))
      return 'Password must contain a letter';
    if (!RegExp(r'\d').hasMatch(text)) return 'Password must contain a number';
    return null;
  }
}
