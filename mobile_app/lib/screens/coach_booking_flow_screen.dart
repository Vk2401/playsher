import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/api_error.dart';
import '../core/app_colors.dart';
import '../models/coach_model.dart';
import '../models/slot_model.dart';
import '../providers/coach_bookings_provider.dart';
import '../providers/coaches_provider.dart';
import '../widgets/error_view.dart';
import '../widgets/shimmer_loader.dart';
import '../widgets/slot_tile.dart';
import '../widgets/sticky_bottom_bar.dart';

/// Booking a coach: where, when, and for how long.
///
/// The slots are half hours, like every other price in the product, and they
/// must be one unbroken stretch — a session that reads "07:00–09:30" because
/// the player picked 07:00 and 09:00 is time the coach never agreed to. The
/// server refuses a gap too; this only stops the player reaching the refusal.
class CoachBookingFlowScreen extends ConsumerStatefulWidget {
  final String coachId;
  const CoachBookingFlowScreen({super.key, required this.coachId});

  @override
  ConsumerState<CoachBookingFlowScreen> createState() =>
      _CoachBookingFlowScreenState();
}

class _CoachBookingFlowScreenState
    extends ConsumerState<CoachBookingFlowScreen> {
  static const _daysAhead = 14;

  final _noteController = TextEditingController();

  late String _date = _isoDate(DateTime.now());
  int? _venueId;

  /// Whether the player has picked a venue themselves. Until they do, the
  /// coach's first approved ground is used, so the common case needs no tap.
  bool _venueChosen = false;
  final Set<int> _selected = <int>{};

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  static String _isoDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  /// The venue this booking will carry: the player's choice once they make
  /// one, otherwise the coach's first approved ground.
  int? _venueFor(CoachModel coach) {
    if (_venueChosen) return _venueId;
    return coach.venues.isEmpty ? null : coach.venues.first.id;
  }

  void _toggleSlot(List<SlotModel> slots, SlotModel slot) {
    setState(() {
      final next = Set<int>.from(_selected);
      if (next.contains(slot.id)) {
        next.remove(slot.id);
      } else {
        next.add(slot.id);
      }

      // Keeping only an unbroken run: if the tap would leave a gap, the tapped
      // slot becomes the whole selection. Silently dropping the tap instead
      // reads as an unresponsive tile.
      if (_isContiguous(slots, next)) {
        _selected
          ..clear()
          ..addAll(next);
      } else {
        _selected
          ..clear()
          ..add(slot.id);
      }
    });
  }

  bool _isContiguous(List<SlotModel> slots, Set<int> ids) {
    if (ids.length <= 1) return true;
    final chosen = slots.where((s) => ids.contains(s.id)).toList()
      ..sort((a, b) => a.slotStartTime.compareTo(b.slotStartTime));
    for (var i = 1; i < chosen.length; i++) {
      if (chosen[i].slotStartTime != chosen[i - 1].slotEndTime) return false;
    }
    return true;
  }

  Future<void> _submit(CoachModel coach, List<SlotModel> slots) async {
    final chosen = slots.where((s) => _selected.contains(s.id)).toList()
      ..sort((a, b) => a.slotStartTime.compareTo(b.slotStartTime));
    if (chosen.isEmpty) return;

    final booking = await ref.read(coachBookingNotifierProvider.notifier).book(
          coachId: coach.id,
          sessionDate: _date,
          slotIds: chosen.map((s) => s.id).toList(),
          groundId: _venueFor(coach),
          customerNote: _noteController.text.trim(),
        );

    if (!mounted) return;
    if (booking == null) return; // the error banner below shows why

    // The slots the day was showing are now held, so the next reader must not
    // be served the stale list.
    ref.invalidate(
        coachSlotsProvider(CoachSlotQuery(coachId: coach.id, date: _date)));

    // pushReplacement, never push: this session is done, and backing into a
    // completed booking form is how a player books the same slot twice.
    context.pushReplacement('/coach-sessions/${booking.id}');
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final id = int.tryParse(widget.coachId);
    if (id == null) {
      return Scaffold(
        backgroundColor: colors.background,
        appBar: AppBar(title: const Text('Book a coach')),
        body: const ErrorView(message: 'That coach link is not valid'),
      );
    }

    final coachAsync = ref.watch(coachDetailProvider(id));
    final bookingState = ref.watch(coachBookingNotifierProvider);

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(title: const Text('Book a coach')),
      body: Stack(
        children: [
          coachAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: CoachCardShimmer(),
            ),
            error: (e, _) => ErrorView(
              message:
                  apiErrorMessage(e, fallback: 'Could not load this coach'),
              onRetry: () => ref.invalidate(coachDetailProvider(id)),
            ),
            data: (coach) => _form(coach, bookingState),
          ),
          // The wait has to be visible where the person is looking. A spinner
          // inside a CTA that the keyboard is covering is not feedback.
          if (bookingState.isLoading)
            Positioned.fill(
              child: ColoredBox(
                color: Colors.black.withValues(alpha: 0.35),
                child: const Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: coachAsync.maybeWhen(
        data: (coach) {
          final slots = ref
                  .watch(coachSlotsProvider(
                      CoachSlotQuery(coachId: coach.id, date: _date)))
                  .valueOrNull ??
              const <SlotModel>[];
          final count = _selected.length;
          final total = coach.pricePerSlot * count;
          return StickyBottomBar(
            price: count == 0 ? null : '₹${total.toStringAsFixed(0)}',
            priceLabel: count == 0 ? null : 'Total',
            priceCaption: count == 0 ? null : _durationLabel(count),
            buttonText: count == 0 ? 'Pick a time' : 'Request session',
            isLoading: bookingState.isLoading,
            onPressed: count == 0 || bookingState.isLoading
                ? null
                : () => _submit(coach, slots),
            footnote: Text(
              'Paid at the venue',
              style: TextStyle(fontSize: 11, color: colors.textSecondary),
            ),
          );
        },
        orElse: () => null,
      ),
    );
  }

  String _durationLabel(int slotCount) {
    final minutes = slotCount * 30;
    final hours = minutes ~/ 60;
    final mins = minutes % 60;
    if (hours == 0) return '$mins mins';
    if (mins == 0) return '$hours hr${hours == 1 ? '' : 's'}';
    return '$hours hr${hours == 1 ? '' : 's'} $mins mins';
  }

  Widget _form(CoachModel coach, CoachBookingState bookingState) {
    final colors = context.colors;
    final slotsAsync = ref.watch(
        coachSlotsProvider(CoachSlotQuery(coachId: coach.id, date: _date)));

    return ListView(
      // resizeToAvoidBottomInset stays on and the form scrolls, so the note
      // field stays visible when the keyboard opens.
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      children: [
        if (bookingState.error != null) ...[
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.error.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.error.withValues(alpha: 0.4)),
            ),
            child: Row(
              children: [
                const Icon(Icons.error_outline,
                    color: AppColors.error, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(bookingState.error!,
                      style: const TextStyle(color: AppColors.error)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],

        Text(coach.name,
            style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: colors.textPrimary)),
        Text('${coach.formattedRate} ${coach.rateCaption}',
            style: TextStyle(color: colors.textSecondary, fontSize: 13)),
        const SizedBox(height: 24),

        // ── Venue ────────────────────────────────────────────────────────────
        const _Label(text: 'Where'),
        const SizedBox(height: 8),
        if (coach.venues.isEmpty)
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: colors.card,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: colors.border),
            ),
            child: Text(
              'This coach has no approved venue yet — you will agree a place '
              'together after they accept.',
              style: TextStyle(color: colors.textSecondary, fontSize: 13),
            ),
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final venue in coach.venues)
                _ChoiceChip(
                  label: venue.name,
                  selected: _venueFor(coach) == venue.id,
                  onTap: () => setState(() {
                    _venueId = venue.id;
                    _venueChosen = true;
                  }),
                ),
              _ChoiceChip(
                label: 'No venue',
                selected: _venueFor(coach) == null,
                onTap: () => setState(() {
                  _venueId = null;
                  _venueChosen = true;
                }),
              ),
            ],
          ),
        const SizedBox(height: 24),

        // ── Date ─────────────────────────────────────────────────────────────
        const _Label(text: 'When'),
        const SizedBox(height: 8),
        SizedBox(
          height: 76,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _daysAhead,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (_, i) {
              final day = DateTime.now().add(Duration(days: i));
              final iso = _isoDate(day);
              return _DayChip(
                day: day,
                selected: iso == _date,
                onTap: () => setState(() {
                  _date = iso;
                  _selected.clear();
                }),
              );
            },
          ),
        ),
        const SizedBox(height: 24),

        // ── Slots ────────────────────────────────────────────────────────────
        const _Label(text: 'Pick a time'),
        const SizedBox(height: 8),
        slotsAsync.when(
          loading: () => const ShimmerBox(
              width: double.infinity, height: 120, radius: 12),
          error: (e, _) => ErrorView(
            message: apiErrorMessage(e, fallback: 'Could not load times'),
            onRetry: () => ref.invalidate(coachSlotsProvider(
                CoachSlotQuery(coachId: coach.id, date: _date))),
          ),
          data: (slots) {
            final bookable =
                slots.where((s) => s.isAvailable && !s.hasStarted).toList();
            if (bookable.isEmpty) {
              return Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: colors.card,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: colors.border),
                ),
                child: Text(
                  'No free times on this day. Try another date.',
                  style: TextStyle(color: colors.textSecondary),
                ),
              );
            }
            return Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final slot in bookable)
                  SizedBox(
                    width: 104,
                    child: SlotTile(
                      slot: slot,
                      selected: _selected.contains(slot.id),
                      onTap: () => _toggleSlot(bookable, slot),
                    ),
                  ),
              ],
            );
          },
        ),
        const SizedBox(height: 8),
        Text(
          'Sessions are booked in 30-minute blocks, one unbroken stretch.',
          style: TextStyle(fontSize: 12, color: colors.textSecondary),
        ),
        const SizedBox(height: 24),

        // ── Note ─────────────────────────────────────────────────────────────
        const _Label(text: 'Anything your coach should know?'),
        const SizedBox(height: 8),
        TextField(
          controller: _noteController,
          maxLines: 3,
          maxLength: 500,
          decoration: const InputDecoration(
            hintText: 'Optional — what you want to work on',
          ),
        ),
      ],
    );
  }
}

