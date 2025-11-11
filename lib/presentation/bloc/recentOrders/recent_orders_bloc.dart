import 'package:bloc/bloc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'recent_orders_event.dart';
import 'recent_orders_state.dart';

class RecentOrdersBloc extends Bloc<RecentOrdersEvent, RecentOrdersState> {
  RecentOrdersBloc() : super(RecentOrdersInitial()) {
    on<LoadRecentOrders>(_onLoadRecentOrders);
  }

  Future<void> _onLoadRecentOrders(
    LoadRecentOrders event,
    Emitter<RecentOrdersState> emit,
  ) async {
    emit(RecentOrdersLoading());
    try {
      final items = <RecentOrderItem>[];

      if (event.mobileOnly) {
        // Only 'orders' collection. Fetch a buffer, then filter to Completed and sort by completedAt desc
        final snap = await FirebaseFirestore.instance
            .collection('orders')
            .limit(event.limit * 5) // fetch a buffer, then sort locally
            .get();
        final mobile = _mapDocsToItems(snap.docs, source: 'Mobile')
            .where((o) => o.status == 'Completed' && o.timestamp != null)
            .toList();
        mobile.sort((a, b) {
          final at = a.timestamp!.millisecondsSinceEpoch;
          final bt = b.timestamp!.millisecondsSinceEpoch;
          return bt.compareTo(at);
        });
        items.addAll(mobile.take(event.limit));
      } else {
        // Combine both orders and ordersWeb, then sort and take top N
        final futures = await Future.wait([
          FirebaseFirestore.instance
              .collection('orders')
              .orderBy('timestamp', descending: true)
              .limit(event.limit * 2)
              .get(),
          FirebaseFirestore.instance
              .collection('ordersWeb')
              .orderBy('timestamp', descending: true)
              .limit(event.limit * 2)
              .get(),
        ]);
        items.addAll(_mapDocsToItems(futures[0].docs, source: 'Mobile'));
        items.addAll(_mapDocsToItems(futures[1].docs, source: 'Web'));
        // Sort merged by timestamp desc, take top limit
        items.sort((a, b) {
          final at = a.timestamp?.millisecondsSinceEpoch ?? 0;
          final bt = b.timestamp?.millisecondsSinceEpoch ?? 0;
          return bt.compareTo(at);
        });
        if (items.length > event.limit) {
          items.removeRange(event.limit, items.length);
        }
      }

      if (items.isEmpty) {
        emit(RecentOrdersEmpty());
      } else {
        emit(RecentOrdersSuccess(items));
      }
    } catch (e) {
      emit(RecentOrdersFailure(e.toString()));
    }
  }

  double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) {
      // strip all non-digits to be robust with values like "5.000.000 ₫"
      final cleaned = value.replaceAll(RegExp(r'[^0-9]'), '');
      if (cleaned.isEmpty) return 0.0;
      final n = double.tryParse(cleaned);
      return n ?? 0.0;
    }
    return 0.0;
  }

  List<RecentOrderItem> _mapDocsToItems(List<QueryDocumentSnapshot> docs, {required String source}) {
    final list = <RecentOrderItem>[];
    for (final doc in docs) {
      final data = doc.data() as Map<String, dynamic>;
      // Prefer business orderId (shown in Orders Admin), fallback to document id
      final id = (data['orderId'] ?? doc.id).toString();
      final status = (data['statusOrder'] ?? data['status'] ?? 'Pending').toString();
      final totalRaw = data['totalAmount'] ?? data['total'] ?? 0;
      final total = _parseDouble(totalRaw);

      String customerName = '';
      try {
        if (data['deliveryInfo'] is Map) {
          final di = data['deliveryInfo'] as Map;
          customerName = (di['name'] ?? '').toString();
        }
        if (customerName.isEmpty && data['customerInfo'] is Map) {
          final ci = data['customerInfo'] as Map;
          customerName = (ci['name'] ?? '').toString();
        }
        if (customerName.isEmpty) {
          customerName = (data['customerName'] ?? data['displayName'] ?? data['userName'] ?? 'Khách hàng').toString();
        }
      } catch (_) {
        customerName = (data['customerName'] ?? 'Khách hàng').toString();
      }

      // Determine sorting timestamp: prefer completedAt (for Completed), else created timestamp
      DateTime? ts;
      DateTime? completedAt;
      final rawCompleted = data['completedAt'];
      if (rawCompleted is Timestamp) {
        completedAt = rawCompleted.toDate();
      } else if (rawCompleted is int) {
        completedAt = DateTime.fromMillisecondsSinceEpoch(rawCompleted);
      } else if (rawCompleted is String) {
        completedAt = DateTime.tryParse(rawCompleted);
      }

      // Derive completion time from shippingInfo if missing
      if (completedAt == null && (data['shippingInfo'] is Map)) {
        try {
          final si = Map<String, dynamic>.from(data['shippingInfo']);
          // Try explicit fields first
          final actual = si['actualDeliveryTime'] ?? si['deliveredAt'];
          if (actual is String) {
            completedAt = DateTime.tryParse(actual);
          }
          // Fallback: scan trackingHistory for the latest 'delivered'
          if (completedAt == null && si['trackingHistory'] is List) {
            final hist = List.from(si['trackingHistory']);
            for (final item in hist.reversed) {
              if (item is Map && (item['status']?.toString() == 'delivered')) {
                final t = item['timestamp'];
                if (t is String) {
                  completedAt = DateTime.tryParse(t);
                }
                break;
              }
            }
          }
        } catch (_) {
          // ignore parsing errors
        }
      }

      final rawTs = data['timestamp'] ?? data['createdAt'];
      DateTime? createdAt;
      if (rawTs is Timestamp) {
        createdAt = rawTs.toDate();
      } else if (rawTs is int) {
        createdAt = DateTime.fromMillisecondsSinceEpoch(rawTs);
      } else if (rawTs is String) {
        createdAt = DateTime.tryParse(rawTs);
      }

      ts = (status == 'Completed' && completedAt != null) ? completedAt : createdAt;

      list.add(RecentOrderItem(
        id: id,
        customerName: customerName.isEmpty ? 'Khách hàng' : customerName,
        status: status,
        totalAmount: total,
        source: source,
        timestamp: ts,
      ));
    }
    return list;
  }
}
