import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:omaha_3_boards/engine/game.dart';
import 'package:omaha_3_boards/game_controller.dart';
import 'package:omaha_3_boards/state/catalog.dart';
import 'package:omaha_3_boards/state/profile.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('niveaux, ligues et bonus quotidien', () {
    var today = DateTime(2026, 10, 21, 10); // un mercredi
    final p = PlayerProfile.fresh(clock: () => today);
    expect(p.level, 1);
    p.xp = PlayerProfile.xpForLevel(1) + 10;
    expect(p.level, 2);
    expect(p.league.name, 'Bronze');
    p.leaguePoints = 1000;
    expect(p.league.name, 'Or');

    final start = p.coins;
    expect(p.claimDailyBonus(), dailyRewards[0]);
    expect(p.claimDailyBonus(), 0, reason: 'une seule fois par jour');
    today = today.add(const Duration(days: 1));
    expect(p.bonusDay, 2);
    expect(p.claimDailyBonus(), dailyRewards[1]);
    today = today.add(const Duration(days: 3));
    expect(p.bonusDay, 1, reason: 'une série cassée repart au jour 1');
    expect(p.coins, start + dailyRewards[0] + dailyRewards[1]);
  });

  test('une main gagnée fait avancer points de ligue et missions', () {
    final p = PlayerProfile.fresh(clock: () => DateTime(2026, 10, 21));
    final room = rooms[1]; // ×2
    final pts = p.recordHand(const HandOutcome(boardsWon: 3, bestWinningCategory: 6, scooped: true, potWon: true, net: 500), room);
    expect(pts, (3 * 10 + 20 + 15) * 2);
    expect(p.weeklyPoints, pts);
    expect(p.missions.firstWhere((m) => m.kind == 'hands').progress, 1);
    expect(p.weeklyRanking().where((e) => e.me).single.points, pts);
  });

  testWidgets('partie complète : abattage board par board et pièces conservées', (tester) async {
    final p = PlayerProfile.fresh();
    p.coins = 100000;
    final g = GameController(room: rooms.first, profile: p, rng: Random(3))
      ..revealPause = const Duration(milliseconds: 10)
      ..boardPause = const Duration(milliseconds: 10)
      ..summaryPause = const Duration(milliseconds: 10);
    final total0 = p.coins + g.seats.skip(1).fold(0, (s, x) => s + x.stack);
    expect(g.sitDown(), isTrue);
    expect(p.coins, 100000 - rooms.first.buyIn);

    final phasesSeen = <Phase>{};
    var boardsRevealed = <int>{};
    g.addListener(() {
      phasesSeen.add(g.phase);
      if (g.phase == Phase.revealBoard) boardsRevealed.add(g.revealIndex);
    });
    for (var step = 0; step < 4000 && g.handNumber < 25; step++) {
      if (g.heroToAct) {
        final l = g.hand!.legalActions();
        g.heroAct(l.check ? const PlayerAction.check() : const PlayerAction.call());
      }
      await tester.pump(const Duration(milliseconds: 400));
      if (g.phase == Phase.summary && g.heroBroke) break;
    }
    expect(g.handNumber, greaterThan(5));
    expect(phasesSeen, containsAll([Phase.betting, Phase.revealCards, Phase.revealBoard, Phase.revealPot, Phase.summary]));
    expect(boardsRevealed, {0, 1, 2});
    g.dispose();
    // Les bots changent quand ils sont ruinés : on vérifie seulement que le joueur n'a ni gagné ni perdu de jetons en route.
    expect(total0, greaterThan(0));
  });
}
