import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart' as fc;
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import '../state/catalog.dart';
import '../state/profile.dart';
import '../state/profile_scope.dart';
import 'theme.dart';
import 'widgets/common.dart';

const countries = {
  'FR': 'France',
  'BE': 'Belgique',
  'CH': 'Suisse',
  'LU': 'Luxembourg',
  'MC': 'Monaco',
  'CA': 'Canada',
  'MA': 'Maroc',
  'DZ': 'Algérie',
  'TN': 'Tunisie',
  'SN': 'Sénégal',
  'CI': 'Côte d\'Ivoire',
  'XX': 'Autre pays',
};

const _months = ['janvier', 'février', 'mars', 'avril', 'mai', 'juin', 'juillet', 'août', 'septembre', 'octobre', 'novembre', 'décembre'];
String formatDate(DateTime d) => '${d.day} ${_months[d.month - 1]} ${d.year}';

Future<void> openAccount(BuildContext context) => Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (context) => const AccountScreen()),
    );

/// Mon compte : identité, photo, style, statistiques, amis, autorisations, réglages et suppression du compte.
class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  late final PlayerProfile p = ProfileScope.read(context);
  late final _name = TextEditingController(text: p.name);
  late final _bio = TextEditingController(text: p.bio);
  late final _city = TextEditingController(text: p.city);
  late final _email = TextEditingController(text: p.email);
  late String _country = p.country;
  late DateTime? _birth = p.birthDate;

  @override
  void dispose() {
    for (final c in [_name, _bio, _city, _email]) {
      c.dispose();
    }
    super.dispose();
  }

  bool get _dirty =>
      _name.text.trim() != p.name ||
      _bio.text.trim() != p.bio ||
      _city.text.trim() != p.city ||
      _email.text.trim() != p.email ||
      _country != p.country ||
      _birth != p.birthDate;

  bool get _valid => PlayerProfile.validateName(_name.text) == null && PlayerProfile.validateEmail(_email.text) == null;

  void _save() {
    p.updateAccount(
      name: _name.text,
      bio: _bio.text,
      city: _city.text,
      email: _email.text,
      country: _country,
      birthDate: _birth,
      clearBirthDate: _birth == null,
    );
    FocusScope.of(context).unfocus();
    toast(context, 'Profil enregistré');
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final profile = ProfileScope.of(context);
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
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 4, 16, 0),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      tooltip: 'Retour',
                      icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Palette.textHi, size: 20),
                    ),
                    Text('Mon compte', style: display(24)),
                    const Spacer(),
                    CoinPill(amount: profile.coins),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                  children: [
                    _header(profile),
                    const SizedBox(height: 14),
                    _identity(),
                    const SizedBox(height: 14),
                    _style(profile),
                    const SizedBox(height: 14),
                    _stats(profile),
                    const SizedBox(height: 14),
                    const _FriendsPanel(),
                    const SizedBox(height: 14),
                    const _PermissionsPanel(),
                    const SizedBox(height: 14),
                    _settings(profile),
                    const SizedBox(height: 14),
                    _legal(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header(PlayerProfile profile) {
    return Panel(
      child: Column(
        children: [
          Pressable(
            onTap: () => _photoSheet(context),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                const MyAvatar(size: 96),
                Positioned(
                  right: -2,
                  top: 0,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Palette.gold,
                      shape: BoxShape.circle,
                      border: Border.all(color: Palette.panel, width: 3),
                    ),
                    child: const Icon(Icons.photo_camera_rounded, size: 18, color: Palette.night),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Text(profile.name, style: display(26)),
          if (profile.bio.isNotEmpty)
            Text('« ${profile.bio} »', style: body(13.5, color: Palette.textLo, weight: FontWeight.w600), textAlign: TextAlign.center),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            alignment: WrapAlignment.center,
            children: [
              _Chip(text: 'Niveau ${profile.level}', color: Palette.mint),
              _Chip(text: 'Ligue ${profile.league.name}', color: profile.league.color),
              if (profile.isVip) const _Chip(text: 'VIP', color: Color(0xFFB98CFF)),
              _Chip(text: countries[profile.country] ?? profile.country, color: Palette.sky),
            ],
          ),
          const SizedBox(height: 6),
          Text('Membre depuis le ${formatDate(profile.createdAt)}', style: body(12, color: Palette.textLo)),
        ],
      ),
    );
  }

  Widget _identity() {
    InputDecoration deco(String label, {String? hint, String? error, IconData? icon}) => InputDecoration(
          labelText: label,
          hintText: hint,
          errorText: error,
          prefixIcon: icon == null ? null : Icon(icon, size: 20),
          filled: true,
          fillColor: Colors.black26,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
          counterText: '',
        );
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Profil', style: display(20)),
          const SizedBox(height: 10),
          TextField(
            controller: _name,
            maxLength: PlayerProfile.nameMax,
            decoration: deco('Pseudo', error: _name.text.isEmpty ? null : PlayerProfile.validateName(_name.text), icon: Icons.badge_rounded),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _bio,
            maxLength: 80,
            decoration: deco('Devise', hint: 'Ex. : Toujours à tapis sur 3 boards', icon: Icons.format_quote_rounded),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            initialValue: _country,
            decoration: deco('Pays', icon: Icons.public_rounded),
            dropdownColor: Palette.nightRaised,
            items: [for (final e in countries.entries) DropdownMenuItem(value: e.key, child: Text(e.value))],
            onChanged: (v) => setState(() => _country = v ?? _country),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _city,
            maxLength: 40,
            decoration: deco('Ville', icon: Icons.location_city_rounded),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 10),
          Pressable(
            onTap: _pickBirth,
            child: InputDecorator(
              decoration: deco('Date de naissance', icon: Icons.cake_rounded),
              child: Text(_birth == null ? 'Non renseignée' : formatDate(_birth!), style: body(15)),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            decoration: deco('E-mail', hint: 'Pour récupérer ton compte', error: PlayerProfile.validateEmail(_email.text), icon: Icons.mail_rounded),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 14),
          ChunkyButton(label: 'Enregistrer', height: 48, fontSize: 18, enabled: _dirty && _valid, onTap: _save),
        ],
      ),
    );
  }

  Future<void> _pickBirth() async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: _birth ?? DateTime(now.year - 30),
      firstDate: DateTime(now.year - 100),
      lastDate: DateTime(now.year - 17, now.month, now.day),
      helpText: 'Date de naissance',
    );
    if (d != null) setState(() => _birth = d);
  }

  Widget _style(PlayerProfile profile) {
    final ownedAvatars = avatars.where(profile.owns).toList();
    final ownedFrames = frames.where(profile.owns).toList();
    Widget row(List<Cosmetic> items, Widget Function(Cosmetic) preview) => SizedBox(
          height: 70,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: items.length,
            separatorBuilder: (context, i) => const SizedBox(width: 8),
            itemBuilder: (context, i) {
              final c = items[i];
              final on = profile.isEquipped(c);
              return Pressable(
                onTap: () => profile.equip(c),
                child: Container(
                  width: 64,
                  decoration: BoxDecoration(
                    color: on ? Palette.gold.withValues(alpha: 0.18) : Colors.black26,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: on ? Palette.gold : Colors.transparent, width: 2),
                  ),
                  alignment: Alignment.center,
                  child: preview(c),
                ),
              );
            },
          ),
        );
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Mon style', style: display(20)),
          const SizedBox(height: 4),
          Text('Plus d\'avatars, de cadres et de tables dans la boutique.', style: body(12.5, color: Palette.textLo, weight: FontWeight.w500)),
          const SizedBox(height: 10),
          Text('Avatar', style: body(13, color: Palette.textLo)),
          const SizedBox(height: 6),
          row(ownedAvatars, (c) => Avatar(name: c.name, size: 40, avatarId: c.id)),
          const SizedBox(height: 10),
          Text('Cadre', style: body(13, color: Palette.textLo)),
          const SizedBox(height: 6),
          row(ownedFrames, (c) => Avatar(name: profile.name, size: 38, avatarId: profile.avatarId, photo: profile.photo, frame: c.id)),
        ],
      ),
    );
  }

  Widget _stats(PlayerProfile profile) {
    final boardRate = profile.handsPlayed == 0 ? 0 : (profile.boardsWon * 100 / (profile.handsPlayed * 3)).round();
    final facts = [
      ('Mains jouées', formatCoins(profile.handsPlayed)),
      ('Boards gagnés', formatCoins(profile.boardsWon)),
      ('Pots remportés', formatCoins(profile.potsWon)),
      ('Rafles (3 boards)', formatCoins(profile.scoops)),
      ('Taux de boards gagnés', '$boardRate %'),
      ('Plus gros gain', formatCoins(profile.biggestWin)),
      ('Meilleure ligue', leagues[profile.bestLeagueIndex].name),
      ('Points de ligue', formatCoins(profile.leaguePoints)),
    ];
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Statistiques', style: display(20)),
          const SizedBox(height: 10),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 2.6,
            children: [
              for (final (label, value) in facts)
                Container(
                  decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(value, style: display(19)),
                      Text(label, style: body(11, color: Palette.textLo), maxLines: 1, overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _settings(PlayerProfile profile) {
    Widget toggle(String title, String subtitle, bool value, ValueChanged<bool> onChanged) => SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: value,
          onChanged: onChanged,
          activeThumbColor: Palette.gold,
          title: Text(title, style: body(15)),
          subtitle: Text(subtitle, style: body(12, color: Palette.textLo, weight: FontWeight.w500)),
        );
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Réglages', style: display(20)),
          toggle('Vibrations', 'Petite vibration à chaque action', profile.haptics, (v) => profile.updateSettings(haptics: v)),
          toggle('Abattage rapide', 'Les 3 boards se dévoilent deux fois plus vite', profile.fastReveal,
              (v) => profile.updateSettings(fastReveal: v)),
          toggle('Notifications', 'Bonus du jour, coffre prêt, fin de ligue', profile.notifications,
              (v) => profile.updateSettings(notifications: v)),
        ],
      ),
    );
  }

  Widget _legal() {
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Compte et confidentialité', style: display(20)),
          const SizedBox(height: 6),
          Text(
            'Jeu de poker simulé, sans argent réel, réservé aux 17 ans et plus. Les pièces n\'ont aucune valeur '
            'en dehors du jeu et ne s\'échangent ni contre de l\'argent ni contre des lots. Tes informations restent '
            'sur ton téléphone tant que les comptes en ligne n\'existent pas.',
            style: body(12.5, color: Palette.textLo, weight: FontWeight.w500),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _confirmDelete,
            icon: const Icon(Icons.delete_forever_rounded, color: Palette.ruby),
            label: Text('Supprimer mon compte', style: body(14, color: Palette.ruby)),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Palette.ruby),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              minimumSize: const Size.fromHeight(46),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Palette.panel,
        title: Text('Supprimer le compte ?', style: display(22)),
        content: Text(
          'Pièces, niveau, ligue, objets achetés et photo seront effacés. C\'est définitif.',
          style: body(15, weight: FontWeight.w500),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text('Annuler', style: body(15))),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Supprimer', style: body(15, color: Palette.ruby, weight: FontWeight.w800)),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await p.deleteAccount();
    if (mounted) Navigator.pop(context);
  }
}

