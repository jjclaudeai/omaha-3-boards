import 'dart:math';

import 'cards.dart';
import 'game.dart';
import 'omaha.dart';

class BotProfile {
  const BotProfile({required this.samples, required this.aggression, required this.bluff});

  /// Tirages Monte-Carlo par décision : plus = plus fort et plus lent.
  final int samples;

  /// 0 = prudent, 1 = très agressif.
  final double aggression;

  /// Probabilité de bluffer quand personne n'a misé.
  final double bluff;

  static const facile = BotProfile(samples: 40, aggression: 0.2, bluff: 0.02);
  static const moyen = BotProfile(samples: 120, aggression: 0.5, bluff: 0.06);
  static const difficile = BotProfile(samples: 300, aggression: 0.7, bluff: 0.1);
}

/// Part du pot gagnée en moyenne contre [opponents] mains aléatoires ; chaque board vaut un tiers.
double estimateEquity(List<CardId> hole, List<List<CardId>> boards, int opponents, int samples, Random rng) {
  final known = {...hole, ...boards.expand((b) => b)};
  final rest = newDeck().where((c) => !known.contains(c)).toList();
  final missing = 5 - boards[0].length;
  final needed = opponents * holeCards + missing * boardCount;
  var total = 0.0;
  for (var s = 0; s < samples; s++) {
    for (var i = 0; i < needed; i++) {
      final j = i + rng.nextInt(rest.length - i);
      final t = rest[i];
      rest[i] = rest[j];
      rest[j] = t;
    }
    var k = 0;
    final opp = <List<CardId>>[];
    for (var o = 0; o < opponents; o++) {
      opp.add(rest.sublist(k, k + holeCards));
      k += holeCards;
    }
    for (final b in boards) {
      final full = [...b, ...rest.sublist(k, k + missing)];
      k += missing;
      final mine = bestOmahaScore(hole, full);
      var best = mine;
      var ties = 1;
      for (final h in opp) {
        final sc = bestOmahaScore(h, full);
        if (sc > best) {
          ties = 0;
          break;
        }
        if (sc == best) ties++;
      }
      if (ties > 0) total += 1 / ties / boardCount;
    }
  }
  return total / samples;
}

/// Choisit une action légale pour le joueur qui doit parler.
PlayerAction chooseBotAction(OmahaHand hand, BotProfile profile, Random rng) {
  final me = hand.players[hand.toAct!];
  final legal = hand.legalActions();
  final opponents = hand.players.where((p) => p != me && !p.folded).length;
  final equity = estimateEquity(me.hole, hand.boards, opponents, profile.samples, rng);

  final toCall = legal.call;
  final potAfterCall = hand.pot + toCall;
  final potOdds = toCall / potAfterCall;
  final strength = equity * (opponents + 1); // 1 = main moyenne
  final noise = (rng.nextDouble() - 0.5) * 0.3;

  PlayerAction? raiseTo(double fraction) {
    if (!legal.canRaise) return null;
    final target = hand.currentBet + toCall + (fraction * potAfterCall).round();
    return PlayerAction.raise(target.clamp(legal.raiseMin!, legal.raiseMax!));
  }

  if (strength + noise > 1.6 - profile.aggression * 0.4) {
    final r = raiseTo(0.5 + profile.aggression * 0.5);
    if (r != null) return r;
  }
  if (legal.check) {
    if (rng.nextDouble() < profile.bluff) return raiseTo(0.5) ?? const PlayerAction.check();
    return const PlayerAction.check();
  }
  if (equity + noise * 0.2 >= potOdds) return const PlayerAction.call();
  return const PlayerAction.fold();
}
