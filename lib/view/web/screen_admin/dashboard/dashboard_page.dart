import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:pet_shop/utils/contants.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  Map<String, int> _statsData = {};
  List<Map<String, dynamic>> _recentOrders = [];
  Map<String, double> _revenueData = {};
  Map<String, int> _orderStatusData = {};
  String? _selectedCategory;  // Track which category is selected
  bool _loading = true;
  bool _revenueLoading = false;
  bool _statsLoading = false;
  bool _categoryDataLoading = false;
  bool _recentOrdersLoading = false;
  bool _petsDataLoading = false;
  bool _usersDataLoading = false;
  
  // Time range selection for revenue
  String _timeRange = '7days'; // '7days', '1month', '3months', 'custom', 'all'
  DateTimeRange? _customRange;
  
  // Category-specific data
  Map<String, dynamic> _categoryData = {};
  Map<String, dynamic> _petsData = {};
  Map<String, dynamic> _usersData = {};

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    try {
      // Load critical data first for immediate display
      await Future.wait([
        _loadStatsData(),
        _loadRecentOrders(),
      ]);
      
      if (mounted) {
        setState(() => _loading = false);
      }
      
      // Load secondary data in background
      _loadSecondaryData();
    } catch (e) {
      print('Error loading dashboard data: $e');
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _loadSecondaryData() async {
    try {
      // Load revenue first as it's most important
      await _loadRevenueData();
      
      // Then load charts data
      await Future.wait([
        _loadOrderStatusData(),
        _loadCategorySpecificData(),
      ]);
    } catch (e) {
      print('Error loading secondary data: $e');
    }
  }

  Future<void> _loadStatsData() async {
    setState(() => _statsLoading = true);
    
    try {
      final stats = <String, int>{};
      
      // Count pets
      final petsSnapshot = await FirebaseFirestore.instance.collection('Pets').get();
      stats['pets'] = petsSnapshot.size;
      
      // Count users
      final usersSnapshot = await FirebaseFirestore.instance.collection('users').get();
      stats['users'] = usersSnapshot.size;
      
      // Count orders from both mobile and web
      final ordersSnapshot = await FirebaseFirestore.instance.collection('orders').get();
      final ordersWebSnapshot = await FirebaseFirestore.instance.collection('ordersWeb').get();
      stats['orders'] = ordersSnapshot.size + ordersWebSnapshot.size;
      
      // Count categories - try different possible collection names
      int categoriesCount = 0;
      try {
        final categoriesSnapshot = await FirebaseFirestore.instance.collection('Category').get();
        categoriesCount += categoriesSnapshot.size;
      } catch (e) {
        print('No categories collection: $e');
      }
      
      stats['categories'] = categoriesCount;
      
      print('📊 Stats loaded: $stats');
      setState(() => _statsData = stats);
    } catch (e) {
      print('❌ Error loading stats data: $e');
    } finally {
      setState(() => _statsLoading = false);
    }
  }

  Future<void> _loadRecentOrders() async {
    setState(() => _recentOrdersLoading = true);
    
    try {
      // Get recent orders from both collections without orderBy first
      final ordersSnapshot = await FirebaseFirestore.instance
          .collection('orders')
          .limit(20)  // Get more to sort later
          .get();
      
      final ordersWebSnapshot = await FirebaseFirestore.instance
          .collection('ordersWeb')
          .limit(20)  // Get more to sort later
          .get();
    
    final allOrders = <Map<String, dynamic>>[];
    
    // Process mobile orders
    allOrders.addAll(ordersSnapshot.docs.map((doc) {
      final data = doc.data();
      return {
        'id': doc.id,
        'customerName': data['fullName'] ?? data['name'] ?? data['customerName'] ?? 'Unknown',
        'totalAmount': (data['totalAmount'] ?? 0.0).toDouble(),
        'status': data['statusOrder'] ?? data['status'] ?? 'Pending',
        'timestamp': data['timestamp'] ?? data['createdAt'] ?? data['created_at'] ?? Timestamp.now(),
        'source': 'Mobile App',
      };
    }).toList());
    
    // Process web orders
    allOrders.addAll(ordersWebSnapshot.docs.map((doc) {
      final data = doc.data();
      return {
        'id': doc.id,
        'customerName': data['fullName'] ?? data['name'] ?? data['customerName'] ?? 'Unknown',
        'totalAmount': (data['totalAmount'] ?? 0.0).toDouble(),
        'status': data['statusOrder'] ?? data['status'] ?? 'Pending',
        'timestamp': data['timestamp'] ?? data['createdAt'] ?? data['created_at'] ?? Timestamp.now(),
        'source': 'Web App',
      };
    }).toList());
    
    print('📊 Dashboard: Found ${allOrders.length} total orders');
    allOrders.forEach((order) {
      print('  - ${order['customerName']}: \$${order['totalAmount']} (${order['source']})');
    });
    
    // Sort by timestamp and take top 5
    allOrders.sort((a, b) {
      final aTime = a['timestamp'];
      final bTime = b['timestamp'];
      
      // Handle different timestamp types
      DateTime aDateTime = DateTime.now();
      DateTime bDateTime = DateTime.now();
      
      if (aTime is Timestamp) {
        aDateTime = aTime.toDate();
      } else if (aTime is String) {
        aDateTime = DateTime.tryParse(aTime) ?? DateTime.now();
      }
      
      if (bTime is Timestamp) {
        bDateTime = bTime.toDate();
      } else if (bTime is String) {
        bDateTime = DateTime.tryParse(bTime) ?? DateTime.now();
      }
      
      return bDateTime.compareTo(aDateTime);  // Newest first
    });
    
    final recentOrders = allOrders.take(5).toList();
    print('📋 Dashboard: Recent orders count: ${recentOrders.length}');
    
    setState(() => _recentOrders = recentOrders);
    } catch (e) {
      print('❌ Error loading recent orders: $e');
    } finally {
      setState(() => _recentOrdersLoading = false);
    }
  }

  Future<void> _loadRevenueData() async {
    setState(() => _revenueLoading = true);
    
    try {
      DateTime endDate = DateTime.now();
      DateTime startDate;
      
      switch (_timeRange) {
        case '7days':
          startDate = endDate.subtract(const Duration(days: 7));
          break;
        case '1month':
          startDate = DateTime(endDate.year, endDate.month - 1, endDate.day);
          break;
        case '3months':
          startDate = DateTime(endDate.year, endDate.month - 3, endDate.day);
          break;
        case 'custom':
          if (_customRange != null) {
            startDate = _customRange!.start;
            endDate = _customRange!.end;
          } else {
            startDate = endDate.subtract(const Duration(days: 7));
          }
          break;
        case 'all':
          startDate = DateTime(2020, 1, 1); // Start from a very early date
          break;
        default:
          startDate = endDate.subtract(const Duration(days: 7));
      }
      
      final revenue = <String, double>{};
      
      print('📅 Loading revenue data from ${startDate.toString().split(' ')[0]} to ${endDate.toString().split(' ')[0]}');
      
      // Generate date range
      DateTime currentDate = startDate;
      int dayCount = 0;
      const maxDays = 100; // Giới hạn số ngày để tránh quá tải
      
      while (currentDate.isBefore(endDate) || currentDate.isAtSameMomentAs(endDate)) {
        if (dayCount >= maxDays) {
          print('⚠️ Limiting to $maxDays days to prevent overload');
          break;
        }
        
        final dayStart = DateTime(currentDate.year, currentDate.month, currentDate.day);
        final dayEnd = dayStart.add(const Duration(days: 1));
        
        // Get revenue from mobile orders - query without status filter first
        final ordersSnapshot = await FirebaseFirestore.instance
            .collection('orders')
            .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(dayStart))
            .where('timestamp', isLessThan: Timestamp.fromDate(dayEnd))
            .get();
        
        // Get revenue from web orders - query without status filter first
        final ordersWebSnapshot = await FirebaseFirestore.instance
            .collection('ordersWeb')
            .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(dayStart))
            .where('timestamp', isLessThan: Timestamp.fromDate(dayEnd))
            .get();
        
        double dayRevenue = 0;
        
        // Sum mobile orders revenue - filter status in code
        for (final doc in ordersSnapshot.docs) {
          final data = doc.data();
          final status = data['statusOrder'] ?? '';
          if (status == 'Completed') {
            final amount = (data['totalAmount'] ?? 0.0).toDouble();
            dayRevenue += amount;
          }
        }
        
        // Sum web orders revenue - filter status in code
        for (final doc in ordersWebSnapshot.docs) {
          final data = doc.data();
          final paymentStatus = data['statusPayment'] ?? '';
          if (paymentStatus == 'Payment Completed') {
            final amount = (data['totalAmount'] ?? 0.0).toDouble();
            dayRevenue += amount;
          }
        }
        
        revenue['${currentDate.month}/${currentDate.day}'] = dayRevenue;
        currentDate = currentDate.add(const Duration(days: 1));
        dayCount++;
        
        // Update UI every 10 days for better UX
        if (dayCount % 10 == 0) {
          setState(() => _revenueData = Map.from(revenue));
        }
      }
      
      print('📊 Revenue Summary: ${revenue.length} days, Total: \$${revenue.values.fold<double>(0, (sum, val) => sum + val)}');
      setState(() => _revenueData = revenue);
    } catch (e) {
      print('❌ Error loading revenue data: $e');
    } finally {
      setState(() => _revenueLoading = false);
    }
  }

  Future<void> _loadOrderStatusData() async {
    final statusData = <String, int>{
      'Completed': 0,
      'Pending': 0,
      'Processing': 0,
      'Cancelled': 0,
    };
    
    // Get status data from mobile orders
    final ordersSnapshot = await FirebaseFirestore.instance.collection('orders').get();
    print('📱 Mobile orders found: ${ordersSnapshot.docs.length}');
    for (final doc in ordersSnapshot.docs) {
      final status = doc.data()['statusOrder'] ?? 'Pending';
      if (statusData.containsKey(status)) {
        statusData[status] = statusData[status]! + 1;
      }
      print('  - Order ${doc.id}: $status');
    }
    
    // Get status data from web orders
    final ordersWebSnapshot = await FirebaseFirestore.instance.collection('ordersWeb').get();
    print('🌐 Web orders found: ${ordersWebSnapshot.docs.length}');
    for (final doc in ordersWebSnapshot.docs) {
      final data = doc.data();
      final status = data['statusOrder'] ?? 'Pending';
      final paymentStatus = data['statusPayment'] ?? 'Unknown';
      if (statusData.containsKey(status)) {
        statusData[status] = statusData[status]! + 1;
      }
      print('  - Order ${doc.id}: $status (Payment: $paymentStatus)');
    }
    
    print('📊 Order Status Summary: $statusData');
    setState(() => _orderStatusData = statusData);
  }

  Future<void> _loadCategorySpecificData() async {
    setState(() {
      _categoryDataLoading = true;
      _petsDataLoading = true;
      _usersDataLoading = true;
    });
    
    try {
      // Load category distribution data
      final categoriesSnapshot = await FirebaseFirestore.instance
          .collection('Pets')
          .get();
    
    Map<String, int> categoryDistribution = {};
    Map<String, int> breedDistribution = {};
    Map<String, int> ageDistribution = {};
    
    for (final doc in categoriesSnapshot.docs) {
      final data = doc.data();
      final category = data['category'] ?? 'Unknown';
      final breed = data['breed'] ?? 'Unknown';
      final age = data['age'] ?? 'Unknown';
      
      categoryDistribution[category] = (categoryDistribution[category] ?? 0) + 1;
      breedDistribution[breed] = (breedDistribution[breed] ?? 0) + 1;
      ageDistribution[age] = (ageDistribution[age] ?? 0) + 1;
    }
    
    _categoryData = {
      'distribution': categoryDistribution,
      'total': categoriesSnapshot.size,
    };
    
    _petsData = {
      'breeds': breedDistribution,
      'ages': ageDistribution,
      'categories': categoryDistribution,
      'total': categoriesSnapshot.size,
    };
    
    // Load user registration data
    final usersSnapshot = await FirebaseFirestore.instance
        .collection('users')
        .get();
    
    Map<String, int> userRegistrationByMonth = {};
    DateTime now = DateTime.now();
    
    for (int i = 11; i >= 0; i--) {
      final date = DateTime(now.year, now.month - i, 1);
      final key = '${date.month}/${date.year}';
      userRegistrationByMonth[key] = 0;
    }
    
    for (final doc in usersSnapshot.docs) {
      final data = doc.data();
      final timestamp = data['createdAt'] ?? data['timestamp'];
      
      if (timestamp != null) {
        DateTime createdDate;
        if (timestamp is Timestamp) {
          createdDate = timestamp.toDate();
        } else if (timestamp is String) {
          createdDate = DateTime.tryParse(timestamp) ?? DateTime.now();
        } else {
          continue;
        }
        
        final key = '${createdDate.month}/${createdDate.year}';
        if (userRegistrationByMonth.containsKey(key)) {
          userRegistrationByMonth[key] = userRegistrationByMonth[key]! + 1;
        }
      }
    }
    
    _usersData = {
      'registrationByMonth': userRegistrationByMonth,
      'total': usersSnapshot.size,
    };
    } catch (e) {
      print('❌ Error loading category/pets data: $e');
    } finally {
      setState(() {
        _categoryDataLoading = false;
        _petsDataLoading = false;
        _usersDataLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: primaryColor),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                const Icon(Icons.dashboard, size: 32, color: primaryColor),
                const SizedBox(width: 12),
                const Text(
                  'Dashboard',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: primaryColor,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => _loadDashboardData(),
                  icon: const Icon(Icons.refresh),
                  tooltip: 'Refresh Data',
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Stats Cards Row
            Row(
              children: [
                Expanded(child: _buildStatsCard('Pets', _statsData['pets'] ?? 0, Icons.pets, Colors.blue)),
                const SizedBox(width: 16),
                Expanded(child: _buildStatsCard('Users', _statsData['users'] ?? 0, Icons.people, Colors.green)),
                const SizedBox(width: 16),
                Expanded(child: _buildStatsCard('Orders', _statsData['orders'] ?? 0, Icons.shopping_cart, Colors.orange)),
                const SizedBox(width: 16),
                Expanded(child: _buildStatsCard('Categories', _statsData['categories'] ?? 0, Icons.category, Colors.purple)),
              ],
            ),
            const SizedBox(height: 32),

            // Dynamic Charts Row based on selected category
            _buildDynamicChartsSection(),
            
            const SizedBox(height: 32),

            // Dynamic Table based on selected category
            _buildDynamicTableSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsCard(String title, int value, IconData icon, Color color) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedCategory = title.toLowerCase();
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Showing detailed view for $title'),
            duration: const Duration(seconds: 2),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: _selectedCategory == title.toLowerCase() 
              ? color.withOpacity(0.1) 
              : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: _selectedCategory == title.toLowerCase()
              ? Border.all(color: color, width: 2)
              : null,
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              spreadRadius: 1,
              blurRadius: 10,
              offset: const Offset(0, 3),
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
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: color, size: 24),
                ),
                const Spacer(),
                _statsLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.grey),
                        ),
                      )
                    : Text(
                        value.toString(),
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDynamicChartsSection() {
    if (_selectedCategory == null) {
      // Default view - show revenue and order status
      return Row(
        children: [
          Expanded(
            flex: 2,
            child: _buildRevenueChart(),
          ),
          const SizedBox(width: 24),
          Expanded(
            child: _buildOrdersStatusChart(),
          ),
        ],
      );
    }

    switch (_selectedCategory) {
      case 'orders':
        return Row(
          children: [
            Expanded(
              flex: 2,
              child: _buildRevenueChart(),
            ),
            const SizedBox(width: 24),
            Expanded(
              child: _buildOrdersStatusChart(),
            ),
          ],
        );
      case 'pets':
        return Row(
          children: [
            Expanded(
              child: _buildPetCategoryChart(),
            ),
            const SizedBox(width: 24),
            Expanded(
              child: _buildPetBreedChart(),
            ),
          ],
        );
      case 'users':
        return Row(
          children: [
            Expanded(
              flex: 2,
              child: _buildUserRegistrationChart(),
            ),
            const SizedBox(width: 24),
            Expanded(
              child: _buildRevenueChart(),
            ),
          ],
        );
      case 'categories':
        return Row(
          children: [
            Expanded(
              flex: 2,
              child: _buildCategoryDistributionChart(),
            ),
            const SizedBox(width: 24),
            Expanded(
              child: _buildPetCategoryChart(),
            ),
          ],
        );
      default:
        return Row(
          children: [
            Expanded(
              flex: 2,
              child: _buildRevenueChart(),
            ),
            const SizedBox(width: 24),
            Expanded(
              child: _buildOrdersStatusChart(),
            ),
          ],
        );
    }
  }

  Widget _buildDynamicTableSection() {
    if (_selectedCategory == null) {
      return _buildRecentOrdersTable();
    }

    switch (_selectedCategory) {
      case 'orders':
        return _buildRecentOrdersTable();
      case 'pets':
        return _buildPetsTable();
      case 'users':
        return _buildUsersTable();
      case 'categories':
        return _buildCategoriesTable();
      default:
        return _buildRecentOrdersTable();
    }
  }

  Widget _buildRevenueChart() {
    return Container(
      height: 300,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                _getRevenueTitle(),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_revenueLoading) ...[
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  _buildTimeRangeSelector(),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          Expanded(
            child: _revenueLoading
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(color: primaryColor),
                        SizedBox(height: 16),
                        Text(
                          'Loading revenue data...',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  )
                : _revenueData.isEmpty
                    ? const Center(
                        child: Text(
                          'No revenue data available',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey,
                          ),
                        ),
                      )
                    : LineChart(
                        LineChartData(
                          gridData: FlGridData(show: true),
                          titlesData: FlTitlesData(
                            bottomTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                getTitlesWidget: (value, meta) {
                                  final dates = _revenueData.keys.toList();
                                  if (value.toInt() < dates.length) {
                                    return Text(
                                      dates[value.toInt()],
                                      style: const TextStyle(fontSize: 10),
                                    );
                                  }
                                  return const Text('');
                                },
                                reservedSize: 30,
                              ),
                            ),
                            leftTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                getTitlesWidget: (value, meta) {
                                  return Text(
                                    '\$${value.toInt()}',
                                    style: const TextStyle(fontSize: 10),
                                  );
                                },
                                reservedSize: 50,
                              ),
                            ),
                            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          ),
                          borderData: FlBorderData(show: true),
                          lineBarsData: [
                            LineChartBarData(
                              spots: _revenueData.values
                                  .toList()
                                  .asMap()
                                  .entries
                                  .map((e) => FlSpot(e.key.toDouble(), e.value))
                                  .toList(),
                              isCurved: true,
                              color: primaryColor,
                              barWidth: 3,
                              dotData: const FlDotData(show: true),
                              belowBarData: BarAreaData(
                                show: true,
                                color: primaryColor.withOpacity(0.1),
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

  String _getRevenueTitle() {
    switch (_timeRange) {
      case '7days':
        return 'Revenue (Last 7 Days)';
      case '1month':
        return 'Revenue (Last Month)';
      case '3months':
        return 'Revenue (Last 3 Months)';
      case 'custom':
        return 'Revenue (Custom Range)';
      case 'all':
        return 'Revenue (All Time)';
      default:
        return 'Revenue';
    }
  }

  Widget _buildTimeRangeSelector() {
    return PopupMenuButton<String>(
      initialValue: _timeRange,
      icon: Row(
        mainAxisSize: MainAxisSize.min,
        children: const [
          Icon(Icons.access_time, size: 16),
          SizedBox(width: 4),
          Icon(Icons.arrow_drop_down, size: 16),
        ],
      ),
      onSelected: (String value) async {
        if (value == 'custom') {
          final DateTimeRange? picked = await showDateRangePicker(
            context: context,
            firstDate: DateTime(2020),
            lastDate: DateTime.now(),
            initialDateRange: _customRange,
          );
          if (picked != null) {
            setState(() {
              _timeRange = value;
              _customRange = picked;
            });
            _loadRevenueData();
          }
        } else {
          setState(() {
            _timeRange = value;
          });
          _loadRevenueData();
        }
      },
      itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
        const PopupMenuItem<String>(
          value: '7days',
          child: Text('Last 7 Days'),
        ),
        const PopupMenuItem<String>(
          value: '1month',
          child: Text('Last Month'),
        ),
        const PopupMenuItem<String>(
          value: '3months',
          child: Text('Last 3 Months'),
        ),
        const PopupMenuItem<String>(
          value: 'custom',
          child: Text('Custom Range'),
        ),
        const PopupMenuItem<String>(
          value: 'all',
          child: Text('All Time'),
        ),
      ],
    );
  }

  Widget _buildOrdersStatusChart() {
    return Container(
      height: 300,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Orders Status',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: PieChart(
              PieChartData(
                sections: _buildPieChartSections(),
                centerSpaceRadius: 30,
                sectionsSpace: 2,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentOrdersTable() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Recent Orders',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          _recentOrdersLoading
              ? Container(
                  padding: const EdgeInsets.all(40),
                  child: const Center(
                    child: Column(
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 10),
                        Text(
                          'Loading recent orders...',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : _recentOrders.isEmpty
                  ? Container(
                      padding: const EdgeInsets.all(20),
                      child: const Center(
                        child: Text(
                          'No recent orders found',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey,
                          ),
                        ),
                      ),
                    )
                  : Table(
            columnWidths: const {
              0: FlexColumnWidth(2),
              1: FlexColumnWidth(2),
              2: FlexColumnWidth(1),
              3: FlexColumnWidth(1),
              4: FlexColumnWidth(1),
            },
            children: [
              TableRow(
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                children: const [
                  Padding(
                    padding: EdgeInsets.all(12),
                    child: Text(
                      'Order ID',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.all(12),
                    child: Text(
                      'Customer',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.all(12),
                    child: Text(
                      'Amount',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.all(12),
                    child: Text(
                      'Status',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.all(12),
                    child: Text(
                      'Source',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              ..._recentOrders.map((order) {
                return TableRow(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(
                        order['id'].toString().substring(0, 8),
                        style: const TextStyle(fontFamily: 'monospace'),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(order['customerName']),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text('\$${order['totalAmount'].toStringAsFixed(2)}'),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: order['status'] == 'Completed'
                              ? Colors.green.withOpacity(0.1)
                              : Colors.orange.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          order['status'],
                          style: TextStyle(
                            color: order['status'] == 'Completed'
                                ? Colors.green[700]
                                : Colors.orange[700],
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: order['source'] == 'Mobile App'
                              ? Colors.blue.withOpacity(0.1)
                              : Colors.purple.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          order['source'],
                          style: TextStyle(
                            color: order['source'] == 'Mobile App'
                                ? Colors.blue[700]
                                : Colors.purple[700],
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              }).toList(),
            ],
          ),
        ],
      ),
    );
  }

  List<PieChartSectionData> _buildPieChartSections() {
    final total = _orderStatusData.values.fold<int>(0, (sum, count) => sum + count);
    if (total == 0) {
      return [
        PieChartSectionData(
          value: 1,
          color: Colors.grey,
          title: 'No Data',
          radius: 60,
          titleStyle: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ];
    }

    final colors = {
      'Completed': Colors.green,
      'Pending': Colors.orange,
      'Processing': Colors.blue,
      'Cancelled': Colors.red,
    };

    return _orderStatusData.entries.where((entry) => entry.value > 0).map((entry) {
      final percentage = (entry.value / total * 100).round();
      return PieChartSectionData(
        value: entry.value.toDouble(),
        color: colors[entry.key] ?? Colors.grey,
        title: '${entry.key}\n$percentage%',
        radius: 60,
        titleStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      );
    }).toList();
  }

  // Pet-specific charts
  Widget _buildPetCategoryChart() {
    final data = _petsData['categories'] as Map<String, int>? ?? {};
    return _buildPieChart('Pet Categories', data, [
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.red,
    ], _petsDataLoading);
  }

  Widget _buildPetBreedChart() {
    final data = _petsData['breeds'] as Map<String, int>? ?? {};
    final topBreeds = data.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final top5Breeds = Map<String, int>.fromEntries(
      topBreeds.take(5)
    );
    return _buildPieChart('Top 5 Breeds', top5Breeds, [
      Colors.indigo,
      Colors.teal,
      Colors.amber,
      Colors.deepOrange,
      Colors.pink,
    ], _petsDataLoading);
  }

  // User-specific charts
  Widget _buildUserRegistrationChart() {
    final data = _usersData['registrationByMonth'] as Map<String, int>? ?? {};
    return Container(
      height: 300,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'User Registrations (Last 12 Months)',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: _usersDataLoading
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 10),
                        Text(
                          'Loading user registration data...',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  )
                : LineChart(
              LineChartData(
                gridData: FlGridData(show: true),
                titlesData: FlTitlesData(
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        final dates = data.keys.toList();
                        if (value.toInt() < dates.length) {
                          return Text(
                            dates[value.toInt()],
                            style: const TextStyle(fontSize: 10),
                          );
                        }
                        return const Text('');
                      },
                      reservedSize: 30,
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          '${value.toInt()}',
                          style: const TextStyle(fontSize: 10),
                        );
                      },
                      reservedSize: 50,
                    ),
                  ),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(show: true),
                lineBarsData: [
                  LineChartBarData(
                    spots: data.values
                        .toList()
                        .asMap()
                        .entries
                        .map((e) => FlSpot(e.key.toDouble(), e.value.toDouble()))
                        .toList(),
                    isCurved: true,
                    color: Colors.green,
                    barWidth: 3,
                    dotData: const FlDotData(show: true),
                    belowBarData: BarAreaData(
                      show: true,
                      color: Colors.green.withOpacity(0.1),
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

  // Category-specific charts
  Widget _buildCategoryDistributionChart() {
    final data = _categoryData['distribution'] as Map<String, int>? ?? {};
    return _buildPieChart('Category Distribution', data, [
      Colors.purple,
      Colors.indigo,
      Colors.blue,
      Colors.teal,
      Colors.green,
    ], _categoryDataLoading);
  }

  // Generic pie chart builder
  Widget _buildPieChart(String title, Map<String, int> data, List<Color> colors, [bool isLoading = false]) {
    return Container(
      height: 300,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: isLoading
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 10),
                        Text(
                          'Loading chart data...',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  )
                : data.isEmpty
                    ? const Center(child: Text('No data available'))
                    : PieChart(
                    PieChartData(
                      sectionsSpace: 2,
                      centerSpaceRadius: 40,
                      sections: data.entries.map((entry) {
                        final index = data.keys.toList().indexOf(entry.key);
                        final color = colors[index % colors.length];
                        final total = data.values.fold<int>(0, (sum, value) => sum + value);
                        final percentage = ((entry.value / total) * 100).round();
                        return PieChartSectionData(
                          value: entry.value.toDouble(),
                          color: color,
                          title: '${entry.key}\n$percentage%',
                          radius: 60,
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
        ],
      ),
    );
  }

  // Table methods
  Widget _buildPetsTable() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Pet Statistics',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          Table(
            columnWidths: const {
              0: FlexColumnWidth(1),
              1: FlexColumnWidth(1),
            },
            children: [
              TableRow(
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                children: const [
                  Padding(
                    padding: EdgeInsets.all(12),
                    child: Text(
                      'Category',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.all(12),
                    child: Text(
                      'Count',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              ...(_petsData['categories'] as Map<String, int>? ?? {}).entries.map((entry) {
                return TableRow(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(entry.key),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(entry.value.toString()),
                    ),
                  ],
                );
              }).toList(),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildUsersTable() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'User Registration Statistics (Total: ${_usersData['total'] ?? 0})',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          Table(
            columnWidths: const {
              0: FlexColumnWidth(1),
              1: FlexColumnWidth(1),
            },
            children: [
              TableRow(
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                children: const [
                  Padding(
                    padding: EdgeInsets.all(12),
                    child: Text(
                      'Month',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.all(12),
                    child: Text(
                      'Registrations',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              ...(_usersData['registrationByMonth'] as Map<String, int>? ?? {}).entries.map((entry) {
                return TableRow(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(entry.key),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(entry.value.toString()),
                    ),
                  ],
                );
              }).toList(),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCategoriesTable() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Category Details (Total: ${_categoryData['total'] ?? 0})',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          Table(
            columnWidths: const {
              0: FlexColumnWidth(2),
              1: FlexColumnWidth(1),
              2: FlexColumnWidth(1),
            },
            children: [
              TableRow(
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                children: const [
                  Padding(
                    padding: EdgeInsets.all(12),
                    child: Text(
                      'Category',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.all(12),
                    child: Text(
                      'Count',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.all(12),
                    child: Text(
                      'Percentage',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              ...(_categoryData['distribution'] as Map<String, int>? ?? {}).entries.map((entry) {
                final total = _categoryData['total'] as int? ?? 1;
                final percentage = ((entry.value / total) * 100).toStringAsFixed(1);
                return TableRow(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(entry.key),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(entry.value.toString()),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text('$percentage%'),
                    ),
                  ],
                );
              }).toList(),
            ],
          ),
        ],
      ),
    );
  }
}
