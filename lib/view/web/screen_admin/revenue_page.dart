import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

class RevenuePage extends StatefulWidget {
  const RevenuePage({super.key});

  @override
  State<RevenuePage> createState() => _RevenuePageState();
}

class _RevenuePageState extends State<RevenuePage> {
  final CollectionReference ordersCollection =
      FirebaseFirestore.instance.collection('orders');

  Map<String, double> dailyRevenue = {}; // key: 'dd/MM'
  List<String> rangeDays = [];
  int selectedMonth = DateTime.now().month;
  double totalRevenue = 0.0; // Biến lưu tổng doanh thu
  String statisticType = 'month'; // 'month' hoặc 'day'
  DateTime? selectedDate;
  int selectedYear = DateTime.now().year;
  DateTimeRange? selectedRange;

  @override
  void initState() {
    super.initState();
    fetchRevenueData(selectedMonth, year: selectedYear);
  }

  Future<void> fetchRevenueData(int month, {int? year, DateTimeRange? range}) async {
    QuerySnapshot querySnapshot = await ordersCollection
        .where('statusOrder', isEqualTo: 'Completed')
        .get();

    Map<String, double> revenueData = {};
    double total = 0.0;
    List<String> days = [];

    if (range != null) {
      DateTime current = range.start;
      while (!current.isAfter(range.end)) {
        String key = DateFormat('dd/MM').format(current);
        revenueData[key] = 0.0;
        days.add(key);
        current = current.add(const Duration(days: 1));
      }
    }

    for (var doc in querySnapshot.docs) {
      DateTime date;
      var timestamp = doc['timestamp'];
      if (timestamp is Timestamp) {
        date = timestamp.toDate();
      } else if (timestamp is String) {
        date = DateTime.parse(timestamp);
      } else {
        continue;
      }
      double totalAmount = double.parse(doc['totalAmount'].toString());
      if (range != null) {
        if (!date.isBefore(range.start) && !date.isAfter(range.end)) {
          String key = DateFormat('dd/MM').format(date);
          revenueData[key] = (revenueData[key] ?? 0) + totalAmount;
          total += totalAmount;
        }
      } else if (year != null && date.year == year && date.month == month) {
        String key = date.day.toString();
        revenueData[key] = (revenueData[key] ?? 0) + totalAmount;
        total += totalAmount;
      }
    }
    setState(() {
      dailyRevenue = revenueData;
      totalRevenue = total;
      rangeDays = days;
    });
    // Reset dailyRevenue nếu chuyển chế độ
    if ((range == null && dailyRevenue.keys.isNotEmpty && dailyRevenue.keys.first.contains('/')) ||
        (range != null && dailyRevenue.keys.isNotEmpty && !dailyRevenue.keys.first.contains('/'))) {
      setState(() {
        dailyRevenue = {};
        rangeDays = [];
      });
    }
  }

