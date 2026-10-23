import 'package:flutter/material.dart';

// Tout ce qui se règle côté économie et contenu est ici : la plateforme d'administration
// pourra remplacer ces valeurs par une configuration distante sans toucher au reste de l'app.

/// Une salle de jeu : les blindes, la cave et le multiplicateur de points de ligue.
class Room {
  const Room({
    required this.id,
    required this.name,
    required this.smallBlind,
    required this.bigBlind,
    required this.minLevel,
    required this.leagueMultiplier,
    required this.color,
  });
  final String id;
  final String name;
  final int smallBlind;
  final int bigBlind;
  final int minLevel;
  final int leagueMultiplier;
  final Color color;

  /// Cave : 50 grosses blindes.
  int get buyIn => bigBlind * 50;

  /// Commission prélevée sur un pot gagné après le flop : 5 %, plafonnée à 2 grosses blindes.
  int rakeOn(int won) => (won * rakePercent ~/ 100).clamp(0, bigBlind * rakeCapBigBlinds);
}

const rakePercent = 5;
const rakeCapBigBlinds = 2;

/// Chaque salle multiplie la cave par 5 et se débloque avec le niveau : un joueur gratuit vit
/// confortablement en Débutant et en Salon, le Club se mérite, Prestige et au-delà se paient.
const rooms = [
  Room(id: 'debutant', name: 'Débutant', smallBlind: 10, bigBlind: 20, minLevel: 1, leagueMultiplier: 1, color: Color(0xFF3FD68E)),
  Room(id: 'salon', name: 'Salon', smallBlind: 50, bigBlind: 100, minLevel: 3, leagueMultiplier: 2, color: Color(0xFF55A8FF)),
  Room(id: 'club', name: 'Club privé', smallBlind: 200, bigBlind: 400, minLevel: 6, leagueMultiplier: 3, color: Color(0xFFB57CFF)),
  Room(id: 'prestige', name: 'Prestige', smallBlind: 1000, bigBlind: 2000, minLevel: 10, leagueMultiplier: 5, color: Color(0xFFF6C453)),
  Room(id: 'elite', name: 'Élite', smallBlind: 5000, bigBlind: 10000, minLevel: 15, leagueMultiplier: 8, color: Color(0xFFFF7A6B)),
  Room(id: 'legende', name: 'Légende', smallBlind: 25000, bigBlind: 50000, minLevel: 20, leagueMultiplier: 12, color: Color(0xFFFF4FD8)),
];

/// Un pack de pièces vendu en achat intégré. Le prix est en centimes, l'App Store affichera le sien.
class CoinPack {
  const CoinPack({required this.id, required this.coins, required this.priceCents, this.bonusPercent = 0, this.tag});
  final String id;
  final int coins;
  final int priceCents;
  final int bonusPercent;
  final String? tag;

  String get price => formatEuros(priceCents);
}

String formatEuros(int cents) => '${cents ~/ 100},${(cents % 100).toString().padLeft(2, '0')} €';

/// Base : 1,99 € = 25 000 pièces = 25 caves Débutant ou 5 caves Salon ; les gros packs offrent plus.
const coinPacks = [
  CoinPack(id: 'poignee', coins: 25000, priceCents: 199),
  CoinPack(id: 'sacoche', coins: 70000, priceCents: 499, bonusPercent: 12),
  CoinPack(id: 'coffret', coins: 160000, priceCents: 999, bonusPercent: 28, tag: 'Populaire'),
  CoinPack(id: 'malle', coins: 360000, priceCents: 1999, bonusPercent: 44),
  CoinPack(id: 'tresor', coins: 1000000, priceCents: 4999, bonusPercent: 60, tag: 'Meilleure valeur'),
  CoinPack(id: 'fortune', coins: 2200000, priceCents: 9999, bonusPercent: 76),
];

const welcomeOffer = CoinPack(id: 'bienvenue', coins: 60000, priceCents: 99, tag: 'Une seule fois');

