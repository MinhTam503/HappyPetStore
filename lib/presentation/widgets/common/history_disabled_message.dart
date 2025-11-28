import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:pet_shop/core/constants/app_constants.dart';
import 'package:pet_shop/presentation/pages/mobile/setting/settings_page.dart';

class HistoryDisabledMessage extends StatelessWidget {
  final String messageKey;
  final IconData icon;
  final Color iconColor;

  const HistoryDisabledMessage({
    super.key,
    required this.messageKey,
    this.icon = Icons.history_outlined,
    this.iconColor = Colors.grey,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 48,
            color: iconColor,
          ),
          const SizedBox(height: 16),
          Builder(builder: (ctx){
            final l10n = AppLocalizations.of(ctx);
            // Fallback to messageKey if not found (during migration)
            return Text(
              _resolveMessage(l10n, messageKey),
              style: const TextStyle(
                fontSize: 16,
                color: Colors.black87,
              ),
              textAlign: TextAlign.center,
            );
          }),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const SettingsPage(),
                ),
              );
            },
            icon: const Icon(Icons.settings_outlined),
            label: Text(
              AppLocalizations.of(context)?.goToSettings ?? 'Đi tới cài đặt',
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.primary,
              side: BorderSide(color: Theme.of(context).colorScheme.primary),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _resolveMessage(AppLocalizations? l10n, String key){
  if(l10n == null) return key;
  // Map legacy keys to new localization getters. Extend as migration progresses.
  switch(key){
    case 'searchHistoryDisabledMessage':
      return l10n.searchHistoryDisabledMessage;
    case 'viewedPetsHistoryDisabledMessage':
      return l10n.viewedPetsHistoryDisabledMessage;
    default:
      return key; // fallback to key for missing mapping
  }
}