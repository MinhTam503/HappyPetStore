import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../../utils/contants.dart';
import 'widgets/loading_skeleton.dart';

class OptimizedDashboardPage extends StatefulWidget {
  const OptimizedDashboardPage({super.key});

  @override
  State<OptimizedDashboardPage> createState() => _OptimizedDashboardPageState();
}

class _OptimizedDashboardPageState extends State<OptimizedDashboardPage>
    with AutomaticKeepAliveClientMixin, TickerProviderStateMixin {
  // Loading states
  bool _loading = true;
  bool _revenueLoading = false;
  bool _statsLoading = false;
  
  // Animation controllers
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  
  // Data
  Map<String, int> _statsData = {};
  Map<String, double> _revenueData = {};
  Map<String, int> _orderStatusData = {
    'Completed': 0,
    'Pending': 0,
    'Processing': 0,
    'Cancelled': 0,
  };
  List<Map<String, dynamic>> _recentOrders = [];
  
  // UI State
  String _timeRange = '7days';

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    
    // Initialize animations
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeOut),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideController, curve: Curves.easeOut));
    
    _loadEssentialData();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  // Load only essential data first for quick display
  Future<void> _loadEssentialData() async {
    setState(() => _loading = true);
    
    try {
      await Future.wait([
        _loadStatsData(),
        _loadRecentOrders(),
      ]);
      
      setState(() => _loading = false);
      
      // Start animations
      _fadeController.forward();
      _slideController.forward();
      
      // Load charts data in background
      _loadChartsData();
    } catch (e) {
      print('Error loading essential data: $e');
      setState(() => _loading = false);
    }
  }

  double _getTodayRevenue() {
    final today = DateTime.now();
    final todayKey = '${today.day}/${today.month}';
    return _revenueData[todayKey] ?? 0.0;
  }

  Future<void> _loadChartsData() async {
    await Future.wait([
      _loadRevenueData(),
      _loadOrderStatusData(),
    ]);
  }

  Future<void> _loadStatsData() async {
    setState(() => _statsLoading = true);
    
    try {
      final futures = [
        FirebaseFirestore.instance.collection('Pets').count().get(),
        FirebaseFirestore.instance.collection('users').count().get(),
        FirebaseFirestore.instance.collection('orders').count().get(),
        FirebaseFirestore.instance.collection('ordersWeb').count().get(),
      ];
      
      final results = await Future.wait(futures);
      
      final stats = {
        'pets': results[0].count ?? 0,
        'users': results[1].count ?? 0,
        'orders': (results[2].count ?? 0) + (results[3].count ?? 0),
        'categories': 4, // Hardcoded for performance
      };
      
      setState(() => _statsData = stats);
    } catch (e) {
      print('Error loading stats: $e');
    } finally {
      setState(() => _statsLoading = false);
    }
  }

  Future<void> _loadRecentOrders() async {
    try {
      print('🔍 Loading recent orders (one time)...');
      
      // Try without orderBy first to avoid index issues
      final ordersQuery = FirebaseFirestore.instance
          .collection('orders')
          .limit(10);
      
      final ordersWebQuery = FirebaseFirestore.instance
          .collection('ordersWeb')
          .limit(10);
      
      final results = await Future.wait([
        ordersQuery.get(),
        ordersWebQuery.get(),
      ]);
      
      print('📦 Found ${results[0].docs.length} mobile orders');
      print('🌐 Found ${results[1].docs.length} web orders');
      
      final allOrders = <Map<String, dynamic>>[];
      
      // Process mobile orders
      for (final doc in results[0].docs) {
        final data = doc.data();
        
        // Handle different timestamp formats
        dynamic rawTimestamp = data['timestamp'];
        Timestamp timestamp;
        
        if (rawTimestamp is Timestamp) {
          timestamp = rawTimestamp;
        } else if (rawTimestamp is String) {
          try {
            // Parse string timestamp to DateTime then convert to Timestamp
            final dateTime = DateTime.parse(rawTimestamp);
            timestamp = Timestamp.fromDate(dateTime);
          } catch (e) {
            print('⚠️ Invalid timestamp format: $rawTimestamp');
            timestamp = Timestamp.now();
          }
        } else {
          timestamp = Timestamp.now();
        }
        
        final order = {
          'id': doc.id,
          'customerName': data['fullName'] ?? data['name'] ?? 'Unknown Customer',
          'totalAmount': (data['totalAmount'] ?? 0.0).toDouble(),
          'status': data['statusOrder'] ?? 'Pending',
          'timestamp': timestamp,
          'source': 'Mobile',
        };
        allOrders.add(order);
        print('📱 Mobile order: ${order['customerName']} - \$${order['totalAmount']}');
      }
      
      // Process web orders
      for (final doc in results[1].docs) {
        final data = doc.data();
        
        // Handle different timestamp formats
        dynamic rawTimestamp = data['timestamp'];
        Timestamp timestamp;
        
        if (rawTimestamp is Timestamp) {
          timestamp = rawTimestamp;
        } else if (rawTimestamp is String) {
          try {
            // Parse string timestamp to DateTime then convert to Timestamp
            final dateTime = DateTime.parse(rawTimestamp);
            timestamp = Timestamp.fromDate(dateTime);
          } catch (e) {
            print('⚠️ Invalid timestamp format: $rawTimestamp');
            timestamp = Timestamp.now();
          }
        } else {
          timestamp = Timestamp.now();
        }
        
        final order = {
          'id': doc.id,
          'customerName': data['fullName'] ?? data['name'] ?? 'Unknown Customer',
          'totalAmount': (data['totalAmount'] ?? 0.0).toDouble(),
          'status': data['statusOrder'] ?? 'Pending',
          'timestamp': timestamp,
          'source': 'Web',
        };
        allOrders.add(order);
        print('🌐 Web order: ${order['customerName']} - \$${order['totalAmount']}');
      }
      
      // Sort by timestamp (newest first)
      try {
        allOrders.sort((a, b) {
          final aTime = a['timestamp'] as Timestamp;
          final bTime = b['timestamp'] as Timestamp;
          return bTime.compareTo(aTime);
        });
      } catch (e) {
        print('⚠️ Error sorting orders: $e');
        // If sorting fails, just use the orders as-is
      }
      
      final recentOrders = allOrders.take(5).toList();
      print('📋 Recent orders to display: ${recentOrders.length}');
      
      if (mounted) {
        setState(() => _recentOrders = recentOrders);
      }
    } catch (e) {
      print('❌ Error loading recent orders: $e');
      // Set empty list on error
      if (mounted) {
        setState(() => _recentOrders = []);
      }
    }
  }

  Future<void> _loadRevenueData() async {
    if (_revenueLoading) return; // Prevent multiple simultaneous calls
    
    setState(() => _revenueLoading = true);
    
    try {
      print('🔍 Loading revenue data for $_timeRange...');
      DateTime endDate = DateTime.now();
      DateTime startDate = endDate.subtract(Duration(days: _timeRange == '7days' ? 7 : 30));
      
      // Simplified queries without complex where clauses
      final ordersQuery = FirebaseFirestore.instance
          .collection('orders')
          .limit(200);
      
      final ordersWebQuery = FirebaseFirestore.instance
          .collection('ordersWeb')
          .limit(200);
      
      final results = await Future.wait([
        ordersQuery.get(),
        ordersWebQuery.get(),
      ]);
      
      print('📦 Orders found: ${results[0].docs.length}');
      print('🌐 Web orders found: ${results[1].docs.length}');
      
      final revenue = <String, double>{};
      
      // Process mobile orders
      for (final doc in results[0].docs) {
        final data = doc.data();
        final rawTimestamp = data['timestamp'];
        final amount = (data['totalAmount'] ?? 0.0).toDouble();
        final status = data['statusOrder'] ?? 'Pending';
        
        if (status == 'Completed' && amount > 0) {
          DateTime? date;
          
          if (rawTimestamp is Timestamp) {
            date = rawTimestamp.toDate();
          } else if (rawTimestamp is String) {
            try {
              date = DateTime.parse(rawTimestamp);
            } catch (e) {
              print('⚠️ Invalid timestamp in mobile order: $rawTimestamp');
              continue;
            }
          }
          
          if (date != null && date.isAfter(startDate) && date.isBefore(endDate)) {
            final dateKey = '${date.day}/${date.month}';
            revenue[dateKey] = (revenue[dateKey] ?? 0) + amount;
            print('💰 Mobile order: ${dateKey} = \$${amount}');
          }
        }
      }
      
      // Process web orders  
      for (final doc in results[1].docs) {
        final data = doc.data();
        final rawTimestamp = data['timestamp'];
        final amount = (data['totalAmount'] ?? 0.0).toDouble();
        final status = data['statusOrder'] ?? 'Pending';
        
        if (status == 'Completed' && amount > 0) {
          DateTime? date;
          
          if (rawTimestamp is Timestamp) {
            date = rawTimestamp.toDate();
          } else if (rawTimestamp is String) {
            try {
              date = DateTime.parse(rawTimestamp);
            } catch (e) {
              print('⚠️ Invalid timestamp in web order: $rawTimestamp');
              continue;
            }
          }
          
          if (date != null && date.isAfter(startDate) && date.isBefore(endDate)) {
            final dateKey = '${date.day}/${date.month}';
            revenue[dateKey] = (revenue[dateKey] ?? 0) + amount;
            print('💰 Web order: ${dateKey} = \$${amount}');
          }
        }
      }
      
      print('📊 Total revenue data points: ${revenue.length}');
      print('💵 Revenue summary: $revenue');
      
      if (mounted) {
        setState(() => _revenueData = revenue);
      }
    } catch (e) {
      print('❌ Error loading revenue: $e');
      if (mounted) {
        setState(() => _revenueData = {});
      }
    } finally {
      if (mounted) {
        setState(() => _revenueLoading = false);
      }
    }
  }

  Future<void> _loadOrderStatusData() async {
    try {
      final orders = await FirebaseFirestore.instance
          .collection('orders')
          .limit(200)
          .get();
      
      final ordersWeb = await FirebaseFirestore.instance
          .collection('ordersWeb')
          .limit(200)
          .get();
      
      final statusData = <String, int>{
        'Completed': 0,
        'Pending': 0,
        'Processing': 0,
        'Cancelled': 0,
      };
      
      for (final doc in orders.docs) {
        final status = doc.data()['statusOrder'] ?? 'Pending';
        if (statusData.containsKey(status)) {
          statusData[status] = statusData[status]! + 1;
        }
      }
      
      for (final doc in ordersWeb.docs) {
        final status = doc.data()['statusOrder'] ?? 'Pending';
        if (statusData.containsKey(status)) {
          statusData[status] = statusData[status]! + 1;
        }
      }
      
      setState(() => _orderStatusData = statusData);
    } catch (e) {
      print('Error loading order status: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    
    final isSmallScreen = MediaQuery.of(context).size.width < 1200;
    
    if (_loading) {
      return Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.1),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: const Center(
                  child: CircularProgressIndicator(
                    color: primaryColor,
                    strokeWidth: 3,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Loading Dashboard...',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Preparing your analytics data',
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

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(isSmallScreen ? 16.0 : 24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: 24),
            _buildStatsCards(),
            const SizedBox(height: 24),
            isSmallScreen 
                ? _buildMobileChartsSection()
                : _buildChartsSection(),
            const SizedBox(height: 24),
            _buildRecentOrdersSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            primaryColor,
            Color(0xFF6366F1),
            Color(0xFF8B5CF6),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.dashboard_rounded,
                  color: Colors.white,
                  size: 32,
                ),
              ),
              const SizedBox(width: 20),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Dashboard Overview',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Monitor your pet store performance in real-time',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
              _buildTimeRangeSelector(),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              _buildQuickStat(
                'Today\'s Revenue', 
                '\$${_getTodayRevenue().toStringAsFixed(2)}', 
                Icons.attach_money, 
                Colors.green
              ),
              const SizedBox(width: 16),
              _buildQuickStat(
                'Total Orders', 
                '${_statsData['orders'] ?? 0}', 
                Icons.shopping_cart_outlined, 
                Colors.blue
              ),
              const SizedBox(width: 16),
              _buildQuickStat(
                'Active Users', 
                '${_statsData['users'] ?? 0}', 
                Icons.people_outline, 
                Colors.orange
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStat(String title, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.white.withOpacity(0.2),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.white, size: 24),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeRangeSelector() {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.schedule,
            color: Colors.white70,
            size: 20,
          ),
          const SizedBox(width: 8),
          DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _timeRange,
              dropdownColor: Colors.white,
              style: const TextStyle(color: Colors.black, fontSize: 14),
              icon: const Icon(Icons.keyboard_arrow_down, color: Colors.white70),
              items: const [
                DropdownMenuItem(
                  value: '7days',
                  child: Row(
                    children: [
                      Icon(Icons.calendar_today, size: 16),
                      SizedBox(width: 8),
                      Text('Last 7 Days'),
                    ],
                  ),
                ),
                DropdownMenuItem(
                  value: '1month',
                  child: Row(
                    children: [
                      Icon(Icons.date_range, size: 16),
                      SizedBox(width: 8),
                      Text('Last Month'),
                    ],
                  ),
                ),
              ],
              onChanged: (value) {
                if (value != null && value != _timeRange && !_revenueLoading) {
                  setState(() => _timeRange = value);
                  // Debounce revenue loading
                  Future.delayed(const Duration(milliseconds: 300), () {
                    if (_timeRange == value && mounted) {
                      _loadRevenueData();
                    }
                  });
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsCards() {
    final stats = [
      {'title': 'Total Pets', 'value': _statsData['pets'] ?? 0, 'icon': Icons.pets, 'color': Colors.blue},
      {'title': 'Total Users', 'value': _statsData['users'] ?? 0, 'icon': Icons.people, 'color': Colors.green},
      {'title': 'Total Orders', 'value': _statsData['orders'] ?? 0, 'icon': Icons.shopping_cart, 'color': Colors.orange},
      {'title': 'Categories', 'value': _statsData['categories'] ?? 0, 'icon': Icons.category, 'color': Colors.purple},
    ];

    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: Row(
          children: stats.asMap().entries.map((entry) {
            final index = entry.key;
            final stat = entry.value;
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: AnimatedContainer(
                  duration: Duration(milliseconds: 300 + (index * 100)),
                  curve: Curves.easeOut,
                  child: _buildStatsCard(
                    stat['title'] as String,
                    stat['value'] as int,
                    stat['icon'] as IconData,
                    stat['color'] as Color,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildStatsCard(String title, int value, IconData icon, Color color) {
    if (_statsLoading) {
      return const StatsCardSkeleton();
    }
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const Spacer(),
              Icon(Icons.trending_up, color: Colors.green, size: 16),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            value.toString(),
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChartsSection() {
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: _buildRevenueChart(),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildOrderStatusChart(),
        ),
      ],
    );
  }

  Widget _buildMobileChartsSection() {
    return Column(
      children: [
        _buildRevenueChart(),
        const SizedBox(height: 16),
        _buildOrderStatusChart(),
      ],
    );
  }

  Widget _buildRevenueChart() {
    if (_revenueLoading) {
      return const ChartSkeleton(title: 'Revenue Trend');
    }
    
    return Container(
      height: 400,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Revenue Trend',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: _revenueData.isEmpty
                ? const Center(child: Text('No revenue data available'))
                : LineChart(
                        LineChartData(
                          gridData: FlGridData(
                            show: true,
                            drawVerticalLine: false,
                            horizontalInterval: 1000,
                            getDrawingHorizontalLine: (value) => FlLine(
                              color: Colors.grey[300]!,
                              strokeWidth: 1,
                            ),
                          ),
                          titlesData: FlTitlesData(
                            show: true,
                            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            bottomTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                reservedSize: 30,
                                interval: 1,
                                getTitlesWidget: (value, meta) {
                                  final dates = _revenueData.keys.toList();
                                  if (value.toInt() < dates.length) {
                                    return Text(
                                      dates[value.toInt()],
                                      style: const TextStyle(fontSize: 12),
                                    );
                                  }
                                  return const Text('');
                                },
                              ),
                            ),
                            leftTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                reservedSize: 50,
                                getTitlesWidget: (value, meta) {
                                  return Text(
                                    '\$${(value / 1000).toStringAsFixed(0)}k',
                                    style: const TextStyle(fontSize: 12),
                                  );
                                },
                              ),
                            ),
                          ),
                          borderData: FlBorderData(show: false),
                          lineBarsData: [
                            LineChartBarData(
                              spots: _revenueData.entries.map((entry) {
                                final index = _revenueData.keys.toList().indexOf(entry.key);
                                return FlSpot(index.toDouble(), entry.value);
                              }).toList(),
                              isCurved: true,
                              gradient: const LinearGradient(
                                colors: [primaryColor, Color(0xFF10B981)],
                              ),
                              barWidth: 3,
                              isStrokeCapRound: true,
                              belowBarData: BarAreaData(
                                show: true,
                                gradient: LinearGradient(
                                  colors: [
                                    primaryColor.withOpacity(0.3),
                                    const Color(0xFF10B981).withOpacity(0.1),
                                  ],
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                ),
                              ),
                              dotData: const FlDotData(show: false),
                            ),
                          ],
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderStatusChart() {
    return Container(
      height: 400,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Order Status',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: PieChart(
              PieChartData(
                sectionsSpace: 2,
                centerSpaceRadius: 60,
                sections: _orderStatusData.entries.map((entry) {
                  final colors = {
                    'Completed': Colors.green,
                    'Pending': Colors.orange,
                    'Processing': Colors.blue,
                    'Cancelled': Colors.red,
                  };
                  final total = _orderStatusData.values.fold<int>(0, (sum, value) => sum + value);
                  final percentage = total > 0 ? (entry.value / total * 100).round() : 0;
                  
                  return PieChartSectionData(
                    value: entry.value.toDouble(),
                    color: colors[entry.key] ?? Colors.grey,
                    title: '$percentage%',
                    radius: 50,
                    titleStyle: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Column(
            children: _orderStatusData.entries.map((entry) {
              final colors = {
                'Completed': Colors.green,
                'Pending': Colors.orange,
                'Processing': Colors.blue,
                'Cancelled': Colors.red,
              };
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: colors[entry.key],
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(entry.key),
                    const Spacer(),
                    Text(
                      entry.value.toString(),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentOrdersSection() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Recent Orders',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: () {},
                child: const Text('View All'),
              ),
            ],
          ),
          const SizedBox(height: 24),
          if (_recentOrders.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(40),
                child: Text('No recent orders found'),
              ),
            )
          else
            Column(
              children: _recentOrders.map((order) => _buildOrderRow(order)).toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildOrderRow(Map<String, dynamic> order) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  primaryColor.withOpacity(0.1),
                  primaryColor.withOpacity(0.05),
                ],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.shopping_bag_outlined,
              color: primaryColor,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      order['customerName'],
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: order['source'] == 'Mobile'
                            ? Colors.blue.withOpacity(0.1)
                            : Colors.purple.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        order['source'],
                        style: TextStyle(
                          color: order['source'] == 'Mobile'
                              ? Colors.blue[700]
                              : Colors.purple[700],
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(
                      Icons.receipt_long,
                      size: 14,
                      color: Colors.grey[600],
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Order #${order['id'].toString().substring(0, 8)}',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: order['status'] == 'Completed' 
                      ? Colors.green.withOpacity(0.1)
                      : order['status'] == 'Pending'
                          ? Colors.orange.withOpacity(0.1)
                          : Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  order['status'],
                  style: TextStyle(
                    color: order['status'] == 'Completed' 
                        ? Colors.green[700]
                        : order['status'] == 'Pending'
                            ? Colors.orange[700]
                            : Colors.blue[700],
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '\$${order['totalAmount'].toStringAsFixed(2)}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
