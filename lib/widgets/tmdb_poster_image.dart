import 'package:flutter/material.dart';

class TmdbPosterImage extends StatelessWidget {
  const TmdbPosterImage({
    super.key,
    required this.posterPath,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
  });

  final String? posterPath;
  // AspectRatio·Stack 안에서는 크기를 비워 부모 크기를 그대로 따른다.
  final double? width;
  final double? height;
  final BoxFit fit;

  static const _baseUrl = 'https://image.tmdb.org/t/p';
  static const _size = 'w500';

  String? get _imageUrl {
    final path = posterPath;
    if (path == null || path.isEmpty) return null;
    return '$_baseUrl/$_size$path';
  }

  @override
  Widget build(BuildContext context) {
    final imageUrl = _imageUrl;

    if (imageUrl == null) return _placeholder(context);

    return Image.network(
      imageUrl,
      width: width,
      height: height,
      fit: fit,
      errorBuilder: (context, error, stackTrace) => _placeholder(context),
    );
  }

  Widget _placeholder(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: width,
      height: height,
      color: colorScheme.surfaceContainerHighest,
      alignment: Alignment.center,
      child: Icon(
        Icons.image_not_supported_outlined,
        color: colorScheme.onSurfaceVariant,
      ),
    );
  }
}
