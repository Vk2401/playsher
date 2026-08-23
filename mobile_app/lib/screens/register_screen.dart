import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/api_error.dart';
import '../core/app_colors.dart';
import '../providers/auth_provider.dart';
import '../widgets/playsher_logo.dart';

/// The last step before the app: a name, an optional email, and the number
/// that has already been verified shown back as proof.
///
/// Third of three — number, code, profile — which is what the rule under the
/// CTA counts off.
class RegisterScreen extends ConsumerStatefulWidget {
  final String mobile;
  const RegisterScreen({super.key, required this.mobile});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    super.dispose();
  }

  bool _submitting = false;

  Future<void> _register() async {
    if (_submitting) return;
    if (!_form.currentState!.validate()) return;
    setState(() => _submitting = true);
    try {
      await ref.read(authProvider.notifier).completeRegistration(
            _name.text.trim(),
            widget.mobile,
            email: _email.text.trim().isEmpty ? null : _email.text.trim(),
          );
      if (!mounted) return;
      // Leave _submitting set — the screen is being replaced and the loader
      // must stay up until /location is on screen.
      context.go('/location', extra: true); // true = fromRegister
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(apiErrorMessage(e,
                fallback:
                    'Could not complete your profile. Please try again.')),
            backgroundColor: AppColors.error,
          ),
        );
    }
  }

  /// Leaving this screen abandons a half-made account, so it asks first.
  ///
  /// The number has been verified but nothing is saved against it yet — going
  /// back drops that and returns to the number entry, so the confirmation is
  /// the difference between a deliberate exit and a mis-swipe on the edge of
  /// the screen. Answering yes clears whatever the flow already put on the
  /// device, which is why it goes through `logout` rather than just popping.
  Future<void> _confirmLeave() async {
    if (_submitting) return;

    final leave = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Log out?'),
        content: const Text(
          "Your number is verified, but your profile isn't saved yet. "
          "You'll need to verify it again to finish signing up.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Stay'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child:
                const Text('Log out', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );

    if (leave != true || !mounted) return;
    await ref.read(authProvider.notifier).logout();
    if (!mounted) return;
    context.go('/login');
  }

  /// The verified number, spaced the way it is dialled rather than stored.
  String get _prettyMobile {
    final m = widget.mobile;
    if (!m.startsWith('+91')) return m;
    final digits = m.substring(3);
    if (digits.length != 10) return m;
    return '+91 ${digits.substring(0, 5)} ${digits.substring(5)}';
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final frame = context.frame;
    final loading = _submitting || ref.watch(authProvider).isLoading;

    // canPop: false so the gesture and the hardware button both come through
    // _confirmLeave. A dialog on the chevron alone would be a confirmation the
    // most common way of leaving never sees.
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmLeave();
      },
      child: Scaffold(
        backgroundColor: frame.page,
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 2, 20, 12),
            child: Form(
              key: _form,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  IconButton(
                    icon:
                        const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
                    color: frame.ink,
                    tooltip: 'Back',
                    constraints:
                        const BoxConstraints(minWidth: 44, minHeight: 44),
                    padding: EdgeInsets.zero,
                    alignment: Alignment.centerLeft,
                    onPressed: loading ? null : _confirmLeave,
                  ),
                  const SizedBox(height: 6),
                  const PlaysherLogo.tile(size: 56),
                  const SizedBox(height: 16),
                  Text.rich(
                    TextSpan(
                      style: TextStyle(
                        fontSize: 29,
                        fontWeight: FontWeight.w800,
                        height: 1.2,
                        letterSpacing: -0.5,
                        color: frame.ink,
                      ),
                      children: [
                        const TextSpan(text: 'Complete Your\n'),
                        TextSpan(
                          text: 'Profile',
                          style: TextStyle(color: colors.brandText),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    "You're almost there!\nJust fill in a few details.",
                    style: TextStyle(
                      fontSize: 15,
                      height: 1.45,
                      color: frame.body,
                    ),
                  ),
                  const SizedBox(height: 18),

                  // The number is not editable here: it is the one the code was
                  // just verified against, and changing it would strand the
                  // registration against a mobile nobody proved.
                  const _FieldLabel('Mobile Number'),
                  _VerifiedMobileField(mobile: _prettyMobile),
                  const SizedBox(height: 16),

                  const _FieldLabel('Full Name', required: true),
                  _ProfileField(
                    controller: _name,
                    enabled: !loading,
                    icon: Icons.person_outline_rounded,
                    hint: 'Enter your full name',
                    textCapitalization: TextCapitalization.words,
                    textInputAction: TextInputAction.next,
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return 'Name is required';
                      }
                      if (v.trim().length < 2) return 'Enter a valid name';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  const _FieldLabel('Email (optional)'),
                  _ProfileField(
                    controller: _email,
                    enabled: !loading,
                    icon: Icons.mail_outline_rounded,
                    hint: 'Enter your email address',
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => _register(),
                    validator: (v) {
                      if (v != null && v.isNotEmpty && !v.contains('@')) {
                        return 'Enter a valid email address';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),

                  const _SafeNote(),
                  const SizedBox(height: 20),

                  _GetStartedButton(loading: loading, onPressed: _register),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A field's label. The asterisk is red *and* announced, so "required" does
/// not depend on seeing the colour.
class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text, {this.required = false});

  final String text;
  final bool required;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text.rich(
        TextSpan(
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: context.frame.ink,
          ),
          children: [
            TextSpan(text: text),
            if (required)
              const TextSpan(
                text: ' *',
                style: TextStyle(color: AppColors.error),
                semanticsLabel: ' required',
              ),
          ],
        ),
      ),
    );
  }
}

/// The one field that is already answered.
class _VerifiedMobileField extends StatelessWidget {
  const _VerifiedMobileField({required this.mobile});

  final String mobile;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final frame = context.frame;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.brandText.withValues(alpha: 0.28)),
      ),
      child: Row(
        children: [
          Icon(Icons.phone_outlined, size: 21, color: frame.body),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              mobile,
              style: TextStyle(
                fontSize: 16.5,
                fontWeight: FontWeight.w600,
                color: frame.ink,
              ),
            ),
          ),
          const SizedBox(width: 8),
          // The word carries the meaning; the tick and the green only repeat
          // it, so the badge still reads in greyscale.
          Container(
            padding: const EdgeInsets.fromLTRB(10, 5, 8, 5),
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Verified',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: colors.successText,
                  ),
                ),
                const SizedBox(width: 5),
                Icon(Icons.check_circle_rounded,
                    size: 17, color: colors.successText),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileField extends StatelessWidget {
  const _ProfileField({
    required this.controller,
    required this.enabled,
    required this.icon,
    required this.hint,
    required this.validator,
    this.keyboardType,
    this.textCapitalization = TextCapitalization.none,
    this.textInputAction,
    this.onFieldSubmitted,
  });

  final TextEditingController controller;
  final bool enabled;
  final IconData icon;
  final String hint;
  final FormFieldValidator<String> validator;
  final TextInputType? keyboardType;
  final TextCapitalization textCapitalization;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onFieldSubmitted;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final frame = context.frame;
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: colors.brandText.withValues(alpha: 0.28)),
    );

    return TextFormField(
      controller: controller,
      enabled: enabled,
      keyboardType: keyboardType,
      textCapitalization: textCapitalization,
      textInputAction: textInputAction,
      onFieldSubmitted: onFieldSubmitted,
      validator: validator,
      style: TextStyle(
        fontSize: 16.5,
        fontWeight: FontWeight.w500,
        color: frame.ink,
      ),
      decoration: InputDecoration(
        filled: true,
        fillColor: colors.card,
        contentPadding: const EdgeInsets.symmetric(vertical: 16),
        border: border,
        enabledBorder: border,
        disabledBorder: border,
        focusedBorder: border.copyWith(
          borderSide: const BorderSide(color: AppColors.primary, width: 1.6),
        ),
        prefixIcon: Padding(
          padding: const EdgeInsets.only(left: 16, right: 12),
          child: Icon(icon, size: 21, color: frame.body),
        ),
        prefixIconConstraints:
            const BoxConstraints(minHeight: 44, minWidth: 44),
        hintText: hint,
        hintStyle: TextStyle(fontSize: 16.5, color: frame.body),
      ),
    );
  }
}

/// Why the app is asking for any of this.
class _SafeNote extends StatelessWidget {
  const _SafeNote();

  @override
  Widget build(BuildContext context) {
    final frame = context.frame;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: frame.tile,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primary,
            ),
            child: const Icon(Icons.verified_user_rounded,
                size: 22, color: AppColors.onPrimary),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Your Information is Safe',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: frame.ink,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'We use industry-standard security to keep your data '
                  'protected and private.',
                  style: TextStyle(
                      fontSize: 13.5, height: 1.4, color: frame.body),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GetStartedButton extends StatelessWidget {
  const _GetStartedButton({required this.loading, required this.onPressed});

  final bool loading;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: loading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        child: loading
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
                  Flexible(
                    child: Text(
                      'Get Started',
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
