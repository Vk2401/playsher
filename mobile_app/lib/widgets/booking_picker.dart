import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/api_error.dart';
import '../core/app_colors.dart';
import '../models/slot_model.dart';
import '../providers/grounds_provider.dart';
import 'error_view.dart';
import 'shimmer_loader.dart';

/// The seven days on offer, and the month they fall in.
///
/// A strip rather than a month grid: a booking is nearly always for today or
/// the next few days, and a full calendar spent half the screen on dates
/// nobody picks. The arrows page a week at a time for the ones who do.
class DateStrip extends StatelessWidget {
  const DateStrip({
    super.key,
    required this.selected,
    required this.firstDay,
    required this.onSelected,
    required this.onPageChanged,
    this.daysAhead = 30,
  });

  /// The day currently booked against.
  final DateTime selected;

  /// The first day of the week on show.
  final DateTime firstDay;

  final ValueChanged<DateTime> onSelected;

  /// Called with the new first-day when the arrows move the window.
  final ValueChanged<DateTime> onPageChanged;

  /// How far ahead the venue takes bookings.
  final int daysAhead;

  static const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  static const _months = [
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

  /// Today on the *device's* clock, which is the clock the person booking is
  /// reading. Every "is this past?" question in the picker starts here.
  DateTime get _today => DateTime.now().dateOnly;
  DateTime get _lastDay => _today.add(Duration(days: daysAhead));

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    // Normalised, and built by calendar day rather than by adding 24h at a
    // time. A `firstDay` carrying a wall-clock time made every cell in the
    // week 20:09:33 while `selectedDay` was midnight, so `day == selectedDay`
    // was false for all seven and nothing highlighted — until an arrow tap
    // happened to replace it with a clean date.
    final start = firstDay.dateOnly;
    final days = [
      for (var i = 0; i < 7; i++)
        DateTime(start.year, start.month, start.day + i),
    ];
    final canGoBack = start.isAfter(_today);
    final canGoOn = days.last.isBefore(_lastDay);
    final selectedDay = selected.dateOnly;
    final weekHoldsSelection = days.any((d) => d == selectedDay);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Select Date',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: colors.textPrimary,
                ),
              ),
            ),
            // Which month the week on show belongs to — the strip only prints
            // day numbers, so without this a week spanning a month boundary is
            // ambiguous. A week that straddles two prints both.
            Text(
              _monthLabel(days.first, days.last),
              style: TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w600,
                color: colors.textSecondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            _Arrow(
              icon: Icons.chevron_left_rounded,
              tooltip: 'Previous week',
              onTap: canGoBack
                  ? () => onPageChanged(_clampWeek(
                      DateTime(start.year, start.month, start.day - 7)))
                  : null,
            ),
            Expanded(
              child: Row(
                children: [
                  for (final day in days)
                    Expanded(
                      child: _DayCell(
                        day: day,
                        selected: day == selectedDay,
                        isToday: day == _today,
                        enabled:
                            !day.isBefore(_today) && !day.isAfter(_lastDay),
                        onTap: () => onSelected(day),
                      ),
                    ),
                ],
              ),
            ),
            _Arrow(
              icon: Icons.chevron_right_rounded,
              tooltip: 'Next week',
              onTap: canGoOn
                  ? () => onPageChanged(_clampWeek(
                      DateTime(start.year, start.month, start.day + 7)))
                  : null,
            ),
          ],
        ),
        // Paging the week carries the strip away from the day being booked.
        // Saying which day that still is — and offering the way back — beats
        // a row with nothing highlighted and no explanation for it.
        if (!weekHoldsSelection) ...[
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => onPageChanged(_clampWeek(selectedDay)),
              icon: const Icon(Icons.event_available_rounded, size: 16),
              label: Text(
                'Booking ${_weekdays[selectedDay.weekday - 1]} '
                '${selectedDay.day} ${_shortMonth(selectedDay.month)} — '
                'jump back',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12.5),
              ),
              style: TextButton.styleFrom(
                foregroundColor: colors.brandText,
                minimumSize: const Size(0, 44),
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
            ),
          ),
        ],
      ],
    );
  }

  String _monthLabel(DateTime first, DateTime last) => first.month == last.month
      ? '${_months[first.month - 1]} ${first.year}'
      : '${_shortMonth(first.month)} – ${_shortMonth(last.month)} ${last.year}';

  DateTime _clampWeek(DateTime candidate) =>
      candidate.isBefore(_today) ? _today : candidate;

  static String _shortMonth(int month) => _months[month - 1].substring(0, 3);
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.selected,
    required this.isToday,
    required this.enabled,
    required this.onTap,
  });

  final DateTime day;
  final bool selected;
  final bool isToday;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final weekday = DateStrip._weekdays[day.weekday - 1];
    // "Today" earns the weekday's line: it is the day most bookings are for,
    // and the date under it still says which day of the week it is.
    final topLine = isToday ? 'Today' : weekday;

    // A tint behind the selected day read as "slightly warmer card" beside
    // six others. A fill reads as chosen from across the room.
    final ink = !enabled
        ? colors.border
        : selected
            ? AppColors.onPrimary
            : colors.textPrimary;
    final subInk = !enabled
        ? colors.border
        : selected
            ? AppColors.onPrimaryMuted
            : colors.textSecondary;

    Widget line(String text, double size, FontWeight weight, Color color) =>
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            text,
            maxLines: 1,
            style: TextStyle(fontSize: size, fontWeight: weight, color: color),
          ),
        );

    return Semantics(
      label: '$weekday ${day.day} ${DateStrip._shortMonth(day.month)}'
          '${isToday ? ', today' : ''}${enabled ? '' : ', unavailable'}',
      selected: selected,
      enabled: enabled,
      button: true,
      child: GestureDetector(
        onTap: enabled ? onTap : null,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          margin: const EdgeInsets.symmetric(horizontal: 3),
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            color: selected ? AppColors.primary : colors.card,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              // Today keeps a ring even when it is not the chosen day, so the
              // strip always says where "now" is.
              color: selected
                  ? AppColors.primary
                  : isToday && enabled
                      ? AppColors.primary.withValues(alpha: 0.45)
                      : colors.border,
              width: selected || isToday ? 1.6 : 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              line(topLine, 11.5, FontWeight.w600, subInk),
              const SizedBox(height: 2),
              line('${day.day}', 18, FontWeight.w800, ink),
              const SizedBox(height: 1),
              line(DateStrip._shortMonth(day.month), 11, FontWeight.w400,
                  subInk),
            ],
          ),
        ),
      ),
    );
  }
}

