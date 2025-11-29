import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:pet_shop/core/constants/app_constants.dart';
import 'package:pet_shop/core/services/user_manager.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pet_shop/presentation/pages/mobile/social/blocked_accounts_page.dart';

/// Social Settings Page - Privacy and account settings for social network
class SocialSettingsPage extends StatefulWidget {
  const SocialSettingsPage({Key? key}) : super(key: key);

  @override
  State<SocialSettingsPage> createState() => _SocialSettingsPageState();
}

class _SocialSettingsPageState extends State<SocialSettingsPage> {
  String? _currentUserId;
  bool _isLoading = true;

  // Privacy settings
  bool _accountPrivate = false;
  bool _showFollowersToPublic = true;
  bool _showFollowingToPublic = true;
  bool _allowComments = true;  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final userId = await UserManager().getUserIdForOperations();
      if (userId == null) {
        setState(() => _isLoading = false);
        return;
      }

      setState(() => _currentUserId = userId);

      // Load settings from Firestore
      final doc = await FirebaseFirestore.instance
          .collection('socialSettings')
          .doc(userId)
          .get();

      if (doc.exists && mounted) {
        final data = doc.data()!;
        setState(() {
          _accountPrivate = data['accountPrivate'] ?? false;
          _showFollowersToPublic = data['showFollowersToPublic'] ?? true;
          _showFollowingToPublic = data['showFollowingToPublic'] ?? true;
          _allowComments = data['allowComments'] ?? true;
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint('Error loading social settings: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveSetting(String key, bool value) async {
    if (_currentUserId == null) return;

    try {
      await FirebaseFirestore.instance
          .collection('socialSettings')
          .doc(_currentUserId)
          .set({key: value}, SetOptions(merge: true));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.settingsSaved),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error saving setting: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.errorSavingSetting),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? Colors.grey[900] : Colors.grey[100],
      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        centerTitle: true,
        title: Text(
          l10n.settings,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Account Privacy Section
                _SectionHeader(
                  title: l10n.accountPrivacy,
                  icon: Icons.lock_outline,
                ),
                const SizedBox(height: 12),
                _SettingsCard(
                  children: [
                    _SettingsToggle(
                      icon: Icons.lock,
                      iconBg: const Color(0xffffe3e3),
                      iconColor: Colors.red,
                      title: l10n.privateAccount,
                      subtitle: l10n.privateAccountDescription,
                      value: _accountPrivate,
                      onChanged: (value) {
                        setState(() => _accountPrivate = value);
                        _saveSetting('accountPrivate', value);
                      },
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // Profile Visibility Section
                _SectionHeader(
                  title: l10n.profileVisibility,
                  icon: Icons.visibility_outlined,
                ),
                const SizedBox(height: 12),
                _SettingsCard(
                  children: [
                    _SettingsToggle(
                      icon: Icons.people,
                      iconBg: const Color(0xffe3f2fd),
                      iconColor: Colors.blue,
                      title: l10n.showFollowers,
                      subtitle: l10n.showFollowersDescription,
                      value: _showFollowersToPublic,
                      onChanged: (value) {
                        setState(() => _showFollowersToPublic = value);
                        _saveSetting('showFollowersToPublic', value);
                      },
                    ),
                    // const Divider(height: 0, indent: 72, endIndent: 12),
                    _SettingsToggle(
                      icon: Icons.person_add,
                      iconBg: const Color(0xffe8f5e8),
                      iconColor: Colors.green,
                      title: l10n.showFollowing,
                      subtitle: l10n.showFollowingDescription,
                      value: _showFollowingToPublic,
                      onChanged: (value) {
                        setState(() => _showFollowingToPublic = value);
                        _saveSetting('showFollowingToPublic', value);
                      },
                    ),
                    // const Divider(height: 0, indent: 72, endIndent: 12),
                    // _SettingsToggle(
                    //   icon: Icons.access_time,
                    //   iconBg: const Color(0xfffff3e0),
                    //   iconColor: Colors.orange,
                    //   title: l10n.showActivityStatus,
                    //   subtitle: l10n.showActivityStatusDescription,
                    //   value: _showActivityStatus,
                    //   onChanged: (value) {
                    //     setState(() => _showActivityStatus = value);
                    //     _saveSetting('showActivityStatus', value);
                    //   },
                    // ),
                  ],
                ),

                const SizedBox(height: 24),

                // Posts & Interactions Section
                _SectionHeader(
                  title: l10n.postsAndInteractions,
                  icon: Icons.photo_library_outlined,
                ),
                const SizedBox(height: 12),
                _SettingsCard(
                  children: [
                    // _SettingsToggle(
                    //   icon: Icons.label,
                    //   iconBg: const Color(0xfff3e5f5),
                    //   iconColor: Colors.purple,
                    //   title: l10n.allowTagging,
                    //   subtitle: l10n.allowTaggingDescription,
                    //   value: _allowTagging,
                    //   onChanged: (value) {
                    //     setState(() => _allowTagging = value);
                    //     _saveSetting('allowTagging', value);
                    //   },
                    // ),
                    // const Divider(height: 0, indent: 72, endIndent: 12),
                    _SettingsToggle(
                      icon: Icons.comment,
                      iconBg: const Color(0xffe3f2fd),
                      iconColor: Colors.blue,
                      title: l10n.allowComments,
                      subtitle: l10n.allowCommentsDescription,
                      value: _allowComments,
                      onChanged: (value) {
                        setState(() => _allowComments = value);
                        _saveSetting('allowComments', value);
                      },
                    ),
                    // const Divider(height: 0, indent: 72, endIndent: 12),
                    // _SettingsToggle(
                    //   icon: Icons.share,
                    //   iconBg: const Color(0xffe8f5e8),
                    //   iconColor: Colors.green,
                    //   title: l10n.allowSharing,
                    //   subtitle: l10n.allowSharingDescription,
                    //   value: _allowSharing,
                    //   onChanged: (value) {
                    //     setState(() => _allowSharing = value);
                    //     _saveSetting('allowSharing', value);
                    //   },
                    // ),
                  ],
                ),

                const SizedBox(height: 24),

                // // Notifications Section
                // _SectionHeader(
                //   title: l10n.socialNotifications,
                //   icon: Icons.notifications_outlined,
                // ),
                // const SizedBox(height: 12),
                // _SettingsCard(
                //   children: [
                //     _SettingsToggle(
                //       icon: Icons.favorite,
                //       iconBg: const Color(0xffffe3e3),
                //       iconColor: Colors.red,
                //       title: l10n.notifyLikes,
                //       subtitle: l10n.notifyLikesDescription,
                //       value: _notifyLikes,
                //       onChanged: (value) {
                //         setState(() => _notifyLikes = value);
                //         _saveSetting('notifyLikes', value);
                //       },
                //     ),
                //     const Divider(height: 0, indent: 72, endIndent: 12),
                //     _SettingsToggle(
                //       icon: Icons.comment,
                //       iconBg: const Color(0xffe3f2fd),
                //       iconColor: Colors.blue,
                //       title: l10n.notifyComments,
                //       subtitle: l10n.notifyCommentsDescription,
                //       value: _notifyComments,
                //       onChanged: (value) {
                //         setState(() => _notifyComments = value);
                //         _saveSetting('notifyComments', value);
                //       },
                //     ),
                //     const Divider(height: 0, indent: 72, endIndent: 12),
                //     _SettingsToggle(
                //       icon: Icons.person_add,
                //       iconBg: const Color(0xffe8f5e8),
                //       iconColor: Colors.green,
                //       title: l10n.notifyFollows,
                //       subtitle: l10n.notifyFollowsDescription,
                //       value: _notifyFollows,
                //       onChanged: (value) {
                //         setState(() => _notifyFollows = value);
                //         _saveSetting('notifyFollows', value);
                //       },
                //     ),
                //     const Divider(height: 0, indent: 72, endIndent: 12),
                //     _SettingsToggle(
                //       icon: Icons.alternate_email,
                //       iconBg: const Color(0xfffff3e0),
                //       iconColor: Colors.orange,
                //       title: l10n.notifyMentions,
                //       subtitle: l10n.notifyMentionsDescription,
                //       value: _notifyMentions,
                //       onChanged: (value) {
                //         setState(() => _notifyMentions = value);
                //         _saveSetting('notifyMentions', value);
                //       },
                //     ),
                //   ],
                // ),

                // const SizedBox(height: 24),

                // Blocked Users Section
                _SectionHeader(
                  title: l10n.blockedAccounts,
                  icon: Icons.block,
                ),
                const SizedBox(height: 12),
                _SettingsCard(
                  children: [
                    _SettingsItem(
                      icon: Icons.block,
                      iconBg: const Color(0xffffe3e3),
                      iconColor: Colors.red,
                      title: l10n.manageBlockedAccounts,
                      subtitle: l10n.viewAndManageBlocked,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const BlockedAccountsPage(),
                          ),
                        );
                      },
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // Account Actions Section
                _SectionHeader(
                  title: l10n.accountActions,
                  icon: Icons.settings_outlined,
                ),
                const SizedBox(height: 12),
                _SettingsCard(
                  children: [
                    _SettingsItem(
                      icon: Icons.delete_forever,
                      iconBg: const Color(0xffffe3e3),
                      iconColor: Colors.red,
                      title: l10n.deleteAccount,
                      subtitle: l10n.deleteAccountDescription,
                      onTap: () {
                        _showDeleteAccountDialog();
                      },
                    ),
                  ],
                ),

                const SizedBox(height: 40),
              ],
            ),
    );
  }

  void _showDeleteAccountDialog() {
    final l10n = AppLocalizations.of(context)!;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded,
                color: Colors.red, size: 28),
            const SizedBox(width: 8),
            Text(l10n.deleteAccount),
          ],
        ),
        content: Text(l10n.deleteAccountWarning),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              // TODO: Implement account deletion
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(l10n.comingSoon)),
              );
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(l10n.deleteAccount),
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
    final isDark = theme.brightness == Brightness.dark;

    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Theme.of(context)
                                    .colorScheme.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            icon,
            size: 20,
            color: Theme.of(context)
                                    .colorScheme.primary,
          ),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white : Colors.black87,
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
    final isDark = theme.brightness == Brightness.dark;

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
          color: isDark ? Colors.white : Colors.black,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: theme.textTheme.bodySmall?.copyWith(
          color: isDark ? Colors.grey[400] : Colors.black54,
        ),
      ),
      trailing: Switch.adaptive(
        value: value,
        onChanged: onChanged,
        activeColor: Theme.of(context)
                                    .colorScheme.primary,
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

  const _SettingsItem({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

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
          color: isDark ? Colors.white : Colors.black,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: theme.textTheme.bodySmall?.copyWith(
          color: isDark ? Colors.grey[400] : Colors.black54,
        ),
      ),
      trailing: Icon(Icons.chevron_right,
          color: isDark ? Colors.grey[400] : Colors.black38),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      horizontalTitleGap: 12,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );
  }
}
