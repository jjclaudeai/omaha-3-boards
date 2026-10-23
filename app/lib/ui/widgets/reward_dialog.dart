import 'dart:math';

import 'package:flutter/material.dart';

import '../theme.dart';
import 'common.dart';

/// Fenêtre de récompense : pièces qui jaillissent et montant qui défile.
Future<void> showReward(BuildContext context, {required String title, required int coins, String? subtitle}) {
  return showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Fermer',
    barrierColor: Colors.black87,
    transitionDuration: const Duration(milliseconds: 380),
    pageBuilder: (context, a, b) => _RewardView(title: title, coins: coins, subtitle: subtitle),
    transitionBuilder: (context, a, b, child) => ScaleTransition(
      scale: CurvedAnimation(parent: a, curve: Curves.easeOutBack),
      child: FadeTransition(opacity: a, child: child),
    ),
  );
}

class _RewardView extends StatefulWidget {
  const _RewardView({required this.title, required this.coins, this.subtitle});
  final String title;
  final int coins;
  final String? subtitle;

  @override
  State<_RewardView> createState() => _RewardViewState();
}

class _RewardViewState extends State<_RewardView> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))..forward();
  final _rng = Random();
  late final _coins = List.generate(14, (i) => (angle: _rng.nextDouble() * 2 * pi, dist: 70 + _rng.nextDouble() * 70));

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Material(
        color: Colors.transparent,
        child: SizedBox(
          width: 300,
          child: Panel(
            gradient: const LinearGradient(
              colors: [Color(0xFF213B63), Color(0xFF14243F)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderColor: Palette.gold.withValues(alpha: 0.5),
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(widget.title, style: display(24), textAlign: TextAlign.center),
                if (widget.subtitle != null) ...[
                  const SizedBox(height: 4),
                  Text(widget.subtitle!, style: body(14, color: Palette.textLo), textAlign: TextAlign.center),
                ],
                SizedBox(
                  height: 150,
                  child: AnimatedBuilder(
                    animation: _c,
                    builder: (context, _) {
                      final t = Curves.easeOutCubic.transform(_c.value);
                      return Stack(
                        alignment: Alignment.center,
                        children: [
                          for (final c in _coins)
                            Transform.translate(
                              offset: Offset(cos(c.angle) * c.dist * t, sin(c.angle) * c.dist * t * 0.6),
                              child: Opacity(opacity: (1 - t).clamp(0, 1), child: const CoinIcon(size: 18)),
                            ),
                          Transform.scale(scale: 0.6 + 0.4 * Curves.elasticOut.transform(_c.value), child: const CoinIcon(size: 72)),
                        ],
                      );
                    },
                  ),
                ),
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: widget.coins.toDouble()),
                  duration: const Duration(milliseconds: 900),
                  curve: Curves.easeOutCubic,
                  builder: (context, v, _) => Text('+${formatCoins(v.round())}', style: display(38, color: Palette.gold)),
                ),
                const SizedBox(height: 16),
                ChunkyButton(label: 'Super !', onTap: () => Navigator.of(context).pop()),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
