import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:table_calendar/table_calendar.dart';
import '../core/app_colors.dart';
import '../models/ground_model.dart';
import '../models/ground_sport_model.dart';
import '../providers/grounds_provider.dart';
import '../widgets/error_view.dart';
import '../widgets/review_card.dart';
import '../widgets/shimmer_loader.dart';
import '../widgets/slot_tile.dart';

class GroundDetailScreen extends ConsumerStatefulWidget {
  final String groundId;
  const GroundDetailScreen({super.key, required this.groundId});

  @override
  ConsumerState<GroundDetailScreen> createState() => _GroundDetailScreenState();
}

class _GroundDetailScreenState extends ConsumerState<GroundDetailScreen> {
  final _pageCtrl = PageController();
  int _imgIndex = 0;

  GroundSportModel? _selectedGroundSport;
  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();
  final Set<int> _selectedSlots = {};

  // Sport pill selection (replaces tab bar)
  int _contentSection = 0; // 0=Overview, 1=Amenities, 2=Reviews

  static const _sportEmojis = {
    'cricket': '\u{1F3CF}', 'football': '\u26BD', 'soccer': '\u26BD',
    'basketball': '\u{1F3C0}', 'volleyball': '\u{1F3D0}', 'badminton': '\u{1F3F8}',
    'tennis': '\u{1F3BE}', 'hockey': '\u{1F3D1}', 'swimming': '\u{1F3CA}',
    'kabaddi': '\u{1F93C}', 'gym': '\u{1F4AA}',
  };

  String _emoji(String name) => _sportEmojis.entries
      .firstWhere((e) => name.toLowerCase().contains(e.key),
          orElse: () => const MapEntry('', '\u{1F3C6}'))
      .value;

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  int get _totalPrice {
    if (_selectedGroundSport == null || _selectedSlots.isEmpty) return 0;
    return (_selectedGroundSport!.pricePerSlot * _selectedSlots.length).round();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final id = int.tryParse(widget.groundId) ?? 0;
    final groundAsync = ref.watch(groundDetailProvider(id));

    return groundAsync.when(
      loading: () => Scaffold(
        backgroundColor: colors.background,
        body: const Center(child: CircularProgressIndicator(color: AppColors.primary)),
      ),
      error: (e, _) => Scaffold(
        backgroundColor: colors.background,
        appBar: AppBar(),
        body: ErrorView(
          message: e.toString(),
          onRetry: () => ref.invalidate(groundDetailProvider(id)),
        ),
      ),
      data: (ground) => _buildScaffold(context, ground),
    );
  }

