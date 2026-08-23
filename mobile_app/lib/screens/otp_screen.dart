import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pin_code_fields/pin_code_fields.dart';
import '../core/api_error.dart';
import '../core/app_colors.dart';
import '../providers/auth_provider.dart';
import '../widgets/kit_scatter.dart';
import '../widgets/security_shield.dart';

/// The six digits between a mobile number and an account.
///
/// One card carries the whole task — the crest, the boxes, the countdown and
/// the CTA — on a page whose feet are filled by the kit, matching the login
/// screen it is pushed from.
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

  /// What is in the boxes, so the CTA can stay disabled until six digits are.
  String _code = '';

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
      setState(() {
        _verifying = false;
        _code = '';
      });
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
    // The page's own gutter, the card's padding, and the five gaps between six
    // boxes — everything the row does not get to use.
    const outside = 20.0 * 2 + 20.0 * 2;
    const gaps = 10.0 * 5;
    final available = MediaQuery.sizeOf(context).width - outside - gaps;
    return (available / 6).clamp(40.0, 54.0);
  }

  /// The number, with the last six digits withheld: it is printed back to the
  /// user as confirmation of where the code went, not as a record of it.
  String get _maskedMobile {
    final m = widget.mobile;
    final masked = m.length > 6 ? '${m.substring(0, m.length - 6)}XXXXXX' : m;
    return masked.startsWith('+91') ? '+91 ${masked.substring(3)}' : masked;
  }

  @override
  Widget build(BuildContext context) {
    final frame = context.frame;
    final size = MediaQuery.of(context).size;

    // The kit is parented above the Scaffold, never inside its body: the
    // keyboard is open for the whole of this screen, and a body Stack clips
    // its decoration along the keyboard's edge.
    return Stack(
      children: [
        Positioned.fill(child: ColoredBox(color: frame.page)),
        Positioned.fill(
          child: KitScatter(size: size, layout: KitLayout.otp),
        ),
        Scaffold(
          backgroundColor: Colors.transparent,
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _BackButton(enabled: !_verifying),
                  const SizedBox(height: 8),
                  _VerifyCard(
                    masked: _maskedMobile,
                    controller: _ctrl,
                    boxWidth: _pinBoxWidth(context),
                    seconds: _seconds,
                    resending: _resending,
                    verifying: _verifying,
                    complete: _code.length == 6,
                    onChanged: (v) => setState(() => _code = v),
                    onCompleted: _verify,
                    onResend: _resend,
                    onVerify: () => _verify(_code),
                  ),
                  const SizedBox(height: 26),
                  const _SecurityNote(),
                  // Room at the foot for the ball and the bat to sit in.
                  SizedBox(height: size.width * 0.30),
                ],
              ),
            ),
          ),
        ),

        // Verify auto-fires on the last digit, with the keyboard covering
        // most of the screen — the wait has to be visible where the user is
        // actually looking, so it is a full-screen overlay, not a spinner
        // tucked into a button.
        if (_verifying) const _VerifyingOverlay(),
      ],
    );
  }
}

/// The wait between the sixth digit and the next screen.
///
/// A card on a dimmed page, not a wash over it: the previous version tinted
/// the whole screen with the page colour at 86%, which on a light theme left
/// the form perfectly legible and merely faded — it read as the screen having
/// broken rather than as work in progress.
///
/// It also carries its own [Material]. The overlay sits above the `Scaffold`
/// so the keyboard cannot resize it, and that puts it outside the Material the
/// `Scaffold` provides — text with no Material ancestor renders in Flutter's
/// debug face, yellow underline and all, which is exactly what it did.
class _VerifyingOverlay extends StatelessWidget {
  const _VerifyingOverlay();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final frame = context.frame;

