import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'spending_event.dart';
import 'spending_state.dart';

class SpendingBloc extends Bloc<SpendingEvent, SpendingState> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  SpendingBloc() : super(SpendingInitial()) {
    on<LoadSpending>(_onLoadSpending);
  }

  Future<void> _onLoadSpending(
    LoadSpending event,
    Emitter<SpendingState> emit,
  ) async {
    emit(SpendingLoading());

    try {
      // Get completed orders by userId
      final ordersQuery = await _firestore
          .collection('orders')
          .where('userId', isEqualTo: event.userId)
          .where('statusOrder', isEqualTo: 'Completed')
          .orderBy('timestamp', descending: true)
          .get();

      // Get completed reservations by userId
      final reservationsQuery = await _firestore
          .collection('reservations')
          .where('userId', isEqualTo: event.userId)
          .where('status', isEqualTo: 'completed')
          .get();

      final Map<String, SpendingData> spendingMap = {};
      final now = DateTime.now();

      for (final orderDoc in ordersQuery.docs) {
        final orderData = orderDoc.data();
        final timestamp = (orderData['timestamp'] as Timestamp?)?.toDate();
        if (timestamp == null) continue;

        final totalAmount = _parseAmount(orderData['totalAmount']);
        if (totalAmount <= 0) continue;

        // Get pet items
        final items = (orderData['items'] as List?)  ?? [];
        final List<PetItem> petItems = [];

        for (final item in items) {
          final productId = item['productId']?.toString() ?? '';
          if (productId.isEmpty) continue;

          try {
            final petDoc = await _firestore.collection('Pets').doc(productId).get();
            if (petDoc.exists) {
              final petData = petDoc.data()!;
              petItems.add(PetItem(
                petId: productId,
                name: petData['name']?.toString() ?? 'Unknown',
                imageUrl: petData['imageUrl']?.toString(),
                quantity: item['quantity'] ?? 1,
                price: _parseAmount(item['price']),
              ));
            }
          } catch (e) {
            print('Error loading pet $productId: $e');
          }
        }

        // Group by period
        String periodKey;
        switch (event.period) {
          case 'week':
            // Group by day of week (last 7 days)
            final daysDiff = now.difference(timestamp).inDays;
            if (daysDiff > 6) continue; // Only last 7 days
            periodKey = _formatDate(timestamp);
            break;
          case 'month':
            // Group by week within current month only
            if (timestamp.year != now.year || timestamp.month != now.month) {
              continue; // Only current month
            }
            // Calculate week number in month (1-5)
            final weekInMonth = ((timestamp.day - 1) ~/ 7) + 1;
            periodKey = 'T$weekInMonth';
            break;
          case 'year':
            // Group by month of year (last 12 months)
            final monthsDiff = (now.year - timestamp.year) * 12 + (now.month - timestamp.month);
            if (monthsDiff > 11) continue; // Only last 12 months
            periodKey = 'T${timestamp.month}';
            break;
          default:
            periodKey = timestamp.toString();
        }

        final orderItem = OrderItem(
          orderId: orderDoc.id,
          amount: totalAmount,
          timestamp: timestamp,
          pets: petItems,
        );

        if (spendingMap.containsKey(periodKey)) {
          final existing = spendingMap[periodKey]!;
          spendingMap[periodKey] = SpendingData(
            totalAmount: existing.totalAmount + totalAmount,
            orders: [...existing.orders, orderItem],
          );
        } else {
          spendingMap[periodKey] = SpendingData(
            totalAmount: totalAmount,
            orders: [orderItem],
          );
        }
      }

      // Process reservations (store pickup orders)
      for (final reservationDoc in reservationsQuery.docs) {
        final reservationData = reservationDoc.data();
        final timestamp = (reservationData['completedAt'] as Timestamp?)?.toDate() ??
                         (reservationData['createdAt'] as Timestamp?)?.toDate();
        if (timestamp == null) continue;

        final totalAmount = _parseAmount(reservationData['totalAmount']);
        if (totalAmount <= 0) continue;

        // Get pet info from reservation items array
        final items = (reservationData['items'] as List?) ?? [];
        final List<PetItem> petItems = [];

        for (final item in items) {
          final itemMap = item as Map<String, dynamic>;
          petItems.add(PetItem(
            petId: itemMap['id']?.toString() ?? '',
            name: itemMap['name']?.toString() ?? 'Unknown',
            imageUrl: itemMap['imageUrl']?.toString(),
            quantity: 1, // Each item is 1 pet
            price: _parseAmount(itemMap['price']),
          ));
        }

        // Group by period
        String periodKey;
        switch (event.period) {
          case 'week':
            final daysDiff = now.difference(timestamp).inDays;
            if (daysDiff > 6) continue;
            periodKey = _formatDate(timestamp);
            break;
          case 'month':
            // Group by week within current month only
            if (timestamp.year != now.year || timestamp.month != now.month) {
              continue; // Only current month
            }
            final weekInMonth = ((timestamp.day - 1) ~/ 7) + 1;
            periodKey = 'T$weekInMonth';
            break;
          case 'year':
            final monthsDiff = (now.year - timestamp.year) * 12 + (now.month - timestamp.month);
            if (monthsDiff > 11) continue;
            periodKey = 'T${timestamp.month}';
            break;
          default:
            periodKey = timestamp.toString();
        }

        final orderItem = OrderItem(
          orderId: reservationDoc.id,
          amount: totalAmount,
          timestamp: timestamp,
          pets: petItems,
        );

        if (spendingMap.containsKey(periodKey)) {
          final existing = spendingMap[periodKey]!;
          spendingMap[periodKey] = SpendingData(
            totalAmount: existing.totalAmount + totalAmount,
            orders: [...existing.orders, orderItem],
          );
        } else {
          spendingMap[periodKey] = SpendingData(
            totalAmount: totalAmount,
            orders: [orderItem],
          );
        }
      }

      emit(SpendingLoaded(data: spendingMap, period: event.period));
    } catch (e) {
      print(e);
      emit(SpendingError('Lỗi tải dữ liệu: $e'));
    }
  }

  double _parseAmount(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value.toDouble();
    if (value is String) {
      // Remove 'đ' and spaces, parse
      final cleaned = value.replaceAll(RegExp(r'[đ,\s]'), '');
      return double.tryParse(cleaned) ?? 0;
    }
    return 0;
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}';
  }
}
