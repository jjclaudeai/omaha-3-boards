import 'dart:math';

import 'cards.dart';
import 'omaha.dart';
import 'pots.dart';

const holeCards = 6;
const boardCount = 3;
const maxPlayers = 6; // 6 × 6 + 3 × 5 = 51 cartes sur 52, sans carte brûlée

enum Street { preflop, flop, turn, river, showdown, complete }

enum ActionType { fold, check, call, raise }

class PlayerAction {
  const PlayerAction(this.type, [this.to = 0]);
  const PlayerAction.fold() : this(ActionType.fold);
  const PlayerAction.check() : this(ActionType.check);
  const PlayerAction.call() : this(ActionType.call);
  const PlayerAction.raise(int to) : this(ActionType.raise, to);
  final ActionType type;

  /// Pour une relance : montant total misé sur ce tour après la relance.
  final int to;
}

class LegalActions {
  const LegalActions({required this.fold, required this.check, required this.call, this.raiseMin, this.raiseMax});
  final bool fold;
  final bool check;

  /// Supplément à payer pour suivre (plafonné au tapis), 0 si rien à suivre.
  final int call;
  final int? raiseMin;
  final int? raiseMax;
  bool get canRaise => raiseMin != null;
}

class SeatInput {
  const SeatInput(this.id, this.stack);
  final String id;
  final int stack;
}

class PlayerState {
  PlayerState(this.id, this.stack);
  final String id;
  int stack;
  List<CardId> hole = [];
  int bet = 0;
  int totalBet = 0;
  bool folded = false;
  bool allIn = false;

  /// Valeur de raiseCounter lors de sa dernière action sur ce tour (-1 = pas encore agi).
  int actedAt = -1;
}

sealed class GameEvent {}

class BlindEvent extends GameEvent {
  BlindEvent(this.id, this.amount);
  final String id;
  final int amount;
}

class ActionEvent extends GameEvent {
  ActionEvent(this.id, this.action, this.amount, this.allIn);
  final String id;
  final PlayerAction action;
  final int amount;
  final bool allIn;
}

class StreetEvent extends GameEvent {
  StreetEvent(this.street);
  final Street street;
}

class BoardWinEvent extends GameEvent {
  BoardWinEvent(this.board, this.pot, this.winners, this.amount);
  final int board;
  final int pot;
  final List<String> winners;
  final int amount;
}

class UncontestedWinEvent extends GameEvent {
  UncontestedWinEvent(this.id, this.amount);
  final String id;
  final int amount;
}

/// Une main d'Omaha 6 cartes Pot-Limit à 3 boards.
/// Portage fidèle du moteur TypeScript (engine/src/game.ts) : garder les deux alignés.
class OmahaHand {
  OmahaHand({
    required List<SeatInput> seats,
    required this.button,
    required this.smallBlind,
    required this.bigBlind,
    required Random rng,
    List<CardId>? deck,
  }) : minRaise = bigBlind {
    final n = seats.length;
    if (n < 2 || n > maxPlayers) throw ArgumentError('Une table compte de 2 à $maxPlayers joueurs');
    if (seats.any((s) => s.stack <= 0)) throw ArgumentError('Chaque joueur doit avoir des jetons');
    _deck = deck != null ? List.of(deck) : shuffled(newDeck(), rng);
    players = [for (final s in seats) PlayerState(s.id, s.stack)];

    // En tête-à-tête, le bouton paie la petite blinde et parle en premier avant le flop.
    final sb = n == 2 ? button : _next(button);
    final bb = _next(sb);
    _post(sb, smallBlind);
    _post(bb, bigBlind);
    currentBet = players.map((p) => p.bet).reduce(max);

    for (final p in players) {
      p.hole = _draw(holeCards);
    }
    toAct = _findNextToAct(bb);
    if (toAct == null) _endStreet();
  }

  late final List<PlayerState> players;
  final int button;
  final int smallBlind;
  final int bigBlind;
  final List<List<CardId>> boards = [[], [], []];
  final List<GameEvent> events = [];
  Street street = Street.preflop;
  int? toAct;
  int currentBet = 0;
  int minRaise;
  int raiseCounter = 0;

  /// Jetons ramassés dans le pot par chaque joueur une fois la main terminée.
  final Map<String, int> winnings = {};

  /// Meilleure main de chaque joueur encore en jeu, par board, après l'abattage.
  Map<String, List<BestHand>> showdownHands = {};
  late List<CardId> _deck;

  int get pot => players.fold(0, (s, p) => s + p.totalBet);
  bool get isComplete => street == Street.complete;

  PlayerState player(String id) => players.firstWhere((p) => p.id == id);

  LegalActions legalActions() {
    final i = toAct;
    if (i == null) return const LegalActions(fold: false, check: false, call: 0);
    final p = players[i];
    final toCall = currentBet - p.bet;
    final callAmount = min(toCall, p.stack);
    int? rMin, rMax;
    final reopened = p.actedAt < raiseCounter;
    final othersCanAct = players.any((q) => q != p && !q.folded && !q.allIn);
    if (reopened && p.stack > toCall && othersCanAct) {
      final allInTo = p.bet + p.stack;
      // Pot-Limit : suivre, puis relancer de la taille du pot après le suivi.
      final potMaxTo = currentBet + pot + toCall;
      rMax = min(potMaxTo, allInTo);
      rMin = min(currentBet + minRaise, allInTo);
    }
    return LegalActions(
      fold: toCall > 0,
      check: toCall == 0,
      call: toCall > 0 ? callAmount : 0,
      raiseMin: rMin,
      raiseMax: rMax,
    );
  }