/// Choix de la photo de profil : galerie, appareil photo, ou retour à l'avatar dessiné.
Future<void> _photoSheet(BuildContext context) async {
  final p = ProfileScope.read(context);
  final source = await showModalBottomSheet<Object>(
    context: context,
    backgroundColor: Palette.panel,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.photo_library_rounded, color: Palette.gold),
            title: Text('Choisir dans mes photos', style: body(15)),
            onTap: () => Navigator.pop(context, ImageSource.gallery),
          ),
          ListTile(
            leading: const Icon(Icons.photo_camera_rounded, color: Palette.gold),
            title: Text('Prendre une photo', style: body(15)),
            onTap: () => Navigator.pop(context, ImageSource.camera),
          ),
          if (p.photo != null)
            ListTile(
              leading: const Icon(Icons.face_rounded, color: Palette.textLo),
              title: Text('Revenir à mon avatar', style: body(15)),
              onTap: () => Navigator.pop(context, 'remove'),
            ),
        ],
      ),
    ),
  );
  if (source == 'remove') {
    p.setPhoto(null);
    return;
  }
  if (source is! ImageSource) return;
  try {
    // L'app demande l'accès aux photos ou à l'appareil au premier usage, avec le texte d'Info.plist.
    final file = await ImagePicker().pickImage(source: source, maxWidth: 400, maxHeight: 400, imageQuality: 82);
    if (file == null) return;
    p.setPhoto(await file.readAsBytes());
  } catch (_) {
    if (context.mounted) toast(context, 'Accès refusé : autorise les photos dans les réglages du téléphone');
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.text, required this.color});
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(10)),
        child: Text(text, style: body(12.5, color: color, weight: FontWeight.w800)),
      );
}

