import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:intl/intl.dart';
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

  @override
  void initState() {
    super.initState();
    fetchRevenueData(selectedMonth, year: selectedYear);
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
    }

    // Convert large numbers for chart rendering
    final convertedRevenue = <String, double>{};
    double maxValue = revenueData.values.isNotEmpty ? 
      revenueData.values.reduce((a, b) => a > b ? a : b) : 0.0;
    
    if (maxValue >= 1000000) {
      // Convert to millions
      revenueUnit = 'triệu ₫';
      for (final entry in revenueData.entries) {
        convertedRevenue[entry.key] = entry.value / 1000000;
      }
    } else if (maxValue >= 1000) {
      // Convert to thousands 
      revenueUnit = 'nghìn ₫';
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

                      return Card(
                        elevation: 0,
                        color: Theme.of(context).cardColor,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (dataSource == 'all') ...[
                                Row(
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
                                              .secondary,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      source == 'ordersWeb' ? 'Web' : 'Mobile',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: source == 'ordersWeb'
                                            ? Theme.of(context)
                                                .colorScheme
                                                .primary
                                            : Theme.of(context)
                                                .colorScheme
                                                .secondary,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                              ],
                              _rowIconText(Icons.email, email),
                              const SizedBox(height: 6),
                              _rowIconText(
                                  Icons.attach_money, l10n.totalAmount(total),
                                  iconColor:
                                      Theme.of(context).colorScheme.primary),
                              const SizedBox(height: 6),
                              _rowIconText(
                                  Icons.verified, l10n.statusOrder(status),
                                  iconColor:
                                      Theme.of(context).colorScheme.secondary),
                              const SizedBox(height: 6),
                              _rowIconText(
                                  Icons.calendar_today, l10n.dateOrder(dateStr),
                                  iconColor:
                                      Theme.of(context).colorScheme.tertiary),
                              const SizedBox(height: 10),
                              if (items.isNotEmpty) ...[
                                Text(l10n.items,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600)),
                                const SizedBox(height: 6),
                                ...items.map((it) {
                                  final name = (it['name'] ?? '').toString();
                                  final price = (it['price'] ?? '').toString();
                                  return Padding(
                                    padding: const EdgeInsets.only(
                                        left: 4, bottom: 4),
                                    child: Row(
                                      children: [
                                        Icon(Icons.pets,
                                            size: 16,
                                            color:
                                                Theme.of(context).brightness ==
                                                        Brightness.dark
                                                    ? const Color(0xFF6C7CE0)
                                                    : const Color(0xFF4158D0)),
                                        const SizedBox(width: 6),
                                        Expanded(
                                            child: Text(name,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                    color: Theme.of(context)
                                                        .textTheme
                                                        .bodyMedium
                                                        ?.color))),
                                        const SizedBox(width: 8),
                                        Text(price,
                                            style: TextStyle(
                                                color: Theme.of(context)
                                                    .textTheme
                                                    .bodySmall
                                                    ?.color)),
                                      ],
                                    ),
                                  );
                                }),
                              ] else if ((o['petName'] ?? '')
                                  .toString()
                                  .isNotEmpty) ...[
                                Text(l10n.pet,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600)),
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
                                        child: Text(o['petName'].toString())),
                                    const SizedBox(width: 8),
                                    Text(o['totalAmount'].toString(),
                                        style: TextStyle(
                                            color: Theme.of(context)
                                                .textTheme
                                                .bodyMedium
                                                ?.color
                                                ?.withOpacity(0.7))),
                                  ],
                                ),
                              ] else
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
    final defaultIconColor = Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF6C7CE0)
        : const Color(0xFF4158D0);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: iconColor ?? defaultIconColor, size: 18),
        const SizedBox(width: 6),
        Expanded(
            child: Text(text,
                style: TextStyle(
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
          content: SizedBox(
            width: 520,
            height: 560, // KHÔNG để unbounded
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
                        elevation: 0,
                        color: Theme.of(context).cardColor,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (dataSource == 'all') ...[
                                Row(
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
                                              .secondary,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      source == 'ordersWeb' ? 'Web' : 'Mobile',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: source == 'ordersWeb'
                                            ? Theme.of(context)
                                                .colorScheme
                                                .primary
                                            : Theme.of(context)
                                                .colorScheme
                                                .secondary,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                              ],
                              _rowIconText(Icons.email, email),
                              const SizedBox(height: 6),
                              _rowIconText(
                                  Icons.attach_money, AppLocalizations.of(context)!.total(CurrencyHelper.formatVND(total)),
                                  iconColor:
                                      Theme.of(context).colorScheme.primary),
                              const SizedBox(height: 6),
                              _rowIconText(
                                  Icons.calendar_today, AppLocalizations.of(context)!.date(dateStr),
                                  iconColor:
                                      Theme.of(context).colorScheme.secondary),
                              const SizedBox(height: 8),
                              if (items.isNotEmpty) ...[
                                Row(
                                  children: [
                                    Icon(Icons.pets,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .primary,
                                        size: 18),
                                    const SizedBox(width: 6),
                                    Text(l10n.pet,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w500)),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                ...items.map((it) {
                                  final name = (it['name'] ?? '').toString();
                                  final price = (it['price'] ?? '').toString();
                                  return Padding(
                                    padding: const EdgeInsets.only(
                                        left: 22, bottom: 4),
                                    child: Row(
                                      children: [
                                        Icon(Icons.pets,
                                            size: 16, 
                                            color: Theme.of(context).brightness == Brightness.dark
                                                ? const Color(0xFF6C7CE0)
                                                : const Color(0xFF4158D0)),
                                        const SizedBox(width: 6),
                                        Expanded(
                                            child: Text(name,
                                                maxLines: 1,
                                                overflow:
                                                    TextOverflow.ellipsis)),
                                        const SizedBox(width: 8),
                                        Text(price,
                                            style: TextStyle(
                                                color: Theme.of(context)
                                                    .textTheme
                                                    .bodyMedium
                                                    ?.color
                                                    ?.withOpacity(0.7))),
                                      ],
                                    ),
                                  );
                                }),
                              ] else if ((o['petName'] ?? '')
                                  .toString()
                                  .isNotEmpty) ...[
                                Text(l10n.pet,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold)),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Icon(Icons.pets,
                                        size: 16,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .primary),
                                    const SizedBox(width: 6),
                                    Expanded(
                                        child: Text(o['petName'].toString())),
                                    const SizedBox(width: 8),
                                    Text(o['totalAmount'].toString(),
                                        style: TextStyle(
                                            color: Theme.of(context)
                                                .textTheme
                                                .bodyMedium
                                                ?.color
                                                ?.withOpacity(0.7))),
                                  ],
                                ),
                              ] else
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

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
                    colors: Theme.of(context).brightness == Brightness.dark
                        ? [const Color(0xFF6C7CE0), const Color(0xFF5A67D8)]
                        : [const Color(0xFF4158D0), const Color(0xFF3B4AA8)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? const Color(0xFF6C7CE0).withOpacity(0.2)
                          : const Color(0xFF4158D0).withOpacity(0.2),
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
                          Text(
                            _getRevenueTitle(),
                            style: TextStyle(
                              color: Theme.of(context).brightness == Brightness.dark
                                  ? Colors.white.withOpacity(0.8)
                                  : Colors.white70,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            CurrencyHelper.formatVND(totalRevenue),
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
                  Text(l10n.dataSource,
                      style: TextStyle(
                          fontWeight: FontWeight.w500,
                          color: Theme.of(context).textTheme.bodyLarge?.color)),
                  const SizedBox(width: 8),
                  DropdownButton<String>(
                    value: dataSource,
                    dropdownColor: Theme.of(context).cardColor,
                    style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color),
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
                    style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color),
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
                      style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color),
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
                    style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color),
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
                      Icon(Icons.calendar_today,
                          color: Theme.of(context).brightness == Brightness.dark
                              ? const Color(0xFF6C7CE0)
                              : const Color(0xFF4158D0)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<int>(
                            value: selectedMonth,
                            isExpanded: true,
                            icon: Icon(Icons.keyboard_arrow_down,
                                color: Theme.of(context).brightness == Brightness.dark
                                    ? const Color(0xFF6C7CE0)
                                    : const Color(0xFF4158D0)),
                            style: TextStyle(
                              color: Theme.of(context).textTheme.bodyLarge?.color,
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
                                        color: Theme.of(context).textTheme.bodyLarge?.color),
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
              Text(
                _getChartTitle(),
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).textTheme.headlineSmall?.color,
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
                        ? ((rangeDays.length * 48.0 + 60) <
                                (MediaQuery.of(context).size.width - 48)
                            ? (MediaQuery.of(context).size.width - 48)
                            : (rangeDays.length * 48.0 + 60))
                        : MediaQuery.of(context).size.width - 48,
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Theme.of(context).shadowColor.withOpacity(0.1),
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
                            bottom: BorderSide(
                                color: Colors.grey.withOpacity(0.2), width: 1),
                            left: BorderSide(
                                color: Colors.grey.withOpacity(0.2), width: 1),
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
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.color,
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
                                if (selectedRange != null &&
                                    value.toInt() < rangeDays.length) {
                                  return Transform.rotate(
                                    angle: -0.5,
                                    child: Text(
                                      rangeDays[value.toInt()],
                                      style: TextStyle(
                                          fontSize: 11,
                                          color: Theme.of(context)
                                              .textTheme
                                              .bodySmall
                                              ?.color),
                                    ),
                                  );
                                } else if (selectedRange == null) {
                                  return Text(
                                    '${value.toInt()}',
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.color),
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
                                    gradient: LinearGradient(
                                      colors: Theme.of(context).brightness ==
                                              Brightness.dark
                                          ? [
                                              const Color(0xFF6C7CE0),
                                              const Color(0xFF4C63D2),
                                            ]
                                          : [
                                              const Color(0xFF4158D0),
                                              const Color(0xFF3B4AA8),
                                            ],
                                      begin: Alignment.bottomCenter,
                                      end: Alignment.topCenter,
                                    ),
                                    width: 20,
                                    borderRadius: BorderRadius.circular(10),
                                    backDrawRodData: BackgroundBarChartRodData(
                                      show: true,
                                      toY: (dailyRevenue[rangeDays[i]] ?? 0) *
                                          1.2,
                                      color: const Color(0xFFEDF2F7),
                                    ),
                                  ),
                                ],
                              )
                          else
                            for (final entry in (dailyRevenue.entries
                                .where((e) => int.tryParse(e.key) != null)
                                .toList()
                              ..sort((a, b) => int.parse(a.key)
                                  .compareTo(int.parse(b.key)))))
                              BarChartGroupData(
                                x: int.parse(entry.key),
                                barRods: [
                                  BarChartRodData(
                                    toY: entry.value,
                                    gradient: const LinearGradient(
                                      colors: [
                                        Color(0xFF4158D0),
                                        Color(0xFF3B4AA8)
                                      ],
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
                            tooltipPadding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            getTooltipItem: (group, groupIndex, rod, rodIndex) {
                              if (selectedRange != null &&
                                  group.x < rangeDays.length) {
                                return BarTooltipItem(
                                  '${rangeDays[group.x]}\n${_formatChartValue(rod.toY)} ${revenueUnit}',
                                  const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                );
                              } else {
                                return BarTooltipItem(
                                  'Day ${group.x}\n${_formatChartValue(rod.toY)} ${revenueUnit}',
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
                            if (response != null &&
                                response.spot != null &&
                                event is FlTapUpEvent) {
                              if (selectedRange != null &&
                                  response.spot!.touchedBarGroup.x <
                                      rangeDays.length) {
                                showOrdersForDayKey(rangeDays[
                                    response.spot!.touchedBarGroup.x]);
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

  // Format chart values based on current unit
  String _formatChartValue(double value) {
    if (revenueUnit == 'triệu ₫') {
      return value.toStringAsFixed(1);
    } else if (revenueUnit == 'nghìn ₫') {
      return value.toStringAsFixed(0);
    } else {
      return value.toStringAsFixed(0);
    }
  }
}
