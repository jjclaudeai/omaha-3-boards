import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import 'engine/bot.dart';
import 'engine/evaluator.dart';
import 'engine/game.dart';
import 'engine/omaha.dart';
import 'engine/pots.dart' show point;
import 'state/catalog.dart';
import 'state/profile.dart';

/// Un siège de la table : le joueur humain ou un bot.
class Seat {
  Seat({required this.id, required this.name, required this.stack, this.bot});
  final String id;
  final String name;
  int stack;

  /// null pour le joueur humain.
  final BotProfile? bot;
  bool get isHuman => bot == null;
}

/// Dernière action affichée sous un siège (« Suit 20 », « Relance à 80 »…).
class SeatBadge {
  const SeatBadge(this.text, {this.highlight = false});
  final String text;
  final bool highlight;
}

/// Ce que l'écran montre pendant l'abattage d'un board (pot principal).
class BoardReveal {
  const BoardReveal({required this.board, required this.winners, required this.handName, required this.best, required this.tally});
  final int board;

  /// Joueurs qui prennent le point de ce board (plusieurs = point partagé).
  final List<String> winners;
  final String handName;

  /// Main gagnante (2 cartes privées + 3 du board) du premier gagnant.
  final BestHand best;

  /// Score cumulé après ce board, en soixantièmes de point.
  final Map<String, int> tally;
}

/// Résultat d'un pot : qui le remporte, combien, avec combien de points.
class PotResult {
  const PotResult({required this.pot, required this.winners, required this.amount, required this.points});
  final int pot;
  final List<String> winners;
  final int amount;
  final Map<String, int> points;
}

/// Points affichés : 1, 1,5, 0,5, 2…
String formatPoints(int sixtieths) {
  final v = sixtieths / point;
  if (v == v.roundToDouble()) return v.round().toString();
  return v.toStringAsFixed(v * 2 == (v * 2).roundToDouble() ? 1 : 2).replaceAll('.', ',');
}

enum Phase { betting, revealCards, revealBoard, revealPot, summary }

/// Pilote une partie locale contre des bots : enchaîne les mains, fait jouer les bots à leur rythme,
/// puis déroule l'abattage board par board. En multijoueur, ce rôle passera au serveur.
class GameController extends ChangeNotifier {
  GameController({required this.room, required this.profile, Random? rng}) : _rng = rng ?? Random() {
    seats.add(Seat(id: 'moi', name: profile.name, stack: 0));
    for (var i = 0; i < 5; i++) {
      seats.add(_newBot());
    }
    _button = _rng.nextInt(seats.length);
  }

  final Room room;
  final PlayerProfile profile;
  static const botNames = ['Lucie', 'Marco', 'Inès', 'Hugo', 'Nadia', 'Théo', 'Chloé', 'Samir', 'Jade', 'Louis', 'Emma', 'Yanis'];

  /// Rythme de l'abattage, réglable pour les tests.
  Duration revealPause = const Duration(milliseconds: 1100);
  Duration boardPause = const Duration(milliseconds: 2300);
  Duration summaryPause = const Duration(milliseconds: 3500);

  final Random _rng;
  final List<Seat> seats = [];
  OmahaHand? hand;
  int _button = 0;
  int _botCounter = 0;
  Timer? _timer;
  final Map<String, SeatBadge> badges = {};
  Phase phase = Phase.betting;

  /// Board en cours de dévoilement (0 à 2), pendant [Phase.revealBoard].
  int revealIndex = -1;
  List<BoardReveal> reveals = [];
  List<PotResult> potResults = [];

  /// Points de ligue gagnés sur la dernière main.
  int lastLeaguePoints = 0;
  int handNumber = 0;
  bool autoNext = true;

  Seat get hero => seats.first;
  int get button => _button;
  bool get heroToAct => phase == Phase.betting && hand?.toAct == 0;
  bool get handOver => hand == null || phase == Phase.summary;
  bool get heroBroke => hero.stack < room.bigBlind;

  Seat seatById(String id) => seats.firstWhere((s) => s.id == id);

  Seat _newBot() {
    final used = seats.skip(1).map((s) => s.name).toSet();
    var name = botNames[_botCounter % botNames.length];
    for (var k = 0; used.contains(name) && k < botNames.length; k++) {
      name = botNames[(_botCounter + k) % botNames.length];
    }
    _botCounter++;
    final profiles = [BotProfile.facile, BotProfile.moyen, BotProfile.moyen, BotProfile.difficile];
    final level = min(profiles.length - 1, rooms.indexOf(room) + _rng.nextInt(2));
    // Les bots arrivent avec une cave proche de la nôtre.
    final stack = (room.buyIn * (0.7 + _rng.nextDouble() * 0.8)).round();
    return Seat(id: 'bot$_botCounter', name: name, stack: stack, bot: profiles[level]);
  }

