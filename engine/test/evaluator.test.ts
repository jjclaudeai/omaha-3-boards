import { test } from 'node:test';
import assert from 'node:assert/strict';
import { parseCards } from '../src/cards.ts';
import { categoryOf, evaluate5 } from '../src/evaluator.ts';
import { bestOmahaHand } from '../src/omaha.ts';

const ev = (s: string) => evaluate5(parseCards(s));

test('reconnaît chaque catégorie de main', () => {
  const cases: [string, number][] = [
    ['As Kd 9h 7c 3s', 0],
    ['As Ad 9h 7c 3s', 1],
    ['As Ad 9h 9c 3s', 2],
    ['As Ad Ah 7c 3s', 3],
    ['5s 4d 3h 2c As', 4],
    ['Ts 8s 6s 4s 2s', 5],
    ['Ks Kd Kh 2c 2s', 6],
    ['Qs Qd Qh Qc 2s', 7],
    ['9h 8h 7h 6h 5h', 8],
  ];
  for (const [cards, cat] of cases) assert.equal(categoryOf(ev(cards)), cat, cards);
});

test('départage correctement', () => {
  assert.ok(ev('As Ad Kh 7c 3s') > ev('As Ad Qh 7c 3s'), 'kicker');
  assert.ok(ev('6s 5d 4h 3c 2s') > ev('5s 4d 3h 2c As'), 'la roue est la plus petite quinte');
  assert.ok(ev('Ks Kd 2h 2c Ah') > ev('Qs Qd Jh Jc Ah'), 'double paire');
  assert.ok(ev('2s 2d 2h Ac As') < ev('3s 3d 3h 2c 2s'), 'full');
  assert.equal(ev('As Kd 9h 7c 3s'), ev('Ad Kh 9c 7s 3d'), 'égalité');
});

test('Omaha : exactement 2 cartes de la main', () => {
  // Board avec 4 cœurs : un seul cœur en main ne fait pas de couleur.
  const board = parseCards('2h 7h 9h Kh 3c');
  const oneHeart = bestOmahaHand(parseCards('Ah As Ad Ac 5s 6d'), board);
  assert.notEqual(categoryOf(oneHeart.score), 5);
  const twoHearts = bestOmahaHand(parseCards('Ah 4h Ts Jd 5s 6d'), board);
  assert.equal(categoryOf(twoHearts.score), 5);

  // Quinte sur le board : sans cartes adaptées, pas de quinte.
  const straightBoard = parseCards('5c 6d 7h 8s 9c');
  const noStraight = bestOmahaHand(parseCards('Ks Kd 2h 2c Qs Jd'), straightBoard);
  assert.equal(categoryOf(noStraight.score), 1, 'seulement une paire de rois');
});

test('les 2 598 960 mains de 5 cartes : fréquences et 7 462 valeurs distinctes', () => {
  const freq = new Array(9).fill(0);
  const distinct = new Set<number>();
  const h = [0, 0, 0, 0, 0];
  for (h[0] = 0; h[0] < 48; h[0]++)
    for (h[1] = h[0] + 1; h[1] < 49; h[1]++)
      for (h[2] = h[1] + 1; h[2] < 50; h[2]++)
        for (h[3] = h[2] + 1; h[3] < 51; h[3]++)
          for (h[4] = h[3] + 1; h[4] < 52; h[4]++) {
            const s = evaluate5(h);
            freq[categoryOf(s)]++;
            distinct.add(s);
          }
  assert.deepEqual(freq, [1302540, 1098240, 123552, 54912, 10200, 5108, 3744, 624, 40]);
  assert.equal(distinct.size, 7462);
});
