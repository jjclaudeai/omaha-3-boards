import 'package:flutter/material.dart';

import '../engine/cards.dart';
import '../state/catalog.dart';
import '../state/profile_scope.dart';
import 'app_shell.dart';
import 'card_widget.dart';
import 'rooms_screen.dart';
import 'theme.dart';
import 'widgets/common.dart';
import 'widgets/reward_dialog.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: const [
        _PlayCard(),
        SizedBox(height: 14),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _DailyBonusCard()),
            SizedBox(width: 12),
            Expanded(child: _LeagueCard()),
          ],
        ),
        SizedBox(height: 14),
        _MissionsCard(),
        SizedBox(height: 14),
        _ShopTeaser(),
      ],
    );
  }
}

/// La carte « Jouer » : le tapis, une main de 6 cartes, et la salle conseillée.
class _PlayCard extends StatelessWidget {
  const _PlayCard();

  static final _fan = parseCards('As Ah Kd Qd Jc Ts');

  @override
  Widget build(BuildContext context) {
    final p = ProfileScope.of(context);
    final room = recommendedRoom(p);
    return Panel(
      padding: EdgeInsets.zero,
      gradient: const RadialGradient(
        colors: [Color(0xFF2E9A63), Palette.feltDark],
        center: Alignment(0.4, -0.4),
        radius: 1.2,
      ),
      borderColor: const Color(0xFF3FB97A),
      child: Stack(
        children: [
          // Éventail de 6 cartes, la signature de l'Omaha 6 cartes.
          Positioned(
            right: 4,
            top: 10,
            child: SizedBox(
              width: 140,
              height: 100,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  for (var i = 0; i < 6; i++)
                    Positioned(
                      left: 14.0 + i * 15,
                      top: 16,
                      child: Transform.rotate(
                        angle: (i - 2.5) * 0.12,
                        alignment: Alignment.bottomCenter,
                        child: PlayingCard(card: _fan[i], width: 38),
                      ),
                    ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(20)),
                  child: Text('OMAHA 6 CARTES', style: body(11.5, color: Palette.gold, weight: FontWeight.w800).copyWith(letterSpacing: 1.2)),
                ),
                const SizedBox(height: 8),
                Text('3 boards,\n1 pot en trois', style: display(27)),
                const SizedBox(height: 6),
                Text('Salle ${room.name} · cave ${formatCoins(room.buyIn)}', style: body(14, color: const Color(0xFFCDEBD9))),
                const SizedBox(height: 16),
                ChunkyButton(
                  label: 'Jouer maintenant',
                  icon: Icons.play_arrow_rounded,
                  height: 58,
                  fontSize: 22,
                  onTap: () => openRoom(context, room),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DailyBonusCard extends StatelessWidget {
  const _DailyBonusCard();

  @override
  Widget build(BuildContext context) {
    final p = ProfileScope.of(context);
    final day = p.bonusDay;
    final available = p.bonusAvailable;
    return Panel(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Bonus du jour', style: display(17)),
          const SizedBox(height: 2),
          Text('Jour $day sur 7', style: body(12.5, color: Palette.textLo)),
          const SizedBox(height: 10),
          // 7 pastilles : les jours déjà pris, celui du jour, les suivants.
          Row(
            children: [
              for (var d = 1; d <= 7; d++)
                Expanded(
                  child: Container(
                    height: 8,
                    margin: EdgeInsets.only(right: d < 7 ? 3 : 0),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(4),
                      color: d < day || (d == day && !available)
                          ? Palette.gold
                          : d == day
                              ? Palette.gold.withValues(alpha: 0.45)
                              : Colors.black38,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const CoinIcon(size: 20),
              const SizedBox(width: 6),
              Text(formatCoins(dailyRewards[day - 1]), style: display(20, color: Palette.gold)),
            ],
          ),
          const SizedBox(height: 10),
          ChunkyButton(
            label: available ? 'Récupérer' : 'Demain',
            height: 42,
            fontSize: 17,
            enabled: available,
            color: Palette.mint,
            shade: const Color(0xFF1F9A5F),
            textColor: const Color(0xFF06301B),
            onTap: () {
              final won = p.claimDailyBonus();
              if (won > 0) showReward(context, title: 'Bonus du jour', subtitle: 'Jour $day sur 7', coins: won);
            },
          ),
        ],
      ),
    );
  }
}

class _LeagueCard extends StatelessWidget {
  const _LeagueCard();

  @override
  Widget build(BuildContext context) {
    final p = ProfileScope.of(context);
    final next = p.nextLeague;
    return Pressable(
      onTap: () => AppShellState.of(context).goTo(2),
      child: Panel(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                LeagueBadge(league: p.league, size: 40),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(p.league.name, style: display(17), overflow: TextOverflow.ellipsis),
                      Text('${p.weeklyRank}e cette semaine', style: body(12.5, color: Palette.textLo)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            ProgressBar(value: p.leagueProgress, color: p.league.color, height: 10),
            const SizedBox(height: 6),
            Text(
              next == null ? '${formatCoins(p.leaguePoints)} points' : '${formatCoins(p.leaguePoints)} / ${formatCoins(next.threshold)} pts',
              style: body(12.5),
            ),
            const SizedBox(height: 10),
            Text(next == null ? 'Ligue la plus haute' : 'Prochaine : ${next.name}',
                style: body(12.5, color: next?.color ?? Palette.gold)),
          ],
        ),
      ),
    );
  }
}

class _MissionsCard extends StatelessWidget {
  const _MissionsCard();

  @override
  Widget build(BuildContext context) {
    final p = ProfileScope.of(context);
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Missions du jour', style: display(19)),
              const Spacer(),
              Text('${p.missions.where((m) => m.claimed).length}/${p.missions.length}', style: body(14, color: Palette.textLo)),
            ],
          ),
          const SizedBox(height: 10),
          for (final m in p.missions) ...[
            Row(
              children: [
                Icon(
                  m.claimed ? Icons.check_circle_rounded : Icons.flag_rounded,
                  color: m.claimed ? Palette.mint : Palette.sky,
                  size: 22,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(m.label, style: body(14.5, color: m.claimed ? Palette.textLo : Palette.textHi)),
                      const SizedBox(height: 5),
                      Row(
                        children: [
                          Expanded(child: ProgressBar(value: m.progress / m.goal, color: Palette.sky, height: 7)),
                          const SizedBox(width: 8),
                          Text('${m.progress}/${m.goal}', style: body(12, color: Palette.textLo)),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  width: 92,
                  child: m.claimed
                      ? Center(child: Text('Récupéré', style: body(12.5, color: Palette.textLo)))
                      : ChunkyButton(
                          label: '+${formatCoins(m.reward)}',
                          height: 38,
                          fontSize: 15,
                          enabled: m.done,
                          onTap: () {
                            final won = p.claimMission(m);
                            if (won > 0) showReward(context, title: 'Mission accomplie', subtitle: m.label, coins: won);
                          },
                        ),
                ),
              ],
            ),
            if (m != p.missions.last) const Divider(height: 22, color: Palette.panelLine),
          ],
        ],
      ),
    );
  }
}

class _ShopTeaser extends StatelessWidget {
  const _ShopTeaser();

  @override
  Widget build(BuildContext context) {
    final p = ProfileScope.of(context);
    if (p.welcomeBought) return const SizedBox.shrink();
    return Pressable(
      onTap: () => AppShellState.of(context).goTo(3),
      child: Panel(
        gradient: const LinearGradient(colors: [Color(0xFF6B3FA0), Color(0xFF2B1E5C)]),
        borderColor: const Color(0xFFB98CFF),
        child: Row(
          children: [
            const CoinIcon(size: 46),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Offre de bienvenue', style: display(19)),
                  Text('${formatCoins(welcomeOffer.coins)} pièces + dos de cartes Or royal',
                      style: body(13, color: const Color(0xFFE2D4FF))),
                ],
              ),
            ),
            Text(welcomeOffer.price, style: display(20, color: Palette.gold)),
          ],
        ),
      ),
    );
  }
}
