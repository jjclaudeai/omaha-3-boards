import 'cards.dart';

const categoryNames = [
  'Hauteur',
  'Paire',
  'Double paire',
  'Brelan',
  'Quinte',
  'Couleur',
  'Full',
  'Carré',
  'Quinte flush',
];

const _cat = 1048576; // 16^5
final _counts = List<int>.filled(13, 0);

int _pad(int v, int digits) {
  var out = v;
  for (var i = digits; i < 5; i++) {
    out *= 16;
  }
  return out;
}

/// Score d'une main de 5 cartes : plus grand = meilleur. Catégorie × 16^5 + départages.
/// Même algorithme que le moteur TypeScript (engine/src/evaluator.ts).
int evaluate5(List<CardId> cards) {
  _counts.fillRange(0, 13, 0);
  var mask = 0;
  final suit0 = cards[0] & 3;
  var flush = true;
  for (var i = 0; i < 5; i++) {
    final c = cards[i];
    final r = c >> 2;
    _counts[r]++;
    mask |= 1 << r;
    if ((c & 3) != suit0) flush = false;
  }

  var straightHigh = -1;
  if (_popcount(mask) == 5) {
    final high = mask.bitLength - 1;
    if (mask >> (high - 4) == 31) {
      straightHigh = high;
    } else if (mask == 4111) {
      straightHigh = 3; // roue A-2-3-4-5
    }
  }
  if (straightHigh >= 0) return (flush ? 8 : 4) * _cat + straightHigh * 65536;

  var quad = -1, trip = -1, pairHi = -1, pairLo = -1, kick = 0;
  for (var r = 12; r >= 0; r--) {
    final n = _counts[r];
    if (n == 4) {
      quad = r;
    } else if (n == 3) {
      trip = r;
    } else if (n == 2) {
      if (pairHi < 0) {
        pairHi = r;
      } else {
        pairLo = r;
      }
    } else if (n == 1) {
      kick = kick * 16 + r;
    }
  }

  if (quad >= 0) return 7 * _cat + _pad(quad * 16 + kick, 2);
  if (trip >= 0 && pairHi >= 0) return 6 * _cat + _pad(trip * 16 + pairHi, 2);
  if (flush) return 5 * _cat + kick;
  if (trip >= 0) return 3 * _cat + _pad(trip * 256 + kick, 3);
  if (pairLo >= 0) return 2 * _cat + _pad((pairHi * 16 + pairLo) * 16 + kick, 3);
  if (pairHi >= 0) return 1 * _cat + _pad(pairHi * 4096 + kick, 4);
  return kick;
}

int _popcount(int x) {
  var n = 0;
  while (x != 0) {
    x &= x - 1;
    n++;
  }
  return n;
}

int categoryOf(int score) => score ~/ _cat;
