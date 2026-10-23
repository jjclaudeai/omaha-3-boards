import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'catalog.dart';

/// Une mission du jour : un objectif, une progression et une récompense.
class Mission {
  Mission({required this.kind, required this.goal, required this.reward, this.progress = 0, this.claimed = false});
  final String kind;
  final int goal;
  final int reward;
  int progress;
  bool claimed;

  bool get done => progress >= goal;

  String get label => switch (kind) {
        'hands' => 'Jouer $goal mains',
        'boards' => 'Gagner $goal boards',
        'flush' => 'Gagner un board avec une couleur ou mieux',
        'scoop' => 'Rafler les 3 boards d\'un même pot',
        _ => kind,
      };

  Map<String, dynamic> toJson() => {'k': kind, 'g': goal, 'r': reward, 'p': progress, 'c': claimed};
  static Mission fromJson(Map<String, dynamic> j) =>
      Mission(kind: j['k'], goal: j['g'], reward: j['r'], progress: j['p'], claimed: j['c']);
}

/// Résultat d'une main pour le joueur, transmis par la table.
class HandOutcome {
  const HandOutcome({
    required this.boardsWon,
    required this.bestWinningCategory,
    required this.scooped,
    required this.net,
    this.potWon = false,
  });
  final int boardsWon;

  /// Le joueur a remporté le pot (seul ou à égalité de points).
  final bool potWon;

  /// Meilleure catégorie (0 = hauteur … 8 = quinte flush) parmi les boards gagnés, -1 si aucun.
  final int bestWinningCategory;
  final bool scooped;

  /// Gain ou perte de jetons sur la main.
  final int net;
}

/// Tout ce qui appartient au joueur : pièces, niveau, ligue, bonus, missions, cosmétiques.
/// Sauvegardé sur l'appareil ; le serveur en sera la référence quand les comptes existeront.
class PlayerProfile extends ChangeNotifier {
  PlayerProfile._();

  static const _key = 'profil_v1';
  static const startingCoins = 5000;

  String name = 'Joueur';
  int coins = startingCoins;
  int xp = 0;
  int leaguePoints = 0;
  int weeklyPoints = 0;
  String weekId = '';
  String lastBonusDay = '';
  int streak = 0;
  String missionsDay = '';
  List<Mission> missions = [];
  Set<String> owned = {'bordeaux', 'vert'};
  String cardBack = 'bordeaux';
  String felt = 'vert';
  bool welcomeBought = false;
  int handsPlayed = 0;
  int boardsWon = 0;
  int biggestWin = 0;

  /// Chiffres du jour et de la semaine : remplaçables dans les tests.
  DateTime Function() now = DateTime.now;

