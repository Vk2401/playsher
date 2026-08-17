import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pin_code_fields/pin_code_fields.dart';
import '../core/theme.dart';
import '../providers/auth_provider.dart';

class OtpScreen extends ConsumerStatefulWidget {
  final String mobile;
  const OtpScreen({super.key, required this.mobile});

  @override
  ConsumerState<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends ConsumerState<OtpScreen> {
  final _ctrl = TextEditingController();
  int _seconds = 30;
  Timer? _timer;
  bool _resending = false;
  bool _verifying = false;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    _seconds = 30;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_seconds == 0) {
        t.cancel();
      } else {
        if (mounted) setState(() => _seconds--);
      }
    });
  }

  Future<void> _resend() async {
    setState(() => _resending = true);
    await ref.read(authProvider.notifier).sendOtp(widget.mobile);
    if (mounted) {
      _startTimer();
      setState(() => _resending = false);
    }
  }

  Future<void> _verify(String otp) async {
    if (otp.length < 6 || _verifying) return;

    setState(() => _verifying = true);
    try {
      final isExisting = await ref
          .read(authProvider.notifier)
          .verifyOtp(widget.mobile, otp);

      if (!mounted) return;

      if (isExisting) {
        context.go('/location'); // ask location on every new session
      } else {
        context.push('/register', extra: widget.mobile);
      }
    } catch (e) {
      if (mounted) {
        _ctrl.clear();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Invalid OTP. Please try again.'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _verifying = false);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _timer?.cancel();
    super.dispose();
  }

  String get _maskedMobile {
    final m = widget.mobile;
    if (m.length > 6) {
      return '${m.substring(0, m.length - 6)}XXXXXX';
    }
    return m;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),

              const Text(
                'Verify OTP',
                style: TextStyle(
                  fontSize: 28, fontWeight: FontWeight.w800, color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 10),
              RichText(
                text: TextSpan(
                  style: const TextStyle(fontSize: 14, color: AppTheme.textSecond, height: 1.55),
                  children: [
                    const TextSpan(text: 'We sent a 6-digit code to '),
                    TextSpan(
                      text: _maskedMobile,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700, color: AppTheme.textPrimary,
                      ),
                    ),
                    const TextSpan(text: '.\nEnter it below to continue.'),
                  ],
                ),
              ),

              const SizedBox(height: 40),

              // PIN field
              PinCodeTextField(
                appContext: context,
                length: 6,
                controller: _ctrl,
                keyboardType: TextInputType.number,
                animationType: AnimationType.scale,
                enabled: !_verifying,
                autoFocus: true,
                pinTheme: PinTheme(
                  shape: PinCodeFieldShape.box,
                  borderRadius: BorderRadius.circular(12),
                  fieldHeight: 58,
                  fieldWidth: 46,
                  activeColor: AppTheme.primary,
                  selectedColor: AppTheme.primary,
                  inactiveColor: const Color(0xFFE5E7EB),
                  activeFillColor: AppTheme.primary.withOpacity(0.05),
                  selectedFillColor: AppTheme.primary.withOpacity(0.08),
                  inactiveFillColor: Colors.white,
                ),
                enableActiveFill: true,
                onCompleted: _verify,
                onChanged: (_) {},
              ),

              const SizedBox(height: 20),

              // Verifying indicator (inline, not full-screen)
              if (_verifying)
                const Row(
                  children: [
                    SizedBox(
                      width: 18, height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: AppTheme.primary,
                      ),
                    ),
                    SizedBox(width: 10),
                    Text(
                      'Verifying…',
                      style: TextStyle(fontSize: 13, color: AppTheme.textSecond),
                    ),
                  ],
                ),

              const Spacer(),

              // Resend
              Center(
                child: _seconds > 0
                    ? RichText(
                        text: TextSpan(
                          style: const TextStyle(fontSize: 13, color: AppTheme.textSecond),
                          children: [
                            const TextSpan(text: 'Resend OTP in '),
                            TextSpan(
                              text: '${_seconds}s',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700, color: AppTheme.primary,
                              ),
                            ),
                          ],
                        ),
                      )
                    : _resending
                        ? const SizedBox(
                            width: 20, height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primary),
                          )
                        : TextButton(
                            onPressed: _resend,
                            child: const Text('Resend OTP'),
                          ),
              ),

              const SizedBox(height: 36),
            ],
          ),
        ),
      ),
    );
  }
}
