import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/app_colors.dart';
import '../core/constants.dart';
import '../providers/location_provider.dart';

class LocationScreen extends ConsumerStatefulWidget {
  final bool fromRegister;
  const LocationScreen({super.key, this.fromRegister = false});

  @override
  ConsumerState<LocationScreen> createState() => _LocationScreenState();
}

class _LocationScreenState extends ConsumerState<LocationScreen> {
  bool _loading = false;
  String? _error;

  /// Delegates to [userLocationProvider] rather than talking to the plugin
  /// here: the home screen reads the same notifier, so a grant made on this
  /// screen shows up as distances the moment the user lands back on Home.
  Future<void> _requestLocation() async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    final notifier = ref.read(userLocationProvider.notifier);
    final granted = await notifier.requestPermission();
    if (!mounted) return;

    if (granted) {
      context.go('/home');
      return;
    }

    setState(() {
      _loading = false;
      _error = switch (ref.read(userLocationProvider).permission) {
        LocationPermissionState.deniedForever =>
          'Location is blocked for ${AppConstants.appName}. Enable it in app settings.',
        LocationPermissionState.serviceDisabled =>
          'Location services are off. Please switch on GPS and try again.',
        LocationPermissionState.denied => 'Location permission denied.',
        _ => 'Could not get your location. Please try again.',
      };
    });
  }

  void _skip() => context.go('/home');

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Spacer(flex: 2),
              Center(
                child: Container(
                  width: 160,
                  height: 160,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.08),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.2),
                      width: 1,
                    ),
                  ),
                  child: Center(
                    child: Container(
                      width: 110,
                      height: 110,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.location_on_rounded,
                        size: 60,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 40),
              Text(
                widget.fromRegister
                    ? 'Welcome to ${AppConstants.appName}!'
                    : 'Enable Location',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: colors.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Allow ${AppConstants.appName} to use your location to show nearby sports grounds, suggest fields in your city, and give you better recommendations.',
                style: TextStyle(
                  fontSize: 15,
                  color: colors.textSecondary,
                  height: 1.6,
                ),
              ),
              const SizedBox(height: 20),
              _Benefit(
                  icon: Icons.explore_rounded,
                  text: 'Find grounds near you',
                  colors: colors),
              _Benefit(
                  icon: Icons.sports_rounded,
                  text: 'Discover local games',
                  colors: colors),
              _Benefit(
                  icon: Icons.recommend_rounded,
                  text: 'Get personalised suggestions',
                  colors: colors),
              if (_error != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: AppColors.error.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline_rounded,
                          size: 18, color: AppColors.error),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _error!,
                          style: const TextStyle(
                              fontSize: 13, color: AppColors.error),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const Spacer(flex: 3),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: _loading ? null : _requestLocation,
                  icon: _loading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2.5, color: AppColors.onPrimary),
                        )
                      : const Icon(Icons.my_location_rounded, size: 20),
                  label: Text(
                    _loading
                        ? 'Getting location\u2026'
                        : 'Allow Location Access',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: _loading ? null : _skip,
                  child: Text(
                    'Skip for now',
                    style: TextStyle(
                        color: colors.textPrimary, fontWeight: FontWeight.w500),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}

class _Benefit extends StatelessWidget {
  final IconData icon;
  final String text;
  final AppColors colors;
  const _Benefit(
      {required this.icon, required this.text, required this.colors});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16, color: AppColors.primary),
          ),
          const SizedBox(width: 12),
          Text(text, style: TextStyle(fontSize: 14, color: colors.textPrimary)),
        ],
      ),
    );
  }
}
