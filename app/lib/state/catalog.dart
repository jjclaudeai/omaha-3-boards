import 'package:flutter/material.dart';

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
}

const rooms = [
  Room(id: 'debutant', name: 'Débutant', smallBlind: 10, bigBlind: 20, minLevel: 1, leagueMultiplier: 1, color: Color(0xFF3FD68E)),
  Room(id: 'salon', name: 'Salon', smallBlind: 50, bigBlind: 100, minLevel: 3, leagueMultiplier: 2, color: Color(0xFF55A8FF)),
  Room(id: 'club', name: 'Club privé', smallBlind: 200, bigBlind: 400, minLevel: 6, leagueMultiplier: 3, color: Color(0xFFB57CFF)),
  Room(id: 'prestige', name: 'Prestige', smallBlind: 1000, bigBlind: 2000, minLevel: 10, leagueMultiplier: 5, color: Color(0xFFF6C453)),
];

/// Un pack de pièces vendu en achat intégré.
class CoinPack {
  const CoinPack({required this.id, required this.coins, required this.price, this.bonusPercent = 0, this.tag});
  final String id;
  final int coins;
  final String price;
  final int bonusPercent;
  final String? tag;
}

const coinPacks = [
  CoinPack(id: 'poignee', coins: 10000, price: '1,99 €'),
  CoinPack(id: 'sacoche', coins: 33000, price: '4,99 €', bonusPercent: 10),
  CoinPack(id: 'coffret', coins: 94000, price: '9,99 €', bonusPercent: 25, tag: 'Populaire'),
  CoinPack(id: 'malle', coins: 280000, price: '19,99 €', bonusPercent: 40),
  CoinPack(id: 'tresor', coins: 960000, price: '49,99 €', bonusPercent: 60, tag: 'Meilleure valeur'),
];

const welcomeOffer = CoinPack(id: 'bienvenue', coins: 50000, price: '0,99 €', tag: 'Une seule fois');

/// Un objet cosmétique : dos de cartes ou tapis.
class Cosmetic {
  const Cosmetic({required this.id, required this.name, required this.price, required this.colors});
  final String id;
  final String name;

  /// Prix en pièces (0 = offert).
  final int price;
  final List<Color> colors;
}

const cardBacks = [
  Cosmetic(id: 'bordeaux', name: 'Bordeaux', price: 0, colors: [Color(0xFF8E1B2C), Color(0xFF5C0F1C)]),
  Cosmetic(id: 'nuit', name: 'Nuit étoilée', price: 20000, colors: [Color(0xFF243B6B), Color(0xFF0D1730)]),
  Cosmetic(id: 'emeraude', name: 'Émeraude', price: 20000, colors: [Color(0xFF15805A), Color(0xFF07402B)]),
  Cosmetic(id: 'royal', name: 'Or royal', price: 60000, colors: [Color(0xFFE2B54A), Color(0xFF8C5E12)]),
];

const felts = [
  Cosmetic(id: 'vert', name: 'Vert classique', price: 0, colors: [Color(0xFF2E8B57), Color(0xFF1B5E3A)]),
  Cosmetic(id: 'bleu', name: 'Bleu minuit', price: 30000, colors: [Color(0xFF2F5E9E), Color(0xFF173561)]),
  Cosmetic(id: 'grenat', name: 'Grenat', price: 30000, colors: [Color(0xFF9E2F3E), Color(0xFF5E1621)]),
  Cosmetic(id: 'onyx', name: 'Onyx et or', price: 80000, colors: [Color(0xFF34343C), Color(0xFF141418)]),
];

/// Les ligues, de la plus basse à la plus haute, avec les points de ligue cumulés pour y entrer.
class League {
  const League(this.name, this.threshold, this.color, this.weeklyReward);
  final String name;
  final int threshold;
  final Color color;

  /// Pièces gagnées par le 1er du classement de la semaine dans cette ligue.
  final int weeklyReward;
}

const leagues = [
  League('Bronze', 0, Color(0xFFCD7F4A), 5000),
  League('Argent', 300, Color(0xFFC3CCD8), 15000),
  League('Or', 1000, Color(0xFFF6C453), 40000),
  League('Platine', 2500, Color(0xFF6FE0D2), 100000),
  League('Diamant', 5000, Color(0xFF8FB8FF), 250000),
  League('Champion', 10000, Color(0xFFFF7A6B), 600000),
];

/// Récompenses du bonus quotidien, du 1er au 7e jour consécutif.
const dailyRewards = [500, 750, 1000, 1500, 2000, 3000, 5000];
