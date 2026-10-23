import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../state/catalog.dart';
import '../theme.dart';

/// Pièce dorée dessinée (pas d'émoji : rendu identique partout).
class CoinIcon extends StatelessWidget {
  const CoinIcon({super.key, this.size = 18});
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const RadialGradient(
          colors: [Color(0xFFFFE08A), Palette.gold, Palette.goldDeep],
          stops: [0, 0.55, 1],
          center: Alignment(-0.3, -0.3),
        ),
        border: Border.all(color: const Color(0xFFA9711A), width: size * 0.07),
      ),
      alignment: Alignment.center,
      child: Container(
        width: size * 0.52,
        height: size * 0.52,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0x99A9711A), width: size * 0.06),
        ),
      ),
    );
  }
}

/// Solde de pièces, avec un « + » qui ouvre la boutique.
class CoinPill extends StatelessWidget {
  const CoinPill({super.key, required this.amount, this.onAdd});
  final int amount;
  final VoidCallback? onAdd;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(6, 4, 4, 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Palette.gold.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CoinIcon(size: 22),
          const SizedBox(width: 6),
          TweenAnimationBuilder<double>(
            tween: Tween(end: amount.toDouble()),
            duration: const Duration(milliseconds: 700),
            curve: Curves.easeOutCubic,
            builder: (context, v, _) => Text(formatCoins(v.round()), style: display(17)),
          ),
          const SizedBox(width: 6),
          if (onAdd != null)
            Pressable(
              onTap: onAdd!,
              child: Container(
                width: 26,
                height: 26,
                decoration: const BoxDecoration(color: Palette.mint, shape: BoxShape.circle),
                child: const Icon(Icons.add_rounded, size: 20, color: Color(0xFF07301D)),
              ),
            )
          else
            const SizedBox(width: 4),
        ],
      ),
    );
  }
}

/// Bouton qui s'enfonce légèrement au toucher, avec un retour haptique.
class Pressable extends StatefulWidget {
  const Pressable({super.key, required this.child, required this.onTap, this.enabled = true});
  final Widget child;
  final VoidCallback onTap;
  final bool enabled;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: widget.enabled,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: widget.enabled ? (_) => setState(() => _down = true) : null,
        onTapCancel: () => setState(() => _down = false),
        onTapUp: widget.enabled ? (_) => setState(() => _down = false) : null,
        onTap: widget.enabled
            ? () {
                HapticFeedback.selectionClick();
                widget.onTap();
              }
            : null,
        child: AnimatedScale(
          scale: _down ? 0.95 : 1,
          duration: const Duration(milliseconds: 90),
          child: AnimatedOpacity(
            opacity: widget.enabled ? 1 : 0.45,
            duration: const Duration(milliseconds: 150),
            child: widget.child,
          ),
        ),
      ),
    );
  }
}

/// Gros bouton coloré à relief, le bouton principal des écrans.
class ChunkyButton extends StatelessWidget {
  const ChunkyButton({
    super.key,
    required this.label,
    required this.onTap,
    this.color = Palette.gold,
    this.shade = Palette.goldDeep,
    this.textColor = const Color(0xFF3A2400),
    this.height = 54,
    this.icon,
    this.enabled = true,
    this.fontSize = 20,
  });
  final String label;
  final VoidCallback onTap;
  final Color color;
  final Color shade;
  final Color textColor;
  final double height;
  final IconData? icon;
  final bool enabled;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      enabled: enabled,
      child: Container(
        height: height,
        padding: const EdgeInsets.only(bottom: 4),
        decoration: BoxDecoration(color: shade, borderRadius: BorderRadius.circular(16)),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              colors: [Color.lerp(color, Colors.white, 0.18)!, color],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          alignment: Alignment.center,
          child: FittedBox(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[Icon(icon, color: textColor, size: fontSize + 2), const SizedBox(width: 6)],
                Text(label, style: display(fontSize, color: textColor)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Panneau des écrans de menu.
class Panel extends StatelessWidget {
  const Panel({super.key, required this.child, this.padding = const EdgeInsets.all(16), this.gradient, this.borderColor});
  final Widget child;
  final EdgeInsets padding;
  final Gradient? gradient;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: gradient == null ? Palette.panel : null,
        gradient: gradient,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor ?? Palette.panelLine),
        boxShadow: const [BoxShadow(color: Color(0x55000000), blurRadius: 14, offset: Offset(0, 6))],
      ),
      child: child,
    );
  }
}

