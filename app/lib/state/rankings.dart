import 'dart:math';

import 'catalog.dart';

/// Une ligne de classement.
class RankEntry {
  const RankEntry({
    required this.rank,
    required this.name,
    required this.points,
    required this.avatarId,
    required this.frame,
    required this.level,
    required this.country,
    this.me = false,
  });
  final int rank;
  final String name;
  final int points;
  final String avatarId;
  final String frame;
  final int level;
  final String country;
  final bool me;
}

/// Les autres joueurs du classement, simulés tant que le serveur n'existe pas.
/// Tout est tiré d'une graine : un même joueur garde son nom, son avatar et son pays d'une ouverture à l'autre.
class SimulatedPlayers {
  static const _first = [
    'Lucie', 'Marco', 'Inès', 'Hugo', 'Nadia', 'Théo', 'Chloé', 'Samir', 'Jade', 'Louis', 'Emma', 'Yanis',
    'Léa', 'Karim', 'Zoé', 'Noah', 'Manon', 'Rayan', 'Camille', 'Enzo', 'Sarah', 'Adam', 'Lina', 'Gabriel',
    'Alice', 'Mehdi', 'Clara', 'Lucas', 'Anaïs', 'Jules', 'Yasmine', 'Hamza', 'Romane', 'Malo', 'Sofia', 'Nathan',
  ];
  static const _suffix = ['', '', '', '75', '_13', 'Pro', '92', 'Ace', '06', 'River', '_69', 'Flush', '33', 'Bluff'];
  static const countries = ['FR', 'FR', 'FR', 'FR', 'BE', 'CH', 'CA', 'MA', 'SN', 'CI', 'LU', 'TN', 'DZ'];

  static RankEntry _player(Random rng, int rank, int points, {int levelBase = 1}) {
    final name = _first[rng.nextInt(_first.length)] + _suffix[rng.nextInt(_suffix.length)];
    final frame = frames[rng.nextInt(frames.length - 1)].id; // le cadre VIP n'est pas tiré
    return RankEntry(
      rank: rank,
      name: name,
      points: points,
      avatarId: avatars[rng.nextInt(avatars.length)].id,
      frame: rng.nextInt(3) == 0 ? frame : 'aucun',
      level: levelBase + rng.nextInt(6),
      country: countries[rng.nextInt(countries.length)],
    );
  }

  /// Classement de la semaine dans une ligue : 29 adversaires et le joueur.
  /// Les adversaires « jouent » au fil de la semaine : leur score grandit avec le jour.
  static List<RankEntry> weekly({
    required String weekId,
    required int leagueIndex,
    required int weekday,
    required RankEntry me,
  }) {
    final rng = Random(weekId.hashCode ^ (leagueIndex * 7919));
    final scale = 60 + 40 * leagueIndex;
    final others = [
      for (var i = 0; i < 29; i++)
        _player(rng, 0, (rng.nextInt(scale * 3) * weekday / 7).round(), levelBase: 1 + leagueIndex * 3),
    ];
    return _ranked([...others, me]);
  }

  /// Nombre de joueurs inscrits affiché au classement général.
  static const population = 12480;

  /// Classement général : les points de ligue de toujours suivent une loi de puissance,
  /// le 1er a 60 000 points, le 100e environ 4 800, le 10 000e environ 380.
  static int _pointsAt(int rank) => (60000 * pow(rank, -0.55)).round();

  static int _rankFor(int points) =>
      points <= 0 ? population : min(population, max(1, pow(60000 / points, 1 / 0.55).ceil()));

  static List<RankEntry> global({required RankEntry me, int top = 100}) =>
      _powerLaw(seed: 4242, top: top, me: me, pointsAt: _pointsAt, rankFor: _rankFor);

  /// Classement des fortunes : le 1er a 40 millions de pièces.
  static int _coinsAt(int rank) => (40000000 * pow(rank, -0.9)).round();

  static int _rankForCoins(int coins) =>
      coins <= 0 ? population : min(population, max(1, pow(40000000 / coins, 1 / 0.9).ceil()));

  static List<RankEntry> fortune({required RankEntry me, int top = 100}) =>
      _powerLaw(seed: 777, top: top, me: me, pointsAt: _coinsAt, rankFor: _rankForCoins);

  static List<RankEntry> _powerLaw({
    required int seed,
    required int top,
    required RankEntry me,
    required int Function(int) pointsAt,
    required int Function(int) rankFor,
  }) {
    final rng = Random(seed);
    final myRank = rankFor(me.points);
    final list = <RankEntry>[];
    var r = 1;
    while (list.length < top) {
      if (r == myRank) {
        list.add(_withRank(me, r));
      } else {
        // Les mieux classés ont un niveau plus élevé.
        list.add(_player(rng, r, pointsAt(r), levelBase: max(1, 30 - r ~/ 4)));
      }
      r++;
    }
    if (myRank > top) list.add(_withRank(me, myRank));
    return list;
  }

  static List<RankEntry> _ranked(List<RankEntry> entries) {
    entries.sort((a, b) => b.points != a.points ? b.points - a.points : (a.me ? -1 : b.me ? 1 : 0));
    return [for (var i = 0; i < entries.length; i++) _withRank(entries[i], i + 1)];
  }

  static RankEntry _withRank(RankEntry e, int rank) => RankEntry(
        rank: rank,
        name: e.name,
        points: e.points,
        avatarId: e.avatarId,
        frame: e.frame,
        level: e.level,
        country: e.country,
        me: e.me,
      );
}
