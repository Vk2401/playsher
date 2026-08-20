import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pin_code_fields/pin_code_fields.dart';
import '../core/api_error.dart';
import '../core/app_colors.dart';
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
    if (_resending || _verifying) return;
    setState(() => _resending = true);
    await ref.read(authProvider.notifier).sendOtp(widget.mobile);
    if (!mounted) return;
    _startTimer();
    setState(() => _resending = false);
  }

  Future<void> _verify(String otp) async {
    if (otp.length < 6 || _verifying) return;

    setState(() => _verifying = true);
    try {
      final isExisting =
          await ref.read(authProvider.notifier).verifyOtp(widget.mobile, otp);

      if (!mounted) return;
      // Do not clear _verifying — this screen is being replaced and the
      // overlay must stay up until the next route is on screen.
      if (isExisting) {
        context.go('/location');
      } else {
        context.pushReplacement('/register', extra: widget.mobile);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _verifying = false);
      _ctrl.clear();
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(apiErrorMessage(e,
                fallback: 'That code was not correct. Please try again.')),
            backgroundColor: AppColors.error,
          ),
        );
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _timer?.cancel();
    super.dispose();
  }

  /// Width for one of the six boxes, derived from the viewport so the row
  /// never overflows on a narrow phone.
  static double _pinBoxWidth(BuildContext context) {
    const horizontalPadding = 28.0 * 2;
    const gaps = 8.0 * 5;
    final available =
        MediaQuery.sizeOf(context).width - horizontalPadding - gaps;
    return (available / 6).clamp(40.0, 54.0);
  }

  String get _maskedMobile {
    final m = widget.mobile;
    if (m.length > 6) return '${m.substring(0, m.length - 6)}XXXXXX';
    return m;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          tooltip: 'Back',
          onPressed: _verifying ? null : () => context.pop(),
        ),
      ),
      // The keyboard is open on this screen; the body must scroll so the PIN
      // field is never pushed under the fold.
      body: Stack(
        children: [
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 16),
                      Text(
                        'Verify OTP',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          color: colors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 10),
                      RichText(
                        text: TextSpan(
                          style: TextStyle(
                              fontSize: 14,
                              color: colors.textSecondary,
                              height: 1.55),
                          children: [
                            const TextSpan(text: 'We sent a 6-digit code to '),
                            TextSpan(
                              text: _maskedMobile,
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: colors.textPrimary,
                              ),
                            ),
                            const TextSpan(
                                text: '.\nEnter it below to continue.'),
                          ],
                        ),
                      ),
                      const SizedBox(height: 40),
                      // pin_code_fields keeps a hidden TextField behind the
                      // boxes and never sets `filled: false` on it, so it
                      // inherits the app's `filled: true` and paints a grey
                      // slab across the row. Clearing the inherited decoration
                      // for this subtree is what removes it.
                      Theme(
                        data: Theme.of(context).copyWith(
                          inputDecorationTheme: const InputDecorationTheme(
                            filled: false,
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                        child: PinCodeTextField(
                          appContext: context,
                          length: 6,
                          controller: _ctrl,
                          keyboardType: TextInputType.number,
                          animationType: AnimationType.fade,
                          animationDuration: const Duration(milliseconds: 120),
                          enabled: !_verifying,
                          autoFocus: true,
                          autoDismissKeyboard: false,
                          enablePinAutofill: true,
                          hapticFeedbackTypes: HapticFeedbackTypes.light,
                          useHapticFeedback: true,
                          cursorColor: AppColors.primary,
                          textStyle: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: colors.textPrimary,
                          ),
                          pinTheme: PinTheme(
                            shape: PinCodeFieldShape.box,
                            borderRadius: BorderRadius.circular(14),
                            // Sized from the viewport so six boxes always fit,
                            // including on a 360dp phone at large text scale.
                            fieldHeight: 56,
                            fieldWidth: _pinBoxWidth(context),
                            borderWidth: 1.5,
                            activeColor: AppColors.primary,
                            selectedColor: AppColors.primary,
                            inactiveColor: colors.border,
                            disabledColor: colors.border,
                            activeFillColor: colors.input,
                            selectedFillColor:
                                AppColors.primary.withValues(alpha: 0.10),
                            inactiveFillColor: colors.input,
                          ),
                          enableActiveFill: true,
                          onCompleted: _verify,
                          onChanged: (_) {},
                        ),
                      ),

                      const SizedBox(height: 24),
                      Center(
                        child: _seconds > 0
                            ? RichText(
                                text: TextSpan(
                                  style: TextStyle(
                                      fontSize: 13,
                                      color: colors.textSecondary),
                                  children: [
                                    const TextSpan(text: 'Resend OTP in '),
                                    TextSpan(
                                      text: '${_seconds}s',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : _resending
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: AppColors.primary),
                                  )
                                : TextButton(
                                    onPressed: _verifying ? null : _resend,
                                    child: const Text('Resend OTP'),
                                  ),
                      ),
                      const SizedBox(height: 36),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Verify auto-fires on the last digit, with the keyboard covering
          // most of the screen — the wait has to be visible where the user is
          // actually looking, so it is a full-screen overlay, not a spinner
          // tucked into a button.
          if (_verifying)
            Positioned.fill(
              child: ColoredBox(
                color: colors.background.withValues(alpha: 0.86),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(
                        width: 40,
                        height: 40,
                        child: CircularProgressIndicator(
                            strokeWidth: 3, color: AppColors.primary),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        'Verifying your code…',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: colors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
