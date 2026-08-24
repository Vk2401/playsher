class SlotModel {
  final int id;
  final int groundSportId;
  final String slotDate;
  final String slotStartTime;
  final String slotEndTime;
  final bool isAvailable;

  const SlotModel({
    required this.id,
    required this.groundSportId,
    required this.slotDate,
    required this.slotStartTime,
    required this.slotEndTime,
    this.isAvailable = true,
  });

  factory SlotModel.fromJson(Map<String, dynamic> json) => SlotModel(
        id: json['id'] as int,
        groundSportId:
            json['ground_sport_id'] as int? ?? json['ground_id'] as int? ?? 0,
        slotDate: json['slot_date'] as String? ?? json['date'] as String? ?? '',
        slotStartTime: json['slot_start_time'] as String? ??
            json['from_time'] as String? ??
            '',
        slotEndTime: json['slot_end_time'] as String? ??
            json['to_time'] as String? ??
            '',
        isAvailable: json['is_available'] as bool? ??
            !(json['is_booked'] as bool? ?? false),
      );

  static List<SlotModel> listFromJson(List<dynamic> list) =>
      list.map((e) => SlotModel.fromJson(e as Map<String, dynamic>)).toList();

  /// Has this slot's start time already passed?
  ///
  /// The API filters past slots out, but a screen left open while the hour
  /// turns, a cached response, or a server whose clock is not on the venue's
  /// timezone can still surface one — and it fails at checkout. Guarding on
  /// the device clock too — the clock the person booking is reading — means
  /// an unbookable slot is never offered.
  bool get hasStarted {
    final start = startsAt;
    return start != null && !start.isAfter(DateTime.now());
  }

  /// When this slot begins, on the device's own clock.
  DateTime? get startsAt {
    final day = _calendarDay;
    if (day == null) return null;
    final parts = slotStartTime.split(':');
    if (parts.length < 2) return null;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null) return null;
    return DateTime(day.year, day.month, day.day, h, m);
  }

  /// The calendar day `slot_date` names, whatever else the string carries.
  ///
  /// Read as a *day*, never as an instant. A server that serialises the date
  /// with a zone — "2026-08-23T18:30:00.000Z" is IST midnight on the 24th —
  /// parses an instant that falls on the day before, and every slot on a
  /// perfectly bookable future date would then read as already started.
  DateTime? get _calendarDay {
    final text = slotDate.split('T').first.split(' ').first;
    final parts = text.split('-');
    if (parts.length < 3) return null;
    final y = int.tryParse(parts[0]);
    final mo = int.tryParse(parts[1]);
    final d = int.tryParse(parts[2]);
    if (y == null || mo == null || d == null) return null;
    return DateTime(y, mo, d);
  }

  /// "6:00 AM" style
  String get formattedStart => _fmt(slotStartTime);
  String get formattedEnd => _fmt(slotEndTime);
  String get timeRange => '$formattedStart - $formattedEnd';

  String _fmt(String t) {
    final parts = t.split(':');
    if (parts.length < 2) return t;
    final h = int.tryParse(parts[0]) ?? 0;
    final m = parts[1];
    final ampm = h >= 12 ? 'PM' : 'AM';
    final h12 = h == 0 ? 12 : (h > 12 ? h - 12 : h);
    return '$h12:$m $ampm';
  }
}
