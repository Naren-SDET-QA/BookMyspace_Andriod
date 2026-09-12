import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/errors/app_exceptions.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/validators/app_validators.dart';
import '../../../../core/widgets/bookmyspace_brand.dart';
import '../../domain/phone_otp_provider.dart';
import '../auth_providers.dart';

/// Email/phone OTP sign-in screen.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _identifierController = TextEditingController();
  final _otpController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _phoneMode = false;
  bool _codeSent = false;
  bool _loading = false;
  bool _oauthBusy = false;
  String? _oauthProvider;
  bool _developmentOnlyVerified = false;
  String? _error;
  bool _errorIsCancellation = false;

  bool get _busy => _loading || _oauthBusy;

  @override
  void initState() {
    super.initState();
    _passwordController.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _identifierController.dispose();
    _otpController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _socialSignIn(String provider) async {
    if (_busy) return;
    setState(() {
      _oauthBusy = true;
      _oauthProvider = provider;
      _error = null;
      _errorIsCancellation = false;
    });
    try {
      final repository = ref.read(authRepositoryProvider);
      if (provider == 'google') {
        await repository.signInWithGoogle();
      } else {
        await repository.signInWithApple();
      }
      if (!mounted) return;
      setState(() {
        _oauthBusy = false;
        _oauthProvider = null;
      });
      GoRouter.maybeOf(context)?.go(AppRoutes.shell);
    } catch (error) {
      if (!mounted) return;
      final cancelled = error is AuthCancelledException;
      setState(() {
        _oauthBusy = false;
        _oauthProvider = null;
        _errorIsCancellation = cancelled;
        _error = _userFacingError(error);
      });
    }
  }

  Future<void> _signInWithPassword() async {
    if (_busy) return;
    final email = _identifierController.text.trim();
    final password = _passwordController.text;
    final validationError = AppValidators.email(email);
    if (validationError != null) {
      setState(() => _error = validationError);
      return;
    }
    if (password.isEmpty) {
      setState(() => _error = 'Enter your password.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
      _errorIsCancellation = false;
    });
    try {
      await ref.read(authNotifierProvider.notifier).signInWithEmailPassword(
            email: email,
            password: password,
          );
      if (!mounted) return;
      setState(() => _loading = false);
      GoRouter.maybeOf(context)?.go(AppRoutes.shell);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = _userFacingError(error);
      });
    }
  }

  Future<void> _sendCode() async {
    if (_busy) return;
    final identifier = _identifierController.text.trim();
    final validationError = _phoneMode
        ? AppValidators.phone(identifier)
        : AppValidators.email(identifier);
    if (validationError != null) {
      setState(() => _error = validationError);
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
      _errorIsCancellation = false;
    });
    try {
      final repository = ref.read(authRepositoryProvider);
      if (_phoneMode) {
        await ref.read(phoneOtpProvider).sendOtp(identifier);
      } else {
        await repository.signInWithEmailOtp(identifier);
      }
      if (mounted) {
        setState(() {
          _codeSent = true;
          _loading = false;
          _developmentOnlyVerified = false;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = _userFacingError(error);
        });
      }
    }
  }

  Future<void> _verifyCode() async {
    if (_busy || _developmentOnlyVerified) return;
    final code = _otpController.text.trim();
    if (_phoneMode && !RegExp(r'^\d{6}$').hasMatch(code)) {
      setState(() => _error = 'Enter a 6-digit OTP');
      return;
    }
    if (!_phoneMode && code.isEmpty) {
      setState(() => _error = 'Enter the verification code');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
      _errorIsCancellation = false;
    });
    try {
      final repository = ref.read(authRepositoryProvider);
      PhoneOtpVerificationResult? phoneResult;
      if (_phoneMode) {
        phoneResult = await ref.read(phoneOtpProvider).verifyOtp(
              _identifierController.text.trim(),
              code,
            );
      } else {
        await repository.verifyEmailOtp(
            _identifierController.text.trim(), code);
      }
      if (!mounted) return;
      if (phoneResult != null && !phoneResult.sessionCreated) {
        setState(() {
          _loading = false;
          _developmentOnlyVerified = true;
          _error = null;
        });
        return;
      }
      setState(() => _loading = false);
      GoRouter.maybeOf(context)?.go(AppRoutes.shell);
    } catch (error) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = _userFacingError(error);
        });
      }
    }
  }

  String _userFacingError(Object error) {
    if (error is AppException) return error.message;
    if (error is StateError) return error.message.toString();
    final mapped = mapError(error);
    if (mapped is NetworkException || mapped is TimeoutException) {
      return mapped.message;
    }
    final text = error.toString();
    if (text.contains('Error sending confirmation email') ||
        text.contains('unexpected_failure')) {
      return 'Could not send a verification email. Sign in with your password, or try again later.';
    }
    if (text.contains('Invalid login credentials')) {
      return 'Email or password is incorrect.';
    }
    return mapped.message;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final viewInsets = MediaQuery.viewInsetsOf(context);
    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final minContentHeight =
                (constraints.maxHeight - viewInsets.bottom - 48)
                    .clamp(0.0, double.infinity);
            return SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: EdgeInsets.fromLTRB(
                24,
                24,
                24,
                24 + viewInsets.bottom,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: 420,
                  minHeight: minContentHeight,
                ),
                child: Form(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Center(child: BookMySpaceMark(size: 88)),
                      const SizedBox(height: 16),
                      const BookMySpaceWordmark(
                        fontSize: 32,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        _codeSent
                            ? _phoneMode
                                ? 'Enter the verification code for ${_maskedPhone(_identifierController.text)}.'
                                : 'Enter the verification code we sent you.'
                            : 'Sign in to continue booking spaces.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyLarge,
                      ),
                      const SizedBox(height: 28),
                      FilledButton.tonalIcon(
                        key: const Key('google-sign-in'),
                        onPressed: _busy ? null : () => _socialSignIn('google'),
                        icon: _oauthProvider == 'google'
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.g_mobiledata_rounded),
                        label: Text(
                          _oauthProvider == 'google'
                              ? 'Connecting to Google...'
                              : 'Continue with Google',
                        ),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        key: const Key('apple-sign-in'),
                        onPressed: _busy ? null : () => _socialSignIn('apple'),
                        icon: _oauthProvider == 'apple'
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.apple_rounded),
                        label: Text(
                          _oauthProvider == 'apple'
                              ? 'Connecting to Apple...'
                              : 'Continue with Apple',
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: theme.colorScheme.onSurface,
                          side: BorderSide(
                              color: AppTheme.brand.withValues(alpha: 0.4)),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          const Expanded(child: Divider()),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Text(
                              'OR',
                              style: theme.textTheme.labelLarge?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                          const Expanded(child: Divider()),
                        ],
                      ),
                      const SizedBox(height: 20),
                      SegmentedButton<bool>(
                        segments: const [
                          ButtonSegment<bool>(
                              value: false, label: Text('Email')),
                          ButtonSegment<bool>(
                              value: true, label: Text('Phone')),
                        ],
                        selected: {_phoneMode},
                        onSelectionChanged: _busy
                            ? null
                            : (selection) {
                                setState(() {
                                  _phoneMode = selection.first;
                                  _codeSent = false;
                                  _error = null;
                                  _errorIsCancellation = false;
                                  _otpController.clear();
                                });
                              },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _identifierController,
                        enabled: !_busy,
                        keyboardType: _phoneMode
                            ? TextInputType.phone
                            : TextInputType.emailAddress,
                        textInputAction: _codeSent
                            ? TextInputAction.next
                            : TextInputAction.next,
                        onFieldSubmitted: (_) {
                          if (!_phoneMode &&
                              _passwordController.text.isNotEmpty) {
                            _signInWithPassword();
                            return;
                          }
                          if (!_codeSent) _sendCode();
                        },
                        scrollPadding: const EdgeInsets.only(bottom: 120),
                        decoration: InputDecoration(
                          labelText: _phoneMode ? 'Phone number' : 'Email',
                          prefixIcon: Icon(
                            _phoneMode
                                ? Icons.phone_outlined
                                : Icons.alternate_email_rounded,
                          ),
                        ),
                      ),
                      if (!_phoneMode && !_codeSent) ...[
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _passwordController,
                          enabled: !_busy,
                          obscureText: true,
                          textInputAction: TextInputAction.done,
                          onFieldSubmitted: (_) {
                            if (_passwordController.text.isNotEmpty) {
                              _signInWithPassword();
                            } else {
                              _sendCode();
                            }
                          },
                          scrollPadding: const EdgeInsets.only(bottom: 120),
                          decoration: const InputDecoration(
                            labelText: 'Password (optional)',
                            prefixIcon: Icon(Icons.lock_outline_rounded),
                          ),
                        ),
                      ],
                      if (_codeSent) ...[
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _otpController,
                          enabled: !_busy,
                          keyboardType: TextInputType.number,
                          textInputAction: TextInputAction.done,
                          onFieldSubmitted: (_) => _verifyCode(),
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          maxLength: 6,
                          decoration: const InputDecoration(
                            labelText: 'Verification code',
                            prefixIcon: Icon(Icons.lock_outline_rounded),
                            counterText: '',
                          ),
                        ),
                        if (_phoneMode) ...[
                          const SizedBox(height: 8),
                          Consumer(
                            builder: (context, ref, child) {
                              final hint = ref
                                  .watch(phoneOtpProvider)
                                  .developmentOtpHint;
                              if (hint == null) return const SizedBox.shrink();
                              return Text(
                                'Development OTP: $hint',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: theme.colorScheme.secondary,
                                  fontWeight: FontWeight.w600,
                                ),
                              );
                            },
                          ),
                        ],
                      ],
                      if (_developmentOnlyVerified) ...[
                        const SizedBox(height: 12),
                        Text(
                          'Phone OTP verified in development only. No Supabase session was created.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: theme.colorScheme.secondary),
                        ),
                      ],
                      if (_error != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          _error!,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: _errorIsCancellation
                                ? theme.colorScheme.onSurfaceVariant
                                : theme.colorScheme.error,
                          ),
                        ),
                      ],
                      const SizedBox(height: 24),
                      FilledButton(
                        key: const Key('otp-submit'),
                        onPressed: _busy || _developmentOnlyVerified
                            ? null
                            : (_codeSent
                                ? _verifyCode
                                : (!_phoneMode &&
                                        _passwordController.text.isNotEmpty
                                    ? _signInWithPassword
                                    : _sendCode)),
                        child: Text(
                          _loading
                              ? 'Please wait...'
                              : (_codeSent
                                  ? 'Verify & log in'
                                  : (!_phoneMode &&
                                          _passwordController.text.isNotEmpty
                                      ? 'Sign in'
                                      : 'Send code')),
                        ),
                      ),
                      if (!_phoneMode &&
                          !_codeSent &&
                          _passwordController.text.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: _busy ? null : _sendCode,
                          child: const Text('Send a verification code instead'),
                        ),
                      ],
                      if (_codeSent) ...[
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: _busy || _developmentOnlyVerified
                              ? null
                              : _sendCode,
                          child: const Text('Resend code'),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  String _maskedPhone(String phone) {
    final normalized = phone.trim();
    if (normalized.length <= 4) return normalized;
    final hiddenLength = normalized.length - 4;
    return '${normalized.substring(0, 2)}${'*' * hiddenLength}${normalized.substring(normalized.length - 2)}';
  }
}