  // ---------- Entrée, sortie, recave ----------

  /// Prend la cave dans les pièces du joueur. Renvoie false s'il n'a pas assez.
  bool sitDown() {
    if (!profile.spend(room.buyIn)) return false;
    hero.stack = room.buyIn;
    startHand();
    return true;
  }

  bool rebuy() {
    if (!profile.spend(room.buyIn - hero.stack)) return false;
    hero.stack = room.buyIn;
    notifyListeners();
    return true;
  }

  /// Quitte la table : les jetons devant le joueur retournent dans ses pièces.
  /// Quitter en pleine main abandonne ce qui est déjà misé.
  void leave() {
    _timer?.cancel();
    final h = hand;
    final onTable = h != null && !h.isComplete ? h.players[0].stack : hero.stack;
    profile.earn(onTable);
    hero.stack = 0;
  }

  // ---------- Main ----------

  void startHand() {
    _timer?.cancel();
    if (heroBroke) {
      notifyListeners();
      return;
    }
    // Un bot ruiné quitte la table et un autre prend sa place, comme un joueur en ligne.
    for (var i = 1; i < seats.length; i++) {
      if (seats[i].stack < room.bigBlind) seats[i] = _newBot();
    }
    _button = (_button + 1) % seats.length;
    badges.clear();
    reveals = [];
    potResults = [];
    revealIndex = -1;
    lastLeaguePoints = 0;
    phase = Phase.betting;
    handNumber++;
    hand = OmahaHand(
      seats: [for (final s in seats) SeatInput(s.id, s.stack)],
      button: _button,
      smallBlind: room.smallBlind,
      bigBlind: room.bigBlind,
      rng: _rng,
    );
    final blinds = hand!.events.whereType<BlindEvent>().toList();
    for (var i = 0; i < blinds.length; i++) {
      badges[blinds[i].id] = SeatBadge(i == 0 ? 'Petite blinde' : 'Grosse blinde');
    }
    _afterChange();
  }

  void heroAct(PlayerAction action) {
    if (!heroToAct) return;
    _apply(hero.id, action);
  }

  void _apply(String id, PlayerAction action) {
    final h = hand!;
    final streetBefore = h.street;
    final openingBet = h.currentBet == 0;
    h.act(id, action);
    final ev = h.events.whereType<ActionEvent>().last;
    badges[id] = SeatBadge(_describe(ev, openingBet), highlight: action.type == ActionType.raise);
    if (h.street != streetBefore) {
      // Nouveau tour d'enchères : on efface les badges sauf « Couché » et « Tapis ».
      badges.removeWhere((k, v) => v.text != 'Couché' && v.text != 'Tapis');
    }
    _afterChange();
  }

  String _describe(ActionEvent e, bool openingBet) {
    if (e.allIn) return 'Tapis';
    return switch (e.action.type) {
      ActionType.fold => 'Couché',
      ActionType.check => 'Check',
      ActionType.call => 'Suit ${e.amount}',
      ActionType.raise => openingBet ? 'Mise ${e.action.to}' : 'Relance à ${e.action.to}',
    };
  }

  void _afterChange() {
    final h = hand!;
    if (h.isComplete) {
      _beginShowdown();
      return;
    }
    _syncStacks();
    notifyListeners();
    _scheduleBot();
  }

  void _scheduleBot() {
    final h = hand!;
    if (h.isComplete || h.toAct == null) return;
    final p = h.players[h.toAct!];
    final seat = seatById(p.id);
    if (seat.isHuman) return;
    // Petit délai variable : le bot « réfléchit », la partie garde un rythme naturel.
    _timer = Timer(Duration(milliseconds: 550 + _rng.nextInt(650)), () {
      if (hand != h || h.isComplete) return;
      _apply(p.id, chooseBotAction(h, seat.bot!, _rng));
    });
  }

  /// Tapis affichés : pendant l'abattage, les gains restent dans le pot jusqu'à l'annonce du gagnant.
  void _syncStacks() {
    final h = hand!;
    final holding = h.isComplete && (phase == Phase.revealCards || phase == Phase.revealBoard);
    for (final p in h.players) {
      seatById(p.id).stack = p.stack - (holding ? h.winnings[p.id] ?? 0 : 0);
    }
  }

