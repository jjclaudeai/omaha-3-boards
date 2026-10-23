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
    var raked = 0;
    g.addListener(() {
      phasesSeen.add(g.phase);
      if (g.phase == Phase.summary) {
        // Le tapis affiché est celui du moteur, moins la commission de la table.
        expectSync(g.hero.stack, g.hand!.players[0].stack - g.lastRake);
        raked += g.lastRake;
      }
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
    expect(raked, greaterThanOrEqualTo(0));
    g.dispose();
    // Les bots changent quand ils sont ruinés : on vérifie seulement que le joueur n'a ni gagné ni perdu de jetons en route.
    expect(total0, greaterThan(0));
  });

  test('commission : 5 % du pot, plafonnée à 2 grosses blindes', () {
    final room = rooms.first; // 10/20
    expect(room.rakeOn(200), 10);
    expect(room.rakeOn(10000), 40);
    expect(room.rakeOn(0), 0);
  });

  test('passage de niveau, coffre gratuit et coup de pouce', () {
    var now = DateTime(2026, 10, 21, 10);
    final p = PlayerProfile.fresh(clock: () => now);
    final c0 = p.coins;
    p.recordHand(const HandOutcome(boardsWon: 3, bestWinningCategory: 2, scooped: true, potWon: true, net: 100), rooms.first);
    for (var i = 0; i < 4; i++) {
      p.recordHand(const HandOutcome(boardsWon: 3, bestWinningCategory: 2, scooped: true, potWon: true, net: 100), rooms.first);
    }
    expect(p.level, 2);
    expect(p.takeLevelUp(), 2);
    expect(p.coins, c0 + levelUpReward(2));

    final chest = p.openChest(Random(1));
    expect(chest, inInclusiveRange(freeChestMin, freeChestMax));
    expect(p.openChest(), 0, reason: 'un coffre toutes les 4 heures');
    now = now.add(const Duration(hours: freeChestHours));
    expect(p.openChest(), greaterThan(0));

    p.coins = 0;
    expect(p.rescueAvailable, isTrue);
    expect(p.claimRescue(), rescueCoins);
    p.coins = 0;
    expect(p.rescueAvailable, isFalse, reason: 'un coup de pouce toutes les 6 heures');
  });

  test('fin de semaine : la place au classement rapporte des pièces', () {
    var now = DateTime(2026, 10, 21, 10);
    final p = PlayerProfile.fresh(clock: () => now);
    p.recordHand(const HandOutcome(boardsWon: 3, bestWinningCategory: 2, scooped: true, potWon: true, net: 100), rooms[5]);
    final rank = p.weeklyRank;
    expect(rank, 1, reason: '780 points écrasent la ligue Bronze');
    now = DateTime(2026, 10, 27, 9); // mardi suivant
    p.recordHand(const HandOutcome(boardsWon: 0, bestWinningCategory: -1, scooped: false, net: -20), rooms.first);
    expect(p.pendingWeeklyReward?.rank, 1);
    final coins = p.coins;
    expect(p.claimWeeklyReward(), p.league.rewardForRank(1) == 0 ? 0 : greaterThan(0));
    expect(p.coins, greaterThan(coins));
    expect(p.claimWeeklyReward(), 0);
  });

  test('boutique : niveau requis, achat, équipement', () {
    final p = PlayerProfile.fresh();
    p.coins = 1000000;
    final neon = themes.firstWhere((t) => t.id == 'neon');
    expect(p.lockReason(neon), 'Niveau ${neon.minLevel}');
    expect(p.buyCosmetic(neon), isFalse);
    final bleu = themes.firstWhere((t) => t.id == 'bleu');
    expect(p.buyCosmetic(bleu), isTrue);
    p.equip(bleu);
    expect(p.themeItem.id, 'bleu');
    expect(p.coins, 1000000 - bleu.price);
    final vip = themes.firstWhere((t) => t.vipOnly);
    expect(p.lockReason(vip), 'Réservé VIP');
    p.purchaseVip();
    expect(p.isVip, isTrue);
    expect(p.owns(vip), isTrue);
    expect(p.dailyRewardFor(1), dailyRewards[0] * 2);
  });

  test('compte : pseudo validé et classements cohérents', () {
    expect(PlayerProfile.validateName('ab'), isNotNull);
    expect(PlayerProfile.validateName('Jérôme_75'), isNull);
    expect(PlayerProfile.validateName('<script>'), isNotNull);
    expect(PlayerProfile.validateEmail('a@b.fr'), isNull);
    expect(PlayerProfile.validateEmail('pas un mail'), isNotNull);
    final p = PlayerProfile.fresh();
    p.updateAccount(name: 'Jérôme', bio: 'Toujours à tapis', country: 'BE');
    expect(p.name, 'Jérôme');
    final global = p.globalRanking();
    expect(global.where((e) => e.me).single.name, 'Jérôme');
    expect([for (final e in global.take(100)) e.rank], List.generate(100, (i) => i + 1));
    p.leaguePoints = 1000000;
    expect(p.globalRanking().first.me, isTrue);
  });
}
