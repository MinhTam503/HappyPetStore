import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:intl/intl.dart';
import 'package:pet_shop/core/constants/app_constants.dart';
import '../../../../../core/utils/currency_helper.dart';

class RevenuePage extends StatefulWidget {
  const RevenuePage({super.key});

  @override
  State<RevenuePage> createState() => _RevenuePageState();
}

class _RevenuePageState extends State<RevenuePage> {
  final CollectionReference ordersCollection =
      FirebaseFirestore.instance.collection('orders');
  final CollectionReference ordersWebCollection =
      FirebaseFirestore.instance.collection('ordersWeb');

  // Add ScrollController for horizontal scrolling
  final ScrollController _scrollController = ScrollController();

  Map<String, double> dailyRevenue = {}; // key: 'dd/MM'
  List<String> rangeDays = [];
  int selectedMonth = DateTime.now().month;
  double totalRevenue = 0.0; // Biến lưu tổng doanh thu
  String revenueUnit = '₫'; // Track unit for chart display
  String statisticType = 'month'; // 'month' hoặc 'day'
  String dataSource = 'all'; // 'all', 'orders', 'ordersWeb'
  DateTime? selectedDate;
  int selectedYear = DateTime.now().year;
  DateTimeRange? selectedRange;

  // Helper to compute a reasonable y-axis interval based on max value.
  double _computeInterval(double maxY) {
    if (maxY <= 0) return 1;

    // Tính interval dựa trên maxY để có khoảng 5-10 khoảng chia
    double interval;
    if (maxY <= 10) {
      interval = 1;
    } else if (maxY <= 50) {
      interval = 5;
    } else if (maxY <= 100) {
      interval = 10;
    } else if (maxY <= 500) {
      interval = 50;
    } else if (maxY <= 1000) {
      interval = 100;
    } else if (maxY <= 5000) {
      interval = 500;
    } else if (maxY <= 10000) {
      interval = 1000;
    } else {
      // Tính toán động cho các giá trị lớn
      final magnitude = maxY / 10; // Chia thành 10 khoảng
      final powerOf10 =
          (magnitude / 100).ceil() * 100; // Làm tròn lên hàng trăm
      interval = powerOf10.toDouble();
    }

    return interval.clamp(1, double.infinity);
  }

  String _formatTooltip(double value) {
    // Format number with thousand separators respecting current unit scaling
    final formatted = NumberFormat.decimalPattern()
        .format(revenueUnit == '₫' ? value : value); // value already scaled
    return formatted;
  }

  // Calculate optimal chart width for scrolling
  double _calculateChartWidth() {
    final screenWidth = MediaQuery.of(context).size.width;
    final minWidth = screenWidth - 100; // Minimum width

    // For both date range and monthly: only count days with actual revenue data
    final daysWithData = dailyRevenue.entries.where((e) => e.value > 0).length;
    final calculatedWidth = daysWithData * 80.0 + 200;
    return calculatedWidth > minWidth ? calculatedWidth : minWidth;
  }

