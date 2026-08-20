import 'sport_model.dart';

class GroundSportModel {
  final int id;
  final int groundId;
  final SportModel? sport;

  /// Price of one 30-minute slot.
  final double pricePerSlot;
  final String currency;

  /// Booking size limits the server enforces; mirrored here so the UI can stop
  /// an invalid selection before it becomes a rejected request.
  final int minSlots;
  final int maxSlots;

  const GroundSportModel({
    required this.id,
    required this.groundId,
    this.sport,
    required this.pricePerSlot,
    this.currency = '\u20b9',
    this.minSlots = 1,
    this.maxSlots = 8,
  });

  factory GroundSportModel.fromJson(Map<String, dynamic> json) =>
      GroundSportModel(
        id: json['id'] as int,
        groundId: json['ground_id'] as int? ?? 0,
        sport: json['sport'] != null
            ? SportModel.fromJson(json['sport'] as Map<String, dynamic>)
            : null,
        // The API's field is price_per_half_hour. Reading `price_per_slot`,
        // which it has never sent, meant this was always 0 — so checkout
        // quoted ₹0 while the server charged the real amount.
        pricePerSlot:
            double.tryParse(json['price_per_half_hour']?.toString() ?? '') ??
                double.tryParse(json['price_per_slot']?.toString() ?? '') ??
                0,
        currency: json['currency'] as String? ?? '\u20b9',
        minSlots: json['min_slots'] as int? ?? 1,
        maxSlots: json['max_slots'] as int? ?? 8,
      );

  static List<GroundSportModel> listFromJson(List<dynamic> list) => list
      .map((e) => GroundSportModel.fromJson(e as Map<String, dynamic>))
      .toList();

  String get formattedPrice => '$currency ${pricePerSlot.toStringAsFixed(0)}';
}
