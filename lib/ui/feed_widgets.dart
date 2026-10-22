import 'package:flutter/material.dart';

import '../core/feed.dart';
import '../screens/screen_registry.dart';
import 'theme.dart';

Color? hexColor(String hex) {
  var h = hex.trim().replaceFirst('#', '');
  if (h.length == 3) h = h.split('').map((c) => '$c$c').join();
  if (h.length == 6) h = 'FF$h';
  final n = int.tryParse(h, radix: 16);
  return n == null ? null : Color(n);
}

/// A tile's circular icon: the feed's own image when it loads, otherwise a keyword icon.
class FeedIcon extends StatelessWidget {
  const FeedIcon({
    super.key,
    required this.item,
    required this.accent,
    this.size = 50,
  });
  final FeedItem item;
  final (Color, Color) accent;
  final double size;

  @override
  Widget build(BuildContext context) {
    final fallback = IconBubble(
      icon: menuIcon(item.label, 2),
      accent: accent,
      size: size,
    );
    if (item.iconUrl.isEmpty) return fallback;
    return ClipRRect(
      borderRadius: BorderRadius.circular(size),
      child: Image.network(
        item.iconUrl,
        width: size,
        height: size,
        fit: BoxFit.cover,
        gaplessPlayback: true,
        errorBuilder: (_, _, _) => fallback,
        loadingBuilder: (_, child, p) =>
            p == null ? child : SizedBox(width: size, height: size),
      ),
    );
  }
}

/// One home-screen card, as in the old app: white rounded card, bold coloured title, a
/// decorative image bottom-right and a 4-column grid of round icons with small labels.
class FeedSectionCard extends StatelessWidget {
  const FeedSectionCard({
    super.key,
    required this.section,
    required this.index,
  });
  final FeedSection section;
  final int index;

  @override
  Widget build(BuildContext context) {
    final titleColor = hexColor(section.colorHex) ?? Brand.text;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: Brand.softShadow,
      ),
      child: Stack(
        children: [
          Positioned(
            right: 0,
            bottom: 0,
            child: ClipRRect(
              borderRadius: const BorderRadius.only(
                bottomRight: Radius.circular(20),
              ),
              child: SizedBox(
                width: 120,
                height: 120,
                child: section.backgroundImage.isEmpty
                    ? Image.asset('assets/images/profile.png', fit: BoxFit.fill)
                    : Image.network(
                        section.backgroundImage,
                        fit: BoxFit.fill,
                        errorBuilder: (_, _, _) => Image.asset(
                          'assets/images/profile.png',
                          fit: BoxFit.fill,
                        ),
                      ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  section.title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: titleColor,
                  ),
                ),
                const SizedBox(height: 20),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: section.items.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4,
                    childAspectRatio: .8,
                  ),
                  itemBuilder: (_, i) => FeedTile(
                    item: section.items[i],
                    accent: Brand.accent(index + i),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class FeedTile extends StatelessWidget {
  const FeedTile({super.key, required this.item, required this.accent});
  final FeedItem item;
  final (Color, Color) accent;

  @override
  Widget build(BuildContext context) {
    final available = hasScreen(context, item);
    return GestureDetector(
      onTap: () => openFeedItem(context, item),
      behavior: HitTestBehavior.opaque,
      child: Opacity(
        opacity: available ? 1 : 0.5,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(6),
              child: FeedIcon(item: item, accent: accent),
            ),
            Text(
              item.label,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.clip,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: Brand.text,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
