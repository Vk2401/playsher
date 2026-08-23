import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/api_error.dart';
import '../core/app_colors.dart';
import '../models/venue_filters.dart';
import '../providers/grounds_provider.dart';
import '../providers/location_provider.dart';
import '../providers/venues_intent_provider.dart';
import '../providers/weather_provider.dart';
import '../widgets/venue_card.dart';
import '../widgets/shimmer_loader.dart';
import '../widgets/error_view.dart';

class ExploreScreen extends ConsumerStatefulWidget {
  final String? initialSearch;

  const ExploreScreen({super.key, this.initialSearch});

  @override
  ConsumerState<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends ConsumerState<ExploreScreen> {
  late final TextEditingController _search;
  late final FocusNode _searchFocus;
  int? _sportId;
  String _query = '';
  Timer? _debounce;
  VenueFilters _filters = VenueFilters.none;

  @override
  void initState() {
    super.initState();
    _query = widget.initialSearch ?? '';
    _search = TextEditingController(text: _query);
    // The field's focus drives the container's outline, so the highlight is
    // drawn once, in the right place.
    _searchFocus = FocusNode()..addListener(() => setState(() {}));
  }

  /// Carry out whatever the caller asked for on the way in, and clear it so a
  /// later tab switch does not replay it.
  void _consumeIntent(VenuesIntent intent) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(venuesIntentProvider.notifier).state = null;
      switch (intent) {
        case VenuesIntent.focusSearch:
          _searchFocus.requestFocus();
        case VenuesIntent.openFilters:
          _openFilters();
      }
    });
  }

  /// Opens the filter sheet and applies whatever comes back.
  ///
  /// The old call was a bare `context.push` whose result was discarded, and
  /// the sheet popped without one anyway — which is why Apply Filters did
  /// nothing at all.
  Future<void> _openFilters() async {
    final result = await context.push<VenueFilters>(
      '/venue-filter',
      extra: _filters,
    );
    if (!mounted || result == null) return;
    setState(() {
      _filters = result;
      // A sport chosen in the sheet drives the same top strip, so the two
      // cannot disagree about what is selected.
      _sportId = result.sportIds.length == 1 ? result.sportIds.first : _sportId;
    });
  }

  /// Each keystroke used to change the provider's filter key immediately,
  /// firing a fresh GET /grounds per character typed. Settle first.
  void _onQueryChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      if (value.trim() == _query.trim()) return;
      setState(() => _query = value);
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    // Watched here rather than listened for: whoever set it did so *before*
    // navigating, so the value is already in place by this first build and a
    // listener would never fire.
    final intent = ref.watch(venuesIntentProvider);
    if (intent != null) _consumeIntent(intent);

    // Where the player is, so the API can order nearest-first. Sent only when
    // there is a real fix — half a coordinate is worse than none.
    final location = ref.watch(userLocationProvider);
    final filter = GroundFilter(
      sportId: _sportId ??
          (_filters.sportIds.length == 1 ? _filters.sportIds.first : null),
      search: _query,
      latitude: location.hasFix ? location.latitude : null,
      longitude: location.hasFix ? location.longitude : null,
      radiusKm: location.hasFix ? _filters.maxDistanceKm : null,
      hasRoof: _filters.hasRoof,
    );
    final grounds = ref.watch(groundsProvider(filter));
    final sports = ref.watch(sportsProvider);

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Explore Turfs',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: colors.textPrimary,
                      ),
                    ),
                  ),
                  Semantics(
                    label: 'Filter grounds',
                    button: true,
                    child: GestureDetector(
                      onTap: _openFilters,
                      behavior: HitTestBehavior.opaque,
                      child: SizedBox(
                        width: 44,
                        height: 44,
                        child: Center(
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: _filters.isEmpty
                                      ? colors.input
                                      : AppColors.primary
                                          .withValues(alpha: 0.15),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: _filters.isEmpty
                                        ? colors.border
                                        : AppColors.primary,
                                  ),
                                ),
                                child: Icon(
                                  Icons.tune_rounded,
                                  size: 20,
                                  color: _filters.isEmpty
                                      ? colors.textSecondary
                                      : AppColors.primary,
                                ),
                              ),
                              // How many filters are narrowing the list, so it
                              // is obvious why results are missing.
                              if (!_filters.isEmpty)
                                Positioned(
                                  right: -2,
                                  top: -2,
                                  child: Container(
                                    width: 17,
                                    height: 17,
                                    alignment: Alignment.center,
                                    decoration: const BoxDecoration(
                                      color: AppColors.primary,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Text(
                                      '${_filters.activeCount}',
                                      style: const TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w800,
                                        color: AppColors.onPrimary,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Search bar
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                height: 50,
                decoration: BoxDecoration(
                  color: colors.input,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: _searchFocus.hasFocus
                        ? AppColors.primary
                        : colors.border,
                    width: _searchFocus.hasFocus ? 1.6 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    const SizedBox(width: 14),
                    Icon(Icons.search_rounded,
                        color: colors.textSecondary, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: _search,
                        focusNode: _searchFocus,
                        autofocus: widget.initialSearch != null,
                        style:
                            TextStyle(color: colors.textPrimary, fontSize: 14),
                        cursorColor: AppColors.primary,
                        decoration: InputDecoration(
                          hintText: 'Ground, sport or area\u2026',
                          hintStyle: TextStyle(
                              color: colors.textSecondary, fontSize: 14),
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          contentPadding: EdgeInsets.zero,
                          filled: false,
                        ),
                        onChanged: _onQueryChanged,
                        textInputAction: TextInputAction.search,
                        onSubmitted: (v) {
                          _debounce?.cancel();
                          setState(() => _query = v);
                        },
                      ),
                    ),
                    if (_query.isNotEmpty)
                      IconButton(
                        icon: Icon(Icons.close,
                            size: 18, color: colors.textSecondary),
                        tooltip: 'Clear search',
                        onPressed: () {
                          _debounce?.cancel();
                          _search.clear();
                          setState(() => _query = '');
                        },
                      )
                    else
                      const SizedBox(width: 12),
                  ],
                ),
              ),
            ),
            // Category pills
            sports.maybeWhen(
              data: (list) => SizedBox(
                height: 48,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  children: [
                    _FilterPill(
                      label: 'All Sports',
                      selected: _sportId == null,
                      onTap: () => setState(() => _sportId = null),
                    ),
                    ...list.map((s) => _FilterPill(
                          label: s.name,
                          selected: _sportId == s.id,
                          onTap: () => setState(
                              () => _sportId = _sportId == s.id ? null : s.id),
                        )),
                  ],
                ),
              ),
              // Loading and error both collapse the strip rather than
              // shifting the results below; the results list reports the
              // failure with its own retry.
              orElse: () => const SizedBox(height: 48),
            ),
            const SizedBox(height: 12),
            // Results
            Expanded(
              child: grounds.when(
                loading: () => const ListShimmer(count: 4),
                error: (e, _) => ErrorView(
                  message:
                      apiErrorMessage(e, fallback: 'Could not load grounds'),
                  onRetry: () => ref.invalidate(groundsProvider(filter)),
                ),
                data: (all) {
                  // Price, rating and amenities have no server-side support,
                  // so they are applied here over the page that came back.
                  final list = _filters.apply(all);

                  // One batched weather request for what is on screen, rather
                  // than a call per card. Published after the frame so it does
                  // not mutate a provider mid-build.
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) publishWeatherPoints(ref, list);
                  });
                  final weather = ref
                          .watch(groundWeatherProvider(
                              list.map((g) => g.id).toList()))
                          .valueOrNull ??
                      const {};

                  if (list.isEmpty) {
                    // Distinguish "your filters hid everything" from "there is
                    // nothing here" — only the first has an obvious fix.
                    final hiddenByFilters = all.isNotEmpty;
                    return _Empty(
                      message: hiddenByFilters
                          ? 'No grounds match these filters.'
                          : 'No grounds found.\nTry a different search.',
                      actionLabel: hiddenByFilters ? 'Clear filters' : null,
                      onAction: hiddenByFilters
                          ? () => setState(() => _filters = VenueFilters.none)
                          : null,
                    );
                  }

                  return RefreshIndicator(
                    color: AppColors.primary,
                    backgroundColor: colors.card,
                    onRefresh: () async {
                      ref.invalidate(groundsProvider(filter));
                      await ref.read(groundsProvider(filter).future);
                    },
                    child: ListView.builder(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                      physics: const AlwaysScrollableScrollPhysics(),
                      itemCount: list.length,
                      itemBuilder: (_, i) => VenueCard(
                        ground: list[i],
                        weather: weather[list[i].id],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterPill extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterPill(
      {required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 18),
        alignment: Alignment.center,
        constraints: const BoxConstraints(minHeight: 44),
        decoration: BoxDecoration(
          color: selected ? AppColors.accent : colors.input,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: selected ? AppColors.accent : colors.border,
          ),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: selected ? AppColors.onPrimary : colors.textSecondary,
          ),
        ),
      ),
    );
  }
}

/// Empty state with an optional way out of it.
class _Empty extends StatelessWidget {
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _Empty({required this.message, this.actionLabel, this.onAction});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off_rounded, size: 44, color: colors.textSecondary),
            const SizedBox(height: 14),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: colors.textSecondary, fontSize: 15, height: 1.5),
            ),
            if (actionLabel != null) ...[
              const SizedBox(height: 18),
              SizedBox(
                height: 44,
                child: OutlinedButton(
                  onPressed: onAction,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.primary),
                  ),
                  child: Text(actionLabel!),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
