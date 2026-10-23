import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'catalog.dart';
import 'rankings.dart';

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
        'pots' => 'Remporter $goal pots',
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

/// Récompense de fin de semaine de ligue, en attente d'être récupérée.
class WeeklyReward {
  const WeeklyReward({required this.rank, required this.league, required this.coins});
  final int rank;
  final String league;
  final int coins;
}

/// Tout ce qui appartient au joueur : identité, pièces, niveau, ligue, bonus, missions, cosmétiques, réglages.
/// Sauvegardé sur l'appareil ; le serveur en sera la référence quand les comptes existeront.
class PlayerProfile extends ChangeNotifier {
  PlayerProfile._();

  static const _key = 'profil_v1';

  // Identité (page Mon compte)
  String name = 'Joueur';
  String avatarId = 'as';

  /// Photo de profil choisie dans la galerie ou prise avec l'appareil, en JPEG réduit.
  Uint8List? photo;
  String frame = 'aucun';
  String bio = '';
  String country = 'FR';
  String city = '';
  DateTime? birthDate;
  String email = '';
  DateTime createdAt = DateTime.now();

  // Économie et progression
  int coins = startingCoins;
  int xp = 0;
  int leaguePoints = 0;
  int weeklyPoints = 0;
  String weekId = '';
  String lastBonusDay = '';
  int streak = 0;
  String missionsDay = '';
  List<Mission> missions = [];
  DateTime? lastChestAt;
  DateTime? lastRescueAt;
  DateTime? vipUntil;
  WeeklyReward? pendingWeeklyReward;

  /// Niveaux atteints dont la récompense n'a pas encore été montrée.
  final List<int> pendingLevelUps = [];

  // Cosmétiques (clés « famille:id »)
  Set<String> owned = {...starterItems};
  String cardBack = 'bordeaux';
  String theme = 'vert';
  bool welcomeBought = false;

  // Statistiques
  int handsPlayed = 0;
  int boardsWon = 0;
  int potsWon = 0;
  int scoops = 0;
  int biggestWin = 0;
  int bestLeagueIndex = 0;