    return Positioned.fill(
      child: Material(
        // A scrim over an arbitrary page is the one place a literal black is
        // right: it has to darken both themes by the same amount. The filled
        // Material also swallows every tap, which is what makes the wait
        // non-cancelable.
        color: Colors.black.withValues(alpha: 0.45),
        child: Semantics(
          liveRegion: true,
          label: 'Verifying your code',
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 28),
              decoration: BoxDecoration(
                color: colors.card,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.brandInk.withValues(alpha: 0.28),
                    blurRadius: 30,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(
                    width: 40,
                    height: 40,
                    child: CircularProgressIndicator(
                        strokeWidth: 3.2, color: AppColors.primary),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Verifying your code',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: frame.ink,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'This only takes a moment',
                    style: TextStyle(fontSize: 13.5, color: frame.body),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The chevron back to the number. A 44px target around a 20px glyph.
class _BackButton extends StatelessWidget {
  const _BackButton({required this.enabled});

  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
      color: context.frame.ink,
      tooltip: 'Back',
      constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
      padding: EdgeInsets.zero,
      alignment: Alignment.centerLeft,
      onPressed: enabled ? () => context.pop() : null,
    );
  }
}

/// The card that owns the whole task.
class _VerifyCard extends StatelessWidget {
  const _VerifyCard({
    required this.masked,
    required this.controller,
    required this.boxWidth,
    required this.seconds,
    required this.resending,
    required this.verifying,
    required this.complete,
    required this.onChanged,
    required this.onCompleted,
    required this.onResend,
    required this.onVerify,
  });

  final String masked;
  final TextEditingController controller;
  final double boxWidth;
  final int seconds;
  final bool resending;
  final bool verifying;
  final bool complete;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onCompleted;
  final VoidCallback onResend;
  final VoidCallback onVerify;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final frame = context.frame;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 24),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.brandInk.withValues(alpha: 0.07),
            blurRadius: 26,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Verify OTP',
                      style: TextStyle(
                        fontSize: 29,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.4,
                        color: frame.ink,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text.rich(
                      TextSpan(
                        style: TextStyle(
                          fontSize: 15,
                          height: 1.5,
                          color: frame.body,
                        ),
                        children: [
                          const TextSpan(text: 'We sent a 6-digit code to\n'),
                          TextSpan(
                            text: masked,
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: colors.brandText,
                            ),
                          ),
                          const TextSpan(
                              text: '.\nEnter it below to continue.'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const SecurityShield(size: 104),
            ],
          ),
          const SizedBox(height: 26),
          _PinRow(
            controller: controller,
            boxWidth: boxWidth,
            enabled: !verifying,
            onChanged: onChanged,
            onCompleted: onCompleted,
          ),
          const SizedBox(height: 22),
          Center(
            child: _Resend(
              seconds: seconds,
              resending: resending,
              enabled: !verifying,
              onResend: onResend,
            ),
          ),
          const SizedBox(height: 22),
          const _DidntReceive(),
          const SizedBox(height: 24),
          _VerifyButton(
            enabled: complete && !verifying,
            busy: verifying,
            onPressed: onVerify,
          ),
        ],
      ),
    );
  }
}

class _PinRow extends StatelessWidget {
  const _PinRow({
    required this.controller,
    required this.boxWidth,
    required this.enabled,
    required this.onChanged,
    required this.onCompleted,
  });

  final TextEditingController controller;
  final double boxWidth;
  final bool enabled;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onCompleted;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    // pin_code_fields keeps a hidden TextField behind the boxes and never sets
    // `filled: false` on it, so it inherits the app's `filled: true` and paints
    // a grey slab across the row. Clearing the inherited decoration for this
    // subtree is what removes it.
    return Theme(
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
        controller: controller,
        keyboardType: TextInputType.number,
        animationType: AnimationType.fade,
        animationDuration: const Duration(milliseconds: 120),
        enabled: enabled,
        // The screen created this controller and disposes it. Left at its
        // default `true`, the package disposes it too — and children unmount
        // before their parent, so the screen's own dispose then touches a
        // controller that is already gone.
        autoDisposeControllers: false,
        autoFocus: true,
        autoDismissKeyboard: false,
        enablePinAutofill: true,
        hapticFeedbackTypes: HapticFeedbackTypes.light,
        useHapticFeedback: true,
        cursorColor: AppColors.primary,
        textStyle: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w700,
          color: context.frame.ink,
        ),
        pinTheme: PinTheme(
          shape: PinCodeFieldShape.box,
          borderRadius: BorderRadius.circular(16),
          // Sized from the viewport so six boxes always fit, including on a
          // 360dp phone at large text scale.
          fieldHeight: 58,
          fieldWidth: boxWidth,
          borderWidth: 1.4,
          activeColor: AppColors.primary,
          selectedColor: AppColors.primary,
          inactiveColor: colors.border,
          disabledColor: colors.border,
          activeFillColor: colors.input,
          selectedFillColor: AppColors.primary.withValues(alpha: 0.08),
          inactiveFillColor: colors.input,
        ),
        enableActiveFill: true,
        onCompleted: onCompleted,
        onChanged: onChanged,
      ),
    );
  }
}

