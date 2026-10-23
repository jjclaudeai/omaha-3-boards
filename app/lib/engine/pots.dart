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

/// Trois tiers, un par board. Les jetons en trop vont au board 1, puis 2.
List<int> splitInThirds(int amount) {
  final third = amount ~/ 3;
  final rest = amount - third * 3;
  return [third + (rest > 0 ? 1 : 0), third + (rest > 1 ? 1 : 0), third];
}
