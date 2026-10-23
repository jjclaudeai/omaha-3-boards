import 'cards.dart';
import 'evaluator.dart';

class BestHand {
  const BestHand(this.score, this.hole, this.board);
  final int score;

  /// Les 2 cartes de la main et les 3 cartes du board retenues.
  final List<CardId> hole;
  final List<CardId> board;

  String get name => categoryNames[categoryOf(score)];
}

final _five = List<int>.filled(5, 0);

/// Meilleure main Omaha : exactement 2 cartes privées et 3 cartes du board (150 combinaisons).
BestHand bestOmahaHand(List<CardId> hole, List<CardId> board) {
  var bestScore = -1;
  var bh = <CardId>[], bb = <CardId>[];
  for (var a = 0; a < hole.length - 1; a++) {
    for (var b = a + 1; b < hole.length; b++) {
      for (var c = 0; c < 3; c++) {
        for (var d = c + 1; d < 4; d++) {
          for (var e = d + 1; e < 5; e++) {
            _five[0] = hole[a];
            _five[1] = hole[b];
            _five[2] = board[c];
            _five[3] = board[d];
            _five[4] = board[e];
            final s = evaluate5(_five);
            if (s > bestScore) {
              bestScore = s;
              bh = [hole[a], hole[b]];
              bb = [board[c], board[d], board[e]];
            }
          }
        }
      }
    }
  }
  return BestHand(bestScore, bh, bb);
}

/// Même calcul sans allocation : seulement le score (utilisé par les bots).
int bestOmahaScore(List<CardId> hole, List<CardId> board) {
  var best = -1;
  for (var a = 0; a < hole.length - 1; a++) {
    _five[0] = hole[a];
    for (var b = a + 1; b < hole.length; b++) {
      _five[1] = hole[b];
      for (var c = 0; c < 3; c++) {
        _five[2] = board[c];
        for (var d = c + 1; d < 4; d++) {
          _five[3] = board[d];
          for (var e = d + 1; e < 5; e++) {
            _five[4] = board[e];
            final s = evaluate5(_five);
            if (s > best) best = s;
          }
        }
      }
    }
  }
  return best;
}