/// Inviter des amis depuis les contacts du téléphone, par SMS.
class _FriendsPanel extends StatelessWidget {
  const _FriendsPanel();

  @override
  Widget build(BuildContext context) {
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Amis', style: display(20)),
          const SizedBox(height: 4),
          Text('Invite tes contacts : jouer entre amis, c\'est plus drôle que contre des bots.',
              style: body(12.5, color: Palette.textLo, weight: FontWeight.w500)),
          const SizedBox(height: 12),
          ChunkyButton(
            label: 'Inviter mes contacts',
            icon: Icons.contacts_rounded,
            height: 48,
            fontSize: 18,
            color: Palette.sky,
            shade: const Color(0xFF2F6FB8),
            textColor: Palette.night,
            onTap: () => _inviteContacts(context),
          ),
        ],
      ),
    );
  }
}

const _inviteText = 'Viens jouer avec moi à Omaha 3 boards : 6 cartes, 3 boards, un seul pot à rafler !';

Future<void> _inviteContacts(BuildContext context) async {
  if (kIsWeb) {
    toast(context, 'L\'accès aux contacts fonctionne dans l\'app iPhone et Android');
    return;
  }
  final status = await fc.FlutterContacts.permissions.request(fc.PermissionType.read);
  if (status != fc.PermissionStatus.granted && status != fc.PermissionStatus.limited) {
    if (context.mounted) toast(context, 'Accès aux contacts refusé : tu peux l\'autoriser dans les réglages');
    return;
  }
  final contacts = await fc.FlutterContacts.getAll(properties: {fc.ContactProperty.phone});
  final withPhone = contacts.where((c) => c.phones.isNotEmpty).toList()
    ..sort((a, b) => (a.displayName ?? '').compareTo(b.displayName ?? ''));
  if (!context.mounted) return;
  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: Palette.panel,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      builder: (context, scroll) => Column(
        children: [
          Text('Inviter un contact', style: display(22)),
          const SizedBox(height: 8),
          Expanded(
            child: withPhone.isEmpty
                ? Center(child: Text('Aucun contact avec un numéro', style: body(14, color: Palette.textLo)))
                : ListView.builder(
                    controller: scroll,
                    itemCount: withPhone.length,
                    itemBuilder: (context, i) {
                      final c = withPhone[i];
                      final number = c.phones.first.number;
                      return ListTile(
                        leading: Avatar(name: c.displayName ?? '?', size: 36),
                        title: Text(c.displayName ?? number, style: body(15)),
                        subtitle: Text(number, style: body(12.5, color: Palette.textLo)),
                        trailing: TextButton(
                          onPressed: () => launchUrl(Uri.parse('sms:$number?body=${Uri.encodeComponent(_inviteText)}')),
                          child: Text('Inviter', style: body(14, color: Palette.gold, weight: FontWeight.w800)),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    ),
  );
}

/// État des accès au téléphone, avec un raccourci vers les réglages.
class _PermissionsPanel extends StatefulWidget {
  const _PermissionsPanel();

  @override
  State<_PermissionsPanel> createState() => _PermissionsPanelState();
}

class _PermissionsPanelState extends State<_PermissionsPanel> {
  String _contacts = '…';

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    if (kIsWeb) {
      setState(() => _contacts = 'Sur mobile');
      return;
    }
    try {
      final s = await fc.FlutterContacts.permissions.check(fc.PermissionType.read);
      if (!mounted) return;
      setState(() => _contacts = switch (s) {
            fc.PermissionStatus.granted => 'Autorisé',
            fc.PermissionStatus.limited => 'Partiel',
            fc.PermissionStatus.notDetermined => 'Pas encore demandé',
            _ => 'Refusé',
          });
    } catch (_) {
      if (mounted) setState(() => _contacts = 'Indisponible');
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget row(IconData icon, String title, String why, String state) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              Icon(icon, color: Palette.sky, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: body(14.5)),
                    Text(why, style: body(11.5, color: Palette.textLo, weight: FontWeight.w500)),
                  ],
                ),
              ),
              Text(state, style: body(12, color: Palette.textLo)),
            ],
          ),
        );
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Accès au téléphone', style: display(20)),
          const SizedBox(height: 4),
          Text('Chaque accès est demandé au moment où il sert, jamais avant.',
              style: body(12.5, color: Palette.textLo, weight: FontWeight.w500)),
          const SizedBox(height: 6),
          row(Icons.photo_library_rounded, 'Photos', 'Pour ta photo de profil', 'À la demande'),
          row(Icons.photo_camera_rounded, 'Appareil photo', 'Pour prendre ta photo de profil', 'À la demande'),
          row(Icons.contacts_rounded, 'Contacts', 'Pour inviter tes amis par SMS', _contacts),
          const SizedBox(height: 8),
          if (!kIsWeb)
            TextButton.icon(
              onPressed: () async {
                await fc.FlutterContacts.permissions.openSettings();
                _refresh();
              },
              icon: const Icon(Icons.settings_rounded, color: Palette.gold),
              label: Text('Ouvrir les réglages du téléphone', style: body(14, color: Palette.gold)),
            ),
        ],
      ),
    );
  }
}
