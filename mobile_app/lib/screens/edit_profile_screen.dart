import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/api_client.dart';
import '../core/api_error.dart';
import '../core/app_colors.dart';
import '../providers/auth_provider.dart';
import '../widgets/sticky_bottom_bar.dart';

/// Edit the signed-in player's profile.
///
/// The app had no edit screen at all — Settings pointed at the read-only
/// profile view, so a player could never correct their own name or email.
///
/// Mobile is deliberately read-only here. It is the account's login identifier,
/// and changing it means proving ownership of the new number by OTP; a silent
/// profile PUT would let anyone move their account onto someone else's number.
/// The field says so rather than sitting there inert.
class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _email;

  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final user = ref.read(authProvider).user;
    _name = TextEditingController(text: user?.name ?? '');
    _email = TextEditingController(text: user?.email ?? '');
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    if (!_form.currentState!.validate()) return;

    setState(() => _saving = true);
    try {
      final email = _email.text.trim();
      await ApiClient.updateProfile({
        'name': _name.text.trim(),
        'email': email.isEmpty ? null : email,
      });
      await ref.read(authProvider.notifier).refreshUser();

      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('Profile updated')));
      context.pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(apiErrorMessage(e,
                fallback: 'Could not save your profile. Please try again.')),
            backgroundColor: AppColors.error,
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final user = ref.watch(authProvider).user;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: const Text('Edit Profile'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          tooltip: 'Back',
          onPressed: _saving ? null : () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Form(
            key: _form,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: CircleAvatar(
                    radius: 40,
                    backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                    child: Text(
                      user?.initials ?? '?',
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 28),
                _Label('Full name', colors: colors),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _name,
                  enabled: !_saving,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    hintText: 'Your full name',
                    prefixIcon: Icon(Icons.person_outline, size: 20),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'Name is required';
                    }
                    if (v.trim().length < 2) return 'Enter a valid name';
                    return null;
                  },
                ),
                const SizedBox(height: 20),
                _Label('Email (optional)', colors: colors),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _email,
                  enabled: !_saving,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _save(),
                  decoration: const InputDecoration(
                    hintText: 'you@example.com',
                    prefixIcon: Icon(Icons.email_outlined, size: 20),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return null;
                    if (!v.contains('@') || !v.contains('.')) {
                      return 'Enter a valid email address';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),
                _Label('Mobile number', colors: colors),
                const SizedBox(height: 8),
                TextFormField(
                  initialValue: user?.mobile ?? '',
                  readOnly: true,
                  enabled: false,
                  style: TextStyle(color: colors.textSecondary),
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.phone_outlined, size: 20),
                    suffixIcon: Icon(Icons.lock_outline_rounded, size: 18),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline_rounded,
                        size: 15, color: colors.textSecondary),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'This is the number you sign in with. Changing it needs '
                        'a new OTP, so contact support to move your account to '
                        'another number.',
                        style: TextStyle(
                            fontSize: 12,
                            color: colors.textSecondary,
                            height: 1.45),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: StickyBottomBar(
        buttonText: 'Save changes',
        isLoading: _saving,
        onPressed: _save,
      ),
    );
  }
}

class _Label extends StatelessWidget {
  final String text;
  final AppColors colors;
  const _Label(this.text, {required this.colors});

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: colors.textPrimary,
        ),
      );
}