class _Arrow extends StatelessWidget {
  const _Arrow({required this.icon, required this.tooltip, this.onTap});

  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final enabled = onTap != null;

    return IconButton(
      icon: Icon(icon, size: 22),
      tooltip: tooltip,
      color: enabled ? colors.textPrimary : colors.border,
      onPressed: onTap,
      // 40 wide keeps seven day cells legible on a 360dp phone; the height
      // still clears the 44 minimum.
      constraints: const BoxConstraints(minWidth: _arrowWidth, minHeight: 44),
      padding: EdgeInsets.zero,
    );
  }
}

/// The quarters of the day a slot can fall in.
enum SlotPeriod {
  morning('Morning', '6 AM – 12 PM', 6, 12, Icons.wb_sunny_outlined),
  afternoon('Afternoon', '12 PM – 6 PM', 12, 18, Icons.wb_sunny_rounded),
  evening('Evening', '6 PM – 12 AM', 18, 24, Icons.wb_twilight_rounded),
  night('Night', '12 AM – 6 AM', 0, 6, Icons.nightlight_round);

  const SlotPeriod(
      this.label, this.range, this.fromHour, this.toHour, this.icon);

  final String label;
  final String range;
  final int fromHour;
  final int toHour;
  final IconData icon;

  bool holds(SlotModel slot) {
    final hour = int.tryParse(slot.slotStartTime.split(':').first);
    if (hour == null) return false;
    return hour >= fromHour && hour < toHour;
  }
}

