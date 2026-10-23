import 'package:flutter/material.dart';

import '../state/catalog.dart';
import '../state/profile_scope.dart';
import 'theme.dart';
import 'widgets/common.dart';

class LeagueScreen extends StatelessWidget {
  const LeagueScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final p = ProfileScope.of(context);
    final ranking = p.weeklyRanking();
    final left = p.timeLeftInWeek;
    final next = p.nextLeague;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        Text('Ligue', style: display(30)),
        const SizedBox(height: 10),
        Panel(
          gradient: LinearGradient(
            colors: [Color.lerp(p.league.color, Palette.panel, 0.65)!, Palette.panel],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          borderColor: p.league.color.withValues(alpha: 0.6),
          child: Column(
            children: [
              LeagueBadge(league: p.league, size: 76),
              const SizedBox(height: 8),
              Text('Ligue ${p.league.name}', style: display(26)),
              Text('${formatCoins(p.leaguePoints)} points de ligue', style: body(14, color: Palette.textLo)),
              const SizedBox(height: 14),
              ProgressBar(value: p.leagueProgress, color: p.league.color, height: 12),
              const SizedBox(height: 6),
              Text(
                next == null
                    ? 'Vous êtes au sommet'
                    : 'Encore ${formatCoins(next.threshold - p.leaguePoints)} points pour la ligue ${next.name}',
                style: body(13.5),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        // L'échelle des 6 ligues.
        SizedBox(
          height: 92,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (var i = 0; i < leagues.length; i++)
                Column(
                  children: [
                    AnimatedScale(
                      scale: i == p.leagueIndex ? 1.15 : 1,
                      duration: const Duration(milliseconds: 300),
                      child: LeagueBadge(league: leagues[i], size: 40, locked: i > p.leagueIndex),
                    ),
                    const SizedBox(height: 6),
                    Text(leagues[i].name,
                        style: body(11, color: i == p.leagueIndex ? leagues[i].color : Palette.textLo, weight: FontWeight.w800)),
                  ],
                ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text('Classement de la semaine', style: display(19)),
                  const Spacer(),
                  const Icon(Icons.timer_outlined, size: 16, color: Palette.textLo),
                  const SizedBox(width: 4),
                  Text('${left.inDays} j ${left.inHours % 24} h', style: body(13, color: Palette.textLo)),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Le 1er remporte ${formatCoins(p.league.weeklyReward)} pièces, le 2e et le 3e la moitié. '
                'Chaque board gagné rapporte 10 points et chaque pot remporté 20, multipliés par la salle.',
                style: body(13, color: Palette.textLo, weight: FontWeight.w500),
              ),
              const SizedBox(height: 12),
              for (var i = 0; i < ranking.length; i++)
                if (i < 10 || ranking[i].me) _RankRow(rank: i + 1, name: ranking[i].name, points: ranking[i].points, me: ranking[i].me),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Panel(
          child: Row(
            children: [
              _Stat(label: 'Mains jouées', value: formatCoins(p.handsPlayed)),
              _Stat(label: 'Boards gagnés', value: formatCoins(p.boardsWon)),
              _Stat(label: 'Plus gros gain', value: formatCoins(p.biggestWin)),
            ],
          ),
        ),
      ],
    );
  }
}

class _RankRow extends StatelessWidget {
  const _RankRow({required this.rank, required this.name, required this.points, required this.me});
  final int rank;
  final String name;
  final int points;
  final bool me;

  @override
  Widget build(BuildContext context) {
    final medal = switch (rank) { 1 => Palette.gold, 2 => const Color(0xFFC3CCD8), 3 => const Color(0xFFCD7F4A), _ => null };
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: me ? Palette.gold.withValues(alpha: 0.14) : Colors.black.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: me ? Border.all(color: Palette.gold.withValues(alpha: 0.6)) : null,
      ),
      child: Row(
        children: [
          SizedBox(
            width: 30,
            child: medal != null
                ? Icon(Icons.workspace_premium_rounded, color: medal, size: 22)
                : Text('$rank', style: display(16, color: Palette.textLo), textAlign: TextAlign.center),
          ),
          const SizedBox(width: 8),
          Avatar(name: name, size: 28),
          const SizedBox(width: 8),
          Expanded(child: Text(me ? '$name (vous)' : name, style: body(14.5))),
          Text(formatCoins(points), style: display(16, color: me ? Palette.gold : Palette.textHi)),
          Text(' pts', style: body(12, color: Palette.textLo)),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(value, style: display(20)),
          const SizedBox(height: 2),
          Text(label, style: body(11.5, color: Palette.textLo), textAlign: TextAlign.center),
        ],
      ),
    );
  }
}
