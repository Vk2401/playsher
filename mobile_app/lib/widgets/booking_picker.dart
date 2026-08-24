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
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];

  DateTime get _today => DateTime.now().dateOnly;
  DateTime get _lastDay => _today.add(Duration(days: daysAhead));

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final days = [for (var i = 0; i < 7; i++) firstDay.add(Duration(days: i))];
    final canGoBack = firstDay.isAfter(_today);
    final canGoOn = days.last.isBefore(_lastDay);

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
            // ambiguous.
            Text(
              '${_months[days.first.month - 1]} ${days.first.year}',
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
                      firstDay.subtract(const Duration(days: 7))))
                  : null,
            ),
            Expanded(
              child: Row(
                children: [
                  for (final day in days)
                    Expanded(
                      child: _DayCell(
                        day: day,
                        selected: day == selected.dateOnly,
                        enabled: !day.isBefore(_today) && !day.isAfter(_lastDay),
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
                  ? () =>
                      onPageChanged(_clampWeek(firstDay.add(const Duration(days: 7))))
                  : null,
            ),
          ],
        ),
      ],
    );
  }

  DateTime _clampWeek(DateTime candidate) =>
      candidate.isBefore(_today) ? _today : candidate;
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final DateTime day;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final weekday = DateStrip._weekdays[day.weekday - 1];

    return Semantics(
      label: '$weekday ${day.day}',
      selected: selected,
      button: true,
      child: GestureDetector(
        onTap: enabled ? onTap : null,
        behavior: HitTestBehavior.opaque,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 3),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.primary.withValues(alpha: 0.10)
                : colors.card,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? AppColors.primary : colors.border,
              width: selected ? 1.6 : 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                weekday,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: !enabled
                      ? colors.border
                      : selected
                          ? colors.brandText
                          : colors.textSecondary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${day.day}',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: !enabled
                      ? colors.border
                      : selected
                          ? colors.brandText
                          : colors.textPrimary,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                _shortMonth(day.month),
                style: TextStyle(
                  fontSize: 11,
                  color: !enabled ? colors.border : colors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _shortMonth(int month) =>
      DateStrip._months[month - 1].substring(0, 3);
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
      constraints: const BoxConstraints(minWidth: 34, minHeight: 44),
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

  const SlotPeriod(this.label, this.range, this.fromHour, this.toHour, this.icon);

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
      child: Row(
        children: [
          for (final period in SlotPeriod.values) ...[
            if (period != SlotPeriod.values.first)
              Container(width: 1, height: 34, color: colors.border),
            Expanded(
              child: _PeriodTab(
                period: period,
                selected: period == selected,
                empty: countFor(period) == 0,
                onTap: () => onSelected(period),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PeriodTab extends StatelessWidget {
  const _PeriodTab({
    required this.period,
    required this.selected,
    required this.empty,
    required this.onTap,
  });

  final SlotPeriod period;
  final bool selected;
  final bool empty;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final tint = selected
        ? colors.brandText
        : empty
            ? colors.border
            : colors.textSecondary;

    return Semantics(
      selected: selected,
      button: true,
      label: '${period.label}, ${period.range}'
          '${empty ? ', no slots' : ''}',
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(period.icon, size: 19, color: tint),
              const SizedBox(height: 5),
              Text(
                period.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                  color: tint,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                period.range,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 10.5, color: tint),
              ),
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
class SlotCard extends StatelessWidget {
  const SlotCard({
    super.key,
    required this.slot,
    required this.price,
    required this.selected,
    required this.onTap,
  });

  final SlotModel slot;
  final String price;
  final bool selected;

  /// Null for a slot that cannot be taken — booked, or already started.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final bookable = onTap != null;

    final background = selected
        ? AppColors.primary
        : bookable
            ? AppColors.success.withValues(alpha: 0.10)
            : colors.input;
    final ink = selected
        ? AppColors.onPrimary
        : bookable
            ? colors.successText
            : colors.textSecondary;

    return Semantics(
      button: bookable,
      selected: selected,
      label: '${slot.timeRange}, $price'
          '${bookable ? '' : ', booked'}',
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 108,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected
                  ? AppColors.primary
                  : bookable
                      ? AppColors.success.withValues(alpha: 0.35)
                      : colors.border,
              width: selected ? 1.6 : 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                slot.formattedStart,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: ink,
                ),
              ),
              Text('–', style: TextStyle(fontSize: 12, color: ink)),
              Text(
                slot.formattedEnd,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: ink,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Flexible(
                    child: Text(
                      price,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: ink,
                      ),
                    ),
                  ),
                  // The tick is what says "selected" without relying on the
                  // fill's colour.
                  if (selected) ...[
                    const SizedBox(width: 4),
                    const Icon(Icons.check_circle_rounded,
                        size: 15, color: AppColors.onPrimary),
                  ],
                ],
              ),
            ],
          ),
        ),
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
  });

  final int groundSportId;
  final String date;

  /// The venue's price for one slot, already formatted.
  final String price;

  final Set<int> selectedSlots;
  final ValueChanged<int> onSlotToggle;

  @override
  ConsumerState<SlotPicker> createState() => _SlotPickerState();
}

