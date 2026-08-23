import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/app_colors.dart';
import '../core/constants.dart';
import '../providers/auth_provider.dart';
import '../widgets/playsher_logo.dart';
import '../widgets/sport_props.dart';

/// The login screen: a floodlit ground behind the welcome, and the mobile
/// number the whole OTP flow starts from.
///
/// Follows the device theme like the splash and onboarding before it.
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
    final frame = context.frame;
    final dark = context.isDark;
    final busy = _submitting || ref.watch(authProvider).isLoading;
    final size = MediaQuery.of(context).size;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: dark ? Brightness.light : Brightness.dark,
        statusBarBrightness: dark ? Brightness.dark : Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: frame.page,
        body: Stack(
          children: [
            // Behind the content, not over it: the kit fills the corners the
            // cards leave and is covered wherever they reach it.
            //
            // Pinned to the top at the page's full height rather than left to
            // fill the body, because the body shrinks when the keyboard opens.
            // The kit therefore keeps painting the corners that are still on
            // screen and the keyboard simply covers the pieces it overlaps —
            // the Stack clips the overflow. Dropping it outright, or letting
            // it re-lay-out against the shorter body, is what made the balls
            // vanish and the top corner jump the moment the field was tapped.
            Positioned(
              top: 0,
              left: 0,
              width: size.width,
              height: size.height,
              child: _KitScatter(size: size),
            ),

            SafeArea(
              bottom: false,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(14, 8, 14, 32),
                child: Form(
                  key: _form,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(left: 14),
                        child: PlaysherLogo.tile(size: 76),
                      ),
                      const SizedBox(height: 26),
                      Padding(
                        padding: const EdgeInsets.only(left: 14, right: 24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text.rich(
                              TextSpan(
                                style: TextStyle(
                                  fontSize: 33,
                                  fontWeight: FontWeight.w800,
                                  height: 1.2,
                                  letterSpacing: -0.5,
                                  color: frame.ink,
                                ),
                                children: [
                                  const TextSpan(text: 'Welcome to\n'),
                                  TextSpan(
                                    text: AppConstants.appName,
                                    style:
                                        TextStyle(color: colors.brandText),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 14),
                            Text(
                              'Book your favourite turf,\nplay your best game.',
                              style: TextStyle(
                                fontSize: 16,
                                height: 1.5,
                                color: frame.body,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 26),
                      const _TrustCard(),
                      const SizedBox(height: 18),
                      _NumberCard(
                        controller: _ctrl,
                        busy: busy,
                        onSubmit: _sendOtp,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The sports kit tucked into the page's corners.
///
/// Every piece sits behind the cards and half of each one runs off an edge, so
/// the page reads as a corner of a kit bag rather than a row of stickers. The
/// football is the photograph from the design; the rest are painted to match
/// it — see [SportPropIcon].
class _KitScatter extends StatelessWidget {
  const _KitScatter({required this.size});

  final Size size;

  @override
  Widget build(BuildContext context) {
    final w = size.width;
    final h = size.height;

    return IgnorePointer(
      child: ExcludeSemantics(
        child: Stack(
          children: [
            // Top right, above the welcome: the biggest piece, mostly off-page.
            Positioned(
              top: -w * 0.10,
              right: -w * 0.16,
              child: SportPropIcon(SportProp.basketball, size: w * 0.46),
            ),
            // Beside the deck, where the headline has already narrowed.
            Positioned(
              top: h * 0.20,
              right: -w * 0.04,
              child: SportPropIcon(SportProp.cricketBall, size: w * 0.17),
            ),
            Positioned(
              top: h * 0.30,
              right: w * 0.16,
              child: SportPropIcon(SportProp.tennisBall, size: w * 0.10),
            ),
            // The bottom, under the form card.
            Positioned(
              left: -w * 0.05,
              bottom: 0,
              child: Image.asset(
                'assets/images/login_ball.png',
                width: w * 0.30,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
            ),
            Positioned(
              right: w * 0.06,
              bottom: -h * 0.06,
              child: SportPropIcon(SportProp.cricketBat,
                  size: w * 0.17, turns: 0.06),
            ),
            Positioned(
              right: -w * 0.06,
              bottom: h * 0.06,
              child: SportPropIcon(SportProp.volleyball, size: w * 0.24),
            ),
          ],
        ),
      ),
    );
  }
}

/// The reassurance strip between the welcome and the form.
class _TrustCard extends StatelessWidget {
  const _TrustCard();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.brandInk.withValues(alpha: 0.08),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primary,
            ),
            child: const Icon(Icons.verified_user_rounded,
                size: 24, color: AppColors.onPrimary),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Fast. Secure. Hassle-free.',
                  style: TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w700,
                    color: context.frame.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Login to continue booking',
                  style: TextStyle(fontSize: 14.5, color: context.frame.body),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The card that owns the mobile number, the CTA and the terms.
class _NumberCard extends StatelessWidget {
  const _NumberCard({
    required this.controller,
    required this.busy,
    required this.onSubmit,
  });

  final TextEditingController controller;
  final bool busy;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final frame = context.frame;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 22),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.brandInk.withValues(alpha: 0.08),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Mobile Number',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: frame.ink,
            ),
          ),
          const SizedBox(height: 12),
          _NumberField(
              controller: controller, busy: busy, onSubmit: onSubmit),
          const SizedBox(height: 12),
         
          const SizedBox(height: 26),
          _SendOtpButton(busy: busy, onPressed: onSubmit),
          const SizedBox(height: 22),
          Center(
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.shield_outlined, size: 16, color: frame.body),
                    const SizedBox(width: 7),
                    // Flexible, not bare: this sentence is the widest fixed
                    // string on the card and it has to wrap at a large text
                    // scale rather than run off the edge.
                    Flexible(
                      child: Text(
                        'By continuing, you agree to our',
                        style: TextStyle(fontSize: 13.5, color: frame.body),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  'Terms of Service & Privacy Policy',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: colors.brandText,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NumberField extends StatelessWidget {
  const _NumberField({
    required this.controller,
    required this.busy,
    required this.onSubmit,
  });

  final TextEditingController controller;
  final bool busy;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final frame = context.frame;
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: colors.brandText.withValues(alpha: 0.35)),
    );

    return TextFormField(
      controller: controller,
      keyboardType: TextInputType.phone,
      textInputAction: TextInputAction.done,
      enabled: !busy,
      onFieldSubmitted: (_) => onSubmit(),
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(10),
      ],
      style: TextStyle(
        fontSize: 16.5,
        fontWeight: FontWeight.w500,
        color: frame.ink,
      ),
      decoration: InputDecoration(
        filled: false,
        contentPadding: const EdgeInsets.symmetric(vertical: 18),
        border: border,
        enabledBorder: border,
        disabledBorder: border,
        focusedBorder: border.copyWith(
          borderSide: const BorderSide(color: AppColors.primary, width: 1.6),
        ),
        prefixIcon: Padding(
          padding: const EdgeInsets.only(left: 16, right: 14),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('\u{1F1EE}\u{1F1F3}', style: TextStyle(fontSize: 21)),
              const SizedBox(width: 8),
              Text(
                '+91',
                style: TextStyle(
                  fontSize: 16.5,
                  fontWeight: FontWeight.w700,
                  color: frame.ink,
                ),
              ),
              const SizedBox(width: 4),
              Icon(Icons.keyboard_arrow_down_rounded,
                  size: 20, color: frame.body),
              const SizedBox(width: 14),
              Container(width: 1, height: 26, color: colors.border),
            ],
          ),
        ),
        prefixIconConstraints:
            const BoxConstraints(minHeight: 44, minWidth: 44),
        hintText: 'Enter mobile number',
        hintStyle: TextStyle(fontSize: 16.5, color: frame.body),
      ),
      validator: (v) {
        if (v == null || v.trim().isEmpty) return 'Mobile number is required';
        if (v.trim().length != 10) return 'Enter a valid 10-digit number';
        if (!RegExp(r'^[6-9]\d{9}$').hasMatch(v.trim())) {
          return 'Enter a valid Indian mobile number';
        }
        return null;
      },
    );
  }
}

class _SendOtpButton extends StatelessWidget {
  const _SendOtpButton({required this.busy, required this.onPressed});

  final bool busy;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primaryLift, AppColors.primary],
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.32),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: SizedBox(
        width: double.infinity,
        height: 58,
        child: ElevatedButton(
          // The gradient is the fill; the button paints only its ink and ripple.
          onPressed: busy ? null : onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            disabledBackgroundColor: Colors.transparent,
            foregroundColor: AppColors.onPrimary,
            shadowColor: Colors.transparent,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
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
                  children: [
                    Icon(Icons.send_rounded, size: 21),
                    SizedBox(width: 12),
                    Text(
                      'Send OTP',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
