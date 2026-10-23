import 'package:flutter/widgets.dart';

import 'profile.dart';

/// Rend le profil accessible à tous les écrans et les reconstruit quand il change.
class ProfileScope extends InheritedNotifier<PlayerProfile> {
  const ProfileScope({super.key, required PlayerProfile profile, required super.child}) : super(notifier: profile);

  static PlayerProfile of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ProfileScope>()!.notifier!;

  /// Accès sans abonnement aux changements (dans un gestionnaire de tap).
  static PlayerProfile read(BuildContext context) =>
      context.getInheritedWidgetOfExactType<ProfileScope>()!.notifier!;
}
