import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/app_colors.dart';
import '../providers/amenities_provider.dart';
import '../providers/grounds_provider.dart';

class VenueFilterScreen extends ConsumerStatefulWidget {
  const VenueFilterScreen({super.key});

  @override
  ConsumerState<VenueFilterScreen> createState() => _VenueFilterScreenState();
}

class _VenueFilterScreenState extends ConsumerState<VenueFilterScreen> {
  final Set<int> _selectedSportIds = {};
  RangeValues _priceRange = const RangeValues(0, 5000);
  int? _distanceKm; // null = Any
  double? _minRating; // null = none
  final Set<int> _selectedAmenityIds = {};

  static const _distances = [2, 5, 10, 20];
  static const _ratings = [3.0, 3.5, 4.0, 4.5, 5.0];

  static const _sportEmojis = {
    'cricket': '\u{1F3CF}',
    'football': '\u26BD',
    'soccer': '\u26BD',
    'basketball': '\u{1F3C0}',
    'volleyball': '\u{1F3D0}',
    'badminton': '\u{1F3F8}',
    'tennis': '\u{1F3BE}',
    'hockey': '\u{1F3D1}',
    'swimming': '\u{1F3CA}',
    'kabaddi': '\u{1F93C}',
    'gym': '\u{1F4AA}',
  };

  static const _amenityIcons = {
    'parking': Icons.local_parking_rounded,
    'changing room': Icons.checkroom_rounded,
    'washroom': Icons.wc_rounded,
    'water': Icons.water_drop_rounded,
    'floodlights': Icons.light_rounded,
    'first aid': Icons.medical_services_rounded,
    'cafe': Icons.local_cafe_rounded,
    'wifi': Icons.wifi_rounded,
    'locker': Icons.lock_rounded,
  };

  String _emojiFor(String name) {
    final lower = name.toLowerCase();
    for (final e in _sportEmojis.entries) {
      if (lower.contains(e.key)) return e.value;
    }
    return '\u{1F3C6}';
  }

  IconData _amenityIcon(String name) {
    final lower = name.toLowerCase();
    for (final e in _amenityIcons.entries) {
      if (lower.contains(e.key)) return e.value;
    }
    return Icons.check_circle_outline_rounded;
  }

  int get _activeCount {
    int count = 0;
    if (_selectedSportIds.isNotEmpty) count++;
    if (_priceRange.start > 0 || _priceRange.end < 5000) count++;
    if (_distanceKm != null) count++;
    if (_minRating != null) count++;
    if (_selectedAmenityIds.isNotEmpty) count++;
    return count;
  }

