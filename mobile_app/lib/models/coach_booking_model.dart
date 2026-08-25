/// A coaching session the customer booked.
///
/// A session is created `pending` and stays there until the coach accepts it —
/// so "booked" on this screen means "requested and the time is held", which is
/// what [statusLabel] has to say rather than implying it is settled.
class CoachBookingModel {
  final int id;
  final int coachId;
  final String coachName;
  final String? coachPhoto;
  final String? coachMobile;
  final String? sportName;
  final int? groundId;
  final String? groundName;
  final String? groundLocality;
  final String sessionDate;
  final String timeFrom;
  final String timeTo;
  final double totalAmount;
  final String status;
  final String? bookingReference;
  final String? customerNote;
  final String? coachNote;
  final String? cancellationReason;

  const CoachBookingModel({
    required this.id,
    required this.coachId,
    required this.coachName,
    this.coachPhoto,
    this.coachMobile,
    this.sportName,
    this.groundId,
    this.groundName,
    this.groundLocality,
    required this.sessionDate,
    required this.timeFrom,
    required this.timeTo,
    this.totalAmount = 0,
    this.status = 'pending',
    this.bookingReference,
    this.customerNote,
    this.coachNote,
    this.cancellationReason,
  });

  factory CoachBookingModel.fromJson(Map<String, dynamic> json) {
    final coach = json['coach'] as Map<String, dynamic>?;
    final ground = json['ground'] as Map<String, dynamic>?;

    return CoachBookingModel(
      id: json['id'] as int,
      coachId: json['coach_id'] as int? ?? coach?['id'] as int? ?? 0,
      coachName: coach?['name'] as String? ?? 'Coach',
      coachPhoto: coach?['profile_picture'] as String?,
      coachMobile: coach?['mobile'] as String?,
      sportName: coach?['sport_name'] as String?,
      groundId: json['ground_id'] as int?,
      groundName: ground?['name'] as String?,
      groundLocality: [ground?['area'], ground?['city']]
          .whereType<String>()
          .where((p) => p.isNotEmpty)
          .join(', '),
      sessionDate: json['session_date']?.toString().split('T').first ?? '',
      timeFrom: json['time_from'] as String? ?? '',
      timeTo: json['time_to'] as String? ?? '',
      totalAmount:
          double.tryParse(json['total_amount']?.toString() ?? '0') ?? 0,
      status: json['status'] as String? ?? 'pending',
      bookingReference: json['booking_reference'] as String?,
      customerNote: json['customer_note'] as String?,
      coachNote: json['coach_note'] as String?,
      cancellationReason: json['cancellation_reason'] as String?,
    );
  }

  static List<CoachBookingModel> listFromJson(List<dynamic> list) => list
      .map((e) => CoachBookingModel.fromJson(e as Map<String, dynamic>))
      .toList();

  bool get isCancellable => status == 'pending' || status == 'confirmed';

  /// Said from the customer's side: `pending` is the coach's move, not theirs.
  String get statusLabel {
    switch (status) {
      case 'pending':
        return 'Awaiting coach';
      case 'confirmed':
        return 'Confirmed';
      case 'completed':
        return 'Completed';
      case 'rejected':
        return 'Declined';
      case 'cancelled':
        return 'Cancelled';
      default:
        return status;
    }
  }

  String get formattedAmount =>
      '₹${totalAmount.toStringAsFixed(0)}';

  String get timeRange => '${_fmt(timeFrom)} - ${_fmt(timeTo)}';

  /// "Thu, 20 Aug 2026", or the raw string when it will not parse.
  String get formattedDate {
    final parts = sessionDate.split('-');
    if (parts.length < 3) return sessionDate;
    final y = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    final d = int.tryParse(parts[2]);
    if (y == null || m == null || d == null) return sessionDate;
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final date = DateTime(y, m, d);
    return '${days[date.weekday - 1]}, $d ${months[m - 1]} $y';
  }

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
