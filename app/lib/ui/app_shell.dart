import 'package:flutter/material.dart';

import '../state/profile_scope.dart';
import 'account_screen.dart';
import 'home_screen.dart';
import 'league_screen.dart';
import 'rooms_screen.dart';
import 'shop_screen.dart';
import 'theme.dart';
import 'widgets/common.dart';

/// L'application hors table : 4 onglets en bas, l'en-tête avec le solde en haut.
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => AppShellState();
}

class AppShellState extends State<AppShell> {
  int tab = 0;

  void goTo(int index) => setState(() => tab = index);

  static AppShellState of(BuildContext context) => context.findAncestorStateOfType<AppShellState>()!;

  @override
  Widget build(BuildContext context) {
    final pages = const [HomeScreen(), RoomsScreen(), LeagueScreen(), ShopScreen()];
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF14284A), Palette.night, Color(0xFF0A111D)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            stops: [0, 0.45, 1],
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              const _Header(),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  transitionBuilder: (child, a) => FadeTransition(
                    opacity: a,
                    child: SlideTransition(
                      position: Tween(begin: const Offset(0, 0.02), end: Offset.zero).animate(a),
                      child: child,
                    ),
                  ),
                  child: KeyedSubtree(key: ValueKey(tab), child: pages[tab]),
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _BottomNav(index: tab, onTap: goTo),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    final p = ProfileScope.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
      child: Row(
        children: [
          Pressable(onTap: () => openAccount(context), child: const MyAvatar(size: 44, showProgress: true)),
          const SizedBox(width: 10),
          Expanded(
            child: Pressable(
              onTap: () => openAccount(context),
              child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(p.name, style: display(19), overflow: TextOverflow.ellipsis),
                Text('Niveau ${p.level} · ligue ${p.league.name}${p.isVip ? ' · VIP' : ''}', style: body(12.5, color: Palette.textLo)),
              ],
            ),
            ),
          ),
          CoinPill(amount: p.coins, onAdd: () => AppShellState.of(context).goTo(3)),
        ],
      ),
    );
  }
}

class _BottomNav extends StatelessWidget {
  const _BottomNav({required this.index, required this.onTap});
  final int index;
  final ValueChanged<int> onTap;

  static const _items = [
    (Icons.home_rounded, 'Accueil'),
    (Icons.style_rounded, 'Salles'),
    (Icons.emoji_events_rounded, 'Ligue'),
    (Icons.storefront_rounded, 'Boutique'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF0A1322),
        border: Border(top: BorderSide(color: Palette.panelLine)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Row(
            children: [
              for (var i = 0; i < _items.length; i++)
                Expanded(
                  child: Pressable(
                    onTap: () => onTap(i),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
                          decoration: BoxDecoration(
                            color: i == index ? Palette.gold.withValues(alpha: 0.16) : Colors.transparent,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(_items[i].$1, color: i == index ? Palette.gold : Palette.textLo, size: 26),
                        ),
                        const SizedBox(height: 2),
                        Text(_items[i].$2,
                            style: body(12, color: i == index ? Palette.gold : Palette.textLo, weight: FontWeight.w800)),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