/// The four period tabs above the slots.
class SlotPeriodBar extends StatelessWidget {
  const SlotPeriodBar({
    super.key,
    required this.selected,
    required this.onSelected,
    required this.countFor,
  });

  final SlotPeriod selected;
  final ValueChanged<SlotPeriod> onSelected;

  /// How many bookable slots each period holds, so a period with none can say
  /// so instead of opening onto an empty row.
  final int Function(SlotPeriod) countFor;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Container(
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.border),
      ),
      // The tabs fill their cells edge to edge and let the bar clip the two
      // outer corners. Rounding each tab instead left the selected one as a
      // pill floating inside its cell, with its underline curling away from
      // the dividers at both ends.
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final period in SlotPeriod.values) ...[
              if (period != SlotPeriod.values.first)
                Container(width: 1, color: colors.border),
              Expanded(
                child: _PeriodTab(
                  period: period,
                  selected: period == selected,
                  count: countFor(period),
                  onTap: () => onSelected(period),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PeriodTab extends StatelessWidget {
  const _PeriodTab({
    required this.period,
    required this.selected,
    required this.count,
    required this.onTap,
  });

  final SlotPeriod period;
  final bool selected;

  /// How many slots are left in this period — the number that decides whether
  /// the tab is worth a tap.
  final int count;

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final empty = count == 0;
    final tint = selected
        ? colors.brandText
        : empty
            ? colors.border
            : colors.textSecondary;

    Widget line(String text, double size, FontWeight weight) => FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            text,
            maxLines: 1,
            style: TextStyle(fontSize: size, fontWeight: weight, color: tint),
          ),
        );

    return Semantics(
      selected: selected,
      button: true,
      label: '${period.label}, ${period.range}, '
          '${empty ? 'no slots left' : '$count slots left'}',
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.primary.withValues(alpha: 0.10)
                : Colors.transparent,
            // Square: SlotPeriodBar clips the two corners that are actually on
            // the outside. A radius here would round all four on every tab.
            // The underline is the part of "selected" that survives being
            // read in greyscale.
            border: Border(
              bottom: BorderSide(
                color: selected ? AppColors.primary : Colors.transparent,
                width: 2.5,
              ),
            ),
          ),
          padding: const EdgeInsets.fromLTRB(4, 10, 4, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(period.icon, size: 19, color: tint),
              const SizedBox(height: 5),
              line(period.label, 12.5,
                  selected ? FontWeight.w700 : FontWeight.w600),
              const SizedBox(height: 2),
              // A greyed-out tab is not a readable state on its own — a tab
              // with nothing left says so in words.
              line(empty ? 'No slots' : '$count left', 10.5, FontWeight.w600),
              const SizedBox(height: 1),
              line(period.range, 10, FontWeight.w400),
            ],
          ),
        ),
      ),
    );
  }
}

/// What the colours on the slots mean.
///
/// Each state is a shape and a word as well as a colour, so the row reads in
/// greyscale — but the legend is still the thing that names them.
class SlotLegend extends StatelessWidget {
  const SlotLegend({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    Widget entry(Color dot, String label) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 9,
              height: 9,
              decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
            Text(label,
                style: TextStyle(fontSize: 12.5, color: colors.textSecondary)),
          ],
        );

    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 18,
      runSpacing: 6,
      children: [
        entry(AppColors.success, 'Available'),
        entry(AppColors.primary, 'Selected'),
        entry(colors.border, 'Booked'),
      ],
    );
  }
}

/// One half-hour, priced.
///
/// Sized from the design rather than by eye: in the mock a card is 11.9% of
/// the screen's width and half again as tall, so six sit across the row. Built
/// at a comfortable-looking 100-odd points it took the place of three, which
/// is the difference between "a row of times" and "three big buttons".
class SlotCard extends StatelessWidget {
  const SlotCard({
    super.key,
    required this.slot,
    required this.price,
    required this.selected,
    required this.onTap,
    required this.width,
  });