/// Pass VIP de 30 jours : bonus quotidien doublé, coffre gratuit 2 fois plus souvent, +25 % d'XP, cadre VIP.
const vipPass = CoinPack(id: 'vip30', coins: 50000, priceCents: 499, tag: '30 jours');
const vipDays = 30;

// ---------- Cosmétiques ----------

/// Motif dessiné sur les tapis et les dos de cartes.
enum Motif { none, diamonds, waves, artDeco, stars, hexagons, stripes, scales }

/// Ce qui distingue les familles de cosmétiques.
enum CosmeticKind { theme, cardBack, avatar, frame }

/// Un objet cosmétique. Les champs utilisés dépendent de [kind].
class Cosmetic {
  const Cosmetic({
    required this.id,
    required this.kind,
    required this.name,
    required this.price,
    required this.colors,
    this.pattern = Motif.none,
    this.rail = const [Color(0xFF6D4C41), Color(0xFF3E2723)],
    this.accent = const Color(0xFFF6C453),
    this.icon,
    this.minLevel = 1,
    this.vipOnly = false,
  });
  final String id;
  final CosmeticKind kind;
  final String name;

  /// Prix en pièces (0 = offert ou gagné autrement).
  final int price;

  /// Thème : tapis clair puis foncé. Dos de cartes : 2 teintes. Avatar : fond. Cadre : anneau.
  final List<Color> colors;
  final Motif pattern;

  /// Thème : couleurs du bord de la table.
  final List<Color> rail;

  /// Thème : ligne de mise et reflets. Dos de cartes : emblème.
  final Color accent;

  /// Avatar et dos de cartes : symbole au centre.
  final IconData? icon;
  final int minLevel;
  final bool vipOnly;
}

const themes = [
  Cosmetic(
      id: 'vert', kind: CosmeticKind.theme, name: 'Vert classique', price: 0,
      colors: [Color(0xFF2E9A63), Color(0xFF175236)], pattern: Motif.none,
      rail: [Color(0xFF7B5236), Color(0xFF3B2416)], accent: Color(0xFFE9D9A6)),
  Cosmetic(
      id: 'bleu', kind: CosmeticKind.theme, name: 'Bleu minuit', price: 25000,
      colors: [Color(0xFF3567B0), Color(0xFF142B57)], pattern: Motif.stars,
      rail: [Color(0xFF26324A), Color(0xFF0C121E)], accent: Color(0xFF9CC3FF)),
  Cosmetic(
      id: 'grenat', kind: CosmeticKind.theme, name: 'Grenat', price: 25000,
      colors: [Color(0xFFAA3446), Color(0xFF55121F)], pattern: Motif.diamonds,
      rail: [Color(0xFF2B2B2B), Color(0xFF0E0E0E)], accent: Color(0xFFFFC2B0)),
  Cosmetic(
      id: 'riviera', kind: CosmeticKind.theme, name: 'Riviera', price: 40000,
      colors: [Color(0xFF1FB5B0), Color(0xFF0B5D69)], pattern: Motif.waves,
      rail: [Color(0xFFF3E7D3), Color(0xFFB9A586)], accent: Color(0xFFFFFFFF), minLevel: 2),
  Cosmetic(
      id: 'jungle', kind: CosmeticKind.theme, name: 'Jungle émeraude', price: 60000,
      colors: [Color(0xFF1E8C4E), Color(0xFF0A3B22)], pattern: Motif.scales,
      rail: [Color(0xFF8A6B2F), Color(0xFF3F2C0D)], accent: Color(0xFFB8F27C), minLevel: 4),
  Cosmetic(
      id: 'glacier', kind: CosmeticKind.theme, name: 'Glacier', price: 60000,
      colors: [Color(0xFF8FD3F4), Color(0xFF2D6E9E)], pattern: Motif.hexagons,
      rail: [Color(0xFFE6EEF5), Color(0xFF8A9BAD)], accent: Color(0xFFFFFFFF), minLevel: 4),
  Cosmetic(
      id: 'onyx', kind: CosmeticKind.theme, name: 'Onyx et or', price: 90000,
      colors: [Color(0xFF3C3C46), Color(0xFF111116)], pattern: Motif.artDeco,
      rail: [Color(0xFFF2CF6B), Color(0xFF8C6416)], accent: Color(0xFFF6C453), minLevel: 6),
  Cosmetic(
      id: 'neon', kind: CosmeticKind.theme, name: 'Néon Vegas', price: 150000,
      colors: [Color(0xFF5B2C9E), Color(0xFF1A0B3B)], pattern: Motif.hexagons,
      rail: [Color(0xFFFF4FD8), Color(0xFF7A1F8C)], accent: Color(0xFF4FF3FF), minLevel: 8),
  Cosmetic(
      id: 'sakura', kind: CosmeticKind.theme, name: 'Sakura', price: 150000,
      colors: [Color(0xFFD9779B), Color(0xFF6A2447)], pattern: Motif.stars,
      rail: [Color(0xFF2E1A24), Color(0xFF120A0F)], accent: Color(0xFFFFE1EC), minLevel: 8),
  Cosmetic(
      id: 'monaco', kind: CosmeticKind.theme, name: 'Monaco royal', price: 400000,
      colors: [Color(0xFFB0202E), Color(0xFF4A0710)], pattern: Motif.artDeco,
      rail: [Color(0xFFFFE08A), Color(0xFFA0711B)], accent: Color(0xFFFFE08A), minLevel: 12),
  Cosmetic(
      id: 'vip', kind: CosmeticKind.theme, name: 'Salon VIP', price: 0, vipOnly: true,
      colors: [Color(0xFF26262E), Color(0xFF07070A)], pattern: Motif.diamonds,
      rail: [Color(0xFFB98CFF), Color(0xFF4B2A85)], accent: Color(0xFFE2D4FF)),
];