  void act(String id, PlayerAction action) {
    final idx = toAct;
    if (idx == null) throw StateError('Personne ne doit jouer');
    final p = players[idx];
    if (p.id != id) throw StateError("Ce n'est pas à $id de jouer");
    final legal = legalActions();
    var amount = 0;

    switch (action.type) {
      case ActionType.fold:
        if (!legal.fold) throw StateError('Rien à suivre : checker plutôt que se coucher');
        p.folded = true;
      case ActionType.check:
        if (!legal.check) throw StateError('Impossible de checker face à une mise');
      case ActionType.call:
        if (legal.call <= 0) throw StateError('Rien à suivre');
        amount = _commit(p, legal.call);
      case ActionType.raise:
        if (!legal.canRaise) throw StateError('Relance interdite');
        if (action.to < legal.raiseMin! || action.to > legal.raiseMax!) {
          throw StateError('Relance hors limites : ${action.to} (entre ${legal.raiseMin} et ${legal.raiseMax})');
        }
        final size = action.to - currentBet;
        amount = _commit(p, action.to - p.bet);
        if (size >= minRaise) {
          minRaise = size;
          raiseCounter++;
        }
        currentBet = action.to;
    }
    p.actedAt = raiseCounter;
    events.add(ActionEvent(id, action, amount, p.allIn));

    if (players.where((q) => !q.folded).length == 1) return _finishUncontested();
    toAct = _findNextToAct(idx);
    if (toAct == null) _endStreet();
  }

  int _next(int i) => (i + 1) % players.length;

  List<CardId> _draw(int n) {
    final out = _deck.sublist(0, n);
    _deck.removeRange(0, n);
    return out;
  }

  void _post(int i, int blind) {
    final p = players[i];
    events.add(BlindEvent(p.id, _commit(p, min(blind, p.stack))));
  }

  int _commit(PlayerState p, int amount) {
    p.stack -= amount;
    p.bet += amount;
    p.totalBet += amount;
    if (p.stack == 0) p.allIn = true;
    return amount;
  }

  bool _needsToAct(PlayerState p) => !p.folded && !p.allIn && (p.actedAt < 0 || p.bet < currentBet);

  int? _findNextToAct(int from) {
    final canAct = players.where((p) => !p.folded && !p.allIn).toList();
    if (canAct.length == 1 && canAct.first.bet >= currentBet) return null;
    for (var k = 1; k <= players.length; k++) {
      final i = (from + k) % players.length;
      if (_needsToAct(players[i])) return i;
    }
    return null;
  }

  void _endStreet() {
    for (final p in players) {
      p.bet = 0;
      p.actedAt = -1;
    }
    currentBet = 0;
    minRaise = bigBlind;
    raiseCounter = 0;

    final nextStreet = Street.values[street.index + 1];
    if (nextStreet == Street.showdown) return _showdown();

    final count = nextStreet == Street.flop ? 3 : 1;
    for (final b in boards) {
      b.addAll(_draw(count));
    }
    street = nextStreet;
    events.add(StreetEvent(nextStreet));

    toAct = _findNextToAct(button);
    if (toAct == null) _endStreet(); // tout le monde à tapis : on déroule les boards
  }

  void _refundUncalled() {
    final refund = uncalledBet([for (final p in players) Contribution(p.id, p.totalBet, p.folded)]);
    if (refund == null) return;
    final p = player(refund.id);
    p.totalBet -= refund.amount;
    p.stack += refund.amount;
  }

  void _credit(String id, int amount) {
    player(id).stack += amount;
    winnings[id] = (winnings[id] ?? 0) + amount;
  }

  void _finishUncontested() {
    _refundUncalled();
    final winner = players.firstWhere((p) => !p.folded);
    final amount = pot;
    _credit(winner.id, amount);
    events.add(UncontestedWinEvent(winner.id, amount));
    _complete();
  }

  List<String> _seatOrderFromButton() =>
      [for (var k = 0; k < players.length; k++) players[(button + 1 + k) % players.length].id];

  void _showdown() {
    street = Street.showdown;
    toAct = null;
    _refundUncalled();

    final live = players.where((p) => !p.folded);
    showdownHands = {for (final p in live) p.id: [for (final b in boards) bestOmahaHand(p.hole, b)]};

    final pots = buildPots([for (final p in players) Contribution(p.id, p.totalBet, p.folded)]);
    final order = _seatOrderFromButton();
    for (var pi = 0; pi < pots.length; pi++) {
      final pot = pots[pi];
      final thirds = splitInThirds(pot.amount);
      for (var board = 0; board < boardCount; board++) {
        final amount = thirds[board];
        if (amount == 0) continue;
        final best = pot.eligible.map((id) => showdownHands[id]![board].score).reduce(max);
        final winners =
            order.where((id) => pot.eligible.contains(id) && showdownHands[id]![board].score == best).toList();
        splitAmong(amount, winners).forEach(_credit);
        events.add(BoardWinEvent(board, pi, winners, amount));
      }
    }
    _complete();
  }

  void _complete() {
    street = Street.complete;
    toAct = null;
  }
}