  final SlotModel slot;
  final String price;
  final bool selected;
  final double width;

  /// Null for a slot that cannot be taken — booked, or already started.
  final VoidCallback? onTap;

  static const heightRatio = 1.32;
  static const _radiusRatio = 0.16;

  /// How many cards sit across the row.
  ///
  /// The mock fits six, but the mock is an artboard: at six on a real phone
  /// the card is under fifty points wide and the times inside it shrink to
  /// the point of being hard to read and hard to hit. Four is the same idea
  /// at a size that survives contact with a thumb — the row still reads as a
  /// timeline you scroll along rather than a stack of buttons.
  static const _perRow = 4;
  static const gap = 8.0;

  /// The width one card gets when the row is shared between [_perRow] of
  /// them — clamped so a very narrow or very wide phone still reads.
  static double widthFor(double available) =>
      ((available - gap * (_perRow - 1)) / _perRow).clamp(70.0, 104.0);

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final bookable = onTap != null;

    // Three states, each a fill *and* an ink — the tick below carries the
    // selected one a fourth way, so none of them depends on seeing colour.
    final (background, border, ink) = selected
        ? (AppColors.primary, AppColors.primary, AppColors.onPrimary)
        : bookable
            ? (
                AppColors.success.withValues(alpha: 0.08),
                AppColors.success.withValues(alpha: 0.30),
                colors.successText,
              )
            // Booked: the card surface, as the design has it, with the border
            // and the muted ink doing the work the green does elsewhere.
            : (colors.card, colors.border, colors.textSecondary);

    return Semantics(
      button: bookable,
      selected: selected,
      label: '${slot.timeRange}, $price${bookable ? '' : ', booked'}',
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: width,
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(width * _radiusRatio),
            border: Border.all(color: border, width: selected ? 1.4 : 1),
          ),
          // Scaled down as a whole rather than line by line: the card is
          // deliberately small, and four lines of type in it will outgrow any
          // fixed height at a large text scale. Shrinking the block keeps the
          // design's proportions instead of clipping or overflowing.
          child: Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _Line(slot.formattedStart, ink, bold: true),
                  _Line('–', ink),
                  _Line(slot.formattedEnd, ink, bold: true),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _Line(price, ink, bold: true),
                      if (selected) ...[
                        const SizedBox(width: 3),
                        // A white disc with the fill showing through the tick.
                        const Icon(Icons.check_circle,
                            size: 15, color: AppColors.onPrimary),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// One line of a slot card, shrunk to fit rather than wrapped or clipped: the
/// card is narrow by design and "12:30 PM" is wider than "7:00 AM".
class _Line extends StatelessWidget {
  const _Line(this.text, this.color, {this.bold = false});

  final String text;
  final Color color;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      maxLines: 1,
      style: TextStyle(
        fontSize: 13,
        height: 1.2,
        fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
        color: color,
      ),
    );
  }
}

extension DateOnly on DateTime {
  /// The day this instant falls on, with the clock discarded — what a booking
  /// date actually is.
  DateTime get dateOnly => DateTime(year, month, day);
}

/// The whole time-of-day picker: which quarter of the day, the slots in it,
/// and what the colours mean.
///
/// It owns the period and the view because it is the thing that knows what
/// slots exist — the parent cannot say "Morning has none" without them.
class SlotPicker extends ConsumerStatefulWidget {
  const SlotPicker({
    super.key,
    required this.groundSportId,
    required this.date,
    required this.price,
    required this.selectedSlots,
    required this.onSlotToggle,
    required this.maxSlots,
  });

  final int groundSportId;
  final String date;

  /// How many slots this venue takes in one booking. Printed under the row so
  /// the rule is known before it is hit, rather than only when a tap is
  /// refused.
  final int maxSlots;

  /// The venue's price for one slot, already formatted.
  final String price;

  final Set<int> selectedSlots;
  final ValueChanged<int> onSlotToggle;

  @override
  ConsumerState<SlotPicker> createState() => _SlotPickerState();
}

