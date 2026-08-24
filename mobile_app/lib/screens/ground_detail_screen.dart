import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/api_error.dart';
import '../core/app_colors.dart';
import '../models/ground_model.dart';
import '../models/review_eligibility_model.dart';
import '../models/ground_sport_model.dart';
import '../providers/favorites_provider.dart';
import '../providers/grounds_provider.dart';
import '../widgets/booking_picker.dart';
import '../widgets/error_view.dart';
import '../widgets/review_card.dart';
import '../widgets/shimmer_loader.dart';
import '../widgets/sport_glyph.dart';
import '../widgets/write_review_sheet.dart';

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
  DateTime _selectedDay = DateTime.now();

  /// The Monday-agnostic start of the week the date strip is showing: it opens
  /// on today rather than on a calendar week, because the first date anyone
  /// wants is today.
  DateTime _weekStart = DateTime.now();
  final Set<int> _selectedSlots = {};

  // Sport pill selection (replaces tab bar)
  int _contentSection = 0; // 0=Overview, 1=Amenities, 2=Reviews

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  /// The date as the API takes it.
  static String _apiDate(DateTime day) =>
      day.toIso8601String().split('T').first;

  /// The date as the screen says it: "24 August 2026".
  static String _longDate(DateTime day) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return '${day.day} ${months[day.month - 1]} ${day.year}';
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
                  final isFav =
                      ref.watch(favoriteIdsProvider).contains(ground.id);
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
                      onPressed: () =>
                          ref.read(favoritesProvider.notifier).toggle(ground),
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
                            icon: Icons.star_outline_rounded,
                            value: ground.reviewCount == 0
                                ? '—'
                                : ground.avgRating.toStringAsFixed(1),
                            label: 'Rating',
                            caption: ground.reviewCount == 0
                                ? 'No reviews yet'
                                : '${ground.reviewCount} Reviews',
                          ),
                        ),
                        const _VertDivider(),
                        Expanded(
                          child: _StatBox(
                            icon: Icons.chat_bubble_outline_rounded,
                            value: '${ground.reviewCount}',
                            label: 'Reviews',
                            caption: 'See all',
                          ),
                        ),
                        const _VertDivider(),
                        Expanded(
                          // The design's "Max Players" is not a field the API
                          // has; the booking limit it does have is slots per
                          // booking, so that is what this says rather than
                          // inventing a headcount.
                          child: _StatBox(
                            icon: Icons.people_outline_rounded,
                            value: '${_selectedGroundSport?.maxSlots ?? 0}',
                            label: 'Max Slots',
                            caption: 'Per Booking',
                          ),
                        ),
                        const _VertDivider(),
                        Expanded(
                          child: _StatBox(
                            icon: Icons.currency_rupee_rounded,
                            value: ground.formattedStartingPrice ?? '—',
                            label: 'Price / Slot',
                            caption: '30 Mins',
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
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: colors.textPrimary,
                        ),
                      ),
                    ),
                    SizedBox(
                      height: 52,
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
                                  horizontal: 18, vertical: 11),
                              decoration: BoxDecoration(
                                // Filled when chosen, as the design has it: a
                                // tinted outline read as "hovered" beside the
                                // solid date and slot selections.
                                color: sel ? AppColors.primary : colors.card,
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(
                                  color:
                                      sel ? AppColors.primary : colors.border,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  SportGlyph(
                                      name: gs.sport?.name ?? 'Sport',
                                      imageUrl: gs.sport?.image,
                                      size: 20),
                                  const SizedBox(width: 6),
                                  Flexible(
                                    child: Text(
                                      gs.sport?.name ?? 'Sport',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: sel
                                            ? AppColors.onPrimary
                                            : colors.textPrimary,
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

                  // Date, then time — the two questions a booking asks,
                  // in the order the design asks them.
                  if (_selectedGroundSport != null) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: DateStrip(
                        selected: _selectedDay,
                        firstDay: _weekStart,
                        onSelected: (day) => setState(() {
                          _selectedDay = day;
                          // The slots belonged to the old day.
                          _selectedSlots.clear();
                        }),
                        onPageChanged: (day) =>
                            setState(() => _weekStart = day),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        children: [
                          Text(
                            'Select Time',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: colors.textPrimary,
                            ),
                          ),
                          Text(
                            '  \u2022  ',
                            style: TextStyle(color: colors.textSecondary),
                          ),
                          Flexible(
                            child: Text(
                              _longDate(_selectedDay),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w600,
                                color: colors.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: SlotPicker(
                        // Keyed so switching sport or date rebuilds the picker
                        // from scratch rather than keeping the old period.
                        key: ValueKey(
                            '${_selectedGroundSport!.id}-${_apiDate(_selectedDay)}'),
                        groundSportId: _selectedGroundSport!.id,
                        date: _apiDate(_selectedDay),
                        price: ground.formattedStartingPrice ?? '—',
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
                    const SizedBox(height: 24),
                  ],

                  // What the venue is, under three tabs.
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Container(
                      decoration: BoxDecoration(
                        color: colors.card,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: colors.border),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              for (final (i, tab) in const [
                                (Icons.info_outline_rounded, 'Overview'),
                                (Icons.tune_rounded, 'Amenities'),
                                (Icons.star_outline_rounded, 'Reviews'),
                              ].indexed)
                                Expanded(
                                  child: _SectionTab(
                                    icon: tab.$1,
                                    label: tab.$2,
                                    selected: _contentSection == i,
                                    onTap: () =>
                                        setState(() => _contentSection = i),
                                  ),
                                ),
                            ],
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(4, 14, 4, 6),
                            child: switch (_contentSection) {
                              0 => _OverviewSection(ground: ground),
                              1 => _AmenitiesSection(ground: ground),
                              _ => _ReviewsSection(ground: ground),
                            },
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),

      // ── Booking bar ────────────────────────────────────────────────────────
      // What was chosen, beside what it costs and the way on. The design puts
      // the slot back in front of the user at the moment they commit, which is
      // the last chance to notice it is the wrong one.
      //
      // A venue with no price cannot be booked — the server refuses with 409 —
      // so say so here rather than quoting a total and failing at payment.
      bottomNavigationBar: !hasSelection
          ? null
          : _BookingBar(
              date: _selectedDay,
              slotCount: _selectedSlots.length,
              total: _totalPriceFor(ground),
              bookable: ground.isBookable,
              onPressed: () => context.push(
                '/book/${_selectedGroundSport!.groundId}',
                extra: {
                  'groundSport': _selectedGroundSport,
                  'date': _apiDate(_selectedDay),
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

  /// The line under the figure — "120 Reviews", "Per Booking", "30 Mins".
  final String caption;

  const _StatBox({
    required this.icon,
    required this.value,
    required this.label,
    required this.caption,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 17, color: AppColors.primary),
        ),
        const SizedBox(height: 7),
        Text(
          label,
          style: TextStyle(fontSize: 11.5, color: colors.textSecondary),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: colors.textPrimary,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 2),
        Text(
          caption,
          style: TextStyle(fontSize: 10.5, color: colors.textSecondary),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
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

// ── Section tab ───────────────────────────────────────────────────────────────

class _SectionTab extends StatelessWidget {
  const _SectionTab({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final tint = selected ? colors.brandText : colors.textSecondary;

    return Semantics(
      selected: selected,
      button: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
          decoration: BoxDecoration(
            // The rule under the active tab, which is what the design uses to
            // say which one you are on — colour alone would not.
            border: Border(
              bottom: BorderSide(
                color: selected ? AppColors.primary : Colors.transparent,
                width: 2.5,
              ),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 17, color: tint),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                    color: tint,
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

// ── Overview section ──────────────────────────────────────────────────────────

/// The venue's rules, one per sentence.
List<String> _rulesOf(GroundModel ground) => (ground.venueRules ?? '')
    .split(RegExp(r'[.;\n]'))
    .map((r) => r.trim())
    .where((r) => r.isNotEmpty)
    .toList();

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
          if (_rulesOf(ground).isNotEmpty) ...[
            Text(
              'Venue Rules',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: colors.textPrimary),
            ),
            const SizedBox(height: 12),
            // The design draws each rule as a glyph. `venue_rules` is one free
            // text field, so it is split into its sentences and each is given
            // the icon its wording earns — no icon is invented for a rule the
            // venue did not write, and anything unrecognised keeps a neutral
            // one rather than being dropped.
            Wrap(
              spacing: 18,
              runSpacing: 16,
              children: [
                for (final rule in _rulesOf(ground)) _RuleChip(rule: rule),
              ],
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

// ── Booking bar ───────────────────────────────────────────────────────────────

// ── Booking bar ───────────────────────────────────────────────────────────────

/// What is about to be booked, and the way on.
class _BookingBar extends StatelessWidget {
  const _BookingBar({
    required this.date,
    required this.slotCount,
    required this.total,
    required this.bookable,
    required this.onPressed,
  });

  final DateTime date;
  final int slotCount;
  final int total;
  final bool bookable;
  final VoidCallback onPressed;

  static const _days = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];
  static const _months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final minutes = slotCount * 30;

    return Container(
      padding: EdgeInsets.fromLTRB(
        16,
        12,
        16,
        12 + MediaQuery.of(context).padding.bottom,
      ),
      decoration: BoxDecoration(
        color: colors.card,
        border: Border(top: BorderSide(color: colors.border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  slotCount == 1 ? 'Selected Slot' : 'Selected Slots',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: colors.brandText,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${date.day} ${_months[date.month - 1]} ${date.year}'
                  '  ·  ${_days[date.weekday - 1]}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: colors.textPrimary,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  '$slotCount ${slotCount == 1 ? 'slot' : 'slots'}'
                  '  ·  $minutes mins  ·  '
                  '${bookable ? '\u20b9$total' : 'price not set'}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12.5, color: colors.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          // The CTA takes what it needs and no more: on a narrow phone the
          // slot summary beside it is the part worth reading, and an
          // ellipsised date is worse than a shorter button.
          SizedBox(
            height: 52,
            child: ElevatedButton(
              onPressed: bookable ? onPressed : null,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(0, 52),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      bookable ? 'Continue to Book' : 'Not available',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 14.5, fontWeight: FontWeight.w700),
                    ),
                  ),
                  if (bookable) ...[
                    const SizedBox(width: 8),
                    const Icon(Icons.arrow_forward_rounded, size: 18),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// One rule, under the glyph its wording earns.
class _RuleChip extends StatelessWidget {
  const _RuleChip({required this.rule});

  final String rule;

  /// Matched on what the owner actually wrote. The fallback is deliberately a
  /// neutral "rule" mark: a wrong icon states something the venue did not.
  static IconData _iconFor(String rule) {
    final text = rule.toLowerCase();
    if (text.contains('smok')) return Icons.smoke_free_rounded;
    if (text.contains('alcohol') || text.contains('drink')) {
      return Icons.no_drinks_rounded;
    }
    if (text.contains('shoe') || text.contains('stud') ||
        text.contains('footwear')) {
      return Icons.hiking_rounded;
    }
    if (text.contains('player') || text.contains('people') ||
        text.contains('max')) {
      return Icons.groups_rounded;
    }
    if (text.contains('food') || text.contains('outside')) {
      return Icons.no_food_rounded;
    }
    if (text.contains('pet') || text.contains('dog')) return Icons.pets_rounded;
    if (text.contains('time') || text.contains('late') ||
        text.contains('punctual')) {
      return Icons.schedule_rounded;
    }
    return Icons.rule_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return SizedBox(
      width: 82,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: colors.input,
              border: Border.all(color: colors.border),
            ),
            child: Icon(_iconFor(rule), size: 22, color: colors.textPrimary),
          ),
          const SizedBox(height: 7),
          Text(
            rule,
            textAlign: TextAlign.center,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                fontSize: 11.5, height: 1.3, color: colors.textSecondary),
          ),
        ],
      ),
    );
  }
}