const cardBacks = [
  Cosmetic(
      id: 'bordeaux', kind: CosmeticKind.cardBack, name: 'Bordeaux', price: 0,
      colors: [Color(0xFF9E2236), Color(0xFF5C0F1C)], pattern: Motif.diamonds, icon: Icons.diamond_outlined),
  Cosmetic(
      id: 'nuit', kind: CosmeticKind.cardBack, name: 'Nuit étoilée', price: 15000,
      colors: [Color(0xFF2B4782), Color(0xFF0D1730)], pattern: Motif.stars, icon: Icons.nightlight_round),
  Cosmetic(
      id: 'emeraude', kind: CosmeticKind.cardBack, name: 'Émeraude', price: 15000,
      colors: [Color(0xFF18915F), Color(0xFF07402B)], pattern: Motif.scales, icon: Icons.eco_rounded),
  Cosmetic(
      id: 'ocean', kind: CosmeticKind.cardBack, name: 'Océan', price: 25000,
      colors: [Color(0xFF1AA6C9), Color(0xFF0B4566)], pattern: Motif.waves, icon: Icons.sailing_rounded, minLevel: 2),
  Cosmetic(
      id: 'rayures', kind: CosmeticKind.cardBack, name: 'Rayures rétro', price: 25000,
      colors: [Color(0xFFF08A3C), Color(0xFF9E3A12)], pattern: Motif.stripes, icon: Icons.local_fire_department_rounded, minLevel: 3),
  Cosmetic(
      id: 'givre', kind: CosmeticKind.cardBack, name: 'Givre', price: 40000,
      colors: [Color(0xFFB5E3F8), Color(0xFF4B86B4)], pattern: Motif.hexagons, icon: Icons.ac_unit_rounded, minLevel: 4),
  Cosmetic(
      id: 'royal', kind: CosmeticKind.cardBack, name: 'Or royal', price: 60000,
      colors: [Color(0xFFE8BE55), Color(0xFF8C5E12)], pattern: Motif.artDeco, icon: Icons.workspace_premium_rounded, minLevel: 5),
  Cosmetic(
      id: 'neon', kind: CosmeticKind.cardBack, name: 'Néon', price: 90000,
      colors: [Color(0xFF6A2FC2), Color(0xFF1A0B3B)], pattern: Motif.hexagons, accent: Color(0xFF4FF3FF), icon: Icons.bolt_rounded, minLevel: 8),
  Cosmetic(
      id: 'dragon', kind: CosmeticKind.cardBack, name: 'Dragon', price: 200000,
      colors: [Color(0xFFC0392B), Color(0xFF3B0A06)], pattern: Motif.scales, accent: Color(0xFFFFD27A), icon: Icons.whatshot_rounded, minLevel: 10),
  Cosmetic(
      id: 'vip', kind: CosmeticKind.cardBack, name: 'VIP', price: 0, vipOnly: true,
      colors: [Color(0xFF2A2340), Color(0xFF0B0814)], pattern: Motif.artDeco, accent: Color(0xFFB98CFF), icon: Icons.star_rounded),
];

