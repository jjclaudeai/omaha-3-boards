// Une carte est un entier de 0 à 51 : rang = carte >> 2 (0 = deux … 12 = as), couleur = carte & 3.
export type Card = number;

export const RANKS = '23456789TJQKA';
export const SUITS = 'cdhs'; // trèfle, carreau, cœur, pique

export const rankOf = (c: Card): number => c >> 2;
export const suitOf = (c: Card): number => c & 3;

export function cardToString(c: Card): string {
  return RANKS[rankOf(c)] + SUITS[suitOf(c)];
}

export function parseCard(s: string): Card {
  const r = RANKS.indexOf(s[0].toUpperCase());
  const su = SUITS.indexOf(s[1].toLowerCase());
  if (s.length !== 2 || r < 0 || su < 0) throw new Error(`Carte invalide : ${s}`);
  return (r << 2) | su;
}

export function parseCards(s: string): Card[] {
  return s.trim().split(/\s+/).filter(Boolean).map(parseCard);
}

export function newDeck(): Card[] {
  return Array.from({ length: 52 }, (_, i) => i);
}

/** Renvoie un nombre aléatoire dans [0, 1). Le serveur passera une source cryptographique. */
export type Rng = () => number;

export function shuffle(deck: Card[], rng: Rng): Card[] {
  const d = deck.slice();
  for (let i = d.length - 1; i > 0; i--) {
    const j = Math.floor(rng() * (i + 1));
    [d[i], d[j]] = [d[j], d[i]];
  }
  return d;
}

/** Générateur déterministe (mulberry32), pour les tests et les simulations rejouables. */
export function seededRng(seed: number): Rng {
  let a = seed >>> 0;
  return () => {
    a = (a + 0x6d2b79f5) >>> 0;
    let t = a;
    t = Math.imul(t ^ (t >>> 15), t | 1);
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}
