import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../engine/cards.dart';
import '../engine/game.dart';
import '../game_controller.dart';
import 'card_widget.dart';

const _gold = Color(0xFFFFD54F);

class TableScreen extends StatefulWidget {
  const TableScreen({super.key});

  @override
  State<TableScreen> createState() => _TableScreenState();
}

class _TableScreenState extends State<TableScreen> {
  final game = GameController();

  @override
  void initState() {
    super.initState();
    game.startHand();
  }

  @override
  void dispose() {
    game.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            colors: [Color(0xFF14432B), Color(0xFF07170F)],
            radius: 1.1,
          ),
        ),
        child: SafeArea(
          child: ListenableBuilder(
            listenable: game,
            builder: (context, _) => Column(
              children: [
                _TopBar(game: game),
                Expanded(child: _Table(game: game)),
                _HeroArea(game: game),
                _ActionBar(game: game),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.game});
  final GameController game;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Row(
        children: [
          const Text(
            'Omaha 3 boards',
            style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700),
          ),
          const Spacer(),
          Text(
            'Blindes ${GameController.smallBlind}/${GameController.bigBlind}',
            style: const TextStyle(color: Colors.white60, fontSize: 13),
          ),
          const SizedBox(width: 12),
          _ChipCount(amount: game.hero.stack),
        ],
      ),
    );
  }
}

class _ChipCount extends StatelessWidget {
  const _ChipCount({required this.amount, this.small = false});
  final int amount;
  final bool small;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: small ? 6 : 10, vertical: small ? 2 : 4),
      decoration: BoxDecoration(color: Colors.black45, borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.circle, size: small ? 9 : 12, color: _gold),
          SizedBox(width: small ? 3 : 5),
          Text(
            formatChips(amount),
            style: TextStyle(color: Colors.white, fontSize: small ? 11.5 : 14, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

String formatChips(int n) {
  final s = n.toString();
  final b = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write(' ');
    b.write(s[i]);
  }
  return b.toString();
}

/// La table : 5 bots autour, les 3 boards et le pot au centre.
class _Table extends StatelessWidget {
  const _Table({required this.game});
  final GameController game;

  // Positions des sièges 1 à 5 (le siège 0, le joueur, est sous la table).
  // Les sièges occupent une bande en haut et une en bas : les boards gardent tout le centre.
  static const _seatAlign = [
    Alignment(-1, 1),
    Alignment(-1, -0.8),
    Alignment(0, -1),
    Alignment(1, -0.8),
    Alignment(1, 1),
  ];
  static const _seatHeight = 112.0;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, box) {
      final w = box.maxWidth;
      // Taille des cartes du board : limitée par la largeur et par la hauteur laissée entre les sièges.
      final byHeight = (box.maxHeight - 2 * _seatHeight - 56) / (3 * 1.4 + 0.3);
      final boardCard = max(28.0, min(46.0, min((w * 0.62 - 26 - 4 * 4) / 5, byHeight)));
      return Stack(
        children: [
          Positioned.fill(
            left: 28,
            right: 28,
            top: 36,
            bottom: 8,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(w),
                gradient: const RadialGradient(colors: [Color(0xFF2E8B57), Color(0xFF1B5E3A)], radius: 0.9),
                border: Border.all(color: const Color(0xFF4E342E), width: 9),
                boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 18, spreadRadius: 2)],
              ),
            ),
          ),
          Center(child: _Boards(game: game, cardWidth: boardCard)),
          for (var i = 1; i < game.seats.length; i++)
            Align(
              alignment: _seatAlign[i - 1],
              child: _BotSeat(game: game, seatIndex: i),
            ),
        ],
      );
    });
  }
}

class _Boards extends StatelessWidget {
  const _Boards({required this.game, required this.cardWidth});
  final GameController game;
  final double cardWidth;

  @override
  Widget build(BuildContext context) {
    final h = game.hand;
    if (h == null) return const SizedBox.shrink();
    final done = h.isComplete && h.showdownHands.isNotEmpty;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(color: Colors.black38, borderRadius: BorderRadius.circular(14)),
          child: Text(
            'Pot ${formatChips(h.isComplete ? h.winnings.values.fold(0, (a, b) => a + b) : h.pot)}',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14),
          ),
        ),
        const SizedBox(height: 8),
        for (var b = 0; b < boardCount; b++) ...[
          _BoardRow(game: game, index: b, cardWidth: cardWidth, highlight: done ? _winningCards(h, b) : null),
          if (b < boardCount - 1) const SizedBox(height: 6),
        ],
      ],
    );
  }

  /// Cartes du board utilisées par le gagnant du pot principal.
  Set<CardId> _winningCards(OmahaHand h, int board) {
    final win = h.events.whereType<BoardWinEvent>().where((e) => e.board == board && e.pot == 0);
    if (win.isEmpty) return {};
    return h.showdownHands[win.first.winners.first]![board].board.toSet();
  }
}

