import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// A back control that always leads somewhere.
///
/// `AppBar`'s automatic leading only appears when there is something to pop.
/// A screen reached with `context.go` — which replaces the whole stack — gets
/// no arrow and swallows the system back, so the app looks frozen and the only
/// way out is to close it. That is what happened to My Bookings after
/// confirming a booking.
///
/// This falls back to [fallbackRoute] when the stack is empty, so the control
/// is never a dead end regardless of how the user arrived.
class AppBackButton extends StatelessWidget {
  final String fallbackRoute;

  const AppBackButton({super.key, this.fallbackRoute = '/home'});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back_rounded),
      tooltip: 'Back',
      onPressed: () {
        if (context.canPop()) {
          context.pop();
        } else {
          context.go(fallbackRoute);
        }
      },
    );
  }
}