class _SlotPickerState extends ConsumerState<SlotPicker> {
  /// The period the user asked for, or null while the picker is still
  /// choosing one for them.
  ///
  /// Both behaviours are wanted and they conflict: on arrival the row should
  /// open on a period that has something in it, but once a tab is tapped that
  /// tab is the answer — even when the answer is "nothing tonight". Falling
  /// back for a *tapped* period is what made Night look broken: the tap
  /// bounced back to Morning and showed morning slots.
  SlotPeriod? _chosen;
  bool _timeline = true;
  Timer? _clock;

  @override
  void initState() {
    super.initState();
    // A picker left open while the hour turns is still offering slots that
    // have since started. Re-reading the clock once a minute drops them — and
    // empties the period they were the last of — without a pull to refresh.
    _clock = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _clock?.cancel();
    super.dispose();
  }

  /// The first period of the day that still has something in it, so the row
  /// does not open empty on a morning that is already over.
  SlotPeriod _firstWithSlots(List<SlotModel> slots) {
    for (final period in SlotPeriod.values) {
      if (slots.any(period.holds)) return period;
    }
    return SlotPeriod.morning;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final query =
        SlotQuery(groundSportId: widget.groundSportId, date: widget.date);
    final slotsAsync = ref.watch(slotsProvider(query));

    return slotsAsync.when(
      loading: () => const SlotGridShimmer(),
      error: (e, _) => ErrorView(
        message:
            apiErrorMessage(e, fallback: 'Could not load slots for this date'),
        onRetry: () => ref.invalidate(slotsProvider(query)),
      ),
      data: (allSlots) {
        // Second line of defence behind the API's own filter, read against
        // the device's own clock: never offer a slot whose start time has
        // gone by, or the tap dies at checkout. A future date keeps every
        // slot — the comparison is against an instant, not a time of day.
        final slots = allSlots.where((s) => !s.hasStarted).toList();

        if (slots.isEmpty) {
          // "Today is over" is a different answer from "this venue is shut",
          // and sending someone to tomorrow is only useful for the first one.
          return _Empty(dayIsSpent: allSlots.isNotEmpty);
        }

        final period = _chosen ?? _firstWithSlots(slots);
        final inPeriod = slots.where(period.holds).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _ViewToggle(
              timeline: _timeline,
              onChanged: (v) => setState(() => _timeline = v),
            ),
            const SizedBox(height: 12),
            SlotPeriodBar(
              selected: period,
              onSelected: (p) => setState(() => _chosen = p),
              countFor: (p) => slots.where(p.holds).length,
            ),
            const SizedBox(height: 14),
            if (inPeriod.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Text(
                  'No slots left this ${period.label.toLowerCase()}.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: colors.textSecondary),
                ),
              )
            else if (_timeline)
              _Timeline(
                // Keyed so each period gets its own controller. Carried from
                // one period to the next, the offset and the scroll extent
                // belonged to a row that was no longer there: a short evening
                // opened halfway along, and the arrows greyed against a
                // length that no longer existed.
                key: ValueKey('${widget.date}-${period.name}'),
                slots: inPeriod,
                price: widget.price,
                selectedSlots: widget.selectedSlots,
                onSlotToggle: widget.onSlotToggle,
              )
            else
              LayoutBuilder(
                builder: (context, constraints) {
                  final cardWidth = SlotCard.widthFor(constraints.maxWidth);
                  return Wrap(
                    spacing: SlotCard.gap,
                    runSpacing: SlotCard.gap,
                    children: [
                      for (final slot in inPeriod)
                        SizedBox(
                          height: cardWidth * SlotCard.heightRatio,
                          child: SlotCard(
                            slot: slot,
                            width: cardWidth,
                            price: widget.price,
                            selected: widget.selectedSlots.contains(slot.id),
                            onTap: slot.isAvailable
                                ? () => widget.onSlotToggle(slot.id)
                                : null,
                          ),
                        ),
                    ],
                  );
                },
              ),
            const SizedBox(height: 14),
            const SlotLegend(),
            if (widget.maxSlots > 0) ...[
              const SizedBox(height: 8),
              Text(
                'Up to ${widget.maxSlots} '
                '${widget.maxSlots == 1 ? 'slot' : 'slots'} per booking',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12.5, color: colors.textSecondary),
              ),
            ],
          ],
        );
      },
    );
  }
}

