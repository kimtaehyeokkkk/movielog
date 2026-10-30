import 'package:movielog/data/models/rating_dto.dart';

class RatingPageDto {
  const RatingPageDto({
    required this.content,
    required this.page,
    required this.size,
    required this.totalElements,
    required this.totalPages,
    required this.hasNext,
  });

  final List<RatingDto> content;
  final int page;
  final int size;
  final int totalElements;
  final int totalPages;
  final bool hasNext;

  factory RatingPageDto.fromJson(Map<String, dynamic> json) {
    final rawContent = json['content'] as List<dynamic>? ?? const [];

    return RatingPageDto(
      content: rawContent
          .map((item) => RatingDto.fromJson(item as Map<String, dynamic>))
          .toList(),
      page: (json['page'] as num? ?? 0).toInt(),
      size: (json['size'] as num? ?? rawContent.length).toInt(),
      totalElements: (json['totalElements'] as num? ?? rawContent.length).toInt(),
      totalPages: (json['totalPages'] as num? ?? 1).toInt(),
      hasNext: json['hasNext'] as bool? ?? false,
    );
  }
}
