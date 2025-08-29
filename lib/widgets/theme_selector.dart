import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';

class ThemeSelector extends StatelessWidget {
  const ThemeSelector({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Theme.of(context).dividerColor,
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                themeProvider.isDarkMode ? Icons.dark_mode : Icons.light_mode,
                size: 18,
                color: Theme.of(context).textTheme.bodyMedium?.color,
              ),
              const SizedBox(width: 8),
              Text(
                themeProvider.isDarkMode 
                    ? AppLocalizations.of(context)!.darkMode 
                    : AppLocalizations.of(context)!.lightMode,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Theme.of(context).textTheme.bodyMedium?.color,
                ),
              ),
              const SizedBox(width: 8),
              Switch(
                value: themeProvider.isDarkMode,
                onChanged: (value) => themeProvider.toggleTheme(),
                activeColor: Theme.of(context).primaryColor,
                activeTrackColor: Theme.of(context).primaryColor.withOpacity(0.3),
                inactiveThumbColor: Colors.grey,
                inactiveTrackColor: Colors.grey.withOpacity(0.3),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ],
          ),
        );
      },
    );
  }
}
