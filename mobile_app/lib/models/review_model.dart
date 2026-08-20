class ReviewModel {
  final int id;
  final int rating;
  final String? comment;
  final String reviewerName;
  final DateTime? createdAt;

  const ReviewModel({
    required this.id,
    required this.rating,
    this.comment,
    required this.reviewerName,
    this.createdAt,
  });

  factory ReviewModel.fromJson(Map<String, dynamic> json) {
    final reviewer = json['reviewer'] as Map<String, dynamic>? ??
        json['user'] as Map<String, dynamic>?;
    return ReviewModel(
      id: json['id'] as int,
      rating: json['rating'] as int? ?? 0,
      comment: json['comment'] as String?,
      reviewerName: reviewer?['name'] as String? ??
          json['user_name'] as String? ??
          'Anonymous',
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
    );
  }

  static List<ReviewModel> listFromJson(List<dynamic> list) =>
      list.map((e) => ReviewModel.fromJson(e as Map<String, dynamic>)).toList();
}
