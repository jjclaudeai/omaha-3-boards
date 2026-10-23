import 'package:flutter/material.dart';

import '../state/catalog.dart';
import '../state/profile.dart';
import '../state/profile_scope.dart';
import 'card_widget.dart';
import 'cosmetics.dart';
import 'theme.dart';
import 'widgets/common.dart';
import 'widgets/reward_dialog.dart';

/// Boutique en 4 rayons : pièces et VIP, thèmes de table, dos de cartes, avatars et cadres.
class ShopScreen extends StatefulWidget {
  const ShopScreen({super.key});

  @override
  State<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends State<ShopScreen> {
  int section = 0;

  static const _sections = [
    (Icons.monetization_on_rounded, 'Pièces'),
    (Icons.table_restaurant_rounded, 'Tables'),
    (Icons.style_rounded, 'Cartes'),
    (Icons.face_rounded, 'Avatars'),
  ];

  @override
  Widget build(BuildContext context) {
    final p = ProfileScope.of(context);
    final content = switch (section) {
      0 => _coins(p),
      1 => [_CosmeticGrid(items: themes, columns: 2, aspect: 1.05, preview: (c, w) => ThemePreview(theme: c, width: w))],
      2 => [
          _CosmeticGrid(
            items: cardBacks,
            columns: 3,
            aspect: 0.62,
            preview: (c, w) => PlayingCard(width: w * 0.5, faceUp: false, back: c),
          ),
        ],
      _ => [
          Text('Avatars', style: display(21)),
          Text('Ou mets ta propre photo depuis Mon compte.', style: body(13, color: Palette.textLo, weight: FontWeight.w500)),
          const SizedBox(height: 10),
          _CosmeticGrid(
            items: avatars,
            columns: 3,
            aspect: 0.78,
            preview: (c, w) => Avatar(name: c.name, size: w * 0.55, avatarId: c.id),
          ),
          const SizedBox(height: 20),
          Text('Cadres', style: display(21)),
          Text('Visibles à la table et au classement.', style: body(13, color: Palette.textLo, weight: FontWeight.w500)),
          const SizedBox(height: 10),
          _CosmeticGrid(
            items: frames,
            columns: 3,
            aspect: 0.78,
            preview: (c, w) => Avatar(name: p.name, size: w * 0.5, avatarId: p.avatarId, photo: p.photo, frame: c.id),
          ),
        ],
    };
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        Text('Boutique', style: display(30)),
        const SizedBox(height: 10),
        Row(
          children: [
            for (var i = 0; i < _sections.length; i++) ...[
              if (i > 0) const SizedBox(width: 8),
              Expanded(
                child: Pressable(
                  onTap: () => setState(() => section = i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    height: 58,
                    decoration: BoxDecoration(
                      color: section == i ? Palette.gold : Palette.panel,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: section == i ? Palette.gold : Palette.panelLine),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(_sections[i].$1, size: 22, color: section == i ? Palette.night : Palette.textLo),
                        Text(_sections[i].$2, style: body(12, color: section == i ? Palette.night : Palette.textHi, weight: FontWeight.w800)),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 16),
        ...content,
        const SizedBox(height: 18),
        Text(
          'Les pièces n\'ont aucune valeur en dehors du jeu : elles ne s\'échangent ni contre de l\'argent ni contre des lots. '
          'Prototype : les achats sont simulés, rien n\'est débité. Dans l\'application publiée, le paiement passera par l\'App Store ou Google Play.',
          style: body(11.5, color: Palette.textLo, weight: FontWeight.w500),
        ),
      ],
    );
  }

  List<Widget> _coins(PlayerProfile p) => [
        if (!p.welcomeBought) ...[
          _PackTile(pack: welcomeOffer, highlight: true, subtitle: '+ dos Or royal et cadre Or'),
          const SizedBox(height: 12),
        ],
        const _VipCard(),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 0.82,
          children: [for (final pack in coinPacks) _PackTile(pack: pack)],
        ),
      ];
}

Future<bool> _confirmPurchase(BuildContext context, {required String title, required String price, String? detail}) async {
  final ok = await showModalBottomSheet<bool>(
    context: context,
    backgroundColor: Palette.nightRaised,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (context) => Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(title, style: display(26), textAlign: TextAlign.center),
          const SizedBox(height: 4),
          Text('Prix : $price', style: body(16, color: Palette.textLo)),
          if (detail != null) ...[
            const SizedBox(height: 6),
            Text(detail, style: body(13.5, weight: FontWeight.w500), textAlign: TextAlign.center),
          ],
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
  return ok == true;
}

class _VipCard extends StatelessWidget {
  const _VipCard();

  @override
  Widget build(BuildContext context) {
    final p = ProfileScope.of(context);
    const perks = ['Bonus quotidien doublé', 'Coffre gratuit toutes les 2 h', '+25 % d\'expérience', 'Table, cartes et cadre VIP'];
    return Panel(
      padding: const EdgeInsets.all(16),
      gradient: const LinearGradient(colors: [Color(0xFF3A2A63), Color(0xFF15102A)], begin: Alignment.topLeft, end: Alignment.bottomRight),
      borderColor: const Color(0xFFB98CFF),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.workspace_premium_rounded, color: Color(0xFFE2D4FF), size: 30),
              const SizedBox(width: 8),
              Expanded(child: Text('Pass VIP', style: display(23))),
              if (p.isVip)
                Text('Encore ${p.vipDaysLeft} j', style: body(13, color: const Color(0xFFE2D4FF), weight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 8),
          for (final perk in perks)
            Padding(
              padding: const EdgeInsets.only(bottom: 3),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_rounded, color: Palette.mint, size: 17),
                  const SizedBox(width: 6),
                  Text(perk, style: body(13.5, weight: FontWeight.w600)),
                ],
              ),
            ),
          Row(
            children: [
              const CoinIcon(size: 16),
              const SizedBox(width: 5),
              Text('+ ${formatCoins(vipPass.coins)} pièces tout de suite', style: body(13.5, color: Palette.gold)),
            ],
          ),
          const SizedBox(height: 12),
          ChunkyButton(
            label: p.isVip ? 'Prolonger 30 jours · ${vipPass.price}' : '30 jours · ${vipPass.price}',
            height: 48,
            fontSize: 18,
            color: const Color(0xFFB98CFF),
            shade: const Color(0xFF6B3FA0),
            textColor: const Color(0xFF1A0B3B),
            onTap: () async {
              if (await _confirmPurchase(context, title: 'Pass VIP 30 jours', price: vipPass.price) && context.mounted) {
                ProfileScope.read(context).purchaseVip();
                showReward(context, title: 'Bienvenue au club VIP', subtitle: '30 jours d\'avantages', coins: vipPass.coins);
              }
            },
          ),
        ],
      ),
    );
  }
}

