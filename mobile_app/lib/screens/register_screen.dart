import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/theme.dart';
import '../providers/auth_provider.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  final String mobile;
  const RegisterScreen({super.key, required this.mobile});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _form   = GlobalKey<FormState>();
  final _name   = TextEditingController();
  final _email  = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!_form.currentState!.validate()) return;
    try {
      await ref.read(authProvider.notifier).completeRegistration(
        _name.text.trim(),
        widget.mobile,
        email: _email.text.trim().isEmpty ? null : _email.text.trim(),
      );
      if (mounted) context.go('/location', extra: true); // true = fromRegister
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: AppTheme.error),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final loading = ref.watch(authProvider).isLoading;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Form(
            key: _form,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 20),
                const Text(
                  'Complete Your\nProfile',
                  style: TextStyle(
                    fontSize: 28, fontWeight: FontWeight.w800,
                    color: AppTheme.textPrimary, height: 1.25,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  "You're almost there! Just fill in a few details.",
                  style: TextStyle(fontSize: 14, color: AppTheme.textSecond, height: 1.5),
                ),
                const SizedBox(height: 36),

                // Mobile (read-only)
                const Text(
                  'Mobile',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  initialValue: widget.mobile,
                  readOnly: true,
                  style: const TextStyle(color: AppTheme.textSecond),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: const Color(0xFFF9FAFB),
                    prefixIcon: const Icon(Icons.phone_outlined, size: 18),
                  ),
                ),
                const SizedBox(height: 20),

                // Name
                const Text(
                  'Full Name *',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _name,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    hintText: 'Ahmed Khan',
                    prefixIcon: Icon(Icons.person_outline, size: 20),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Name is required';
                    if (v.trim().length < 2) return 'Enter a valid name';
                    return null;
                  },
                ),
                const SizedBox(height: 20),

                // Email (optional)
                const Text(
                  'Email (optional)',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    hintText: 'ahmed@example.com',
                    prefixIcon: Icon(Icons.email_outlined, size: 20),
                  ),
                  validator: (v) {
                    if (v != null && v.isNotEmpty && !v.contains('@')) {
                      return 'Enter a valid email address';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 36),

                ElevatedButton(
                  onPressed: loading ? null : _register,
                  child: loading
                      ? const SizedBox(
                          width: 22, height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                        )
                      : const Text('Get Started'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
