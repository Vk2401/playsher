import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:table_calendar/table_calendar.dart';
import '../core/api_error.dart';
import '../core/app_colors.dart';
import '../models/ground_model.dart';
import '../models/review_eligibility_model.dart';
import '../models/ground_sport_model.dart';
import '../providers/favorites_provider.dart';
import '../providers/grounds_provider.dart';
import '../widgets/error_view.dart';
import '../widgets/review_card.dart';
import '../widgets/shimmer_loader.dart';
import '../widgets/sport_glyph.dart';
import '../widgets/write_review_sheet.dart';
import '../widgets/sticky_bottom_bar.dart';
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

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  /// Price is the venue's, so it no longer depends on which sport is selected.
  /// The server recomputes it on create and stays the authority; this only makes
  /// the bottom bar honest before the tap.
  int _totalPriceFor(GroundModel ground) {
    if (_selectedSlots.isEmpty) return 0;
    return (ground.pricePerSlot * _selectedSlots.length).round();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final id = int.tryParse(widget.groundId) ?? 0;
    final groundAsync = ref.watch(groundDetailProvider(id));

    return groundAsync.when(
      loading: () => Scaffold(
        backgroundColor: colors.background,
        appBar: AppBar(backgroundColor: colors.background),
        body: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20),
          child: GroundCardShimmer(),
        ),
      ),
      error: (e, _) => Scaffold(
        backgroundColor: colors.background,
        appBar: AppBar(),
        body: ErrorView(
          message: apiErrorMessage(e, fallback: 'Could not load this ground'),
          onRetry: () => ref.invalidate(groundDetailProvider(id)),
        ),
      ),
      data: (ground) => _buildScaffold(context, ground),
    );
  }

  Widget _buildScaffold(BuildContext context, GroundModel ground) {
    final colors = context.colors;
    // Watched (not just read) so the hero heart repaints when the list changes.
    ref.watch(favoritesProvider);
    // No stock-photo fallback: an invented image reads as a real photo of a
    // venue the user is about to pay for. An empty list renders the themed
    // placeholder below.
    final images = ground.images.map((i) => i.image).toList();

    // Default to the ground's first sport. With nothing selected the screen
    // renders no calendar, no slots and no booking bar — the ground looks
    // unbookable, and nothing on screen hints that tapping a sport pill is
    // what unlocks it. Assigning during build is safe here: the value is used
    // by this same build and the operation is idempotent.
    if (_selectedGroundSport == null && ground.groundSports.isNotEmpty) {
      _selectedGroundSport = ground.groundSports.first;
    }

    final hasSelection =
        _selectedGroundSport != null && _selectedSlots.isNotEmpty;

    return Scaffold(
      backgroundColor: colors.background,
      body: CustomScrollView(
        slivers: [
          // ── Hero SliverAppBar ──────────────────────────────────────────
          SliverAppBar(
            expandedHeight: 384,
            pinned: true,
            backgroundColor: colors.background,
            leading: IconButton(
              onPressed: () => context.pop(),
              tooltip: 'Back',
              icon: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.4),
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
              Consumer(
                builder: (context, ref, _) {
                  final isFav = ref
                      .watch(favoritesProvider.notifier)
                      .isFavorite(ground.id);
                  return Container(
                    margin: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.4),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: Icon(
                        isFav
                            ? Icons.favorite_rounded
                            : Icons.favorite_border_rounded,
                        size: 20,
                        color: isFav ? AppColors.error : Colors.white,
                      ),
                      tooltip: isFav ? 'Remove from saved' : 'Save this ground',
                      onPressed: () => ref
                          .read(favoritesProvider.notifier)
                          .toggle(ground.id),
                    ),
                  );
                },
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  if (images.isEmpty)
                    Container(
                      color: colors.input,
                      child: Icon(
                        Icons.sports_soccer_rounded,
                        size: 64,
                        color: colors.border,
                      ),
                    )
                  else
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
                  // Gradient overlay. Decorative, so it must not take hits:
                  // this layer fills the hero above the PageView, and without
                  // IgnorePointer it absorbs the horizontal drag — the gallery
                  // simply never swipes.
                  Positioned.fill(
                    child: IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.black.withValues(alpha: 0.4),
                              Colors.transparent,
                              Colors.black.withValues(alpha: 0.7),
                            ],
                            stops: const [0.0, 0.4, 1.0],
                          ),
                        ),
                      ),
                    ),
                  ),
                  // The rounded sheet-top, drawn as the last 20px of the hero
                  // rather than by translating the content sliver up over it.
                  // A paint-only transform left the content's layout box where
                  // it was, so the ground name rendered underneath the image.
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    height: 20,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: colors.background,
                        borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(24)),
                      ),
                    ),
                  ),
                  // Page dots
                  if (images.length > 1)
                    Positioned(
                      bottom: 28,
                      left: 0,
                      right: 0,
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
                                  : Colors.white.withValues(alpha: 0.4),
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
              decoration: BoxDecoration(color: colors.background),
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
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.star_rounded,
                                    size: 14, color: AppColors.onPrimary),
                                const SizedBox(width: 3),
                                Text(
                                  ground.avgRating.toStringAsFixed(1),
                                  style: const TextStyle(
                                    color: AppColors.onPrimary,
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
                  if ((ground.address ?? '').isNotEmpty ||
                      (ground.city ?? '').isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        children: [
                          const Icon(Icons.location_on_rounded,
                              size: 14, color: AppColors.primary),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              [ground.address, ground.city]
                                  .where((s) => s != null && s.isNotEmpty)
                                  .join(', '),
                              style: TextStyle(
                                  fontSize: 13, color: colors.textSecondary),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),

                  const SizedBox(height: 20),

                  // Stats row
                  Container(
                    margin:
                        const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: colors.input,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: colors.border),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        Expanded(
                          child: _StatBox(
                            icon: Icons.star_rounded,
                            value: ground.avgRating.toStringAsFixed(1),
                            label: 'RATING',
                          ),
                        ),
                        const _VertDivider(),
                        Expanded(
                          child: _StatBox(
                            icon: Icons.rate_review_rounded,
                            value: '${ground.reviewCount}',
                            label: 'REVIEWS',
                          ),
                        ),
                        const _VertDivider(),
                        Expanded(
                          child: _StatBox(
                            icon: Icons.attach_money_rounded,
                            value: ground.startingPrice > 0
                                ? '\u20b9${ground.startingPrice.toStringAsFixed(0)}'
                                : '\u2014',
                            label: 'FROM/SLOT',
                          ),
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
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 8),
                              decoration: BoxDecoration(
                                color: sel
                                    ? AppColors.primary.withValues(alpha: 0.1)
                                    : colors.input,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color:
                                      sel ? AppColors.primary : colors.border,
                                  width: sel ? 2 : 1,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  SportGlyph(
                                      name: gs.sport?.name ?? 'Sport',
                                      imageUrl: gs.sport?.image,
                                      size: 16),
                                  const SizedBox(width: 6),
                                  Flexible(
                                    child: Text(
                                      gs.sport?.name ?? 'Sport',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: sel
                                            ? AppColors.primary
                                            : colors.textSecondary,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
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
                          selectedDayPredicate: (d) =>
                              isSameDay(d, _selectedDay),
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
                              color: AppColors.onPrimary,
                              fontWeight: FontWeight.w700,
                            ),
                            todayDecoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.2),
                              shape: BoxShape.circle,
                            ),
                            todayTextStyle: const TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w700,
                            ),
                            defaultTextStyle:
                                TextStyle(color: colors.textPrimary),
                            weekendTextStyle:
                                TextStyle(color: colors.textSecondary),
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
                            leftChevronIcon: Icon(Icons.chevron_left,
                                color: colors.textSecondary),
                            rightChevronIcon: Icon(Icons.chevron_right,
                                color: colors.textSecondary),
                          ),
                          daysOfWeekStyle: DaysOfWeekStyle(
                            weekdayStyle: TextStyle(
                                color: colors.textSecondary, fontSize: 12),
                            weekendStyle: TextStyle(
                                color: colors.textSecondary, fontSize: 12),
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
                    height: 48,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      children: [
                        _SectionPill('Overview', 0, _contentSection,
                            () => setState(() => _contentSection = 0)),
                        _SectionPill('Amenities', 1, _contentSection,
                            () => setState(() => _contentSection = 1)),
                        _SectionPill('Reviews', 2, _contentSection,
                            () => setState(() => _contentSection = 2)),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Content sections
                  if (_contentSection == 0) _OverviewSection(ground: ground),
                  if (_contentSection == 1) _AmenitiesSection(ground: ground),
                  if (_contentSection == 2) _ReviewsSection(ground: ground),

                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),

      // ── Booking bar ────────────────────────────────────────────────────────
      // The shared widget rather than a hand-rolled copy: it already owns the
      // bottom safe-area inset and the disabled/loading state.
      // A venue with no price cannot be booked — the server refuses with 409 —
      // so say so here rather than quoting ₹0 and failing at the payment step.
      bottomNavigationBar: !hasSelection
          ? null
          : !ground.isBookable
              ? const StickyBottomBar(
                  priceLabel: 'PRICE',
                  price: 'Not set',
                  buttonText: 'Not available for booking',
                  onPressed: null,
                )
              : StickyBottomBar(
              priceLabel: 'TOTAL PRICE',
              price: '\u20b9${_totalPriceFor(ground)}',
              buttonText:
                  'Book Now (${_selectedSlots.length} slot${_selectedSlots.length > 1 ? 's' : ''})',
              onPressed: () => context.push(
                '/book/${_selectedGroundSport!.groundId}',
                extra: {
                  'groundSport': _selectedGroundSport,
                  'date': _selectedDay.toIso8601String().split('T').first,
                  'slotIds': _selectedSlots.toList(),
                  'totalPrice': _totalPriceFor(ground),
                  // The per-slot figure the total was built from, so the
                  // checkout sheet quotes the venue's price rather than
                  // recomputing one from the sport.
                  'pricePerSlot': ground.pricePerSlot,
                  // POST /bookings answers with the bare Booking row, which
                  // carries no ground or sport name — carry them ourselves.
                  'groundName': ground.name,
                },
              ),
            ),
    );
  }
}