  List<BarChartGroupData> _buildBarGroups(
      {required bool hasRange,
      required List<String> days,
      required Map<String, double> data,
      required Color c1,
      required Color c2}) {
    final List<BarChartGroupData> groups = [];
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (hasRange) {
      // For date range: only show days with revenue > 0
      final daysWithRevenue =
          days.where((key) => (data[key] ?? 0) > 0).toList();
      for (int i = 0; i < daysWithRevenue.length; i++) {
        final key = daysWithRevenue[i];
        final value = data[key] ?? 0;
        groups.add(
          BarChartGroupData(
            x: i,
            barRods: [
              BarChartRodData(
                toY: value,
                gradient: LinearGradient(
                  colors: [
                    c1.withOpacity(0.8),
                    c1,
                    c2.withOpacity(0.9),
                  ],
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  stops: const [0.0, 0.5, 1.0],
                ),
                width: 24,
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: c1.withOpacity(0.3),
                  width: 1.5,
                ),
                backDrawRodData: BackgroundBarChartRodData(
                  show: true,
                  toY: value * 1.1,
                  gradient: LinearGradient(
                    colors: [
                      isDark
                          ? const Color(0xFF2A2D3A).withOpacity(0.3)
                          : const Color(0xFFF0F4F8).withOpacity(0.6),
                      isDark
                          ? const Color(0xFF1E1E2E).withOpacity(0.2)
                          : const Color(0xFFE2E8F0).withOpacity(0.4),
                    ],
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                  ),
                ),
              ),
            ],
          ),
        );
      }
    } else {
      // For monthly: only show days with revenue > 0
      final entries = data.entries
          .where((e) => int.tryParse(e.key) != null && e.value > 0)
          .toList()
        ..sort((a, b) => int.parse(a.key).compareTo(int.parse(b.key)));
      for (int i = 0; i < entries.length; i++) {
        final entry = entries[i];
        final value = entry.value;
        groups.add(
          BarChartGroupData(
            x: i, // Use index instead of day number for consecutive display
            barRods: [
              BarChartRodData(
                toY: value,
                gradient: LinearGradient(
                  colors: [
                    c1.withOpacity(0.8),
                    c1,
                    c2.withOpacity(0.9),
                  ],
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  stops: const [0.0, 0.5, 1.0],
                ),
                width: 24,
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: c1.withOpacity(0.3),
                  width: 1.5,
                ),
                backDrawRodData: BackgroundBarChartRodData(
                  show: true,
                  toY: value * 1.1,
                  gradient: LinearGradient(
                    colors: [
                      isDark
                          ? const Color(0xFF2A2D3A).withOpacity(0.3)
                          : const Color(0xFFF0F4F8).withOpacity(0.6),
                      isDark
                          ? const Color(0xFF1E1E2E).withOpacity(0.2)
                          : const Color(0xFFE2E8F0).withOpacity(0.4),
                    ],
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                  ),
                ),
              ),
            ],
          ),
        );
      }
    }
    return groups;
  }

  @override
  void initState() {
    super.initState();
    fetchRevenueData(selectedMonth, year: selectedYear);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> fetchRevenueData(int month,
      {int? year, DateTimeRange? range}) async {
    // Lấy dữ liệu từ collection dựa trên dataSource được chọn
    List<QuerySnapshot> snapshots = [];

    if (dataSource == 'all' || dataSource == 'orders') {
      QuerySnapshot ordersSnapshot = await ordersCollection
          .where('statusOrder', isEqualTo: 'Completed')
          .get();
      snapshots.add(ordersSnapshot);
    }

    if (dataSource == 'all' || dataSource == 'ordersWeb') {
      QuerySnapshot ordersWebSnapshot = await ordersWebCollection
          .where('statusOrder', isEqualTo: 'Completed')
          .get();
      snapshots.add(ordersWebSnapshot);
    }

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

    // Xử lý dữ liệu từ tất cả các snapshots
    for (var snapshot in snapshots) {
      for (var doc in snapshot.docs) {
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
          // Fix: Use proper date comparison with time normalization
          final normalizedDate = DateTime(date.year, date.month, date.day);
          final normalizedStart =
              DateTime(range.start.year, range.start.month, range.start.day);
          final normalizedEnd =
              DateTime(range.end.year, range.end.month, range.end.day);

          if (!normalizedDate.isBefore(normalizedStart) &&
              !normalizedDate.isAfter(normalizedEnd)) {
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
    }

    // Convert large numbers for chart rendering
    final convertedRevenue = <String, double>{};
    double maxValue = revenueData.values.isNotEmpty
        ? revenueData.values.reduce((a, b) => a > b ? a : b)
        : 0.0;

    if (maxValue >= 1000000) {
      // Convert to millions
      revenueUnit = 'triệu ₫'; // millions
      for (final entry in revenueData.entries) {
        convertedRevenue[entry.key] = entry.value / 1000000;
      }
    } else if (maxValue >= 1000) {
      // Convert to thousands
      revenueUnit = 'nghìn ₫'; // thousands
      for (final entry in revenueData.entries) {
        convertedRevenue[entry.key] = entry.value / 1000;
      }
    } else {
      // Use original values
      revenueUnit = '₫';
      convertedRevenue.addAll(revenueData);
    }

    setState(() {
      dailyRevenue = convertedRevenue; // Use converted data for chart
      totalRevenue = total;
      rangeDays = days;
    });
    // Reset dailyRevenue nếu chuyển chế độ
    if ((range == null &&
            dailyRevenue.keys.isNotEmpty &&
            dailyRevenue.keys.first.contains('/')) ||
        (range != null &&
            dailyRevenue.keys.isNotEmpty &&
            !dailyRevenue.keys.first.contains('/'))) {
      setState(() {
        dailyRevenue = {};
        rangeDays = [];
      });
    }
  }

  Future<void> showOrdersForDayKey(String key) async {
    DateTime? date;
    if (statisticType == 'day' && selectedRange != null) {
      // key dạng dd/MM
      final parts = key.split('/');
      final d = int.tryParse(parts[0]) ?? 1;
      final m = int.tryParse(parts[1]) ?? 1;
      // chọn đúng năm trong khoảng
      var year = selectedRange!.start.year;
      if (selectedRange!.start.year != selectedRange!.end.year) {
        year = (m == selectedRange!.end.month)
            ? selectedRange!.end.year
            : selectedRange!.start.year;
      }
      date = DateTime(year, m, d);
    }

    // Lấy dữ liệu từ collection dựa trên dataSource được chọn
    final List<Map<String, dynamic>> orders = [];

    if (dataSource == 'all' || dataSource == 'orders') {
      final snap = await ordersCollection
          .where('statusOrder', isEqualTo: 'Completed')
          .get();

      // Xử lý orders từ collection orders
      for (final doc in snap.docs) {
        final data = (doc.data() as Map).cast<String, dynamic>();
        final ts = data['timestamp'];
        DateTime docDate;
        if (ts is Timestamp) {
          docDate = ts.toDate();
        } else if (ts is String) {
          docDate = DateTime.tryParse(ts) ?? DateTime(1970);
        } else {
          continue;
        }
        if (date != null &&
            docDate.year == date.year &&
            docDate.month == date.month &&
            docDate.day == date.day) {
          data['source'] = 'orders'; // Đánh dấu nguồn
          orders.add(data);
        }
      }
    }

    if (dataSource == 'all' || dataSource == 'ordersWeb') {
      final snapWeb = await ordersWebCollection
          .where('statusOrder', isEqualTo: 'Completed')
          .get();

      // Xử lý orders từ collection ordersWeb
      for (final doc in snapWeb.docs) {
        final data = (doc.data() as Map).cast<String, dynamic>();
        final ts = data['timestamp'];
        DateTime docDate;
        if (ts is Timestamp) {
          docDate = ts.toDate();
        } else if (ts is String) {
          docDate = DateTime.tryParse(ts) ?? DateTime(1970);
        } else {
          continue;
        }
        if (date != null &&
            docDate.year == date.year &&
            docDate.month == date.month &&
            docDate.day == date.day) {
          data['source'] = 'ordersWeb'; // Đánh dấu nguồn
          orders.add(data);
        }
      }
    }

    // Hiển thị dialog (kích thước hữu hạn, 1 scroll duy nhất)
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      useRootNavigator: true,
      builder: (ctx) {
        final l10n = AppLocalizations.of(ctx)!;
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          backgroundColor: Theme.of(context).dialogBackgroundColor,
          surfaceTintColor: Colors.transparent,
          title: Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color:
                        Theme.of(context).colorScheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.receipt_long,
                      color: Theme.of(context).colorScheme.primary, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l10n.orderDetails,
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 20,
                              color: Theme.of(context)
                                  .textTheme
                                  .titleLarge
                                  ?.color)),
                      const SizedBox(height: 2),
                      Text(
                        '${DateFormat('dd/MM/yyyy').format(DateTime.now())}',
                        style: TextStyle(
                          fontSize: 13,
                          color: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.color
                              ?.withOpacity(0.7),
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          content: SizedBox(
            width: 520, // cố định bề ngang
            height: 560, // và CHIỀU CAO HỮU HẠN
            child: orders.isEmpty
                ? Center(child: Text(l10n.noOrders))
                : ListView.separated(
                    padding: EdgeInsets.zero,
                    itemCount: orders.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, idx) {
                      final o = orders[idx];
                      final email = (o['email'] ?? '').toString();
                      final total = (o['totalAmount'] ?? '').toString();
                      final status = (o['statusOrder'] ?? '').toString();
                      final source =
                          (o['source'] ?? 'orders').toString(); // Nguồn order
                      final ts = o['timestamp'];
                      final dateStr = (ts is Timestamp)
                          ? DateFormat('dd/MM/yyyy').format(ts.toDate())
                          : (ts?.toString() ?? '');

                      final List<Map<String, dynamic>> items = (o['items']
                              is List)
                          ? (o['items'] as List)
                              .where((e) => e is Map)
                              .map<Map<String, dynamic>>(
                                  (e) => Map<String, dynamic>.from(e as Map))
                              .toList()
                          : const [];

                      final formattedTotal = CurrencyHelper.formatVND(total);
                      Color statusColor;
                      switch (status.toLowerCase()) {
                        case 'completed':
                          statusColor = Colors.green.shade600;
                          break;
                        case 'processing':
                          statusColor = Colors.orange.shade600;
                          break;
                        case 'pending':
                          statusColor = Colors.amber.shade700;
                          break;
                        case 'cancelled':
                          statusColor = Colors.red.shade600;
                          break;
                        default:
                          statusColor = Theme.of(context).colorScheme.primary;
                      }
                      return Card(
                        elevation: 1,
                        color: Theme.of(context).cardColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  if (dataSource == 'all') ...[
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: (source == 'ordersWeb'
                                                ? Colors.green.shade50
                                                : Colors.green.shade50)
                                            .withOpacity(.6),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .primary
                                              .withOpacity(.35),
                                          width: 0.6,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            source == 'ordersWeb'
                                                ? Icons.web
                                                : Icons.phone_android,
                                            size: 14,
                                            color: Theme.of(context)
                                                .colorScheme
                                                .primary,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            source == 'ordersWeb'
                                                ? 'Web'
                                                : 'Mobile',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .primary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                  ],
                                  Expanded(
                                    child: Text(
                                      email,
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                        color: Theme.of(context)
                                            .textTheme
                                            .bodyMedium
                                            ?.color,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: statusColor.withOpacity(.12),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                          color: statusColor.withOpacity(.4),
                                          width: .6),
                                    ),
                                    child: Text(
                                      status,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        letterSpacing: .2,
                                        color: statusColor,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Icon(Icons.calendar_today,
                                      size: 14,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .primary),
                                  const SizedBox(width: 6),
                                  Text(
                                    dateStr,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.color,
                                    ),
                                  ),
                                  const Spacer(),
                                  Icon(Icons.attach_money,
                                      size: 16,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .primary),
                                  const SizedBox(width: 4),
                                  Text(
                                    formattedTotal,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color:
                                          Theme.of(context).colorScheme.primary,
                                    ),
                                  )
                                ],
                              ),
                              const SizedBox(height: 10),
                              if (items.isNotEmpty) ...[
                                Text(l10n.items,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13)),
                                const SizedBox(height: 6),
                                ...items.map((it) {
                                  final name = (it['name'] ?? '').toString();
                                  final priceRaw =
                                      (it['price'] ?? '').toString();
                                  final price =
                                      CurrencyHelper.formatVND(priceRaw);
                                  return Padding(
                                    padding: const EdgeInsets.only(
                                        left: 2, bottom: 4),
                                    child: Row(
                                      children: [
                                        Icon(Icons.pets,
                                            size: 16,
                                            color: Theme.of(context)
                                                .colorScheme
                                                .primary),
                                        const SizedBox(width: 6),
                                        Expanded(
                                          child: Text(
                                            name,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontSize: 12.5,
                                              color: Theme.of(context)
                                                  .textTheme
                                                  .bodyMedium
                                                  ?.color,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          price,
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500,
                                            color: Theme.of(context)
                                                .textTheme
                                                .bodySmall
                                                ?.color,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }),
                              ] else if ((o['petName'] ?? '')
                                  .toString()
                                  .isNotEmpty) ...[
                                Text(l10n.pet,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13)),
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    Icon(Icons.pets,
                                        size: 16,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .primary),
                                    const SizedBox(width: 6),
                                    Expanded(
                                        child: Text(o['petName'].toString(),
                                            style: TextStyle(
                                              fontSize: 12.5,
                                              color: Theme.of(context)
                                                  .textTheme
                                                  .bodyMedium
                                                  ?.color,
                                            ))),
                                    const SizedBox(width: 8),
                                    Text(
                                      CurrencyHelper.formatVND(
                                          o['totalAmount']?.toString() ?? ''),
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                        color: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.color,
                                      ),
                                    ),
                                  ],
                                ),
                              ] else
                                Text(
                                  l10n.noPetInfo,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.color
                                        ?.withOpacity(0.7),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(l10n.close,
                    style: TextStyle(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? const Color(0xFF6C7CE0)
                            : const Color(0xFF4158D0)))),
          ],
        );
      },
    );
  }

  Widget _rowIconText(IconData icon, String text, {Color? iconColor}) {
    final defaultIconColor =
        Theme.of(context).colorScheme.primary.withOpacity(0.7);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: iconColor ?? defaultIconColor, size: 18),
        const SizedBox(width: 8),
        Expanded(
            child: Text(text,
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Theme.of(context).textTheme.bodyMedium?.color))),
      ],
    );
  }

  String _getDataSourceTitle() {
    final l10n = AppLocalizations.of(context)!;
    switch (dataSource) {
      case 'orders':
        return '(${l10n.mobileApp})';
      case 'ordersWeb':
        return '(${l10n.web})';
      case 'all':
      default:
        return '(${l10n.mobileApp} & ${l10n.web})';
    }
  }

  String _getRevenueTitle() {
    final l10n = AppLocalizations.of(context)!;
    switch (dataSource) {
      case 'orders':
        return l10n.totalRevenueMobile;
      case 'ordersWeb':
        return l10n.totalRevenueWeb;
      case 'all':
      default:
        return l10n.totalRevenueAll;
    }
  }

  String _getChartTitle() {
    final l10n = AppLocalizations.of(context)!;
    switch (dataSource) {
      case 'orders':
        return l10n.dailyRevenueOverviewMobile;
      case 'ordersWeb':
        return l10n.dailyRevenueOverviewWeb;
      case 'all':
      default:
        return l10n.dailyRevenueOverviewAll;
    }
  }

  Future<void> showOrdersForDay(String day) async {
    final date = DateTime(selectedYear, selectedMonth, int.tryParse(day) ?? 1);

    // Lấy dữ liệu từ collection dựa trên dataSource được chọn
    final List<Map<String, dynamic>> orders = [];

    if (dataSource == 'all' || dataSource == 'orders') {
      final snap = await ordersCollection
          .where('statusOrder', isEqualTo: 'Completed')
          .get();

      // Xử lý orders từ collection orders
      for (final doc in snap.docs) {
        final data = (doc.data() as Map).cast<String, dynamic>();
        final ts = data['timestamp'];
        DateTime d;
        if (ts is Timestamp) {
          d = ts.toDate();
        } else if (ts is String) {
          d = DateTime.tryParse(ts) ?? DateTime(1970);
        } else {
          continue;
        }
        if (d.year == date.year && d.month == date.month && d.day == date.day) {
          data['source'] = 'orders'; // Đánh dấu nguồn
          orders.add(data);
        }
      }
    }

    if (dataSource == 'all' || dataSource == 'ordersWeb') {
      final snapWeb = await ordersWebCollection
          .where('statusOrder', isEqualTo: 'Completed')
          .get();

      // Xử lý orders từ collection ordersWeb
      for (final doc in snapWeb.docs) {
        final data = (doc.data() as Map).cast<String, dynamic>();
        final ts = data['timestamp'];
        DateTime d;
        if (ts is Timestamp) {
          d = ts.toDate();
        } else if (ts is String) {
          d = DateTime.tryParse(ts) ?? DateTime(1970);
        } else {
          continue;
        }
        if (d.year == date.year && d.month == date.month && d.day == date.day) {
          data['source'] = 'ordersWeb'; // Đánh dấu nguồn
          orders.add(data);
        }
      }
    }

    if (!mounted) return;
    await showDialog<void>(
      context: context,
      useRootNavigator: true,
      builder: (ctx) {
        final l10n = AppLocalizations.of(ctx)!;
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          title: Row(
            children: [
              Icon(Icons.receipt_long,
                  color: Theme.of(context).brightness == Brightness.dark
                      ? const Color(0xFF6C7CE0)
                      : const Color(0xFF4158D0)),
              const SizedBox(width: 8),
              Text(l10n.orderDetails,
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).textTheme.titleLarge?.color)),
            ],
          ),
          content: Container(
            width: 540,
            height: 580,
            decoration: BoxDecoration(
              color: Theme.of(context).brightness == Brightness.dark
                  ? Theme.of(context).cardColor.withOpacity(0.3)
                  : Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Theme.of(context).dividerColor.withOpacity(0.1),
              ),
            ),
            child: orders.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.inbox_outlined,
                          size: 48,
                          color: Theme.of(context)
                              .colorScheme
                              .primary
                              .withOpacity(0.5),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          l10n.noOrders,
                          style: TextStyle(
                            fontSize: 16,
                            color: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.color
                                ?.withOpacity(0.7),
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: orders.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (_, idx) {
                      final o = orders[idx];
                      final email = (o['email'] ?? '').toString();
                      final total = (o['totalAmount'] ?? '').toString();
                      final source =
                          (o['source'] ?? 'orders').toString(); // Nguồn order
                      final ts = o['timestamp'];
                      final dateStr = (ts is Timestamp)
                          ? DateFormat('dd/MM/yyyy').format(ts.toDate())
                          : (ts?.toString() ?? '');

                      final List<Map<String, dynamic>> items = (o['items']
                              is List)
                          ? (o['items'] as List)
                              .where((e) => e is Map)
                              .map<Map<String, dynamic>>(
                                  (e) => Map<String, dynamic>.from(e as Map))
                              .toList()
                          : const [];

                      return Card(
                          elevation: 2,
                          color: Theme.of(context).cardColor,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: BorderSide(
                              color: Theme.of(context).dividerColor,
                              width: 1,
                            ),
                          ),
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              gradient: LinearGradient(
                                colors: [
                                  Theme.of(context).cardColor,
                                  Theme.of(context).cardColor.withOpacity(0.8),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (dataSource == 'all') ...[
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: source == 'ordersWeb'
                                            ? Theme.of(context)
                                                .colorScheme
                                                .primary
                                                .withOpacity(0.1)
                                            : Theme.of(context)
                                                .colorScheme
                                                .secondary
                                                .withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(
                                          color: source == 'ordersWeb'
                                              ? Theme.of(context)
                                                  .colorScheme
                                                  .primary
                                                  .withOpacity(0.3)
                                              : Theme.of(context)
                                                  .colorScheme
                                                  .secondary
                                                  .withOpacity(0.3),
                                          width: 1,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            source == 'ordersWeb'
                                                ? Icons.web
                                                : Icons.phone_android,
                                            size: 16,
                                            color: source == 'ordersWeb'
                                                ? Theme.of(context)
                                                    .colorScheme
                                                    .primary
                                                : Theme.of(context)
                                                    .colorScheme
                                                    .primary,
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            source == 'ordersWeb'
                                                ? 'Web'
                                                : 'Mobile',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: source == 'ordersWeb'
                                                  ? Theme.of(context)
                                                      .colorScheme
                                                      .primary
                                                  : Theme.of(context)
                                                      .colorScheme
                                                      .primary,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                  ],
                                  _rowIconText(Icons.email, email),
                                  const SizedBox(height: 10),
                                  _rowIconText(Icons.attach_money,
                                      '${l10n.totalLabel}: ${CurrencyHelper.formatVND(total)}',
                                      iconColor: Theme.of(context)
                                          .colorScheme
                                          .primary),
                                  const SizedBox(height: 10),
                                  _rowIconText(Icons.calendar_today,
                                      '${l10n.dateLabel}: $dateStr',
                                      iconColor: Theme.of(context)
                                          .colorScheme
                                          .primary),
                                  const SizedBox(height: 12),
                                  if (items.isNotEmpty) ...[
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 12, vertical: 8),
                                      decoration: BoxDecoration(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .primary
                                            .withOpacity(0.05),
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .primary
                                              .withOpacity(0.1),
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(Icons.pets,
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .primary,
                                              size: 18),
                                          const SizedBox(width: 8),
                                          Text(l10n.pet,
                                              style: TextStyle(
                                                  fontWeight: FontWeight.w600,
                                                  color: Theme.of(context)
                                                      .colorScheme
                                                      .primary)),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    ...items.map((it) {
                                      final name =
                                          (it['name'] ?? '').toString();
                                      final price =
                                          (it['price'] ?? '').toString();
                                      return Container(
                                        margin:
                                            const EdgeInsets.only(bottom: 6),
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 12, vertical: 8),
                                        decoration: BoxDecoration(
                                          color: Theme.of(context).brightness ==
                                                  Brightness.dark
                                              ? Theme.of(context)
                                                  .cardColor
                                                  .withOpacity(0.3)
                                              : Theme.of(context)
                                                  .colorScheme
                                                  .surface,
                                          borderRadius:
                                              BorderRadius.circular(8),
                                          border: Border.all(
                                            color: Theme.of(context)
                                                .dividerColor
                                                .withOpacity(0.2),
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            Icon(Icons.pets,
                                                size: 16,
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .primary),
                                            const SizedBox(width: 8),
                                            Expanded(
                                                child: Text(name,
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.w500,
                                                      color: Theme.of(context)
                                                          .textTheme
                                                          .bodyMedium
                                                          ?.color,
                                                    ))),
                                            const SizedBox(width: 8),
                                            Text(
                                                CurrencyHelper.formatVND(price),
                                                style: TextStyle(
                                                    fontWeight: FontWeight.w600,
                                                    color: Theme.of(context)
                                                        .colorScheme
                                                        .primary)),
                                          ],
                                        ),
                                      );
                                    }),
                                  ] else if ((o['petName'] ?? '')
                                      .toString()
                                      .isNotEmpty) ...[
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 12, vertical: 8),
                                      decoration: BoxDecoration(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .primary
                                            .withOpacity(0.05),
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .primary
                                              .withOpacity(0.1),
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(Icons.pets,
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .primary,
                                              size: 18),
                                          const SizedBox(width: 8),
                                          Text(l10n.pet,
                                              style: TextStyle(
                                                  fontWeight: FontWeight.w600,
                                                  color: Theme.of(context)
                                                      .colorScheme
                                                      .primary)),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 12, vertical: 8),
                                      decoration: BoxDecoration(
                                        color: Theme.of(context).brightness ==
                                                Brightness.dark
                                            ? Theme.of(context)
                                                .cardColor
                                                .withOpacity(0.3)
                                            : Theme.of(context)
                                                .colorScheme
                                                .surface,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: Theme.of(context)
                                              .dividerColor
                                              .withOpacity(0.2),
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(Icons.pets,
                                              size: 16,
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .primary),
                                          const SizedBox(width: 8),
                                          Expanded(
                                              child: Text(
                                                  o['petName'].toString(),
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.w500,
                                                    color: Theme.of(context)
                                                        .textTheme
                                                        .bodyMedium
                                                        ?.color,
                                                  ))),
                                          const SizedBox(width: 8),
                                          Text(
                                              CurrencyHelper.formatVND(
                                                  o['totalAmount']
                                                          ?.toString() ??
                                                      ''),
                                              style: TextStyle(
                                                  fontWeight: FontWeight.w600,
                                                  color: Theme.of(context)
                                                      .colorScheme
                                                      .primary)),
                                        ],
                                      ),
                                    ),
                                  ] else
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 12, vertical: 8),
                                      decoration: BoxDecoration(
                                        color: Theme.of(context).brightness ==
                                                Brightness.dark
                                            ? Theme.of(context)
                                                .cardColor
                                                .withOpacity(0.3)
                                            : Theme.of(context)
                                                .colorScheme
                                                .surface
                                                .withOpacity(0.5),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(Icons.info_outline,
                                              size: 16,
                                              color: Theme.of(context)
                                                  .textTheme
                                                  .bodySmall
                                                  ?.color
                                                  ?.withOpacity(0.7)),
                                          const SizedBox(width: 8),
                                          Text(l10n.noPetInfo,
                                              style: TextStyle(
                                                  color: Theme.of(context)
                                                      .textTheme
                                                      .bodyMedium
                                                      ?.color
                                                      ?.withOpacity(0.7))),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ));
                    },
                  ),
          ),
          actions: [
            Container(
              margin: const EdgeInsets.only(bottom: 8, right: 8),
              child: TextButton.icon(
                onPressed: () => Navigator.pop(ctx),
                icon: Icon(Icons.close,
                    size: 18, color: Theme.of(context).colorScheme.primary),
                label: Text(l10n.close,
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w600)),
                style: TextButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  backgroundColor:
                      Theme.of(context).colorScheme.primary.withOpacity(0.1),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: BorderSide(
                      color: Theme.of(context)
                          .colorScheme
                          .primary
                          .withOpacity(0.2),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryA = Theme.of(context).colorScheme.primary; // app green
    final primaryB = isDark
        ? Theme.of(context).colorScheme.primary.withOpacity(.7)
        : const Color(0xff0a8d3c); // darker green shade

    // Determine maxY for chart (scaled values already in dailyRevenue)
    final values = dailyRevenue.values.toList();
    final double rawMaxY =
        values.isEmpty ? 0.0 : values.reduce((a, b) => a > b ? a : b);
    final double maxY = rawMaxY == 0 ? 10.0 : (rawMaxY * 1.25);
    final double interval = _computeInterval(maxY);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          '${l10n.revenue} ${_getDataSourceTitle()}',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 24,
            color: Theme.of(context).appBarTheme.foregroundColor,
          ),
        ),
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        elevation: 0,
      ),
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
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
                  gradient: LinearGradient(
                    colors: [primaryA, primaryB],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: primaryA.withOpacity(0.30),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                _getRevenueTitle(),
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.85),
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(30),
                                  border: Border.all(
                                      color: Colors.white.withOpacity(.25),
                                      width: .8),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.stacked_bar_chart,
                                        size: 14, color: Colors.white),
                                    const SizedBox(width: 4),
                                    Text(
                                      revenueUnit,
                                      style: const TextStyle(
                                          color: Colors.white, fontSize: 12),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                CurrencyHelper.formatVND(totalRevenue),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 34,
                                  letterSpacing: 0.5,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(width: 8),
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 250),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  revenueUnit,
                                  style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500),
                                ),
                              )
                            ],
                          ),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              DateFormat('MMMM yyyy').format(
                                  DateTime(selectedYear, selectedMonth)),
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                          )
                        ],
                      ),
                    ),
                    Container(
                      height: 74,
                      width: 74,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [
                            Colors.white.withOpacity(.28),
                            Colors.white.withOpacity(.12)
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        border: Border.all(color: Colors.white30, width: 1),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(.18),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          )
                        ],
                      ),
                      alignment: Alignment.center,
                      child: const Icon(
                        Icons.attach_money,
                        color: Colors.white,
                        size: 34,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              // Bộ lọc thống kê
              Row(
                children: [
                  Text(l10n.dataSource,
                      style: TextStyle(
                          fontWeight: FontWeight.w500,
                          color: Theme.of(context).textTheme.bodyLarge?.color)),
                  const SizedBox(width: 8),
                  DropdownButton<String>(
                    value: dataSource,
                    dropdownColor: Theme.of(context).cardColor,
                    style: TextStyle(
                        color: Theme.of(context).textTheme.bodyLarge?.color),
                    items: [
                      DropdownMenuItem(value: 'all', child: Text(l10n.all)),
                      DropdownMenuItem(
                          value: 'orders', child: Text(l10n.mobileApp)),
                      DropdownMenuItem(
                          value: 'ordersWeb', child: Text(l10n.web)),
                    ],
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() {
                        dataSource = value;
                        // Reset dữ liệu khi thay đổi nguồn
                        dailyRevenue = {};
                        rangeDays = [];
                      });
                      // Fetch lại dữ liệu với nguồn mới
                      if (statisticType == 'month') {
                        fetchRevenueData(selectedMonth, year: selectedYear);
                      } else if (selectedRange != null) {
                        fetchRevenueData(selectedMonth,
                            year: selectedYear, range: selectedRange);
                      }
                    },
                  ),
                  const SizedBox(width: 16),
                  Text(l10n.year,
                      style: TextStyle(
                          fontWeight: FontWeight.w500,
                          color: Theme.of(context).textTheme.bodyLarge?.color)),
                  const SizedBox(width: 8),
                  DropdownButton<int>(
                    value: selectedYear,
                    dropdownColor: Theme.of(context).cardColor,
                    style: TextStyle(
                        color: Theme.of(context).textTheme.bodyLarge?.color),
                    items: [
                      for (int y = DateTime.now().year; y >= 2020; y--)
                        DropdownMenuItem(value: y, child: Text(y.toString())),
                    ],
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() {
                        selectedYear = value;
                      });
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
                      dropdownColor: Theme.of(context).cardColor,
                      style: TextStyle(
                          color: Theme.of(context).textTheme.bodyLarge?.color),
                      items: List.generate(
                          selectedYear == DateTime.now().year
                              ? DateTime.now().month
                              : 12, (index) {
                        return DropdownMenuItem(
                          value: index + 1,
                          child: Text(l10n.monthName(index + 1)),
                        );
                      }),
                      onChanged: (newMonth) {
                        if (selectedYear == DateTime.now().year &&
                            newMonth! > DateTime.now().month) return;
                        setState(() {
                          selectedMonth = newMonth!;
                          // Reset lại khoảng ngày về null khi đổi tháng
                          selectedRange = null;
                        });
                      },
                    ),
                  const SizedBox(width: 16),
                  Text(l10n.statisticsBy,
                      style: TextStyle(
                          fontWeight: FontWeight.w500,
                          color: Theme.of(context).textTheme.bodyLarge?.color)),
                  const SizedBox(width: 12),
                  DropdownButton<String>(
                    value: statisticType,
                    dropdownColor: Theme.of(context).cardColor,
                    style: TextStyle(
                        color: Theme.of(context).textTheme.bodyLarge?.color),
                    items: [
                      DropdownMenuItem(value: 'month', child: Text(l10n.month)),
                      DropdownMenuItem(value: 'day', child: Text(l10n.day)),
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
                      label: Text(selectedRange != null
                          ? '${selectedRange!.start.day}/${selectedRange!.start.month}/${selectedRange!.start.year} - ${selectedRange!.end.day}/${selectedRange!.end.month}/${selectedRange!.end.year}'
                          : l10n.selectDateRange),
                      onPressed: () async {
                        final now = DateTime.now();
                        final isCurrentYear = selectedYear == now.year;
                        final firstDayOfYear = DateTime(selectedYear, 1, 1);
                        final lastDayOfYear = isCurrentYear
                            ? now
                            : DateTime(selectedYear, 12, 31);
                        // Target vào tháng hiện tại nếu là năm hiện tại, còn lại là tháng 1
                        final initialMonth = isCurrentYear ? now.month : 1;
                        final initialDay = isCurrentYear ? now.day : 1;
                        final initialStart =
                            DateTime(selectedYear, initialMonth, 1);
                        final initialEnd =
                            DateTime(selectedYear, initialMonth, initialDay);
                        DateTimeRange? picked = await showDateRangePicker(
                          context: context,
                          initialDateRange: selectedRange ??
                              DateTimeRange(
                                  start: initialStart, end: initialEnd),
                          firstDate: firstDayOfYear,
                          lastDate: lastDayOfYear,
                        );
                        if (picked != null) {
                          setState(() {
                            selectedRange = picked;
                          });
                          fetchRevenueData(selectedMonth,
                              year: selectedYear, range: picked);
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
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Theme.of(context).shadowColor.withOpacity(0.1),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.calendar_today,
                        color: primaryColor,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<int>(
                            value: selectedMonth,
                            isExpanded: true,
                            icon: const Icon(
                              Icons.keyboard_arrow_down,
                              color: primaryColor,
                            ),
                            style: TextStyle(
                              color:
                                  Theme.of(context).textTheme.bodyLarge?.color,
                              fontSize: 16,
                            ),
                            onChanged: (newMonth) {
                              if (selectedYear == DateTime.now().year &&
                                  newMonth! > DateTime.now().month) return;
                              setState(() {
                                selectedMonth = newMonth!;
                                fetchRevenueData(selectedMonth,
                                    year: selectedYear);
                              });
                            },
                            items: List.generate(
                                selectedYear == DateTime.now().year
                                    ? DateTime.now().month
                                    : 12, (index) {
                              return DropdownMenuItem(
                                value: index + 1,
                                child: Padding(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 8.0),
                                  child: Text(
                                    l10n.monthName(index + 1),
                                    style: TextStyle(
                                        fontSize: 16,
                                        color: Theme.of(context)
                                            .textTheme
                                            .bodyLarge
                                            ?.color),
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
              Row(
                children: [
                  Text(
                    _getChartTitle(),
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).textTheme.headlineSmall?.color,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: primaryA.withOpacity(isDark ? 0.18 : 0.12),
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(
                          color: primaryA.withOpacity(0.35), width: 0.8),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.stacked_bar_chart,
                            size: 14, color: primaryA.withOpacity(.9)),
                        const SizedBox(width: 4),
                        Text(
                          revenueUnit,
                          style: TextStyle(
                            fontSize: 11,
                            color: Theme.of(context).textTheme.bodySmall?.color,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Chart Container - Redesigned for better scrolling
              Container(
                height: 650,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Theme.of(context).cardColor,
                      Theme.of(context).cardColor.withOpacity(0.98),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: primaryA.withOpacity(0.12),
                      blurRadius: 24,
                      spreadRadius: 0,
                      offset: const Offset(0, 12),
                    ),
                    BoxShadow(
                      color: Theme.of(context).shadowColor.withOpacity(0.08),
                      blurRadius: 40,
                      spreadRadius: 0,
                      offset: const Offset(0, 20),
                    ),
                  ],
                  border: Border.all(
                    color: primaryA.withOpacity(0.15),
                    width: 1.5,
                  ),
                ),
                child: Column(
                  children: [
                    // Chart Header
                    Container(
                      padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            primaryA.withOpacity(0.08),
                            primaryA.withOpacity(0.04),
                          ],
                        ),
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(24),
                          topRight: Radius.circular(24),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [primaryA, primaryB],
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.bar_chart_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            _getChartTitle(),
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context)
                                  .textTheme
                                  .headlineSmall
                                  ?.color,
                            ),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: primaryA.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: primaryA.withOpacity(0.3),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.stacked_bar_chart,
                                  size: 14,
                                  color: primaryA,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  revenueUnit,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: primaryA,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Scrollable Chart Area
                    Expanded(
                      child: Scrollbar(
                        controller: _scrollController,
                        thumbVisibility: true,
                        trackVisibility: true,
                        child: SingleChildScrollView(
                          controller: _scrollController,
                          scrollDirection: Axis.horizontal,
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Container(
                            width: _calculateChartWidth(),
                            padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                            child: BarChart(
                              BarChartData(
                                maxY: maxY,
                                minY: 0,
                                alignment: BarChartAlignment.spaceAround,
                                gridData: FlGridData(
                                  show: true,
                                  drawVerticalLine: false,
                                  horizontalInterval: interval,
                                  getDrawingHorizontalLine: (value) {
                                    return FlLine(
                                      color: isDark
                                          ? Colors.white.withOpacity(0.05)
                                          : Colors.grey.withOpacity(0.1),
                                      strokeWidth: 1,
                                      dashArray: [8, 4],
                                    );
                                  },
                                ),
                                borderData: FlBorderData(
                                  show: true,
                                  border: Border(
                                    bottom: BorderSide(
                                      color: primaryA.withOpacity(0.2),
                                      width: 2,
                                    ),
                                    left: BorderSide(
                                      color: primaryA.withOpacity(0.2),
                                      width: 2,
                                    ),
                                  ),
                                ),
                                titlesData: FlTitlesData(
                                  leftTitles: AxisTitles(
                                    axisNameWidget: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [
                                            primaryA.withOpacity(0.1),
                                            primaryA.withOpacity(0.05)
                                          ],
                                        ),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        revenueUnit,
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          color: primaryA,
                                        ),
                                      ),
                                    ),
                                    axisNameSize: 28,
                                    sideTitles: SideTitles(
                                      showTitles: true,
                                      getTitlesWidget: (value, meta) {
                                        return Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 4, vertical: 2),
                                          margin:
                                              const EdgeInsets.only(right: 6),
                                          decoration: BoxDecoration(
                                            color: isDark
                                                ? Theme.of(context)
                                                    .cardColor
                                                    .withOpacity(0.4)
                                                : Colors.white.withOpacity(0.8),
                                            borderRadius:
                                                BorderRadius.circular(4),
                                            border: Border.all(
                                              color: primaryA.withOpacity(0.1),
                                              width: 0.5,
                                            ),
                                          ),
                                          child: Text(
                                            '${value.toInt()}',
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w600,
                                              color: Theme.of(context)
                                                  .textTheme
                                                  .bodySmall
                                                  ?.color,
                                            ),
                                          ),
                                        );
                                      },
                                      reservedSize: 50,
                                    ),
                                  ),
                                  bottomTitles: AxisTitles(
                                    sideTitles: SideTitles(
                                      showTitles: true,
                                      reservedSize: 60,
                                      getTitlesWidget: (value, meta) {
                                        if (selectedRange != null &&
                                            value.toInt() < rangeDays.length) {
                                          // Range view: map index back to actual day
                                          final daysWithRevenue = rangeDays
                                              .where((key) =>
                                                  (dailyRevenue[key] ?? 0) > 0)
                                              .toList();

                                          if (value.toInt() >=
                                              daysWithRevenue.length) {
                                            return const SizedBox.shrink();
                                          }

                                          final dayKey =
                                              daysWithRevenue[value.toInt()];
                                          final hasData =
                                              (dailyRevenue[dayKey] ?? 0) > 0;

                                          return Padding(
                                            padding:
                                                const EdgeInsets.only(top: 8),
                                            child: Transform.rotate(
                                              angle: -0.1,
                                              child: Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 6,
                                                        vertical: 3),
                                                decoration: BoxDecoration(
                                                  gradient: hasData
                                                      ? LinearGradient(
                                                          colors: [
                                                            primaryA
                                                                .withOpacity(
                                                                    0.15),
                                                            primaryA
                                                                .withOpacity(
                                                                    0.08)
                                                          ],
                                                        )
                                                      : null,
                                                  color: !hasData
                                                      ? Colors.grey
                                                          .withOpacity(0.1)
                                                      : null,
                                                  borderRadius:
                                                      BorderRadius.circular(6),
                                                  border: hasData
                                                      ? Border.all(
                                                          color: primaryA
                                                              .withOpacity(0.3),
                                                          width: 1)
                                                      : null,
                                                ),
                                                child: Text(
                                                  dayKey,
                                                  style: TextStyle(
                                                    fontSize: 8,
                                                    fontWeight: hasData
                                                        ? FontWeight.w700
                                                        : FontWeight.w500,
                                                    color: hasData
                                                        ? primaryA
                                                        : Theme.of(context)
                                                            .textTheme
                                                            .bodySmall
                                                            ?.color
                                                            ?.withOpacity(0.5),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          );
                                        } else if (selectedRange == null) {
                                          // Monthly view: map index back to actual day
                                          final entries = dailyRevenue.entries
                                              .where((e) =>
                                                  int.tryParse(e.key) != null &&
                                                  e.value > 0)
                                              .toList()
                                            ..sort((a, b) => int.parse(a.key)
                                                .compareTo(int.parse(b.key)));

                                          if (value.toInt() >= entries.length) {
                                            return const SizedBox.shrink();
                                          }

                                          final actualDay = int.parse(
                                              entries[value.toInt()].key);
                                          final hasData =
                                              entries[value.toInt()].value > 0;

                                          return Padding(
                                            padding:
                                                const EdgeInsets.only(top: 8),
                                            child: Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 6,
                                                      vertical: 3),
                                              decoration: BoxDecoration(
                                                gradient: hasData
                                                    ? LinearGradient(
                                                        colors: [
                                                          primaryA.withOpacity(
                                                              0.15),
                                                          primaryA
                                                              .withOpacity(0.08)
                                                        ],
                                                      )
                                                    : null,
                                                color: !hasData
                                                    ? Colors.grey
                                                        .withOpacity(0.1)
                                                    : null,
                                                borderRadius:
                                                    BorderRadius.circular(6),
                                                border: hasData
                                                    ? Border.all(
                                                        color: primaryA
                                                            .withOpacity(0.3),
                                                        width: 1)
                                                    : null,
                                              ),
                                              child: Text(
                                                '$actualDay',
                                                style: TextStyle(
                                                  fontSize: 9,
                                                  fontWeight: hasData
                                                      ? FontWeight.w700
                                                      : FontWeight.w500,
                                                  color: hasData
                                                      ? primaryA
                                                      : Theme.of(context)
                                                          .textTheme
                                                          .bodySmall
                                                          ?.color
                                                          ?.withOpacity(0.5),
                                                ),
                                              ),
                                            ),
                                          );
                                        }
                                        return const SizedBox.shrink();
                                      },
                                      interval: 1,
                                    ),
                                    axisNameWidget: Container(
                                      margin: const EdgeInsets.only(top: 12),
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 6),
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [
                                            primaryA.withOpacity(0.1),
                                            primaryA.withOpacity(0.05)
                                          ],
                                        ),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        statisticType == 'day'
                                            ? l10n.dateLabel
                                            : l10n.day,
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          color: primaryA,
                                        ),
                                      ),
                                    ),
                                    axisNameSize: 40,
                                  ),
                                  topTitles: const AxisTitles(
                                      sideTitles:
                                          SideTitles(showTitles: false)),
                                  rightTitles: const AxisTitles(
                                      sideTitles:
                                          SideTitles(showTitles: false)),
                                ),
                                barGroups: _buildBarGroups(
                                  hasRange: selectedRange != null,
                                  days: rangeDays,
                                  data: dailyRevenue,
                                  c1: primaryA,
                                  c2: primaryB,
                                ),
                                barTouchData: BarTouchData(
                                  enabled: true,
                                  touchTooltipData: BarTouchTooltipData(
                                    tooltipBgColor: isDark
                                        ? const Color(0xFF1A2332)
                                            .withOpacity(0.95)
                                        : const Color(0xFF2D3748)
                                            .withOpacity(0.95),
                                    tooltipRoundedRadius: 16,
                                    tooltipPadding: const EdgeInsets.symmetric(
                                        horizontal: 20, vertical: 16),
                                    tooltipMargin: 12,
                                    getTooltipItem:
                                        (group, groupIndex, rod, rodIndex) {
                                      // Build lists of displayed keys matching the groups building logic
                                      List<String> displayedRangeKeys = [];
                                      List<int> displayedMonthDays = [];
                                      if (selectedRange != null) {
                                        // Keep chronological order based on rangeDays but only those with revenue > 0
                                        for (final k in rangeDays) {
                                          if ((dailyRevenue[k] ?? 0) > 0)
                                            displayedRangeKeys.add(k);
                                        }
                                      } else {
                                        final entries = dailyRevenue.entries
                                            .where((e) =>
                                                int.tryParse(e.key) != null &&
                                                e.value > 0)
                                            .toList()
                                          ..sort((a, b) => int.parse(a.key)
                                              .compareTo(int.parse(b.key)));
                                        displayedMonthDays = entries
                                            .map((e) => int.parse(e.key))
                                            .toList();
                                      }

                                      String dayKey;
                                      if (selectedRange != null) {
                                        dayKey =
                                            group.x < displayedRangeKeys.length
                                                ? displayedRangeKeys[group.x]
                                                : '';
                                      } else {
                                        dayKey = group.x <
                                                displayedMonthDays.length
                                            ? '${displayedMonthDays[group.x]}'
                                            : '';
                                      }
                                      if (dayKey.isEmpty) return null; // safety
                                      return BarTooltipItem(
                                        '',
                                        const TextStyle(),
                                        children: [
                                          TextSpan(
                                            text: '📊 $dayKey\n',
                                            style: TextStyle(
                                              color: Colors.white
                                                  .withOpacity(0.95),
                                              fontSize: 14,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                          TextSpan(
                                            text:
                                                '💰 ${_formatTooltip(rod.toY)} $revenueUnit\n',
                                            style: TextStyle(
                                              color: const Color(0xFF4ADE80),
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          const TextSpan(
                                            text: '👆 Nhấn để xem chi tiết',
                                            style: TextStyle(
                                              color: Colors.white60,
                                              fontSize: 11,
                                              fontStyle: FontStyle.italic,
                                            ),
                                          ),
                                        ],
                                      );
                                    },
                                  ),
                                  touchCallback: (event, response) {
                                    if (response == null ||
                                        response.spot == null) return;
                                    if (event is! FlTapUpEvent) return;
                                    final barIndex =
                                        response.spot!.touchedBarGroup.x;
                                    if (selectedRange != null) {
                                      // Build displayed range keys identical to tooltip logic
                                      final displayedRangeKeys = [
                                        for (final k in rangeDays)
                                          if ((dailyRevenue[k] ?? 0) > 0) k
                                      ];
                                      if (barIndex >= 0 &&
                                          barIndex <
                                              displayedRangeKeys.length) {
                                        showOrdersForDayKey(
                                            displayedRangeKeys[barIndex]);
                                      }
                                    } else {
                                      final entries = dailyRevenue.entries
                                          .where((e) =>
                                              int.tryParse(e.key) != null &&
                                              e.value > 0)
                                          .toList()
                                        ..sort((a, b) => int.parse(a.key)
                                            .compareTo(int.parse(b.key)));
                                      final displayedMonthDays = entries
                                          .map((e) => int.parse(e.key))
                                          .toList();
                                      if (barIndex >= 0 &&
                                          barIndex <
                                              displayedMonthDays.length) {
                                        final realDay =
                                            displayedMonthDays[barIndex];
                                        showOrdersForDay(realDay.toString());
                                      }
                                    }
                                  },
                                ),
                                groupsSpace: 20,
                                backgroundColor: Colors.transparent,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
