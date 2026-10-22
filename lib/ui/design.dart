import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'theme.dart';

/// Shared building blocks of the "Teach Connect LMS K12" design system.

// ---------------------------------------------------------------------------------------
// Logo
// ---------------------------------------------------------------------------------------

/// The mortar-board mark (Lucide-style graduation cap).
class CapMark extends StatelessWidget {
  const CapMark({super.key, this.size = 28, this.color = Colors.white});
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: Size.square(size), painter: _CapPainter(color));
}

class _CapPainter extends CustomPainter {
  _CapPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final k = size.width / 24;
    final top = Path()
      ..moveTo(2 * k, 9.5 * k)
      ..lineTo(12 * k, 5 * k)
      ..lineTo(22 * k, 9.5 * k)
      ..lineTo(12 * k, 14 * k)
      ..close();
    final base = Path()
      ..moveTo(6 * k, 12 * k)
      ..lineTo(6 * k, 16.5 * k)
      ..cubicTo(6 * k, 17.9 * k, 8.7 * k, 19 * k, 12 * k, 19 * k)
      ..cubicTo(15.3 * k, 19 * k, 18 * k, 17.9 * k, 18 * k, 16.5 * k)
      ..lineTo(18 * k, 12 * k);
    final side = Path()
      ..moveTo(22 * k, 9.5 * k)
      ..lineTo(22 * k, 15 * k);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.75 * k
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    for (final p in [top, base, side]) {
      canvas.drawPath(p, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _CapPainter old) => old.color != color;
}

/// The indigo app tile with the mark in it.
class LogoTile extends StatelessWidget {
  const LogoTile({super.key, this.size = 56});
  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: Brand.primary,
      borderRadius: BorderRadius.circular(size * .29),
      boxShadow: const [
        BoxShadow(
          color: Color(0x734F46E5),
          blurRadius: 12,
          offset: Offset(0, 4),
        ),
      ],
    ),
    child: Center(child: CapMark(size: size * .54)),
  );
}

// ---------------------------------------------------------------------------------------
// Surfaces and small parts
// ---------------------------------------------------------------------------------------

/// White 16px card with a 1px line border.
class SoftCard extends StatelessWidget {
  const SoftCard({
    super.key,
    required this.child,
    this.padding,
    this.onTap,
    this.radius = 16,
    this.clip = false,
    this.color = Colors.white,
    this.borderColor = Brand.line,
  });
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;
  final double radius;
  final bool clip;
  final Color color;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    final r = BorderRadius.circular(radius);
    return Container(
      decoration: BoxDecoration(
        color: color,
        borderRadius: r,
        border: Border.all(color: borderColor),
        boxShadow: Brand.softShadow,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: r,
        clipBehavior: clip || onTap != null ? Clip.antiAlias : Clip.none,
        child: InkWell(
          onTap: onTap,
          child: Padding(padding: padding ?? EdgeInsets.zero, child: child),
        ),
      ),
    );
  }
}

/// Status badge: always a word, never colour alone.
class Tag extends StatelessWidget {
  const Tag(
    this.text, {
    super.key,
    this.fg = Brand.primaryDark,
    this.bg = Brand.tint,
  });
  final String text;
  final Color fg;
  final Color bg;

  const Tag.ok(this.text, {super.key}) : fg = Brand.ok, bg = Brand.ok0;
  const Tag.warn(this.text, {super.key}) : fg = Brand.warn, bg = Brand.warn0;
  const Tag.err(this.text, {super.key}) : fg = Brand.err, bg = Brand.err0;
  const Tag.info(this.text, {super.key}) : fg = Brand.info, bg = Brand.info0;
  const Tag.neutral(this.text, {super.key}) : fg = Brand.ink2, bg = Brand.field;

  @override
  Widget build(BuildContext context) => Container(
    height: 24,
    padding: const EdgeInsets.symmetric(horizontal: 10),
    decoration: BoxDecoration(
      color: bg,
      borderRadius: BorderRadius.circular(999),
    ),
    child: Center(
      widthFactor: 1,
      child: Text(
        text,
        style: TextStyle(
          color: fg,
          fontSize: 12,
          height: 1,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
  );
}

/// A rounded-square icon tile (indigo tint by default).
class IconTile extends StatelessWidget {
  const IconTile(
    this.icon, {
    super.key,
    this.size = 40,
    this.fg = Brand.primaryDark,
    this.bg = Brand.tint,
    this.radius,
  });
  final IconData icon;
  final double size;
  final Color fg;
  final Color bg;
  final double? radius;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: bg,
      borderRadius: BorderRadius.circular(radius ?? size * .3),
    ),
    child: Icon(icon, size: size * .55, color: fg),
  );
}

class ProgressBar extends StatelessWidget {
  const ProgressBar(this.value, {super.key, this.color = Brand.primary});
  final double value;
  final Color color;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(3),
    child: LinearProgressIndicator(
      value: value.clamp(0, 1).toDouble(),
      minHeight: 6,
      backgroundColor: const Color(0xFFE7EAF3),
      color: color,
    ),
  );
}

