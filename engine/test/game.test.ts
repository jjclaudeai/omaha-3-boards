import { test } from 'node:test';
import assert from 'node:assert/strict';
import { type Card, newDeck, parseCards, seededRng } from '../src/cards.ts';
import { type Action, OmahaHand, type SeatInput } from '../src/game.ts';
import { boardPoints, potWinners } from '../src/pots.ts';
import { chooseBotAction, BOT_PROFILES } from '../src/bot.ts';

const rng = seededRng(42);
const seats = (...stacks: number[]): SeatInput[] => stacks.map((stack, i) => ({ id: `J${i + 1}`, stack }));

/** Construit un paquet : mains dans l'ordre des sièges, puis flop ×3, turn ×3, river ×3, puis le reste. */
function stackedDeck(holes: string[], flops: string[], turns: string, rivers: string): Card[] {
  const top = [...holes.flatMap(parseCards), ...flops.flatMap(parseCards), ...parseCards(turns), ...parseCards(rivers)];
  assert.equal(new Set(top).size, top.length, 'cartes en double dans le paquet de test');
  return [...top, ...newDeck().filter((c) => !top.includes(c))];
}

const totalChips = (h: OmahaHand) => h.players.reduce((s, p) => s + p.stack + (h.isComplete ? 0 : p.totalBet), 0);

test('blindes et premier joueur à parler (3 joueurs)', () => {
  const h = new OmahaHand({ seats: seats(100, 100, 100), button: 0, smallBlind: 1, bigBlind: 2, rng });
  assert.equal(h.players[1].bet, 1);
  assert.equal(h.players[2].bet, 2);
  assert.equal(h.toAct, 0, 'le bouton parle en premier à 3 joueurs');
  assert.equal(h.players[0].hole.length, 6);
});

test('tête-à-tête : le bouton paie la petite blinde et parle en premier', () => {
  const h = new OmahaHand({ seats: seats(100, 100), button: 0, smallBlind: 1, bigBlind: 2, rng });
  assert.equal(h.players[0].bet, 1);
  assert.equal(h.players[1].bet, 2);
  assert.equal(h.toAct, 0);
  h.act('J1', { type: 'call' });
  assert.equal(h.toAct, 1, 'la grosse blinde garde la parole');
  assert.equal(h.legalActions().check, true);
  h.act('J2', { type: 'check' });
  assert.equal(h.street, 'flop');
  assert.equal(h.toAct, 1, 'après le flop, le bouton parle en dernier');
  assert.deepEqual(h.boards.map((b) => b.length), [3, 3, 3]);
});

test('Pot-Limit : relance maximale à 7 avec des blindes 1/2', () => {
  const h = new OmahaHand({ seats: seats(500, 500, 500), button: 0, smallBlind: 1, bigBlind: 2, rng });
  assert.deepEqual(h.legalActions().raise, { min: 4, max: 7 });
  h.act('J1', { type: 'raise', to: 7 });
  // Petite blinde : suit 6, pot = 7 + 1 + 2 + 6 = 16, relance jusqu'à 7 + 16 = 23.
  assert.deepEqual(h.legalActions().raise, { min: 12, max: 23 });
  assert.throws(() => h.act('J2', { type: 'raise', to: 24 }));
});

test('tout le monde se couche : le dernier joueur ramasse le pot', () => {
  const h = new OmahaHand({ seats: seats(100, 100, 100), button: 0, smallBlind: 1, bigBlind: 2, rng });
  h.act('J1', { type: 'raise', to: 7 });
  h.act('J2', { type: 'fold' });
  h.act('J3', { type: 'fold' });
  assert.ok(h.isComplete);
  assert.equal(h.player('J1').stack, 103);
  assert.equal(totalChips(h), 300);
});

test('2 boards sur 3 remportent tout le pot', () => {
  // J1 gagne les boards 1 et 2 (brelan d'as), J2 gagne le board 3 (couleur à cœur) : 2 points contre 1.
  const deck = stackedDeck(
    ['As Ad 2c 3d 4c 5d', 'Kh Qh 2s 3s 4s 5s'],
    ['Ac 7s 8d', 'Ah 7c 8c', '2h 9h Jc'],
    '9c 9d Th',
    'Tc Td 6c',
  );
  const h = new OmahaHand({ seats: seats(100, 100), button: 0, smallBlind: 1, bigBlind: 2, rng, deck });
  h.act('J1', { type: 'raise', to: 6 }); // pot max = 2 + 3 + 1 = 6
  h.act('J2', { type: 'call' });
  for (let i = 0; i < 3; i++) {
    h.act('J2', { type: 'check' });
    h.act('J1', { type: 'check' });
  }
  assert.ok(h.isComplete);
  assert.equal(h.winnings.get('J1'), 12);
  assert.equal(h.winnings.get('J2'), undefined);
  assert.equal(h.player('J1').stack, 106);
  assert.equal(h.player('J2').stack, 94);
});

