import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:pet_shop/core/providers/locale_provider.dart';

/// Demo widget để demonstrate tính năng đổi ngôn ngữ
class LanguageSwitchDemo extends StatelessWidget {
  const LanguageSwitchDemo({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)?.language ?? 'Language Demo'),
        actions: [
          // Dropdown để đổi ngôn ngữ
          Consumer<LocaleProvider>(
            builder: (context, localeProvider, child) {
              return DropdownButton<String>(
                value: localeProvider.locale.languageCode,
                items: LocaleProvider.supportedLocales.map((locale) {
                  return DropdownMenuItem(
                    value: locale.languageCode,
                    child: Text(LocaleProvider.languageNames[locale.languageCode] ?? locale.languageCode),
                  );
                }).toList(),
                onChanged: (languageCode) {
                  if (languageCode != null) {
                    localeProvider.setLocale(Locale(languageCode));
                  }
                },
              );
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Consumer<LocaleProvider>(
          builder: (context, localeProvider, child) {
            final l10n = AppLocalizations.of(context);
            
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Current Language: ${localeProvider.locale.languageCode}',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 20),
                
                Text(
                  'Demo Localized Strings:',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 10),
                
                // Demo các string đã được localize
                _DemoRow('Language:', l10n?.language ?? 'N/A'),
                _DemoRow('English:', l10n?.english ?? 'N/A'),
                _DemoRow('Vietnamese:', l10n?.vietnamese ?? 'N/A'),
                _DemoRow('Dashboard:', l10n?.dashboard ?? 'N/A'),
                _DemoRow('Pets:', l10n?.pets ?? 'N/A'),
                _DemoRow('Orders:', l10n?.orders ?? 'N/A'),
                _DemoRow('Account:', l10n?.account ?? 'N/A'),
                _DemoRow('All:', l10n?.all ?? 'N/A'),
                _DemoRow('Mobile App:', l10n?.mobileApp ?? 'N/A'),
                _DemoRow('Web App:', l10n?.webApp ?? 'N/A'),
                
                const SizedBox(height: 30),
                
                // Buttons để test đổi ngôn ngữ nhanh
                Row(
                  children: [
                    ElevatedButton(
                      onPressed: () {
                        localeProvider.setLocale(const Locale('vi'));
                      },
                      child: const Text('🇻🇳 Tiếng Việt'),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton(
                      onPressed: () {
                        localeProvider.setLocale(const Locale('en'));
                      },
                      child: const Text('🇺🇸 English'),
                    ),
                  ],
                ),
                
                const SizedBox(height: 30),
                
                // Info về implementation
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Implementation Notes:',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text('• Uses LocaleProvider for state management'),
                      const Text('• Persists to SharedPreferences'),
                      const Text('• Syncs with SettingsService for mobile'),
                      const Text('• Real-time UI updates via Consumer'),
                      const Text('• Supports fallback for missing strings'),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _DemoRow extends StatelessWidget {
  final String label;
  final String value;
  
  const _DemoRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(color: Colors.grey.shade700),
            ),
          ),
        ],
      ),
    );
  }
}