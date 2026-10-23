import 'package:flutter/material.dart';

import '../state/catalog.dart';
import '../state/profile.dart';
import '../state/profile_scope.dart';
import 'app_shell.dart';
import 'table_screen.dart';
import 'theme.dart';
import 'widgets/common.dart';

/// Salle conseillée : la plus haute débloquée dont le joueur peut payer 2 caves, sinon Débutant.
Room recommendedRoom(PlayerProfile p) {
  var best = rooms.first;
  for (final r in rooms) {
    if (p.level >= r.minLevel && p.coins >= r.buyIn * 2) best = r;
  }
  return best;
}

/// Ouvre une table si le joueur a le niveau et les pièces, sinon explique ce qui manque.
Future<void> openRoom(BuildContext context, Room room) async {
  final p = ProfileScope.read(context);
  if (p.level < room.minLevel) {
    toast(context, 'Salle ${room.name} : niveau ${room.minLevel} requis');
    return;
  }
  if (p.coins < room.buyIn) {
    final goShop = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Palette.panel,
        title: Text('Pas assez de pièces', style: display(22)),
        content: Text(
          'La cave de la salle ${room.name} est de ${formatCoins(room.buyIn)} pièces. '
          'Il vous en manque ${formatCoins(room.buyIn - p.coins)}.',
          style: body(15, weight: FontWeight.w500),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text('Plus tard', style: body(15))),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Boutique', style: body(15, color: Palette.gold, weight: FontWeight.w800)),
          ),
        ],
      ),
    );
    if (goShop == true && context.mounted) AppShellState.of(context).goTo(3);
    return;
  }
  await Navigator.of(context).push(PageRouteBuilder(
    transitionDuration: const Duration(milliseconds: 350),
    pageBuilder: (context, a, b) => TableScreen(room: room),
    transitionsBuilder: (context, a, b, child) => FadeTransition(
      opacity: a,
      child: ScaleTransition(scale: Tween(begin: 1.06, end: 1.0).animate(a), child: child),
    ),
  ));
}

class RoomsScreen extends StatelessWidget {
  const RoomsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final p = ProfileScope.of(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        Text('Salles', style: display(30)),
        Text('Plus la salle est haute, plus les boards gagnés rapportent de points de ligue.',
            style: body(14, color: Palette.textLo, weight: FontWeight.w500)),
        const SizedBox(height: 14),
        for (final r in rooms) ...[
          _RoomCard(room: r, unlocked: p.level >= r.minLevel, affordable: p.coins >= r.buyIn),
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}

class _RoomCard extends StatelessWidget {
  const _RoomCard({required this.room, required this.unlocked, required this.affordable});
  final Room room;
  final bool unlocked;
  final bool affordable;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: () => openRoom(context, room),
      child: Panel(
        padding: EdgeInsets.zero,
        gradient: LinearGradient(
          colors: [Color.lerp(room.color, Palette.panel, 0.72)!, Palette.panel],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderColor: unlocked ? room.color.withValues(alpha: 0.5) : Palette.panelLine,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: room.color.withValues(alpha: unlocked ? 0.22 : 0.08),
                  borderRadius: BorderRadius.circular(16),
                ),
                alignment: Alignment.center,
                child: unlocked
                    ? Text('×${room.leagueMultiplier}', style: display(24, color: room.color))
                    : const Icon(Icons.lock_rounded, color: Palette.textLo),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(room.name, style: display(21)),
                    const SizedBox(height: 2),
                    Text('Blindes ${formatCoins(room.smallBlind)} / ${formatCoins(room.bigBlind)}',
                        style: body(13.5, color: Palette.textLo)),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const CoinIcon(size: 15),
                        const SizedBox(width: 5),
                        Text('Cave ${formatCoins(room.buyIn)}', style: body(13.5)),
                      ],
                    ),
                  ],
                ),
              ),
              if (unlocked)
                SizedBox(
                  width: 92,
                  child: ChunkyButton(
                    label: 'Jouer',
                    height: 46,
                    fontSize: 18,
                    color: affordable ? Palette.mint : const Color(0xFF5B6B84),
                    shade: affordable ? const Color(0xFF1F9A5F) : const Color(0xFF3B4659),
                    textColor: affordable ? const Color(0xFF06301B) : Palette.textHi,
                    onTap: () => openRoom(context, room),
                  ),
                )
              else
                Text('Niveau ${room.minLevel}', style: body(13, color: Palette.textLo)),
            ],
          ),
        ),
      ),
    );
  }
}
