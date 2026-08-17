class SportModel {
  final int id;
  final String name;
  final String? image;

  const SportModel({required this.id, required this.name, this.image});

  factory SportModel.fromJson(Map<String, dynamic> json) => SportModel(
        id:    json['id'] as int,
        name:  json['name'] as String? ?? '',
        image: json['image'] as String?,
      );

  static List<SportModel> listFromJson(List<dynamic> list) =>
      list.map((e) => SportModel.fromJson(e as Map<String, dynamic>)).toList();
}
