import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/app_colors.dart';
import '../core/storage.dart';
import '../providers/app_version_provider.dart';
import '../widgets/playsher_logo.dart';
import '../widgets/splash_stage.dart';

/// The first frame of the app: the lockup standing in a floodlit stadium.
///
/// Follows the device theme, so a fresh install on a dark phone opens at the
/// ground at night rather than on a white screen. See [SplashStage].
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _fade;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900));
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeIn);
    _scale = Tween<double>(begin: 0.8, end: 1.0)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack));
    _ctrl.forward();

    // Start the version check while the splash animates. The 2.2s below is
    // dead time anyway, so the answer is usually ready before the first real
    // screen appears and the prompt does not arrive late over the top of it.
    // Fire-and-forget: the provider resolves failures to "nothing to do", and
    // splash must never wait on the network to let someone into the app.
    ref.read(appVersionCheckProvider.future).ignore();

    _navigate();
  }

  Future<void> _navigate() async {
    await Future.delayed(const Duration(milliseconds: 2200));
    if (!mounted) return;

    final onboardingSeen = await StorageService.isOnboardingSeen();
    if (!mounted) return;

    if (!onboardingSeen) {
      context.go('/onboarding');
      return;
    }

    final loggedIn = await StorageService.isLoggedIn();
    if (!mounted) return;
    context.go(loggedIn ? '/home' : '/login');
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final frame = context.frame;
    final dark = context.isDark;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: dark ? Brightness.light : Brightness.dark,
        statusBarBrightness: dark ? Brightness.dark : Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: frame.page,
        body: LayoutBuilder(
          builder: (context, constraints) {
            final h = constraints.maxHeight;

            return Stack(
              fit: StackFit.expand,
              children: [
                const SplashStage(),

                // One entrance for the screen: the lockup fades up while the
                // stadium is already in place behind it.
                FadeTransition(
                  opacity: _fade,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Positioned(
                        top: h * 0.26,
                        left: 0,
                        right: 0,
                        child: Column(
                          children: [
                            ScaleTransition(
                              scale: _scale,
                              child: const PlaysherLogo.tile(size: 112),
                            ),
                            const SizedBox(height: 26),

                            // The wordmark is a very wide shape (10.8:1), so it
                            // is sized by the width it may occupy — not by a
                            // height, which ran it off both edges of the phone.
                            SizedBox(
                              width: constraints.maxWidth * 0.58,
                              child: FittedBox(
                                child: PlaysherLogo.wordmark(
                                  size: 40,
                                  tone: dark
                                      ? PlaysherTone.white
                                      : PlaysherTone.navy,
                                ),
                              ),
                            ),
                            const SizedBox(height: 14),
                            Text(
                              'Book · Play · Win',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w600,
                                // brandText, not primary: the deep brand blue
                                // is only 3.5:1 on the night sky.
                                color: context.colors.brandText,
                                letterSpacing: 1.2,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // The bar sits low on the turf, clear of the centre
                      // circle above it and of the gesture bar below.
                      Positioned(
                        top: h * 0.86,
                        left: 0,
                        right: 0,
                        child: Center(
                          child: SplashProgress(
                            width: constraints.maxWidth * 0.38,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