/// Avatars dessinés, en plus de la photo de profil.
const avatars = [
  Cosmetic(id: 'as', kind: CosmeticKind.avatar, name: 'As', price: 0, colors: [Color(0xFFE76F51), Color(0xFFB0412A)], icon: Icons.style_rounded),
  Cosmetic(id: 'chat', kind: CosmeticKind.avatar, name: 'Chat', price: 0, colors: [Color(0xFF2A9D8F), Color(0xFF16655C)], icon: Icons.pets_rounded),
  Cosmetic(id: 'eclair', kind: CosmeticKind.avatar, name: 'Éclair', price: 0, colors: [Color(0xFF8E7DFF), Color(0xFF5440C9)], icon: Icons.bolt_rounded),
  Cosmetic(id: 'fusee', kind: CosmeticKind.avatar, name: 'Fusée', price: 0, colors: [Color(0xFF4CC9F0), Color(0xFF1C7FA3)], icon: Icons.rocket_launch_rounded),
  Cosmetic(id: 'ancre', kind: CosmeticKind.avatar, name: 'Ancre', price: 8000, colors: [Color(0xFF3D5A80), Color(0xFF1B2D47)], icon: Icons.anchor_rounded),
  Cosmetic(id: 'feu', kind: CosmeticKind.avatar, name: 'Flamme', price: 8000, colors: [Color(0xFFF77F00), Color(0xFFB23A00)], icon: Icons.local_fire_department_rounded),
  Cosmetic(id: 'trefle', kind: CosmeticKind.avatar, name: 'Trèfle', price: 12000, colors: [Color(0xFF52B788), Color(0xFF1B4332)], icon: Icons.spa_rounded),
  Cosmetic(id: 'masque', kind: CosmeticKind.avatar, name: 'Masque', price: 20000, colors: [Color(0xFFEF476F), Color(0xFF8C1D3A)], icon: Icons.theater_comedy_rounded, minLevel: 3),
  Cosmetic(id: 'diamant', kind: CosmeticKind.avatar, name: 'Diamant', price: 50000, colors: [Color(0xFF8FB8FF), Color(0xFF3B5BA8)], icon: Icons.diamond_rounded, minLevel: 6),
  Cosmetic(id: 'couronne', kind: CosmeticKind.avatar, name: 'Couronne', price: 120000, colors: [Color(0xFFF6C453), Color(0xFF9C6B10)], icon: Icons.emoji_events_rounded, minLevel: 10),
];

