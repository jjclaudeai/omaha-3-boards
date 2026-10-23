import 'dart:math';

import 'package:flutter/material.dart';

import '../state/catalog.dart';

/// Dessine un motif répété (losanges, vagues, art déco…) dans tout le rectangle.
class MotifPainter extends CustomPainter {
  MotifPainter(this.motif, this.color, {this.cell = 22});
  final Motif motif;
  final Color color;

  /// Taille d'une maille du motif, en pixels logiques.
  final double cell;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = max(0.8, cell / 22);
    final fill = Paint()..color = color;
    final c = cell;
    switch (motif) {
      case Motif.none:
        return;
      case Motif.diamonds:
        for (var y = 0.0; y < size.height + c; y += c) {
          for (var x = (y / c).round().isOdd ? c / 2 : 0.0; x < size.width + c; x += c) {
            canvas.drawPath(
              Path()
                ..moveTo(x, y - c * 0.35)
                ..lineTo(x + c * 0.25, y)
                ..lineTo(x, y + c * 0.35)
                ..lineTo(x - c * 0.25, y)
                ..close(),
              stroke,
            );
          }
        }
      case Motif.waves:
        for (var y = 0.0; y < size.height + c; y += c * 0.6) {
          final path = Path()..moveTo(-c, y);
          for (var x = -c; x < size.width + c; x += c) {
            path.quadraticBezierTo(x + c / 4, y - c * 0.22, x + c / 2, y);
            path.quadraticBezierTo(x + 3 * c / 4, y + c * 0.22, x + c, y);
          }
          canvas.drawPath(path, stroke);
        }
      case Motif.artDeco:
        // Éventails concentriques en quinconce, le motif des casinos des années 30.
        for (var y = 0.0; y < size.height + c; y += c * 0.5) {
          final row = (y / (c * 0.5)).round();
          for (var x = row.isOdd ? c / 2 : 0.0; x < size.width + c; x += c) {
            for (var k = 1; k <= 3; k++) {
              canvas.drawArc(Rect.fromCircle(center: Offset(x, y), radius: c * 0.5 * k / 3), pi, pi, false, stroke);
            }
          }
        }
      case Motif.stars:
        final rng = Random(7);
        final count = (size.width * size.height / (c * c) * 0.9).round();
        for (var i = 0; i < count; i++) {
          final p = Offset(rng.nextDouble() * size.width, rng.nextDouble() * size.height);
          final r = c * (0.04 + rng.nextDouble() * 0.09);
          canvas.drawPath(_star(p, r), fill);
        }
      case Motif.hexagons:
        final w = c * 0.866;
        for (var y = 0.0; y < size.height + c; y += c * 0.75) {
          final row = (y / (c * 0.75)).round();
          for (var x = row.isOdd ? w / 2 : 0.0; x < size.width + c; x += w) {
            final path = Path();
            for (var k = 0; k < 6; k++) {
              final a = pi / 6 + k * pi / 3;
              final pt = Offset(x + cos(a) * c / 2, y + sin(a) * c / 2);
              k == 0 ? path.moveTo(pt.dx, pt.dy) : path.lineTo(pt.dx, pt.dy);
            }
            canvas.drawPath(path..close(), stroke);
          }
        }
      case Motif.stripes:
        final band = Paint()..color = color;
        for (var x = -size.height; x < size.width; x += c * 0.7) {
          canvas.drawPath(
            Path()
              ..moveTo(x, size.height)
              ..lineTo(x + c * 0.3, size.height)
              ..lineTo(x + c * 0.3 + size.height, 0)
              ..lineTo(x + size.height, 0)
              ..close(),
            band,
          );
        }
      case Motif.scales:
        for (var y = 0.0; y < size.height + c; y += c * 0.4) {
          final row = (y / (c * 0.4)).round();
          for (var x = row.isOdd ? c / 2 : 0.0; x < size.width + c; x += c) {
            canvas.drawArc(Rect.fromCircle(center: Offset(x, y), radius: c / 2), 0, pi, false, stroke);
          }
        }
    }
  }

  static Path _star(Offset c, double r) {
    final path = Path();
    for (var k = 0; k < 8; k++) {
      final a = -pi / 2 + k * pi / 4;
      final rr = k.isEven ? r : r * 0.35;
      final p = Offset(c.dx + cos(a) * rr, c.dy + sin(a) * rr);
      k == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
    }
    return path..close();
  }

  @override
  bool shouldRepaint(MotifPainter old) => old.motif != motif || old.color != color || old.cell != cell;
}