class _SlotPickerState extends ConsumerState<SlotPicker> {
  SlotPeriod _period = SlotPeriod.morning;
  bool _timeline = true;
  final _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
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
        // Second line of defence behind the API's own filter: never offer a
        // slot whose start time has gone by, or the tap dies at checkout.
        final slots = allSlots.where((s) => !s.hasStarted).toList();

        if (slots.isEmpty) {
          // "Today is over" is a different answer from "this venue is shut",
          // and sending someone to tomorrow is only useful for the first one.
          return _Empty(dayIsSpent: allSlots.isNotEmpty);
        }

        final period =
            slots.any(_period.holds) ? _period : _firstWithSlots(slots);
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
              onSelected: (p) => setState(() => _period = p),
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
                slots: inPeriod,
                controller: _scroll,
                price: widget.price,
                selectedSlots: widget.selectedSlots,
                onSlotToggle: widget.onSlotToggle,
              )
            else
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final slot in inPeriod)
                    SlotCard(
                      slot: slot,
                      price: widget.price,
                      selected: widget.selectedSlots.contains(slot.id),
                      onTap: slot.isAvailable
                          ? () => widget.onSlotToggle(slot.id)
                          : null,
                    ),
                ],
              ),
            const SizedBox(height: 14),
            const SlotLegend(),
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

    Widget half(String label, bool isTimeline) {
      final on = timeline == isTimeline;
      return Expanded(
        child: Semantics(
          selected: on,
          button: true,
          child: GestureDetector(
            onTap: () => onChanged(isTimeline),
            behavior: HitTestBehavior.opaque,
            child: Container(
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: on
                    ? AppColors.primary.withValues(alpha: 0.10)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: on ? AppColors.primary : Colors.transparent,
                  width: 1.4,
                ),
              ),
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: on ? FontWeight.w700 : FontWeight.w600,
                  color: on ? colors.brandText : colors.textSecondary,
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
        width: 180,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: colors.input,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(children: [half('Timeline', true), half('Grid', false)]),
      ),
    );
  }
}

class _Timeline extends StatelessWidget {
  const _Timeline({
    required this.slots,
    required this.controller,
    required this.price,
    required this.selectedSlots,
    required this.onSlotToggle,
  });

  final List<SlotModel> slots;
  final ScrollController controller;
  final String price;
  final Set<int> selectedSlots;
  final ValueChanged<int> onSlotToggle;

  @override
  Widget build(BuildContext context) {
    // The row's height has to follow the text, not a fixed number: at a large
    // text scale the card's four lines are taller than any constant, and a
    // horizontal ListView cannot size itself to its children.
    final height = MediaQuery.textScalerOf(context).scale(150).clamp(150.0, 240.0);

    return Column(
      children: [
        SizedBox(
          height: height,
          child: ListView.separated(
            controller: controller,
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.zero,
            itemCount: slots.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (_, i) => SlotCard(
              slot: slots[i],
              price: price,
              selected: selectedSlots.contains(slots[i].id),
              onTap: slots[i].isAvailable
                  ? () => onSlotToggle(slots[i].id)
                  : null,
            ),
          ),
        ),
        const SizedBox(height: 10),
        _ScrollDots(controller: controller),
      ],
    );
  }
}

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
