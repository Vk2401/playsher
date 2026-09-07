import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/api_client.dart';
import '../core/api_error.dart';
import '../core/app_colors.dart';
import '../models/player_model.dart';
import '../providers/games_provider.dart';
import '../providers/players_provider.dart';
import 'error_view.dart';
import 'player_tile.dart';

/// Pick the players to invite to a game.
///
/// Opens on the people you have actually played with, because those are the
/// names you can offer before anybody has typed anything — and they are the
/// ones most likely to be invited again. Search is the fallback for everyone
/// else: a username, a display name, or a full mobile number.
///
/// A number has to be complete. A partial one matches nothing, by design on the
/// server — that is what stops the search being walked to harvest accounts —
/// and the empty state says so rather than leaving the player wondering why
/// their friend's number "doesn't work".
class InvitePlayersSheet extends ConsumerStatefulWidget {
  final int gameId;
  final String gameName;

  /// Already in the game or already asked — shown as such, never invitable
  /// twice. The server drops these anyway; the sheet just does not pretend.
  final Set<int> alreadyInvolved;

  const InvitePlayersSheet({
    super.key,
    required this.gameId,
    required this.gameName,
    this.alreadyInvolved = const {},
  });

  static Future<int?> show(
    BuildContext context, {
    required int gameId,
    required String gameName,
    Set<int> alreadyInvolved = const {},
  }) {
    return showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => InvitePlayersSheet(
        gameId: gameId,
        gameName: gameName,
        alreadyInvolved: alreadyInvolved,
      ),
    );
  }

  @override
  ConsumerState<InvitePlayersSheet> createState() => _InvitePlayersSheetState();
}

class _InvitePlayersSheetState extends ConsumerState<InvitePlayersSheet> {
  final _search = TextEditingController();
  final _selected = <int, PlayerCard>{};

