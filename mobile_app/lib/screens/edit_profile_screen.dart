import 'dart:async';

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
  late final TextEditingController _username;
  late final TextEditingController _bio;

  /// The handle the account already has, so an untouched field is not saved
  /// again — and so the availability line knows to stay quiet.
  String _originalUsername = '';

  /// What every field held when the screen opened.
  ///
  /// "Has anything changed?" has to be answered against the values the person
  /// arrived with, not against whether they typed — typing a character and
  /// deleting it again leaves nothing to discard, and warning about it would
  /// train people to dismiss the warning.
  late final Map<String, String> _original;

  Timer? _usernameDebounce;
  bool _checkingUsername = false;

  /// What the server said about the handle currently typed: null while nothing
  /// has been checked, otherwise available plus the reason when it is not.
  ({bool available, String? reason})? _usernameCheck;

  bool _saving = false;

  /// Mirrors [_isDirty] so the button and the guard rebuild with it.
  bool _dirty = false;

  @override
  void initState() {
    super.initState();
    final user = ref.read(authProvider).user;
    _name = TextEditingController(text: user?.name ?? '');
    _email = TextEditingController(text: user?.email ?? '');
    _originalUsername = user?.username ?? '';
    _username = TextEditingController(text: _originalUsername);
    _bio = TextEditingController(text: user?.bio ?? '');

    _original = {
      'name': _name.text,
      'email': _email.text,
      'username': _username.text,
      'bio': _bio.text,
    };

    // Every field drives the same "is anything different?" question, so the
    // bar's enabled state and the leave guard cannot disagree about it.
    for (final c in [_name, _email, _username, _bio]) {
      c.addListener(_onAnyFieldChanged);
    }
  }

  void _onAnyFieldChanged() {
    final dirty = _isDirty;
    if (dirty != _dirty && mounted) setState(() => _dirty = dirty);
  }

  /// Does the form hold anything the account does not?
  bool get _isDirty =>
      _name.text.trim() != _original['name']!.trim() ||
      _email.text.trim() != _original['email']!.trim() ||
      _bio.text.trim() != _original['bio']!.trim() ||
      _typedUsername != _originalUsername;

  @override
  void dispose() {
    _usernameDebounce?.cancel();
    for (final c in [_name, _email, _username, _bio]) {
      c.removeListener(_onAnyFieldChanged);
    }
    _name.dispose();
    _email.dispose();
    _username.dispose();
    _bio.dispose();
    super.dispose();
  }

  /// The handle as the API stores it: trimmed, lowercased, no leading `@`.
  String get _typedUsername =>
      _username.text.trim().replaceAll(RegExp(r'^@+'), '').toLowerCase();

  bool get _usernameChanged =>
      _typedUsername.isNotEmpty && _typedUsername != _originalUsername;

  /// Ask the server whether the typed handle is free.
  ///
  /// Debounced, because every keystroke would otherwise be a request. Advisory
  /// only — the save still handles a 409, since somebody can claim the name in
  /// the moment between this answer and the write.
  void _onUsernameChanged(String _) {
    _usernameDebounce?.cancel();
    setState(() => _usernameCheck = null);
    if (!_usernameChanged) return;

    _usernameDebounce = Timer(const Duration(milliseconds: 450), () async {
      final candidate = _typedUsername;
      if (!mounted || candidate.isEmpty) return;
      setState(() => _checkingUsername = true);
      try {
        final res = await ApiClient.checkUsername(candidate);
        if (!mounted || _typedUsername != candidate) return;
        setState(() {
          _checkingUsername = false;
          _usernameCheck = (
            available: res['available'] as bool? ?? false,
            reason: res['reason'] as String?,
          );
        });
      } catch (_) {
        if (!mounted) return;
        // A failed check is not a verdict — the field stays neutral and the
        // save is what finally decides.
        setState(() {
          _checkingUsername = false;
          _usernameCheck = null;
        });
      }
    });
  }

  /// May the screen close?
  ///
  /// True when nothing has changed, or when the person confirms they are happy
  /// to lose it. A save in flight is never interrupted — the request is already
  /// on its way, so leaving mid-write would leave the person unsure whether it
  /// landed.
  Future<bool> _confirmLeave() async {
    if (_saving) return false;
    if (!_isDirty) return true;

    final discard = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final colors = ctx.colors;
        return AlertDialog(
          title: const Text('Discard your changes?'),
          content: Text(
            'You have edits you have not saved yet. If you leave now they '
            'will be lost.',
            style: TextStyle(color: colors.textSecondary, height: 1.45),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Keep editing'),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              style: TextButton.styleFrom(foregroundColor: AppColors.error),
              child: const Text('Discard'),
            ),
          ],
        );
      },
    );
    return discard ?? false;
  }

  /// The back control, and the only way out other than saving.
  Future<void> _leave() async {
    if (!await _confirmLeave()) return;
    if (!mounted) return;
    context.pop();
  }

  Future<void> _save() async {
    if (_saving) return;
    if (!_form.currentState!.validate()) return;

    setState(() => _saving = true);
    try {
      // The handle has its own endpoint and its own failure — do it first, so
      // a name that was taken in the last second stops the save with the right
      // message rather than half-applying the form.
      if (_usernameChanged) {
        await ApiClient.setUsername(_typedUsername);
        _originalUsername = _typedUsername;
      }

      final email = _email.text.trim();
      final bio = _bio.text.trim();
      await ApiClient.updateProfile({
        'name': _name.text.trim(),
        'email': email.isEmpty ? null : email,
        'bio': bio.isEmpty ? null : bio,
      });
      await ref.read(authProvider.notifier).refreshUser();

      if (!mounted) return;
      // Saved is the new baseline: leaving now has nothing to discard, and the
      // guard must not ask about changes that are already persisted.
      _original
        ..['name'] = _name.text
        ..['email'] = _email.text
        ..['username'] = _username.text
        ..['bio'] = _bio.text;
      setState(() {
        _saving = false;
        _dirty = false;
      });
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

    return PopScope(
      // The system back gesture and the hardware button go through the same
      // guard as the arrow in the app bar — a screen that only protects one of
      // them protects nothing, because people leave whichever way is nearest.
      canPop: !_dirty && !_saving,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await _confirmLeave() && context.mounted) context.pop();
      },
      child: Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: const Text('Edit Profile'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          tooltip: 'Back',
          onPressed: _saving ? null : _leave,
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
                _Label('Username', colors: colors),
                const SizedBox(height: 4),
                Text(
                  'How other players find and invite you.',
                  style: TextStyle(fontSize: 12.5, color: colors.textSecondary),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _username,
                  enabled: !_saving,
                  autocorrect: false,
                  textInputAction: TextInputAction.next,
                  onChanged: _onUsernameChanged,
                  decoration: InputDecoration(
                    hintText: 'ravi_99',
                    prefixIcon: const Icon(Icons.alternate_email_rounded, size: 20),
                    suffixIcon: _UsernameStatus(
                      checking: _checkingUsername,
                      changed: _usernameChanged,
                      check: _usernameCheck,
                    ),
                  ),
                  validator: (_) {
                    if (!_usernameChanged) return null;
                    final check = _usernameCheck;
                    if (check != null && !check.available) {
                      return check.reason ?? 'Pick a different username.';
                    }
                    return null;
                  },
                ),
                if (_usernameChanged &&
                    _usernameCheck != null &&
                    _usernameCheck!.available) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(Icons.check_circle_rounded,
                          size: 15, color: colors.successText),
                      const SizedBox(width: 6),
                      Text(
                        '@$_typedUsername is available',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: colors.successText,
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 20),
                _Label('Bio (optional)', colors: colors),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _bio,
                  enabled: !_saving,
                  maxLines: 2,
                  maxLength: 160,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    hintText: 'Left wing. Plays most Sundays.',
                  ),
                ),
                const SizedBox(height: 4),
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
        // Disabled until something has actually changed. The label stays put:
        // swapping it to "Saved" when the screen opens would claim a save that
        // never happened.
        onPressed: _dirty ? _save : null,
      ),
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

/// The live verdict inside the username field.
///
/// Deliberately silent until the handle actually differs from the one the
/// account already has — telling somebody their own username is taken is the
/// classic bug in this control.
class _UsernameStatus extends StatelessWidget {
  final bool checking;
  final bool changed;
  final ({bool available, String? reason})? check;

  const _UsernameStatus({
    required this.checking,
    required this.changed,
    required this.check,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    if (!changed) return const SizedBox.shrink();
    if (checking) {
      return const Padding(
        padding: EdgeInsets.all(14),
        child: SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    final result = check;
    if (result == null) return const SizedBox.shrink();

    // Paired with an icon, never signalled by colour alone.
    return Icon(
      result.available ? Icons.check_circle_rounded : Icons.cancel_rounded,
      size: 20,
      color: result.available ? colors.successText : AppColors.error,
    );
  }
}