class _Label extends StatelessWidget {
  final String text;
  const _Label({required this.text});

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: context.colors.textPrimary,
        ),
      );
}

class _ChoiceChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ChoiceChip({
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
      label: '$label${selected ? ', selected' : ''}',
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 44),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: selected ? AppColors.accent : colors.input,
            borderRadius: BorderRadius.circular(20),
            border:
                Border.all(color: selected ? AppColors.accent : colors.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Selection is never colour alone — a tick rides along with it.
              if (selected) ...[
                const Icon(Icons.check_rounded,
                    size: 16, color: AppColors.onAccent),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: TextStyle(
                  color: selected ? AppColors.onAccent : colors.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DayChip extends StatelessWidget {
  final DateTime day;
  final bool selected;
  final VoidCallback onTap;

  const _DayChip({
    required this.day,
    required this.selected,
    required this.onTap,
  });

  static const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final label = '${_weekdays[day.weekday - 1]} ${day.day} ${_months[day.month - 1]}';

    return Semantics(
      button: true,
      selected: selected,
      label: '$label${selected ? ', selected' : ''}',
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          width: 64,
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? AppColors.accent : colors.input,
            borderRadius: BorderRadius.circular(12),
            border:
                Border.all(color: selected ? AppColors.accent : colors.border),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                _weekdays[day.weekday - 1],
                style: TextStyle(
                  fontSize: 11,
                  color: selected ? AppColors.onAccent : colors.textSecondary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${day.day}',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: selected ? AppColors.onAccent : colors.textPrimary,
                ),
              ),
              Text(
                _months[day.month - 1],
                style: TextStyle(
                  fontSize: 10,
                  color: selected ? AppColors.onAccent : colors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
