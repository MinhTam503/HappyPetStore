import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:pet_shop/domain/entities/group_chat_entities.dart';
import 'package:pet_shop/core/constants/app_constants.dart';

class CommunityGroupsAdmin extends StatefulWidget {
  const CommunityGroupsAdmin({Key? key}) : super(key: key);

  @override
  State<CommunityGroupsAdmin> createState() => _CommunityGroupsAdminState();
}

class _CommunityGroupsAdminState extends State<CommunityGroupsAdmin> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _sortBy = 'newest';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Stream<List<GroupConversation>> _getGroupsStream() {
    Query query = FirebaseFirestore.instance
        .collection('groupConversations')
        .where('isPublic', isEqualTo: true);

    // Sort
    switch (_sortBy) {
      case 'newest':
        query = query.orderBy('createdAt', descending: true);
        break;
      case 'oldest':
        query = query.orderBy('createdAt', descending: false);
        break;
      case 'mostMembers':
        query = query.orderBy('participants', descending: true);
        break;
    }

    return query.limit(100).snapshots().map((snapshot) {
      final groups = snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return GroupConversation(
          id: doc.id,
          name: data['name'] ?? '',
          avatarUrl: data['avatarUrl'],
          participants: List<String>.from(data['participants'] ?? []),
          createdBy: data['createdBy'] ?? '',
          isPublic: data['isPublic'] ?? false,
          lastMessage: data['lastMessage'],
          lastMessageTime: (data['lastMessageTime'] as Timestamp?)?.toDate() ?? DateTime.now(),
          lastMessageSenderId: data['lastMessageSenderId'],
          unreadCount: Map<String, int>.from(data['unreadCount'] ?? {}),
          createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
          participantsInfo: Map<String, dynamic>.from(data['participantsInfo'] ?? {}),
          admins: List<String>.from(data['admins'] ?? []),
        );
      }).toList();

      // Filter by search query
      if (_searchQuery.isNotEmpty) {
        return groups.where((group) {
          final name = group.name.toLowerCase();
          final query = _searchQuery.toLowerCase();
          return name.contains(query);
        }).toList();
      }

