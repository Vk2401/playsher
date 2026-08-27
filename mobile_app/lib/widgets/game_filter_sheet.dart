import 'package:flutter/material.dart';
import '../core/app_colors.dart';
import '../models/game_filters.dart';

/// The Discover feed's filter sheet.
///
/// Only the choices that do not fit on the feed itself live here: the sport
/// strip and the date chips are already on screen, so putting them in the sheet
/// too would give a player two places to change one thing and no way to tell
/// which won.
///
/// Same modal-sheet pattern as [VenueFilterSheet] — the feed stays visible
/// behind it, and it dismisses by swipe or scrim.
class GameFilterSheet extends StatefulWidget {
  /// What is already applied, so reopening does not silently reset the choices
  /// the player made a moment ago.
  final GameFilters initial;

  const GameFilterSheet({super.key, required this.initial});

  static Future<GameFilters?> show(
    BuildContext context, {
    required GameFilters initial,
  }) {
    return showModalBottomSheet<GameFilters>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => GameFilterSheet(initial: initial),
    );
  }

  @override
  State<GameFilterSheet> createState() => _GameFilterSheetState();
}

class _GameFilterSheetState extends State<GameFilterSheet> {
  late GameWhen _when;
  late GameLevel? _level;
  late bool _onlyOpen;
  late GameSort _sort;

  @override
  void initState() {
    super.initState();
    _when = widget.initial.when;
    _level = widget.initial.level;
    _onlyOpen = widget.initial.onlyOpen;
    _sort = widget.initial.sort;
  }

  /// Built fresh on apply rather than mutated, so a dismissed sheet cannot leak
  /// half-made changes back to the feed.
  GameFilters get _result => widget.initial.copyWith(
        when: _when,
        level: _level,
        clearLevel: _level == null,
        onlyOpen: _onlyOpen,
        sort: _sort,
        page: 1,
      );

  void _reset() => setState(() {
        _when = GameWhen.anytime;
        _level = null;
        _onlyOpen = false;
        _sort = GameSort.soonest;
      });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final active = _result.activeCount;

    return Container(
      clipBehavior: Clip.antiAlias,
      // Capped rather than left to grow: an uncapped `isScrollControlled`
      // sheet whose content is tall enough fills the screen, and a sheet with
      // no scrim above it cannot be dismissed by tapping outside — it reads as
      // a page the player is stuck on.
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
              margin: const EdgeInsets.only(top: 10, bottom: 10),
              decoration: BoxDecoration(
                color: colors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 12, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Refine games',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: colors.textPrimary,
                          ),
                        ),
                        Text(
                          active > 0 ? '$active active' : 'Showing everything',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: active > 0
                                ? colors.brandText
                                : colors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Semantics(
                    button: true,
                    label: 'Reset filters',
                    child: GestureDetector(
                      onTap: _reset,
                      behavior: HitTestBehavior.opaque,
                      child: Container(
                        height: 44,
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.refresh_rounded,
                                size: 16, color: colors.brandText),
                            const SizedBox(width: 4),
                            Text(
                              'Reset',
                              style: TextStyle(
                                fontSize: 14,
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
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                children: [
                  _Group(
                    title: 'When',
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: GameWhen.values
                          .map((w) => _Choice(
                                label: w.label,
                                selected: _when == w,
                                onTap: () => setState(() => _when = w),
                              ))
                          .toList(),
                    ),
                  ),
                  _Group(
                    title: 'Skill level',
                    subtitle: 'Games pitched at players like you',
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _Choice(
                          label: 'Any level',
                          selected: _level == null,
                          onTap: () => setState(() => _level = null),
                        ),
                        ...GameLevel.values.map((l) => _Choice(
                              label: l.label,
                              selected: _level == l,
                              onTap: () => setState(() => _level = l),
                            )),
                      ],
                    ),
                  ),
                  _Group(
                    title: 'Sort by',
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: GameSort.values
                          .map((s) => _Choice(
                                label: s.label,
                                selected: _sort == s,
                                onTap: () => setState(() => _sort = s),
                              ))
                          .toList(),
                    ),
                  ),
                  _Toggle(
                    title: 'Only games I can join',
                    subtitle: 'Hides games that are full or already started',
                    value: _onlyOpen,
                    onChanged: (v) => setState(() => _onlyOpen = v),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(_result),
                  child: const Text('Show games'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Group extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget child;

  const _Group({required this.title, this.subtitle, required this.child});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.only(bottom: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: colors.textPrimary,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(
              subtitle!,
              style: TextStyle(fontSize: 12, color: colors.textSecondary),
            ),
          ],
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

/// A selectable pill. 44px tall so it is hittable, whatever the label's length.
class _Choice extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _Choice({
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
          padding: const EdgeInsets.symmetric(horizontal: 16),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected
                ? AppColors.primary.withValues(alpha: 0.12)
                : colors.card,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: selected ? AppColors.primary : colors.border,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Selection is not signalled by the fill alone.
              if (selected) ...[
                Icon(Icons.check_rounded, size: 15, color: colors.brandText),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected ? colors.brandText : colors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Toggle extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _Toggle({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: colors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 12, color: colors.textSecondary),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: AppColors.primary,
          ),
        ],
      ),
    );
  }
}
