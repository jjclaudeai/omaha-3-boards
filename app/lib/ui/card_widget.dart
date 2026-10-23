import 'package:flutter/material.dart';

import '../engine/cards.dart';

/// Jeu « 4 couleurs » : avec 3 boards, distinguer carreau et cœur d'un coup d'œil aide à voir les couleurs.
const suitColors = [
  Color(0xFF1B8A3A), // trèfle
  Color(0xFF1565C0), // carreau
  Color(0xFFC62828), // cœur
  Color(0xFF212121), // pique
];
const rankLabels = ['2', '3', '4', '5', '6', '7', '8', '9', '10', 'V', 'D', 'R', 'A'];

class PlayingCard extends StatelessWidget {
  const PlayingCard({
    super.key,
    this.card,
    required this.width,
    this.faceUp = true,
    this.dimmed = false,
    this.glow = false,
    this.lift = false,
    this.back,
  });

  final CardId? card;

  /// Soulève la carte (abattage : les 2 cartes de la main gagnante).
  final bool lift;

  /// Couleurs du dos de carte choisi en boutique.
  final List<Color>? back;
  final double width;
  final bool faceUp;
  final bool dimmed;
  final bool glow;

  @override
  Widget build(BuildContext context) {
    final h = width * 1.4;
    final radius = BorderRadius.circular(width * 0.12);
    final c = card;
    Widget face;
    if (!faceUp || c == null) {
      face = Container(
        decoration: BoxDecoration(
          borderRadius: radius,
          gradient: LinearGradient(
            colors: back ?? const [Color(0xFF8E1B2C), Color(0xFF5C0F1C)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(color: Colors.white, width: width * 0.05),
        ),
        child: Center(
          child: Icon(Icons.diamond_outlined, color: Colors.white24, size: width * 0.5),
        ),
      );
    } else {
      final color = suitColors[suitOf(c)];
      face = Container(
        decoration: BoxDecoration(color: Colors.white, borderRadius: radius),
        padding: EdgeInsets.symmetric(horizontal: width * 0.08, vertical: width * 0.04),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              rankLabels[rankOf(c)],
              style: TextStyle(
                color: color,
                fontSize: width * 0.42,
                fontWeight: FontWeight.w800,
                height: 1.05,
                letterSpacing: -1,
              ),
            ),
            Expanded(
              child: Align(
                alignment: Alignment.bottomRight,
                child: SuitIcon(suit: suitOf(c), size: width * 0.46, color: color),
              ),
            ),
          ],
        ),
      );
    }
    return AnimatedSlide(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutBack,
      offset: lift ? const Offset(0, -0.14) : Offset.zero,
      child: AnimatedOpacity(
      duration: const Duration(milliseconds: 250),
      opacity: dimmed ? 0.38 : 1,
      child: Container(
        width: width,
        height: h,
        decoration: BoxDecoration(
          borderRadius: radius,
          boxShadow: [
            if (glow) const BoxShadow(color: Color(0xFFFFD54F), blurRadius: 12, spreadRadius: 2),
            const BoxShadow(color: Colors.black38, blurRadius: 3, offset: Offset(0, 1.5)),
          ],
        ),
        child: face,
      ),
      ),
    );
  }
}

/// Fait apparaître une carte (glissé + fondu) après [delay], pour l'animation de distribution.
class DealIn extends StatefulWidget {
  const DealIn({super.key, required this.child, this.delay = Duration.zero, this.from = const Offset(0, -0.6)});
  final Widget child;
  final Duration delay;
  final Offset from;

  @override
  State<DealIn> createState() => _DealInState();
}

class _DealInState extends State<DealIn> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 320));
  late final _curve = CurvedAnimation(parent: _c, curve: Curves.easeOutCubic);

  @override
  void initState() {
    super.initState();
    Future.delayed(widget.delay, () {
      if (mounted) _c.forward();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _curve,
      builder: (context, child) => Opacity(
        opacity: _curve.value,
        child: FractionalTranslation(
          translation: Offset.lerp(widget.from, Offset.zero, _curve.value)!,
          child: Transform.scale(scale: 0.85 + 0.15 * _curve.value, child: child),
        ),
      ),
      child: widget.child,
    );
  }
}

/// Symbole de couleur dessiné à la main : les polices affichent souvent ♦ et ♥ en émoji, sans notre couleur.
class SuitIcon extends StatelessWidget {
  const SuitIcon({super.key, required this.suit, required this.size, required this.color});
  final int suit;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: Size.square(size), painter: _SuitPainter(suit, color));
}

class _SuitPainter extends CustomPainter {
  _SuitPainter(this.suit, this.color);
  final int suit;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final paint = Paint()..color = color;
    final path = Path();
    switch (suit) {
      case 0: // trèfle : trois ronds et une tige
        canvas.drawCircle(Offset(s * 0.5, s * 0.28), s * 0.21, paint);
        canvas.drawCircle(Offset(s * 0.27, s * 0.56), s * 0.21, paint);
        canvas.drawCircle(Offset(s * 0.73, s * 0.56), s * 0.21, paint);
        path
          ..moveTo(s * 0.5, s * 0.45)
          ..lineTo(s * 0.64, s)
          ..lineTo(s * 0.36, s)
          ..close();
      case 1: // carreau
        path
          ..moveTo(s * 0.5, 0)
          ..lineTo(s * 0.88, s * 0.5)
          ..lineTo(s * 0.5, s)
          ..lineTo(s * 0.12, s * 0.5)
          ..close();
      case 2: // cœur
        path
          ..moveTo(s * 0.5, s * 0.95)
          ..cubicTo(s * 0.1, s * 0.62, 0, s * 0.4, 0, s * 0.28)
          ..cubicTo(0, s * 0.08, s * 0.16, 0, s * 0.28, 0)
          ..cubicTo(s * 0.4, 0, s * 0.48, s * 0.08, s * 0.5, s * 0.18)
          ..cubicTo(s * 0.52, s * 0.08, s * 0.6, 0, s * 0.72, 0)
          ..cubicTo(s * 0.84, 0, s, s * 0.08, s, s * 0.28)
          ..cubicTo(s, s * 0.4, s * 0.9, s * 0.62, s * 0.5, s * 0.95)
          ..close();
      default: // pique : un cœur renversé et une tige
        path
          ..moveTo(s * 0.5, 0)
          ..cubicTo(s * 0.9, s * 0.3, s, s * 0.45, s, s * 0.57)
          ..cubicTo(s, s * 0.74, s * 0.86, s * 0.8, s * 0.74, s * 0.8)
          ..cubicTo(s * 0.62, s * 0.8, s * 0.54, s * 0.74, s * 0.52, s * 0.66)
          ..lineTo(s * 0.64, s)
          ..lineTo(s * 0.36, s)
          ..lineTo(s * 0.48, s * 0.66)
          ..cubicTo(s * 0.46, s * 0.74, s * 0.38, s * 0.8, s * 0.26, s * 0.8)
          ..cubicTo(s * 0.14, s * 0.8, 0, s * 0.74, 0, s * 0.57)
          ..cubicTo(0, s * 0.45, s * 0.1, s * 0.3, s * 0.5, 0)
          ..close();
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_SuitPainter old) => old.suit != suit || old.color != color;
}
