import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../core/app_colors.dart';

/// The icon for a sport.
///
/// Prefers the `image` the Sports API serves for that sport. Sports seeded
/// without an icon come back with `image: null`, so a name-matched emoji is
/// used as the fallback rather than leaving an empty pill — upload an icon in
/// the admin panel and this switches to the real asset with no app change.
///
/// Replaces three copies of the same emoji map that previously lived in
/// `home_screen`, `ground_detail_screen` and `venue_filter_screen`.
class SportGlyph extends StatelessWidget {
  final String name;
  final String? imageUrl;
  final double size;

  const SportGlyph({
    super.key,
    required this.name,
    this.imageUrl,
    this.size = 28,
  });

  static const _emojis = <String, String>{
    'cricket': '\u{1F3CF}',
    'football': '⚽',
    'soccer': '⚽',
    'basketball': '\u{1F3C0}',
    'volleyball': '\u{1F3D0}',
    'badminton': '\u{1F3F8}',
    'tennis': '\u{1F3BE}',
    'squash': '\u{1F3BE}',
    'hockey': '\u{1F3D1}',
    'kabaddi': '\u{1F93C}',
    'swimming': '\u{1F3CA}',
    'gym': '\u{1F4AA}',
  };

  /// Emoji for [name], or a trophy when nothing matches.
  static String emojiFor(String name) {
    final lower = name.toLowerCase();
    for (final e in _emojis.entries) {
      if (lower.contains(e.key)) return e.value;
    }
    return '\u{1F3C6}';
  }

  @override
  Widget build(BuildContext context) {
    final url = imageUrl?.trim();

    if (url == null || url.isEmpty) {
      // Decorative: the label beside it already names the sport.
      return ExcludeSemantics(
        child: Text(emojiFor(name), style: TextStyle(fontSize: size)),
      );
    }

    return CachedNetworkImage(
      imageUrl: url,
      width: size,
      height: size,
      fit: BoxFit.contain,
      placeholder: (_, __) => SizedBox(width: size, height: size),
      errorWidget: (_, __, ___) => ExcludeSemantics(
        child: Text(emojiFor(name), style: TextStyle(fontSize: size)),
      ),
      imageBuilder: (_, provider) => Image(
        image: provider,
        width: size,
        height: size,
        fit: BoxFit.contain,
        color: AppColors.primary,
        colorBlendMode: BlendMode.srcIn,
        excludeFromSemantics: true,
      ),
    );
  }
}