/// Barre de progression arrondie.
class ProgressBar extends StatelessWidget {
  const ProgressBar({super.key, required this.value, this.color = Palette.mint, this.height = 8});
  final double value;
  final Color color;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(color: Colors.black38, borderRadius: BorderRadius.circular(height)),
      alignment: Alignment.centerLeft,
      child: TweenAnimationBuilder<double>(
        tween: Tween(end: value.clamp(0, 1).toDouble()),
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeOutCubic,
        builder: (context, v, _) => FractionallySizedBox(
          widthFactor: max(v, 0.02),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(height),
              gradient: LinearGradient(colors: [Color.lerp(color, Colors.white, 0.25)!, color]),
            ),
          ),
        ),
      ),
    );
  }
}

/// Écusson de ligue dessiné : forme de blason, couleur de la ligue, initiale.
class LeagueBadge extends StatelessWidget {
  const LeagueBadge({super.key, required this.league, this.size = 48, this.locked = false});
  final League league;
  final double size;
  final bool locked;

  @override
  Widget build(BuildContext context) {
    final c = locked ? const Color(0xFF4A5A73) : league.color;
    return SizedBox(
      width: size,
      height: size * 1.12,
      child: CustomPaint(
        painter: _ShieldPainter(c),
        child: Center(
          child: Padding(
            padding: EdgeInsets.only(bottom: size * 0.12),
            child: locked
                ? Icon(Icons.lock_rounded, size: size * 0.38, color: Colors.white54)
                : Text(league.name[0], style: display(size * 0.5, color: const Color(0xFF1A1A1A))),
          ),
        ),
      ),
    );
  }
}

class _ShieldPainter extends CustomPainter {
  _ShieldPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final path = Path()
      ..moveTo(w * 0.5, 0)
      ..lineTo(w, h * 0.14)
      ..lineTo(w * 0.94, h * 0.6)
      ..quadraticBezierTo(w * 0.84, h * 0.84, w * 0.5, h)
      ..quadraticBezierTo(w * 0.16, h * 0.84, w * 0.06, h * 0.6)
      ..lineTo(0, h * 0.14)
      ..close();
    canvas.drawShadow(path, Colors.black, 4, false);
    canvas.drawPath(
      path,
      Paint()
        ..shader = LinearGradient(
          colors: [Color.lerp(color, Colors.white, 0.35)!, color, Color.lerp(color, Colors.black, 0.25)!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ).createShader(Offset.zero & size),
    );
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.05
        ..color = Colors.white.withValues(alpha: 0.5),
    );
  }

  @override
  bool shouldRepaint(_ShieldPainter old) => old.color != color;
}

/// Avatar rond avec l'initiale, entouré de l'anneau de progression du niveau.
class Avatar extends StatelessWidget {
  const Avatar({super.key, required this.name, this.size = 52, this.progress, this.level});
  final String name;
  final double size;
  final double? progress;
  final int? level;

  static const _colors = [Color(0xFFE76F51), Color(0xFF2A9D8F), Color(0xFF8E7DFF), Color(0xFFF4A261), Color(0xFF4CC9F0), Color(0xFFEF476F)];

  @override
  Widget build(BuildContext context) {
    final color = _colors[name.codeUnits.fold(0, (a, b) => a + b) % _colors.length];
    return SizedBox(
      width: size + 8,
      height: size + 8,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          if (progress != null)
            SizedBox(
              width: size + 8,
              height: size + 8,
              child: CircularProgressIndicator(
                value: progress,
                strokeWidth: 3.5,
                backgroundColor: Colors.black38,
                valueColor: const AlwaysStoppedAnimation(Palette.mint),
              ),
            ),
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(colors: [Color.lerp(color, Colors.white, 0.2)!, color]),
            ),
            alignment: Alignment.center,
            child: Text(name.isEmpty ? '?' : name[0].toUpperCase(), style: display(size * 0.48)),
          ),
          if (level != null)
            Positioned(
              bottom: -4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
                decoration: BoxDecoration(
                  color: Palette.night,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Palette.mint, width: 1.5),
                ),
                child: Text('$level', style: display(12, color: Palette.mint)),
              ),
            ),
        ],
      ),
    );
  }
}

/// Message bref en bas de l'écran.
void toast(BuildContext context, String text) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(text, style: body(14)),
      backgroundColor: Palette.panel,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      duration: const Duration(seconds: 2),
    ));
}
