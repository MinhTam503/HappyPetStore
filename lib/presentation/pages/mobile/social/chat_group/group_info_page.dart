import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../../domain/entities/group_chat_entities.dart';

class GroupInfoPage extends StatefulWidget {
  final GroupConversation groupInfo;
  final String currentUserId;
  final VoidCallback onLeaveGroup;

  const GroupInfoPage({
    super.key,
    required this.groupInfo,
    required this.currentUserId,
    required this.onLeaveGroup,
  });

  @override
  State<GroupInfoPage> createState() => _GroupInfoPageState();
}

class _GroupInfoPageState extends State<GroupInfoPage> {
  final Map<String, String> _userAvatars = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserAvatars();
  }

  Future<void> _loadUserAvatars() async {
    try {
      for (final userId in widget.groupInfo.participants) {
        final profileDoc = await FirebaseFirestore.instance
            .collection('socialPetProfiles')
            .doc(userId)
            .get();
        
        if (profileDoc.exists && mounted) {
          final data = profileDoc.data();
          setState(() {
            _userAvatars[userId] = data?['avatarUrl'] ?? '';
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading user avatars: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final memberCount = widget.groupInfo.participants.length;
    final displayMembers = widget.groupInfo.participants.take(8).toList();
    final hasMore = memberCount > 8;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        iconTheme: const IconThemeData(color: Color(0xFF00A86B)),
        title: const Text(
          'Thông tin nhóm',
          style: TextStyle(
            color: Colors.black87,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF00A86B)))
          : SingleChildScrollView(
        child: Column(
          children: [
            // Group Header
            Container(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  // Group Avatar
                  CircleAvatar(
                    radius: 50,
                    backgroundColor: const Color(0xFF00A86B).withOpacity(0.1),
                    backgroundImage: widget.groupInfo.avatarUrl != null && widget.groupInfo.avatarUrl!.isNotEmpty
                        ? NetworkImage(widget.groupInfo.avatarUrl!)
                        : null,
                    child: widget.groupInfo.avatarUrl == null || widget.groupInfo.avatarUrl!.isEmpty
                        ? const Icon(Icons.group, color: Color(0xFF00A86B), size: 50)
                        : null,
                  ),
                  const SizedBox(height: 16),
                  
                  // Group Name
                  Text(
                    widget.groupInfo.name,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  
                  // Member Count
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00A86B).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.people, color: Color(0xFF00A86B), size: 16),
                        const SizedBox(width: 6),
                        Text(
                          '$memberCount ${l10n.members}',
                          style: const TextStyle(
                            color: Color(0xFF00A86B),
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const Divider(height: 1, thickness: 8, color: Color(0xFFF5F5F5)),

            // Members Section
            Container(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        l10n.members,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      if (hasMore)
                        TextButton(
                          onPressed: () => _showAllMembers(context),
                          child: const Text(
                            'Xem thêm',
                            style: TextStyle(
                              color: Color(0xFF00A86B),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  
                  // Display up to 8 members
                  ...displayMembers.map((userId) {
                    final userInfo = widget.groupInfo.participantsInfo[userId];
                    final isMe = userId == widget.currentUserId;
                    
                    return _buildMemberTile(
                      context,
                      userId: userId,
                      name: userInfo?['name'] ?? 'User',
                      avatar: _userAvatars[userId] ?? '',
                      isMe: isMe,
                    );
                  }).toList(),
                ],
              ),
            ),

            const Divider(height: 1, thickness: 8, color: Color(0xFFF5F5F5)),

            // Leave Group Button
            Container(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: widget.onLeaveGroup,
                  icon: const Icon(Icons.exit_to_app),
                  label: Text(l10n.leaveGroup),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMemberTile(
    BuildContext context, {
    required String userId,
    required String name,
    required String avatar,
    required bool isMe,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.grey[200]!, width: 0.5),
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        leading: CircleAvatar(
          radius: 24,
          backgroundColor: const Color(0xFF00A86B).withOpacity(0.1),
          backgroundImage: avatar.isNotEmpty ? NetworkImage(avatar) : null,
          child: avatar.isEmpty
              ? const Icon(Icons.person, color: Color(0xFF00A86B), size: 24)
              : null,
        ),
        title: Text(
          name,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 15,
            color: Colors.black87,
          ),
        ),
        subtitle: isMe
            ? Text(
                'Bạn',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 13,
                ),
              )
            : null,
      ),
    );
  }

  void _showAllMembers(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.5,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) {
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(20),
                ),
              ),
              child: Column(
                children: [
                  // Header
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Column(
                      children: [
                        Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.grey[300],
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const SizedBox(width: 48),
                            Text(
                              'Thành viên (${widget.groupInfo.participants.length})',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close),
                              onPressed: () => Navigator.pop(context),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),

                  // All Members List
                  Expanded(
                    child: ListView.builder(
                      controller: scrollController,
                      itemCount: widget.groupInfo.participants.length,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemBuilder: (context, index) {
                        final userId = widget.groupInfo.participants[index];
                        final userInfo = widget.groupInfo.participantsInfo[userId];
                        final isMe = userId == widget.currentUserId;

                        return _buildMemberTile(
                          context,
                          userId: userId,
                          name: userInfo?['name'] ?? 'User',
                          avatar: _userAvatars[userId] ?? '',
                          isMe: isMe,
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
