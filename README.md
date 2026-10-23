# Omaha 6 cartes à 3 boards

Application mobile (iOS et Android) de poker Omaha 6 cartes Pot-Limit joué sur 3 boards en même temps.

## Contenu

- `app/` : application Flutter (iOS, Android, et web pour les essais). Prototype jouable contre 5 bots.
  - `lib/engine/` : le moteur de règles porté en Dart, pour jouer contre les bots sans serveur.
    Mêmes tests que la version TypeScript ; garder les deux alignés.
  - `lib/game_controller.dart` : enchaîne les mains, fait jouer les bots, remplace un bot ruiné.
  - `lib/ui/` : table (6 sièges, 3 boards, cartes 4 couleurs, animations de distribution, résultats par board).

- `engine/` : moteur de règles en TypeScript, sans dépendance. Il tournera sur le serveur de jeu, qui fait autorité.
  - `src/cards.ts` : cartes, paquet, mélange.
  - `src/evaluator.ts` : valeur d'une main de 5 cartes.
  - `src/omaha.ts` : meilleure main Omaha (exactement 2 cartes privées + 3 du board).
  - `src/pots.ts` : pot principal, pots annexes, mise non suivie, partage en trois tiers.
  - `src/game.ts` : une main complète (blindes, 4 tours d'enchères Pot-Limit, 3 boards, abattage).
  - `src/bot.ts` : bots à 3 niveaux, basés sur une estimation Monte-Carlo de l'équité.

## Règles retenues (validées le 23/10/2026)

- 2 à 6 joueurs ; 6 cartes privées chacun ; 51 cartes sur 52 utilisées à 6, donc aucune carte brûlée.
- 3 boards de 5 cartes (flop, turn, river distribués sur les 3 boards à la fois).
- Pot-Limit, petite et grosse blinde ; en tête-à-tête, le bouton paie la petite blinde.
- Chaque board : exactement 2 cartes privées + 3 cartes du board.
- Chaque pot est coupé en trois tiers égaux, un par board ; jetons indivisibles au premier joueur après le bouton.

## Lancer

Node.js 22.18 ou plus récent (TypeScript exécuté directement, sans compilation) :

```sh
cd engine
npm test               # tests, dont les 2,6 millions de mains de 5 cartes et 3 000 mains aléatoires
npm run simulate -- 200  # 6 bots jouent 200 mains entre eux
```

Application (Flutter 3.47 ou plus récent) :

```sh
cd app
flutter test                                  # tests du moteur Dart
flutter run                                   # sur un téléphone ou un simulateur
flutter build web --no-web-resources-cdn      # version web pour essayer dans un navigateur
```