/// Cadres autour de l'avatar, visibles à la table et au classement.
const frames = [
  Cosmetic(id: 'aucun', kind: CosmeticKind.frame, name: 'Sans cadre', price: 0, colors: [Color(0x00000000), Color(0x00000000)]),
  Cosmetic(id: 'argent', kind: CosmeticKind.frame, name: 'Argent', price: 20000, colors: [Color(0xFFF2F5FA), Color(0xFF8A9BAD)], minLevel: 2),
  Cosmetic(id: 'or', kind: CosmeticKind.frame, name: 'Or', price: 60000, colors: [Color(0xFFFFE08A), Color(0xFFC98D23)], minLevel: 5),
  Cosmetic(id: 'emeraude', kind: CosmeticKind.frame, name: 'Émeraude', price: 60000, colors: [Color(0xFF7CF2B0), Color(0xFF15805A)], minLevel: 5),
  Cosmetic(id: 'neon', kind: CosmeticKind.frame, name: 'Néon', price: 120000, colors: [Color(0xFFFF4FD8), Color(0xFF4FF3FF)], minLevel: 8),
  Cosmetic(id: 'diamant', kind: CosmeticKind.frame, name: 'Diamant', price: 300000, colors: [Color(0xFFE0F0FF), Color(0xFF8FB8FF)], minLevel: 12),
  Cosmetic(id: 'vip', kind: CosmeticKind.frame, name: 'VIP', price: 0, vipOnly: true, colors: [Color(0xFFE2D4FF), Color(0xFF7B4FD6)]),
];

const allCosmetics = [...themes, ...cardBacks, ...avatars, ...frames];

/// Objets offerts dès le départ.
const starterItems = {'theme:vert', 'cardBack:bordeaux', 'avatar:as', 'avatar:chat', 'avatar:eclair', 'avatar:fusee', 'frame:aucun'};

String itemKey(Cosmetic c) => '${c.kind.name}:${c.id}';

// ---------- Ligues ----------

/// Les ligues, de la plus basse à la plus haute, avec les points de ligue cumulés pour y entrer.
class League {
  const League(this.name, this.threshold, this.color, this.rewardScale);
  final String name;
  final int threshold;
  final Color color;

  /// Multiplie le barème des récompenses de fin de semaine.
  final int rewardScale;

  /// Pièces gagnées selon la place au classement de la semaine (1 = premier), 0 au-delà de la 20e.
  int rewardForRank(int rank) => rankRewardBase(rank) * rewardScale;

  int get weeklyReward => rewardForRank(1);
}

/// Barème Bronze ; chaque ligue le multiplie par son [League.rewardScale].
int rankRewardBase(int rank) => switch (rank) {
      1 => 5000,
      2 => 3000,
      3 => 2000,
      <= 10 => 1000,
      <= 20 => 400,
      _ => 0,
    };

const leagues = [
  League('Bronze', 0, Color(0xFFCD7F4A), 1),
  League('Argent', 300, Color(0xFFC3CCD8), 3),
  League('Or', 1000, Color(0xFFF6C453), 8),
  League('Platine', 2500, Color(0xFF6FE0D2), 20),
  League('Diamant', 5000, Color(0xFF8FB8FF), 50),
  League('Champion', 10000, Color(0xFFFF7A6B), 120),
];

// ---------- Gains gratuits ----------

/// Pièces de départ : 10 caves Débutant.
const startingCoins = 10000;

/// Récompenses du bonus quotidien, du 1er au 7e jour consécutif (27 500 par semaine complète).
const dailyRewards = [1000, 1500, 2000, 3000, 4000, 6000, 10000];

/// Coffre gratuit : toutes les 4 heures (2 heures en VIP), entre 500 et 2 000 pièces.
const freeChestHours = 4;
const freeChestMin = 500;
const freeChestMax = 2000;

/// Récompense de passage au niveau [level].
int levelUpReward(int level) => 500 * level;

/// Coup de pouce quand le joueur n'a plus de quoi payer la cave Débutant.
const rescueCoins = 2000;
const rescueCooldownHours = 6;