  String _query = '';
  Timer? _debounce;
  bool _sending = false;

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _onQueryChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      if (!mounted || value.trim() == _query) return;
      setState(() => _query = value.trim());
    });
  }

  void _toggle(PlayerCard player) {
    setState(() {
      if (_selected.containsKey(player.id)) {
        _selected.remove(player.id);
      } else {
        _selected[player.id] = player;
      }
    });
  }

  Future<void> _send() async {
    if (_sending || _selected.isEmpty) return;
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    setState(() => _sending = true);
    try {
      final res =
          await ApiClient.inviteToGame(widget.gameId, _selected.keys.toList());
      final invited =
          (res['data'] as Map<String, dynamic>?)?['invited'] as int? ??
              _selected.length;

      // The game's own screen shows the invitees, so it has to refetch.
      ref.invalidate(gameDetailProvider(widget.gameId));

      if (!mounted) return;
      navigator.pop(invited);
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          content: Text(res['message'] as String? ??
              '$invited invited to ${widget.gameName}.'),
        ));
    } catch (e) {
      if (!mounted) return;
      setState(() => _sending = false);
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          content: Text(apiErrorMessage(e,
              fallback: 'Could not send those invitations. Please try again.')),
          backgroundColor: AppColors.error,
        ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final searching = _query.length >= 2;
    final results = searching
        ? ref.watch(playerSearchProvider(_query))
        : ref.watch(teammatesProvider);

    return Padding(
      // Lifts the sheet above the keyboard while the search field has focus.
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        clipBehavior: Clip.antiAlias,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.85,
        ),
        decoration: BoxDecoration(
          color: colors.background,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(top: 10, bottom: 12),
                decoration: BoxDecoration(
                  color: colors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Invite players',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: colors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'to ${widget.gameName}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style:
                          TextStyle(fontSize: 13, color: colors.textSecondary),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _search,
                      onChanged: _onQueryChanged,
                      textInputAction: TextInputAction.search,
                      decoration: InputDecoration(
                        isDense: true,
                        hintText: 'Username, name or full mobile number',
                        prefixIcon: Icon(Icons.search_rounded,
                            size: 20, color: colors.textSecondary),
                        contentPadding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ],
                ),
              ),
              if (_selected.isNotEmpty) _SelectedStrip(
                selected: _selected.values.toList(),
                onRemove: _toggle,
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    searching ? 'Results' : 'People you play with',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.3,
                      color: colors.textSecondary,
                    ),
                  ),
                ),
              ),
              Flexible(
                child: results.when(
                  loading: () => const Padding(
                    padding: EdgeInsets.symmetric(vertical: 36),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  error: (e, _) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: ErrorView(
                      message: apiErrorMessage(e,
                          fallback: 'Could not load players'),
                      onRetry: () => ref.invalidate(searching
                          ? playerSearchProvider(_query)
                          : teammatesProvider),
                    ),
                  ),
                  data: (players) {
                    if (players.isEmpty) {
                      return _Empty(searching: searching, query: _query);
                    }
                    return ListView.builder(
                      shrinkWrap: true,
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                      itemCount: players.length,
                      itemBuilder: (_, i) {
                        final p = players[i];
                        final involved = widget.alreadyInvolved.contains(p.id);
                        final picked = _selected.containsKey(p.id);
                        return PlayerTile(
                          player: p,
                          onTap: involved || _sending ? null : () => _toggle(p),
                          trailing: involved
                              ? _InGamePill()
                              : _PickBox(selected: picked),
                        );
                      },
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                child: SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    // The in-flight flag is the double-submit guard; an empty
                    // selection has nothing to send.
                    onPressed:
                        _sending || _selected.isEmpty ? null : _send,
                    child: _sending
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: AppColors.onPrimary),
                          )
                        : Text(_selected.isEmpty
                            ? 'Pick players to invite'
                            : 'Invite ${_selected.length}'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The people picked so far, removable — so a long list does not lose track of
/// who is already in the basket.
class _SelectedStrip extends StatelessWidget {
  final List<PlayerCard> selected;
  final void Function(PlayerCard) onRemove;

  const _SelectedStrip({required this.selected, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: selected.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final p = selected[i];
          return Semantics(
            button: true,
            label: 'Remove ${p.name}',
            child: GestureDetector(
              onTap: () => onRemove(p),
              behavior: HitTestBehavior.opaque,
              child: Container(
                height: 44,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.35)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    PlayerAvatar(
                      name: p.name,
                      avatar: p.avatar,
                      initials: p.initials,
                      size: 24,
                    ),
                    const SizedBox(width: 7),
                    Text(
                      p.name.split(' ').first,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: colors.textPrimary,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Icon(Icons.close_rounded, size: 15, color: colors.textSecondary),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _PickBox extends StatelessWidget {
  final bool selected;

  const _PickBox({required this.selected});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return SizedBox(
      width: 44,
      height: 44,
      child: Center(
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: selected ? AppColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(7),
            border: Border.all(
              color: selected ? AppColors.primary : colors.border,
              width: 1.5,
            ),
          ),
          child: selected
              ? const Icon(Icons.check_rounded,
                  size: 16, color: AppColors.onPrimary)
              : null,
        ),
      ),
    );
  }
}

class _InGamePill extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: colors.input,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        'Already in',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: colors.textSecondary,
        ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  final bool searching;
  final String query;

  const _Empty({required this.searching, required this.query});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    // A number that is nearly complete matches nothing — say why, rather than
    // letting it read as "your friend isn't on Playsher".
    final partialNumber =
        searching && RegExp(r'^\+?\d[\d\s-]*$').hasMatch(query) &&
            query.replaceAll(RegExp(r'\D'), '').length < 10;

    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 24, 32, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            searching ? Icons.person_search_rounded : Icons.groups_2_rounded,
            size: 44,
            color: colors.textSecondary,
          ),
          const SizedBox(height: 14),
          Text(
            !searching
                ? 'No teammates yet'
                : partialNumber
                    ? 'Enter the full 10-digit number'
                    : 'Nobody matched that',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: colors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            !searching
                ? 'Once you have played a game together, your teammates show up '
                    'here. Until then, search for them by username or number.'
                : partialNumber
                    ? 'A mobile number has to be complete to match — a partial '
                        'one finds nobody.'
                    : 'Check the username, or try their full mobile number.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              height: 1.45,
              color: colors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