class _BoardRow extends StatelessWidget {
  const _BoardRow({required this.game, required this.index, required this.cardWidth, this.highlight});
  final GameController game;
  final int index;
  final double cardWidth;
  final Set<CardId>? highlight;

  @override
  Widget build(BuildContext context) {
    final cards = game.hand!.boards[index];
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 20,
          height: 20,
          alignment: Alignment.center,
          decoration: const BoxDecoration(color: Colors.black38, shape: BoxShape.circle),
          child: Text('${index + 1}',
              style: const TextStyle(color: Colors.white70, fontSize: 11.5, fontWeight: FontWeight.w700)),
        ),
        const SizedBox(width: 6),
        for (var i = 0; i < 5; i++)
          Padding(
            padding: EdgeInsets.only(right: i < 4 ? 4 : 0),
            child: i < cards.length
                ? DealIn(
                    key: ValueKey('${game.handNumber}-$index-$i'),
                    // Les 3 boards se dévoilent l'un après l'autre, carte par carte.
                    delay: Duration(milliseconds: (i < 3 ? i : 0) * 90 + index * 160),
                    from: const Offset(0, -0.3),
                    child: PlayingCard(
                      card: cards[i],
                      width: cardWidth,
                      glow: highlight?.contains(cards[i]) ?? false,
                      dimmed: highlight != null && highlight!.isNotEmpty && !highlight!.contains(cards[i]),
                    ),
                  )
                : Container(
                    width: cardWidth,
                    height: cardWidth * 1.4,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(cardWidth * 0.12),
                      border: Border.all(color: Colors.white24),
                    ),
                  ),
          ),
      ],
    );
  }
}

class _BotSeat extends StatelessWidget {
  const _BotSeat({required this.game, required this.seatIndex});
  final GameController game;
  final int seatIndex;

  @override
  Widget build(BuildContext context) {
    final seat = game.seats[seatIndex];
    final h = game.hand!;
    final p = h.players[seatIndex];
    final acting = h.toAct == seatIndex;
    final showCards = h.isComplete && h.showdownHands.containsKey(p.id);
    final badge = game.badges[p.id];
    return SizedBox(
      width: 112,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 30,
            child: p.folded
                ? null
                : Stack(
                    clipBehavior: Clip.none,
                    children: [
                      for (var i = 0; i < 6; i++)
                        Positioned(
                          left: 6 + i * 15.0,
                          child: DealIn(
                            key: ValueKey('${game.handNumber}-$seatIndex-$i'),
                            delay: Duration(milliseconds: 40 * (i * 6 + seatIndex)),
                            child: PlayingCard(
                              card: p.hole[i],
                              width: showCards ? 22 : 18,
                              faceUp: showCards,
                              dimmed: p.folded,
                            ),
                          ),
                        ),
                    ],
                  ),
          ),
          const SizedBox(height: 4),
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: p.folded ? 0.35 : 0.6),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: acting ? _gold : Colors.white12, width: acting ? 2 : 1),
              boxShadow: acting ? const [BoxShadow(color: Color(0x88FFD54F), blurRadius: 12)] : null,
            ),
            child: Column(
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (game.button == seatIndex) const _DealerButton(),
                    Text(seat.name,
                        style: TextStyle(
                            color: p.folded ? Colors.white38 : Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 13)),
                  ],
                ),
                const SizedBox(height: 2),
                _ChipCount(amount: seat.stack, small: true),
              ],
            ),
          ),
          const SizedBox(height: 3),
          _Badge(badge: badge, bet: p.bet),
        ],
      ),
    );
  }
}

class _DealerButton extends StatelessWidget {
  const _DealerButton();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: 4),
      width: 16,
      height: 16,
      alignment: Alignment.center,
      decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
      child: const Text('D', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.black)),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.badge, required this.bet});
  final SeatBadge? badge;
  final int bet;

  @override
  Widget build(BuildContext context) {
    final b = badge;
    return SizedBox(
      height: 20,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 180),
        transitionBuilder: (child, a) => ScaleTransition(scale: a, child: child),
        child: b == null
            ? const SizedBox.shrink()
            : Container(
                key: ValueKey(b.text),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: b.highlight ? _gold : Colors.white,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(b.text,
                    style: const TextStyle(color: Colors.black87, fontSize: 11.5, fontWeight: FontWeight.w700)),
              ),
      ),
    );
  }
}

/// Le joueur : ses 6 cartes en grand, son tapis et le résultat de la main.
class _HeroArea extends StatelessWidget {
  const _HeroArea({required this.game});
  final GameController game;

