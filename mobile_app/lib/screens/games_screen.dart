import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/api_error.dart';
import '../core/app_colors.dart';
import '../models/game_filters.dart';
import '../models/game_model.dart';
import '../providers/games_provider.dart';
import '../providers/grounds_provider.dart';
import '../widgets/animated_list_item.dart';
import '../widgets/error_view.dart';
import '../widgets/game_card.dart';
import '../widgets/game_filter_sheet.dart';
import '../widgets/shimmer_loader.dart';
import '../widgets/sport_chip.dart';
import '../widgets/sport_glyph.dart';

/// Games — Discover, and the games I'm already in.
///
/// This is the screen that separates Playsher from a booking app: a player with
/// nobody to play with browses games other players have opened on their own
/// bookings and takes a seat. So Discover is built for scanning — sport, when,
/// where, how many seats are left, what it costs — with the filters a player
/// actually uses (sport, day, level) reachable without leaving the feed.
class GamesScreen extends ConsumerStatefulWidget {
  const GamesScreen({super.key});

  @override
  ConsumerState<GamesScreen> createState() => _GamesScreenState();
}

class _GamesScreenState extends ConsumerState<GamesScreen> {
  int _tab = 0;
  MyGamesScope _scope = MyGamesScope.upcoming;

  GameFilters _filters = const GameFilters();

