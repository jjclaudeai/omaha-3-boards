import type { Card } from './cards.ts';
import { evaluate5 } from './evaluator.ts';

export interface BestHand {
  score: number;
  /** Les 2 cartes de la main et les 3 cartes du board retenues. */
  hole: [Card, Card];
  board: [Card, Card, Card];
}

/**
 * Meilleure main Omaha : exactement 2 cartes privées parmi les 6 et 3 cartes du board parmi les 5.
 * 15 × 10 = 150 combinaisons.
 */
export function bestOmahaHand(hole: readonly Card[], board: readonly Card[]): BestHand {
  if (board.length !== 5) throw new Error('Le board doit compter 5 cartes');
  let best: BestHand | null = null;
  const five: Card[] = [0, 0, 0, 0, 0];
  for (let a = 0; a < hole.length - 1; a++) {
    for (let b = a + 1; b < hole.length; b++) {
      five[0] = hole[a];
      five[1] = hole[b];
      for (let c = 0; c < 3; c++) {
        for (let d = c + 1; d < 4; d++) {
          for (let e = d + 1; e < 5; e++) {
            five[2] = board[c];
            five[3] = board[d];
            five[4] = board[e];
            const score = evaluate5(five);
            if (!best || score > best.score) {
              best = { score, hole: [hole[a], hole[b]], board: [board[c], board[d], board[e]] };
            }
          }
        }
      }
    }
  }
  return best!;
}

const five: Card[] = [0, 0, 0, 0, 0];

/** Même calcul que bestOmahaHand, sans allocation : seulement le score (utilisé par les bots). */
export function bestOmahaScore(hole: readonly Card[], board: readonly Card[]): number {
  let best = -1;
  for (let a = 0; a < hole.length - 1; a++) {
    five[0] = hole[a];
    for (let b = a + 1; b < hole.length; b++) {
      five[1] = hole[b];
      for (let c = 0; c < 3; c++) {
        five[2] = board[c];
        for (let d = c + 1; d < 4; d++) {
          five[3] = board[d];
          for (let e = d + 1; e < 5; e++) {
            five[4] = board[e];
            const score = evaluate5(five);
            if (score > best) best = score;
          }
        }
      }
    }
  }
  return best;
}