class RingProgress extends StatelessWidget {
  const RingProgress({
    super.key,
    required this.value,
    this.size = 64,
    this.stroke = 7,
    this.color = Brand.primary,
    this.track = const Color(0xFFE7EAF3),
    this.child,
  });
  final double value;
  final double size;
  final double stroke;
  final Color color;
  final Color track;
  final Widget? child;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: size,
    height: size,
    child: CustomPaint(
      painter: _RingPainter(value.clamp(0, 1).toDouble(), stroke, color, track),
      child: Center(child: child),
    ),
  );
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.v, this.stroke, this.color, this.track);
  final double v;
  final double stroke;
  final Color color;
  final Color track;

  @override
  void paint(Canvas canvas, Size size) {
    final rect =
        Offset(stroke / 2, stroke / 2) &
        Size(size.width - stroke, size.height - stroke);
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, 0, math.pi * 2, false, p..color = track);
    if (v > 0) {
      canvas.drawArc(rect, -math.pi / 2, math.pi * 2 * v, false, p..color = color);
    }
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) =>
      old.v != v || old.color != color || old.track != track;
}

/// Section heading with an optional trailing link, e.g. "Awaiting grading   View all".
class SectionHeading extends StatelessWidget {
  const SectionHeading(this.title, {super.key, this.action, this.onAction});
  final String title;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              height: 1.375,
              fontWeight: FontWeight.w600,
              color: Brand.ink,
            ),
          ),
        ),
        if (action != null)
          GestureDetector(
            onTap: onAction,
            behavior: HitTestBehavior.opaque,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 44),
              child: Align(
                widthFactor: 1,
                child: Text(
                  action!,
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                    color: Brand.primaryDark,
                  ),
                ),
              ),
            ),
          ),
      ],
    ),
  );
}

/// Small uppercase group label ("ACADEMIC SESSION").
class GroupLabel extends StatelessWidget {
  const GroupLabel(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
    child: Text(
      text.toUpperCase(),
      style: const TextStyle(
        fontSize: 12,
        height: 1.33,
        fontWeight: FontWeight.w600,
        letterSpacing: .6,
        color: Brand.ink3,
      ),
    ),
  );
}

