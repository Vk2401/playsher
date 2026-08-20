import 'sport_model.dart';

class GroundSportModel {
  final int id;
  final int groundId;
  final SportModel? sport;
  final double pricePerSlot;
  final String currency;

  const GroundSportModel({
    required this.id,
    required this.groundId,
    this.sport,
    required this.pricePerSlot,
    this.currency = '\u20b9',
  });

  factory GroundSportModel.fromJson(Map<String, dynamic> json) =>
      GroundSportModel(
        id: json['id'] as int,
        groundId: json['ground_id'] as int? ?? 0,
        sport: json['sport'] != null
            ? SportModel.fromJson(json['sport'] as Map<String, dynamic>)
            : null,
        pricePerSlot: double.tryParse(json['price_per_slot'].toString()) ?? 0,
        currency: json['currency'] as String? ?? '\u20b9',
      );

  static List<GroundSportModel> listFromJson(List<dynamic> list) => list
      .map((e) => GroundSportModel.fromJson(e as Map<String, dynamic>))
      .toList();

  String get formattedPrice => '$currency ${pricePerSlot.toStringAsFixed(0)}';
}
