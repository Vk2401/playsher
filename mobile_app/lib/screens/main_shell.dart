import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../core/app_colors.dart';

class MainShell extends StatefulWidget {
  final StatefulNavigationShell shell;

  const MainShell({super.key, required this.shell});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  static const _homeBranch = 0;
  static const _exitWindow = Duration(seconds: 2);

  DateTime? _lastExitAttempt;

  bool get _canExitNow {
    final last = _lastExitAttempt;
    return last != null && DateTime.now().difference(last) < _exitWindow;
  }

  /// Android back from inside the tab shell.
  ///
  /// Away from Home, back returns to Home rather than closing the app — losing
  /// the whole session because you were three tabs deep is the classic Android
  /// complaint. On Home, it takes two presses inside a short window to leave,
  /// with the first press saying so.
  void _handleBack(bool didPop, Object? result) {
    if (didPop) return;

    if (widget.shell.currentIndex != _homeBranch) {
      widget.shell.goBranch(_homeBranch);
      return;
    }

    if (_canExitNow) {
      Navigator.of(context).maybePop();
      return;
    }

    setState(() => _lastExitAttempt = DateTime.now());
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text('Press back again to exit'),
          duration: _exitWindow,
          behavior: SnackBarBehavior.floating,
          margin: EdgeInsets.fromLTRB(16, 0, 16, 12),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    // canPop stays false so this handler always runs; it decides what back
    // means rather than letting the shell close the app outright.
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: _handleBack,
      child: Scaffold(
        body: widget.shell,
        bottomNavigationBar: NavigationBar(
          selectedIndex: widget.shell.currentIndex,
          onDestinationSelected: (i) => widget.shell
              .goBranch(i, initialLocation: i == widget.shell.currentIndex),
          backgroundColor: context.colors.background,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home_rounded),
              label: 'Home',
            ),
            NavigationDestination(
              icon: Icon(Icons.location_on_outlined),
              selectedIcon: Icon(Icons.location_on_rounded),
              label: 'Venues',
            ),
            NavigationDestination(
              icon: Icon(Icons.emoji_events_outlined),
              selectedIcon: Icon(Icons.emoji_events_rounded),
              label: 'Games',
            ),
            NavigationDestination(
              icon: Icon(Icons.school_outlined),
              selectedIcon: Icon(Icons.school_rounded),
              label: 'Coaching',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline_rounded),
              selectedIcon: Icon(Icons.person_rounded),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }
}