  Widget _buildScaffold(BuildContext context, GroundModel ground) {
    final colors = context.colors;
    final images = ground.images.isNotEmpty
        ? ground.images.map((i) => i.image).toList()
        : ['https://picsum.photos/seed/${ground.id}/800/400'];

    return Scaffold(
      backgroundColor: colors.background,
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              // ── Hero SliverAppBar ──────────────────────────────────────────
              SliverAppBar(
                expandedHeight: 384,
                pinned: true,
                backgroundColor: colors.background,
                leading: GestureDetector(
                  onTap: () => context.pop(),
                  child: Container(
                    margin: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.4),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.arrow_back_ios_new_rounded,
                      size: 18,
                      color: Colors.white,
                    ),
                  ),
                ),
                actions: [
                  Container(
                    margin: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.4),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.favorite_border_rounded, size: 20, color: Colors.white),
                      onPressed: () {},
                    ),
                  ),
                ],
                flexibleSpace: FlexibleSpaceBar(
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      PageView.builder(
                        controller: _pageCtrl,
                        itemCount: images.length,
                        onPageChanged: (i) => setState(() => _imgIndex = i),
                        itemBuilder: (_, i) => CachedNetworkImage(
                          imageUrl: images[i],
                          fit: BoxFit.cover,
                          placeholder: (_, __) => Container(color: colors.input),
                          errorWidget: (_, __, ___) => Container(
                            color: colors.input,
                            child: Icon(
                              Icons.sports_soccer_rounded,
                              size: 64,
                              color: colors.border,
                            ),
                          ),
                        ),
                      ),
                      // Gradient overlay
                      Positioned.fill(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.black.withOpacity(0.4),
                                Colors.transparent,
                                Colors.black.withOpacity(0.7),
                              ],
                              stops: const [0.0, 0.4, 1.0],
                            ),
                          ),
                        ),
                      ),
                      // Page dots
                      if (images.length > 1)
                        Positioned(
                          bottom: 16, left: 0, right: 0,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(
                              images.length,
                              (i) => AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                margin: const EdgeInsets.symmetric(horizontal: 3),
                                width: i == _imgIndex ? 16 : 6,
                                height: 6,
                                decoration: BoxDecoration(
                                  color: i == _imgIndex
                                      ? Colors.white
                                      : Colors.white.withOpacity(0.4),
                                  borderRadius: BorderRadius.circular(3),
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),

              // ── Content (overlapping card style) ────────────────────────────
              SliverToBoxAdapter(
                child: Container(
                  decoration: BoxDecoration(
                    color: colors.background,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(40)),
                  ),
                  transform: Matrix4.translationValues(0, -40, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 20),

                      // Title + rating
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                ground.name,
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                  color: colors.textPrimary,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            if (ground.avgRating > 0)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color: AppColors.primary,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.star_rounded, size: 14, color: Colors.black),
                                    const SizedBox(width: 3),
                                    Text(
                                      ground.avgRating.toStringAsFixed(1),
                                      style: const TextStyle(
                                        color: Colors.black,
                                        fontWeight: FontWeight.w800,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 10),

                      // Location row
                      if ((ground.address ?? '').isNotEmpty || (ground.city ?? '').isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Row(
                            children: [
                              const Icon(Icons.location_on_rounded, size: 14, color: AppColors.primary),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  [ground.address, ground.city]
                                      .where((s) => s != null && s.isNotEmpty)
                                      .join(', '),
                                  style: TextStyle(fontSize: 13, color: colors.textSecondary),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                'View Map',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),

                      const SizedBox(height: 20),

                      // Stats row
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          color: colors.input,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: colors.border),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _StatBox(
                              icon: Icons.star_rounded,
                              value: ground.avgRating.toStringAsFixed(1),
                              label: 'RATING',
                            ),
                            _VertDivider(),
                            _StatBox(
                              icon: Icons.rate_review_rounded,
                              value: '${ground.reviewCount}',
                              label: 'REVIEWS',
                            ),
                            _VertDivider(),
                            _StatBox(
                              icon: Icons.attach_money_rounded,
                              value: ground.startingPrice > 0
                                  ? '\u20b9${ground.startingPrice.toStringAsFixed(0)}'
                                  : '\u2014',
                              label: 'FROM/SLOT',
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Sport pills (select sport for slots)
                      if (ground.groundSports.isNotEmpty) ...[
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                          child: Text(
                            'Select Sport',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: colors.textPrimary,
                            ),
                          ),
                        ),
                        SizedBox(
                          height: 44,
                          child: ListView(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            children: ground.groundSports.map((gs) {
                              final sel = gs.id == _selectedGroundSport?.id;
                              return GestureDetector(
                                onTap: () => setState(() {
                                  _selectedGroundSport = gs;
                                  _selectedSlots.clear();
                                }),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  margin: const EdgeInsets.only(right: 8),
                                  constraints: const BoxConstraints(minWidth: 100),
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: sel
                                        ? AppColors.primary.withOpacity(0.1)
                                        : colors.input,
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: sel ? AppColors.primary : colors.border,
                                      width: sel ? 2 : 1,
                                    ),
                                  ),
                                  child: Text(
                                    '${_emoji(gs.sport?.name ?? '')}  ${gs.sport?.name ?? 'Sport'}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: sel ? AppColors.primary : colors.textSecondary,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],

                      // Slot calendar + grid
                      if (_selectedGroundSport != null) ...[
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Container(
                            decoration: BoxDecoration(
                              color: colors.card,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: colors.border),
                            ),
                            child: TableCalendar(
                              firstDay: DateTime.now(),
                              lastDay: DateTime.now().add(const Duration(days: 30)),
                              focusedDay: _focusedDay,
                              selectedDayPredicate: (d) => isSameDay(d, _selectedDay),
                              onDaySelected: (sel, foc) => setState(() {
                                _selectedDay = sel;
                                _focusedDay = foc;
                                _selectedSlots.clear();
                              }),
                              calendarStyle: CalendarStyle(
                                selectedDecoration: const BoxDecoration(
                                  color: AppColors.primary,
                                  shape: BoxShape.circle,
                                ),
                                selectedTextStyle: const TextStyle(
                                  color: Colors.black,
                                  fontWeight: FontWeight.w700,
                                ),
                                todayDecoration: BoxDecoration(
                                  color: AppColors.primary.withOpacity(0.2),
                                  shape: BoxShape.circle,
                                ),
                                todayTextStyle: const TextStyle(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w700,
                                ),
                                defaultTextStyle: TextStyle(color: colors.textPrimary),
                                weekendTextStyle: TextStyle(color: colors.textSecondary),
                                outsideTextStyle: TextStyle(color: colors.border),
                                disabledTextStyle: TextStyle(color: colors.border),
                              ),
                              headerStyle: HeaderStyle(
                                formatButtonVisible: false,
                                titleCentered: true,
                                titleTextStyle: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                  color: colors.textPrimary,
                                ),
                                leftChevronIcon: Icon(Icons.chevron_left, color: colors.textSecondary),
                                rightChevronIcon: Icon(Icons.chevron_right, color: colors.textSecondary),
                              ),
                              daysOfWeekStyle: DaysOfWeekStyle(
                                weekdayStyle: TextStyle(color: colors.textSecondary, fontSize: 12),
                                weekendStyle: TextStyle(color: colors.textSecondary, fontSize: 12),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Text(
                            'Available Slots \u2014 ${_selectedDay.day}/${_selectedDay.month}/${_selectedDay.year}',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: colors.textPrimary,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: _SlotsGrid(
                            groundSportId: _selectedGroundSport!.id,
                            date: _selectedDay.toIso8601String().split('T').first,
                            selectedSlots: _selectedSlots,
                            onSlotToggle: (id) => setState(() {
                              if (_selectedSlots.contains(id)) {
                                _selectedSlots.remove(id);
                              } else {
                                _selectedSlots.add(id);
                              }
                            }),
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],

                      // Section nav pills
                      SizedBox(
                        height: 44,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          children: [
                            _SectionPill('Overview', 0, _contentSection, () => setState(() => _contentSection = 0)),
                            _SectionPill('Amenities', 1, _contentSection, () => setState(() => _contentSection = 1)),
                            _SectionPill('Reviews', 2, _contentSection, () => setState(() => _contentSection = 2)),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Content sections
                      if (_contentSection == 0)
                        _OverviewSection(ground: ground),
                      if (_contentSection == 1)
                        _AmenitiesSection(ground: ground),
                      if (_contentSection == 2)
                        _ReviewsSection(ground: ground),

                      // Extra bottom padding for booking bar
                      const SizedBox(height: 100),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // ── Fixed booking bar ──────────────────────────────────────────────
          if (_selectedGroundSport != null && _selectedSlots.isNotEmpty)
            Positioned(
              bottom: 0, left: 0, right: 0,
              child: _BookingBar(
                groundSport: _selectedGroundSport!,
                slotCount: _selectedSlots.length,
                totalPrice: _totalPrice,
                onBook: () => context.push(
                  '/book/${_selectedGroundSport!.groundId}',
                  extra: {
                    'groundSport': _selectedGroundSport,
                    'date': _selectedDay.toIso8601String().split('T').first,
                    'slotIds': _selectedSlots.toList(),
                    'totalPrice': _totalPrice,
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Stat box ──────────────────────────────────────────────────────────────────

class _StatBox extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;

  const _StatBox({required this.icon, required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 36, height: 36,
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 18, color: AppColors.primary),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 9,
            color: colors.textSecondary,
            letterSpacing: 0.6,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: colors.textPrimary,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

class _VertDivider extends StatelessWidget {
  const _VertDivider();

  @override
  Widget build(BuildContext context) {
    return Container(width: 1, height: 40, color: context.colors.border);
  }
}

// ── Section pill ──────────────────────────────────────────────────────────────

class _SectionPill extends StatelessWidget {
  final String label;
  final int index;
  final int current;
  final VoidCallback onTap;

  const _SectionPill(this.label, this.index, this.current, this.onTap);

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final sel = index == current;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: sel ? AppColors.primary.withOpacity(0.12) : colors.input,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: sel ? AppColors.primary : colors.border),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: sel ? AppColors.primary : colors.textSecondary,
          ),
        ),
      ),
    );
  }
}

// ── Overview section ──────────────────────────────────────────────────────────

class _OverviewSection extends StatelessWidget {
  final GroundModel ground;
  const _OverviewSection({required this.ground});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final desc = ground.description ?? ground.about ?? '';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (desc.isNotEmpty) ...[
            Text(
              'About',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: colors.textPrimary),
            ),
            const SizedBox(height: 8),
            Text(
              desc,
              style: TextStyle(
                fontSize: 14,
                color: colors.textSecondary,
                height: 1.6,
              ),
            ),
            const SizedBox(height: 20),
          ],
          if ((ground.venueRules ?? '').isNotEmpty) ...[
            Text(
              'Venue Rules',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: colors.textPrimary),
            ),
            const SizedBox(height: 8),
            Text(
              ground.venueRules!,
              style: TextStyle(
                fontSize: 14,
                color: colors.textSecondary,
                height: 1.6,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Amenities section ─────────────────────────────────────────────────────────

class _AmenitiesSection extends StatelessWidget {
  final GroundModel ground;
  const _AmenitiesSection({required this.ground});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    if (ground.amenities.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Text('No amenities listed.', style: TextStyle(color: colors.textSecondary)),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
          childAspectRatio: 4.0,
        ),
        itemCount: ground.amenities.length,
        itemBuilder: (_, i) => Row(
          children: [
            Container(
              width: 8, height: 8,
              decoration: const BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                ground.amenities[i].name,
                style: TextStyle(
                  fontSize: 13,
                  color: colors.textPrimary,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Reviews section ───────────────────────────────────────────────────────────

class _ReviewsSection extends StatelessWidget {
  final GroundModel ground;
  const _ReviewsSection({required this.ground});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    if (ground.reviews.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Text(
            'No reviews yet. Be the first!',
            style: TextStyle(color: colors.textSecondary),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: ground.reviews.map((r) => ReviewCard(review: r)).toList(),
      ),
    );
  }
}

// ── Slots grid ────────────────────────────────────────────────────────────────

class _SlotsGrid extends ConsumerWidget {
  final int groundSportId;
  final String date;
  final Set<int> selectedSlots;
  final ValueChanged<int> onSlotToggle;

  const _SlotsGrid({
    required this.groundSportId,
    required this.date,
    required this.selectedSlots,
    required this.onSlotToggle,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final slotsAsync = ref.watch(
      slotsProvider(SlotQuery(groundSportId: groundSportId, date: date)),
    );

    return slotsAsync.when(
      loading: () => Wrap(
        spacing: 8, runSpacing: 8,
        children: List.generate(8, (_) => const ShimmerBox(height: 56, width: 100)),
      ),
      error: (e, _) => ErrorView(
        message: e.toString(),
        onRetry: () => ref.invalidate(
          slotsProvider(SlotQuery(groundSportId: groundSportId, date: date)),
        ),
      ),
      data: (slots) {
        if (slots.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: Text(
                'No slots available for this date.',
                style: TextStyle(color: colors.textSecondary),
              ),
            ),
          );
        }
        return Wrap(
          spacing: 8, runSpacing: 8,
          children: slots.map((s) => SlotTile(
            slot: s,
            selected: selectedSlots.contains(s.id),
            onTap: !s.isAvailable ? null : () => onSlotToggle(s.id),
          )).toList(),
        );
      },
    );
  }
}

// ── Booking bar ───────────────────────────────────────────────────────────────

class _BookingBar extends StatelessWidget {
  final GroundSportModel groundSport;
  final int slotCount;
  final int totalPrice;
  final VoidCallback onBook;

  const _BookingBar({
    required this.groundSport,
    required this.slotCount,
    required this.totalPrice,
    required this.onBook,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      padding: EdgeInsets.fromLTRB(
        20, 16, 20, MediaQuery.of(context).padding.bottom + 16,
      ),
      decoration: BoxDecoration(
        color: colors.background.withOpacity(0.92),
        border: Border(top: BorderSide(color: colors.border)),
      ),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'TOTAL PRICE',
                style: TextStyle(
                  fontSize: 10,
                  color: colors.textSecondary,
                  letterSpacing: 1,
                ),
              ),
              Text(
                '\u20b9$totalPrice',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          const Spacer(),
          ElevatedButton(
            onPressed: onBook,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              minimumSize: Size.zero,
            ),
            child: Text(
              'Book Now  ($slotCount slot${slotCount > 1 ? 's' : ''})',
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}