  void _reset() {
    setState(() {
      _selectedSportIds.clear();
      _priceRange = const RangeValues(0, 5000);
      _distanceKm = null;
      _minRating = null;
      _selectedAmenityIds.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final sportsAsync = ref.watch(sportsProvider);
    final amenitiesAsync = ref.watch(amenitiesProvider);
    final active = _activeCount;

    return Scaffold(
      backgroundColor: colors.background,
      body: Column(
        children: [
          // ── Custom App Bar ─────────────────────────────────────────────
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => context.pop(),
                    icon: Icon(Icons.arrow_back_rounded,
                        color: colors.textPrimary, size: 22),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Filters',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: colors.textPrimary,
                          ),
                        ),
                        if (active > 0)
                          Text(
                            '$active active',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.accent,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: _reset,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.close_rounded,
                            size: 16, color: colors.textSecondary),
                        const SizedBox(width: 4),
                        Text(
                          'Reset',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: colors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
              ),
            ),
          ),

          // ── Body ───────────────────────────────────────────────────────
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              children: [
                // ── SPORTS ───────────────────────────────────────────────
                const _SectionLabel(icon: null, label: 'SPORTS'),
                const SizedBox(height: 10),
                sportsAsync.when(
                  loading: () => const SizedBox(
                    height: 40,
                    child: Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: AppColors.primary),
                      ),
                    ),
                  ),
                  error: (_, __) => Text(
                    'Could not load sports',
                    style: TextStyle(color: colors.textSecondary, fontSize: 13),
                  ),
                  data: (sports) => Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: sports.map((s) {
                      final sel = _selectedSportIds.contains(s.id);
                      return _ChipButton(
                        label: '${_emojiFor(s.name)}  ${s.name}',
                        selected: sel,
                        onTap: () => setState(() {
                          sel
                              ? _selectedSportIds.remove(s.id)
                              : _selectedSportIds.add(s.id);
                        }),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 28),

                // ── PRICE RANGE ──────────────────────────────────────────
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const _SectionLabel(icon: null, label: 'PRICE RANGE'),
                    Text(
                      '\u20b9${_priceRange.start.toInt()} - \u20b9${_priceRange.end.toInt()}',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.accent,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                SliderTheme(
                  data: SliderThemeData(
                    activeTrackColor: AppColors.primary,
                    inactiveTrackColor: colors.border,
                    thumbColor: AppColors.accent,
                    overlayColor: AppColors.accent.withValues(alpha: 0.15),
                    rangeThumbShape: const RoundRangeSliderThumbShape(
                        enabledThumbRadius: 10),
                    trackHeight: 4,
                  ),
                  child: RangeSlider(
                    values: _priceRange,
                    min: 0,
                    max: 5000,
                    divisions: 50,
                    onChanged: (v) => setState(() => _priceRange = v),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('\u20b90',
                          style: TextStyle(
                              fontSize: 11, color: colors.textSecondary)),
                      Text('\u20b95,000',
                          style: TextStyle(
                              fontSize: 11, color: colors.textSecondary)),
                    ],
                  ),
                ),
                const SizedBox(height: 28),

                // ── DISTANCE ─────────────────────────────────────────────
                const _SectionLabel(
                    icon: Icons.location_on_outlined, label: 'DISTANCE'),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ..._distances.map((d) {
                      final sel = _distanceKm == d;
                      return _ChipButton(
                        label: '$d km',
                        selected: sel,
                        onTap: () =>
                            setState(() => _distanceKm = sel ? null : d),
                      );
                    }),
                    _ChipButton(
                      label: 'Any',
                      selected: _distanceKm == null,
                      onTap: () => setState(() => _distanceKm = null),
                    ),
                  ],
                ),
                const SizedBox(height: 28),

                // ── MINIMUM RATING ───────────────────────────────────────
                const _SectionLabel(
                    icon: Icons.star_rounded, label: 'MINIMUM RATING'),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _ratings.map((r) {
                    final sel = _minRating == r;
                    final label = r == r.toInt().toDouble()
                        ? '${r.toInt()}+'
                        : '${r.toString()}+';
                    return _ChipButton(
                      label: label,
                      selected: sel,
                      onTap: () => setState(() => _minRating = sel ? null : r),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 28),

                // ── AMENITIES ────────────────────────────────────────────
                const _SectionLabel(icon: null, label: 'AMENITIES'),
                const SizedBox(height: 10),
                amenitiesAsync.when(
                  loading: () => const SizedBox(
                    height: 40,
                    child: Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: AppColors.primary),
                      ),
                    ),
                  ),
                  error: (_, __) => Text(
                    'Could not load amenities',
                    style: TextStyle(color: colors.textSecondary, fontSize: 13),
                  ),
                  data: (amenities) => Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: amenities.map((a) {
                      final sel = _selectedAmenityIds.contains(a.id);
                      return _AmenityChip(
                        icon: _amenityIcon(a.name),
                        label: a.name,
                        selected: sel,
                        onTap: () => setState(() {
                          sel
                              ? _selectedAmenityIds.remove(a.id)
                              : _selectedAmenityIds.add(a.id);
                        }),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),

          // ── Apply Button ───────────────────────────────────────────────
          Padding(
            padding: EdgeInsets.fromLTRB(
                20, 0, 20, MediaQuery.of(context).padding.bottom + 16),
            child: SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: () => context.pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: AppColors.onPrimary,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  textStyle: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w800),
                ),
                child: Text(
                  active > 0 ? 'Apply Filters ($active)' : 'Apply Filters',
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Section label with optional icon ─────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final IconData? icon;
  final String label;

  const _SectionLabel({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Row(
      children: [
        if (icon != null) ...[
          Icon(icon, size: 16, color: colors.textSecondary),
          const SizedBox(width: 6),
        ],
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: colors.textSecondary,
            letterSpacing: 1,
          ),
        ),
      ],
    );
  }
}

// ── Generic chip button ──────────────────────────────────────────────────────

class _ChipButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ChipButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppColors.accent : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? AppColors.accent : colors.border,
            width: 1.5,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: selected ? AppColors.onPrimary : colors.textPrimary,
          ),
        ),
      ),
    );
  }
}

// ── Amenity chip with icon ───────────────────────────────────────────────────

class _AmenityChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _AmenityChip({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: (MediaQuery.of(context).size.width - 50) / 2,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color:
              selected ? AppColors.accent.withValues(alpha: 0.1) : colors.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? AppColors.accent : colors.border,
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 18,
              color: selected ? AppColors.accent : colors.textSecondary,
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: selected ? AppColors.accent : colors.textPrimary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
