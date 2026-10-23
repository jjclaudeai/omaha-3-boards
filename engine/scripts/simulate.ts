// Fait jouer des bots entre eux et affiche les résultats : `npm run simulate -- 300`
import { seededRng } from '../src/cards.ts';
import { OmahaHand } from '../src/game.ts';
import { BOT_PROFILES, chooseBotAction, type BotProfile } from '../src/bot.ts';

const hands = Number(process.argv[2] ?? 200);
const rng = seededRng(2026);
const lineup: [string, BotProfile][] = [
  ['facile-1', BOT_PROFILES.facile],
  ['facile-2', BOT_PROFILES.facile],
  ['moyen-1', BOT_PROFILES.moyen],
  ['moyen-2', BOT_PROFILES.moyen],
  ['difficile-1', BOT_PROFILES.difficile],
  ['difficile-2', BOT_PROFILES.difficile],
];
const profit = new Map(lineup.map(([id]) => [id, 0]));
let decisions = 0;
let thinkMs = 0;
const startingStack = 200;

for (let n = 0; n < hands; n++) {
  const h = new OmahaHand({
    seats: lineup.map(([id]) => ({ id, stack: startingStack })),
    button: n % lineup.length,
    smallBlind: 1,
    bigBlind: 2,
    rng,
  });
  while (!h.isComplete) {
    const id = h.players[h.toAct!].id;
    const profile = lineup.find(([pid]) => pid === id)![1];
    const t0 = performance.now();
    const action = chooseBotAction(h, profile, rng);
    thinkMs += performance.now() - t0;
    decisions++;
    h.act(id, action);
  }
  for (const p of h.players) profit.set(p.id, profit.get(p.id)! + p.stack - startingStack);
}

console.log(`${hands} mains, ${decisions} décisions, ${(thinkMs / decisions).toFixed(1)} ms par décision en moyenne`);
for (const [id, v] of profit) console.log(`${id.padEnd(12)} ${(v / hands).toFixed(2).padStart(7)} jetons par main`);
