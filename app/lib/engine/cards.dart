import 'dart:math';

/// Une carte est un entier de 0 à 51 : rang = carte >> 2 (0 = deux … 12 = as), couleur = carte & 3.
typedef CardId = int;

const ranks = '23456789TJQKA';
const suits = 'cdhs'; // trèfle, carreau, cœur, pique

int rankOf(CardId c) => c >> 2;
int suitOf(CardId c) => c & 3;

String cardToString(CardId c) => ranks[rankOf(c)] + suits[suitOf(c)];

CardId parseCard(String s) {
  final r = ranks.indexOf(s[0].toUpperCase());
  final su = suits.indexOf(s[1].toLowerCase());
  if (s.length != 2 || r < 0 || su < 0) throw ArgumentError('Carte invalide : $s');
  return (r << 2) | su;
}

List<CardId> parseCards(String s) =>
    s.trim().split(RegExp(r'\s+')).where((x) => x.isNotEmpty).map(parseCard).toList();

List<CardId> newDeck() => List.generate(52, (i) => i);

List<CardId> shuffled(List<CardId> deck, Random rng) {
  final d = List<CardId>.of(deck);
  for (var i = d.length - 1; i > 0; i--) {
    final j = rng.nextInt(i + 1);
    final t = d[i];
    d[i] = d[j];
    d[j] = t;
  }
  return d;
}
