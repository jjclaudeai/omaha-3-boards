# Back-office Omaha 3 Boards

Plateforme d'administration du propriétaire : une page web autonome (`index.html`, sans dépendance ni compilation).

## Ce qu'on y fait

- **Tableau de bord** : joueurs actifs, nouveaux inscrits, revenus, pièces en circulation, dernières opérations, meilleurs acheteurs.
- **Joueurs** : recherche par pseudo ou identifiant, filtres (actifs, payeurs, VIP, bannis, nouveaux), tri, fiche complète
  (profil « Mon compte », statistiques, cosmétiques, journal), ajustement de pièces avec motif, renommage, VIP offert,
  retrait de photo ou de bio, bannissement avec confirmation.
- **Économie** : sources et dépenses de pièces (bonus, coffres, missions, table, commission, boutique…), ventes par pack, journal filtrable.
- **Ligues et classement** : seuils, multiplicateurs, barème des primes par rang, clôture de la semaine, classement général et par ligue.
- **Salles et blindes** : blindes, cave, niveau requis, multiplicateur de points, commission, contrôles de cohérence.
- **Boutique** : packs de pièces, offre de bienvenue, pass VIP, thèmes, dos de cartes, avatars et cadres, contrôles de prix.
- **Réglages** : pièces de départ, bonus quotidien, coffres, passage de niveau, coup de pouce, missions, annonce sur l'accueil, JSON publié.

Les réglages du jeu se modifient en brouillon puis se publient en une version numérotée de la **config distante**
(`config.example.json`), que l'app chargera au démarrage. Sa forme suit `app/lib/state/catalog.dart`.

## État actuel

Il n'y a pas encore de serveur ni de comptes joueurs : la page tourne sur **260 joueurs de démonstration** générés au
chargement et garde les modifications dans le navigateur (bouton « Régénérer la démo » pour repartir de zéro).
Le contrat d'API à brancher est décrit dans [`API.md`](API.md).

## Lancer

Ouvrir `admin/index.html` dans un navigateur, ou :

```sh
cd admin && python3 -m http.server 8080   # puis http://localhost:8080
```
