import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pet_shop/services/recommendation_logger.dart';
import 'package:share_plus/share_plus.dart';
import 'package:pet_shop/core/services/user_manager.dart';
import 'package:pet_shop/data/repositories/recommendation_repository_impl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class RecommendationAnalyticsPage extends StatefulWidget {
  const RecommendationAnalyticsPage({super.key});

  @override
  State<RecommendationAnalyticsPage> createState() => _RecommendationAnalyticsPageState();
}

class _RecommendationAnalyticsPageState extends State<RecommendationAnalyticsPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Map<String, dynamic>> _logs = [];
  Map<String, dynamic> _analytics = {};
  bool _isLoading = true;
  String _selectedLogType = 'All';
  DateTime? _startDate;
  DateTime? _endDate;

  final List<String> _logTypes = [
    'All',
    'SESSION_START',
    'SESSION_COMPLETE', 
    'USER_INTERACTION',
    'ALGORITHM_EXECUTION',
    'HYBRID_COMBINATION'
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this); // Changed from 3 to 4
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    
    try {
      await RecommendationLogger.initialize();
      
      // Load logs
      final logs = await RecommendationLogger.getLogs(
        startDate: _startDate,
        endDate: _endDate,
        logType: _selectedLogType == 'All' ? null : _selectedLogType,
      );
      
      // Generate analytics
      final analytics = await RecommendationLogger.generateAnalyticsReport(
        startDate: _startDate,
        endDate: _endDate,
      );
      
      setState(() {
        _logs = logs;
        _analytics = analytics;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading data: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Recommendation Analytics'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Overview'),
            Tab(text: 'User Prefs'), // New tab
            Tab(text: 'Logs'),
            Tab(text: 'Performance'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
          ),
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: _shareAnalytics,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildOverviewTab(),
                _buildUserPreferencesTab(), // New tab
                _buildLogsTab(),
                _buildPerformanceTab(),
              ],
            ),
    );
  }

  Widget _buildOverviewTab() {
    final sessionStats = _analytics['sessionStatistics'] ?? {};
    final interactions = _analytics['userInteractions'] ?? {};
    final performance = _analytics['performanceMetrics'] ?? {};

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildDateFilters(),
          const SizedBox(height: 20),
          
          // Session Statistics
          _buildStatsCard(
            'Session Statistics',
            [
              _StatItem('Total Sessions', '${sessionStats['totalSessions'] ?? 0}'),
              _StatItem('Success Rate', '${((sessionStats['successRate'] ?? 0.0) * 100).toStringAsFixed(1)}%'),
              _StatItem('Avg Response Time', '${(sessionStats['averageResponseTimeMs'] ?? 0.0).toStringAsFixed(0)}ms'),
              _StatItem('Failed Sessions', '${sessionStats['failedSessions'] ?? 0}'),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // User Interactions
          _buildStatsCard(
            'User Interactions',
            [
              _StatItem('Total Interactions', '${interactions['totalInteractions'] ?? 0}'),
              ..._buildInteractionStats(interactions['interactionTypes'] ?? {}),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Performance Metrics
          _buildStatsCard(
            'Performance Metrics',
            [
              _StatItem('Fast Sessions (<1s)', '${performance['fastSessions'] ?? 0}'),
              _StatItem('Slow Sessions (>5s)', '${performance['slowSessions'] ?? 0}'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLogsTab() {
    return Column(
      children: [
        _buildLogFilters(),
        Expanded(
          child: _logs.isEmpty
              ? const Center(child: Text('No logs found'))
              : ListView.builder(
                  itemCount: _logs.length,
                  itemBuilder: (context, index) {
                    final log = _logs[index];
                    return _buildLogItem(log);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildPerformanceTab() {
    final sessionLogs = _logs.where((log) => log['type'] == 'SESSION_COMPLETE').toList();
    
    if (sessionLogs.isEmpty) {
      return const Center(child: Text('No session data available'));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildPerformanceChart(sessionLogs),
          const SizedBox(height: 20),
          _buildAlgorithmPerformance(),
        ],
      ),
    );
  }

  Widget _buildDateFilters() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Date Range Filter', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => _selectDate(true),
                    child: Text(_startDate == null ? 'Start Date' : DateFormat.yMd().format(_startDate!)),
                  ),
                ),
                const Text(' - '),
                Expanded(
                  child: TextButton(
                    onPressed: () => _selectDate(false),
                    child: Text(_endDate == null ? 'End Date' : DateFormat.yMd().format(_endDate!)),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    setState(() {
                      _startDate = null;
                      _endDate = null;
                    });
                    _loadData();
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLogFilters() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: DropdownButtonFormField<String>(
        value: _selectedLogType,
        decoration: const InputDecoration(
          labelText: 'Log Type',
          border: OutlineInputBorder(),
        ),
        items: _logTypes.map((type) => DropdownMenuItem(
          value: type,
          child: Text(type),
        )).toList(),
        onChanged: (value) {
          if (value != null) {
            setState(() => _selectedLogType = value);
            _loadData();
          }
        },
      ),
    );
  }

  Widget _buildStatsCard(String title, List<_StatItem> stats) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            ...stats.map((stat) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(stat.label),
                  Text(stat.value, style: const TextStyle(fontWeight: FontWeight.w500)),
                ],
              ),
            )),
          ],
        ),
      ),
    );
  }

  List<_StatItem> _buildInteractionStats(Map<String, dynamic> interactions) {
    return interactions.entries.map((entry) => 
      _StatItem(entry.key, '${entry.value}')
    ).toList();
  }

  Widget _buildLogItem(Map<String, dynamic> log) {
    final timestamp = DateTime.parse(log['timestamp']);
    final type = log['type'];
    
    Color typeColor;
    IconData typeIcon;
    
    switch (type) {
      case 'SESSION_START':
        typeColor = Colors.green;
        typeIcon = Icons.play_arrow;
        break;
      case 'SESSION_COMPLETE':
        typeColor = log['success'] == true ? Colors.blue : Colors.red;
        typeIcon = log['success'] == true ? Icons.check_circle : Icons.error;
        break;
      case 'USER_INTERACTION':
        typeColor = Colors.orange;
        typeIcon = Icons.touch_app;
        break;
      case 'ALGORITHM_EXECUTION':
        typeColor = Colors.purple;
        typeIcon = Icons.psychology;
        break;
      default:
        typeColor = Colors.grey;
        typeIcon = Icons.info;
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ExpansionTile(
        leading: Icon(typeIcon, color: typeColor),
        title: Text(type),
        subtitle: Text(DateFormat('MM/dd HH:mm:ss').format(timestamp)),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Details:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    const JsonEncoder.withIndent('  ').convert(log),
                    style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton.icon(
                      icon: const Icon(Icons.copy),
                      label: const Text('Copy'),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(
                          text: const JsonEncoder.withIndent('  ').convert(log),
                        ));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Copied to clipboard')),
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPerformanceChart(List<Map<String, dynamic>> sessionLogs) {
    final responseTimes = sessionLogs
        .map((log) => (log['totalTimeMs'] as num).toDouble())
        .toList();
    
    if (responseTimes.isEmpty) return const SizedBox();

    final avgTime = responseTimes.reduce((a, b) => a + b) / responseTimes.length;
    final maxTime = responseTimes.reduce((a, b) => a > b ? a : b);
    final minTime = responseTimes.reduce((a, b) => a < b ? a : b);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Response Time Analysis', 
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildMetricColumn('Average', '${avgTime.toStringAsFixed(0)}ms'),
                _buildMetricColumn('Min', '${minTime.toStringAsFixed(0)}ms'),
                _buildMetricColumn('Max', '${maxTime.toStringAsFixed(0)}ms'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricColumn(String label, String value) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: Colors.grey)),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildAlgorithmPerformance() {
    final algorithmLogs = _logs.where((log) => log['type'] == 'ALGORITHM_EXECUTION').toList();
    
    if (algorithmLogs.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('No algorithm execution data available'),
        ),
      );
    }

    final algorithmStats = <String, Map<String, dynamic>>{};
    
    for (final log in algorithmLogs) {
      final algorithm = log['algorithmType'] as String;
      if (!algorithmStats.containsKey(algorithm)) {
        algorithmStats[algorithm] = {
          'executions': 0,
          'totalTime': 0.0,
          'totalResults': 0,
          'errors': 0,
        };
      }
      
      final stats = algorithmStats[algorithm]!;
      stats['executions'] = stats['executions'] + 1;
      stats['totalTime'] = stats['totalTime'] + (log['executionTimeMs'] ?? 0);
      stats['totalResults'] = stats['totalResults'] + (log['outputCount'] ?? 0);
      if (log['success'] == false) {
        stats['errors'] = stats['errors'] + 1;
      }
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Algorithm Performance', 
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            ...algorithmStats.entries.map((entry) {
              final algorithm = entry.key.split('.').last;
              final stats = entry.value;
              final avgTime = stats['totalTime'] / stats['executions'];
              final avgResults = stats['totalResults'] / stats['executions'];
              
              return Card(
                margin: const EdgeInsets.symmetric(vertical: 4),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(algorithm, style: const TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Executions: ${stats['executions']}'),
                          Text('Avg Time: ${avgTime.toStringAsFixed(0)}ms'),
                        ],
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Avg Results: ${avgResults.toStringAsFixed(1)}'),
                          Text('Errors: ${stats['errors']}', 
                               style: TextStyle(color: stats['errors'] > 0 ? Colors.red : Colors.green)),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildUserPreferencesTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildUserPreferencesCard(),
          const SizedBox(height: 16),
          _buildUserDataCard(),
        ],
      ),
    );
  }

  Widget _buildUserPreferencesCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Current User Preferences',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            FutureBuilder<Map<String, dynamic>>(
              future: _getUserPreferences(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const CircularProgressIndicator();
                }
                
                if (snapshot.hasError) {
                  return Text('Error: ${snapshot.error}');
                }
                
                final preferences = snapshot.data ?? {};
                final favoriteCategories = preferences['favoriteCategories'] as List<String>? ?? [];
                final categoryScores = preferences['categoryScores'] as Map<String, int>? ?? {};
                
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Favorite Categories:',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    if (favoriteCategories.isNotEmpty) ...[
                      ...favoriteCategories.take(5).map((category) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            Container(
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(
                                color: _getCategoryColor(category),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(category),
                            const Spacer(),
                            Text('Score: ${categoryScores[category] ?? 0}'),
                          ],
                        ),
                      )),
                    ] else ...[
                      const Text('No preferences found', style: TextStyle(color: Colors.grey)),
                    ],
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () {
                        setState(() {}); // Refresh preferences
                      },
                      child: const Text('Refresh Preferences'),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserDataCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'User Data Sources',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            FutureBuilder<Map<String, int>>(
              future: _getUserDataCounts(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const CircularProgressIndicator();
                }
                
                final counts = snapshot.data ?? {};
                
                return Column(
                  children: [
                    _buildDataSourceRow('Viewed Pets', counts['viewedPets'] ?? 0, Icons.visibility),
                    _buildDataSourceRow('Favorites', counts['favorites'] ?? 0, Icons.favorite),
                    _buildDataSourceRow('Search History', counts['searchHistory'] ?? 0, Icons.search),
                    _buildDataSourceRow('Interactions', counts['interactions'] ?? 0, Icons.touch_app),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDataSourceRow(String label, int count, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.blue),
          const SizedBox(width: 12),
          Text(label),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: count > 0 ? Colors.green.shade100 : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              count.toString(),
              style: TextStyle(
                color: count > 0 ? Colors.green.shade700 : Colors.grey.shade700,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getCategoryColor(String category) {
    switch (category.toLowerCase()) {
      case 'chó':
      case 'dogs':
        return Colors.brown;
      case 'mèo':
      case 'cats':
        return Colors.orange;
      case 'chim':
      case 'birds':
        return Colors.blue;
      case 'cá':
      case 'fish':
        return Colors.cyan;
      case 'thỏ':
      case 'rabbits':
        return Colors.pink;
      default:
        return Colors.grey;
    }
  }

  Future<Map<String, dynamic>> _getUserPreferences() async {
    try {
      final userManager = UserManager();
      await userManager.initialize();
      final userId = await userManager.getUserIdForOperations();
      
      if (userId == null) {
        return {'favoriteCategories': <String>[], 'categoryScores': <String, int>{}};
      }
      
      final repository = RecommendationRepositoryImpl(
        firestore: FirebaseFirestore.instance,
        userManager: userManager,
      );
      
      // Use public method to access user preferences
      return await repository.analyzeUserPreferences(userId);
    } catch (e) {
      print('Error getting user preferences: $e');
      return {'favoriteCategories': <String>[], 'categoryScores': <String, int>{}};
    }
  }

  Future<Map<String, int>> _getUserDataCounts() async {
    try {
      final userManager = UserManager();
      await userManager.initialize();
      final userId = await userManager.getUserIdForOperations();
      
      if (userId == null) {
        return {};
      }
      
      final firestore = FirebaseFirestore.instance;
      
      // Count viewed pets
      final viewedSnapshot = await firestore
          .collection('ViewedPets')
          .doc(userId)
          .collection('pets')
          .get();
      
      // Count favorites
      final favSnapshot = await firestore
          .collection('UserFav')
          .doc(userId)
          .collection('favorites')
          .get();
      
      // Count search history
      final searchSnapshot = await firestore
          .collection('SearchHistory')
          .doc(userId)
          .collection('searches')
          .get();
      
      // Count interactions
      final interactionSnapshot = await firestore
          .collection('user_interactions')
          .where('userId', isEqualTo: userId)
          .get();
      
      return {
        'viewedPets': viewedSnapshot.docs.length,
        'favorites': favSnapshot.docs.length,
        'searchHistory': searchSnapshot.docs.length,
        'interactions': interactionSnapshot.docs.length,
      };
    } catch (e) {
      print('Error getting user data counts: $e');
      return {};
    }
  }

  Future<void> _selectDate(bool isStartDate) async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now(),
    );
    
    if (date != null) {
      setState(() {
        if (isStartDate) {
          _startDate = date;
        } else {
          _endDate = date;
        }
      });
      _loadData();
    }
  }

  Future<void> _shareAnalytics() async {
    try {
      final analyticsText = const JsonEncoder.withIndent('  ').convert(_analytics);
      await Share.share(
        'Recommendation System Analytics Report\n\n$analyticsText',
        subject: 'Recommendation Analytics Report',
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error sharing analytics: $e')),
      );
    }
  }
}

class _StatItem {
  final String label;
  final String value;
  
  _StatItem(this.label, this.value);
}