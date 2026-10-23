import { type Card, type Rng, newDeck, shuffle } from './cards.ts';
import { bestOmahaHand, type BestHand } from './omaha.ts';
import { boardPoints, buildPots, potWinners, splitAmong, uncalledBet, type Pot } from './pots.ts';

export const HOLE_CARDS = 6;
export const BOARDS = 3;
export const MAX_PLAYERS = 6; // 6 × 6 + 3 × 5 = 51 cartes sur 52, sans carte brûlée

export type Street = 'preflop' | 'flop' | 'turn' | 'river' | 'showdown' | 'complete';

export type Action =
  | { type: 'fold' }
  | { type: 'check' }
  | { type: 'call' }
  /** `to` = montant total misé sur ce tour après la relance (et non le supplément). */
  | { type: 'raise'; to: number };

export interface LegalActions {
  fold: boolean;
  check: boolean;
  /** Supplément à payer pour suivre (plafonné au tapis), 0 si pas de suivi possible. */
  call: number;
  /** Bornes de relance « jusqu'à », ou null si la relance est interdite. */
  raise: { min: number; max: number } | null;
}

export interface SeatInput {
  id: string;
  stack: number;
}

export interface PlayerState {
  id: string;
  stack: number;
  hole: Card[];
  /** Mise sur le tour d'enchères en cours. */
  bet: number;
  /** Mise totale sur la main. */
  totalBet: number;
  folded: boolean;
  allIn: boolean;
  /** Valeur de raiseCounter lors de sa dernière action sur ce tour (-1 = pas encore agi). */
  actedAt: number;
}

export type GameEvent =
  | { type: 'blind'; id: string; amount: number }
  | { type: 'deal-hole' }
  | { type: 'action'; id: string; action: Action; amount: number; allIn: boolean }
  | { type: 'street'; street: Street; boards: Card[][] }
  | { type: 'refund'; id: string; amount: number }
  | { type: 'showdown'; hands: Record<string, BestHand[]> }
  /** Gagnants d'un board pour un pot : ils se partagent le point du board. */
  | { type: 'board-win'; board: number; pot: number; winners: string[] }
  /** Le pot va au(x) joueur(s) qui ont le plus de points (en soixantièmes : 60 = 1 board). */
  | { type: 'pot-win'; pot: number; winners: string[]; amount: number; points: Record<string, number> }
  | { type: 'win-uncontested'; id: string; amount: number };

export interface HandOptions {
  seats: SeatInput[];
  /** Index du bouton dans `seats`. */
  button: number;
  smallBlind: number;
  bigBlind: number;
  rng: Rng;
  /** Paquet imposé, dans l'ordre de distribution (tests uniquement). */
  deck?: Card[];
}

export class OmahaHand {
  readonly players: PlayerState[];
  readonly button: number;
  readonly smallBlind: number;
  readonly bigBlind: number;
  readonly boards: Card[][] = [[], [], []];
  readonly events: GameEvent[] = [];
  street: Street = 'preflop';
  /** Index du joueur qui doit agir, ou null. */
  toAct: number | null = null;
  currentBet = 0;
  /** Taille de la dernière relance complète, minimum pour la suivante. */
  minRaise: number;
  /** Incrémenté à chaque relance complète : rouvre les enchères pour ceux qui ont déjà parlé. */
  raiseCounter = 0;
  /** Jetons ramassés dans le pot par chaque joueur une fois la main terminée. */
  readonly winnings = new Map<string, number>();
  private deck: Card[];

