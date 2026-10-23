import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../engine/cards.dart';
import '../engine/game.dart';
import '../game_controller.dart';
import '../state/catalog.dart';
import '../state/profile_scope.dart';
import 'card_widget.dart';
import 'theme.dart';
import 'widgets/common.dart';

class TableScreen extends StatefulWidget {
  const TableScreen({super.key, required this.room});
  final Room room;

  @override
  State<TableScreen> createState() => _TableScreenState();
}

class _TableScreenState extends State<TableScreen> {
  GameController? game;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (game == null) {
      game = GameController(room: widget.room, profile: ProfileScope.read(context));
      game!.sitDown();
    }
  }

  @override
  void dispose() {
    game?.dispose();
    super.dispose();
  }

  Future<void> _leave() async {
    final g = game!;
    final inHand = g.phase == Phase.betting && !g.hand!.players[0].folded && g.hand!.players[0].totalBet > 0;
    if (inHand) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: Palette.panel,
          title: Text('Quitter la table ?', style: display(22)),
          content: Text('Vous êtes dans la main : vos jetons déjà misés seront perdus.', style: body(15, weight: FontWeight.w500)),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: Text('Rester', style: body(15))),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text('Quitter', style: body(15, color: Palette.ruby, weight: FontWeight.w800)),
            ),
          ],
        ),
      );
      if (ok != true) return;
    }
    g.leave();
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final g = game!;
    final profile = ProfileScope.of(context);
    final felt = felts.firstWhere((f) => f.id == profile.felt);
    final back = cardBacks.firstWhere((c) => c.id == profile.cardBack).colors;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _leave();
      },
      child: Scaffold(
        body: Container(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              colors: [Color.lerp(felt.colors.last, Palette.night, 0.55)!, const Color(0xFF060B12)],
              radius: 1.1,
            ),
          ),
          child: SafeArea(
            child: ListenableBuilder(
              listenable: g,
              builder: (context, _) => _TableLook(
                back: back,
                felt: felt.colors,
                child: Column(
                  children: [
                    _TopBar(game: g, onLeave: _leave),
                    Expanded(child: _Table(game: g)),
                    _HeroArea(game: g),
                    _ActionBar(game: g, onLeave: _leave),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Transmet le dos de cartes et le tapis choisis aux widgets de la table.
class _TableLook extends InheritedWidget {
  const _TableLook({required this.back, required this.felt, required super.child});
  final List<Color> back;
  final List<Color> felt;

  static _TableLook of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<_TableLook>()!;

  @override
  bool updateShouldNotify(_TableLook old) => old.back != back || old.felt != felt;
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.game, required this.onLeave});
  final GameController game;
  final VoidCallback onLeave;

  @override
  Widget build(BuildContext context) {
    final room = game.room;
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 6, 16, 0),
      child: Row(
        children: [
          IconButton(
            onPressed: onLeave,
            tooltip: 'Quitter la table',
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Palette.textHi, size: 20),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(room.name, style: display(18)),
              Text('Blindes ${formatCoins(room.smallBlind)}/${formatCoins(room.bigBlind)}', style: body(12, color: Palette.textLo)),
            ],
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: room.color.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(10)),
            child: Text('Ligue ×${room.leagueMultiplier}', style: body(12, color: room.color, weight: FontWeight.w800)),
          ),
          const Spacer(),
          CoinPill(amount: game.profile.coins),
        ],
      ),
    );
  }
}

