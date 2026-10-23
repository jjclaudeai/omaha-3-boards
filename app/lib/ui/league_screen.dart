import 'package:flutter/material.dart';

import '../state/catalog.dart';
import '../state/profile.dart';
import '../state/profile_scope.dart';
import '../state/rankings.dart';
import 'theme.dart';
import 'widgets/common.dart';

/// Ligue et classements : la ligue de la semaine (qui rapporte des pièces), le général et les fortunes.
class LeagueScreen extends StatefulWidget {
  const LeagueScreen({super.key});

  @override
  State<LeagueScreen> createState() => _LeagueScreenState();
}

class _LeagueScreenState extends State<LeagueScreen> {
  int board = 0;

  @override
  Widget build(BuildContext context) {
    final p = ProfileScope.of(context);
    final List<RankEntry> ranking;
    final String unit;
    switch (board) {
      case 0:
        ranking = p.weeklyRanking();
        unit = 'pts';
      case 1:
        ranking = p.globalRanking();
        unit = 'pts';
      default:
        ranking = p.fortuneRanking();
        unit = '';
    }
    final me = ranking.firstWhere((e) => e.me);
    final podium = ranking.take(3).toList();
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        Text('Ligue', style: display(30)),
        const SizedBox(height: 10),
        _LeagueHeader(profile: p),
        const SizedBox(height: 12),
        _RewardsTable(profile: p),
        const SizedBox(height: 18),
        Text('Classements', style: display(22)),
        const SizedBox(height: 8),
        _Tabs(
          labels: const ['Ma ligue', 'Général', 'Fortune'],
          index: board,
          onTap: (i) => setState(() => board = i),
        ),
        const SizedBox(height: 6),
        Text(
          switch (board) {
            0 => 'Les 30 joueurs de ta ligue cette semaine. Fin dans ${_left(p.timeLeftInWeek)}.',
            1 => 'Points de ligue de toujours, sur ${formatCoins(SimulatedPlayers.population)} joueurs.',
            _ => 'Les plus grosses fortunes en pièces.',
          },
          style: body(12.5, color: Palette.textLo, weight: FontWeight.w500),
        ),
        const SizedBox(height: 12),
        _Podium(entries: podium, unit: unit),
        const SizedBox(height: 12),
        // Ta place, toujours visible même loin dans le classement.
        _RankRow(entry: me, unit: unit, reward: board == 0 ? p.league.rewardForRank(me.rank) : 0),
        const Divider(color: Palette.panelLine, height: 20),
        for (final e in ranking.skip(3))
          if (!e.me) _RankRow(entry: e, unit: unit, reward: board == 0 ? p.league.rewardForRank(e.rank) : 0),
        const SizedBox(height: 10),
        Text(
          'Prototype : les autres joueurs sont simulés. Avec le serveur, ce seront les vrais inscrits.',
          style: body(11.5, color: Palette.textLo, weight: FontWeight.w500),
        ),
      ],
    );
  }

  static String _left(Duration d) => '${d.inDays} j ${d.inHours % 24} h';
}

class _LeagueHeader extends StatelessWidget {
  const _LeagueHeader({required this.profile});
  final PlayerProfile profile;