/// Timeline or grid. The same slots either way — one row you scroll along, or
/// the whole period at once.
class _ViewToggle extends StatelessWidget {
  const _ViewToggle({required this.timeline, required this.onChanged});

  final bool timeline;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    Widget half(String label, IconData icon, bool isTimeline) {
      final on = timeline == isTimeline;
      return Expanded(
        child: Semantics(
          selected: on,
          button: true,
          child: GestureDetector(
            onTap: () => onChanged(isTimeline),
            behavior: HitTestBehavior.opaque,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              height: 44,
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 6),
              decoration: BoxDecoration(
                color: on ? AppColors.primary : Colors.transparent,
                borderRadius: BorderRadius.circular(10),
              ),
              // Scaled as a block rather than wrapped: the toggle is a fixed
              // width and "Timeline" beside its glyph outgrows half of it at
              // a large text scale.
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      icon,
                      size: 15,
                      color: on ? AppColors.onPrimary : colors.textSecondary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      label,
                      maxLines: 1,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: on ? FontWeight.w700 : FontWeight.w600,
                        color: on ? AppColors.onPrimary : colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        width: 200,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: colors.input,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            half('Timeline', Icons.view_week_rounded, true),
            half('Grid', Icons.grid_view_rounded, false),
          ],
        ),
      ),
    );
  }
}

class _Timeline extends StatefulWidget {
  const _Timeline({
    super.key,
    required this.slots,
    required this.price,
    required this.selectedSlots,
    required this.onSlotToggle,
  });

  final List<SlotModel> slots;
  final String price;
  final Set<int> selectedSlots;
  final ValueChanged<int> onSlotToggle;

  @override
  State<_Timeline> createState() => _TimelineState();
}

class _TimelineState extends State<_Timeline> {
  /// Owned here, not passed in, so it dies with the row it measures.
  final _controller = ScrollController();

  @override
  void initState() {
    super.initState();
    // The arrows grey out at each end, so they have to hear the row move —
    // by finger as well as by tap.
    _controller.addListener(_onScroll);
    // And they have to hear the *first* layout. On the frame this is built
    // the controller has no clients yet, so there is nothing to page through
    // and both arrows come up disabled; without this nudge nothing would ever
    // scroll the row, so no scroll notification would arrive to enable them,
    // and they would stay dead.
    WidgetsBinding.instance.addPostFrameCallback((_) => _onScroll());
  }

