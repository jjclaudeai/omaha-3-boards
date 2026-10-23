import 'package:flutter/material.dart';

import '../state/catalog.dart';
import '../state/profile.dart';
import '../state/profile_scope.dart';
import 'app_shell.dart';
import 'table_screen.dart';
import 'theme.dart';
import 'widgets/common.dart';
import 'widgets/reward_dialog.dart';

/// Salle conseillée : la plus haute débloquée dont le joueur peut payer 2 caves, sinon Débutant.
Room recommendedRoom(PlayerProfile p) {
  var best = rooms.first;
  for (final r in rooms) {
    if (p.level >= r.minLevel && p.coins >= r.buyIn * 2) best = r;
  }
  return best;
}

/// Ouvre une table si le joueur a le niveau et les pièces, sinon explique ce qui manque.
/// [extraCoins] compte les jetons que le joueur récupérera en quittant sa table.
Future<bool> openRoom(BuildContext context, Room room, {int extraCoins = 0}) async {
  final p = ProfileScope.read(context);
  if (p.level < room.minLevel) {
    toast(context, 'Salle ${room.name} : niveau ${room.minLevel} requis');
    return false;
  }
  if (p.coins + extraCoins < room.buyIn) {
    final goShop = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Palette.panel,
        title: Text('Pas assez de pièces', style: display(22)),
        content: Text(
          'La cave de la salle ${room.name} est de ${formatCoins(room.buyIn)} pièces. '
          'Il vous en manque ${formatCoins(room.buyIn - p.coins - extraCoins)}.',
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
    // Depuis une table il n’y a pas d’onglets : seul l’accueil sait ouvrir la boutique.
    if (goShop == true && context.mounted) context.findAncestorStateOfType<AppShellState>()?.goTo(3);
    return false;
  }
  return true;
}

/// Lance la table de [room] (après les vérifications d'[openRoom]) ; [replace] remplace la table en cours.
Future<void> pushTable(BuildContext context, Room room, {bool replace = false}) {
  final route = PageRouteBuilder<void>(
    transitionDuration: const Duration(milliseconds: 350),
    pageBuilder: (context, a, b) => TableScreen(room: room),
    transitionsBuilder: (context, a, b, child) => FadeTransition(
      opacity: a,
      child: ScaleTransition(scale: Tween(begin: 1.06, end: 1.0).animate(a), child: child),
    ),
  );
  final nav = Navigator.of(context);
  if (replace) return nav.pushReplacement(route);
  // Au retour à l'accueil, on fête les niveaux gagnés pendant la partie.
  return nav.push(route).then((_) {
    if (context.mounted) showLevelUps(context);
  });
}

/// Vérifie puis ouvre la table de [room].
Future<void> playRoom(BuildContext context, Room room) async {
  if (await openRoom(context, room) && context.mounted) await pushTable(context, room);
}

/// Feuille de choix de salle : niveau des blindes, cave et multiplicateur de ligue.
Future<Room?> pickRoom(BuildContext context, {Room? current}) {
  final p = ProfileScope.read(context);
  return showModalBottomSheet<Room>(
    context: context,
    backgroundColor: Palette.panel,
    showDragHandle: true,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (context) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Choisir les blindes', style: display(24)),
            Text('Plus les blindes sont hautes, plus la ligue rapporte.',
                style: body(13.5, color: Palette.textLo, weight: FontWeight.w500)),
            const SizedBox(height: 12),
            for (final r in rooms)
              _RoomRow(
                room: r,
                unlocked: p.level >= r.minLevel,
                selected: r == current,
                onTap: () => Navigator.pop(context, r),
              ),
          ],
        ),
      ),
    ),
  );
}

class _RoomRow extends StatelessWidget {
  const _RoomRow({required this.room, required this.unlocked, required this.selected, required this.onTap});
  final Room room;
  final bool unlocked;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Pressable(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: selected ? room.color.withValues(alpha: 0.18) : Colors.black12,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: selected ? room.color : Palette.panelLine, width: selected ? 2 : 1),
          ),
          child: Row(
            children: [
              Icon(unlocked ? Icons.casino_rounded : Icons.lock_rounded, color: unlocked ? room.color : Palette.textLo, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(room.name, style: display(18, color: unlocked ? Palette.textHi : Palette.textLo)),
                    Text(
                      unlocked
                          ? 'Blindes ${formatCoins(room.smallBlind)} / ${formatCoins(room.bigBlind)} · cave ${formatCoins(room.buyIn)}'
                          : 'Niveau ${room.minLevel} requis',
                      style: body(12.5, color: Palette.textLo),
                    ),
                  ],
                ),
              ),
              Text('×${room.leagueMultiplier}', style: display(18, color: unlocked ? room.color : Palette.textLo)),
            ],
          ),
        ),
      ),
    );
  }
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
      onTap: () => playRoom(context, room),
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
                    onTap: () => playRoom(context, room),
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
