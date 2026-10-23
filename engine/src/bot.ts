import { type Card, type Rng, newDeck } from './cards.ts';
import { type Action, BOARDS, HOLE_CARDS, OmahaHand } from './game.ts';
import { bestOmahaScore } from './omaha.ts';

export interface BotProfile {
  /** Nombre de tirages Monte-Carlo par décision : plus = plus fort et plus lent. */
  samples: number;
  /** 0 = prudent, 1 = très agressif. */
  aggression: number;
  /** Probabilité de bluffer quand la main est faible et que personne n'a misé. */
  bluff: number;
}

export const BOT_PROFILES = {
  facile: { samples: 40, aggression: 0.2, bluff: 0.02 },
  moyen: { samples: 120, aggression: 0.5, bluff: 0.06 },
  difficile: { samples: 300, aggression: 0.7, bluff: 0.1 },
} satisfies Record<string, BotProfile>;

/**
 * Part du pot que la main remporte en moyenne contre `opponents` mains aléatoires,
 * en complétant les 3 boards au hasard. Chaque board vaut un tiers.
 */
export function estimateEquity(
  hole: readonly Card[],
  boards: readonly (readonly Card[])[],
  opponents: number,
  samples: number,
  rng: Rng,
): number {
  const known = new Set<Card>([...hole, ...boards.flat()]);
  const rest = newDeck().filter((c) => !known.has(c));
  const missing = 5 - boards[0].length;
  const needed = opponents * HOLE_CARDS + missing * BOARDS;
  let total = 0;
  for (let s = 0; s < samples; s++) {
    // Tirage partiel de Fisher-Yates : seules les `needed` premières cartes sont mélangées.
    for (let i = 0; i < needed; i++) {
      const j = i + Math.floor(rng() * (rest.length - i));
      [rest[i], rest[j]] = [rest[j], rest[i]];
    }
    let k = 0;
    const opp: Card[][] = [];
    for (let o = 0; o < opponents; o++) opp.push(rest.slice(k, (k += HOLE_CARDS)));
    for (const b of boards) {
      const full = [...b, ...rest.slice(k, (k += missing))];
      const mine = bestOmahaScore(hole, full);
      let best = mine;
      let ties = 1;
      for (const h of opp) {
        const sc = bestOmahaScore(h, full);
        if (sc > best) {
          best = sc;
          ties = 0;
          break;
        }
        if (sc === best) ties++;
      }
      if (best === mine && ties > 0) total += 1 / ties / BOARDS;
    }
  }
  return total / samples;
}

/** Choisit une action légale pour le joueur qui doit parler. */
export function chooseBotAction(hand: OmahaHand, profile: BotProfile, rng: Rng): Action {
  if (hand.toAct === null) throw new Error("Aucun joueur ne doit parler");
  const me = hand.players[hand.toAct];
  const legal = hand.legalActions();
  const opponents = hand.players.filter((p) => p !== me && !p.folded).length;
  const equity = estimateEquity(me.hole, hand.boards, opponents, profile.samples, rng);

  const toCall = legal.call;
  const potAfterCall = hand.pot + toCall;
  const potOdds = toCall / potAfterCall;
  // Part « juste » du pot à plusieurs : au-dessus, la main est meilleure que la moyenne.
  const fair = 1 / (opponents + 1);
  const strength = equity / fair; // 1 = main moyenne
  const noise = (rng() - 0.5) * 0.3;

  const raiseTo = (fraction: number): Action | null => {
    if (!legal.raise) return null;
    const { min, max } = legal.raise;
    const target = hand.currentBet + toCall + Math.round(fraction * potAfterCall);
    return { type: 'raise', to: Math.max(min, Math.min(max, target)) };
  };

  if (strength + noise > 1.6 - profile.aggression * 0.4) {
    const r = raiseTo(0.5 + profile.aggression * 0.5);
    if (r) return r;
  }
  if (legal.check) {
    if (rng() < profile.bluff) return raiseTo(0.5) ?? { type: 'check' };
    return { type: 'check' };
  }
  if (equity + noise * 0.2 >= potOdds) return { type: 'call' };
  return { type: 'fold' };
}