test('points par board et partage seulement en cas d\'égalité de points', () => {
  const order = ['A', 'B', 'C'];
  const win = (...boards: string[][]) => potWinners(boardPoints(boards), order);
  assert.deepEqual(win(['A'], ['A'], ['B']), ['A'], '2 points contre 1');
  assert.deepEqual(win(['A'], ['B'], ['A', 'B']), ['A', 'B'], '2 joueurs à 1,5 point');
  assert.deepEqual(win(['A'], ['B'], ['C']), ['A', 'B', 'C'], '3 joueurs à 1 point');
  assert.deepEqual(win(['A'], ['B'], ['A', 'B']), ['A', 'B'], '1,5 / 1,5 / 0');
  assert.deepEqual(win(['A'], ['B', 'C'], ['B', 'C']), ['A', 'B', 'C'], '1 / 0,5 + 0,5 / 0,5 + 0,5 : 3 joueurs à 1 point');
  assert.deepEqual(win(['A', 'B'], ['C'], ['C']), ['C'], '0,5 / 0,5 / 2');
});

test('pots annexes avec plusieurs tapis', () => {
  // J1 (20 jetons) a la meilleure main sur les 3 boards, J2 (50) la deuxième, J3 (100) la pire.
  const deck = stackedDeck(
    ['As Ad Ah 5c 6c 7d', 'Ks Kd Kh 5d 6d 7c', '2s 3s 2h 3h 4s 4h'],
    ['Ac Kc Jd', 'Qc Jh Tc', 'Th Js 9c'],
    'Ts Qd Qs',
    'Qh Jc Td',
  );
  const h = new OmahaHand({ seats: seats(20, 50, 100), button: 0, smallBlind: 1, bigBlind: 2, rng, deck });
  while (!h.isComplete) {
    const legal = h.legalActions();
    const id = h.players[h.toAct!].id;
    if (legal.raise) h.act(id, { type: 'raise', to: legal.raise.max });
    else if (legal.call > 0) h.act(id, { type: 'call' });
    else h.act(id, { type: 'check' });
  }
  // Pot principal 60 pour J1, pot annexe 60 pour J2, J3 récupère le reste.
  assert.equal(h.player('J1').stack, 60);
  assert.equal(h.player('J2').stack, 60);
  assert.equal(h.player('J3').stack, 50);
});

test('mains aléatoires : jetons conservés et cartes uniques sur 3000 mains', () => {
  const r = seededRng(7);
  for (let n = 0; n < 3000; n++) {
    const players = 2 + Math.floor(r() * 5);
    const stacks = Array.from({ length: players }, () => 1 + Math.floor(r() * 300));
    const h = new OmahaHand({ seats: seats(...stacks), button: n % players, smallBlind: 1, bigBlind: 2, rng: r });
    const start = stacks.reduce((a, b) => a + b, 0);
    const all = [...h.players.flatMap((p) => p.hole)];
    let guard = 0;
    while (!h.isComplete) {
      assert.ok(guard++ < 200, 'la main ne se termine pas');
      const legal = h.legalActions();
      const id = h.players[h.toAct!].id;
      const options: Action[] = [];
      if (legal.fold) options.push({ type: 'fold' });
      if (legal.check) options.push({ type: 'check' });
      if (legal.call > 0) options.push({ type: 'call' }, { type: 'call' });
      if (legal.raise) {
        const { min, max } = legal.raise;
        options.push({ type: 'raise', to: min }, { type: 'raise', to: max });
      }
      h.act(id, options[Math.floor(r() * options.length)]);
    }
    all.push(...h.boards.flat());
    assert.equal(new Set(all).size, all.length, 'carte distribuée deux fois');
    const end = h.players.reduce((s, p) => s + p.stack, 0);
    assert.equal(end, start, `main ${n} : jetons perdus ou créés`);
    assert.ok(h.players.every((p) => p.stack >= 0));
  }
});

test('les bots jouent des mains complètes sans action illégale', () => {
  const r = seededRng(11);
  for (let n = 0; n < 30; n++) {
    const h = new OmahaHand({ seats: seats(200, 200, 200, 200, 200, 200), button: n % 6, smallBlind: 1, bigBlind: 2, rng: r });
    while (!h.isComplete) h.act(h.players[h.toAct!].id, chooseBotAction(h, BOT_PROFILES.facile, r));
    assert.equal(h.players.reduce((s, p) => s + p.stack, 0), 1200);
  }
});
