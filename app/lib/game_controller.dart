import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import 'engine/bot.dart';
import 'engine/game.dart';

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

/// Dernière action affichée sous un siège (« Suit », « Relance 24 »…).
class SeatBadge {
  const SeatBadge(this.text, {this.highlight = false});
  final String text;
  final bool highlight;
}

/// Pilote une partie locale contre des bots : enchaîne les mains, fait jouer les bots à leur rythme.
/// En multijoueur, ce rôle passera au serveur ; l'écran ne lira que l'état publié.
class GameController extends ChangeNotifier {
  GameController({Random? rng}) : _rng = rng ?? Random() {
    seats = [
      Seat(id: 'moi', name: 'Vous', stack: startingStack),
      for (var i = 0; i < 5; i++) _newBot(),
    ];
  }

  static const startingStack = 2000;
  static const smallBlind = 10;
  static const bigBlind = 20;
  static const botNames = ['Lucie', 'Marco', 'Inès', 'Hugo', 'Nadia', 'Théo', 'Chloé', 'Samir', 'Jade', 'Louis'];

  final Random _rng;
  late final List<Seat> seats;
  OmahaHand? hand;
  int _button = 0;
  int _botCounter = 0;
  Timer? _timer;
  final Map<String, SeatBadge> badges = {};

  /// Texte du bandeau de résultat, une ligne par board.
  List<String> results = [];

  /// Numéro de la main, pour relancer les animations de distribution.
  int handNumber = 0;

  Seat get hero => seats.first;
  bool get heroToAct => hand?.toAct != null && hand!.players[hand!.toAct!].id == hero.id;
  bool get handOver => hand == null || hand!.isComplete;

  Seat seatById(String id) => seats.firstWhere((s) => s.id == id);

  Seat _newBot() {
    final name = botNames[_botCounter % botNames.length];
    _botCounter++;
    final profile = [BotProfile.facile, BotProfile.moyen, BotProfile.moyen][_rng.nextInt(3)];
    return Seat(id: 'bot$_botCounter', name: name, stack: startingStack, bot: profile);
  }

  void startHand() {
    _timer?.cancel();
    // Un bot ruiné quitte la table et un autre prend sa place, comme un joueur en ligne.
    for (var i = 1; i < seats.length; i++) {
      if (seats[i].stack <= 0) seats[i] = _newBot();
    }
    if (hero.stack <= 0) hero.stack = startingStack; // recharge gratuite du prototype
    _button = (_button + 1) % seats.length;
    badges.clear();
    results = [];
    handNumber++;
    hand = OmahaHand(
      seats: [for (final s in seats) SeatInput(s.id, s.stack)],
      button: _button,
      smallBlind: smallBlind,
      bigBlind: bigBlind,
      rng: _rng,
    );
    for (final e in hand!.events.whereType<BlindEvent>()) {
      badges[e.id] = SeatBadge(e.amount == smallBlind ? 'Petite blinde' : 'Grosse blinde');
    }
    _sync();
    _scheduleBot();
  }

  int get button => _button;

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
    _sync();
    if (h.isComplete) {
      _announce();
    } else {
      _scheduleBot();
    }
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

  void _sync() {
    for (final p in hand!.players) {
      seatById(p.id).stack = p.stack;
    }
    notifyListeners();
  }

  void _announce() {
    final h = hand!;
    final uncontested = h.events.whereType<UncontestedWinEvent>();
    if (uncontested.isNotEmpty) {
      final e = uncontested.first;
      results = ['${seatById(e.id).name} remporte ${e.amount} sans abattage'];
    } else {
      final lines = <String>[];
      for (var b = 0; b < boardCount; b++) {
        final wins = h.events.whereType<BoardWinEvent>().where((e) => e.board == b && e.pot == 0);
        if (wins.isEmpty) continue;
        final w = wins.first;
        final names = w.winners.map((id) => seatById(id).name).join(' et ');
        final handName = h.showdownHands[w.winners.first]![b].name;
        lines.add('Board ${b + 1} : $names ($handName)');
      }
      results = lines;
    }
    for (final e in h.winnings.entries) {
      badges[e.key] = SeatBadge('+${e.value}', highlight: true);
    }
    notifyListeners();
    _timer = Timer(const Duration(seconds: 5), startHand);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