/// La table : 5 bots autour, les 3 boards et le pot au centre.
class _Table extends StatelessWidget {
  const _Table({required this.game});
  final GameController game;

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
    final look = _TableLook.of(context);
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
                gradient: RadialGradient(colors: look.felt, radius: 0.9),
                border: Border.all(color: const Color(0xFF4E342E), width: 9),
                boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 18, spreadRadius: 2)],
              ),
            ),
          ),
          Center(child: _Boards(game: game, cardWidth: boardCard)),
          for (var i = 1; i < game.seats.length; i++)
            Align(alignment: _seatAlign[i - 1], child: _BotSeat(game: game, seatIndex: i)),
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
    final revealing = game.phase == Phase.revealBoard;
    final potShown = switch (game.phase) {
      Phase.betting => h.pot,
      Phase.revealCards => h.pot,
      Phase.revealBoard => game.reveals.skip(game.revealIndex + 1).fold(0, (s, r) => s + r.amount),
      Phase.summary => 0,
    };
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: game.phase == Phase.summary
              ? _Pill(key: const ValueKey('fin'), text: game.lastLeaguePoints > 0 ? '+${game.lastLeaguePoints} points de ligue' : 'Main terminée', gold: game.lastLeaguePoints > 0)
              : _Pill(key: const ValueKey('pot'), text: 'Pot ${formatCoins(potShown)}'),
        ),
        const SizedBox(height: 8),
        for (var b = 0; b < boardCount; b++) ...[
          _BoardRow(
            game: game,
            index: b,
            cardWidth: cardWidth,
            focus: revealing && game.revealIndex == b,
            dim: revealing && game.revealIndex != b,
            done: (revealing && b < game.revealIndex) || (game.phase == Phase.summary && game.reveals.isNotEmpty),
          ),
          if (b < boardCount - 1) const SizedBox(height: 6),
        ],
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({super.key, required this.text, this.gold = false});
  final String text;
  final bool gold;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: gold ? Palette.gold : Colors.black38,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(text, style: display(15, color: gold ? const Color(0xFF3A2400) : Palette.textHi)),
    );
  }
}

class _BoardRow extends StatelessWidget {
  const _BoardRow({
    required this.game,
    required this.index,
    required this.cardWidth,
    required this.focus,
    required this.dim,
    required this.done,
  });
  final GameController game;
  final int index;
  final double cardWidth;
  final bool focus;
  final bool dim;
  final bool done;

  @override
  Widget build(BuildContext context) {
    final cards = game.hand!.boards[index];
    final reveal = game.reveals.length > index ? game.reveals[index] : null;
    final used = focus ? reveal!.best.board.toSet() : const <CardId>{};
    final winnerName = reveal == null ? '' : reveal.winners.map((id) => game.seatById(id).name).join(' et ');
    return AnimatedScale(
      scale: focus ? 1.08 : 1,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutBack,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: focus ? Colors.black.withValues(alpha: 0.28) : Colors.transparent,
          border: Border.all(color: focus ? Palette.gold : Colors.transparent, width: 1.5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: 22,
              height: 22,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: focus ? Palette.gold : Colors.black38, shape: BoxShape.circle),
              child: Text('${index + 1}', style: display(13, color: focus ? const Color(0xFF3A2400) : Palette.textLo)),
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
                          glow: used.contains(cards[i]),
                          dimmed: dim || (focus && !used.contains(cards[i])),
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
            // Gagnant du board, une fois montré.
            AnimatedSize(
              duration: const Duration(milliseconds: 250),
              child: done && reveal != null
                  ? Padding(
                      padding: const EdgeInsets.only(left: 6),
                      child: Tooltip(message: '$winnerName · ${reveal.handName}', child: Avatar(name: winnerName, size: 22)),
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
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
    final acting = game.phase == Phase.betting && h.toAct == seatIndex;
    final showCards = game.phase != Phase.betting && h.showdownHands.containsKey(p.id);
    final reveal = game.phase == Phase.revealBoard ? game.reveals[game.revealIndex] : null;
    final winning = reveal != null && reveal.winners.contains(p.id);
    final usedHole = winning ? h.showdownHands[p.id]![reveal.board].hole.toSet() : const <CardId>{};
    final badge = game.badges[p.id];
    final back = _TableLook.of(context).back;
    return SizedBox(
      width: 112,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 32,
            child: p.folded
                ? null
                : Stack(
                    clipBehavior: Clip.none,
                    children: [
                      for (var i = 0; i < 6; i++)
                        Positioned(
                          left: 6 + i * 15.0,
                          top: 2,
                          child: DealIn(
                            key: ValueKey('${game.handNumber}-$seatIndex-$i'),
                            delay: Duration(milliseconds: 40 * (i * 6 + seatIndex)),
                            child: PlayingCard(
                              card: p.hole[i],
                              width: showCards ? 22 : 18,
                              faceUp: showCards,
                              back: back,
                              glow: usedHole.contains(p.hole[i]),
                              lift: usedHole.contains(p.hole[i]),
                              dimmed: reveal != null && !usedHole.contains(p.hole[i]),
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
              border: Border.all(
                color: acting || winning ? Palette.gold : Colors.white12,
                width: acting || winning ? 2 : 1,
              ),
              boxShadow: acting || winning ? const [BoxShadow(color: Color(0x88FFD54F), blurRadius: 12)] : null,
            ),
            child: Column(
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (game.button == seatIndex) const _DealerButton(),
                    Text(seat.name,
                        style: body(13.5, color: p.folded ? Colors.white38 : Palette.textHi, weight: FontWeight.w800)),
                  ],
                ),
                const SizedBox(height: 2),
                _StackChip(amount: seat.stack),
              ],
            ),
          ),
          const SizedBox(height: 3),
          _Badge(badge: badge),
        ],
      ),
    );
  }
}

class _StackChip extends StatelessWidget {
  const _StackChip({required this.amount});
  final int amount;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const CoinIcon(size: 12),
        const SizedBox(width: 4),
        TweenAnimationBuilder<double>(
          tween: Tween(end: amount.toDouble()),
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeOutCubic,
          builder: (context, v, _) => Text(formatCoins(v.round()), style: body(12.5, weight: FontWeight.w800)),
        ),
      ],
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
  const _Badge({required this.badge});
  final SeatBadge? badge;

