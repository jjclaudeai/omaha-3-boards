export interface Contribution {
  id: string;
  /** Total misé pendant la main. */
  amount: number;
  folded: boolean;
}

export interface Pot {
  amount: number;
  /** Joueurs pouvant gagner ce pot, dans l'ordre des sièges. */
  eligible: string[];
}

/**
 * Rend la part d'une mise que personne n'a suivie (ex. relance à 100 suivie à 40 par un tapis).
 * Renvoie le joueur remboursé et le montant, ou null.
 */
export function uncalledBet(contribs: readonly Contribution[]): { id: string; amount: number } | null {
  const sorted = [...contribs].sort((a, b) => b.amount - a.amount);
  if (sorted.length < 2) return null;
  const excess = sorted[0].amount - sorted[1].amount;
  return excess > 0 ? { id: sorted[0].id, amount: excess } : null;
}

/** Découpe les mises en pot principal et pots annexes (après remboursement de la mise non suivie). */
export function buildPots(contribs: readonly Contribution[]): Pot[] {
  const levels = [...new Set(contribs.filter((c) => !c.folded && c.amount > 0).map((c) => c.amount))].sort(
    (a, b) => a - b,
  );
  const pots: Pot[] = [];
  let prev = 0;
  for (const level of levels) {
    let amount = 0;
    for (const c of contribs) amount += Math.max(0, Math.min(c.amount, level) - prev);
    const eligible = contribs.filter((c) => !c.folded && c.amount >= level).map((c) => c.id);
    // Deux niveaux avec les mêmes joueurs éligibles forment un seul pot.
    const last = pots.at(-1);
    if (last && last.eligible.join() === eligible.join()) last.amount += amount;
    else pots.push({ amount, eligible });
    prev = level;
  }
  // Mises de joueurs couchés au-delà du plus haut niveau encore en jeu : elles restent dans le dernier pot.
  let leftover = 0;
  for (const c of contribs) leftover += Math.max(0, c.amount - prev);
  if (leftover > 0 && pots.length) pots[pots.length - 1].amount += leftover;
  return pots;
}

/**
 * Partage une somme entre gagnants. Les jetons indivisibles vont aux premiers gagnants
 * dans l'ordre donné (le serveur passe l'ordre en partant du joueur après le bouton).
 */
export function splitAmong(amount: number, winners: readonly string[]): Map<string, number> {
  const out = new Map<string, number>();
  const share = Math.floor(amount / winners.length);
  let rest = amount - share * winners.length;
  for (const w of winners) {
    out.set(w, share + (rest > 0 ? 1 : 0));
    if (rest > 0) rest--;
  }
  return out;
}

/** Coupe un pot en trois tiers, un par board. Les jetons en trop vont au board 1, puis 2. */
export function splitInThirds(amount: number): [number, number, number] {
  const third = Math.floor(amount / 3);
  const rest = amount - third * 3;
  return [third + (rest > 0 ? 1 : 0), third + (rest > 1 ? 1 : 0), third];
}