// ── Stat box ──────────────────────────────────────────────────────────────────

class _StatBox extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;

  const _StatBox(
      {required this.icon, required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.15),
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
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
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
        padding: const EdgeInsets.symmetric(horizontal: 18),
        // Centred both ways and floored at 44 high: the label used to sit
        // wherever its own baseline fell, so the three pills read ragged.
        alignment: Alignment.center,
        constraints: const BoxConstraints(minHeight: 44, minWidth: 96),
        decoration: BoxDecoration(
          color: sel ? AppColors.primary.withValues(alpha: 0.12) : colors.input,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: sel ? AppColors.primary : colors.border),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13,
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
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: colors.textPrimary),
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
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: colors.textPrimary),
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
          child: Text('No amenities listed.',
              style: TextStyle(color: colors.textSecondary)),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 220,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
          // Height, not ratio: a fixed ratio clips the label as text scales.
          mainAxisExtent: 32 *
              MediaQuery.textScalerOf(context)
                  .clamp(maxScaleFactor: 1.4)
                  .scale(1),
        ),
        itemCount: ground.amenities.length,
        itemBuilder: (_, i) => Row(
          children: [
            Container(
              width: 8,
              height: 8,
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

class _ReviewsSection extends ConsumerWidget {
  final GroundModel ground;
  const _ReviewsSection({required this.ground});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final eligibility = ref.watch(reviewEligibilityProvider(ground.id));

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // The eligibility answer decides between a button, an explanation and
          // nothing at all — never an error, since a failed check just means we
          // do not offer the form.
          eligibility.maybeWhen(
            data: (e) => _ReviewAction(
              eligibility: e,
              ground: ground,
              onPosted: () {
                ref.invalidate(groundDetailProvider(ground.id));
                ref.invalidate(reviewEligibilityProvider(ground.id));
              },
            ),
            orElse: () => const SizedBox.shrink(),
          ),

          if (ground.reviews.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  'No reviews yet. Be the first!',
                  style: TextStyle(color: colors.textSecondary),
                ),
              ),
            )
          else
            ...ground.reviews.map((r) => ReviewCard(review: r)),
        ],
      ),
    );
  }
}

