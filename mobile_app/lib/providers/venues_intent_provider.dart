import 'package:flutter_riverpod/flutter_riverpod.dart';

/// What the caller wants the venues screen to do the moment it appears.
enum VenuesIntent {
  /// Put the cursor in the search field and raise the keyboard.
  focusSearch,

  /// Open the filter sheet.
  openFilters,
}

/// A one-shot request for the venues tab, set by whoever navigates there.
///
/// It is a provider rather than a query parameter because the venues tab lives
/// in a `StatefulShellRoute.indexedStack`: its `State` survives every tab
/// switch, so `initState` runs once and a `?q=` left on the route would still
/// be there on the user's next visit — raising the keyboard again, every time,
/// for a tap they made ten minutes ago. This is read once and cleared.
final venuesIntentProvider = StateProvider<VenuesIntent?>((_) => null);
