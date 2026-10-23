import 'package:flutter/material.dart';

import '../state/catalog.dart';
import '../state/profile.dart';
import '../state/profile_scope.dart';
import 'card_widget.dart';
import 'theme.dart';
import 'widgets/common.dart';
import 'widgets/reward_dialog.dart';

class ShopScreen extends StatelessWidget {
  const ShopScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final p = ProfileScope.of(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        Text('Boutique', style: display(30)),
        Text('Les pièces servent à payer la cave des tables. Elles ne s\'échangent jamais contre de l\'argent.',
            style: body(13.5, color: Palette.textLo, weight: FontWeight.w500)),
        const SizedBox(height: 14),
        if (!p.welcomeBought) ...[
          _PackTile(pack: welcomeOffer, highlight: true, subtitle: '+ dos de cartes Or royal'),
          const SizedBox(height: 12),
        ],
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 0.82,
          children: [for (final pack in coinPacks) _PackTile(pack: pack)],
        ),
        const SizedBox(height: 22),
        Text('Dos de cartes', style: display(21)),
        const SizedBox(height: 10),
        _CosmeticRow(items: cardBacks, selected: p.cardBack, preview: (c) => PlayingCard(width: 48, faceUp: false, back: c.colors)),
        const SizedBox(height: 22),
        Text('Tapis', style: display(21)),
        const SizedBox(height: 10),
        _CosmeticRow(
          items: felts,
          selected: p.felt,
          preview: (c) => Container(
            width: 64,
            height: 44,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              gradient: RadialGradient(colors: c.colors),
              border: Border.all(color: const Color(0xFF4E342E), width: 4),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Prototype : les achats sont simulés et aucun paiement n\'est demandé. '
          'Dans l\'application publiée, le paiement passera par l\'App Store ou Google Play.',
          style: body(12, color: Palette.textLo, weight: FontWeight.w500),
        ),
      ],
    );
  }
}

class _PackTile extends StatelessWidget {
  const _PackTile({required this.pack, this.highlight = false, this.subtitle});
  final CoinPack pack;
  final bool highlight;
  final String? subtitle;

  int get _stackSize => switch (pack.coins) { < 20000 => 1, < 60000 => 2, < 150000 => 3, < 500000 => 4, _ => 5 };

  Future<void> _buy(BuildContext context) async {
    final ok = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Palette.nightRaised,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('${formatCoins(pack.coins)} pièces', style: display(26)),
            const SizedBox(height: 4),
            Text('Prix : ${pack.price}', style: body(16, color: Palette.textLo)),
            const SizedBox(height: 10),
            Text(
              'Achat simulé pour le prototype : rien n\'est débité.',
              style: body(13.5, color: Palette.textLo, weight: FontWeight.w500),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 18),
            ChunkyButton(label: 'Confirmer l\'achat', onTap: () => Navigator.pop(context, true)),
          ],
        ),
      ),
    );
    if (ok == true && context.mounted) {
      ProfileScope.read(context).purchasePack(pack);
      showReward(context, title: 'Merci !', subtitle: pack.price, coins: pack.coins);
    }
  }

  @override
  Widget build(BuildContext context) {
    final content = Column(
      children: [
        if (pack.tag != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
            decoration: BoxDecoration(color: Palette.ruby, borderRadius: BorderRadius.circular(10)),
            child: Text(pack.tag!.toUpperCase(), style: body(10.5, weight: FontWeight.w800).copyWith(letterSpacing: 0.8)),
          )
        else
          const SizedBox(height: 18),
        const Spacer(),
        // Pile de pièces : plus le pack est gros, plus la pile est haute.
        SizedBox(
          height: 58,
          width: 80,
          child: Stack(
            alignment: Alignment.bottomCenter,
            children: [
              for (var i = 0; i < _stackSize; i++)
                Positioned(
                  bottom: i * 7.0,
                  left: 10 + (i.isEven ? 0 : 6.0) + (i == 4 ? -12 : 0),
                  child: const CoinIcon(size: 40),
                ),
            ],
          ),
        ),
        const Spacer(),
        Text(formatCoins(pack.coins), style: display(24)),
        if (pack.bonusPercent > 0)
          Text('+${pack.bonusPercent} % offerts', style: body(12.5, color: Palette.mint))
        else
          Text(subtitle ?? 'pièces', style: body(12.5, color: Palette.textLo)),
        const SizedBox(height: 10),
        ChunkyButton(label: pack.price, height: 42, fontSize: 18, onTap: () => _buy(context)),
      ],
    );
    return Panel(
      padding: const EdgeInsets.all(12),
      gradient: highlight ? const LinearGradient(colors: [Color(0xFF6B3FA0), Color(0xFF2B1E5C)]) : null,
      borderColor: highlight ? const Color(0xFFB98CFF) : null,
      child: highlight
          ? Row(
              children: [
                const CoinIcon(size: 54),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Offre de bienvenue', style: display(20)),
                      Text('${formatCoins(pack.coins)} pièces ${subtitle ?? ''}', style: body(13, color: const Color(0xFFE2D4FF))),
                    ],
                  ),
                ),
                SizedBox(width: 92, child: ChunkyButton(label: pack.price, height: 44, fontSize: 18, onTap: () => _buy(context))),
              ],
            )
          : content,
    );
  }
}

class _CosmeticRow extends StatelessWidget {
  const _CosmeticRow({required this.items, required this.selected, required this.preview});
  final List<Cosmetic> items;
  final String selected;
  final Widget Function(Cosmetic) preview;

  @override
  Widget build(BuildContext context) {
    final p = ProfileScope.of(context);
    return SizedBox(
      height: 150,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (context, i) => const SizedBox(width: 10),
        itemBuilder: (context, i) {
          final c = items[i];
          final own = p.owned.contains(c.id);
          final on = selected == c.id;
          return SizedBox(
            width: 112,
            child: Panel(
              padding: const EdgeInsets.all(10),
              borderColor: on ? Palette.gold : null,
              child: Column(
                children: [
                  SizedBox(height: 70, child: Center(child: preview(c))),
                  const SizedBox(height: 4),
                  Text(c.name, style: body(12.5), maxLines: 1, overflow: TextOverflow.ellipsis),
                  const Spacer(),
                  SizedBox(
                    height: 30,
                    child: on
                        ? Center(child: Text('Équipé', style: body(12.5, color: Palette.gold)))
                        : own
                            ? _SmallButton(label: 'Équiper', onTap: () => p.equip(c))
                            : _SmallButton(
                                label: formatCoins(c.price),
                                coin: true,
                                onTap: () => _buyCosmetic(context, p, c),
                              ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _buyCosmetic(BuildContext context, PlayerProfile p, Cosmetic c) {
    if (p.buyCosmetic(c)) {
      p.equip(c);
      toast(context, '${c.name} débloqué et équipé');
    } else {
      toast(context, 'Il vous manque ${formatCoins(c.price - p.coins)} pièces');
    }
  }
}

class _SmallButton extends StatelessWidget {
  const _SmallButton({required this.label, required this.onTap, this.coin = false});
  final String label;
  final VoidCallback onTap;
  final bool coin;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(color: Palette.panelLine, borderRadius: BorderRadius.circular(10)),
        alignment: Alignment.center,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (coin) ...[const CoinIcon(size: 14), const SizedBox(width: 4)],
            Text(label, style: body(12.5, weight: FontWeight.w800)),
          ],
        ),
      ),
    );
  }
}