/// Segmented control: Operations | Reports.
class Segmented extends StatelessWidget {
  const Segmented({
    super.key,
    required this.labels,
    required this.index,
    required this.onChanged,
  });
  final List<String> labels;
  final int index;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(4),
    decoration: BoxDecoration(
      color: Brand.field,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      children: [
        for (var i = 0; i < labels.length; i++) ...[
          if (i > 0) const SizedBox(width: 4),
          Expanded(
            child: Semantics(
              button: true,
              selected: i == index,
              child: GestureDetector(
                onTap: () => onChanged(i),
                behavior: HitTestBehavior.opaque,
                child: Container(
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: i == index ? Colors.white : Colors.transparent,
                    borderRadius: BorderRadius.circular(9),
                    boxShadow: i == index
                        ? const [
                            BoxShadow(
                              color: Color(0x1F0F172A),
                              blurRadius: 2,
                              offset: Offset(0, 1),
                            ),
                          ]
                        : null,
                  ),
                  child: Text(
                    labels[i],
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: i == index
                          ? FontWeight.w600
                          : FontWeight.w500,
                      color: i == index ? Brand.primaryDark : Brand.ink2,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    ),
  );
}

/// Pill chip (level-3 tabs, filters, month picker).
class PillChip extends StatelessWidget {
  const PillChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.leading,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? leading;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(right: 8),
    child: Semantics(
      button: true,
      selected: selected,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: selected ? Brand.primary : Colors.white,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: selected ? Brand.primary : Brand.line),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (leading != null) ...[
                Icon(
                  leading,
                  size: 18,
                  color: selected ? Colors.white : Brand.ink2,
                ),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  color: selected ? Colors.white : Brand.ink2,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

// ---------------------------------------------------------------------------------------
// Bottom navigation
// ---------------------------------------------------------------------------------------

class NavItem {
  const NavItem(this.icon, this.label, this.onTap);
  final IconData icon;
  final String label;
  final VoidCallback onTap;
}

/// Floating, rounded glass bar. A translucent white pill blurs whatever scrolls behind it,
/// and one indigo-tint highlight slides to whichever item is selected.
class BottomNav extends StatelessWidget {
  const BottomNav({super.key, required this.items, required this.selected});
  final List<NavItem> items;
  final int selected;

  /// Height the bar occupies, so scrolling pages can leave room under it.
  static double clearance(BuildContext context) => 68 + 12 + MediaQuery.paddingOf(context).bottom + 16;

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    final reduce = MediaQuery.disableAnimationsOf(context);
    final slide = reduce ? Duration.zero : const Duration(milliseconds: 320);
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, (bottom > 0 ? bottom : 0) + 12),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          boxShadow: const [BoxShadow(color: Color(0x290B1437), blurRadius: 28, offset: Offset(0, 10))],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 22, sigmaY: 22),
            child: Container(
              height: 68,
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: .72),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: Colors.white.withValues(alpha: .8)),
              ),
              child: LayoutBuilder(
                builder: (context, box) {
                  final w = box.maxWidth / items.length;
                  return Stack(children: [
                    AnimatedPositioned(
                      duration: slide,
                      curve: Curves.easeOutCubic,
                      left: w * selected,
                      top: 0,
                      bottom: 0,
                      width: w,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Brand.primary.withValues(alpha: .12),
                          borderRadius: BorderRadius.circular(22),
                        ),
                      ),
                    ),
                    Row(children: [
                      for (var i = 0; i < items.length; i++)
                        Expanded(
                          child: Semantics(
                            button: true,
                            selected: i == selected,
                            label: items[i].label,
                            child: Pressable(
                              onTap: items[i].onTap,
                              child: SizedBox(
                                height: double.infinity,
                                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                                  AnimatedScale(
                                    scale: i == selected ? 1.12 : 1,
                                    duration: slide,
                                    curve: Curves.easeOutBack,
                                    child: Icon(items[i].icon, size: 22, color: i == selected ? Brand.primaryDark : Brand.ink3),
                                  ),
                                  const SizedBox(height: 2),
                                  AnimatedDefaultTextStyle(
                                    duration: slide,
                                    style: TextStyle(
                                      fontFamily: kFont,
                                      fontSize: 12,
                                      height: 1.33,
                                      fontWeight: i == selected ? FontWeight.w600 : FontWeight.w500,
                                      color: i == selected ? Brand.primaryDark : Brand.ink3,
                                    ),
                                    child: Text(items[i].label, maxLines: 1, overflow: TextOverflow.ellipsis),
                                  ),
                                ]),
                              ),
                            ),
                          ),
                        ),
                    ]),
                  ]);
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------------------
// Motion
// ---------------------------------------------------------------------------------------

/// Fades and lifts its child into place. [delay] staggers siblings. Does nothing when the
/// device asks for reduced motion. Driven by one controller (no timers), so tests settle.
class Rise extends StatefulWidget {
  const Rise({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.offset = 16,
  });
  final Widget child;
  final Duration delay;
  final double offset;

  @override
  State<Rise> createState() => _RiseState();
}

class _RiseState extends State<Rise> with SingleTickerProviderStateMixin {
  static const _run = Duration(milliseconds: 450);
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: _run + widget.delay,
  );
  late final Animation<double> _t = CurvedAnimation(
    parent: _c,
    curve: Interval(
      widget.delay.inMilliseconds / (_run + widget.delay).inMilliseconds,
      1,
      curve: Curves.easeOutCubic,
    ),
  );
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    MediaQuery.disableAnimationsOf(context) ? _c.value = 1 : _c.forward();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _t,
    child: widget.child,
    builder: (_, child) => Opacity(
      opacity: _t.value.clamp(0.0, 1.0),
      child: Transform.translate(
        offset: Offset(0, (1 - _t.value) * widget.offset),
        child: child,
      ),
    ),
  );
}

/// Counts a number up to [value] (e.g. the home stats).
class CountUp extends StatelessWidget {
  const CountUp({super.key, required this.value, required this.builder});
  final int value;
  final Widget Function(int v) builder;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(begin: 0, end: value.toDouble()),
    duration: MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 800),
    curve: Curves.easeOutCubic,
    builder: (_, v, _) => builder(v.round()),
  );
}

/// Shrinks slightly while pressed, for tiles and buttons that have no ripple of their own.
class Pressable extends StatefulWidget {
  const Pressable({super.key, required this.child, required this.onTap});
  final Widget child;
  final VoidCallback onTap;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;

  @override
  Widget build(BuildContext context) => GestureDetector(
    behavior: HitTestBehavior.opaque,
    onTapDown: (_) => setState(() => _down = true),
    onTapUp: (_) => setState(() => _down = false),
    onTapCancel: () => setState(() => _down = false),
    onTap: widget.onTap,
    child: AnimatedScale(
      scale: _down ? .94 : 1,
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOut,
      child: widget.child,
    ),
  );
}

/// Quick horizontal shake, replayed whenever [trigger] changes to a new non-null value.
class Shake extends StatefulWidget {
  const Shake({super.key, required this.trigger, required this.child});
  final Object? trigger;
  final Widget child;

  @override
  State<Shake> createState() => _ShakeState();
}

class _ShakeState extends State<Shake> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
  );

  @override
  void didUpdateWidget(covariant Shake old) {
    super.didUpdateWidget(old);
    if (widget.trigger != null &&
        widget.trigger != old.trigger &&
        !MediaQuery.disableAnimationsOf(context)) {
      _c.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _c,
    child: widget.child,
    builder: (_, child) => Transform.translate(
      offset: Offset(math.sin(_c.value * math.pi * 5) * 8 * (1 - _c.value), 0),
      child: child,
    ),
  );
}
