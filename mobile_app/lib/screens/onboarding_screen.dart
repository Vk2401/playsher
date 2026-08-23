import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../core/app_colors.dart';
import '../core/storage.dart';
import '../widgets/onboarding_page.dart';

/// The three-page introduction, shown once before the first login.
///
/// Follows the device theme through [FramePalette], like the splash it hands
/// over from: a fresh install on a dark phone runs the whole first-launch flow
/// dark rather than flashing between a light introduction and a dark app.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pageCtrl = PageController();
  int _page = 0;

  static const _verified = OnboardingFeature(
    icon: Icons.verified_user_rounded,
    title: 'Secure Payments',
    body: 'Safe and hassle-free transactions.',
  );

  static const _pages = <OnboardingContent>[
    OnboardingContent(
      illustration: 'assets/images/onboarding_book.png',
      heroIcon: Icons.calendar_month_rounded,
      title: 'Book Slots',
      titleAccent: 'Instantly',
      deck: 'Pick your date, choose available slots and confirm your booking '
          'in seconds.',
      features: [
        OnboardingFeature(
          icon: Icons.bolt_rounded,
          title: 'Quick & Easy Booking',
          body: 'Book your favourite turf in just a few taps.',
        ),
        OnboardingFeature(
          icon: Icons.access_time_rounded,
          title: 'Real-time Availability',
          body: 'See live slots and never miss a game.',
        ),
        _verified,
      ],
    ),
    OnboardingContent(
      illustration: 'assets/images/onboarding_discover.png',
      heroIcon: Icons.location_on_rounded,
      title: 'Discover',
      titleAccent: 'Nearby Venues',
      deck: 'Find the best sports grounds around you — cricket, football, '
          'basketball and more.',
      features: [
        OnboardingFeature(
          icon: Icons.location_on_rounded,
          title: 'Nearby Search',
          body: 'Find the best turfs closest to your location.',
        ),
        OnboardingFeature(
          icon: Icons.sports_soccer_rounded,
          title: 'Multiple Sports',
          body: 'Explore venues for all your favourite sports.',
        ),
        OnboardingFeature(
          icon: Icons.verified_user_rounded,
          title: 'Verified Venues',
          body: 'Book from trusted and quality venues.',
        ),
      ],
    ),
    OnboardingContent(
      illustration: 'assets/images/onboarding_join.png',
      heroIcon: Icons.groups_rounded,
      title: 'Join Games &',
      titleAccent: 'Meet Players',
      deck: 'Join open games in your area, team up with other players and '
          'level up your game.',
      features: [
        OnboardingFeature(
          icon: Icons.groups_rounded,
          title: 'Join Open Games',
          body: 'Find and join open games near you instantly.',
        ),
        OnboardingFeature(
          icon: Icons.people_alt_rounded,
          title: 'Meet Players',
          body: 'Connect with players who share your passion.',
        ),
        OnboardingFeature(
          icon: Icons.trending_up_rounded,
          title: 'Level Up Your Game',
          body: 'Play more, improve skills and have fun!',
        ),
      ],
    ),
  ];

  void _next() {
    if (_page < _pages.length - 1) {
      _pageCtrl.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    } else {
      _finish();
    }
  }

  Future<void> _finish() async {
    await StorageService.setOnboardingSeen();
    if (mounted) context.go('/login');
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isLast = _page == _pages.length - 1;
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
        body: SafeArea(
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: Padding(
                  padding: const EdgeInsets.only(right: 8, top: 4),
                  child: TextButton(
                    onPressed: _finish,
                    child: Text(
                      'Skip',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: context.colors.brandText,
                      ),
                    ),
                  ),
                ),
              ),

              // Only the page content slides; the dots and the button below are
              // the same control on all three pages and hold still.
              Expanded(
                child: PageView.builder(
                  controller: _pageCtrl,
                  itemCount: _pages.length,
                  onPageChanged: (i) => setState(() => _page = i),
                  itemBuilder: (_, i) => OnboardingPage(content: _pages[i]),
                ),
              ),

              Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(_pages.length, (i) {
                        final active = i == _page;
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 220),
                          curve: Curves.easeOut,
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          width: active ? 26 : 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: active
                                ? context.colors.brandText
                                : frame.dot,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 22),
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: _next,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: AppColors.onPrimary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          elevation: 0,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              isLast ? 'Get Started' : 'Next',
                              style: const TextStyle(
                                fontSize: 16.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(width: 10),
                            const Icon(Icons.arrow_forward_rounded, size: 20),
                          ],
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: _finish,
                      child: Text(
                        'Skip for now',
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w500,
                          color: frame.body,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
