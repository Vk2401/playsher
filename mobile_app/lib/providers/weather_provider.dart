import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/weather_client.dart';
import '../models/ground_model.dart';
import '../models/weather_model.dart';

/// Weather for one venue, keyed by ground id.
///
/// Fetched in a single batched request for the whole list rather than one per
/// card, then read back per card from this map. Ground ids that have no
/// coordinates, or whose fetch failed, are simply absent — the card shows
/// nothing rather than an error.
final groundWeatherProvider =
    FutureProvider.family<Map<int, Weather>, List<int>>((ref, groundIds) async {
  final coords = ref.watch(_weatherPointsProvider);

  final wanted = groundIds
      .where(coords.containsKey)
      .toList(growable: false);
  if (wanted.isEmpty) return const {};

  final results = await WeatherClient.forCoordinates(
    wanted.map((id) => coords[id]!).toList(),
  );

  // A short answer means some points were dropped; pairing by index past that
  // point would label venues with each other's weather.
  if (results.length != wanted.length) return const {};

  return {for (var i = 0; i < wanted.length; i++) wanted[i]: results[i]};
});

/// Coordinates the weather fetch should use, published by whichever screen is
/// showing venues. Kept separate from the fetch so the family key stays a
/// plain list of ids with cheap equality.
final _weatherPointsProvider =
    StateProvider<Map<int, ({double latitude, double longitude})>>((_) => {});

/// Registers the coordinates of the grounds currently on screen.
///
/// Call from a screen after its list resolves. Ignores grounds without usable
/// coordinates — 0,0 is an unset column, not a venue in the Atlantic.
void publishWeatherPoints(WidgetRef ref, List<GroundModel> grounds) {
  final points = <int, ({double latitude, double longitude})>{};
  for (final g in grounds) {
    final lat = g.latitude;
    final lng = g.longitude;
    if (lat == null || lng == null) continue;
    if (lat == 0 && lng == 0) continue;
    points[g.id] = (latitude: lat, longitude: lng);
  }

  final notifier = ref.read(_weatherPointsProvider.notifier);
  // Only write when something actually changed, or every rebuild invalidates
  // the fetch and the list re-requests forever.
  if (!_sameKeys(notifier.state, points)) notifier.state = points;
}

bool _sameKeys(
  Map<int, ({double latitude, double longitude})> a,
  Map<int, ({double latitude, double longitude})> b,
) =>
    a.length == b.length && a.keys.every(b.containsKey);
