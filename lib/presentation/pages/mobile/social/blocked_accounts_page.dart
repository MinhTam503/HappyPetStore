import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pet_shop/core/constants/app_constants.dart';
import 'package:pet_shop/core/services/user_manager.dart';
import 'package:cached_network_image/cached_network_image.dart';

/// Blocked Accounts Page - Manage blocked users
class BlockedAccountsPage extends StatefulWidget {
  const BlockedAccountsPage({Key? key}) : super(key: key);

  @override
  State<BlockedAccountsPage> createState() => _BlockedAccountsPageState();
}

class _BlockedAccountsPageState extends State<BlockedAccountsPage> {
  String? _currentUserId;
  bool _isLoading = true;
  List<BlockedUser> _blockedUsers = [];

  @override
  void initState() {
    super.initState();
    _loadBlockedUsers();
  }

  Future<void> _loadBlockedUsers() async {
    try {
      final userId = await UserManager().getUserIdForOperations();
      if (userId == null) {
        setState(() => _isLoading = false);
        return;
      }

      setState(() => _currentUserId = userId);

      // Load blocked users list
      final doc = await FirebaseFirestore.instance
          .collection('blockedUsers')
          .doc(userId)
          .get();

      if (doc.exists && mounted) {
        final data = doc.data()!;
        final List<dynamic> blockedList = data['blocked'] ?? [];
        
        // Fetch user details for each blocked user
        final List<BlockedUser> users = [];
        for (String blockedUserId in blockedList) {
          // Try socialPetProfiles first (for social users)
          var userDoc = await FirebaseFirestore.instance
              .collection('socialPetProfiles')
              .doc(blockedUserId)
              .get();
          
          if (userDoc.exists) {
            final userData = userDoc.data()!;
            users.add(BlockedUser(
              userId: blockedUserId,
              username: userData['petName'] ?? userData['displayName'] ?? 'Unknown',
              fullName: userData['displayName'] ?? userData['petName'] ?? '',
              avatarUrl: userData['avatarUrl'] ?? '',
              blockedAt: (data['blockedAt_$blockedUserId'] as Timestamp?)?.toDate() ?? DateTime.now(),
            ));
          } else {
            // Fallback to users collection
            userDoc = await FirebaseFirestore.instance
                .collection('users')
                .doc(blockedUserId)
                .get();
            
            if (userDoc.exists) {
              final userData = userDoc.data()!;
              users.add(BlockedUser(
                userId: blockedUserId,
                username: userData['username'] ?? userData['displayName'] ?? 'Unknown',
                fullName: userData['fullName'] ?? userData['displayName'] ?? '',
                avatarUrl: userData['avatarUrl'] ?? userData['imageUrl'] ?? '',
                blockedAt: (data['blockedAt_$blockedUserId'] as Timestamp?)?.toDate() ?? DateTime.now(),
              ));
            }
          }
        }

        setState(() {
          _blockedUsers = users;
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint('Error loading blocked users: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _unblockUser(BlockedUser user) async {
    if (_currentUserId == null) return;

    try {
      // Show loading
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      // Remove from blocked list
      await FirebaseFirestore.instance
          .collection('blockedUsers')
          .doc(_currentUserId)
          .update({
        'blocked': FieldValue.arrayRemove([user.userId]),
        'blockedAt_${user.userId}': FieldValue.delete(),
      });

      // Also remove from the other user's blockedBy list
      final targetUserDoc = await FirebaseFirestore.instance
          .collection('blockedUsers')
          .doc(user.userId)
          .get();
      
      if (targetUserDoc.exists) {
        await FirebaseFirestore.instance
            .collection('blockedUsers')
            .doc(user.userId)
            .update({
          'blockedBy': FieldValue.arrayRemove([_currentUserId]),
          'blockedByAt_$_currentUserId': FieldValue.delete(),
        });
      }

      // Remove user from local list
      setState(() {
        _blockedUsers.removeWhere((u) => u.userId == user.userId);
      });

      if (mounted) {
        Navigator.pop(context); // Close loading dialog
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.userUnblocked),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error unblocking user: $e');
      if (mounted) {
        Navigator.pop(context); // Close loading dialog
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.errorUnblockingUser),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showUnblockConfirmation(BlockedUser user) {
    final l10n = AppLocalizations.of(context)!;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.unblockUser),
        content: Text(l10n.unblockUserConfirmation(user.username)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _unblockUser(user);
            },
            style: TextButton.styleFrom(foregroundColor: primaryColor),
            child: Text(l10n.unblock),
          ),
        ],
      ),
    );
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
        title: Text(
          l10n.blockedAccounts,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _blockedUsers.isEmpty
              ? _buildEmptyState(l10n, isDark)
              : RefreshIndicator(
                  onRefresh: _loadBlockedUsers,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _blockedUsers.length,
                    itemBuilder: (context, index) {
                      final user = _blockedUsers[index];
                      return _BlockedUserCard(
                        user: user,
                        onUnblock: () => _showUnblockConfirmation(user),
                      );
                    },
                  ),
                ),
    );
  }

  Widget _buildEmptyState(AppLocalizations l10n, bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: isDark ? Colors.grey[800] : Colors.grey[200],
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.block,
                size: 64,
                color: isDark ? Colors.grey[600] : Colors.grey[400],
              ),
            ),
            const SizedBox(height: 24),
            Text(
              l10n.noBlockedAccounts,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              l10n.noBlockedAccountsDescription,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.grey[400] : Colors.black54,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Blocked User Data Model
class BlockedUser {
  final String userId;
  final String username;
  final String fullName;
  final String avatarUrl;
  final DateTime blockedAt;

  BlockedUser({
    required this.userId,
    required this.username,
    required this.fullName,
    required this.avatarUrl,
    required this.blockedAt,
  });
}

// Blocked User Card Widget
class _BlockedUserCard extends StatelessWidget {
  final BlockedUser user;
  final VoidCallback onUnblock;

  const _BlockedUserCard({
    required this.user,
    required this.onUnblock,
  });

  String _getTimeAgo(DateTime blockedAt, BuildContext context) {
    final now = DateTime.now();
    final difference = now.difference(blockedAt);
    final l10n = AppLocalizations.of(context)!;

    if (difference.inDays > 365) {
      final years = (difference.inDays / 365).floor();
      return years == 1 ? l10n.oneYearAgo : l10n.yearsAgo(years);
    } else if (difference.inDays > 30) {
      final months = (difference.inDays / 30).floor();
      return months == 1 ? l10n.oneMonthAgo : l10n.monthsAgo(months);
    } else if (difference.inDays > 0) {
      return difference.inDays == 1 ? l10n.oneDayAgo : l10n.daysAgo(difference.inDays);
    } else if (difference.inHours > 0) {
      return difference.inHours == 1 ? l10n.oneHourAgo : l10n.hoursAgo(difference.inHours);
    } else if (difference.inMinutes > 0) {
      return difference.inMinutes == 1 ? l10n.oneMinuteAgo : l10n.minutesAgo(difference.inMinutes);
    } else {
      return l10n.justNow;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context)!;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            // Avatar
            CircleAvatar(
              radius: 28,
              backgroundColor: Colors.grey[300],
              backgroundImage: user.avatarUrl.isNotEmpty
                  ? CachedNetworkImageProvider(user.avatarUrl)
                  : null,
              child: user.avatarUrl.isEmpty
                  ? Icon(Icons.person, size: 32, color: Colors.grey[600])
                  : null,
            ),
            const SizedBox(width: 12),

            // User Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user.fullName.isNotEmpty ? user.fullName : user.username,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '@${user.username}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: isDark ? Colors.grey[400] : Colors.black54,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.block,
                        size: 12,
                        color: isDark ? Colors.grey[500] : Colors.grey[600],
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${l10n.blocked} ${_getTimeAgo(user.blockedAt, context)}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontSize: 11,
                          color: isDark ? Colors.grey[500] : Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Unblock Button
            OutlinedButton(
              onPressed: onUnblock,
              style: OutlinedButton.styleFrom(
                foregroundColor: primaryColor,
                side: BorderSide(color: primaryColor, width: 1.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              ),
              child: Text(
                l10n.unblock,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
