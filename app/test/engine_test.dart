import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:omaha_3_boards/engine/bot.dart';
import 'package:omaha_3_boards/engine/cards.dart';
import 'package:omaha_3_boards/engine/evaluator.dart';
import 'package:omaha_3_boards/engine/game.dart';
import 'package:omaha_3_boards/engine/omaha.dart';
import 'package:omaha_3_boards/engine/pots.dart';

// Mêmes cas que engine/test/*.test.ts : les deux moteurs doivent donner les mêmes résultats.

List<SeatInput> seats(List<int> stacks) => [for (var i = 0; i < stacks.length; i++) SeatInput('J${i + 1}', stacks[i])];

List<CardId> stackedDeck(List<String> holes, List<String> flops, String turns, String rivers) {
  final top = [...holes.expand(parseCards), ...flops.expand(parseCards), ...parseCards(turns), ...parseCards(rivers)];
  expect(top.toSet().length, top.length, reason: 'cartes en double dans le paquet de test');
  return [...top, ...newDeck().where((c) => !top.contains(c))];
}

void playMaxRaise(OmahaHand h) {
  while (!h.isComplete) {
    final l = h.legalActions();
    final id = h.players[h.toAct!].id;
    if (l.canRaise) {
      h.act(id, PlayerAction.raise(l.raiseMax!));
    } else if (l.call > 0) {
      h.act(id, const PlayerAction.call());
    } else {
      h.act(id, const PlayerAction.check());
    }
  }
}

void main() {
  test('les 2 598 960 mains de 5 cartes : fréquences et 7 462 valeurs distinctes', () {
    final freq = List.filled(9, 0);
    final distinct = <int>{};
    final h = List.filled(5, 0);
    for (h[0] = 0; h[0] < 48; h[0]++) {
      for (h[1] = h[0] + 1; h[1] < 49; h[1]++) {
        for (h[2] = h[1] + 1; h[2] < 50; h[2]++) {
          for (h[3] = h[2] + 1; h[3] < 51; h[3]++) {
            for (h[4] = h[3] + 1; h[4] < 52; h[4]++) {
              final s = evaluate5(h);
              freq[categoryOf(s)]++;
              distinct.add(s);
            }
          }
        }
      }
    }
    expect(freq, [1302540, 1098240, 123552, 54912, 10200, 5108, 3744, 624, 40]);
    expect(distinct.length, 7462);
  });

  test('Omaha : exactement 2 cartes de la main', () {
    final board = parseCards('2h 7h 9h Kh 3c');
    expect(categoryOf(bestOmahaHand(parseCards('Ah As Ad Ac 5s 6d'), board).score), isNot(5));
    expect(categoryOf(bestOmahaHand(parseCards('Ah 4h Ts Jd 5s 6d'), board).score), 5);
  });

  test('Pot-Limit : relance maximale à 7 avec des blindes 1/2', () {
    final h = OmahaHand(seats: seats([500, 500, 500]), button: 0, smallBlind: 1, bigBlind: 2, rng: Random(1));
    expect([h.legalActions().raiseMin, h.legalActions().raiseMax], [4, 7]);
    h.act('J1', const PlayerAction.raise(7));
    expect([h.legalActions().raiseMin, h.legalActions().raiseMax], [12, 23]);
  });

  test('2 boards sur 3 remportent tout le pot', () {
    final deck = stackedDeck(
      ['As Ad 2c 3d 4c 5d', 'Kh Qh 2s 3s 4s 5s'],
      ['Ac 7s 8d', 'Ah 7c 8c', '2h 9h Jc'],
      '9c 9d Th',
      'Tc Td 6c',
    );
    final h = OmahaHand(seats: seats([100, 100]), button: 0, smallBlind: 1, bigBlind: 2, rng: Random(1), deck: deck);
    h.act('J1', const PlayerAction.raise(6));
    h.act('J2', const PlayerAction.call());
    for (var i = 0; i < 3; i++) {
      h.act('J2', const PlayerAction.check());
      h.act('J1', const PlayerAction.check());
    }
    expect(h.winnings, {'J1': 12});
  });

  test('points par board et partage seulement en cas d\'égalité de points', () {
    const order = ['A', 'B', 'C'];
    List<String> win(List<List<String>> boards) => potWinners(boardPoints(boards), order);
    expect(win([['A'], ['A'], ['B']]), ['A']);
    expect(win([['A'], ['B'], ['A', 'B']]), ['A', 'B'], reason: '2 joueurs à 1,5 point');
    expect(win([['A'], ['B'], ['C']]), ['A', 'B', 'C'], reason: '3 joueurs à 1 point');
    expect(win([['A'], ['B', 'C'], ['B', 'C']]), ['A', 'B', 'C']);
    expect(win([['A', 'B'], ['C'], ['C']]), ['C']);
  });

  test('pots annexes avec plusieurs tapis', () {
    final deck = stackedDeck(
      ['As Ad Ah 5c 6c 7d', 'Ks Kd Kh 5d 6d 7c', '2s 3s 2h 3h 4s 4h'],
      ['Ac Kc Jd', 'Qc Jh Tc', 'Th Js 9c'],
      'Ts Qd Qs',
      'Qh Jc Td',
    );
    final h = OmahaHand(seats: seats([20, 50, 100]), button: 0, smallBlind: 1, bigBlind: 2, rng: Random(1), deck: deck);
    playMaxRaise(h);
    expect([for (final p in h.players) p.stack], [60, 60, 50]);
  });

  test('mains aléatoires : jetons conservés et cartes uniques sur 3000 mains', () {
    final r = Random(7);
    for (var n = 0; n < 3000; n++) {
      final count = 2 + r.nextInt(5);
      final stacks = [for (var i = 0; i < count; i++) 1 + r.nextInt(300)];
      final h = OmahaHand(seats: seats(stacks), button: n % count, smallBlind: 1, bigBlind: 2, rng: r);
      final start = stacks.reduce((a, b) => a + b);
      var guard = 0;
      while (!h.isComplete) {
        expect(guard++ < 200, isTrue);
        final l = h.legalActions();
        final options = <PlayerAction>[
          if (l.fold) const PlayerAction.fold(),
          if (l.check) const PlayerAction.check(),
          if (l.call > 0) ...[const PlayerAction.call(), const PlayerAction.call()],
          if (l.canRaise) ...[PlayerAction.raise(l.raiseMin!), PlayerAction.raise(l.raiseMax!)],
        ];
        h.act(h.players[h.toAct!].id, options[r.nextInt(options.length)]);
      }
      final all = [...h.players.expand((p) => p.hole), ...h.boards.expand((b) => b)];
      expect(all.toSet().length, all.length);
      expect(h.players.fold(0, (s, p) => s + p.stack), start);
    }
  });

  test('les bots jouent des mains complètes sans action illégale', () {
    final r = Random(11);
    for (var n = 0; n < 20; n++) {
      final h = OmahaHand(seats: seats(List.filled(6, 200)), button: n % 6, smallBlind: 1, bigBlind: 2, rng: r);
      while (!h.isComplete) {
        h.act(h.players[h.toAct!].id, chooseBotAction(h, BotProfile.facile, r));
      }
      expect(h.players.fold(0, (s, p) => s + p.stack), 1200);
    }
  });
}
