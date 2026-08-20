class AmenityModel {
  final int id;
  final String name;
  final String? type;
  final String? icon;

  const AmenityModel(
      {required this.id, required this.name, this.type, this.icon});

  factory AmenityModel.fromJson(Map<String, dynamic> json) => AmenityModel(
        id: json['id'] as int,
        name: json['name'] as String? ?? '',
        type: json['type'] as String?,
        icon: json['icon'] as String?,
      );

  static List<AmenityModel> listFromJson(List<dynamic> list) => list
      .map((e) => AmenityModel.fromJson(e as Map<String, dynamic>))
      .toList();
}