  constructor(opts: HandOptions) {
    const n = opts.seats.length;
    if (n < 2 || n > MAX_PLAYERS) throw new Error(`Une table compte de 2 à ${MAX_PLAYERS} joueurs`);
    if (opts.seats.some((s) => s.stack <= 0)) throw new Error('Chaque joueur doit avoir des jetons');
    this.button = opts.button;
    this.smallBlind = opts.smallBlind;
    this.bigBlind = opts.bigBlind;
    this.minRaise = opts.bigBlind;
    this.deck = opts.deck ? opts.deck.slice() : shuffle(newDeck(), opts.rng);
    this.players = opts.seats.map((s) => ({
      id: s.id,
      stack: s.stack,
      hole: [],
      bet: 0,
      totalBet: 0,
      folded: false,
      allIn: false,
      actedAt: -1,
    }));

    // En tête-à-tête, le bouton paie la petite blinde et parle en premier avant le flop.
    const sb = n === 2 ? this.button : this.next(this.button);
    const bb = this.next(sb);
    this.post(sb, this.smallBlind);
    this.post(bb, this.bigBlind);
    this.currentBet = Math.max(...this.players.map((p) => p.bet));

    for (const p of this.players) p.hole = this.draw(HOLE_CARDS);
    this.events.push({ type: 'deal-hole' });

    this.toAct = this.findNextToAct(bb);
    if (this.toAct === null) this.endStreet();
  }

  get pot(): number {
    return this.players.reduce((s, p) => s + p.totalBet, 0);
  }

  get isComplete(): boolean {
    return this.street === 'complete';
  }

  player(id: string): PlayerState {
    const p = this.players.find((q) => q.id === id);
    if (!p) throw new Error(`Joueur inconnu : ${id}`);
    return p;
  }

  legalActions(): LegalActions {
    if (this.toAct === null) return { fold: false, check: false, call: 0, raise: null };
    const p = this.players[this.toAct];
    const toCall = this.currentBet - p.bet;
    const callAmount = Math.min(toCall, p.stack);
    let raise: LegalActions['raise'] = null;
    const reopened = p.actedAt < this.raiseCounter;
    const othersCanAct = this.players.some((q) => q !== p && !q.folded && !q.allIn);
    if (reopened && p.stack > toCall && othersCanAct) {
      const allInTo = p.bet + p.stack;
      // Pot-Limit : suivre, puis relancer de la taille du pot après le suivi.
      const potMaxTo = this.currentBet + this.pot + toCall;
      const max = Math.min(potMaxTo, allInTo);
      const min = Math.min(this.currentBet + this.minRaise, allInTo);
      raise = { min, max };
    }
    return { fold: toCall > 0, check: toCall === 0, call: toCall > 0 ? callAmount : 0, raise };
  }

  act(id: string, action: Action): void {
    if (this.toAct === null) throw new Error("Personne ne doit jouer");
    const idx = this.toAct;
    const p = this.players[idx];
    if (p.id !== id) throw new Error(`Ce n'est pas à ${id} de jouer`);
    const legal = this.legalActions();
    let amount = 0;

    switch (action.type) {
      case 'fold':
        if (!legal.fold) throw new Error('Rien à suivre : checker plutôt que se coucher');
        p.folded = true;
        break;
      case 'check':
        if (!legal.check) throw new Error('Impossible de checker face à une mise');
        break;
      case 'call':
        if (legal.call <= 0) throw new Error('Rien à suivre');
        amount = this.commit(p, legal.call);
        break;
      case 'raise': {
        if (!legal.raise) throw new Error('Relance interdite');
        const { min, max } = legal.raise;
        if (!Number.isInteger(action.to) || action.to < min || action.to > max) {
          throw new Error(`Relance hors limites : ${action.to} (entre ${min} et ${max})`);
        }
        const size = action.to - this.currentBet;
        amount = this.commit(p, action.to - p.bet);
        if (size >= this.minRaise) {
          this.minRaise = size;
          this.raiseCounter++;
        }
        this.currentBet = action.to;
        break;
      }
    }
    p.actedAt = this.raiseCounter;
    this.events.push({ type: 'action', id, action, amount, allIn: p.allIn });

    if (this.players.filter((q) => !q.folded).length === 1) return this.finishUncontested();
    this.toAct = this.findNextToAct(idx);
    if (this.toAct === null) this.endStreet();
  }

  private next(i: number): number {
    return (i + 1) % this.players.length;
  }

  private draw(n: number): Card[] {
    if (this.deck.length < n) throw new Error('Paquet épuisé');
    return this.deck.splice(0, n);
  }

  private post(i: number, blind: number): void {
    const p = this.players[i];
    const amount = this.commit(p, Math.min(blind, p.stack));
    this.events.push({ type: 'blind', id: p.id, amount });
  }

