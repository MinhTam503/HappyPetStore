import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math' as math;
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:pet_shop/core/constants/app_constants.dart';
import 'package:pet_shop/core/utils/currency_helper.dart';
import 'package:pet_shop/presentation/pages/web/screen_admin/order/orders_admin.dart';
import 'widgets/loading_skeleton.dart';

class DashboardPage extends StatefulWidget {
  final void Function(int index)? onNavigateToTab; // allow parent to switch NavigationRail tab
  const DashboardPage({super.key, this.onNavigateToTab});

  @override
  State<DashboardPage> createState() => _OptimizedDashboardPageState();
}

class _OptimizedDashboardPageState extends State<DashboardPage>
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
  String _revenueUnit = '₫'; // Track current unit for display
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
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final todayKey = '${today.day}/${today.month}';
    return _revenueData[todayKey] ?? 0.0; // already scaled to unit
  }

  // Get total revenue for the current time period
  double _getTotalRevenue() {
    if (_revenueData.isEmpty) return 0.0;
    return _revenueData.values.fold(0.0, (sum, value) => sum + value);
  }

  // Format total revenue with proper unit
  String _getTotalRevenueFormatted() {
    final convertedValue = _getTotalRevenue();
    return '${_formatChartCurrency(convertedValue)} ${_getChartUnit()}';
  }

  // Format today revenue with proper unit
  String _getTodayRevenueFormatted() {
    final convertedValue = _getTodayRevenue();
    return '${_formatChartCurrency(convertedValue)} ${_getChartUnit()}';
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
      final ordersQuery =
          FirebaseFirestore.instance.collection('orders').limit(10);

      final ordersWebQuery =
          FirebaseFirestore.instance.collection('ordersWeb').limit(10);

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

        final totalAmount = _parseDouble(data['totalAmount']);

        final order = {
          'id': doc.id,
          'customerName':
              data['fullName'] ?? data['name'] ?? 'Unknown Customer',
          'totalAmount': totalAmount,
          'status': data['statusOrder'] ?? 'Pending',
          'timestamp': timestamp,
          'source': 'Mobile',
        };
        allOrders.add(order);
        print(
            '📱 Mobile order: ${order['customerName']} - \$${order['totalAmount']}');
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

        final totalAmount = _parseDouble(data['totalAmount']);

        final order = {
          'id': doc.id,
          'customerName':
              data['fullName'] ?? data['name'] ?? 'Unknown Customer',
          'totalAmount': totalAmount,
          'status': data['statusOrder'] ?? 'Pending',
          'timestamp': timestamp,
          'source': 'Web',
        };
        allOrders.add(order);
        print(
            '🌐 Web order: ${order['customerName']} - \$${order['totalAmount']}');
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

      // Prefer Completed orders; fallback to any if none
      List<Map<String, dynamic>> ordered = List.from(allOrders);
      ordered.sort((a, b) {
        final at = a['timestamp'] as Timestamp;
        final bt = b['timestamp'] as Timestamp;
        return bt.compareTo(at);
      });
      final completed = ordered.where((o) => (o['status'] ?? '') == 'Completed').toList();
      final recentOrders = (completed.isNotEmpty ? completed : ordered).take(5).toList();
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
      final now = DateTime.now();
      DateTime startDate;
      DateTime endDate;
      if (_timeRange == '1month') {
        // Previous full calendar month
        final prevMonth = DateTime(now.year, now.month - 1, 1);
        startDate = prevMonth;
        endDate = DateTime(prevMonth.year, prevMonth.month + 1, 0); // last day prev month
      } else {
        // trailing 7 days including today
        endDate = DateTime(now.year, now.month, now.day);
        startDate = endDate.subtract(const Duration(days: 6));
      }
      bool inRange(DateTime d) {
        final nd = DateTime(d.year, d.month, d.day);
        return !nd.isBefore(startDate) && !nd.isAfter(endDate);
      }

      // Simplified queries without complex where clauses
      final ordersQuery =
          FirebaseFirestore.instance.collection('orders').limit(200);

      final ordersWebQuery =
          FirebaseFirestore.instance.collection('ordersWeb').limit(200);

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
        final amount = _parseDouble(data['totalAmount']);
        final status = data['statusOrder'] ?? 'Pending';

        if (status == 'Completed' && amount > 0) {
          // Debug: log large amounts but don't skip them
          if (amount > 1000000) {
            print(
                '💰 Large amount detected: \$${amount} for mobile order ${doc.id}');
            print(
                '💰 Will display as: ${(amount / 1000000).toStringAsFixed(1)}M');
          }

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

          if (date != null && inRange(date)) {
            final dateKey = '${date.day}/${date.month}';
            revenue[dateKey] = (revenue[dateKey] ?? 0) + amount;
            print('💰 Mobile order: $dateKey = $amount');
          }
        }
      }

      // Process web orders
      for (final doc in results[1].docs) {
        final data = doc.data();
        final rawTimestamp = data['timestamp'];
        final amount = _parseDouble(data['totalAmount']);
        final status = data['statusOrder'] ?? 'Pending';

        if (status == 'Completed' && amount > 0) {
          // Debug: log large amounts but don't skip them
          if (amount > 1000000) {
            print(
                '💰 Large amount detected: \$${amount} for web order ${doc.id}');
            print(
                '💰 Will display as: ${(amount / 1000000).toStringAsFixed(1)}M');
          }

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

          if (date != null && inRange(date)) {
            final dateKey = '${date.day}/${date.month}';
            revenue[dateKey] = (revenue[dateKey] ?? 0) + amount;
            print('💰 Web order: $dateKey = $amount');
          }
        }
      }

      print('📊 Total revenue data points: ${revenue.length}');
      print('💵 Revenue summary: $revenue');

      // Convert large numbers to smaller units for chart rendering
      final convertedRevenue = <String, double>{};
      double maxValue = revenue.values.isNotEmpty
          ? revenue.values.reduce((a, b) => a > b ? a : b)
          : 0.0;

      if (maxValue >= 1000000) {
        // Convert to millions for chart rendering
        print('📊 Converting to millions for chart rendering...');
        _revenueUnit = 'triệu';
        for (final entry in revenue.entries) {
          convertedRevenue[entry.key] =
              entry.value / 1000000; // Convert to millions
        }
        print('📊 Converted revenue (millions): $convertedRevenue');
      } else if (maxValue >= 1000) {
        // Convert to thousands for chart rendering
        print('📊 Converting to thousands for chart rendering...');
        _revenueUnit = 'nghìn';
        for (final entry in revenue.entries) {
          convertedRevenue[entry.key] =
              entry.value / 1000; // Convert to thousands
        }
        print('📊 Converted revenue (thousands): $convertedRevenue');
      } else {
        // Use original values
        _revenueUnit = '₫';
        convertedRevenue.addAll(revenue);
      }

      if (convertedRevenue.isEmpty) {
        print('📊 No revenue found in range $startDate -> $endDate');
      }

      // Build full chronological window with zero-fill for missing days
      final sortedMap = <String, double>{};
      DateTime cursor = startDate;
      while (!cursor.isAfter(endDate)) {
        final key = '${cursor.day}/${cursor.month}';
        sortedMap[key] = convertedRevenue[key] ?? 0.0;
        cursor = cursor.add(const Duration(days: 1));
      }

      if (mounted) {
        setState(() => _revenueData = sortedMap);
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
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Theme.of(context).shadowColor.withOpacity(0.1),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Center(
                  child: CircularProgressIndicator(
                    color: Theme.of(context).primaryColor,
                    strokeWidth: 3,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                AppLocalizations.of(context)!.dashboard,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).textTheme.bodyLarge?.color,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                AppLocalizations.of(context)!.preparingAnalytics,
                style: TextStyle(
                  fontSize: 14,
                  color: Theme.of(context).textTheme.bodyMedium?.color,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SingleChildScrollView(
        padding: EdgeInsets.all(isSmallScreen ? 16.0 : 24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: 24),
            _buildStatsCards(),
            const SizedBox(height: 24),
            isSmallScreen ? _buildMobileChartsSection() : _buildChartsSection(),
            const SizedBox(height: 24),
            _buildRecentOrdersSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final l10n = AppLocalizations.of(context)!;
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
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.dashboard,
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      l10n.dashboardTagline,
                      style: const TextStyle(
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
              _buildQuickStat(l10n.revenue, _getTotalRevenueFormatted(),
                  Icons.attach_money, Colors.green),
              const SizedBox(width: 16),
              _buildQuickStat(l10n.orders, '${_statsData['orders'] ?? 0}',
                  Icons.shopping_cart_outlined, Colors.blue),
              const SizedBox(width: 16),
              _buildQuickStat(l10n.account, '${_statsData['users'] ?? 0}',
                  Icons.people_outline, Colors.orange),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStat(
      String title, String value, IconData icon, Color color) {
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
              dropdownColor: Theme.of(context).cardColor,
              style: TextStyle(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.white
                      : Colors.black,
                  fontSize: 14),
              icon:
                  const Icon(Icons.keyboard_arrow_down, color: Colors.white70),
              items: [
                DropdownMenuItem(
                  value: '7days',
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today, size: 16),
                      const SizedBox(width: 8),
                      Text(AppLocalizations.of(context)!.last7Days),
                    ],
                  ),
                ),
                DropdownMenuItem(
                  value: '1month',
                  child: Row(
                    children: [
                      const Icon(Icons.date_range, size: 16),
                      const SizedBox(width: 8),
                      Text(AppLocalizations.of(context)!.lastMonth),
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
    final l10n = AppLocalizations.of(context)!;
    final stats = [
      {
        'title': l10n.pets,
        'value': _statsData['pets'] ?? 0,
        'icon': Icons.pets,
        'color': Colors.blue
      },
      {
        'title': l10n.account,
        'value': _statsData['users'] ?? 0,
        'icon': Icons.people,
        'color': Colors.green
      },
      {
        'title': l10n.orders,
        'value': _statsData['orders'] ?? 0,
        'icon': Icons.shopping_cart,
        'color': Colors.orange
      },
      {
        'title': l10n.category,
        'value': _statsData['categories'] ?? 0,
        'icon': Icons.category,
        'color': Colors.purple
      },
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
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).shadowColor.withOpacity(0.1),
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
              // Icon(Icons.trending_up,
              //     color: Theme.of(context).brightness == Brightness.dark
              //         ? Colors.lightGreenAccent
              //         : Colors.green,
              //     size: 16),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            value.toString(),
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).textTheme.headlineLarge?.color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              color: Theme.of(context).textTheme.bodyMedium?.color,
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
    final l10n = AppLocalizations.of(context)!;
    if (_revenueLoading) {
      return ChartSkeleton(title: l10n.revenue);
    }

    return Container(
      height: 450,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).shadowColor.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 8),
            spreadRadius: 2,
          ),
        ],
        border: Border.all(
          color: Theme.of(context).dividerColor.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: Theme.of(context).dividerColor.withOpacity(0.1),
                  width: 1,
                ),
              ),
            ),
            child: Row(
              children: [
                // Container(
                //   padding: const EdgeInsets.all(8),
                //   decoration: BoxDecoration(
                //     color: (Theme.of(context).brightness == Brightness.dark
                //         ? const Color(0xFF2196F3)
                //         : const Color(0xFF4CAF50)).withOpacity(0.1),
                //     borderRadius: BorderRadius.circular(8),
                //   ),
                //   child: Icon(
                //     Icons.trending_up,
                //     color: Theme.of(context).brightness == Brightness.dark
                //         ? const Color(0xFF2196F3)
                //         : const Color(0xFF4CAF50),
                //     size: 20,
                //   ),
                // ),
                const SizedBox(width: 12),
                Text(
                  l10n.revenue,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).textTheme.headlineSmall?.color,
                  ),
                ),
                const Spacer(),
                // Container(
                //   padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                //   decoration: BoxDecoration(
                //     color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                //     borderRadius: BorderRadius.circular(12),
                //   ),
                //   child: Text(
                //     '(${_getChartUnit()})',
                //     style: TextStyle(
                //       fontSize: 12,
                //       fontWeight: FontWeight.w600,
                //       color: Theme.of(context).colorScheme.primary,
                //       fontStyle: FontStyle.italic,
                //     ),
                //   ),
                // ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: _revenueData.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.show_chart,
                          size: 64,
                          color: Theme.of(context)
                              .iconTheme
                              .color
                              ?.withOpacity(0.3),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          AppLocalizations.of(context)!.noDataAvailable,
                          style: TextStyle(
                            color:
                                Theme.of(context).textTheme.bodyMedium?.color,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Data will appear when orders are completed',
                          style: TextStyle(
                            color: Theme.of(context).textTheme.bodySmall?.color,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  )
                : LineChart(
                    LineChartData(
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        horizontalInterval: _computeYInterval(),
                        verticalInterval: 1,
                        getDrawingHorizontalLine: (value) => FlLine(
                          color: Theme.of(context).dividerColor.withOpacity(0.1),
                          strokeWidth: 0.8,
                          dashArray: [5, 5],
                        ),
                      ),
                      titlesData: FlTitlesData(
                        show: true,
                        rightTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false)),
                        topTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false)),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 40,
                            interval: 1,
                            getTitlesWidget: (value, meta) {
                              final idx = value.toInt();
                              final dates = _revenueData.keys.toList();
                              if (idx < 0 || idx >= dates.length) {
                                return const SizedBox.shrink();
                              }
                              
                              // Smart label display based on data density
                              final shouldShow = _shouldShowLabel(idx, dates.length);
                              if (!shouldShow) return const SizedBox.shrink();
                              
                              final parts = dates[idx].split('/');
                              final day = parts[0];
                              final month = parts[1];
                              
                              return Container(
                                margin: const EdgeInsets.only(top: 8),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      day,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: Theme.of(context).textTheme.bodyMedium?.color,
                                      ),
                                    ),
                                    Text(
                                      month,
                                      style: TextStyle(
                                        fontSize: 9,
                                        color: Theme.of(context).textTheme.bodySmall?.color?.withOpacity(0.7),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 60,
                            interval: _computeYInterval(),
                            getTitlesWidget: (value, meta) {
                              return Container(
                                margin: const EdgeInsets.only(right: 8),
                                child: Text(
                                  _formatChartCurrency(value),
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                    color: Theme.of(context).textTheme.bodySmall?.color,
                                  ),
                                  textAlign: TextAlign.right,
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      borderData: FlBorderData(
                        show: true,
                        border: Border(
                          left: BorderSide(
                            color: Theme.of(context).dividerColor.withOpacity(0.3),
                            width: 1,
                          ),
                          bottom: BorderSide(
                            color: Theme.of(context).dividerColor.withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                      ),
                      minX: 0,
                      maxX: (_revenueData.length - 1).toDouble(),
                      minY: 0,
            maxY: _computeMaxY(),
                      lineTouchData: LineTouchData(
                        enabled: true,
                        touchTooltipData: LineTouchTooltipData(
                          tooltipBgColor: Theme.of(context).cardColor.withOpacity(0.95),
                          tooltipBorder: BorderSide(
                            color: Theme.of(context).dividerColor.withOpacity(0.3),
                            width: 1,
                          ),
                          tooltipRoundedRadius: 8,
                          tooltipPadding: const EdgeInsets.all(8),
                          getTooltipItems: (List<LineBarSpot> touchedSpots) {
                            return touchedSpots.map((LineBarSpot touchedSpot) {
                              final dates = _revenueData.keys.toList();
                              final date = dates[touchedSpot.x.toInt()];
                              final value = touchedSpot.y;
                              return LineTooltipItem(
                                '$date\n${_formatChartCurrency(value)} ${_getChartUnit()}',
                                TextStyle(
                                  color: Theme.of(context).textTheme.bodyMedium?.color,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              );
                            }).toList();
                          },
                        ),
                        handleBuiltInTouches: true,
                        touchSpotThreshold: 50,
                      ),
                      lineBarsData: [
                        LineChartBarData(
                          spots: _revenueData.entries.map((entry) {
                            final index =
                                _revenueData.keys.toList().indexOf(entry.key);
                            return FlSpot(index.toDouble(), entry.value);
                          }).toList(),
                          isCurved: true,
                          curveSmoothness: 0.35,
                          preventCurveOverShooting: true,
                          gradient: LinearGradient(
                            colors: Theme.of(context).brightness == Brightness.dark
                                ? [
                                    const Color(0xFF64B5F6),
                                    const Color(0xFF42A5F5),
                                    const Color(0xFF2196F3),
                                  ]
                                : [
                                    const Color(0xFF4CAF50),
                                    const Color(0xFF66BB6A),
                                    const Color(0xFF81C784),
                                  ],
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                          ),
                          barWidth: 3.5,
                          isStrokeCapRound: true,
                          belowBarData: BarAreaData(
                            show: true,
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: Theme.of(context).brightness == Brightness.dark
                                  ? [
                                      const Color(0xFF2196F3).withOpacity(0.25),
                                      const Color(0xFF2196F3).withOpacity(0.1),
                                      Colors.transparent,
                                    ]
                                  : [
                                      const Color(0xFF4CAF50).withOpacity(0.25),
                                      const Color(0xFF4CAF50).withOpacity(0.1),
                                      Colors.transparent,
                                    ],
                            ),
                          ),
                          dotData: FlDotData(
                            show: true,
                            getDotPainter: (spot, percent, barData, index) {
                              final isHighlight = spot.y > 0;
                              return FlDotCirclePainter(
                                radius: isHighlight ? 5 : 3,
                                color: isHighlight
                                    ? (Theme.of(context).brightness == Brightness.dark
                                        ? const Color(0xFF2196F3)
                                        : const Color(0xFF4CAF50))
                                    : Theme.of(context).dividerColor.withOpacity(0.5),
                                strokeWidth: isHighlight ? 2.5 : 1,
                                strokeColor: Colors.white,
                              );
                            },
                          ),
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
    final l10n = AppLocalizations.of(context)!;
    return Container(
      height: 400,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).shadowColor.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.orders,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).textTheme.headlineSmall?.color,
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
                  final total = _orderStatusData.values
                      .fold<int>(0, (sum, value) => sum + value);
                  final percentage =
                      total > 0 ? (entry.value / total * 100).round() : 0;

                  return PieChartSectionData(
                    value: entry.value.toDouble(),
                    color: colors[entry.key] ?? Colors.grey,
                    title: '$percentage%',
                    radius: 50,
                    titleStyle: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      shadows: [
                        Shadow(
                          color: Colors.black.withOpacity(0.8),
                          blurRadius: 1,
                        ),
                      ],
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
                    Text(entry.key,
                        style: TextStyle(
                            color:
                                Theme.of(context).textTheme.bodyMedium?.color)),
                    const Spacer(),
                    Text(
                      entry.value.toString(),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).textTheme.bodyLarge?.color,
                      ),
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
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).shadowColor.withOpacity(0.1),
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
              Text(
                AppLocalizations.of(context)!.recentOrders,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).textTheme.headlineSmall?.color,
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: () {
                  if (widget.onNavigateToTab != null) {
                    widget.onNavigateToTab!(4); // Orders tab index in HomePageAdmin
                  } else {
                    // fallback push
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const OrdersAdmin()),
                    );
                  }
                },
                child: Text(AppLocalizations.of(context)!.viewAll),
              ),
            ],
          ),
          const SizedBox(height: 24),
          if (_recentOrders.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(40),
                child: Text(AppLocalizations.of(context)!.noDataAvailable,
                    style: TextStyle(
                        color: Theme.of(context).textTheme.bodyMedium?.color)),
              ),
            )
          else
            Column(
              children:
                  _recentOrders.map((order) => _buildOrderRow(order)).toList(),
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
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).dividerColor, width: 1),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).shadowColor.withOpacity(0.05),
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
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Theme.of(context).textTheme.bodyLarge?.color,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: order['source'] == 'Mobile'
                            ? (Theme.of(context).brightness == Brightness.dark
                                ? Colors.blue.withOpacity(0.2)
                                : Colors.blue.withOpacity(0.1))
                            : (Theme.of(context).brightness == Brightness.dark
                                ? Colors.purple.withOpacity(0.2)
                                : Colors.purple.withOpacity(0.1)),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        order['source'],
                        style: TextStyle(
                          color: order['source'] == 'Mobile'
                              ? (Theme.of(context).brightness == Brightness.dark
                                  ? Colors.lightBlueAccent
                                  : Colors.blue[700])
                              : (Theme.of(context).brightness == Brightness.dark
                                  ? Colors.purpleAccent
                                  : Colors.purple[700]),
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
                      color: Theme.of(context).textTheme.bodyMedium?.color,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Order #${order['id'].toString().substring(0, 8)}',
                      style: TextStyle(
                        color: Theme.of(context).textTheme.bodyMedium?.color,
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: order['status'] == 'Completed'
                      ? (Theme.of(context).brightness == Brightness.dark
                          ? Colors.green.withOpacity(0.2)
                          : Colors.green.withOpacity(0.1))
                      : order['status'] == 'Pending'
                          ? (Theme.of(context).brightness == Brightness.dark
                              ? Colors.orange.withOpacity(0.2)
                              : Colors.orange.withOpacity(0.1))
                          : (Theme.of(context).brightness == Brightness.dark
                              ? Colors.blue.withOpacity(0.2)
                              : Colors.blue.withOpacity(0.1)),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  order['status'],
                  style: TextStyle(
                    color: order['status'] == 'Completed'
                        ? (Theme.of(context).brightness == Brightness.dark
                            ? Colors.lightGreenAccent
                            : Colors.green[700])
                        : order['status'] == 'Pending'
                            ? (Theme.of(context).brightness == Brightness.dark
                                ? Colors.orangeAccent
                                : Colors.orange[700])
                            : (Theme.of(context).brightness == Brightness.dark
                                ? Colors.lightBlueAccent
                                : Colors.blue[700]),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                CurrencyHelper.formatVND(order['totalAmount']),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: Theme.of(context).textTheme.bodyLarge?.color,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) {
      return double.tryParse(value) ?? 0.0;
    }
    return 0.0;
  }

  // Smart currency formatting for charts - works with pre-converted data
  String _formatChartCurrency(double convertedAmount) {
    // Format based on current unit scale₫
    if (_revenueUnit == 'triệu') {
      return convertedAmount.toStringAsFixed(1); // Show decimals for millions
    } else if (_revenueUnit == 'nghìn') {
      return convertedAmount.toStringAsFixed(0); // No decimals for thousands
    } else {
      return convertedAmount.toStringAsFixed(0); // No decimals for original
    }
  }

  // Get chart unit label
  String _getChartUnit() {
    return _revenueUnit;
  }

  double _computeMaxY() {
    if (_revenueData.isEmpty) return 10;
    final maxVal = _revenueData.values.reduce((a, b) => a > b ? a : b);
    if (maxVal == 0) return 10;
    // Round up to a nice step (1,2,5 * 10^n)
  double magnitude = math.pow(10, (math.log(maxVal) / math.ln10).floor()).toDouble();
  double normalized = maxVal / magnitude;
    double nice;
    if (normalized <= 1) {
      nice = 1;
    } else if (normalized <= 2) {
      nice = 2;
    } else if (normalized <= 5) {
      nice = 5;
    } else {
      nice = 10;
    }
    return (nice * magnitude) * 1.1; // small headroom
  }

  double _computeYInterval() {
    final maxY = _computeMaxY();
    if (maxY <= 10) return 2;
    return (maxY / 5).ceilToDouble();
  }

  bool _shouldShowLabel(int index, int totalLength) {
    // Always show first and last
    if (index == 0 || index == totalLength - 1) return true;
    
    // For 7 days, show every other day
    if (totalLength <= 7) return index % 2 == 0;
    
    // For longer periods, show every 3rd-4th day
    if (totalLength <= 14) return index % 3 == 0;
    
    // For very long periods, show every 5th day
    return index % 5 == 0;
  }
}
