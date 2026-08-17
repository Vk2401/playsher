import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/theme.dart';
import '../providers/auth_provider.dart';

class PhoneScreen extends ConsumerStatefulWidget {
  const PhoneScreen({super.key});

  @override
  ConsumerState<PhoneScreen> createState() => _PhoneScreenState();
}

class _PhoneScreenState extends ConsumerState<PhoneScreen> {
  final _ctrl = TextEditingController();
  final _form = GlobalKey<FormState>();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _sendOtp() async {
    if (!_form.currentState!.validate()) return;
    final mobile = '+91${_ctrl.text.trim()}';
    print("Request BUilt");

    // Navigate to OTP screen immediately — sendOtp fires in the background
    context.push('/otp', extra: mobile);
    print("Sent to OTP Screen");
    ref.read(authProvider.notifier).sendOtp(mobile);
  }

  @override
  Widget build(BuildContext context) {
    final loading = ref.watch(authProvider).isLoading;

    return Scaffold(
      backgroundColor: Colors.white,
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
                  width: 72, height: 72,
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(Icons.sports_soccer, color: AppTheme.primary, size: 38),
                ),
                const SizedBox(height: 32),

                const Text(
                  'Welcome to\nPlaysher',
                  style: TextStyle(
                    fontSize: 30, fontWeight: FontWeight.w800,
                    color: AppTheme.textPrimary, height: 1.25,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Enter your mobile number to receive a\none-time verification code.',
                  style: TextStyle(fontSize: 15, color: AppTheme.textSecond, height: 1.55),
                ),
                const SizedBox(height: 40),

                const Text(
                  'Mobile Number',
                  style: TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),

                TextFormField(
                  controller: _ctrl,
                  keyboardType: TextInputType.phone,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(10),
                  ],
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w500),
                  decoration: InputDecoration(
                    prefixIcon: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      margin: const EdgeInsets.only(right: 8),
                      decoration: const BoxDecoration(
                        border: Border(right: BorderSide(color: Color(0xFFE5E7EB))),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('🇮🇳', style: TextStyle(fontSize: 20)),
                          SizedBox(width: 6),
                          Text(
                            '+91',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    hintText: '9XXXXXXXXX',
                    hintStyle: const TextStyle(letterSpacing: 1),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Mobile number is required';
                    if (v.trim().length != 10) return 'Enter a valid 10-digit number';
                    if (!RegExp(r'^[6-9]\d{9}$').hasMatch(v.trim())) {
                      return 'Enter a valid Indian mobile number';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 10),
                const Text(
                  'Indian numbers starting with 6, 7, 8 or 9',
                  style: TextStyle(fontSize: 12, color: AppTheme.textSecond),
                ),

                const SizedBox(height: 32),

                ElevatedButton(
                  onPressed: loading ? null : _sendOtp,
                  child: loading
                      ? const SizedBox(
                          width: 22, height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                        )
                      : const Text('Send OTP'),
                ),

                const SizedBox(height: 28),
                const Center(
                  child: Text(
                    'By continuing, you agree to our\nTerms of Service & Privacy Policy',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: AppTheme.textSecond, height: 1.5),
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
