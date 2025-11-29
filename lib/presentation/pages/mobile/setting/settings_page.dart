import 'package:flutter/material.dart';
import 'package:pet_shop/presentation/pages/mobile/tab/bottom_navigator.dart';
import 'package:provider/provider.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:pet_shop/core/services/settings_service.dart';
import 'package:pet_shop/core/providers/locale_provider.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _showChatBubble = true;
  String _selectedLanguage = 'vi';
  bool _searchHistoryEnabled = true;
  bool _viewedPetsHistoryEnabled = true;
  bool _useAdminTheme = true; // true = follow admin, false = default
  bool _isLoading = true;

  final SettingsService _settingsService = SettingsService();

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final chatBubbleVisible =
          await _settingsService.getChatBubbleVisibility();
      final selectedLanguage = await _settingsService.getSelectedLanguage();
      final searchHistoryEnabled =
          await _settingsService.getSearchHistoryEnabled();
      final viewedPetsHistoryEnabled =
          await _settingsService.getViewedPetsHistoryEnabled();
      final useAdminTheme = await _settingsService.getUseAdminTheme();

      if (mounted) {
        // Sync with LocaleProvider
        final localeProvider =
            Provider.of<LocaleProvider>(context, listen: false);
        final currentLocale = localeProvider.locale.languageCode;

        // If there's a mismatch, update SettingsService to match LocaleProvider
        final finalLanguage = currentLocale != selectedLanguage
            ? currentLocale
            : selectedLanguage;

        setState(() {
          _showChatBubble = chatBubbleVisible;
          _selectedLanguage = finalLanguage;
          _searchHistoryEnabled = searchHistoryEnabled;
          _viewedPetsHistoryEnabled = viewedPetsHistoryEnabled;
          _useAdminTheme = useAdminTheme;
          _isLoading = false;
        });

        // Update SettingsService if there was a mismatch
        if (currentLocale != selectedLanguage) {
          await _settingsService.setSelectedLanguage(finalLanguage);
        }
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      debugPrint('Error loading settings: $e');
    }
  }

  Future<void> _saveChatBubbleSetting(bool value) async {
    try {
      await _settingsService.setChatBubbleVisibility(value);
      setState(() {
        _showChatBubble = value;
      });

      // Show feedback to user
      if (mounted) {
        final l10n = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              value
                  ? (l10n?.chatbotEnabled ?? 'Chatbot bubble đã được bật')
                  : (l10n?.chatbotDisabled ?? 'Chatbot bubble đã được tắt'),
            ),
            backgroundColor: value ? Colors.green : Colors.orange,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error saving chat bubble setting: $e');
      if (mounted) {
        final l10n = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n?.errorSavingSetting ?? 'Lỗi khi lưu cài đặt'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _saveLanguageSetting(String value) async {
    try {
      // Update both SettingsService and LocaleProvider
      await _settingsService.setSelectedLanguage(value);

      // Use LocaleProvider to change the app's locale
      if (mounted) {
        final localeProvider =
            Provider.of<LocaleProvider>(context, listen: false);
        localeProvider.setLocale(Locale(value));
      }

      setState(() {
        _selectedLanguage = value;
      });

      // Show feedback to user using localized strings
      if (mounted) {
        final l10n = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              value == 'vi'
                  ? (l10n?.switchedToVietnamese ?? 'Đã chuyển sang Tiếng Việt')
                  : (l10n?.switchedToEnglish ?? 'Switched to English'),
            ),
            backgroundColor: Theme.of(context).colorScheme.primary,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error saving language setting: $e');
      if (mounted) {
        final l10n = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                l10n?.errorSavingLanguage ?? 'Lỗi khi lưu cài đặt ngôn ngữ'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _saveSearchHistorySetting(bool value) async {
    try {
      await _settingsService.setSearchHistoryEnabled(value);
      setState(() {
        _searchHistoryEnabled = value;
      });

      // Show feedback to user
      if (mounted) {
        final l10n = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              value
                  ? (l10n?.searchHistoryEnabled ??
                      'Đã bật lưu lịch sử tìm kiếm')
                  : (l10n?.searchHistoryDisabled ??
                      'Đã tắt lưu lịch sử tìm kiếm'),
            ),
            backgroundColor: value ? Colors.green : Colors.orange,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error saving search history setting: $e');
      if (mounted) {
        final l10n = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n?.errorSavingSetting ?? 'Lỗi khi lưu cài đặt'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _saveViewedPetsHistorySetting(bool value) async {
    try {
      await _settingsService.setViewedPetsHistoryEnabled(value);
      setState(() {
        _viewedPetsHistoryEnabled = value;
      });

      // Show feedback to user
      if (mounted) {
        final l10n = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              value
                  ? (l10n?.viewedPetsHistoryEnabled ??
                      'Đã bật lưu lịch sử xem thú cưng')
                  : (l10n?.viewedPetsHistoryDisabled ??
                      'Đã tắt lưu lịch sử xem thú cưng'),
            ),
            backgroundColor: value ? Colors.green : Colors.orange,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error saving viewed pets history setting: $e');
      if (mounted) {
        final l10n = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n?.errorSavingSetting ?? 'Lỗi khi lưu cài đặt'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _saveThemePreference(bool useAdminTheme) async {
    try {
      await _settingsService.setUseAdminTheme(useAdminTheme);
      setState(() {
        _useAdminTheme = useAdminTheme;
      });

      // Show feedback to user
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              useAdminTheme
                  ? 'Sử dụng giao diện theo quản trị viên'
                  : 'Sử dụng giao diện mặc định',
            ),
            backgroundColor: Theme.of(context).colorScheme.primary,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error saving theme preference: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Lỗi khi lưu cài đặt'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final width = MediaQuery.of(context).size.width;
    final isWide = width >= 900;
    final horizontal = isWide ? width * 0.12 : 16.0;
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        elevation: 0,
        centerTitle: true,
        backgroundColor: Theme.of(context).colorScheme.surface,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: Theme.of(context).colorScheme.onSurface),
          onPressed: () => Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(
              builder: (_) => const BottomNavigator(initialIndex: 4),
            ),
            (route) => false,
          ),
        ),
        title: Text(
          l10n?.settings ?? 'Settings',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
            color: Theme.of(context).colorScheme.onSurface,
            letterSpacing: .3,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xff08A045)),
              ),
            )
          : ListView(
              padding: EdgeInsets.fromLTRB(horizontal, 20, horizontal, 24),
              children: [
                // App Settings Section
                _SectionHeader(
                  title: l10n?.appSettings ?? 'Cài đặt ứng dụng',
                  icon: Icons.settings,
                ),
                const SizedBox(height: 12),
                _SettingsCard(
                  children: [
                    _SettingsToggle(
                      icon: Icons.chat_bubble_outline,
                      iconBg: const Color(0xffe3f2fd),
                      iconColor: Colors.blue,
                      title: l10n?.showChatbot ?? 'Hiển thị Chatbot',
                      subtitle: l10n?.chatbotToggleSubtitle ??
                          'Bật/tắt biểu tượng chatbot trên màn hình',
                      value: _showChatBubble,
                      onChanged: _saveChatBubbleSetting,
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // Language Settings Section
                _SectionHeader(
                  title: l10n?.language ?? 'Ngôn ngữ',
                  icon: Icons.language,
                ),
                const SizedBox(height: 12),
                _SettingsCard(
                  children: [
                    _LanguageSelector(
                      selectedLanguage: _selectedLanguage,
                      onLanguageChanged: _saveLanguageSetting,
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // Theme Preference Section
                _SectionHeader(
                  title: 'Giao diện theo mùa',
                  icon: Icons.palette_outlined,
                ),
                const SizedBox(height: 12),
                _SettingsCard(
                  children: [
                    _ThemePreferenceSelector(
                      useAdminTheme: _useAdminTheme,
                      onChanged: _saveThemePreference,
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // Privacy Settings Section
                _SectionHeader(
                  title: l10n?.privacySettings ?? 'Cài đặt riêng tư',
                  icon: Icons.privacy_tip_outlined,
                ),
                const SizedBox(height: 12),
                _SettingsCard(
                  children: [
                    _SettingsToggle(
                      icon: Icons.search,
                      iconBg: const Color(0xffe8f5e8),
                      iconColor: Colors.green,
                      title: l10n?.saveSearchHistory ?? 'Lưu lịch sử tìm kiếm',
                      subtitle: l10n?.searchHistoryDescription ??
                          'Lưu các truy vấn tìm kiếm để truy cập nhanh',
                      value: _searchHistoryEnabled,
                      onChanged: _saveSearchHistorySetting,
                    ),
                    const Divider(
                        height: 0, indent: 16 + 44 + 12, endIndent: 12),
                    _SettingsToggle(
                      icon: Icons.pets,
                      iconBg: const Color(0xfff3e5f5),
                      iconColor: Colors.purple,
                      title: l10n?.saveViewedPetsHistory ??
                          'Lưu lịch sử xem thú cưng',
                      subtitle: l10n?.viewedPetsHistoryDescription ??
                          'Theo dõi các thú cưng bạn đã xem gần đây',
                      value: _viewedPetsHistoryEnabled,
                      onChanged: _saveViewedPetsHistorySetting,
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // About Section
                _SectionHeader(
                  title: l10n?.about ?? 'Thông tin',
                  icon: Icons.info_outline,
                ),
                const SizedBox(height: 12),
                _SettingsCard(
                  children: [
                    _SettingsItem(
                      icon: Icons.info,
                      iconBg: const Color(0xfff3e5f5),
                      iconColor: Colors.purple,
                      title: l10n?.appVersion ?? 'Phiên bản ứng dụng',
                      subtitle: '1.0.0',
                      onTap: () {},
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'v1.0.0',
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context).colorScheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
    );
  }
}

// Section Header Widget
class _SectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;

  const _SectionHeader({
    required this.title,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            icon,
            size: 20,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.87),
            letterSpacing: 0.2,
          ),
        ),
      ],
    );
  }
}

// Settings Card Container
class _SettingsCard extends StatelessWidget {
  final List<Widget> children;

  const _SettingsCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(children: children),
      ),
    );
  }
}

// Settings Toggle Widget
class _SettingsToggle extends StatelessWidget {
  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SettingsToggle({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      leading: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: iconBg,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: iconColor, size: 24),
      ),
      title: Text(
        title,
        style: theme.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w600,
          color: Theme.of(context).colorScheme.onSurface,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: theme.textTheme.bodySmall?.copyWith(
          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.54),
        ),
      ),
      trailing: Switch.adaptive(
        value: value,
        onChanged: onChanged,
        activeColor: Theme.of(context).colorScheme.primary,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      horizontalTitleGap: 12,
    );
  }
}

// Settings Item Widget
class _SettingsItem extends StatelessWidget {
  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Widget? trailing;

  const _SettingsItem({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      onTap: onTap,
      leading: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: iconBg,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: iconColor, size: 24),
      ),
      title: Text(
        title,
        style: theme.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w600,
          color: Theme.of(context).colorScheme.onSurface,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: theme.textTheme.bodySmall?.copyWith(
          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.54),
        ),
      ),
      trailing:
          trailing ?? Icon(Icons.chevron_right, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.38)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      horizontalTitleGap: 12,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );
  }
}

// Language Selector Widget
class _LanguageSelector extends StatelessWidget {
  final String selectedLanguage;
  final ValueChanged<String> onLanguageChanged;

  const _LanguageSelector({
    required this.selectedLanguage,
    required this.onLanguageChanged,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Column(
      children: [
        _LanguageOption(
          flag: '🇻🇳',
          title: l10n?.vietnamese ?? 'Tiếng Việt',
          subtitle: 'Vietnamese',
          value: 'vi',
          groupValue: selectedLanguage,
          onChanged: onLanguageChanged,
        ),
        const Divider(
          height: 0,
          indent: 16 + 44 + 12,
          endIndent: 12,
        ),
        _LanguageOption(
          flag: '🇺🇸',
          title: l10n?.english ?? 'English',
          subtitle: 'English (US)',
          value: 'en',
          groupValue: selectedLanguage,
          onChanged: onLanguageChanged,
        ),
      ],
    );
  }
}

// Language Option Widget
class _LanguageOption extends StatelessWidget {
  final String flag;
  final String title;
  final String subtitle;
  final String value;
  final String groupValue;
  final ValueChanged<String> onChanged;

  const _LanguageOption({
    required this.flag,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.groupValue,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isSelected = value == groupValue;

    return ListTile(
      onTap: () => onChanged(value),
      leading: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color:
              isSelected ? Theme.of(context).colorScheme.primary.withOpacity(0.1) : Theme.of(context).colorScheme.surfaceVariant,
          borderRadius: BorderRadius.circular(12),
          border: isSelected ? Border.all(color: Theme.of(context).colorScheme.primary, width: 2) : null,
        ),
        child: Center(
          child: Text(
            flag,
            style: const TextStyle(fontSize: 24),
          ),
        ),
      ),
      title: Text(
        title,
        style: theme.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w600,
          color: isSelected ? Theme.of(context).colorScheme.primary : Colors.black,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: theme.textTheme.bodySmall?.copyWith(
          color: isSelected ? Theme.of(context).colorScheme.primary.withOpacity(0.8) : Theme.of(context).colorScheme.onSurface.withOpacity(0.54),
        ),
      ),
      trailing: Radio<String>(
        value: value,
        groupValue: groupValue,
        onChanged: (value) => onChanged(value!),
        activeColor: Theme.of(context).colorScheme.primary,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      horizontalTitleGap: 12,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );
  }
}

// Theme Preference Selector Widget
class _ThemePreferenceSelector extends StatelessWidget {
  final bool useAdminTheme;
  final ValueChanged<bool> onChanged;

  const _ThemePreferenceSelector({
    required this.useAdminTheme,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _ThemeOption(
          icon: Icons.admin_panel_settings,
          title: 'Theo quản trị viên',
          subtitle: 'Giao diện thay đổi theo mùa do admin thiết lập',
          value: true,
          groupValue: useAdminTheme,
          onChanged: onChanged,
        ),
        const Divider(
          height: 0,
          indent: 16 + 44 + 12,
          endIndent: 12,
        ),
        _ThemeOption(
          icon: Icons.palette,
          title: 'Giao diện mặc định',
          subtitle: 'Luôn sử dụng giao diện màu xanh lá truyền thống',
          value: false,
          groupValue: useAdminTheme,
          onChanged: onChanged,
        ),
      ],
    );
  }
}

// Theme Option Widget
class _ThemeOption extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final bool groupValue;
  final ValueChanged<bool> onChanged;

  const _ThemeOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.groupValue,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isSelected = value == groupValue;

    return ListTile(
      onTap: () => onChanged(value),
      leading: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: isSelected 
              ? Theme.of(context).colorScheme.primary.withOpacity(0.1) 
              : Theme.of(context).colorScheme.surfaceVariant,
          borderRadius: BorderRadius.circular(12),
          border: isSelected 
              ? Border.all(color: Theme.of(context).colorScheme.primary, width: 2) 
              : null,
        ),
        child: Icon(
          icon,
          color: isSelected 
              ? Theme.of(context).colorScheme.primary 
              : Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
          size: 24,
        ),
      ),
      title: Text(
        title,
        style: theme.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w600,
          color: isSelected ? Theme.of(context).colorScheme.primary : Colors.black,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: theme.textTheme.bodySmall?.copyWith(
          color: isSelected 
              ? Theme.of(context).colorScheme.primary.withOpacity(0.8) 
              : Theme.of(context).colorScheme.onSurface.withOpacity(0.54),
        ),
      ),
      trailing: Radio<bool>(
        value: value,
        groupValue: groupValue,
        onChanged: (value) => onChanged(value!),
        activeColor: Theme.of(context).colorScheme.primary,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      horizontalTitleGap: 12,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );
  }
}
