import 'package:flutter/material.dart';
import 'package:pet_shop/core/constants/app_constants.dart';
import 'package:pet_shop/core/services/settings_service.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _showChatBubble = true;
  String _selectedLanguage = 'vi';
  bool _isLoading = true;
  
  final SettingsService _settingsService = SettingsService();

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final chatBubbleVisible = await _settingsService.getChatBubbleVisibility();
      final selectedLanguage = await _settingsService.getSelectedLanguage();
      
      setState(() {
        _showChatBubble = chatBubbleVisible;
        _selectedLanguage = selectedLanguage;
        _isLoading = false;
      });
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              value ? 'Chatbot bubble đã được bật' : 'Chatbot bubble đã được tắt',
            ),
            backgroundColor: value ? Colors.green : Colors.orange,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error saving chat bubble setting: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Lỗi khi lưu cài đặt'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _saveLanguageSetting(String value) async {
    try {
      await _settingsService.setSelectedLanguage(value);
      setState(() {
        _selectedLanguage = value;
      });
      
      // Show feedback to user
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              value == 'vi' ? 'Đã chuyển sang Tiếng Việt' : 'Switched to English',
            ),
            backgroundColor: primaryColor,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error saving language setting: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Lỗi khi lưu cài đặt ngôn ngữ'),
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

    return Scaffold(
      backgroundColor: secondaryColor,
      appBar: AppBar(
        elevation: 0,
        centerTitle: true,
        backgroundColor: secondaryColor,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Settings',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
            color: Colors.black,
            letterSpacing: .3,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
              ),
            )
          : ListView(
              padding: EdgeInsets.fromLTRB(horizontal, 20, horizontal, 24),
              children: [
                // App Settings Section
                _SectionHeader(
                  title: 'Cài đặt ứng dụng',
                  icon: Icons.settings,
                ),
                const SizedBox(height: 12),
                _SettingsCard(
                  children: [
                    _SettingsToggle(
                      icon: Icons.chat_bubble_outline,
                      iconBg: const Color(0xffe3f2fd),
                      iconColor: Colors.blue,
                      title: 'Hiển thị Chatbot',
                      subtitle: 'Bật/tắt biểu tượng chatbot trên màn hình',
                      value: _showChatBubble,
                      onChanged: _saveChatBubbleSetting,
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // Language Settings Section
                _SectionHeader(
                  title: 'Ngôn ngữ',
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

                // About Section
                _SectionHeader(
                  title: 'Thông tin',
                  icon: Icons.info_outline,
                ),
                const SizedBox(height: 12),
                _SettingsCard(
                  children: [
                    _SettingsItem(
                      icon: Icons.info,
                      iconBg: const Color(0xfff3e5f5),
                      iconColor: Colors.purple,
                      title: 'Phiên bản ứng dụng',
                      subtitle: '1.0.0',
                      onTap: () {},
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: primaryColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          'v1.0.0',
                          style: TextStyle(
                            fontSize: 12,
                            color: primaryColor,
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
            color: primaryColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            icon,
            size: 20,
            color: primaryColor,
          ),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: Colors.black87,
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
          color: Colors.black,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: theme.textTheme.bodySmall?.copyWith(
          color: Colors.black54,
        ),
      ),
      trailing: Switch.adaptive(
        value: value,
        onChanged: onChanged,
        activeColor: primaryColor,
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
          color: Colors.black,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: theme.textTheme.bodySmall?.copyWith(
          color: Colors.black54,
        ),
      ),
      trailing: trailing ?? const Icon(Icons.chevron_right, color: Colors.black38),
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
    
    return Column(
      children: [
        _LanguageOption(
          flag: '🇻🇳',
          title: 'Tiếng Việt',
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
          title: 'English',
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
          color: isSelected ? primaryColor.withOpacity(0.1) : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
          border: isSelected 
              ? Border.all(color: primaryColor, width: 2)
              : null,
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
          color: isSelected ? primaryColor : Colors.black,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: theme.textTheme.bodySmall?.copyWith(
          color: isSelected ? primaryColor.withOpacity(0.8) : Colors.black54,
        ),
      ),
      trailing: Radio<String>(
        value: value,
        groupValue: groupValue,
        onChanged: (value) => onChanged(value!),
        activeColor: primaryColor,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      horizontalTitleGap: 12,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );
  }
}