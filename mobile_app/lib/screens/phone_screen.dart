import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/app_colors.dart';
import '../core/constants.dart';
import '../providers/auth_provider.dart';

class PhoneScreen extends ConsumerStatefulWidget {
  const PhoneScreen({super.key});

  @override
  ConsumerState<PhoneScreen> createState() => _PhoneScreenState();
}

class _PhoneScreenState extends ConsumerState<PhoneScreen> {
  final _ctrl = TextEditingController();
  final _form = GlobalKey<FormState>();
  bool _submitting = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _sendOtp() async {
    if (_submitting) return;
    if (!_form.currentState!.validate()) return;

    setState(() => _submitting = true);
    final mobile = '+91${_ctrl.text.trim()}';

    // Fire the request, then move on — the OTP screen owns the retry/resend.
    ref.read(authProvider.notifier).sendOtp(mobile);

    if (!mounted) return;
    setState(() => _submitting = false);
    context.push('/otp', extra: mobile);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final busy = _submitting || ref.watch(authProvider).isLoading;

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Form(
            key: _form,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 56),

                // Logo
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(Icons.sports_soccer,
                      color: AppColors.primary, size: 38),
                ),
                const SizedBox(height: 32),

                Text(
                  'Welcome to\n${AppConstants.appName}',
                  style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                    color: colors.textPrimary,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Enter your mobile number to receive a\none-time verification code.',
                  style: TextStyle(
                      fontSize: 15, color: colors.textSecondary, height: 1.55),
                ),
                const SizedBox(height: 40),

                Text(
                  'Mobile Number',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: colors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),

                TextFormField(
                  controller: _ctrl,
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.done,
                  enabled: !busy,
                  onFieldSubmitted: (_) => _sendOtp(),
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(10),
                  ],
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w500,
                    color: colors.textPrimary,
                  ),
                  decoration: InputDecoration(
                    prefixIcon: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        border: Border(right: BorderSide(color: colors.border)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('\u{1F1EE}\u{1F1F3}',
                              style: TextStyle(fontSize: 20)),
                          const SizedBox(width: 6),
                          Text(
                            '+91',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: colors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    prefixIconConstraints:
                        const BoxConstraints(minHeight: 44, minWidth: 44),
                    hintText: '9XXXXXXXXX',
                    hintStyle: const TextStyle(letterSpacing: 1),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'Mobile number is required';
                    }
                    if (v.trim().length != 10) {
                      return 'Enter a valid 10-digit number';
                    }
                    if (!RegExp(r'^[6-9]\d{9}$').hasMatch(v.trim())) {
                      return 'Enter a valid Indian mobile number';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 10),
                Text(
                  'Indian numbers starting with 6, 7, 8 or 9',
                  style: TextStyle(fontSize: 12, color: colors.textSecondary),
                ),

                const SizedBox(height: 32),

                ElevatedButton(
                  onPressed: busy ? null : _sendOtp,
                  child: busy
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                              strokeWidth: 2.5, color: AppColors.onPrimary),
                        )
                      : const Text('Send OTP'),
                ),

                const SizedBox(height: 28),
                Center(
                  child: Text(
                    'By continuing, you agree to our\nTerms of Service & Privacy Policy',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 12, color: colors.textSecondary, height: 1.5),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
