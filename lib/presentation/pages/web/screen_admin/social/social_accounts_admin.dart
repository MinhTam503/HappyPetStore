import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:pet_shop/domain/entities/social_pet_profile.dart';
import 'package:pet_shop/data/models/social_pet_profile_model.dart';
import 'package:pet_shop/core/constants/app_constants.dart';

class SocialAccountsAdmin extends StatefulWidget {
  const SocialAccountsAdmin({Key? key}) : super(key: key);

  @override
  State<SocialAccountsAdmin> createState() => _SocialAccountsAdminState();
}

class _SocialAccountsAdminState extends State<SocialAccountsAdmin> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _sortBy = 'mostFollowers';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Stream<List<SocialPetProfile>> _getAccountsStream() {
    Query query = FirebaseFirestore.instance.collection('socialPetProfiles');

    // Sort
    switch (_sortBy) {
      case 'newest':
        query = query.orderBy('createdAt', descending: true);
        break;
      case 'oldest':
        query = query.orderBy('createdAt', descending: false);
        break;
      case 'mostFollowers':
        query = query.orderBy('followers', descending: true);
        break;
      case 'mostPosts':
        query = query.orderBy('stats.posts', descending: true);
        break;
    }

    return query.limit(100).snapshots().map((snapshot) {
      final accounts = snapshot.docs
          .map((doc) => SocialPetProfileModel.fromFirestore(doc))
          .toList();

      // Filter by search query
      if (_searchQuery.isNotEmpty) {
        return accounts.where((account) {
          final name = (account.displayName ?? account.petName).toLowerCase();
          final query = _searchQuery.toLowerCase();
          return name.contains(query) || account.email?.toLowerCase().contains(query) == true;
        }).toList();
      }

      return accounts;
    });
  }

  Future<void> _toggleAccountStatus(String accountId, bool isLocked) async {
    try {
      await FirebaseFirestore.instance
          .collection('socialPetProfiles')
          .doc(accountId)
          .update({'isLocked': !isLocked});
      
      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(!isLocked ? l10n.accountLocked : l10n.accountUnlocked),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  void _showLockDialog(SocialPetProfile account, bool isLocked) {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isLocked ? l10n.unlockAccount : l10n.lockAccount),
        content: Text(isLocked ? l10n.unlockAccountConfirm : l10n.lockAccountConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.cancel),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _toggleAccountStatus(account.id, isLocked);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: isLocked ? primaryColor : Colors.orange,
            ),
            child: Text(isLocked ? 'Unlock' : 'Lock'),
          ),
        ],
      ),
    );
  }

  void _showAccountDetails(SocialPetProfile account) {
    showDialog(
      context: context,
      builder: (context) => _AccountDetailsDialog(account: account),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Scaffold(
      body: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: theme.cardColor,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.people_outlined, size: 32, color: primaryColor),
                    const SizedBox(width: 12),
                    Text(
                      l10n.accountManagement,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: l10n.searchAccounts,
                          prefixIcon: const Icon(Icons.search),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: theme.scaffoldBackgroundColor,
                        ),
                        onChanged: (value) {
                          setState(() {
                            _searchQuery = value;
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _sortBy,
                        decoration: InputDecoration(
                          labelText: l10n.sortBy,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: theme.scaffoldBackgroundColor,
                        ),
                        items: [
                          DropdownMenuItem(value: 'newest', child: Text(l10n.newest)),
                          DropdownMenuItem(value: 'oldest', child: Text(l10n.oldest)),
                          DropdownMenuItem(value: 'mostFollowers', child: Text(l10n.mostFollowers)),
                          DropdownMenuItem(value: 'mostPosts', child: Text('Most Posts')),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            setState(() {
                              _sortBy = value;
                            });
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Accounts List
          Expanded(
            child: StreamBuilder<List<SocialPetProfile>>(
              stream: _getAccountsStream(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                final accounts = snapshot.data ?? [];

                if (accounts.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.people_outlined, size: 64, color: Colors.grey[400]),
                        const SizedBox(height: 16),
                        Text(
                          l10n.noAccountsFound,
                          style: theme.textTheme.titleLarge?.copyWith(color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(24),
                  itemCount: accounts.length + 1,
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Text(
                          l10n.showingResults(accounts.length.toString()),
                          style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
                        ),
                      );
                    }

                    final account = accounts[index - 1];
                    return _AccountCard(
                      account: account,
                      onView: () => _showAccountDetails(account),
                      onToggleStatus: () {
                        // Get lock status from Firestore
                        FirebaseFirestore.instance
                            .collection('socialPetProfiles')
                            .doc(account.id)
                            .get()
                            .then((doc) {
                          final isLocked = doc.data()?['isLocked'] ?? false;
                          _showLockDialog(account, isLocked);
                        });
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _AccountCard extends StatelessWidget {
  final SocialPetProfile account;
  final VoidCallback onView;
  final VoidCallback onToggleStatus;

  const _AccountCard({
    required this.account,
    required this.onView,
    required this.onToggleStatus,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      child: InkWell(
        onTap: onView,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Avatar
              CircleAvatar(
                radius: 40,
                backgroundColor: primaryColor.withOpacity(0.1),
                backgroundImage: account.avatarUrl.isNotEmpty
                    ? NetworkImage(account.avatarUrl)
                    : null,
                child: account.avatarUrl.isEmpty
                    ? Icon(Icons.person, size: 40, color: primaryColor)
                    : null,
              ),
              const SizedBox(width: 16),
              
              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      account.displayName ?? account.petName,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (account.email != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        account.email!,
                        style: TextStyle(color: Colors.grey[600], fontSize: 13),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _StatChip(
                          icon: Icons.article,
                          label: account.stats.posts.toString(),
                        ),
                        const SizedBox(width: 8),
                        _StatChip(
                          icon: Icons.people,
                          label: account.followerCount.toString(),
                        ),
                        const SizedBox(width: 8),
                        _StatChip(
                          icon: Icons.person_add,
                          label: account.followingCount.toString(),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              
              // Actions
              Column(
                children: [
                  IconButton(
                    icon: const Icon(Icons.visibility),
                    onPressed: onView,
                    tooltip: l10n.viewAccount,
                    color: primaryColor,
                  ),
                  IconButton(
                    icon: const Icon(Icons.lock_outline),
                    onPressed: onToggleStatus,
                    tooltip: l10n.lockAccount,
                    color: Colors.orange,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _StatChip({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: primaryColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: primaryColor),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(color: primaryColor, fontSize: 12, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}

class _AccountDetailsDialog extends StatelessWidget {
  final SocialPetProfile account;

  const _AccountDetailsDialog({required this.account});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Dialog(
      child: Container(
        width: 600,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.8,
        ),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: primaryColor,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              ),
              child: Row(
                children: [
                  Text(
                    l10n.accountDetails,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            
            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    // Avatar
                    CircleAvatar(
                      radius: 60,
                      backgroundColor: primaryColor.withOpacity(0.1),
                      backgroundImage: account.avatarUrl.isNotEmpty
                          ? NetworkImage(account.avatarUrl)
                          : null,
                      child: account.avatarUrl.isEmpty
                          ? Icon(Icons.person, size: 60, color: primaryColor)
                          : null,
                    ),
                    const SizedBox(height: 16),
                    
                    // Name
                    Text(
                      account.displayName ?? account.petName,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (account.bio.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        account.bio,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ],
                    const SizedBox(height: 24),
                    
                    // Stats
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _StatColumn(
                          label: l10n.post,
                          value: account.stats.posts.toString(),
                        ),
                        _StatColumn(
                          label: l10n.userFollowers,
                          value: account.followerCount.toString(),
                        ),
                        _StatColumn(
                          label: l10n.userFollowing,
                          value: account.followingCount.toString(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    
                    // Contact Info
                    if (account.email != null || account.phone != null || account.website != null) ...[
                      const Divider(),
                      const SizedBox(height: 16),
                      if (account.email != null)
                        _InfoRow(
                          icon: Icons.email,
                          label: l10n.email,
                          value: account.email!,
                        ),
                      if (account.phone != null)
                        _InfoRow(
                          icon: Icons.phone,
                          label: l10n.phone,
                          value: account.phone!,
                        ),
                      if (account.website != null)
                        _InfoRow(
                          icon: Icons.language,
                          label: 'Website',
                          value: account.website!,
                        ),
                      const SizedBox(height: 16),
                      const Divider(),
                    ],
                    const SizedBox(height: 16),
                    
                    // Timestamps
                    _InfoRow(
                      icon: Icons.calendar_today,
                      label: l10n.createdDate,
                      value: DateFormat('dd/MM/yyyy HH:mm').format(account.createdAt),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatColumn extends StatelessWidget {
  final String label;
  final String value;

  const _StatColumn({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: primaryColor,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(color: Colors.grey[600], fontSize: 13),
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 20, color: primaryColor),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
