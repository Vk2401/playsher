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
  });

  factory BookingModel.fromJson(Map<String, dynamic> json) {
    // Handle ground: direct 'ground' field (backend) or nested in 'ground_sport'
    final gs = json['groundSport'] as Map<String, dynamic>? ??
        json['ground_sport'] as Map<String, dynamic>?;
    final sport = gs?['sport'] as Map<String, dynamic>?;
    final ground = json['ground'] as Map<String, dynamic>? ??
        gs?['ground'] as Map<String, dynamic>?;
    final category = ground?['category'] as Map<String, dynamic>?;
    final payment = json['payment'] as Map<String, dynamic>?;

    // Try to get ground image
    final images = (ground?['images'] as List<dynamic>?) ??
        (ground?['slider_images'] as List<dynamic>?) ?? [];
    final primaryImg = images.isNotEmpty
        ? ((images.first as Map<String, dynamic>)['image'] as String? ??
           (images.first as Map<String, dynamic>)['image_url'] as String?)
        : null;

    // Handle booked slots: 'booked_slots' (backend) or 'slots'
    final slots = (json['booked_slots'] as List<dynamic>?) ??
        (json['bookedSlots'] as List<dynamic>?) ??
        (json['slots'] as List<dynamic>?) ??
        [];
    String? sTime;
    String? eTime;
    if (slots.isNotEmpty) {
      final first = slots.first as Map<String, dynamic>;
      final slot = first['slot'] as Map<String, dynamic>? ?? first;
      sTime = slot['slot_start_time'] as String? ?? slot['from_time'] as String? ?? slot['start_time'] as String?;
      eTime = slot['slot_end_time'] as String? ?? slot['to_time'] as String? ?? slot['end_time'] as String?;
    }

    // Total price: try multiple field names
    final price = double.tryParse(json['total_price']?.toString() ?? '') ??
        double.tryParse(json['total']?.toString() ?? '') ??
        double.tryParse(payment?['total']?.toString() ?? '') ?? 0;

    return BookingModel(
      id: json['id'] as int,
      bookingDate: json['booking_date'] as String? ?? '',
      status: json['status'] as String? ?? 'pending',
      totalPrice: price,
      cancellationReason: json['cancellation_reason'] as String? ?? json['cancel_reason'] as String?,
      groundName: ground?['name'] as String? ?? json['ground_name'] as String?,
      sportName: sport?['name'] as String? ?? category?['name'] as String?,
      paymentStatus: payment?['status'] as String? ?? payment?['payment_status'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
      groundImage: primaryImg ?? json['ground_image'] as String?,
      startTime: sTime ?? json['start_time'] as String?,
      endTime: eTime ?? json['end_time'] as String?,
      bookingReference: json['booking_reference'] as String?,
    );
  }

  static List<BookingModel> listFromJson(List<dynamic> list) =>
      list.map((e) => BookingModel.fromJson(e as Map<String, dynamic>)).toList();

  bool get isUpcoming => status == 'pending' || status == 'confirmed';
  bool get isPast => status == 'completed';
  bool get isCancelled => status == 'cancelled';

  String get formattedPrice => '\u20b9${totalPrice.toStringAsFixed(0)}';
  double get totalAmount => totalPrice;
  String get date => bookingDate;
  int get slotCount => 1;

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