  late final TextEditingController _search;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _search = TextEditingController();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  /// Each keystroke would otherwise be a new provider key and a fresh
  /// `GET /games`. Settle first.
  void _onQueryChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      if (value.trim() == _filters.search.trim()) return;
      setState(() => _filters = _filters.copyWith(search: value, page: 1));
    });
  }

  Future<void> _openFilters() async {
    final result = await GameFilterSheet.show(context, initial: _filters);
    if (!mounted || result == null) return;
    setState(() => _filters = result);
  }

  void _clearFilters() {
    _debounce?.cancel();
    _search.clear();
    setState(() => _filters = const GameFilters());
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final filters = _filters;

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _Header(onHost: () => context.push('/host-game')),
            const SizedBox(height: 14),
            _Segmented(
              index: _tab,
              labels: const ['Discover', 'My games'],
              onChanged: (i) => setState(() => _tab = i),
            ),
            const SizedBox(height: 12),
            Expanded(
              // IndexedStack, not a rebuild: switching tabs keeps each list's
              // scroll position, and the two are separate scrollables rather
              // than one nested in the other. Both children build, so "My
              // games" is fetched once when this tab is first opened — a
              // deliberate prefetch, since the shell keeps this branch alive
              // for the rest of the session rather than rebuilding it.
              child: IndexedStack(
                index: _tab,
                children: [
                  _DiscoverTab(
                    filters: filters,
                    searchController: _search,
                    onQueryChanged: _onQueryChanged,
                    onOpenFilters: _openFilters,
                    onClearFilters: _clearFilters,
                    onSportChanged: (id) => setState(() => _filters = id == null
                        ? _filters.copyWith(clearSport: true, page: 1)
                        : _filters.copyWith(sportId: id, page: 1)),
                    onWhenChanged: (w) =>
                        setState(() => _filters = _filters.copyWith(when: w, page: 1)),
                  ),
                  _MyGamesTab(
                    scope: _scope,
                    onScopeChanged: (s) => setState(() => _scope = s),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Header ────────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  final VoidCallback onHost;

  const _Header({required this.onHost});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Games',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.6,
                    color: colors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Join a game near you, or open your own booking to players.',
                  style: TextStyle(fontSize: 12.5, color: colors.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // The one thing that makes the feed exist. A labelled pill rather
          // than a bare `+`: "host a game" is not an obvious icon.
          Semantics(
            button: true,
            label: 'Host a game',
            child: GestureDetector(
              onTap: onHost,
              behavior: HitTestBehavior.opaque,
              child: Container(
                height: 44,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(22),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.add_rounded,
                        size: 18, color: AppColors.onPrimary),
                    SizedBox(width: 5),
                    Text(
                      'Host',
                      style: TextStyle(
                        color: AppColors.onPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A two- or three-way switch. 44px tall, and the selected side is named as
/// selected to a screen reader rather than merely filled in.
class _Segmented extends StatelessWidget {
  final int index;
  final List<String> labels;
  final ValueChanged<int> onChanged;

  const _Segmented({
    required this.index,
    required this.labels,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        height: 46,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: colors.input,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            for (var i = 0; i < labels.length; i++)
              Expanded(
                child: Semantics(
                  button: true,
                  selected: i == index,
                  child: GestureDetector(
                    onTap: () => onChanged(i),
                    behavior: HitTestBehavior.opaque,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: i == index ? colors.card : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        labels[i],
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight:
                              i == index ? FontWeight.w800 : FontWeight.w600,
                          color: i == index
                              ? colors.textPrimary
                              : colors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Discover ──────────────────────────────────────────────────────────────────

class _DiscoverTab extends ConsumerWidget {
  final GameFilters filters;
  final TextEditingController searchController;
  final ValueChanged<String> onQueryChanged;
  final VoidCallback onOpenFilters;
  final VoidCallback onClearFilters;
  final ValueChanged<int?> onSportChanged;
  final ValueChanged<GameWhen> onWhenChanged;

  const _DiscoverTab({
    required this.filters,
    required this.searchController,
    required this.onQueryChanged,
    required this.onOpenFilters,
    required this.onClearFilters,
    required this.onSportChanged,
    required this.onWhenChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final games = ref.watch(gamesProvider(filters));
    final busy = ref.watch(gameActionsProvider);

    return RefreshIndicator(
      color: AppColors.primary,
      backgroundColor: colors.card,
      onRefresh: () async => ref.invalidate(gamesProvider(filters)),
      child: CustomScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        slivers: [
          SliverToBoxAdapter(
            child: _SearchRow(
              controller: searchController,
              onChanged: onQueryChanged,
              activeCount: filters.activeCount,
              onOpenFilters: onOpenFilters,
            ),
          ),
          SliverToBoxAdapter(
            child: _WhenStrip(
              selected: filters.when,
              onChanged: onWhenChanged,
            ),
          ),
          SliverToBoxAdapter(
            child: _SportStrip(
              selectedId: filters.sportId,
              onChanged: onSportChanged,
            ),
          ),
          SliverToBoxAdapter(
            child: _ResultBar(
              filters: filters,
              count: games.valueOrNull?.length,
              onClear: onClearFilters,
            ),
          ),
          games.when(
            data: (list) => list.isEmpty
                ? SliverFillRemaining(
                    hasScrollBody: false,
                    child: _NoGames(
                      filtered: !filters.isClean,
                      onClear: onClearFilters,
                    ),
                  )
                : SliverList.builder(
                    itemCount: list.length,
                    itemBuilder: (context, i) => AnimatedListItem(
                      index: i,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                        child: _FeedCard(game: list[i], busy: busy),
                      ),
                    ),
                  ),
            loading: () => const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    GameCardShimmer(),
                    GameCardShimmer(),
                    GameCardShimmer(),
                  ],
                ),
              ),
            ),
            error: (e, _) => SliverFillRemaining(
              hasScrollBody: false,
              child: ErrorView(
                message: apiErrorMessage(e, fallback: 'Could not load games'),
                onRetry: () => ref.invalidate(gamesProvider(filters)),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: SizedBox(height: 24 + MediaQuery.of(context).padding.bottom),
          ),
        ],
      ),
    );
  }
}

/// A feed card wired to the join action.
///
/// Joining happens in place: the seat is what the player came for, and pushing
/// them into the detail screen to press a second button is a step that earns
/// nothing. Errors surface as a snackbar and the feed refreshes, so a game that
/// filled up between the render and the tap corrects itself.
class _FeedCard extends ConsumerWidget {
  final GameModel game;
  final GameActionState busy;

  const _FeedCard({required this.game, required this.busy});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GameCard(
      game: game,
      isJoining: busy.isBusyFor(game.id),
      onTap: () => context.push('/games/${game.id}'),
      onJoin: game.canJoin
          ? () => _join(context, ref)
          : null,
    );
  }

  Future<void> _join(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    // Guarded twice: the button is already disabled while any action is in
    // flight, and the notifier refuses a second call.
    if (ref.read(gameActionsProvider).isBusy) return;
    try {
      await ref.read(gameActionsProvider.notifier).join(game.id);
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          content: Text("You're in — ${game.displayTitle}"),
          action: SnackBarAction(
            label: 'View',
            onPressed: () => context.push('/games/${game.id}'),
          ),
        ));
    } catch (e) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          content: Text(apiErrorMessage(e,
              fallback: 'Could not join this game. Please try again.')),
          backgroundColor: AppColors.error,
        ));
    }
  }
}

class _SearchRow extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final int activeCount;
  final VoidCallback onOpenFilters;

  const _SearchRow({
    required this.controller,
    required this.onChanged,
    required this.activeCount,
    required this.onOpenFilters,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                isDense: true,
                hintText: 'Search games, venues, sports',
                prefixIcon: Icon(Icons.search_rounded,
                    size: 20, color: colors.textSecondary),
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Semantics(
            button: true,
            label: activeCount > 0
                ? 'Filters, $activeCount active'
                : 'Filters',
            child: GestureDetector(
              onTap: onOpenFilters,
              behavior: HitTestBehavior.opaque,
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: activeCount > 0
                      ? AppColors.primary.withValues(alpha: 0.12)
                      : colors.input,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color:
                        activeCount > 0 ? AppColors.primary : colors.border,
                  ),
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Icon(
                      Icons.tune_rounded,
                      size: 20,
                      color: activeCount > 0
                          ? colors.brandText
                          : colors.textSecondary,
                    ),
                    if (activeCount > 0)
                      Positioned(
                        top: 6,
                        right: 6,
                        child: Container(
                          width: 16,
                          height: 16,
                          decoration: const BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            '$activeCount',
                            style: const TextStyle(
                              color: AppColors.onPrimary,
                              fontSize: 9.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The day chips — the filter a player reaches for first.
class _WhenStrip extends StatelessWidget {
  final GameWhen selected;
  final ValueChanged<GameWhen> onChanged;

  const _WhenStrip({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: GameWhen.values.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final w = GameWhen.values[i];
          return _Pill(
            label: w.label,
            selected: w == selected,
            onTap: () => onChanged(w),
          );
        },
      ),
    );
  }
}

/// The sport strip, from the same `sportsProvider` Explore uses.
class _SportStrip extends ConsumerWidget {
  final int? selectedId;
  final ValueChanged<int?> onChanged;

  const _SportStrip({required this.selectedId, required this.onChanged});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sports = ref.watch(sportsProvider);

    return sports.when(
      // The strip is a filter, not content: while it loads, or if it fails,
      // the feed below is still perfectly usable unfiltered, so neither state
      // gets an error block of its own.
      loading: () => const SizedBox(
        height: 56,
        child: Padding(
          padding: EdgeInsets.fromLTRB(20, 12, 20, 0),
          child: CategoryStripShimmer(),
        ),
      ),
      error: (_, __) => const SizedBox.shrink(),
      data: (list) {
        if (list.isEmpty) return const SizedBox.shrink();
        return SizedBox(
          height: 56,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            itemCount: list.length + 1,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (_, i) {
              if (i == 0) {
                return SportChip(
                  label: 'All sports',
                  selected: selectedId == null,
                  onTap: () => onChanged(null),
                );
              }
              final sport = list[i - 1];
              return SportChip(
                label: sport.name,
                // The API serves an icon for most sports; the emoji is the
                // fallback for the ones seeded without one.
                emoji: SportGlyph.emojiFor(sport.name),
                imageUrl: sport.image,
                selected: selectedId == sport.id,
                onTap: () =>
                    onChanged(selectedId == sport.id ? null : sport.id),
              );
            },
          ),
        );
      },
    );
  }
}

/// How many games matched, and a way out of the filters that narrowed it.
class _ResultBar extends StatelessWidget {
  final GameFilters filters;
  final int? count;
  final VoidCallback onClear;

  const _ResultBar({
    required this.filters,
    required this.count,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final n = count;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      child: Row(
        children: [
          Expanded(
            child: Text(
              n == null
                  ? 'Finding games…'
                  : '$n ${n == 1 ? 'game' : 'games'}'
                      '${filters.when == GameWhen.anytime ? '' : ' ${filters.when.label.toLowerCase()}'}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: colors.textPrimary,
              ),
            ),
          ),
          if (!filters.isClean)
            Semantics(
              button: true,
              label: 'Clear filters',
              child: GestureDetector(
                onTap: onClear,
                behavior: HitTestBehavior.opaque,
                child: Container(
                  height: 44,
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(left: 16),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.close_rounded,
                          size: 15, color: colors.brandText),
                      const SizedBox(width: 4),
                      Text(
                        'Clear',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: colors.brandText,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── My games ──────────────────────────────────────────────────────────────────

class _MyGamesTab extends ConsumerWidget {
  final MyGamesScope scope;
  final ValueChanged<MyGamesScope> onScopeChanged;

  const _MyGamesTab({required this.scope, required this.onScopeChanged});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final games = ref.watch(myGamesProvider(scope));

    return RefreshIndicator(
      color: AppColors.primary,
      backgroundColor: colors.card,
      onRefresh: () async => ref.invalidate(myGamesProvider(scope)),
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: _Segmented(
                index: MyGamesScope.values.indexOf(scope),
                labels: const ['Upcoming', 'Past'],
                onChanged: (i) => onScopeChanged(MyGamesScope.values[i]),
              ),
            ),
          ),
          games.when(
            data: (list) => list.isEmpty
                ? SliverFillRemaining(
                    hasScrollBody: false,
                    child: _NoMyGames(scope: scope),
                  )
                : SliverList.builder(
                    itemCount: list.length,
                    itemBuilder: (context, i) => AnimatedListItem(
                      index: i,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                        child: _MyGameTile(game: list[i]),
                      ),
                    ),
                  ),
            loading: () => const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [GameCardShimmer(), GameCardShimmer()],
                ),
              ),
            ),
            error: (e, _) => SliverFillRemaining(
              hasScrollBody: false,
              child: ErrorView(
                message:
                    apiErrorMessage(e, fallback: 'Could not load your games'),
                onRetry: () => ref.invalidate(myGamesProvider(scope)),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: SizedBox(height: 24 + MediaQuery.of(context).padding.bottom),
          ),
        ],
      ),
    );
  }
}

/// A game I'm in, with the badge that says which side of it I'm on.
class _MyGameTile extends StatelessWidget {
  final GameModel game;

  const _MyGameTile({required this.game});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final hosting = game.relation == 'hosting' || game.isHost;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 6, left: 2),
          child: Row(
            children: [
              Icon(
                hosting
                    ? Icons.workspace_premium_rounded
                    : Icons.sports_handball_rounded,
                size: 14,
                color: hosting ? colors.brandText : colors.successText,
              ),
              const SizedBox(width: 5),
              Text(
                hosting ? 'You are hosting' : 'You are playing',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.2,
                  color: hosting ? colors.brandText : colors.successText,
                ),
              ),
            ],
          ),
        ),
        GameCard(
          game: game,
          onTap: () => context.push('/games/${game.id}'),
        ),
      ],
    );
  }
}

// ── Empty states ──────────────────────────────────────────────────────────────

class _NoGames extends StatelessWidget {
  final bool filtered;
  final VoidCallback onClear;

  const _NoGames({required this.filtered, required this.onClear});

  @override
  Widget build(BuildContext context) {
    return _Empty(
      icon: filtered ? Icons.search_off_rounded : Icons.sports_soccer_rounded,
      title: filtered ? 'No games match that' : 'No open games right now',
      body: filtered
          ? 'Try a different day or sport — or clear the filters to see everything.'
          : 'Be the one who starts it. Book a slot, open it to players, and '
              'split the cost.',
      actionLabel: filtered ? 'Clear filters' : 'Host a game',
      onAction: filtered ? onClear : () => context.push('/host-game'),
    );
  }
}

class _NoMyGames extends StatelessWidget {
  final MyGamesScope scope;

  const _NoMyGames({required this.scope});

  @override
  Widget build(BuildContext context) {
    final past = scope == MyGamesScope.past;
    return _Empty(
      icon: past ? Icons.history_rounded : Icons.event_available_rounded,
      title: past ? 'Nothing played yet' : 'No games lined up',
      body: past
          ? 'Games you have played will show up here.'
          : 'Join one from Discover, or open a game on a slot you have booked.',
      actionLabel: past ? null : 'Host a game',
      onAction: past ? null : () => context.push('/host-game'),
    );
  }
}

class _Empty extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _Empty({
    required this.icon,
    required this.title,
    required this.body,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Center(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(32, 12, 32, 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                color: colors.input,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 34, color: colors.textSecondary),
            ),
            const SizedBox(height: 18),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: colors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              body,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13.5,
                height: 1.45,
                color: colors.textSecondary,
              ),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 20),
              SizedBox(
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: onAction,
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: Text(actionLabel!),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(190, 52),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// A small selectable pill, used by the day strip.
class _Pill extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _Pill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Semantics(
      button: true,
      selected: selected,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 15),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? AppColors.primary : colors.input,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: selected ? AppColors.primary : colors.border,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              color: selected ? AppColors.onPrimary : colors.textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}
