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
        id:             json['id'] as int,
        groundSportId:  json['ground_sport_id'] as int? ?? json['ground_id'] as int? ?? 0,
        slotDate:       json['slot_date'] as String? ?? json['date'] as String? ?? '',
        slotStartTime:  json['slot_start_time'] as String? ?? json['from_time'] as String? ?? '',
        slotEndTime:    json['slot_end_time'] as String? ?? json['to_time'] as String? ?? '',
        isAvailable:    json['is_available'] as bool? ?? !(json['is_booked'] as bool? ?? false),
      );

  static List<SlotModel> listFromJson(List<dynamic> list) =>
      list.map((e) => SlotModel.fromJson(e as Map<String, dynamic>)).toList();

  /// "6:00 AM" style
  String get formattedStart => _fmt(slotStartTime);
  String get formattedEnd   => _fmt(slotEndTime);
  String get timeRange      => '$formattedStart - $formattedEnd';

  String _fmt(String t) {
    final parts = t.split(':');
    if (parts.length < 2) return t;
    final h = int.tryParse(parts[0]) ?? 0;
    final m = parts[1];
    final ampm = h >= 12 ? 'PM' : 'AM';
    final h12  = h == 0 ? 12 : (h > 12 ? h - 12 : h);
    return '$h12:$m $ampm';
  }
}