  @override
  Widget build(BuildContext context) {
    final p = profile;
    final next = p.nextLeague;
    return Panel(
      gradient: LinearGradient(
        colors: [Color.lerp(p.league.color, Palette.panel, 0.65)!, Palette.panel],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ),
      borderColor: p.league.color.withValues(alpha: 0.6),
      child: Column(
        children: [
          Row(
            children: [
              LeagueBadge(league: p.league, size: 64),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Ligue ${p.league.name}', style: display(24)),
                    Text('${formatCoins(p.leaguePoints)} points · ${p.weeklyRank}e cette semaine', style: body(13.5, color: Palette.textLo)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ProgressBar(value: p.leagueProgress, color: p.league.color, height: 12),
          const SizedBox(height: 6),
          Text(
            next == null
                ? 'Vous êtes au sommet'
                : 'Encore ${formatCoins(next.threshold - p.leaguePoints)} points pour la ligue ${next.name} (gains ×${next.rewardScale})',
            style: body(13),
          ),
          const SizedBox(height: 12),
          // L'échelle des 6 ligues.
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (var i = 0; i < leagues.length; i++)
                Column(
                  children: [
                    AnimatedScale(
                      scale: i == p.leagueIndex ? 1.15 : 1,
                      duration: const Duration(milliseconds: 300),
                      child: LeagueBadge(league: leagues[i], size: 34, locked: i > p.leagueIndex),
                    ),
                    const SizedBox(height: 4),
                    Text(leagues[i].name,
                        style: body(10.5, color: i == p.leagueIndex ? leagues[i].color : Palette.textLo, weight: FontWeight.w800)),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Chaque board gagné rapporte 10 points et chaque pot remporté 20, multipliés par la salle.',
            style: body(12.5, color: Palette.textLo, weight: FontWeight.w500),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

/// Ce que rapporte chaque place en fin de semaine, dans la ligue actuelle.
class _RewardsTable extends StatelessWidget {
  const _RewardsTable({required this.profile});
  final PlayerProfile profile;

  @override
  Widget build(BuildContext context) {
    final l = profile.league;
    final rows = [('1er', l.rewardForRank(1)), ('2e', l.rewardForRank(2)), ('3e', l.rewardForRank(3)), ('4e à 10e', l.rewardForRank(4)), ('11e à 20e', l.rewardForRank(11))];
    return Panel(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.emoji_events_rounded, color: Palette.gold, size: 22),
              const SizedBox(width: 6),
              Text('Gains de fin de semaine', style: display(18)),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final (place, coins) in rows)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(12)),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('$place  ', style: body(12.5, color: Palette.textLo)),
                      const CoinIcon(size: 14),
                      const SizedBox(width: 4),
                      Text(formatCoins(coins), style: display(15, color: Palette.gold)),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text('Les pièces sont créditées lundi, à récupérer sur l\'accueil.',
              style: body(12, color: Palette.textLo, weight: FontWeight.w500)),
        ],
      ),
    );
  }
}

class _Tabs extends StatelessWidget {
  const _Tabs({required this.labels, required this.index, required this.onTap});
  final List<String> labels;
  final int index;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(16)),
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++)
            Expanded(
              child: Pressable(
                onTap: () => onTap(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  height: 38,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: i == index ? Palette.panel : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    border: i == index ? Border.all(color: Palette.gold.withValues(alpha: 0.6)) : null,
                  ),
                  child: Text(labels[i], style: body(13.5, color: i == index ? Palette.gold : Palette.textLo, weight: FontWeight.w800)),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

const _medals = [Palette.gold, Color(0xFFC3CCD8), Color(0xFFCD7F4A)];

class _Podium extends StatelessWidget {
  const _Podium({required this.entries, required this.unit});
  final List<RankEntry> entries;
  final String unit;

  @override
  Widget build(BuildContext context) {
    if (entries.length < 3) return const SizedBox.shrink();
    // 2e à gauche, 1er au centre et plus haut, 3e à droite.
    Widget step(RankEntry e, double height) {
      final color = _medals[e.rank - 1];
      return Expanded(
        child: Pressable(
          onTap: () => showPlayerCard(context, e),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (e.rank == 1) const Icon(Icons.emoji_events_rounded, color: Palette.gold, size: 26),
              e.me
                  ? MyAvatar(size: e.rank == 1 ? 54 : 44, showLevel: false)
                  : Avatar(name: e.name, size: e.rank == 1 ? 54 : 44, avatarId: e.avatarId, frame: e.frame),
              const SizedBox(height: 4),
              Text(e.me ? 'Vous' : e.name, style: body(13), maxLines: 1, overflow: TextOverflow.ellipsis),
              Text('${formatCoins(e.points)} $unit', style: body(12, color: color)),
              const SizedBox(height: 4),
              Container(
                height: height,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [color.withValues(alpha: 0.55), color.withValues(alpha: 0.12)], begin: Alignment.topCenter, end: Alignment.bottomCenter),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                ),
                alignment: Alignment.center,
                child: Text('${e.rank}', style: display(26)),
              ),
            ],
          ),
        ),
      );
    }

    return SizedBox(
      height: 200,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [step(entries[1], 56), const SizedBox(width: 8), step(entries[0], 78), const SizedBox(width: 8), step(entries[2], 42)],
      ),
    );
  }
}

class _RankRow extends StatelessWidget {
  const _RankRow({required this.entry, required this.unit, this.reward = 0});
  final RankEntry entry;
  final String unit;
  final int reward;