      return groups;
    });
  }

  Future<void> _deleteGroup(String groupId) async {
    try {
      // Delete all messages first
      final messagesSnapshot = await FirebaseFirestore.instance
          .collection('groupConversations')
          .doc(groupId)
          .collection('messages')
          .get();

      for (final doc in messagesSnapshot.docs) {
        await doc.reference.delete();
      }

      // Delete group
      await FirebaseFirestore.instance
          .collection('groupConversations')
          .doc(groupId)
          .delete();

      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.groupDeleted)),
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

  void _showDeleteDialog(GroupConversation group) {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.deleteGroup),
        content: Text(l10n.deleteGroupConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.cancel),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteGroup(group.id);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
  }

  void _showGroupDetails(GroupConversation group) {
    showDialog(
      context: context,
      builder: (context) => _GroupDetailsDialog(group: group),
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
                    Icon(Icons.groups_outlined, size: 32, color: primaryColor),
                    const SizedBox(width: 12),
                    Text(
                      l10n.communityGroupManagement,
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
                          hintText: l10n.searchGroups,
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
                          DropdownMenuItem(value: 'mostMembers', child: Text('Most Members')),
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

          // Groups List
          Expanded(
            child: StreamBuilder<List<GroupConversation>>(
              stream: _getGroupsStream(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                final groups = snapshot.data ?? [];

                if (groups.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.groups_outlined, size: 64, color: Colors.grey[400]),
                        const SizedBox(height: 16),
                        Text(
                          l10n.noGroupsFound,
                          style: theme.textTheme.titleLarge?.copyWith(color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(24),
                  itemCount: groups.length + 1,
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Text(
                          l10n.showingResults(groups.length.toString()),
                          style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
                        ),
                      );
                    }

                    final group = groups[index - 1];
                    return _GroupCard(
                      group: group,
                      onView: () => _showGroupDetails(group),
                      onDelete: () => _showDeleteDialog(group),
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

class _GroupCard extends StatelessWidget {
  final GroupConversation group;
  final VoidCallback onView;
  final VoidCallback onDelete;

  const _GroupCard({
    required this.group,
    required this.onView,
    required this.onDelete,
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
                backgroundImage: group.avatarUrl != null && group.avatarUrl!.isNotEmpty
                    ? NetworkImage(group.avatarUrl!)
                    : null,
                child: group.avatarUrl == null || group.avatarUrl!.isEmpty
                    ? Icon(Icons.groups, size: 40, color: primaryColor)
                    : null,
              ),
              const SizedBox(width: 16),
              
              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            group.name,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: primaryColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.public, size: 12, color: primaryColor),
                              const SizedBox(width: 4),
                              Text(
                                l10n.publicGroup,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: primaryColor,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.people, size: 16, color: Colors.grey[600]),
                        const SizedBox(width: 4),
                        Text(
                          '${group.participants.length} ${l10n.members}',
                          style: TextStyle(color: Colors.grey[600], fontSize: 13),
                        ),
                        const SizedBox(width: 16),
                        Icon(Icons.calendar_today, size: 16, color: Colors.grey[600]),
                        const SizedBox(width: 4),
                        Text(
                          DateFormat('dd/MM/yyyy').format(group.createdAt),
                          style: TextStyle(color: Colors.grey[600], fontSize: 13),
                        ),
                      ],
                    ),
                    if (group.lastMessage != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        group.lastMessage!,
                        style: TextStyle(color: Colors.grey[500], fontSize: 12),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              
              // Actions
              Column(
                children: [
                  IconButton(
                    icon: const Icon(Icons.visibility),
                    onPressed: onView,
                    tooltip: l10n.viewGroup,
                    color: primaryColor,
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: onDelete,
                    tooltip: l10n.deleteGroup,
                    color: Colors.red,
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

class _GroupDetailsDialog extends StatefulWidget {
  final GroupConversation group;

  const _GroupDetailsDialog({required this.group});

  @override
  State<_GroupDetailsDialog> createState() => _GroupDetailsDialogState();
}

class _GroupDetailsDialogState extends State<_GroupDetailsDialog> {
  int _messageCount = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadMessageCount();
  }

  Future<void> _loadMessageCount() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('groupConversations')
          .doc(widget.group.id)
          .collection('messages')
          .count()
          .get();
      
      if (mounted) {
        setState(() {
          _messageCount = snapshot.count ?? 0;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Dialog(
      child: Container(
        width: 700,
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
                    l10n.groupDetails,
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
                      backgroundImage: widget.group.avatarUrl != null && widget.group.avatarUrl!.isNotEmpty
                          ? NetworkImage(widget.group.avatarUrl!)
                          : null,
                      child: widget.group.avatarUrl == null || widget.group.avatarUrl!.isEmpty
                          ? Icon(Icons.groups, size: 60, color: primaryColor)
                          : null,
                    ),
                    const SizedBox(height: 16),
                    
                    // Group name
                    Text(
                      widget.group.name,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: primaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        l10n.publicGroup,
                        style: TextStyle(
                          color: primaryColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    
                    // Stats
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _StatColumn(
                          icon: Icons.people,
                          label: l10n.members,
                          value: widget.group.participants.length.toString(),
                        ),
                        _StatColumn(
                          icon: Icons.message,
                          label: l10n.totalMessages,
                          value: _loading ? '...' : _messageCount.toString(),
                        ),
                        _StatColumn(
                          icon: Icons.admin_panel_settings,
                          label: 'Admins',
                          value: widget.group.admins.length.toString(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    const Divider(),
                    const SizedBox(height: 16),
                    
                    // Info
                    _InfoRow(
                      icon: Icons.calendar_today,
                      label: l10n.createdDate,
                      value: DateFormat('dd/MM/yyyy HH:mm').format(widget.group.createdAt),
                    ),
                    if (widget.group.lastMessage != null) ...[
                      _InfoRow(
                        icon: Icons.access_time,
                        label: l10n.lastActivity,
                        value: DateFormat('dd/MM/yyyy HH:mm').format(widget.group.lastMessageTime),
                      ),
                      _InfoRow(
                        icon: Icons.chat_bubble_outline,
                        label: 'Last Message',
                        value: widget.group.lastMessage!,
                      ),
                    ],
                    const SizedBox(height: 24),
                    
                    // Members list preview
                    if (widget.group.participantsInfo.isNotEmpty) ...[
                      const Divider(),
                      const SizedBox(height: 16),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          '${l10n.members} (${widget.group.participants.length})',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      ...widget.group.participants.take(5).map((userId) {
                        final info = widget.group.participantsInfo[userId];
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundImage: info?['avatar'] != null && info!['avatar'].toString().isNotEmpty
                                ? NetworkImage(info['avatar'])
                                : null,
                            child: info?['avatar'] == null || info!['avatar'].toString().isEmpty
                                ? const Icon(Icons.person)
                                : null,
                          ),
                          title: Text(info?['name'] ?? 'User'),
                          trailing: widget.group.admins.contains(userId)
                              ? const Chip(
                                  label: Text('Admin', style: TextStyle(fontSize: 11)),
                                  padding: EdgeInsets.zero,
                                )
                              : null,
                        );
                      }).toList(),
                      if (widget.group.participants.length > 5)
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Text(
                            '...and ${widget.group.participants.length - 5} more',
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                        ),
                    ],
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
  final IconData icon;
  final String label;
  final String value;

  const _StatColumn({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, size: 32, color: primaryColor),
        const SizedBox(height: 8),
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
        crossAxisAlignment: CrossAxisAlignment.start,
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