  static Future<PlayerProfile> load() async {
    final p = PlayerProfile._();
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw != null) p._fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      // Stockage indisponible (navigation privée…) : on joue avec un profil neuf.
    }
    p._refreshPeriods();
    return p;
  }

  /// Profil en mémoire seulement, pour les tests.
  @visibleForTesting
  static PlayerProfile fresh({DateTime Function()? clock}) {
    final p = PlayerProfile._();
    if (clock != null) p.now = clock;
    p._refreshPeriods();
    return p;
  }

  // ---------- Niveau ----------

  /// XP nécessaire pour passer du niveau [level] au suivant.
  static int xpForLevel(int level) => 150 + 75 * (level - 1);

  int get level {
    var l = 1, rest = xp;
    while (rest >= xpForLevel(l)) {
      rest -= xpForLevel(l);
      l++;
    }
    return l;
  }

  /// Progression vers le niveau suivant, entre 0 et 1.
  double get levelProgress {
    var l = 1, rest = xp;
    while (rest >= xpForLevel(l)) {
      rest -= xpForLevel(l);
      l++;
    }
    return rest / xpForLevel(l);
  }

  // ---------- Ligue ----------

  int get leagueIndex {
    var i = 0;
    for (var k = 0; k < leagues.length; k++) {
      if (leaguePoints >= leagues[k].threshold) i = k;
    }
    return i;
  }

  League get league => leagues[leagueIndex];
  League? get nextLeague => leagueIndex + 1 < leagues.length ? leagues[leagueIndex + 1] : null;

  double get leagueProgress {
    final next = nextLeague;
    if (next == null) return 1;
    return (leaguePoints - league.threshold) / (next.threshold - league.threshold);
  }

  /// Classement de la semaine dans la ligue : 29 adversaires simulés et le joueur.
  /// Les scores des adversaires sont tirés d'une graine liée à la semaine : stables d'une ouverture à l'autre.
  List<({String name, int points, bool me})> weeklyRanking() {
    final rng = Random(weekId.hashCode ^ leagueIndex);
    const names = [
      'Lucie', 'Marco', 'Inès', 'Hugo', 'Nadia', 'Théo', 'Chloé', 'Samir', 'Jade', 'Louis', 'Emma', 'Yanis',
      'Léa', 'Karim', 'Zoé', 'Noah', 'Manon', 'Rayan', 'Camille', 'Enzo', 'Sarah', 'Adam', 'Lina', 'Gabriel',
      'Alice', 'Mehdi', 'Clara', 'Lucas', 'Anaïs',
    ];
    // Les adversaires « jouent » au fil de la semaine : leur score grandit avec le jour.
    final dayOfWeek = now().weekday;
    final scale = 40 + 25 * leagueIndex;
    final list = [
      for (final n in names) (name: n, points: (rng.nextInt(scale * 3) * dayOfWeek / 7).round(), me: false),
      (name: name, points: weeklyPoints, me: true),
    ]..sort((a, b) => b.points - a.points);
    return list;
  }

  int get weeklyRank => weeklyRanking().indexWhere((e) => e.me) + 1;

  Duration get timeLeftInWeek {
    final n = now();
    final nextMonday = DateTime(n.year, n.month, n.day).add(Duration(days: 8 - n.weekday));
    return nextMonday.difference(n);
  }

  // ---------- Bonus quotidien ----------

  bool get bonusAvailable => lastBonusDay != _day(now());

  /// Jour de la série (1 à 7) dont la récompense est proposée aujourd'hui.
  int get bonusDay {
    final yesterday = _day(now().subtract(const Duration(days: 1)));
    final continues = lastBonusDay == yesterday || lastBonusDay == _day(now());
    final base = continues ? streak : 0;
    return bonusAvailable ? base % 7 + 1 : ((streak - 1) % 7) + 1;
  }

  int claimDailyBonus() {
    if (!bonusAvailable) return 0;
    final day = bonusDay;
    final reward = dailyRewards[day - 1];
    streak = day;
    lastBonusDay = _day(now());
    coins += reward;
    _save();
    return reward;
  }

  // ---------- Missions ----------

  int claimMission(Mission m) {
    if (!m.done || m.claimed) return 0;
    m.claimed = true;
    coins += m.reward;
    xp += 50;
    _save();
    return m.reward;
  }

  // ---------- Pièces et boutique ----------

  bool spend(int amount) {
    if (coins < amount) return false;
    coins -= amount;
    _save();
    return true;
  }

  void earn(int amount) {
    coins += amount;
    _save();
  }

  /// Achat intégré simulé : dans l'app publiée, l'App Store ou Google Play encaisse, le serveur crédite.
  void purchasePack(CoinPack pack) {
    coins += pack.coins;
    if (pack.id == welcomeOffer.id) {
      welcomeBought = true;
      owned.add('royal');
    }
    _save();
  }

  bool buyCosmetic(Cosmetic c) {
    if (owned.contains(c.id)) return true;
    if (!spend(c.price)) return false;
    owned.add(c.id);
    _save();
    return true;
  }

  void equip(Cosmetic c) {
    if (!owned.contains(c.id)) return;
    if (cardBacks.contains(c)) cardBack = c.id;
    if (felts.contains(c)) felt = c.id;
    _save();
  }

  // ---------- Fin de main ----------

  /// Points de ligue d'une main : 10 par board gagné, 20 pour le pot, 15 de plus pour une rafle,
  /// le tout × multiplicateur de la salle.
  static int leaguePointsFor(HandOutcome o, Room room) =>
      (o.boardsWon * 10 + (o.potWon ? 20 : 0) + (o.scooped ? 15 : 0)) * room.leagueMultiplier;

  /// Enregistre une main jouée ; renvoie les points de ligue gagnés.
  int recordHand(HandOutcome o, Room room) {
    _refreshPeriods();
    handsPlayed++;
    boardsWon += o.boardsWon;
    if (o.net > biggestWin) biggestWin = o.net;
    xp += 5 + o.boardsWon * 10;
    final pts = leaguePointsFor(o, room);
    leaguePoints += pts;
    weeklyPoints += pts;
    for (final m in missions) {
      if (m.claimed) continue;
      switch (m.kind) {
        case 'hands':
          m.progress++;
        case 'boards':
          m.progress += o.boardsWon;
        case 'flush':
          if (o.bestWinningCategory >= 5) m.progress = m.goal;
        case 'scoop':
          if (o.scooped) m.progress = m.goal;
      }
      if (m.progress > m.goal) m.progress = m.goal;
    }
    _save();
    return pts;
  }

  // ---------- Périodes ----------

  static String _day(DateTime d) => '${d.year}-${d.month}-${d.day}';

  static String _week(DateTime d) {
    final monday = DateTime(d.year, d.month, d.day).subtract(Duration(days: d.weekday - 1));
    return 'S${_day(monday)}';
  }

  void _refreshPeriods() {
    final n = now();
    if (weekId != _week(n)) {
      weekId = _week(n);
      weeklyPoints = 0;
    }
    if (missionsDay != _day(n)) {
      missionsDay = _day(n);
      final rng = Random(missionsDay.hashCode);
      missions = [
        Mission(kind: 'hands', goal: 10 + 5 * rng.nextInt(3), reward: 1000),
        Mission(kind: 'boards', goal: 4 + rng.nextInt(4), reward: 1500),
        rng.nextBool() ? Mission(kind: 'flush', goal: 1, reward: 2000) : Mission(kind: 'scoop', goal: 1, reward: 2500),
      ];
    }
    // Une série cassée repart au jour 1.
    if (lastBonusDay.isNotEmpty &&
        lastBonusDay != _day(n) &&
        lastBonusDay != _day(n.subtract(const Duration(days: 1)))) {
      streak = 0;
    }
  }

  void rename(String value) {
    final v = value.trim();
    if (v.isEmpty) return;
    name = v.length > 14 ? v.substring(0, 14) : v;
    _save();
  }

  // ---------- Sauvegarde ----------

  Map<String, dynamic> _toJson() => {
        'name': name,
        'coins': coins,
        'xp': xp,
        'lp': leaguePoints,
        'wp': weeklyPoints,
        'week': weekId,
        'bonus': lastBonusDay,
        'streak': streak,
        'mday': missionsDay,
        'missions': [for (final m in missions) m.toJson()],
        'owned': owned.toList(),
        'back': cardBack,
        'felt': felt,
        'welcome': welcomeBought,
        'hands': handsPlayed,
        'boards': boardsWon,
        'best': biggestWin,
      };

  void _fromJson(Map<String, dynamic> j) {
    name = j['name'] ?? name;
    coins = j['coins'] ?? coins;
    xp = j['xp'] ?? 0;
    leaguePoints = j['lp'] ?? 0;
    weeklyPoints = j['wp'] ?? 0;
    weekId = j['week'] ?? '';
    lastBonusDay = j['bonus'] ?? '';
    streak = j['streak'] ?? 0;
    missionsDay = j['mday'] ?? '';
    missions = [for (final m in (j['missions'] as List? ?? [])) Mission.fromJson(Map<String, dynamic>.from(m))];
    owned = {...(j['owned'] as List? ?? []).cast<String>(), 'bordeaux', 'vert'};
    cardBack = j['back'] ?? 'bordeaux';
    felt = j['felt'] ?? 'vert';
    welcomeBought = j['welcome'] ?? false;
    handsPlayed = j['hands'] ?? 0;
    boardsWon = j['boards'] ?? 0;
    biggestWin = j['best'] ?? 0;
  }

  void _save() {
    notifyListeners();
    final data = jsonEncode(_toJson());
    SharedPreferences.getInstance().then((p) => p.setString(_key, data)).catchError((_) => false);
  }
}
