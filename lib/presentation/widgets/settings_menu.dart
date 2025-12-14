import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pet_shop/core/providers/theme_provider.dart';
import 'package:pet_shop/core/providers/locale_provider.dart';

class SettingsMenu extends StatelessWidget {
  const SettingsMenu({super.key});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      icon: Icon(
        Icons.settings,
        color: Theme.of(context).colorScheme.onPrimary,
      ),
      tooltip: 'Settings',
      offset: const Offset(-150, 50),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      color: Theme.of(context).cardColor,
      elevation: 8,
      itemBuilder: (context) => [
        PopupMenuItem<String>(
          enabled: false,
          child: Container(
            width: 300,
            padding: const EdgeInsets.all(12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Theme Section
                Row(
                  children: [
                    Icon(
                      Icons.brightness_6,
                      size: 20,
                      color: Theme.of(context).iconTheme.color,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Theme',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Theme.of(context).textTheme.bodyLarge?.color,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: Consumer<ThemeProvider>(
                    builder: (context, themeProvider, child) {
                      return _buildThemeToggle(context, themeProvider);
                    },
                  ),
                ),
                const Divider(height: 24),

                // Language Section
                Row(
                  children: [
                    Icon(
                      Icons.language,
                      size: 20,
                      color: Theme.of(context).iconTheme.color,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Language',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Theme.of(context).textTheme.bodyLarge?.color,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: Consumer<LocaleProvider>(
                    builder: (context, localeProvider, child) {
                      return _buildLanguageToggle(context, localeProvider);
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildThemeToggle(BuildContext context, ThemeProvider themeProvider) {
    return Row(
      children: [
        Expanded(
          child: ToggleButtons(
            isSelected: [!themeProvider.isDarkMode, themeProvider.isDarkMode],
            onPressed: (index) {
              // Delay the theme change to avoid widget tree instability
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if ((index == 0 && themeProvider.isDarkMode) ||
                    (index == 1 && !themeProvider.isDarkMode)) {
                  themeProvider.toggleTheme();
                }
              });
              Navigator.pop(context);
            },
            borderRadius: BorderRadius.circular(8),
            constraints: const BoxConstraints(
              minHeight: 36.0,
              minWidth: 0.0,
            ),
            selectedColor: Theme.of(context).colorScheme.onPrimary,
            fillColor: Theme.of(context).primaryColor,
            children: const [
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.light_mode, size: 16),
                    SizedBox(width: 4),
                    Text('Light', style: TextStyle(fontSize: 12)),
                  ],
                ),
              ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.dark_mode, size: 16),
                    SizedBox(width: 4),
                    Text('Dark', style: TextStyle(fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLanguageToggle(
      BuildContext context, LocaleProvider localeProvider) {
    return Row(
      children: [
        Expanded(
          child: ToggleButtons(
            isSelected: [
              localeProvider.locale.languageCode == 'en',
              localeProvider.locale.languageCode == 'vi',
            ],
            onPressed: (index) {
              // Delay the locale change to avoid widget tree instability
              WidgetsBinding.instance.addPostFrameCallback((_) {
                final newLocale =
                    index == 0 ? const Locale('en') : const Locale('vi');
                localeProvider.setLocale(newLocale);
              });
              Navigator.pop(context);
            },
            borderRadius: BorderRadius.circular(8),
            constraints: const BoxConstraints(
              minHeight: 36.0,
              minWidth: 0.0,
            ),
            selectedColor: Theme.of(context).colorScheme.onPrimary,
            fillColor: Theme.of(context).primaryColor,
            children: const [
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('🇺🇸', style: TextStyle(fontSize: 14)),
                    SizedBox(width: 4),
                    Text('EN', style: TextStyle(fontSize: 12)),
                  ],
                ),
              ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('🇻🇳', style: TextStyle(fontSize: 14)),
                    SizedBox(width: 4),
                    Text('VI', style: TextStyle(fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