  @override
  Widget build(BuildContext context) {
    final e = entry;
    final p = ProfileScope.of(context);
    return Pressable(
      onTap: () => showPlayerCard(context, e),
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: e.me ? Palette.gold.withValues(alpha: 0.14) : Colors.black.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
          border: e.me ? Border.all(color: Palette.gold.withValues(alpha: 0.6)) : null,
        ),
        child: Row(
          children: [
            SizedBox(
              width: 44,
              child: e.rank <= 3
                  ? Icon(Icons.workspace_premium_rounded, color: _medals[e.rank - 1], size: 22)
                  : Text(formatCoins(e.rank), style: display(e.rank > 999 ? 13 : 16, color: Palette.textLo), textAlign: TextAlign.center),
            ),
            const SizedBox(width: 4),
            e.me
                ? Avatar(name: p.name, size: 30, avatarId: p.avatarId, photo: p.photo, frame: p.frame)
                : Avatar(name: e.name, size: 30, avatarId: e.avatarId, frame: e.frame),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(e.me ? '${e.name} (vous)' : e.name, style: body(14), maxLines: 1, overflow: TextOverflow.ellipsis),
                  Text('Niv. ${e.level} · ${e.country}', style: body(11, color: Palette.textLo)),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (unit.isEmpty) ...[const CoinIcon(size: 13), const SizedBox(width: 3)],
                    Text(formatCoins(e.points), style: display(15.5, color: e.me ? Palette.gold : Palette.textHi)),
                    if (unit.isNotEmpty) Text(' $unit', style: body(11.5, color: Palette.textLo)),
                  ],
                ),
                if (reward > 0)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('gain ', style: body(10.5, color: Palette.textLo)),
                      const CoinIcon(size: 11),
                      Text(' ${formatCoins(reward)}', style: body(11, color: Palette.mint)),
                    ],
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Fiche d'un joueur du classement.
void showPlayerCard(BuildContext context, RankEntry e) {
  final p = ProfileScope.read(context);
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: Palette.panel,
    showDragHandle: true,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (context) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            e.me
                ? Avatar(name: p.name, size: 84, avatarId: p.avatarId, photo: p.photo, frame: p.frame, level: p.level)
                : Avatar(name: e.name, size: 84, avatarId: e.avatarId, frame: e.frame, level: e.level),
            const SizedBox(height: 10),
            Text(e.me ? p.name : e.name, style: display(24)),
            Text(e.me && p.bio.isNotEmpty ? p.bio : 'Pays : ${e.country}', style: body(13.5, color: Palette.textLo), textAlign: TextAlign.center),
            const SizedBox(height: 14),
            Row(
              children: [
                _Fact(label: 'Classement', value: '${formatCoins(e.rank)}e'),
                _Fact(label: 'Niveau', value: '${e.level}'),
                _Fact(label: 'Score', value: formatCoins(e.points)),
              ],
            ),
            if (!e.me) ...[
              const SizedBox(height: 16),
              ChunkyButton(
                label: 'Inviter à une table',
                icon: Icons.person_add_alt_1_rounded,
                height: 48,
                fontSize: 18,
                onTap: () {
                  Navigator.pop(context);
                  toast(context, 'Les tables entre amis arrivent avec le multijoueur en ligne');
                },
              ),
            ],
          ],
        ),
      ),
    ),
  );
}

class _Fact extends StatelessWidget {
  const _Fact({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(value, style: display(20)),
          Text(label, style: body(11.5, color: Palette.textLo)),
        ],
      ),
    );
  }
}
