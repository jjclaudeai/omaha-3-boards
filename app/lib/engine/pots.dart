class Contribution {
  const Contribution(this.id, this.amount, this.folded);
  final String id;
  final int amount;
  final bool folded;
}

class Pot {
  Pot(this.amount, this.eligible);
  int amount;
  final List<String> eligible;
}

/// Part d'une mise que personne n'a suivie, à rendre à son auteur.
({String id, int amount})? uncalledBet(List<Contribution> contribs) {
  if (contribs.length < 2) return null;
  final sorted = [...contribs]..sort((a, b) => b.amount - a.amount);
  final excess = sorted[0].amount - sorted[1].amount;
  return excess > 0 ? (id: sorted[0].id, amount: excess) : null;
}

/// Pot principal et pots annexes.
List<Pot> buildPots(List<Contribution> contribs) {
  final levels = contribs.where((c) => !c.folded && c.amount > 0).map((c) => c.amount).toSet().toList()..sort();
  final pots = <Pot>[];
  var prev = 0;
  for (final level in levels) {
    var amount = 0;
    for (final c in contribs) {
      final part = (c.amount < level ? c.amount : level) - prev;
      if (part > 0) amount += part;
    }
    final eligible = contribs.where((c) => !c.folded && c.amount >= level).map((c) => c.id).toList();
    if (pots.isNotEmpty && pots.last.eligible.join(',') == eligible.join(',')) {
      pots.last.amount += amount;
    } else {
      pots.add(Pot(amount, eligible));
    }
    prev = level;
  }
  var leftover = 0;
  for (final c in contribs) {
    if (c.amount > prev) leftover += c.amount - prev;
  }
  if (leftover > 0 && pots.isNotEmpty) pots.last.amount += leftover;
  return pots;
}

/// Partage une somme ; les jetons indivisibles vont aux premiers gagnants dans l'ordre donné.
Map<String, int> splitAmong(int amount, List<String> winners) {
  final share = amount ~/ winners.length;
  var rest = amount - share * winners.length;
  final out = <String, int>{};
  for (final w in winners) {
    out[w] = share + (rest > 0 ? 1 : 0);
    if (rest > 0) rest--;
  }
  return out;
}

/// Un board vaut 1 point ; compté en soixantièmes pour partager exactement entre 2 à 6 gagnants.
const point = 60;

/// Points de chaque joueur sur un pot : chaque board donne 1 point, partagé à parts égales en cas d'égalité.
Map<String, int> boardPoints(List<List<String>> boardWinners) {
  final points = <String, int>{};
  for (final winners in boardWinners) {
    for (final id in winners) {
      points[id] = (points[id] ?? 0) + point ~/ winners.length;
    }
  }
  return points;
}

/// Joueurs qui remportent le pot : le plus de points. Plusieurs seulement en cas d'égalité parfaite.
List<String> potWinners(Map<String, int> points, List<String> order) {
  final best = points.values.reduce((a, b) => a > b ? a : b);
  return order.where((id) => points[id] == best).toList();
}