/// Either the button to write a review, or why it is not on offer.
class _ReviewAction extends StatelessWidget {
  final ReviewEligibility eligibility;
  final GroundModel ground;
  final VoidCallback onPosted;

  const _ReviewAction({
    required this.eligibility,
    required this.ground,
    required this.onPosted,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    if (eligibility.canReview) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: SizedBox(
          height: 48,
          child: OutlinedButton.icon(
            onPressed: () async {
              final posted = await WriteReviewSheet.show(
                context,
                groundId: ground.id,
                groundName: ground.name,
              );
              if (posted) onPosted();
            },
            icon: const Icon(Icons.rate_review_outlined, size: 18),
            label: const Text('Write a review'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primary,
              side: const BorderSide(color: AppColors.primary),
            ),
          ),
        ),
      );
    }

    // Silent when the check could not run — an anonymous browser should not be
    // told they are ineligible, only that reviews exist.
    if (eligibility.reason == null) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: colors.input,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            eligibility.alreadyReviewed
                ? Icons.check_circle_outline_rounded
                : Icons.lock_outline_rounded,
            size: 16,
            color: colors.textSecondary,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              eligibility.message ??
                  'Only players who have booked and played here can review.',
              style: TextStyle(
                fontSize: 12,
                color: colors.textSecondary,
                height: 1.4,
              ),
            ),
          ),
        ],
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
      loading: () => const SlotGridShimmer(),
      error: (e, _) => ErrorView(
        message:
            apiErrorMessage(e, fallback: 'Could not load slots for this date'),
        onRetry: () => ref.invalidate(
          slotsProvider(SlotQuery(groundSportId: groundSportId, date: date)),
        ),
      ),
      data: (allSlots) {
        // Second line of defence behind the API's own filter: never offer a
        // slot whose start time has gone by, or the tap dies at checkout.
        final slots = allSlots.where((s) => !s.hasStarted).toList();
        if (slots.isEmpty) {
          // "Today is over" is a different answer from "this venue is shut",
          // and sending someone to tomorrow is only useful for the first one.
          final dayIsSpent = allSlots.isNotEmpty;
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: Text(
                dayIsSpent
                    ? "Today's slots have all started. Try another date."
                    : 'No slots available for this date.',
                textAlign: TextAlign.center,
                style: TextStyle(color: colors.textSecondary),
              ),
            ),
          );
        }
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: slots
              .map((s) => SlotTile(
                    slot: s,
                    selected: selectedSlots.contains(s.id),
                    onTap: !s.isAvailable ? null : () => onSlotToggle(s.id),
                  ))
              .toList(),
        );
      },
    );
  }
}

// ── Booking bar ───────────────────────────────────────────────────────────────
