import 'dart:async';

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
    final p = ProfileScope.of(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        if (p.pendingWeeklyReward != null) ...[const _WeeklyRewardCard(), const SizedBox(height: 14)],
        if (p.rescueAvailable) ...[const _RescueCard(), const SizedBox(height: 14)],
        const _PlayCard(),
        const SizedBox(height: 14),
        const Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _DailyBonusCard()),
            SizedBox(width: 12),
            Expanded(child: _LeagueCard()),
          ],
        ),
        const SizedBox(height: 14),
        const _ChestCard(),
        const SizedBox(height: 14),
        const _MissionsCard(),
        const SizedBox(height: 14),
        const _ShopTeaser(),
      ],
    );
  }
}

/// Gains de la semaine de ligue écoulée, à récupérer.
class _WeeklyRewardCard extends StatelessWidget {
  const _WeeklyRewardCard();

  @override
  Widget build(BuildContext context) {
    final p = ProfileScope.of(context);
    final r = p.pendingWeeklyReward!;
    return Panel(
      gradient: const LinearGradient(colors: [Color(0xFF8C5E12), Color(0xFF3A2400)], begin: Alignment.topLeft, end: Alignment.bottomRight),
      borderColor: Palette.gold,
      child: Row(
        children: [
          const Icon(Icons.emoji_events_rounded, color: Palette.gold, size: 46),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${r.rank}${r.rank == 1 ? 'er' : 'e'} de la ligue ${r.league} !', style: display(19)),
                Text('Tes gains de la semaine passée', style: body(13, color: const Color(0xFFFFE7B0))),
              ],
            ),
          ),
          SizedBox(
            width: 110,
            child: ChunkyButton(
              label: '+${formatCoins(r.coins)}',
              height: 44,
              fontSize: 17,
              onTap: () {
                final won = p.claimWeeklyReward();
                if (won > 0) showReward(context, title: 'Gains de ligue', subtitle: '${r.rank}e en ${r.league}', coins: won);
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Plus assez de pièces pour une cave : un coup de pouce gratuit, ou la boutique.
class _RescueCard extends StatelessWidget {
  const _RescueCard();

  @override
  Widget build(BuildContext context) {
    final p = ProfileScope.of(context);
    return Panel(
      borderColor: Palette.sky,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Plus assez de pièces ?', style: display(19)),
          Text('On t\'offre de quoi retourner à la table.', style: body(13, color: Palette.textLo)),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: ChunkyButton(
                  label: 'Coup de pouce +${formatCoins(rescueCoins)}',
                  height: 44,
                  fontSize: 16,
                  color: Palette.sky,
                  shade: const Color(0xFF2F6FB8),
                  textColor: Palette.night,
                  onTap: () {
                    final won = p.claimRescue();
                    if (won > 0) showReward(context, title: 'Coup de pouce', subtitle: 'Bonne chance à la table !', coins: won);
                  },
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 100,
                child: ChunkyButton(label: 'Boutique', height: 44, fontSize: 16, onTap: () => AppShellState.of(context).goTo(3)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Coffre gratuit toutes les 4 heures, avec compte à rebours.
class _ChestCard extends StatefulWidget {
  const _ChestCard();

  @override
  State<_ChestCard> createState() => _ChestCardState();
}

class _ChestCardState extends State<_ChestCard> {
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = ProfileScope.of(context);
    final wait = p.chestWait;
    final ready = wait == Duration.zero;
    String two(int n) => n.toString().padLeft(2, '0');
    return Panel(
      padding: const EdgeInsets.all(14),
      gradient: ready ? const LinearGradient(colors: [Color(0xFF7A4A12), Palette.panel], begin: Alignment.centerLeft, end: Alignment.centerRight) : null,
      borderColor: ready ? Palette.gold : null,
      child: Row(
        children: [
          AnimatedScale(
            scale: ready ? 1.1 : 1,
            duration: const Duration(milliseconds: 400),
            child: Icon(ready ? Icons.redeem_rounded : Icons.lock_clock_rounded, color: ready ? Palette.gold : Palette.textLo, size: 42),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Coffre gratuit', style: display(18)),
                Text(
                  ready
                      ? '${formatCoins(freeChestMin)} à ${formatCoins(freeChestMax)} pièces'
                      : 'Prêt dans ${wait.inHours} h ${two(wait.inMinutes % 60)} min ${two(wait.inSeconds % 60)} s',
                  style: body(12.5, color: Palette.textLo),
                ),
                if (!p.isVip) Text('2 fois plus souvent en VIP', style: body(11.5, color: const Color(0xFFB98CFF))),
              ],
            ),
          ),
          SizedBox(
            width: 96,
            child: ChunkyButton(
              label: ready ? 'Ouvrir' : 'Bientôt',
              height: 42,
              fontSize: 17,
              enabled: ready,
              onTap: () {
                final won = p.openChest();
                if (won > 0) showReward(context, title: 'Coffre ouvert', subtitle: 'Prochain dans ${p.chestInterval.inHours} h', coins: won);
              },
            ),
          ),
        ],
      ),
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
                Text('3 boards,\n1 pot à rafler', style: display(27)),
                const SizedBox(height: 6),
                // Choix des blindes directement depuis l'accueil.
                Pressable(
                  onTap: () async {
                    final r = await pickRoom(context, current: room);
                    if (r != null && context.mounted) await playRoom(context, r);
                  },
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(12, 6, 8, 6),
                    decoration: BoxDecoration(
                      color: Colors.black26,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0x55CDEBD9)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('${room.name} · blindes ${formatCoins(room.smallBlind)}/${formatCoins(room.bigBlind)}',
                            style: body(14, color: const Color(0xFFCDEBD9))),
                        const Icon(Icons.expand_more_rounded, color: Color(0xFFCDEBD9), size: 20),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                ChunkyButton(
                  label: 'Jouer maintenant',
                  icon: Icons.play_arrow_rounded,
                  height: 58,
                  fontSize: 22,
                  onTap: () => playRoom(context, room),
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
              Text(formatCoins(p.dailyRewardFor(day)), style: display(20, color: Palette.gold)),
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
                  Text('${formatCoins(welcomeOffer.coins)} pièces + dos Or royal et cadre Or',
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