  @override
  Widget build(BuildContext context) {
    final b = badge;
    return SizedBox(
      height: 22,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 180),
        transitionBuilder: (child, a) => ScaleTransition(scale: a, child: child),
        child: b == null
            ? const SizedBox.shrink()
            : Container(
                key: ValueKey(b.text),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: b.highlight ? Palette.gold : Colors.white,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(b.text, style: body(12, color: const Color(0xFF1A1A1A), weight: FontWeight.w800)),
              ),
      ),
    );
  }
}

/// Le joueur : ses 6 cartes en grand, son tapis, et le récit de l'abattage.
class _HeroArea extends StatelessWidget {
  const _HeroArea({required this.game});
  final GameController game;

  @override
  Widget build(BuildContext context) {
    final h = game.hand!;
    final me = h.players[0];
    final acting = game.heroToAct;
    final reveal = game.phase == Phase.revealBoard ? game.reveals[game.revealIndex] : null;
    final myHand = reveal != null && h.showdownHands.containsKey(me.id) ? h.showdownHands[me.id]![reveal.board] : null;
    final usedHole = myHand?.hole.toSet() ?? const <CardId>{};
    final iWin = reveal != null && reveal.winners.contains(me.id);
    return LayoutBuilder(builder: (context, box) {
      final cardW = min(58.0, (box.maxWidth - 32 - 5 * 6) / 6);
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
        child: Column(
          children: [
            _Narration(game: game),
            const SizedBox(height: 6),
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
                      child: PlayingCard(
                        card: me.hole[i],
                        width: cardW,
                        dimmed: me.folded || (myHand != null && !usedHole.contains(me.hole[i])),
                        lift: usedHole.contains(me.hole[i]),
                        glow: iWin && usedHole.contains(me.hole[i]),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (game.button == 0) const _DealerButton(),
                Text(game.hero.name, style: body(14.5, color: acting ? Palette.gold : Palette.textHi, weight: FontWeight.w800)),
                const SizedBox(width: 8),
                _StackChip(amount: game.hero.stack),
                const SizedBox(width: 8),
                _Badge(badge: game.badges[me.id]),
              ],
            ),
          ],
        ),
      );
    });
  }
}

