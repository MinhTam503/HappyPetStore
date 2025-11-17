import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:pet_shop/core/constants/app_constants.dart';
import 'package:pet_shop/domain/entities/social_pet_profile.dart';
import 'package:pet_shop/presentation/bloc/social/social_bloc.dart';
import 'package:pet_shop/presentation/bloc/social/social_event.dart';
import 'package:pet_shop/presentation/bloc/social/social_state.dart';

class SocialSearchPage extends StatefulWidget {
  const SocialSearchPage({Key? key}) : super(key: key);

  @override
  State<SocialSearchPage> createState() => _SocialSearchPageState();
}

class _SocialSearchPageState extends State<SocialSearchPage> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  List<String> _recentSearches = [];
  List<String> _trendingTags = [];

  @override
  void initState() {
    super.initState();
    _loadRecentSearches();
    context.read<SocialBloc>().add(const LoadTrendingTags());
  }

  void _loadRecentSearches() {
    // TODO: Load from shared preferences
    _recentSearches = [];
  }

  void _saveSearch(String query) {
    if (query.isEmpty) return;
    setState(() {
      _recentSearches.remove(query);
      _recentSearches.insert(0, query);
      if (_recentSearches.length > 10) {
        _recentSearches = _recentSearches.sublist(0, 10);
      }
    });
    // TODO: Save to shared preferences
  }

  void _clearRecentSearches() {
    setState(() {
      _recentSearches.clear();
    });
    // TODO: Clear from shared preferences
  }

  void _performSearch(String query) {
    if (query.trim().isEmpty) return;
    _saveSearch(query);
    context.read<SocialBloc>().add(SearchPets(query.trim()));
    _searchFocusNode.unfocus();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? theme.scaffoldBackgroundColor : secondaryColor,
      appBar: AppBar(
        backgroundColor: isDark ? theme.scaffoldBackgroundColor : secondaryColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(25),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.3),
                spreadRadius: 1,
                blurRadius: 5,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: TextField(
            controller: _searchController,
            focusNode: _searchFocusNode,
            autofocus: true,
            decoration: InputDecoration(
              hintText: l10n?.searchPets ?? 'Search pets, people...',
              hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 20),
                      color: Colors.grey[600],
                      onPressed: () {
                        setState(() {
                          _searchController.clear();
                        });
                      },
                    )
                  : null,
            ),
            style: const TextStyle(fontSize: 15),
            textInputAction: TextInputAction.search,
            onSubmitted: _performSearch,
            onChanged: (value) {
              if (value.length >= 2) {
                // Debounce search
                Future.delayed(const Duration(milliseconds: 500), () {
                  if (_searchController.text == value) {
                    _performSearch(value);
                  }
                });
              }
            },
          ),
        ),
      ),
      body: BlocBuilder<SocialBloc, SocialState>(
        builder: (context, state) {
          // Show search results
          if (state is SocialSearchResults) {
            return _buildSearchResults(context, state.results);
          }

          // Show loading
          if (state is SocialLoading) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          // Show default suggestions
          if (state is SocialLoaded) {
            _trendingTags = state.trendingTags;
          }

          return _buildSuggestions(context, isDark);
        },
      ),
    );
  }

  Widget _buildSuggestions(BuildContext context, bool isDark) {
    final l10n = AppLocalizations.of(context);

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        // Recent Searches
        if (_recentSearches.isNotEmpty) ...[
          Container(
            decoration: BoxDecoration(
              color: isDark ? Colors.grey[850] : Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  spreadRadius: 1,
                  blurRadius: 5,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      Icon(
                        Icons.history,
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        l10n?.recentSearches ?? 'Recent Searches',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: isDark ? Colors.grey[300] : Colors.grey[800],
                        ),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: _clearRecentSearches,
                        child: Text(
                          l10n?.clearAll ?? 'Clear All',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.red[400],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Divider(height: 1, color: Colors.grey.withOpacity(0.2)),
                ...(_recentSearches.asMap().entries.map((entry) {
                  final index = entry.key;
                  final search = entry.value;
                  return Container(
                    decoration: BoxDecoration(
                      border: index < _recentSearches.length - 1
                          ? Border(
                              bottom: BorderSide(
                                color: Colors.grey.withOpacity(0.2),
                              ),
                            )
                          : null,
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      leading: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: (isDark ? darkPrimaryColor : primaryColor).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.history,
                          color: isDark ? darkPrimaryColor : primaryColor,
                          size: 20,
                        ),
                      ),
                      title: Text(
                        search,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: isDark ? Colors.grey[300] : Colors.black87,
                        ),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.north_west,
                            color: Colors.grey[400],
                            size: 16,
                          ),
                          IconButton(
                            icon: Icon(Icons.close, size: 18, color: Colors.grey[500]),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            onPressed: () {
                              setState(() {
                                _recentSearches.remove(search);
                              });
                            },
                          ),
                        ],
                      ),
                      onTap: () {
                        _searchController.text = search;
                        _performSearch(search);
                      },
                    ),
                  );
                })),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],

        // Trending Tags
        if (_trendingTags.isNotEmpty) ...[
          Container(
            decoration: BoxDecoration(
              color: isDark ? Colors.grey[850] : Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  spreadRadius: 1,
                  blurRadius: 5,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      Icon(
                        Icons.local_fire_department,
                        color: Colors.orange[700],
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        l10n?.trending ?? 'Trending',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: isDark ? Colors.grey[300] : Colors.grey[800],
                        ),
                      ),
                    ],
                  ),
                ),
                Divider(height: 1, color: Colors.grey.withOpacity(0.2)),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _trendingTags.map((tag) {
                      return ActionChip(
                        avatar: Icon(
                          Icons.tag,
                          size: 16,
                          color: isDark ? darkPrimaryColor : primaryColor,
                        ),
                        label: Text(tag),
                        backgroundColor: (isDark ? darkPrimaryColor : primaryColor).withOpacity(0.1),
                        labelStyle: TextStyle(
                          color: isDark ? darkPrimaryColor : primaryColor,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                        onPressed: () {
                          _searchController.text = tag;
                          _performSearch(tag);
                        },
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],

        // Search Tips
        Container(
          decoration: BoxDecoration(
            color: isDark ? Colors.grey[850] : Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.1),
                spreadRadius: 1,
                blurRadius: 5,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Icon(
                      Icons.lightbulb_outline,
                      color: Colors.amber[700],
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      l10n?.searchTips ?? 'Search Tips',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: isDark ? Colors.grey[300] : Colors.grey[800],
                      ),
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: Colors.grey.withOpacity(0.2)),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    _buildSearchTip(
                      Icons.pets,
                      l10n?.searchByPetName ?? 'Search by pet name',
                      'Try "Golden", "Luna", "Max"',
                      isDark,
                    ),
                    const SizedBox(height: 12),
                    _buildSearchTip(
                      Icons.category,
                      l10n?.searchByBreed ?? 'Search by breed',
                      'Try "Husky", "Persian", "Beagle"',
                      isDark,
                    ),
                    const SizedBox(height: 12),
                    _buildSearchTip(
                      Icons.tag,
                      l10n?.searchByTag ?? 'Search by tag',
                      'Try "#cute", "#funny", "#playful"',
                      isDark,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSearchTip(IconData icon, String title, String example, bool isDark) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: (isDark ? darkPrimaryColor : primaryColor).withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            size: 18,
            color: isDark ? darkPrimaryColor : primaryColor,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.grey[300] : Colors.black87,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                example,
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.grey[500] : Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSearchResults(
      BuildContext context, List<SocialPetProfile> results) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (results.isEmpty) {
      return Center(
        child: Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: isDark ? Colors.grey[850] : Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.1),
                spreadRadius: 1,
                blurRadius: 5,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.search_off,
                size: 80,
                color: Colors.grey[400],
              ),
              const SizedBox(height: 16),
              Text(
                l10n?.noResults ?? 'Không tìm thấy người dùng',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.grey[300] : Colors.grey[800],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Hãy thử tìm kiếm bằng tên, giống loại, hoặc thông tin khác',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: results.length,
      itemBuilder: (context, index) {
        final profile = results[index];
        final isLastItem = index == results.length - 1;
        
        return Container(
          margin: EdgeInsets.only(bottom: isLastItem ? 0 : 12),
          decoration: BoxDecoration(
            color: isDark ? Colors.grey[850] : Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.1),
                spreadRadius: 1,
                blurRadius: 5,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: _buildProfileTile(context, profile, theme),
        );
      },
    );
  }

  Widget _buildProfileTile(
      BuildContext context, SocialPetProfile profile, ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      leading: CircleAvatar(
        radius: 28,
        backgroundColor: (isDark ? darkPrimaryColor : primaryColor).withOpacity(0.1),
        backgroundImage:
            profile.avatarUrl.isNotEmpty ? NetworkImage(profile.avatarUrl) : null,
        child: profile.avatarUrl.isEmpty
            ? Icon(
                Icons.pets,
                color: isDark ? darkPrimaryColor : primaryColor,
                size: 28,
              )
            : null,
      ),
      title: Text(
        (profile.displayName?.isNotEmpty ?? false) 
            ? profile.displayName! 
            : profile.petName,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 16,
          color: isDark ? Colors.grey[200] : Colors.black87,
        ),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if ((profile.displayName?.isNotEmpty ?? false) && profile.petName.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                '@${profile.petName}',
                style: TextStyle(
                  color: isDark ? Colors.grey[500] : Colors.grey[600],
                  fontSize: 13,
                ),
              ),
            ),
          if (profile.bio.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                profile.bio,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: isDark ? Colors.grey[400] : Colors.grey[700],
                  fontSize: 13,
                ),
              ),
            ),
          const SizedBox(height: 6),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: (isDark ? darkPrimaryColor : primaryColor).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.grid_on,
                      size: 12,
                      color: isDark ? darkPrimaryColor : primaryColor,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${profile.stats.posts}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: isDark ? darkPrimaryColor : primaryColor,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: (isDark ? darkPrimaryColor : primaryColor).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.people,
                      size: 12,
                      color: isDark ? darkPrimaryColor : primaryColor,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${profile.stats.followers}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: isDark ? darkPrimaryColor : primaryColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      trailing: Icon(
        Icons.arrow_forward_ios,
        size: 16,
        color: Colors.grey[400],
      ),
      onTap: () {
        Navigator.pushNamed(
          context,
          '/social/profile',
          arguments: profile.id,
        );
      },
    );
  }
}