  private commit(p: PlayerState, amount: number): number {
    p.stack -= amount;
    p.bet += amount;
    p.totalBet += amount;
    if (p.stack === 0) p.allIn = true;
    return amount;
  }

  private needsToAct(p: PlayerState): boolean {
    return !p.folded && !p.allIn && (p.actedAt < 0 || p.bet < this.currentBet);
  }

  private findNextToAct(from: number): number | null {
    // Un joueur seul avec des jetons face à des tapis n'a rien à décider s'il a déjà égalisé.
    const canAct = this.players.filter((p) => !p.folded && !p.allIn);
    if (canAct.length === 1 && canAct[0].bet >= this.currentBet) return null;
    for (let k = 1; k <= this.players.length; k++) {
      const i = (from + k) % this.players.length;
      if (this.needsToAct(this.players[i])) return i;
    }
    return null;
  }

  private endStreet(): void {
    const order: Street[] = ['preflop', 'flop', 'turn', 'river', 'showdown'];
    const nextStreet = order[order.indexOf(this.street) + 1];
    for (const p of this.players) {
      p.bet = 0;
      p.actedAt = -1;
    }
    this.currentBet = 0;
    this.minRaise = this.bigBlind;
    this.raiseCounter = 0;

    if (nextStreet === 'showdown') return this.showdown();

    const count = nextStreet === 'flop' ? 3 : 1;
    for (const b of this.boards) b.push(...this.draw(count));
    this.street = nextStreet;
    this.events.push({ type: 'street', street: nextStreet, boards: this.boards.map((b) => b.slice()) });

    this.toAct = this.findNextToAct(this.button);
    if (this.toAct === null) this.endStreet(); // tout le monde à tapis : on déroule les boards
  }

  private refundUncalled(): void {
    const refund = uncalledBet(this.players.map((p) => ({ id: p.id, amount: p.totalBet, folded: p.folded })));
    if (!refund) return;
    const p = this.player(refund.id);
    p.totalBet -= refund.amount;
    p.stack += refund.amount;
    this.events.push({ type: 'refund', id: p.id, amount: refund.amount });
  }

  private credit(id: string, amount: number): void {
    this.player(id).stack += amount;
    this.winnings.set(id, (this.winnings.get(id) ?? 0) + amount);
  }

  private finishUncontested(): void {
    this.refundUncalled();
    const winner = this.players.find((p) => !p.folded)!;
    const amount = this.pot;
    this.credit(winner.id, amount);
    this.events.push({ type: 'win-uncontested', id: winner.id, amount });
    this.complete();
  }

  /** Joueurs dans l'ordre de partage des jetons indivisibles : à partir du siège après le bouton. */
  private seatOrderFromButton(): string[] {
    return this.players.map((_, k) => this.players[(this.button + 1 + k) % this.players.length].id);
  }

  private showdown(): void {
    this.street = 'showdown';
    this.toAct = null;
    this.refundUncalled();

    const live = this.players.filter((p) => !p.folded);
    const hands: Record<string, BestHand[]> = {};
    for (const p of live) hands[p.id] = this.boards.map((b) => bestOmahaHand(p.hole, b));
    this.events.push({ type: 'showdown', hands });

    const pots: Pot[] = buildPots(this.players.map((p) => ({ id: p.id, amount: p.totalBet, folded: p.folded })));
    const order = this.seatOrderFromButton();
    pots.forEach((pot, potIndex) => {
      // Chaque board vaut 1 point ; le meilleur total remporte tout le pot, partage seulement en cas d'égalité.
      const boardWinners = this.boards.map((_, board) => {
        const best = Math.max(...pot.eligible.map((id) => hands[id][board].score));
        const winners = order.filter((id) => pot.eligible.includes(id) && hands[id][board].score === best);
        this.events.push({ type: 'board-win', board, pot: potIndex, winners });
        return winners;
      });
      const points = boardPoints(boardWinners);
      const winners = potWinners(points, order);
      for (const [id, won] of splitAmong(pot.amount, winners)) this.credit(id, won);
      this.events.push({ type: 'pot-win', pot: potIndex, winners, amount: pot.amount, points: Object.fromEntries(points) });
    });
    this.complete();
  }

  private complete(): void {
    this.street = 'complete';
    this.toAct = null;
  }
}
