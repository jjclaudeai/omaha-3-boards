# Contrat d'API du back-office

À implémenter par le serveur de jeu. Toutes les routes sont sous `/admin/v1`, réservées au compte propriétaire
(connexion par e-mail + mot de passe et double authentification ; jeton de session en cookie `HttpOnly`).
Chaque écriture est tracée dans un journal d'audit (qui, quand, quoi, avant/après).

## Config distante

| Méthode | Route | Rôle |
|---|---|---|
| GET | `/config` | Version publiée (forme de `config.example.json`) |
| GET | `/config/draft` | Brouillon en cours |
| PUT | `/config/draft` | Remplace le brouillon |
| POST | `/config/publish` | Publie le brouillon : `version + 1`, `publishedAt` = maintenant |

L'app lit la version publiée sur une route publique `GET /v1/config` (cache 5 min) ; `catalog.dart` reste la valeur de secours hors ligne.

## Joueurs

| Méthode | Route | Rôle |
|---|---|---|
| GET | `/players?q=&filter=actifs\|payeurs\|vip\|bannis\|nouveaux&sort=&page=` | Liste paginée |
| GET | `/players/{id}` | Fiche complète |
| GET | `/players/{id}/transactions?page=` | Journal du joueur |
| POST | `/players/{id}/coins` | `{ amount, reason }` : crédit (> 0) ou débit (< 0), journalisé en `admin` |
| PATCH | `/players/{id}` | `{ name?, bio?, avatarUrl?: null, vipUntil? }` (modération) |
| POST | `/players/{id}/ban` | `{ reason }` |
| DELETE | `/players/{id}/ban` | Lève le bannissement |

Joueur : `id, name, avatarId, avatarUrl, frame, theme, cardBack, bio, country, city, birthDate, email, platform,
createdAt, lastSeenAt, vipUntil, coins, xp, leaguePoints, weeklyPoints, handsPlayed, boardsWon, potsWon, scoops,
biggestWin, owned ("kind:id"), welcomeBought, banned, banReason`.

## Économie

| Méthode | Route | Rôle |
|---|---|---|
| GET | `/stats/daily?days=30` | `[{ day, activePlayers, newPlayers, revenueCents, hands }]` |
| GET | `/stats/flows?days=30` | Somme des pièces par type de transaction, entrées et sorties |
| GET | `/transactions?kind=&page=` | Journal global |

Transaction : `{ id, playerId, kind, amount, at, note?, pack?, priceCents?, store? }` avec
`kind` ∈ `purchase, bonus, chest, levelup, rescue, mission, table, rake, league, shop, admin`.
Les achats ne sont crédités qu'après vérification du reçu App Store / Google Play par le serveur.

## Ligues

| Méthode | Route | Rôle |
|---|---|---|
| GET | `/leagues/ranking?league=&period=week\|all&page=` | Classement |
| GET | `/leagues/week/preview` | Primes qui seraient versées maintenant |
| POST | `/leagues/week/close` | Verse les primes et remet `weeklyPoints` à 0 (aussi lancé chaque lundi à 0 h, heure de Paris) |

Prime = barème `leagueRankRewards` selon le rang dans la ligue × `rewardScale` de la ligue.