  @override
  Widget build(BuildContext context) {
    final h = game.hand!;
    final me = h.players[0];
    final acting = game.heroToAct;
    return LayoutBuilder(builder: (context, box) {
      final cardW = min(58.0, (box.maxWidth - 32 - 5 * 6) / 6);
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
        child: Column(
          children: [
            if (game.results.isNotEmpty) _Results(lines: game.results),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < 6; i++)
                  Padding(
                    padding: EdgeInsets.only(right: i < 5 ? 6 : 0),
                    child: DealIn(
                      key: ValueKey('${game.handNumber}-hero-$i'),
                      delay: Duration(milliseconds: 40 * (i * 6)),
                      from: const Offset(0, -1.2),
                      child: PlayingCard(card: me.hole[i], width: cardW, dimmed: me.folded),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (game.button == 0) const _DealerButton(),
                Text('Vous',
                    style: TextStyle(
                        color: acting ? _gold : Colors.white, fontWeight: FontWeight.w700, fontSize: 14)),
                const SizedBox(width: 8),
                _Badge(badge: game.badges[me.id], bet: me.bet),
              ],
            ),
          ],
        ),
      );
    });
  }
}

class _Results extends StatelessWidget {
  const _Results({required this.lines});
  final List<String> lines;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _gold.withValues(alpha: 0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final l in lines)
            Text(l, style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.4)),
        ],
      ),
    );
  }
}

/// Boutons d'action. La relance se règle avec des raccourcis (min, ½ pot, pot) ou le curseur.
class _ActionBar extends StatefulWidget {
  const _ActionBar({required this.game});
  final GameController game;

  @override
  State<_ActionBar> createState() => _ActionBarState();
}

class _ActionBarState extends State<_ActionBar> {
  double? _raiseTo;

  GameController get game => widget.game;

  void _do(PlayerAction a) {
    HapticFeedback.lightImpact();
    _raiseTo = null;
    game.heroAct(a);
  }

  @override
  Widget build(BuildContext context) {
    final h = game.hand!;
    if (h.isComplete) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: SizedBox(
          width: double.infinity,
          height: 50,
          child: FilledButton(
            style: FilledButton.styleFrom(backgroundColor: _gold, foregroundColor: Colors.black),
            onPressed: game.startHand,
            child: const Text('Main suivante', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          ),
        ),
      );
    }
    if (!game.heroToAct) {
      final who = h.toAct == null ? '' : game.seats[h.toAct!].name;
      return SizedBox(
        height: 74,
        child: Center(
          child: Text(
            h.players[0].folded ? 'Vous êtes couché · $who joue' : '$who réfléchit…',
            style: const TextStyle(color: Colors.white60, fontSize: 14),
          ),
        ),
      );
    }

    final legal = h.legalActions();
    final toCall = legal.call;
    final canRaise = legal.canRaise;
    final rMin = legal.raiseMin ?? 0, rMax = legal.raiseMax ?? 0;
    final raiseTo = (_raiseTo ?? rMin.toDouble()).clamp(rMin.toDouble(), rMax.toDouble()).round();
    int potFraction(double f) =>
        (h.currentBet + toCall + (f * (h.pot + toCall)).round()).clamp(rMin, rMax);
    final isBet = h.currentBet == 0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (canRaise && rMax > rMin)
            Row(
              children: [
                for (final (label, value) in [('Min', rMin), ('½ pot', potFraction(0.5)), ('Pot', rMax)])
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: BorderSide(color: raiseTo == value ? _gold : Colors.white30),
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        minimumSize: const Size(0, 34),
                      ),
                      onPressed: () => setState(() => _raiseTo = value.toDouble()),
                      child: Text(label, style: const TextStyle(fontSize: 13)),
                    ),
                  ),
                Expanded(
                  child: Slider(
                    value: raiseTo.toDouble(),
                    min: rMin.toDouble(),
                    max: rMax.toDouble(),
                    activeColor: _gold,
                    onChanged: (v) => setState(() => _raiseTo = v),
                  ),
                ),
              ],
            ),
          Row(
            children: [
              Expanded(
                child: _BigButton(
                  label: legal.fold ? 'Se coucher' : 'Check',
                  color: legal.fold ? const Color(0xFF8E2A2A) : const Color(0xFF37474F),
                  onTap: () => _do(legal.fold ? const PlayerAction.fold() : const PlayerAction.check()),
                ),
              ),
              if (legal.fold) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: _BigButton(
                    label: 'Suivre ${formatChips(toCall)}',
                    color: const Color(0xFF2E7D32),
                    onTap: () => _do(const PlayerAction.call()),
                  ),
                ),
              ],
              if (canRaise) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: _BigButton(
                    label: raiseTo == h.players[0].bet + h.players[0].stack
                        ? 'Tapis ${formatChips(raiseTo)}'
                        : '${isBet ? 'Miser' : 'Relancer à'} ${formatChips(raiseTo)}',
                    color: const Color(0xFFB8860B),
                    onTap: () => _do(PlayerAction.raise(raiseTo)),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _BigButton extends StatelessWidget {
  const _BigButton({required this.label, required this.color, required this.onTap});
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 50,
      child: FilledButton(
        style: FilledButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(horizontal: 6),
        ),
        onPressed: onTap,
        child: FittedBox(
          child: Text(label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
        ),
      ),
    );
  }
}