/// Bandeau qui raconte l'abattage : un board à la fois, qui gagne, avec quelle main, combien.
class _Narration extends StatelessWidget {
  const _Narration({required this.game});
  final GameController game;

  @override
  Widget build(BuildContext context) {
    final h = game.hand!;
    Widget? content;
    switch (game.phase) {
      case Phase.betting:
        content = null;
      case Phase.revealCards:
        content = Text('Abattage : on retourne les cartes', style: display(17), key: const ValueKey('abattage'));
      case Phase.revealBoard:
        final r = game.reveals[game.revealIndex];
        final names = r.winners.map((id) => id == game.hero.id ? 'Vous' : game.seatById(id).name).join(' et ');
        final mine = h.showdownHands[game.hero.id]?[r.board];
        content = Column(
          key: ValueKey('board${r.board}'),
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('BOARD ${r.board + 1} SUR 3', style: body(11.5, color: Palette.gold, weight: FontWeight.w800).copyWith(letterSpacing: 1.4)),
            const SizedBox(height: 2),
            Text(
              '$names ${r.winners.length > 1 ? 'partagent' : r.winners.first == game.hero.id ? 'gagnez' : 'gagne'} ${formatCoins(r.amount)}',
              style: display(19),
              textAlign: TextAlign.center,
            ),
            Text(
              mine != null && !r.winners.contains(game.hero.id)
                  ? '${r.handName} · votre main : ${mine.name.toLowerCase()}'
                  : r.handName,
              style: body(13.5, color: Palette.textLo),
            ),
          ],
        );
      case Phase.summary:
        final uncontested = h.events.whereType<UncontestedWinEvent>();
        if (uncontested.isNotEmpty) {
          final e = uncontested.first;
          final who = e.id == game.hero.id ? 'Vous remportez' : '${game.seatById(e.id).name} remporte';
          content = Text('$who ${formatCoins(e.amount)} sans abattage', style: display(17), key: const ValueKey('sans'), textAlign: TextAlign.center);
        } else {
          content = Row(
            key: const ValueKey('resume'),
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (final r in game.reveals)
                Expanded(
                  child: Column(
                    children: [
                      Text('Board ${r.board + 1}', style: body(11.5, color: Palette.textLo)),
                      Text(
                        r.winners.map((id) => id == game.hero.id ? 'Vous' : game.seatById(id).name).join(', '),
                        style: body(14, color: r.winners.contains(game.hero.id) ? Palette.gold : Palette.textHi, weight: FontWeight.w800),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(r.handName, style: body(11.5, color: Palette.textLo)),
                    ],
                  ),
                ),
            ],
          );
        }
    }
    return AnimatedSize(
      duration: const Duration(milliseconds: 220),
      child: content == null
          ? const SizedBox(width: double.infinity)
          : Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Palette.gold.withValues(alpha: 0.5)),
              ),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                // Seul le nouveau texte est affiché : pas de superposition avec l'ancien.
                layoutBuilder: (current, previous) => current ?? const SizedBox.shrink(),
                transitionBuilder: (child, a) => FadeTransition(
                  opacity: a,
                  child: SlideTransition(position: Tween(begin: const Offset(0.08, 0), end: Offset.zero).animate(a), child: child),
                ),
                child: content,
              ),
            ),
    );
  }
}

/// Boutons d'action. La relance se règle avec des raccourcis (min, ½ pot, pot) ou le curseur.
class _ActionBar extends StatefulWidget {
  const _ActionBar({required this.game, required this.onLeave});
  final GameController game;
  final VoidCallback onLeave;

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

  Widget _wrap(Widget child) =>
      Padding(padding: const EdgeInsets.fromLTRB(12, 8, 12, 12), child: SizedBox(height: 98, child: Center(child: child)));

