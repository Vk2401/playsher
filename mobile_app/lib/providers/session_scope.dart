import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'bookings_provider.dart';
import 'city_provider.dart';
import 'coach_bookings_provider.dart';
import 'coaches_provider.dart';
import 'favorites_provider.dart';
import 'games_provider.dart';
import 'grounds_provider.dart';
import 'notifications_provider.dart';
import 'profile_provider.dart';

/// Everything the app holds *for the signed-in account*.
///
/// Riverpod keeps a resolved provider's value for the life of the process, so
/// a logout that only drops the tokens leaves every one of these still holding
/// the last user's rows: sign in with a different number and the previous
/// name, bookings and favourites are still on screen, which reads as having
/// been logged into the wrong account. Clearing them is part of logging out,
/// not an optimisation.
///
/// **Add a provider here when it reads anything behind an `Authorization`
/// header, or anything the server personalises for the caller** — the venue
/// catalogue counts, because a ground carries the signed-in user's
/// `is_favorite`. Invalidating a family clears every parameterisation of it.
///
/// Device preferences deliberately stay: the theme, whether onboarding has
/// been seen, and the installed version belong to the phone, not the account.
final _userScoped = <ProviderOrFamily>[
  // Straightforwardly the user's own rows.
  bookingsProvider,
  bookingDetailProvider,
  myGamesProvider,
  favoritesProvider,
  profileProvider,
  notificationsProvider,
  unreadNotificationCountProvider,

  // The city the account chose, which the next user must pick for themselves.
  cityProvider,

  // Personalised reads: each of these carries per-user flags in its payload.
  groundsProvider,
  groundDetailProvider,
  groundSportsProvider,
  slotsProvider,
  reviewEligibilityProvider,
  gamesProvider,
  gameDetailProvider,
  coachesProvider,
  coachDetailProvider,
  coachSlotsProvider,
  coachBookingsProvider,
  coachBookingDetailProvider,
];

/// Drop every cached answer that belonged to the account that just signed out.
///
/// Safe to call when nothing is watching: an unwatched provider is simply
/// discarded rather than refetched.
void invalidateUserScopedProviders(Ref ref) {
  for (final provider in _userScoped) {
    ref.invalidate(provider);
  }
}
