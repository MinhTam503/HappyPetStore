import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:pet_shop/presentation/bloc/social/social_bloc.dart';
import 'package:pet_shop/presentation/bloc/social/social_event.dart';
import 'package:pet_shop/presentation/bloc/social/social_state.dart';

class FollowersListPage extends StatefulWidget {
  final String userId;
  final bool isFollowersMode; // true = followers, false = following

  const FollowersListPage({
    Key? key,
    required this.userId,
    required this.isFollowersMode,
  }) : super(key: key);

  @override
  State<FollowersListPage> createState() => _FollowersListPageState();
}

class _FollowersListPageState extends State<FollowersListPage> {
  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() {
    context.read<SocialBloc>().add(LoadUserProfile(widget.userId));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.isFollowersMode ? l10n.followersList : l10n.followingList,
        ),
      ),
      body: BlocBuilder<SocialBloc, SocialState>(
        builder: (context, state) {
          if (state is SocialLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state is SocialError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  Text(state.message),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _loadData,
                    child: Text(l10n.retry),
                  ),
                ],
              ),
            );
          }

          if (state is! SocialLoaded) {
            return const SizedBox.shrink();
          }

          final profile = state.profileCache[widget.userId];
          if (profile == null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.person_off, size: 64),
                  const SizedBox(height: 16),
                  Text(l10n.userNotFound),
                ],
              ),
            );
          }

          final userIds =
              widget.isFollowersMode ? profile.followers : profile.following;

          if (userIds.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    widget.isFollowersMode
                        ? Icons.people_outline
                        : Icons.person_add_outlined,
                    size: 64,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    widget.isFollowersMode
                        ? l10n.noFollowers
                        : l10n.noFollowing,
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ],
              ),
            );
          }

          // TODO: Load full user profiles for each userId
          // For now, just show user IDs
          return ListView.builder(
            itemCount: userIds.length,
            itemBuilder: (context, index) {
              final userId = userIds[index];
              final userProfile = state.profileCache[userId];

              return ListTile(
                leading: CircleAvatar(
                  backgroundImage: userProfile?.avatarUrl != null &&
                          userProfile!.avatarUrl.isNotEmpty
                      ? NetworkImage(userProfile.avatarUrl)
                      : null,
                  child: userProfile?.avatarUrl == null
                      ? const Icon(Icons.person)
                      : null,
                ),
                title: Text(
                  userProfile?.displayName ??
                      userProfile?.petName ??
                      'User $userId',
                ),
                subtitle: userProfile?.bio.isNotEmpty == true
                    ? Text(userProfile!.bio,
                        maxLines: 1, overflow: TextOverflow.ellipsis)
                    : null,
                trailing: _buildFollowButton(context, userId, state),
                onTap: () {
                  Navigator.pushNamed(
                    context,
                    '/social/profile',
                    arguments: userId,
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildFollowButton(
      BuildContext context, String userId, SocialLoaded state) {
    final l10n = AppLocalizations.of(context)!;
    final isFollowing = state.followingStatus[userId] ?? false;

    return OutlinedButton(
      onPressed: () {
        if (isFollowing) {
          context.read<SocialBloc>().add(UnfollowPet(userId));
        } else {
          context.read<SocialBloc>().add(FollowPet(userId));
        }
      },
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        minimumSize: const Size(80, 32),
      ),
      child: Text(
        isFollowing ? l10n.unfollow : l10n.follow,
        style: const TextStyle(fontSize: 12),
      ),
    );
  }
}
