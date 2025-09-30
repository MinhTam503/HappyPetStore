import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pet_shop/core/services/user_manager.dart';
import 'package:pet_shop/domain/entities/recommendation_entities.dart';
import 'package:pet_shop/presentation/bloc/recommendation/recommendation_bloc.dart';
import 'package:pet_shop/presentation/bloc/recommendation/recommendation_event.dart';
import 'package:pet_shop/presentation/bloc/recommendation/recommendation_state.dart';
import 'package:pet_shop/presentation/widgets/recommendation_section.dart';

class RecommendationDemoPage extends StatefulWidget {
  const RecommendationDemoPage({super.key});

  @override
  State<RecommendationDemoPage> createState() => _RecommendationDemoPageState();
}

class _RecommendationDemoPageState extends State<RecommendationDemoPage> 
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String? userId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _initializeUser();
  }

  void _initializeUser() async {
    final userManager = UserManager();
    await userManager.initialize();
    userId = await userManager.getUserIdForOperations();
    
    if (userId != null && mounted) {
      // Load initial personalized recommendations
      context.read<RecommendationBloc>().add(
        LoadPersonalizedRecommendations(userId: userId!),
      );
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Hệ thống khuyến nghị'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.blue,
          unselectedLabelColor: Colors.grey,
          indicatorColor: Colors.blue,
          tabs: const [
            Tab(text: 'Cá nhân'),
            Tab(text: 'Thịnh hành'),
            Tab(text: 'Tương tự'),
            Tab(text: 'Phân tích'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              if (userId != null) {
                context.read<RecommendationBloc>().add(
                  RefreshRecommendations(userId!),
                );
              }
            },
          ),
        ],
      ),
      body: userId == null
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.login, size: 48, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'Vui lòng đăng nhập để xem khuyến nghị',
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                ],
              ),
            )
          : TabBarView(
              controller: _tabController,
              children: [
                _buildPersonalizedTab(),
                _buildTrendingTab(),
                _buildSimilarUsersTab(),
                _buildAnalysisTab(),
              ],
            ),
    );
  }

  Widget _buildPersonalizedTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Khuyến nghị được cá nhân hóa',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Dựa trên sở thích và hành vi của bạn',
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 20),
          
          const RecommendationSection(
            title: "Đề xuất cho bạn",
            type: RecommendationType.personalized,
            showViewAll: false,
            limit: 20,
          ),
          
          const SizedBox(height: 30),
          
          const RecommendationSection(
            title: "Phù hợp với sở thích",
            type: RecommendationType.contentBased,
            showViewAll: false,
            limit: 15,
          ),
          
          const SizedBox(height: 30),
          
          const RecommendationSection(
            title: "Thường mua cùng nhau",
            type: RecommendationType.association,
            showViewAll: false,
            limit: 10,
          ),
        ],
      ),
    );
  }

  Widget _buildTrendingTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Thú cưng thịnh hành',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Những thú cưng được quan tâm nhiều nhất gần đây',
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 20),
          
          const RecommendationSection(
            title: "Hot trend",
            type: RecommendationType.trending,
            showViewAll: false,
            limit: 20,
          ),
          
          const SizedBox(height: 30),
          
          const RecommendationSection(
            title: "Người dùng tương tự thích",
            type: RecommendationType.collaborative,
            showViewAll: false,
            limit: 15,
          ),
        ],
      ),
    );
  }

  Widget _buildSimilarUsersTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Người dùng tương tự',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Dựa trên những người có sở thích giống bạn',
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 20),
          
          BlocBuilder<RecommendationBloc, RecommendationState>(
            builder: (context, state) {
              if (state is RecommendationLoading) {
                return const Center(child: CircularProgressIndicator());
              }
              
              if (state is SimilarUsersLoaded) {
                if (state.similarUsers.isEmpty) {
                  return const Center(
                    child: Text('Chưa tìm thấy người dùng tương tự'),
                  );
                }
                
                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: state.similarUsers.length,
                  itemBuilder: (context, index) {
                    final user = state.similarUsers[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: CircleAvatar(
                          child: Text(
                            '${(user.similarity * 100).toInt()}%',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                        title: Text('Người dùng ${user.userId.substring(0, 8)}...'),
                        subtitle: Text(
                          'Sở thích chung: ${user.commonPreferences.join(", ")}',
                        ),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.blue.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${(user.similarity * 100).toInt()}% tương tự',
                            style: const TextStyle(
                              color: Colors.blue,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                );
              }
              
              return ElevatedButton(
                onPressed: () {
                  if (userId != null) {
                    context.read<RecommendationBloc>().add(
                      LoadSimilarUsers(userId: userId!),
                    );
                  }
                },
                child: const Text('Tìm người dùng tương tự'),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildAnalysisTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Phân tích hành vi',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Thống kê về sở thích và hành vi của bạn',
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 20),
          
          BlocBuilder<RecommendationBloc, RecommendationState>(
            builder: (context, state) {
              if (state is UserProfileLoaded) {
                return _buildProfileAnalysis(state.userProfile, state.behaviorAnalysis);
              }
              
              return ElevatedButton(
                onPressed: () {
                  if (userId != null) {
                    context.read<RecommendationBloc>().add(
                      LoadUserProfile(userId!),
                    );
                  }
                },
                child: const Text('Tải phân tích'),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildProfileAnalysis(UserProfile profile, Map<String, dynamic>? analysis) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Sở thích chính',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                
                if (profile.preferredCategories.isNotEmpty) ...[
                  const Text('Loại thú cưng yêu thích:'),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 8,
                    children: profile.preferredCategories.map((category) {
                      return Chip(
                        label: Text(category),
                        backgroundColor: Colors.blue.withOpacity(0.1),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 12),
                ],
                
                if (profile.preferredBreeds.isNotEmpty) ...[
                  const Text('Giống yêu thích:'),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 8,
                    children: profile.preferredBreeds.take(5).map((breed) {
                      return Chip(
                        label: Text(breed),
                        backgroundColor: Colors.green.withOpacity(0.1),
                      );
                    }).toList(),
                  ),
                ],
              ],
            ),
          ),
        ),
        
        const SizedBox(height: 16),
        
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Thống kê hành vi',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                
                _buildStatRow('Hoạt động gần đây', 
                    profile.lastActivity.toString().split('.')[0]),
                _buildStatRow('Mức chi tiêu trung bình', 
                    '${profile.averageSpending.toStringAsFixed(0)} ₫'),
                
                if (analysis != null) ...[
                  const SizedBox(height: 8),
                  _buildStatRow('Tổng tương tác', 
                      '${analysis['totalInteractions'] ?? 0}'),
                  _buildStatRow('Loại tương tác nhiều nhất', 
                      '${analysis['topInteractionType'] ?? 'N/A'}'),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}