/// Dos de carte : dégradé, motif, liseré blanc et emblème central.
class CardBackFace extends StatelessWidget {
  const CardBackFace({super.key, required this.item, required this.width, required this.radius});
  final Cosmetic item;
  final double width;
  final BorderRadius radius;

  @override
  Widget build(BuildContext context) {
    final inset = width * 0.09;
    return Container(
      decoration: BoxDecoration(
        borderRadius: radius,
        color: Colors.white,
      ),
      padding: EdgeInsets.all(width * 0.05),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(width * 0.08),
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: item.colors, begin: Alignment.topLeft, end: Alignment.bottomRight),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              CustomPaint(painter: MotifPainter(item.pattern, Colors.white.withValues(alpha: 0.16), cell: width * 0.32)),
              Padding(
                padding: EdgeInsets.all(inset),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border.all(color: item.accent.withValues(alpha: 0.55), width: max(0.7, width * 0.02)),
                    borderRadius: BorderRadius.circular(width * 0.05),
                  ),
                ),
              ),
              if (item.icon != null)
                Center(
                  child: Container(
                    width: width * 0.5,
                    height: width * 0.5,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.black.withValues(alpha: 0.22),
                      border: Border.all(color: item.accent.withValues(alpha: 0.7), width: max(0.7, width * 0.025)),
                    ),
                    child: Icon(item.icon, color: item.accent, size: width * 0.3),
                  ),
                ),
              // Reflet en haut à gauche : la carte paraît vernie.
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.white.withValues(alpha: 0.22), Colors.transparent],
                    begin: Alignment.topLeft,
                    end: const Alignment(0.2, 0.1),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// La table elle-même : bord en relief, tapis en dégradé avec motif, ligne de mise et éclairage.
class TableFelt extends StatelessWidget {
  const TableFelt({super.key, required this.theme, this.railWidth = 11});
  final Cosmetic theme;
  final double railWidth;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, box) {
      final radius = BorderRadius.circular(box.maxWidth);
      return Container(
        decoration: BoxDecoration(
          borderRadius: radius,
          gradient: LinearGradient(colors: theme.rail, begin: Alignment.topCenter, end: Alignment.bottomCenter),
          boxShadow: [
            const BoxShadow(color: Colors.black54, blurRadius: 22, spreadRadius: 2, offset: Offset(0, 8)),
            BoxShadow(color: theme.accent.withValues(alpha: 0.12), blurRadius: 30, spreadRadius: -4),
          ],
        ),
        padding: EdgeInsets.all(railWidth),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: radius,
            border: Border.all(color: Colors.black.withValues(alpha: 0.45), width: 1.5),
            gradient: RadialGradient(colors: theme.colors, radius: 0.95, center: const Alignment(0, -0.25)),
          ),
          child: ClipRRect(
            borderRadius: radius,
            child: Stack(
              fit: StackFit.expand,
              children: [
                CustomPaint(painter: MotifPainter(theme.pattern, theme.accent.withValues(alpha: 0.07), cell: 26)),
                // Ligne de mise, comme sur les vraies tables.
                Padding(
                  padding: EdgeInsets.all(railWidth * 1.4),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: radius,
                      border: Border.all(color: theme.accent.withValues(alpha: 0.28), width: 1.4),
                    ),
                  ),
                ),
                // Lumière du plafonnier au centre, bords plus sombres.
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      colors: [Colors.white.withValues(alpha: 0.10), Colors.transparent, Colors.black.withValues(alpha: 0.28)],
                      stops: const [0, 0.55, 1],
                      radius: 0.9,
                      center: const Alignment(0, -0.3),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    });
  }
}

/// Aperçu d'un thème en boutique : une petite table avec ses 3 boards.
class ThemePreview extends StatelessWidget {
  const ThemePreview({super.key, required this.theme, this.width = 120});
  final Cosmetic theme;
  final double width;

  @override
  Widget build(BuildContext context) {
    final h = width * 0.62;
    return SizedBox(
      width: width,
      height: h,
      child: Stack(
        children: [
          Positioned.fill(child: TableFelt(theme: theme, railWidth: width * 0.05)),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var b = 0; b < 3; b++)
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: width * 0.008),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (var i = 0; i < 5; i++)
                          Container(
                            margin: EdgeInsets.symmetric(horizontal: width * 0.006),
                            width: width * 0.07,
                            height: width * 0.095,
                            decoration: BoxDecoration(
                              color: i < 3 + b % 2 ? Colors.white : Colors.white24,
                              borderRadius: BorderRadius.circular(width * 0.01),
                            ),
                          ),
                      ],
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