  @override
  Widget build(BuildContext context) {
    final h = game.hand!;
    if (game.phase == Phase.revealCards || game.phase == Phase.revealBoard) {
      return _wrap(TextButton(
        onPressed: game.skipReveal,
        child: Text('Passer l\'abattage', style: body(14, color: Palette.textLo)),
      ));
    }
    if (game.phase == Phase.summary) {
      if (game.heroBroke) {
        final cost = game.room.buyIn - game.hero.stack;
        return _wrap(Row(
          children: [
            Expanded(child: ChunkyButton(label: 'Quitter', color: const Color(0xFF5B6B84), shade: const Color(0xFF3B4659), textColor: Palette.textHi, onTap: widget.onLeave)),
            const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: ChunkyButton(
                label: 'Recaver ${formatCoins(cost)}',
                enabled: game.profile.coins >= cost,
                onTap: () {
                  if (game.rebuy()) game.startHand();
                },
              ),
            ),
          ],
        ));
      }
      return _wrap(ChunkyButton(label: 'Main suivante', icon: Icons.skip_next_rounded, onTap: game.startHand));
    }
    if (!game.heroToAct) {
      final who = h.toAct == null ? '' : game.seats[h.toAct!].name;
      return _wrap(Text(
        h.players[0].folded ? 'Vous êtes couché · $who joue' : '$who réfléchit…',
        style: body(14, color: Palette.textLo),
      ));
    }

    final legal = h.legalActions();
    final toCall = legal.call;
    final canRaise = legal.canRaise;
    final rMin = legal.raiseMin ?? 0, rMax = legal.raiseMax ?? 0;
    final raiseTo = (_raiseTo ?? rMin.toDouble()).clamp(rMin.toDouble(), rMax.toDouble()).round();
    int potFraction(double f) => (h.currentBet + toCall + (f * (h.pot + toCall)).round()).clamp(rMin, rMax);
    final isBet = h.currentBet == 0;
    final me = h.players[0];

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      child: SizedBox(
        height: 98,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            if (canRaise && rMax > rMin)
              Row(
                children: [
                  for (final (label, value) in [('Min', rMin), ('½ pot', potFraction(0.5)), ('Pot', rMax)])
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: Pressable(
                        onTap: () => setState(() => _raiseTo = value.toDouble()),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
                          decoration: BoxDecoration(
                            color: raiseTo == value ? Palette.gold.withValues(alpha: 0.2) : Colors.black26,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: raiseTo == value ? Palette.gold : Colors.white24),
                          ),
                          child: Text(label, style: body(13)),
                        ),
                      ),
                    ),
                  Expanded(
                    child: SliderTheme(
                      data: SliderTheme.of(context).copyWith(trackHeight: 6),
                      child: Slider(
                        value: raiseTo.toDouble(),
                        min: rMin.toDouble(),
                        max: rMax.toDouble(),
                        activeColor: Palette.gold,
                        inactiveColor: Colors.white24,
                        onChanged: (v) => setState(() => _raiseTo = v),
                      ),
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: legal.fold
                      ? ChunkyButton(
                          label: 'Se coucher',
                          fontSize: 17,
                          color: Palette.ruby,
                          shade: const Color(0xFF8E2620),
                          textColor: Colors.white,
                          onTap: () => _do(const PlayerAction.fold()),
                        )
                      : ChunkyButton(
                          label: 'Check',
                          fontSize: 17,
                          color: const Color(0xFF5B6B84),
                          shade: const Color(0xFF3B4659),
                          textColor: Colors.white,
                          onTap: () => _do(const PlayerAction.check()),
                        ),
                ),
                if (legal.fold) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: ChunkyButton(
                      label: 'Suivre ${formatCoins(toCall)}',
                      fontSize: 17,
                      color: Palette.mint,
                      shade: const Color(0xFF1F9A5F),
                      textColor: const Color(0xFF06301B),
                      onTap: () => _do(const PlayerAction.call()),
                    ),
                  ),
                ],
                if (canRaise) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: ChunkyButton(
                      label: raiseTo == me.bet + me.stack
                          ? 'Tapis ${formatCoins(raiseTo)}'
                          : '${isBet ? 'Miser' : 'Relancer'} ${formatCoins(raiseTo)}',
                      fontSize: 17,
                      onTap: () => _do(PlayerAction.raise(raiseTo)),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
