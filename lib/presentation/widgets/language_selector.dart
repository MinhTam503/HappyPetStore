import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:pet_shop/core/providers/locale_provider.dart';

class LanguageSelector extends StatelessWidget {
  const LanguageSelector({super.key});

  @override
  Widget build(BuildContext context) {
    final localeProvider = Provider.of<LocaleProvider>(context);
    final l10n = AppLocalizations.of(context)!;
    
    return PopupMenuButton<Locale>(
      icon: const Icon(Icons.language, color: Colors.white),
      tooltip: l10n.language,
      onSelected: (Locale locale) {
        localeProvider.setLocale(locale);
      },
      itemBuilder: (BuildContext context) {
        return LocaleProvider.supportedLocales.map((Locale locale) {
          String displayName;
          switch (locale.languageCode) {
            case 'en':
              displayName = l10n.english;
              break;
            case 'vi':
              displayName = l10n.vietnamese;
              break;
            default:
              displayName = locale.languageCode;
          }
          
          return PopupMenuItem<Locale>(
            value: locale,
            child: Row(
              children: [
                Icon(
                  localeProvider.locale.languageCode == locale.languageCode
                      ? Icons.check_circle
                      : Icons.radio_button_unchecked,
                  color: localeProvider.locale.languageCode == locale.languageCode
                      ? Colors.green
                      : Colors.grey,
                ),
                const SizedBox(width: 8),
                Text(displayName),
              ],
            ),
          );
        }).toList();
      },
    );
  }
}