  void showOrdersForDayKey(String key) async {
    DateTime? date;
    if (statisticType == 'day' && selectedRange != null) {
      date = DateFormat('dd/MM').parse(key);
      // Năm lấy từ selectedRange.start/end
      int year = selectedRange!.start.year;
      // Nếu tháng 12 và range qua năm mới thì lấy năm đúng
      if (selectedRange!.start.year != selectedRange!.end.year) {
        // Tìm năm đúng dựa vào tháng
        int month = int.parse(key.split('/')[1]);
        year = (month == selectedRange!.end.month) ? selectedRange!.end.year : selectedRange!.start.year;
      }
      date = DateTime(year, int.parse(key.split('/')[1]), int.parse(key.split('/')[0]));
    }
    QuerySnapshot querySnapshot = await ordersCollection
        .where('statusOrder', isEqualTo: 'Completed')
        .get();
    List<Map<String, dynamic>> orders = [];
    for (var doc in querySnapshot.docs) {
      DateTime docDate;
      var timestamp = doc['timestamp'];
      if (timestamp is Timestamp) {
        docDate = timestamp.toDate();
      } else if (timestamp is String) {
        docDate = DateTime.parse(timestamp);
      } else {
        continue;
      }
      if (date != null) {
        if (docDate.year == date.year && docDate.month == date.month && docDate.day == date.day) {
          orders.add(doc.data() as Map<String, dynamic>);
        }
      }
    }
    if (orders.isNotEmpty) {
      showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: Row(
              children: const [
                Icon(Icons.receipt_long, color: Color(0xFF4158D0)),
                SizedBox(width: 8),
                Text("Order Details", style: TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            content: SizedBox(
              width: 400,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Số lượng hóa đơn: ${orders.length}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 8),
                  Expanded(
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: orders.length,
                      separatorBuilder: (context, idx) => const Divider(),
                      itemBuilder: (context, idx) {
                        final order = orders[idx];
                        return Card(
                          color: const Color(0xFFF5F7FA),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 0,
                          child: Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.email, color: Color(0xFF4158D0), size: 18),
                                    const SizedBox(width: 6),
                                    Expanded(child: Text(order['email'], style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500))),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    const Icon(Icons.attach_money, color: Colors.green, size: 18),
                                    const SizedBox(width: 6),
                                    Text('Total: ', style: TextStyle(fontWeight: FontWeight.w500)),
                                    Text('\$${order['totalAmount']}', style: const TextStyle(fontSize: 15)),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    const Icon(Icons.verified, color: Colors.blue, size: 18),
                                    const SizedBox(width: 6),
                                    Text('Status: ', style: TextStyle(fontWeight: FontWeight.w500)),
                                    Text(order['statusOrder'], style: const TextStyle(fontSize: 15)),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                // Hiển thị danh sách items nếu có, nếu không thì hiển thị petName
                                if (order['items'] != null && order['items'] is List && (order['items'] as List).isNotEmpty) ...[
                                  const Text("Items:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                  ...((order['items'] as List<dynamic>).map((item) =>
                                    Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 2.0),
                                      child: Row(
                                        children: [
                                          const Icon(Icons.pets, size: 16, color: Color(0xFF4158D0)),
                                          const SizedBox(width: 4),
                                          Expanded(child: Text(item['name'] ?? '', style: const TextStyle(fontSize: 14))),
                                          const SizedBox(width: 8),
                                          if (item['price'] != null)
                                            Text(' ${item['price']}', style: const TextStyle(fontSize: 13, color: Colors.black54)),
                                        ],
                                      ),
                                    ))),
                                ] else if (order['petName'] != null && order['petName'].toString().isNotEmpty) ...[
                                  const Text("Pet:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 2.0),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.pets, size: 16, color: Color(0xFF4158D0)),
                                        const SizedBox(width: 4),
                                        Expanded(child: Text(order['petName'], style: const TextStyle(fontSize: 14))),
                                        const SizedBox(width: 8),
                                        if (order['totalAmount'] != null)
                                          Text(' ${order['totalAmount']}', style: const TextStyle(fontSize: 13, color: Colors.black54)),
                                      ],
                                    ),
                                  ),
                                ] else ...[
                                  const Text("Không có thông tin thú cưng", style: TextStyle(fontSize: 14, color: Colors.black54)),
                                ],
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Close', style: TextStyle(color: Color(0xFF4158D0))),
              ),
            ],
          );
        },
      );
    }
  }

  void showOrdersForDay(String day) async {
    // Lấy ngày/tháng/năm hiện tại từ selectedMonth, selectedYear
    int year = selectedYear;
    int month = selectedMonth;
    int d = int.tryParse(day) ?? 1;
    DateTime date = DateTime(year, month, d);
    QuerySnapshot querySnapshot = await ordersCollection
        .where('statusOrder', isEqualTo: 'Completed')
        .get();
    List<Map<String, dynamic>> orders = [];
    for (var doc in querySnapshot.docs) {
      DateTime docDate;
      var timestamp = doc['timestamp'];
      if (timestamp is Timestamp) {
        docDate = timestamp.toDate();
      } else if (timestamp is String) {
        docDate = DateTime.parse(timestamp);
      } else {
        continue;
      }
      if (docDate.year == date.year && docDate.month == date.month && docDate.day == date.day) {
        orders.add(doc.data() as Map<String, dynamic>);
      }
    }
    if (orders.isNotEmpty) {
      // ...existing dialog code...
      showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.receipt_long, color: Color(0xFF4158D0)),
                SizedBox(width: 8),
                Text("Order Details", style: TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            content: SizedBox(
              width: 400,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Số lượng hóa đơn: ${orders.length}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 8),
                  Expanded(
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: orders.length,
                      separatorBuilder: (context, idx) => const Divider(),
                      itemBuilder: (context, idx) {
                        final order = orders[idx];
                        return Card(
                          color: const Color(0xFFF5F7FA),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 0,
                          child: Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.email, color: Color(0xFF4158D0), size: 18),
                                    const SizedBox(width: 6),
                                    Expanded(child: Text(order['email'], style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500))),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    const Icon(Icons.attach_money, color: Colors.green, size: 18),
                                    const SizedBox(width: 6),
                                    const Text('Total: ', style: TextStyle(fontWeight: FontWeight.w500)),
                                    Text('\$${order['totalAmount']}', style: const TextStyle(fontSize: 15)),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    const Icon(Icons.calendar_today, color: Colors.blue, size: 18),
                                    const SizedBox(width: 6),
                                    const Text('Date: ', style: TextStyle(fontWeight: FontWeight.w500)),
                                    Text(order['timestamp'] is Timestamp
                                        ? DateFormat('dd/MM/yyyy').format((order['timestamp'] as Timestamp).toDate())
                                        : order['timestamp'].toString(),
                                      style: const TextStyle(fontSize: 15),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                // Hiển thị danh sách items nếu có, nếu không thì hiển thị petName
                                if (order['items'] != null && order['items'] is List && (order['items'] as List).isNotEmpty) ...[
                                  const Row(
                                    children: [
                                      Icon(Icons.pets, color: Colors.orange, size: 18),
                                      SizedBox(width: 6),
                                      Text('Pet: ', style: TextStyle(fontWeight: FontWeight.w500)),
                                    ],
                                  ),
                                  ...((order['items'] as List<dynamic>).map((item) =>
                                    Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 2.0,horizontal: 20),
                                      child: Row(
                                        children: [
                                          const Icon(Icons.pets, size: 16, color: Color(0xFF4158D0)),
                                          const SizedBox(width: 4),
                                          Expanded(child: Text(item['name'] ?? '', style: const TextStyle(fontSize: 14))),
                                          const SizedBox(width: 8),
                                          if (item['price'] != null)
                                            Text(' ${item['price']}', style: const TextStyle(fontSize: 13, color: Colors.black54)),
                                        ],
                                      ),
                                    ))),
                                ] else if (order['petName'] != null && order['petName'].toString().isNotEmpty) ...[
                                  const Text("Pet:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 2.0),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.pets, size: 16, color: Color(0xFF4158D0)),
                                        const SizedBox(width: 4),
                                        Expanded(child: Text(order['petName'], style: const TextStyle(fontSize: 14))),
                                        const SizedBox(width: 8),
                                        if (order['totalAmount'] != null)
                                          Text(' ${order['totalAmount']}', style: const TextStyle(fontSize: 13, color: Colors.black54)),
                                      ],
                                    ),
                                  ),
                                ] else ...[
                                  const Text("Không có thông tin thú cưng", style: TextStyle(fontSize: 14, color: Colors.black54)),
                                ],
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ],
          );
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Revenue Pet Shop',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 24,
            color: Colors.black87,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      backgroundColor: const Color(0xFFF5F7FA),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Revenue Card
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF4158D0), Color(0xFF3B4AA8)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF4158D0).withOpacity(0.2),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Total Revenue',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '\$${totalRevenue.toStringAsFixed(2)}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.attach_money,
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              // Bộ lọc thống kê
              Row(
                children: [
                  const Text('Năm:', style: TextStyle(fontWeight: FontWeight.w500)),
                  const SizedBox(width: 8),
                  DropdownButton<int>(
                    value: selectedYear,
                    items: [
                      for (int y = DateTime.now().year; y >= 2020; y--)
                        DropdownMenuItem(value: y, child: Text(y.toString())),
                    ],
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() { selectedYear = value; });
                      if (statisticType == 'month') {
                        selectedMonth = 1;
                        fetchRevenueData(selectedMonth, year: selectedYear);
                      } else {
                        selectedMonth = 1;
                        selectedRange = null;
                      }
                    },
                  ),
                  const SizedBox(width: 8),
                  if (statisticType == 'day')
                    DropdownButton<int>(
                      value: selectedMonth,
                      items: List.generate(
                        selectedYear == DateTime.now().year ? DateTime.now().month : 12,
                        (index) {
                          return DropdownMenuItem(
                            value: index + 1,
                            child: Text('Tháng ${index + 1}'),
                          );
                        }),
                      onChanged: (newMonth) {
                        if (selectedYear == DateTime.now().year && newMonth! > DateTime.now().month) return;
                        setState(() {
                          selectedMonth = newMonth!;
                          // Reset lại khoảng ngày về null khi đổi tháng
                          selectedRange = null;
                        });
                      },
                    ),
                  const SizedBox(width: 16),
                  const Text('Thống kê theo:', style: TextStyle(fontWeight: FontWeight.w500)),
                  const SizedBox(width: 12),
                  DropdownButton<String>(
                    value: statisticType,
                    items: const [
                      DropdownMenuItem(value: 'month', child: Text('Tháng')),
                      DropdownMenuItem(value: 'day', child: Text('Ngày')),
                    ],
                    onChanged: (value) async {
                      if (value == null) return;
                      setState(() {
                        statisticType = value;
                        // Reset dữ liệu ngay khi chuyển chế độ
                        dailyRevenue = {};
                        rangeDays = [];
                      });
                      if (value == 'month') {
                        selectedRange = null;
                        fetchRevenueData(selectedMonth, year: selectedYear);
                      } else {
                        selectedRange = null;
                      }
                    },
                  ),
                  if (statisticType == 'day') ...[
                    const SizedBox(width: 16),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.date_range, size: 18),
                      label: Text(selectedRange != null ?
                        '${selectedRange!.start.day}/${selectedRange!.start.month}/${selectedRange!.start.year} - ${selectedRange!.end.day}/${selectedRange!.end.month}/${selectedRange!.end.year}' : 'Chọn khoảng ngày'),
                      onPressed: () async {
                        final now = DateTime.now();
                        final isCurrentYear = selectedYear == now.year;
                        final firstDayOfYear = DateTime(selectedYear, 1, 1);
                        final lastDayOfYear = isCurrentYear ? now : DateTime(selectedYear, 12, 31);
                        // Target vào tháng hiện tại nếu là năm hiện tại, còn lại là tháng 1
                        final initialMonth = isCurrentYear ? now.month : 1;
                        final initialDay = isCurrentYear ? now.day : 1;
                        final initialStart = DateTime(selectedYear, initialMonth, 1);
                        final initialEnd = DateTime(selectedYear, initialMonth, initialDay);
                        DateTimeRange? picked = await showDateRangePicker(
                          context: context,
                          initialDateRange: selectedRange ?? DateTimeRange(start: initialStart, end: initialEnd),
                          firstDate: firstDayOfYear,
                          lastDate: lastDayOfYear,
                        );
                        if (picked != null) {
                          setState(() { selectedRange = picked; });
                          fetchRevenueData(selectedMonth, year: selectedYear, range: picked);
                        }
                      },
                    ),
                  ]
                ],
              ),
              const SizedBox(height: 10),
              // Month Selector
              if (statisticType == 'month')
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.1),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today, color: Color(0xFF4158D0)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<int>(
                          value: selectedMonth,
                          isExpanded: true,
                          icon: const Icon(Icons.keyboard_arrow_down, color: Color(0xFF4158D0)),
                          style: const TextStyle(
                            color: Colors.black87,
                            fontSize: 16,
                          ),
                          onChanged: (newMonth) {
                            if (selectedYear == DateTime.now().year && newMonth! > DateTime.now().month) return;
                            setState(() {
                              selectedMonth = newMonth!;
                              fetchRevenueData(selectedMonth, year: selectedYear);
                            });
                          },
                          items: List.generate(
                            selectedYear == DateTime.now().year ? DateTime.now().month : 12,
                            (index) {
                              return DropdownMenuItem(
                                value: index + 1,
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                                  child: Text(
                                    'Tháng ${index + 1}',
                                    style: const TextStyle(fontSize: 16),
                                  ),
                                ),
                              );
                            }),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              
              // Chart Title
              const Text(
                'Daily Revenue Overview',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2D3748),
                ),
              ),
              const SizedBox(height: 12),
              // Chart
              SizedBox(
                height: 550,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Container(
                    width: selectedRange != null
                      ? ((rangeDays.length * 48.0 + 60) < (MediaQuery.of(context).size.width - 48)
                          ? (MediaQuery.of(context).size.width - 48)
                          : (rangeDays.length * 48.0 + 60))
                      : MediaQuery.of(context).size.width - 48,
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.1),
                          blurRadius: 10,
                          spreadRadius: 0,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: BarChart(
                      BarChartData(
                        alignment: BarChartAlignment.spaceAround,
                        gridData: FlGridData(
                          show: true,
                          drawVerticalLine: false,
                          horizontalInterval: 50,
                          getDrawingHorizontalLine: (value) {
                            return FlLine(
                              color: Colors.grey.withOpacity(0.15),
                              strokeWidth: 1,
                            );
                          },
                        ),
                        borderData: FlBorderData(
                          show: true,
                          border: Border(
                            bottom: BorderSide(color: Colors.grey.withOpacity(0.2), width: 1),
                            left: BorderSide(color: Colors.grey.withOpacity(0.2), width: 1),
                          ),
                        ),
                        titlesData: FlTitlesData(
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              getTitlesWidget: (value, meta) {
                                return Padding(
                                  padding: const EdgeInsets.only(right: 8.0),
                                  child: Text(
                                    '${value.toInt()}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF64748B),
                                    ),
                                  ),
                                );
                              },
                              reservedSize: 56,
                            ),
                          ),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              getTitlesWidget: (value, meta) {
                                if (selectedRange != null && value.toInt() < rangeDays.length) {
                                  return Transform.rotate(
                                    angle: -0.5,
                                    child: Text(
                                      rangeDays[value.toInt()],
                                      style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                    ),
                                  );
                                } else if (selectedRange == null) {
                                  return Text(
                                    '${value.toInt()}',
                                    style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                                  );
                                }
                                return const SizedBox.shrink();
                              },
                              interval: 1,
                            ),
                          ),
                        ),
                        barGroups: [
                          if (selectedRange != null)
                            for (int i = 0; i < rangeDays.length; i++)
                              BarChartGroupData(
                                x: i,
                                barRods: [
                                  BarChartRodData(
                                    toY: dailyRevenue[rangeDays[i]] ?? 0,
                                    gradient: const LinearGradient(
                                      colors: [Color(0xFF4158D0), Color(0xFF3B4AA8)],
                                      begin: Alignment.bottomCenter,
                                      end: Alignment.topCenter,
                                    ),
                                    width: 20,
                                    borderRadius: BorderRadius.circular(10),
                                    backDrawRodData: BackgroundBarChartRodData(
                                      show: true,
                                      toY: (dailyRevenue[rangeDays[i]] ?? 0) * 1.2,
                                      color: const Color(0xFFEDF2F7),
                                    ),
                                  ),
                                ],
                              )
                          else
                            for (final entry in (dailyRevenue.entries
                                .where((e) => int.tryParse(e.key) != null)
                                .toList()..sort((a, b) => int.parse(a.key).compareTo(int.parse(b.key)))) )
                              BarChartGroupData(
                                x: int.parse(entry.key),
                                barRods: [
                                  BarChartRodData(
                                    toY: entry.value,
                                    gradient: const LinearGradient(
                                      colors: [Color(0xFF4158D0), Color(0xFF3B4AA8)],
                                      begin: Alignment.bottomCenter,
                                      end: Alignment.topCenter,
                                    ),
                                    width: 20,
                                    borderRadius: BorderRadius.circular(10),
                                    backDrawRodData: BackgroundBarChartRodData(
                                      show: true,
                                      toY: entry.value * 1.2,
                                      color: const Color(0xFFEDF2F7),
                                    ),
                                  ),
                                ],
                              ),
                        ],
                        barTouchData: BarTouchData(
                          touchTooltipData: BarTouchTooltipData(
                            tooltipBgColor: const Color(0xFF2D3748),
                            tooltipRoundedRadius: 8,
                            tooltipPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            getTooltipItem: (group, groupIndex, rod, rodIndex) {
                              if (selectedRange != null && group.x < rangeDays.length) {
                                return BarTooltipItem(
                                  '${rangeDays[group.x]}\n\$${rod.toY.toStringAsFixed(2)}',
                                  const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                );
                              } else {
                                return BarTooltipItem(
                                  'Day ${group.x}\n\$${rod.toY.toStringAsFixed(2)}',
                                  const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                );
                              }
                            },
                          ),
                          touchCallback: (event, response) {
                            if (response != null && response.spot != null && event is FlTapUpEvent) {
                              if (selectedRange != null && response.spot!.touchedBarGroup.x < rangeDays.length) {
                                showOrdersForDayKey(rangeDays[response.spot!.touchedBarGroup.x]);
                              } else {
                                int day = response.spot!.touchedBarGroup.x;
                                showOrdersForDay(day.toString());
                              }
                            }
                          },
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