  @override
  void didUpdateWidget(_Timeline old) {
    super.didUpdateWidget(old);
    // The same period can gain or lose a slot without the key changing — a
    // minute passes, someone else books. Re-measure once it has re-laid out.
    if (old.slots.length != widget.slots.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _onScroll());
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onScroll);
    _controller.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (mounted) setState(() {});
  }

  /// Nearly a full screenful, so the slot you were looking at stays in view
  /// as an anchor rather than the row jumping to somewhere unrecognisable.
  void _page(int direction) {
    if (!_controller.hasClients) return;
    final position = _controller.position;
    final target =
        (position.pixels + direction * position.viewportDimension * 0.8)
            .clamp(position.minScrollExtent, position.maxScrollExtent);
    _controller.animateTo(
      target,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final ready =
        _controller.hasClients && _controller.position.hasContentDimensions;
    final position = ready ? _controller.position : null;

    return LayoutBuilder(
      builder: (context, constraints) {
        // The arrows take their width off the row before the cards are
        // measured, so six still fit between them.
        final rowWidth = constraints.maxWidth - _arrowWidth * 2;
        final cardWidth = SlotCard.widthFor(rowWidth);
        // The row cannot size itself to its children, and the card's four
        // lines grow with the text scale, so the height follows both.
        final height = MediaQuery.textScalerOf(context)
            .scale(cardWidth * SlotCard.heightRatio)
            .clamp(cardWidth * SlotCard.heightRatio, 190.0);

        // Whether there is anything to page to, worked out from the cards
        // themselves rather than from the scroll position. The position is
        // only consulted to say *which* end you are at, and only once it
        // exists: relying on it for the forward arrow meant the arrow was
        // dead until something else scrolled the row — which is to say,
        // until the arrow was no longer needed.
        final content = widget.slots.length * cardWidth +
            (widget.slots.length - 1) * SlotCard.gap;
        final overflows = content > rowWidth + 1;
        final canGoBack = position != null && position.pixels > 1;
        final canGoOn = position != null
            ? position.pixels < position.maxScrollExtent - 1
            : overflows;

        return Column(
          children: [
            Row(
              children: [
                _Arrow(
                  icon: Icons.chevron_left_rounded,
                  tooltip: 'Earlier slots',
                  onTap: canGoBack ? () => _page(-1) : null,
                ),
                Expanded(
                  child: SizedBox(
                    height: height,
                    child: ListView.separated(
                      controller: _controller,
                      scrollDirection: Axis.horizontal,
                      padding: EdgeInsets.zero,
                      itemCount: widget.slots.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(width: SlotCard.gap),
                      itemBuilder: (_, i) => SlotCard(
                        slot: widget.slots[i],
                        width: cardWidth,
                        price: widget.price,
                        selected:
                            widget.selectedSlots.contains(widget.slots[i].id),
                        onTap: widget.slots[i].isAvailable
                            ? () => widget.onSlotToggle(widget.slots[i].id)
                            : null,
                      ),
                    ),
                  ),
                ),
                _Arrow(
                  icon: Icons.chevron_right_rounded,
                  tooltip: 'Later slots',
                  onTap: canGoOn ? () => _page(1) : null,
                ),
              ],
            ),
            const SizedBox(height: 10),
            _ScrollDots(controller: _controller),
          ],
        );
      },
    );
  }
}

/// What an [_Arrow] costs the row it flanks.
const _arrowWidth = 34.0;

/// How far along the row you are.
///
/// Driven by the scroll offset rather than by paging: the slots scroll freely,
/// which is the right feel for a row of times, and the dots are then a
/// position readout rather than a control.
class _ScrollDots extends StatefulWidget {
  const _ScrollDots({required this.controller});

  final ScrollController controller;

  @override
  State<_ScrollDots> createState() => _ScrollDotsState();
}

class _ScrollDotsState extends State<_ScrollDots> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onScroll);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onScroll);
    super.dispose();
  }

  void _onScroll() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    // Before the row has been laid out there is no scroll extent to read, and
    // asking for one throws rather than answering zero.
    if (!widget.controller.hasClients) return const SizedBox(height: 6);
    final position = widget.controller.position;
    if (!position.hasContentDimensions || position.viewportDimension <= 0) {
      return const SizedBox(height: 6);
    }
    final pages = (position.maxScrollExtent / position.viewportDimension)
            .ceil()
            .clamp(1, 8) +
        1;
    if (pages <= 1) return const SizedBox(height: 6);

    final current = position.maxScrollExtent <= 0
        ? 0
        : ((position.pixels / position.maxScrollExtent) * (pages - 1))
            .round()
            .clamp(0, pages - 1);

    return ExcludeSemantics(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 0; i < pages; i++)
            AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: i == current ? 18 : 6,
              height: 6,
              decoration: BoxDecoration(
                color: i == current ? AppColors.primary : colors.border,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
        ],
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.dayIsSpent});

  final bool dayIsSpent;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Center(
        child: Text(
          dayIsSpent
              ? "Today's slots have all started. Try another date."
              : 'No slots available for this date.',
          textAlign: TextAlign.center,
          style: TextStyle(color: context.colors.textSecondary),
        ),
      ),
    );
  }
}
