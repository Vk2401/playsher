class BookingModel {
  final int id;
  final String bookingDate;
  final String status;
  final double totalPrice;
  final String? cancellationReason;
  final String? groundName;
  final String? sportName;
  final String? paymentStatus;
  final DateTime? createdAt;
  final String? groundImage;
  final String? startTime;
  final String? endTime;
  final String? bookingReference;

  /// How many 30-minute slots the booking covers. 0 when the payload carried
  /// none — the list endpoint used to omit slots entirely.
  final int slotCount;

  /// Raw API value: 'online' or 'pay_at_ground'.
  final String? paymentMethod;

  /// Taken online up front. Equals [totalPrice] for an online booking; the
  /// advance for pay-at-ground, with the rest in [balanceDue].
  final double advanceAmount;
  final double balanceDue;

  const BookingModel({
    required this.id,
    required this.bookingDate,
    required this.status,
    required this.totalPrice,
    this.cancellationReason,
    this.groundName,
    this.sportName,
    this.paymentStatus,
    this.createdAt,
    this.groundImage,
    this.startTime,
    this.endTime,
    this.bookingReference,
    this.slotCount = 0,
    this.paymentMethod,
    this.advanceAmount = 0,
    this.balanceDue = 0,
  });

  factory BookingModel.fromJson(Map<String, dynamic> json) {
    // Handle ground: direct 'ground' field (backend) or nested in 'ground_sport'
    final gs = json['groundSport'] as Map<String, dynamic>? ??
        json['ground_sport'] as Map<String, dynamic>?;
    final sport = gs?['sport'] as Map<String, dynamic>?;
    final ground = json['ground'] as Map<String, dynamic>? ??
        gs?['ground'] as Map<String, dynamic>?;
    final category = ground?['category'] as Map<String, dynamic>?;
    // The API's hasOne alias is `paymentRecord`; `payment` is the older
    // belongsTo shape still present on some rows.
    final payment = json['paymentRecord'] as Map<String, dynamic>? ??
        json['payment'] as Map<String, dynamic>?;

    // Try to get ground image
    final images = (ground?['images'] as List<dynamic>?) ??
        (ground?['slider_images'] as List<dynamic>?) ??
        [];
    final primaryImg = images.isNotEmpty
        ? ((images.first as Map<String, dynamic>)['image'] as String? ??
            (images.first as Map<String, dynamic>)['image_url'] as String?)
        : null;

    // Handle booked slots: 'booked_slots' (backend) or 'slots'
    final slots = (json['booked_slots'] as List<dynamic>?) ??
        (json['bookedSlots'] as List<dynamic>?) ??
        (json['slots'] as List<dynamic>?) ??
        [];
    // A booking can span several consecutive 30-minute slots, and the API does
    // not promise an order. Take the earliest start and the latest end so a
    // three-slot booking reads "6:00 PM - 7:30 PM" rather than the first
    // half-hour only.
    String? sTime;
    String? eTime;
    for (final raw in slots) {
      final entry = raw as Map<String, dynamic>;
      final slot = entry['slot'] as Map<String, dynamic>? ?? entry;
      final start = slot['slot_start_time'] as String? ??
          slot['from_time'] as String? ??
          slot['start_time'] as String?;
      final end = slot['slot_end_time'] as String? ??
          slot['to_time'] as String? ??
          slot['end_time'] as String?;
      if (start != null && (sTime == null || start.compareTo(sTime) < 0)) {
        sTime = start;
      }
      if (end != null && (eTime == null || end.compareTo(eTime) > 0)) {
        eTime = end;
      }
    }

    // Total price: try multiple field names
    final price = double.tryParse(json['total_amount']?.toString() ?? '') ??
        double.tryParse(json['total_price']?.toString() ?? '') ??
        double.tryParse(json['total']?.toString() ?? '') ??
        double.tryParse(payment?['total']?.toString() ?? '') ??
        0;

    return BookingModel(
      id: json['id'] as int,
      bookingDate:
          json['slot_date'] as String? ?? json['booking_date'] as String? ?? '',
      status: json['status'] as String? ?? 'pending',
      totalPrice: price,
      cancellationReason: json['cancellation_reason'] as String? ??
          json['cancel_reason'] as String?,
      groundName: ground?['name'] as String? ?? json['ground_name'] as String?,
      sportName: sport?['name'] as String? ?? category?['name'] as String?,
      paymentStatus: payment?['status'] as String? ??
          payment?['payment_status'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
      groundImage: primaryImg ?? json['ground_image'] as String?,
      startTime: sTime ??
          json['slot_time_from'] as String? ??
          json['start_time'] as String?,
      endTime: eTime ??
          json['slot_time_to'] as String? ??
          json['end_time'] as String?,
      bookingReference: json['booking_reference'] as String?,
      slotCount: slots.length,
      paymentMethod: json['payment_method'] as String?,
      advanceAmount:
          double.tryParse(json['advance_amount']?.toString() ?? '') ?? 0,
      balanceDue: double.tryParse(json['balance_due']?.toString() ?? '') ?? 0,
    );
  }

  static List<BookingModel> listFromJson(List<dynamic> list) => list
      .map((e) => BookingModel.fromJson(e as Map<String, dynamic>))
      .toList();

  bool get isUpcoming => status == 'pending' || status == 'confirmed';
  bool get isPast => status == 'completed';
  bool get isCancelled => status == 'cancelled';

  String get formattedPrice => '\u20b9${totalPrice.toStringAsFixed(0)}';
  String get formattedAdvance => '\u20b9${advanceAmount.toStringAsFixed(0)}';
  String get formattedBalance => '\u20b9${balanceDue.toStringAsFixed(0)}';

  /// True when money is still owed at the venue.
  bool get hasBalanceDue => balanceDue > 0;

  /// Human label for [paymentMethod]. Falls back to the API's own default
  /// rather than asserting a method the booking may not have used.
  String get paymentMethodLabel {
    switch (paymentMethod) {
      case 'online':
        return 'Paid Online';
      case 'pay_at_ground':
        return 'Pay at Ground';
      default:
        return 'Not specified';
    }
  }

  double get totalAmount => totalPrice;
  String get date => bookingDate;

  // ── Display helpers ────────────────────────────────────────────────────────
  // Derived on the model rather than in each widget, so the ticket, the card
  // and the detail screen can never disagree about the same booking.

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  /// "20 Aug 2026". Falls back to the raw value if it will not parse, so a
  /// surprising format is still shown rather than blanked.
  String get formattedDate {
    final d = DateTime.tryParse(bookingDate);
    if (d == null) return bookingDate;
    return '${d.day} ${_months[d.month - 1]} ${d.year}';
  }

  /// "Thu, 20 Aug 2026" — the weekday matters when you are deciding whether
  /// you can actually make it.
  String get formattedDateLong {
    final d = DateTime.tryParse(bookingDate);
    if (d == null) return bookingDate;
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return '${days[d.weekday - 1]}, $formattedDate';
  }

  /// "6:00 PM" from a "18:00:00" wall-clock string.
  static String? _hhmm(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    final parts = raw.split(':');
    if (parts.length < 2) return null;
    final h = int.tryParse(parts[0]);
    final m = parts[1].padLeft(2, '0');
    if (h == null) return null;
    final suffix = h >= 12 ? 'PM' : 'AM';
    final h12 = h % 12 == 0 ? 12 : h % 12;
    return '$h12:$m $suffix';
  }

  String? get formattedStartTime => _hhmm(startTime);
  String? get formattedEndTime => _hhmm(endTime);

  /// "6:00 PM - 7:30 PM", or null when the payload carried no slots.
  String? get timeRange {
    final start = formattedStartTime;
    final end = formattedEndTime;
    if (start == null) return null;
    return end == null ? start : '$start - $end';
  }

  /// "1 hr 30 min" across the booked slots.
  String? get durationLabel {
    if (startTime == null || endTime == null) return null;
    int? minutes(String raw) {
      final p = raw.split(':');
      if (p.length < 2) return null;
      final h = int.tryParse(p[0]);
      final m = int.tryParse(p[1]);
      return (h == null || m == null) ? null : h * 60 + m;
    }

    final from = minutes(startTime!);
    final to = minutes(endTime!);
    if (from == null || to == null || to <= from) return null;

    final total = to - from;
    final hours = total ~/ 60;
    final mins = total % 60;
    if (hours == 0) return '$mins min';
    if (mins == 0) return '$hours hr';
    return '$hours hr $mins min';
  }

  /// "3 slots" — plural handled, hidden entirely when the count is unknown.
  String? get slotCountLabel =>
      slotCount == 0 ? null : '$slotCount slot${slotCount == 1 ? '' : 's'}';

  /// What to show as the booking's identifier. The server reference is the one
  /// a venue can look up; the row id is only a fallback.
  String get referenceLabel =>
      (bookingReference != null && bookingReference!.isNotEmpty)
          ? bookingReference!
          : '#$id';

  String get statusLabel {
    switch (status) {
      case 'confirmed':
        return 'Confirmed';
      case 'pending':
        return 'Pending';
      case 'completed':
        return 'Completed';
      case 'cancelled':
        return 'Cancelled';
      default:
        return status.toUpperCase();
    }
  }
}
