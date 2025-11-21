import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
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
      final messagesSnapshot = await FirebaseFirestore.instance
          .collection('groupConversations')
          .doc(groupId)
          .collection('messages')
          .get();

      for (final doc in messagesSnapshot.docs) {
        await doc.reference.delete();
      }

      await FirebaseFirestore.instance
          .collection('groupConversations')
          .doc(groupId)
          .delete();

      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.groupDeleted),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showGroupDetailsDialog(GroupConversation group) {
    showDialog(
      context: context,
      builder: (context) => _GroupDetailsDialog(
        group: group,
        onDelete: () => _showDeleteDialog(group.id),
      ),
    );
  }

  void _showDeleteDialog(String groupId) {
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
              Navigator.pop(context); // Close details dialog too
              _deleteGroup(groupId);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Column(
        children: [
          // Header with Search and Sort
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: theme.cardColor,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
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
                DropdownButton<String>(
                  value: _sortBy,
                  items: [
                    DropdownMenuItem(value: 'newest', child: Text(l10n.newest)),
                    DropdownMenuItem(value: 'oldest', child: Text(l10n.oldest)),
                    DropdownMenuItem(value: 'mostMembers', child: Text(l10n.mostFollowers)),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        _sortBy = value;
                      });
                    }
                  },
                ),
              ],
            ),
          ),

          // Groups List
          Expanded(
            child: StreamBuilder<List<GroupConversation>>(
              stream: _getGroupsStream(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
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
                          style: TextStyle(color: Colors.grey[600], fontSize: 16),
                        ),
                      ],
                    ),
                  );
                }

                return GridView.builder(
                  padding: const EdgeInsets.all(24),
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 400,
                    childAspectRatio: 1.5,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                  ),
                  itemCount: groups.length,
                  itemBuilder: (context, index) {
                    return _GroupCard(
                      group: groups[index],
                      onTap: () => _showGroupDetailsDialog(groups[index]),
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
  final VoidCallback onTap;

  const _GroupCard({
    required this.group,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundImage: group.avatarUrl != null
                        ? NetworkImage(group.avatarUrl!)
                        : null,
                    child: group.avatarUrl == null
                        ? const Icon(Icons.groups, size: 30)
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          group.name,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.people, size: 14, color: Colors.grey[600]),
                            const SizedBox(width: 4),
                            Text(
                              '${group.participants.length} ${l10n.members}',
                              style: TextStyle(color: Colors.grey[600], fontSize: 12),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const Spacer(),
              if (group.lastMessage != null) ...[
                const Divider(),
                Text(
                  group.lastMessage!,
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    DateFormat('dd/MM/yyyy').format(group.createdAt),
                    style: TextStyle(color: Colors.grey[500], fontSize: 11),
                  ),
                  Icon(Icons.chevron_right, color: primaryColor),
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
  final VoidCallback onDelete;

  const _GroupDetailsDialog({
    required this.group,
    required this.onDelete,
  });

  @override
  State<_GroupDetailsDialog> createState() => _GroupDetailsDialogState();
}

class _GroupDetailsDialogState extends State<_GroupDetailsDialog> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 900,
        height: 700,
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 40,
                  backgroundImage: widget.group.avatarUrl != null
                      ? NetworkImage(widget.group.avatarUrl!)
                      : null,
                  child: widget.group.avatarUrl == null
                      ? const Icon(Icons.groups, size: 40)
                      : null,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.group.name,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${widget.group.participants.length} ${l10n.members}',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TabBar(
              controller: _tabController,
              labelColor: primaryColor,
              unselectedLabelColor: Colors.grey[600],
              indicatorColor: primaryColor,
              tabs: [
                Tab(icon: Icon(Icons.info_outline), text: l10n.groupInfo),
                Tab(icon: Icon(Icons.people_outline), text: l10n.groupMembers),
                Tab(icon: Icon(Icons.message_outlined), text: l10n.messagesReadOnly),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _GroupInfoTab(group: widget.group),
                  _GroupMembersTab(group: widget.group),
                  _GroupMessagesTab(groupId: widget.group.id),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                ElevatedButton.icon(
                  onPressed: widget.onDelete,
                  icon: const Icon(Icons.delete),
                  label: Text(l10n.deleteGroup),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// Group Info Tab with Edit Capabilities
class _GroupInfoTab extends StatefulWidget {
  final GroupConversation group;

  const _GroupInfoTab({required this.group});

  @override
  State<_GroupInfoTab> createState() => _GroupInfoTabState();
}

class _GroupInfoTabState extends State<_GroupInfoTab> {
  final TextEditingController _nameController = TextEditingController();
  bool _isEditing = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nameController.text = widget.group.name;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _updateGroupName() async {
    if (_nameController.text.trim().isEmpty) return;

    setState(() => _isLoading = true);

    try {
      await FirebaseFirestore.instance
          .collection('groupConversations')
          .doc(widget.group.id)
          .update({'name': _nameController.text.trim()});

      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.groupNameUpdated),
            backgroundColor: Colors.green,
          ),
        );
        setState(() => _isEditing = false);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _updateGroupAvatar() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);

    if (image == null) return;

    setState(() => _isLoading = true);

    try {
      final l10n = AppLocalizations.of(context)!;

      // Delete old avatar if exists
      if (widget.group.avatarUrl != null) {
        try {
          final oldRef = FirebaseStorage.instance.refFromURL(widget.group.avatarUrl!);
          await oldRef.delete();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(l10n.deleteOldAvatar)),
            );
          }
        } catch (e) {
          print('Error deleting old avatar: $e');
        }
      }

      // Upload new avatar
      final String fileName = '${widget.group.id}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final Reference storageRef = FirebaseStorage.instance
          .ref()
          .child('avatar_chat_group')
          .child(fileName);

      final File file = File(image.path);
      await storageRef.putFile(file);
      final String downloadUrl = await storageRef.getDownloadURL();

      // Update Firestore
      await FirebaseFirestore.instance
          .collection('groupConversations')
          .doc(widget.group.id)
          .update({'avatarUrl': downloadUrl});

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.groupAvatarUpdated),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Group Avatar
          Center(
            child: Stack(
              children: [
                CircleAvatar(
                  radius: 60,
                  backgroundImage: widget.group.avatarUrl != null
                      ? NetworkImage(widget.group.avatarUrl!)
                      : null,
                  child: widget.group.avatarUrl == null
                      ? const Icon(Icons.groups, size: 60)
                      : null,
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: IconButton(
                    onPressed: _isLoading ? null : _updateGroupAvatar,
                    icon: const Icon(Icons.camera_alt),
                    style: IconButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Group Name
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _nameController,
                  enabled: _isEditing,
                  decoration: InputDecoration(
                    labelText: l10n.groupName,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              if (!_isEditing)
                IconButton(
                  onPressed: () => setState(() => _isEditing = true),
                  icon: const Icon(Icons.edit),
                )
              else ...[
                IconButton(
                  onPressed: _isLoading ? null : _updateGroupName,
                  icon: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.check, color: Colors.green),
                ),
                IconButton(
                  onPressed: () {
                    setState(() {
                      _isEditing = false;
                      _nameController.text = widget.group.name;
                    });
                  },
                  icon: const Icon(Icons.close, color: Colors.red),
                ),
              ],
            ],
          ),
          const SizedBox(height: 16),

          // Group Details
          _InfoRow(
            label: l10n.createdDate,
            value: DateFormat('dd/MM/yyyy HH:mm').format(widget.group.createdAt),
          ),
          _InfoRow(
            label: l10n.groupType,
            value: widget.group.isPublic ? l10n.publicGroup : l10n.privateGroup,
          ),
          _InfoRow(
            label: l10n.members,
            value: widget.group.participants.length.toString(),
          ),
          _InfoRow(
            label: l10n.admin,
            value: widget.group.admins.length.toString(),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 14,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}

// Group Members Tab with Role Management
class _GroupMembersTab extends StatelessWidget {
  final GroupConversation group;

  const _GroupMembersTab({required this.group});

  Future<void> _removeMember(BuildContext context, String userId) async {
    final l10n = AppLocalizations.of(context)!;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.removeUser),
        content: Text(l10n.removeUserConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final updatedParticipants = List<String>.from(group.participants)
        ..remove(userId);
      final updatedAdmins = List<String>.from(group.admins)..remove(userId);
      final updatedParticipantsInfo = Map<String, dynamic>.from(group.participantsInfo)
        ..remove(userId);

      await FirebaseFirestore.instance
          .collection('groupConversations')
          .doc(group.id)
          .update({
        'participants': updatedParticipants,
        'admins': updatedAdmins,
        'participantsInfo': updatedParticipantsInfo,
      });

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.userRemoved),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _changeRole(BuildContext context, String userId, bool isCurrentlyAdmin) async {
    final l10n = AppLocalizations.of(context)!;

    final role = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.changeRole),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(l10n.admin),
              leading: Radio<String>(
                value: 'admin',
                groupValue: isCurrentlyAdmin ? 'admin' : 'member',
                onChanged: (value) => Navigator.pop(context, value),
              ),
            ),
            ListTile(
              title: Text(l10n.member),
              leading: Radio<String>(
                value: 'member',
                groupValue: isCurrentlyAdmin ? 'admin' : 'member',
                onChanged: (value) => Navigator.pop(context, value),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.cancel),
          ),
        ],
      ),
    );

    if (role == null) return;

    try {
      final updatedAdmins = List<String>.from(group.admins);
      if (role == 'admin' && !updatedAdmins.contains(userId)) {
        updatedAdmins.add(userId);
      } else if (role == 'member') {
        updatedAdmins.remove(userId);
      }

      await FirebaseFirestore.instance
          .collection('groupConversations')
          .doc(group.id)
          .update({'admins': updatedAdmins});

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.roleChanged),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return ListView.builder(
      itemCount: group.participants.length,
      itemBuilder: (context, index) {
        final userId = group.participants[index];
        final userInfo = group.participantsInfo[userId] as Map<String, dynamic>?;
        final isAdmin = group.admins.contains(userId);
        final isCreator = userId == group.createdBy;

        return Card(
          margin: const EdgeInsets.symmetric(vertical: 4),
          child: ListTile(
            leading: CircleAvatar(
              backgroundImage: userInfo?['avatar'] != null
                  ? NetworkImage(userInfo!['avatar'])
                  : null,
              child: userInfo?['avatar'] == null
                  ? Text(userInfo?['name']?[0] ?? 'U')
                  : null,
            ),
            title: Text(userInfo?['name'] ?? 'Unknown User'),
            subtitle: Text(
              isCreator
                  ? 'Creator & ${l10n.admin}'
                  : (isAdmin ? l10n.admin : l10n.member),
              style: TextStyle(
                color: isCreator || isAdmin ? primaryColor : Colors.grey[600],
                fontWeight: isCreator || isAdmin ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  onPressed: () => _changeRole(context, userId, isAdmin),
                  icon: const Icon(Icons.admin_panel_settings),
                  tooltip: l10n.changeRole,
                ),
                IconButton(
                  onPressed: () => _removeMember(context, userId),
                  icon: const Icon(Icons.remove_circle, color: Colors.red),
                  tooltip: l10n.removeUser,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// Group Messages Tab (Read-Only)
class _GroupMessagesTab extends StatelessWidget {
  final String groupId;

  const _GroupMessagesTab({required this.groupId});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.orange.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              const Icon(Icons.info_outline, color: Colors.orange),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  l10n.cannotSendMessage,
                  style: const TextStyle(color: Colors.orange),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('groupConversations')
                .doc(groupId)
                .collection('messages')
                .orderBy('timestamp', descending: true)
                .limit(50)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              }

              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final messages = snapshot.data?.docs ?? [];

              if (messages.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.message_outlined, size: 64, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text(
                        l10n.noMessagesYet,
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ],
                  ),
                );
              }

              return ListView.builder(
                reverse: true,
                itemCount: messages.length,
                itemBuilder: (context, index) {
                  final message = messages[index].data() as Map<String, dynamic>;
                  final senderName = message['senderName'] ?? 'Unknown';
                  final text = message['text'] ?? '';
                  final timestamp = (message['timestamp'] as Timestamp?)?.toDate();

                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundImage: message['senderAvatar'] != null
                            ? NetworkImage(message['senderAvatar'])
                            : null,
                        child: message['senderAvatar'] == null
                            ? Text(senderName[0])
                            : null,
                      ),
                      title: Text(senderName),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(text),
                          if (timestamp != null)
                            Text(
                              DateFormat('dd/MM/yyyy HH:mm').format(timestamp),
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey[500],
                              ),
                            ),
                        ],
                      ),
                      isThreeLine: true,
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