/// The countdown, and the resend it turns into.
class _Resend extends StatelessWidget {
  const _Resend({
    required this.seconds,
    required this.resending,
    required this.enabled,
    required this.onResend,
  });

  final int seconds;
  final bool resending;
  final bool enabled;
  final VoidCallback onResend;

  @override
  Widget build(BuildContext context) {
    final frame = context.frame;

    if (resending) {
      return const SizedBox(
        height: 44,
        width: 44,
        child: Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
                strokeWidth: 2, color: AppColors.primary),
          ),
        ),
      );
    }

    if (seconds == 0) {
      return TextButton(
        onPressed: enabled ? onResend : null,
        child: const Text('Resend OTP'),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(shape: BoxShape.circle, color: frame.tile),
          child: Icon(Icons.schedule_rounded,
              size: 17, color: context.colors.brandText),
        ),
        const SizedBox(width: 10),
        // Flexible so the sentence wraps at a large text scale rather than
        // running off the card.
        Flexible(
          child: Text.rich(
            TextSpan(
              style: TextStyle(fontSize: 14.5, color: frame.body),
              children: [
                const TextSpan(text: 'Resend OTP in '),
                TextSpan(
                  text: '${seconds}s',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: context.colors.brandText,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// The strip that answers the question everyone asks at this screen.
class _DidntReceive extends StatelessWidget {
  const _DidntReceive();

  @override
  Widget build(BuildContext context) {
    final frame = context.frame;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        color: frame.tile,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.verified_user_rounded,
              size: 20, color: context.colors.brandText),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Didn't receive the code?",
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    color: frame.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Check your SMS or try resending the code.',
                  style: TextStyle(fontSize: 13.5, color: frame.body),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _VerifyButton extends StatelessWidget {
  const _VerifyButton({
    required this.enabled,
    required this.busy,
    required this.onPressed,
  });

  final bool enabled;
  final bool busy;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 58,
      child: ElevatedButton(
        // Disabled until six digits are in, and while a verify is in flight —
        // the same flag that guards the auto-fire on the last digit.
        onPressed: enabled ? onPressed : null,
        style: ElevatedButton.styleFrom(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        child: busy
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                    strokeWidth: 2.5, color: AppColors.onPrimary),
              )
            : const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Flexible: at a large text scale the label is wider than
                  // the button, and a CTA that overflows is a red-and-yellow
                  // bar across the card.
                  Flexible(
                    child: Text(
                      'Verify & Continue',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 16.5, fontWeight: FontWeight.w700),
                    ),
                  ),
                  SizedBox(width: 10),
                  Icon(Icons.arrow_forward_rounded, size: 20),
                ],
              ),
      ),
    );
  }
}

/// The promise under the card, on the page itself rather than in it.
class _SecurityNote extends StatelessWidget {
  const _SecurityNote();

  @override
  Widget build(BuildContext context) {
    final frame = context.frame;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(shape: BoxShape.circle, color: frame.tile),
          child: Icon(Icons.lock_outline_rounded, size: 21, color: frame.body),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Your security is our priority',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: frame.ink,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                'We never share your OTP or personal details with anyone.',
                style:
                    TextStyle(fontSize: 13.5, height: 1.45, color: frame.body),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