  // ---------- Abattage board par board ----------

  void _beginShowdown() {
    final h = hand!;
    _recordOutcome();
    if (h.showdownHands.isEmpty) {
      // Tout le monde s'est couché : pas d'abattage.
      final e = h.events.whereType<UncontestedWinEvent>().first;
      badges[e.id] = SeatBadge('+${formatAmount(e.amount)}', highlight: true);
      _finish();
      return;
    }
    potResults = [
      for (final e in h.events.whereType<PotWinEvent>())
        PotResult(pot: e.pot, winners: e.winners, amount: e.amount, points: e.points),
    ];
    final tally = <String, int>{};
    reveals = [
      for (final e in h.events.whereType<BoardWinEvent>().where((e) => e.pot == 0))
        () {
          for (final id in e.winners) {
            tally[id] = (tally[id] ?? 0) + point ~/ e.winners.length;
          }
          final best = h.showdownHands[e.winners.first]![e.board];
          return BoardReveal(board: e.board, winners: e.winners, handName: best.name, best: best, tally: Map.of(tally));
        }(),
    ];
    badges.removeWhere((k, v) => v.text != 'Couché');
    phase = Phase.revealCards;
    _syncStacks();
    notifyListeners();
    _timer = Timer(revealPause, () => _revealBoard(0));
  }

  void _revealBoard(int b) {
    phase = Phase.revealBoard;
    revealIndex = b;
    final r = reveals[b];
    badges.removeWhere((k, v) => v.text != 'Couché');
    // Le score de chacun s'affiche sous son siège et grandit board après board.
    r.tally.forEach((id, pts) {
      badges[id] = SeatBadge('${formatPoints(pts)} pt${pts > point ? 's' : ''}', highlight: r.winners.contains(id));
    });
    _syncStacks();
    notifyListeners();
    _timer = Timer(boardPause, () => b + 1 < boardCount ? _revealBoard(b + 1) : _revealPot());
  }

  void _revealPot() {
    phase = Phase.revealPot;
    revealIndex = -1;
    final h = hand!;
    badges.removeWhere((k, v) => v.text != 'Couché');
    for (final e in h.winnings.entries) {
      badges[e.key] = SeatBadge('+${formatAmount(e.value)}', highlight: true);
    }
    _syncStacks();
    notifyListeners();
    _timer = Timer(boardPause, _finish);
  }

  /// Passe l'abattage en cours (bouton « Passer »).
  void skipReveal() {
    if (phase == Phase.revealCards || phase == Phase.revealBoard || phase == Phase.revealPot) _finish();
  }

  void _finish() {
    _timer?.cancel();
    phase = Phase.summary;
    revealIndex = -1;
    final h = hand!;
    badges.removeWhere((k, v) => v.text != 'Couché');
    for (final e in h.winnings.entries) {
      badges[e.key] = SeatBadge('+${formatAmount(e.value)}', highlight: true);
    }
    _syncStacks();
    notifyListeners();
    if (autoNext && !heroBroke) _timer = Timer(summaryPause, startHand);
  }

  void _recordOutcome() {
    final h = hand!;
    final me = h.players[0];
    final startStack = me.stack - (h.winnings[me.id] ?? 0) + me.totalBet;
    var won = 0, bestCat = -1;
    for (final e in h.events.whereType<BoardWinEvent>().where((e) => e.pot == 0)) {
      if (e.winners.contains(me.id)) {
        won++;
        bestCat = max(bestCat, categoryOf(h.showdownHands[me.id]![e.board].score));
      }
    }
    final mainPot = h.events.whereType<PotWinEvent>().where((e) => e.pot == 0);
    // Pot gagné sans abattage : compte comme un board, sans rafle.
    final uncontested = h.events.whereType<UncontestedWinEvent>().any((e) => e.id == me.id);
    if (uncontested) won = 1;
    final potWon = uncontested || (mainPot.isNotEmpty && mainPot.first.winners.contains(me.id));
    final scooped = mainPot.isNotEmpty && (mainPot.first.points[me.id] ?? 0) == boardCount * point;
    lastLeaguePoints = profile.recordHand(
      HandOutcome(boardsWon: won, bestWinningCategory: bestCat, scooped: scooped, potWon: potWon, net: me.stack - startStack),
      room,
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

String formatAmount(int n) {
  final s = n.toString();
  final b = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write(' ');
    b.write(s[i]);
  }
  return b.toString();
}
