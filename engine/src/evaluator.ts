import type { Card } from './cards.ts';

export const CATEGORY_NAMES = [
  'Hauteur',
  'Paire',
  'Double paire',
  'Brelan',
  'Quinte',
  'Couleur',
  'Full',
  'Carré',
  'Quinte flush',
] as const;

export type Category = 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8;

const CAT = 16 ** 5;
const counts = new Uint8Array(13);

/**
 * Score d'une main de 5 cartes : plus grand = meilleur. Catégorie × 16^5 + départages.
 * Écrit sans allocation : les bots l'appellent des centaines de milliers de fois par décision.
 */
export function evaluate5(cards: readonly Card[]): number {
  counts.fill(0);
  let mask = 0;
  const suit0 = cards[0] & 3;
  let flush = true;
  for (let i = 0; i < 5; i++) {
    const c = cards[i];
    const r = c >> 2;
    counts[r]++;
    mask |= 1 << r;
    if ((c & 3) !== suit0) flush = false;
  }

  let straightHigh = -1;
  if (popcount(mask) === 5) {
    const high = 31 - Math.clz32(mask);
    if (mask >> (high - 4) === 0b11111) straightHigh = high;
    else if (mask === 0b1000000001111) straightHigh = 3; // roue A-2-3-4-5
  }
  if (straightHigh >= 0) return (flush ? 8 : 4) * CAT + straightHigh * 16 ** 4;

  // Groupes du plus fort au plus faible ; les cartes isolées forment les départages (kick).
  let quad = -1, trip = -1, pairHi = -1, pairLo = -1, kick = 0;
  for (let r = 12; r >= 0; r--) {
    const n = counts[r];
    if (n === 4) quad = r;
    else if (n === 3) trip = r;
    else if (n === 2) {
      if (pairHi < 0) pairHi = r;
      else pairLo = r;
    } else if (n === 1) kick = kick * 16 + r;
  }
  // Aligne `digits` chiffres hexadécimaux à gauche des 5 emplacements de départage.
  const pad = (v: number, digits: number) => v * 16 ** (5 - digits);

  if (quad >= 0) return 7 * CAT + pad(quad * 16 + kick, 2);
  if (trip >= 0 && pairHi >= 0) return 6 * CAT + pad(trip * 16 + pairHi, 2);
  if (flush) return 5 * CAT + kick;
  if (trip >= 0) return 3 * CAT + pad(trip * 256 + kick, 3);
  if (pairLo >= 0) return 2 * CAT + pad((pairHi * 16 + pairLo) * 16 + kick, 3);
  if (pairHi >= 0) return 1 * CAT + pad(pairHi * 4096 + kick, 4);
  return kick;
}

function popcount(x: number): number {
  let n = 0;
  while (x) {
    x &= x - 1;
    n++;
  }
  return n;
}

export function categoryOf(score: number): Category {
  return Math.floor(score / CAT) as Category;
}