class _PackTile extends StatelessWidget {
  const _PackTile({required this.pack, this.highlight = false, this.subtitle});
  final CoinPack pack;
  final bool highlight;
  final String? subtitle;

  int get _stackSize => switch (pack.coins) { < 50000 => 1, < 100000 => 2, < 300000 => 3, < 1000000 => 4, _ => 5 };

  Future<void> _buy(BuildContext context) async {
    if (await _confirmPurchase(context, title: '${formatCoins(pack.coins)} pièces', price: pack.price, detail: subtitle) &&
        context.mounted) {
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

/// Grille d'objets cosmétiques avec aperçu, prix, verrou de niveau ou bouton Équiper.
class _CosmeticGrid extends StatelessWidget {
  const _CosmeticGrid({required this.items, required this.columns, required this.aspect, required this.preview});
  final List<Cosmetic> items;
  final int columns;
  final double aspect;
  final Widget Function(Cosmetic c, double width) preview;

  @override
  Widget build(BuildContext context) {
    final p = ProfileScope.of(context);
    return LayoutBuilder(builder: (context, box) {
      final tileW = (box.maxWidth - 10 * (columns - 1)) / columns;
      return GridView.count(
        crossAxisCount: columns,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: aspect,
        children: [
          for (final c in items)
            if (!c.vipOnly || p.owns(c)) _tile(context, p, c, tileW),
        ],
      );
    });
  }

  Widget _tile(BuildContext context, PlayerProfile p, Cosmetic c, double w) {
    final own = p.owns(c);
    final on = p.isEquipped(c);
    final lock = p.lockReason(c);
    return Panel(
      padding: const EdgeInsets.all(8),
      borderColor: on ? Palette.gold : null,
      child: Column(
        children: [
          Expanded(
            child: Center(
              child: Opacity(opacity: lock != null ? 0.55 : 1, child: preview(c, w - 16)),
            ),
          ),
          const SizedBox(height: 4),
          Text(c.name, style: body(12.5), maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 4),
          SizedBox(
            height: 30,
            child: on
                ? Center(child: Text('Équipé', style: body(12.5, color: Palette.gold)))
                : own
                    ? _SmallButton(label: 'Équiper', onTap: () => p.equip(c))
                    : lock != null
                        ? _SmallButton(label: lock, icon: Icons.lock_rounded, onTap: () => toast(context, '${c.name} : $lock requis'))
                        : _SmallButton(label: formatCoins(c.price), coin: true, onTap: () => _buy(context, p, c)),
          ),
        ],
      ),
    );
  }

  void _buy(BuildContext context, PlayerProfile p, Cosmetic c) {
    if (p.buyCosmetic(c)) {
      p.equip(c);
      toast(context, '${c.name} débloqué et équipé');
    } else {
      toast(context, 'Il vous manque ${formatCoins(c.price - p.coins)} pièces');
    }
  }
}

class _SmallButton extends StatelessWidget {
  const _SmallButton({required this.label, required this.onTap, this.coin = false, this.icon});
  final String label;
  final VoidCallback onTap;
  final bool coin;
  final IconData? icon;

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
            if (icon != null) ...[Icon(icon, size: 13, color: Palette.textLo), const SizedBox(width: 3)],
            Text(label, style: body(12, weight: FontWeight.w800, color: icon != null ? Palette.textLo : Palette.textHi)),
          ],
        ),
      ),
    );
  }
}