  // Réglages
  bool haptics = true;
  bool fastReveal = false;
  bool notifications = true;

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
    p.createdAt = p.now();
    p._refreshPeriods();
    return p;
  }

  // ---------- Niveau ----------

  /// XP nécessaire pour passer du niveau [level] au suivant.
  static int xpForLevel(int level) => 150 + 75 * (level - 1);

  int get level => _levelOf(xp);

  static int _levelOf(int xp) {
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

  /// Ajoute de l'XP (+25 % en VIP) et crédite la récompense de chaque niveau franchi.
  void _gainXp(int amount) {
    final before = level;
    xp += isVip ? (amount * 1.25).round() : amount;
    for (var l = before + 1; l <= level; l++) {
      coins += levelUpReward(l);
      pendingLevelUps.add(l);
    }
  }

  int? takeLevelUp() {
    if (pendingLevelUps.isEmpty) return null;
    final l = pendingLevelUps.removeAt(0);
    notifyListeners();
    return l;
  }

  // ---------- VIP ----------

  bool get isVip => vipUntil != null && vipUntil!.isAfter(now());

  int get vipDaysLeft => isVip ? vipUntil!.difference(now()).inHours ~/ 24 + 1 : 0;

  void purchaseVip() {
    final start = isVip ? vipUntil! : now();
    vipUntil = start.add(const Duration(days: vipDays));
    coins += vipPass.coins;
    for (final c in allCosmetics.where((c) => c.vipOnly)) {
      owned.add(itemKey(c));
    }
    _save();
  }

  // ---------- Ligue ----------

  int get leagueIndex => _leagueIndexFor(leaguePoints);

  static int _leagueIndexFor(int points) {
    var i = 0;
    for (var k = 0; k < leagues.length; k++) {
      if (points >= leagues[k].threshold) i = k;
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

  RankEntry _meEntry(int points) => RankEntry(
        rank: 0,
        name: name,
        points: points,
        avatarId: avatarId,
        frame: frame,
        level: level,
        country: country,
        me: true,
      );

  /// Classement de la semaine dans la ligue du joueur.
  List<RankEntry> weeklyRanking() => SimulatedPlayers.weekly(
        weekId: weekId,
        leagueIndex: leagueIndex,
        weekday: now().weekday,
        me: _meEntry(weeklyPoints),
      );

  int get weeklyRank => weeklyRanking().firstWhere((e) => e.me).rank;

  /// Classement général sur les points de ligue de toujours.
  List<RankEntry> globalRanking() => SimulatedPlayers.global(me: _meEntry(leaguePoints));

  /// Classement des fortunes en pièces.
  List<RankEntry> fortuneRanking() => SimulatedPlayers.fortune(me: _meEntry(coins));

  Duration get timeLeftInWeek {
    final n = now();
    final nextMonday = DateTime(n.year, n.month, n.day).add(Duration(days: 8 - n.weekday));
    return nextMonday.difference(n);
  }

  int claimWeeklyReward() {
    final r = pendingWeeklyReward;
    if (r == null) return 0;
    pendingWeeklyReward = null;
    coins += r.coins;
    _save();
    return r.coins;
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

  /// Récompense du jour [day] de la série : doublée en VIP.
  int dailyRewardFor(int day) => dailyRewards[day - 1] * (isVip ? 2 : 1);

  int claimDailyBonus() {
    if (!bonusAvailable) return 0;
    final day = bonusDay;
    final reward = dailyRewardFor(day);
    streak = day;
    lastBonusDay = _day(now());
    coins += reward;
    _save();
    return reward;
  }

  // ---------- Coffre gratuit et coup de pouce ----------

  Duration get chestInterval => Duration(hours: isVip ? freeChestHours ~/ 2 : freeChestHours);

  /// Temps restant avant le prochain coffre gratuit (zéro = disponible).
  Duration get chestWait {
    if (lastChestAt == null) return Duration.zero;
    final left = lastChestAt!.add(chestInterval).difference(now());
    return left.isNegative ? Duration.zero : left;
  }

  int openChest([Random? rng]) {
    if (chestWait > Duration.zero) return 0;
    final r = rng ?? Random();
    // Arrondi à 50 pièces : des montants ronds se lisent mieux.
    final reward = (freeChestMin + r.nextInt(freeChestMax - freeChestMin + 1)) ~/ 50 * 50;
    lastChestAt = now();
    coins += reward;
    _save();
    return reward;
  }

  /// Le joueur ne peut plus payer la moindre cave : on lui offre de quoi revenir à la table.
  bool get rescueAvailable =>
      coins < rooms.first.buyIn &&
      (lastRescueAt == null || now().difference(lastRescueAt!) >= const Duration(hours: rescueCooldownHours));

  int claimRescue() {
    if (!rescueAvailable) return 0;
    lastRescueAt = now();
    coins += rescueCoins;
    _save();
    return rescueCoins;
  }

  // ---------- Missions ----------

  int claimMission(Mission m) {
    if (!m.done || m.claimed) return 0;
    m.claimed = true;
    coins += m.reward;
    _gainXp(50);
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
      owned.addAll({'cardBack:royal', 'frame:or'});
    }
    _save();
  }

  bool owns(Cosmetic c) => owned.contains(itemKey(c));

  /// Pourquoi l'objet n'est pas encore achetable, ou null s'il l'est.
  String? lockReason(Cosmetic c) {
    if (owns(c)) return null;
    if (c.vipOnly) return 'Réservé VIP';
    if (level < c.minLevel) return 'Niveau ${c.minLevel}';
    return null;
  }

  bool buyCosmetic(Cosmetic c) {
    if (owns(c)) return true;
    if (lockReason(c) != null || !spend(c.price)) return false;
    owned.add(itemKey(c));
    _save();
    return true;
  }

  bool isEquipped(Cosmetic c) => switch (c.kind) {
        CosmeticKind.theme => theme == c.id,
        CosmeticKind.cardBack => cardBack == c.id,
        CosmeticKind.avatar => photo == null && avatarId == c.id,
        CosmeticKind.frame => frame == c.id,
      };

  void equip(Cosmetic c) {
    if (!owns(c)) return;
    switch (c.kind) {
      case CosmeticKind.theme:
        theme = c.id;
      case CosmeticKind.cardBack:
        cardBack = c.id;
      case CosmeticKind.avatar:
        avatarId = c.id;
        photo = null;
      case CosmeticKind.frame:
        frame = c.id;
    }
    _save();
  }

  Cosmetic get themeItem => themes.firstWhere((t) => t.id == theme, orElse: () => themes.first);
  Cosmetic get cardBackItem => cardBacks.firstWhere((t) => t.id == cardBack, orElse: () => cardBacks.first);

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
    if (o.potWon) potsWon++;
    if (o.scooped) scoops++;
    if (o.net > biggestWin) biggestWin = o.net;
    _gainXp(5 + o.boardsWon * 10);
    final pts = leaguePointsFor(o, room);
    leaguePoints += pts;
    weeklyPoints += pts;
    bestLeagueIndex = max(bestLeagueIndex, leagueIndex);
    for (final m in missions) {
      if (m.claimed) continue;
      switch (m.kind) {
        case 'hands':
          m.progress++;
        case 'boards':
          m.progress += o.boardsWon;
        case 'pots':
          if (o.potWon) m.progress++;
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
      // Fin de semaine : la place obtenue dans la ligue rapporte des pièces, à récupérer à l'accueil.
      if (weekId.isNotEmpty && weeklyPoints > 0) {
        final finalRanking = SimulatedPlayers.weekly(weekId: weekId, leagueIndex: leagueIndex, weekday: 7, me: _meEntry(weeklyPoints));
        final rank = finalRanking.firstWhere((e) => e.me).rank;
        final reward = league.rewardForRank(rank);
        if (reward > 0) pendingWeeklyReward = WeeklyReward(rank: rank, league: league.name, coins: reward);
      }
      weekId = _week(n);
      weeklyPoints = 0;
    }
    if (missionsDay != _day(n)) {
      missionsDay = _day(n);
      final rng = Random(missionsDay.hashCode);
      missions = [
        Mission(kind: 'hands', goal: 10 + 5 * rng.nextInt(3), reward: 2000),
        rng.nextBool()
            ? Mission(kind: 'boards', goal: 4 + rng.nextInt(4), reward: 3000)
            : Mission(kind: 'pots', goal: 3 + rng.nextInt(3), reward: 3000),
        rng.nextBool() ? Mission(kind: 'flush', goal: 1, reward: 4000) : Mission(kind: 'scoop', goal: 1, reward: 5000),
      ];
    }
    // Une série cassée repart au jour 1.
    if (lastBonusDay.isNotEmpty &&
        lastBonusDay != _day(n) &&
        lastBonusDay != _day(n.subtract(const Duration(days: 1)))) {
      streak = 0;
    }
  }

  // ---------- Compte ----------

  static const nameMin = 3;
  static const nameMax = 16;

  /// Pourquoi ce pseudo est refusé, ou null s'il convient.
  static String? validateName(String value) {
    final v = value.trim();
    if (v.length < nameMin) return 'Au moins $nameMin caractères';
    if (v.length > nameMax) return 'Au plus $nameMax caractères';
    if (!RegExp(r"^[\p{L}\p{N} _.'-]+$", unicode: true).hasMatch(v)) return 'Lettres, chiffres, espace, - _ . et \' seulement';
    return null;
  }

  static String? validateEmail(String value) {
    final v = value.trim();
    if (v.isEmpty) return null;
    return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v) ? null : 'Adresse e-mail invalide';
  }

  void updateAccount({
    String? name,
    String? bio,
    String? country,
    String? city,
    DateTime? birthDate,
    bool clearBirthDate = false,
    String? email,
  }) {
    if (name != null && validateName(name) == null) this.name = name.trim();
    if (bio != null) this.bio = bio.trim().length > 80 ? bio.trim().substring(0, 80) : bio.trim();
    if (country != null) this.country = country;
    if (city != null) this.city = city.trim();
    if (birthDate != null) this.birthDate = birthDate;
    if (clearBirthDate) this.birthDate = null;
    if (email != null && validateEmail(email) == null) this.email = email.trim();
    _save();
  }

  void setPhoto(Uint8List? bytes) {
    photo = bytes;
    _save();
  }

  void updateSettings({bool? haptics, bool? fastReveal, bool? notifications}) {
    if (haptics != null) this.haptics = haptics;
    if (fastReveal != null) this.fastReveal = fastReveal;
    if (notifications != null) this.notifications = notifications;
    _save();
  }

  /// Efface toutes les données du joueur sur l'appareil (exigé par l'App Store).
  Future<void> deleteAccount() async {
    final fresh = PlayerProfile._();
    _fromJson(fresh._toJson());
    photo = null;
    birthDate = null;
    vipUntil = null;
    lastChestAt = null;
    lastRescueAt = null;
    pendingWeeklyReward = null;
    pendingLevelUps.clear();
    createdAt = now();
    weekId = '';
    missionsDay = '';
    _refreshPeriods();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_key);
    } catch (_) {}
    _save();
  }

  // ---------- Sauvegarde ----------

  static String? _date(DateTime? d) => d?.toIso8601String();
  static DateTime? _parse(Object? s) => s is String ? DateTime.tryParse(s) : null;

  Map<String, dynamic> _toJson() => {
        'name': name,
        'avatar': avatarId,
        'photo': photo == null ? null : base64Encode(photo!),
        'frame': frame,
        'bio': bio,
        'country': country,
        'city': city,
        'birth': _date(birthDate),
        'email': email,
        'created': _date(createdAt),
        'coins': coins,
        'xp': xp,
        'lp': leaguePoints,
        'wp': weeklyPoints,
        'week': weekId,
        'bonus': lastBonusDay,
        'streak': streak,
        'mday': missionsDay,
        'missions': [for (final m in missions) m.toJson()],
        'chest': _date(lastChestAt),
        'rescue': _date(lastRescueAt),
        'vip': _date(vipUntil),
        'wreward': pendingWeeklyReward == null
            ? null
            : {'rank': pendingWeeklyReward!.rank, 'league': pendingWeeklyReward!.league, 'coins': pendingWeeklyReward!.coins},
        'owned2': owned.toList(),
        'back': cardBack,
        'theme': theme,
        'welcome': welcomeBought,
        'hands': handsPlayed,
        'boards': boardsWon,
        'pots': potsWon,
        'scoops': scoops,
        'best': biggestWin,
        'bestLeague': bestLeagueIndex,
        'haptics': haptics,
        'fast': fastReveal,
        'notif': notifications,
      };

  void _fromJson(Map<String, dynamic> j) {
    name = j['name'] ?? name;
    avatarId = j['avatar'] ?? 'as';
    photo = j['photo'] is String ? base64Decode(j['photo']) : null;
    frame = j['frame'] ?? 'aucun';
    bio = j['bio'] ?? '';
    country = j['country'] ?? 'FR';
    city = j['city'] ?? '';
    birthDate = _parse(j['birth']);
    email = j['email'] ?? '';
    createdAt = _parse(j['created']) ?? DateTime.now();
    coins = j['coins'] ?? coins;
    xp = j['xp'] ?? 0;
    leaguePoints = j['lp'] ?? 0;
    weeklyPoints = j['wp'] ?? 0;
    weekId = j['week'] ?? '';
    lastBonusDay = j['bonus'] ?? '';
    streak = j['streak'] ?? 0;
    missionsDay = j['mday'] ?? '';
    missions = [for (final m in (j['missions'] as List? ?? [])) Mission.fromJson(Map<String, dynamic>.from(m))];
    lastChestAt = _parse(j['chest']);
    lastRescueAt = _parse(j['rescue']);
    vipUntil = _parse(j['vip']);
    final w = j['wreward'];
    pendingWeeklyReward = w is Map ? WeeklyReward(rank: w['rank'], league: w['league'], coins: w['coins']) : null;
    owned = {...starterItems, ...(j['owned2'] as List? ?? []).cast<String>()};
    // Sauvegardes d'avant les familles de cosmétiques : les ids seuls désignaient dos et tapis.
    for (final id in (j['owned'] as List? ?? []).cast<String>()) {
      if (cardBacks.any((c) => c.id == id)) owned.add('cardBack:$id');
      if (themes.any((c) => c.id == id)) owned.add('theme:$id');
    }
    cardBack = j['back'] ?? 'bordeaux';
    theme = j['theme'] ?? j['felt'] ?? 'vert';
    welcomeBought = j['welcome'] ?? false;
    handsPlayed = j['hands'] ?? 0;
    boardsWon = j['boards'] ?? 0;
    potsWon = j['pots'] ?? 0;
    scoops = j['scoops'] ?? 0;
    biggestWin = j['best'] ?? 0;
    bestLeagueIndex = j['bestLeague'] ?? 0;
    haptics = j['haptics'] ?? true;
    fastReveal = j['fast'] ?? false;
    notifications = j['notif'] ?? true;
  }

  void _save() {
    notifyListeners();
    final data = jsonEncode(_toJson());
    SharedPreferences.getInstance().then((p) => p.setString(_key, data)).catchError((_) => false);
  }
}
