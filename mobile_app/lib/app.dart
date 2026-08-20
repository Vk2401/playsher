import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/app_colors.dart';
import 'core/theme.dart';
import 'providers/theme_provider.dart';
import 'router.dart';
import 'widgets/app_update_gate.dart';

class PlaysherApp extends ConsumerWidget {
  const PlaysherApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final themeMode = ref.watch(themeProvider);

    return MaterialApp.router(
      title: 'Playsher',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      routerConfig: router,
      // The update gate sits above the router so a retired build is blocked on
      // every route, including login.
      builder: (context, child) => AppUpdateGate(
        child: _SystemBars(child: child ?? const SizedBox()),
      ),
    );
  }
}

/// Keeps the status/navigation bar glyphs readable on screens that have no
/// `AppBar` to carry `AppBarTheme.systemOverlayStyle` — most of the app's
/// tabs build a bare `Scaffold`, so without this the bars keep whatever style
/// the previous route happened to set.
class _SystemBars extends StatelessWidget {
  final Widget child;
  const _SystemBars({required this.child});

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    final colors = context.colors;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
        systemNavigationBarColor: colors.background,
        systemNavigationBarIconBrightness:
            isDark ? Brightness.light : Brightness.dark,
      ),
      child: child,
    );
  }
}
