import 'package:bloc/bloc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'popular_event.dart';
import 'popular_state.dart';

class PopularBloc extends Bloc<PopularEvent, PopularState> {
  PopularBloc() : super(PopularInitial()) {
    on<LoadPopularBreeds>(_onLoadPopularBreeds);
  }

  Future<void> _onLoadPopularBreeds(
      LoadPopularBreeds event, Emitter<PopularState> emit) async {
    emit(PopularLoading());

    try {
      final ordersSnapshot = await FirebaseFirestore.instance
          .collection('orders')
          .where('statusOrder', isEqualTo: 'Completed')
          .get();

      // Collect all productIds from orders
      final Set<String> productIds = {};
      for (var orderDoc in ordersSnapshot.docs) {
        final orderData = orderDoc.data();
        final items = List<Map<String, dynamic>>.from(orderData['items']);
        for (final item in items) {
          final String productId = item['productId'];
          productIds.add(productId);
        }
      }

      if (productIds.isEmpty) {
        emit(const PopularLoaded([], []));
        return;
      }

      // Map productId -> breed in chunks to avoid whereIn > 10 limit
      final Map<String, String> idToBreed = {};
      final idsList = productIds.toList();
      const int chunkSize = 10;
      for (int i = 0; i < idsList.length; i += chunkSize) {
        final sub = idsList.sublist(i, i + chunkSize > idsList.length ? idsList.length : i + chunkSize);
        final snap = await FirebaseFirestore.instance
            .collection('Pets')
            .where(FieldPath.documentId, whereIn: sub)
            .get();
        for (final doc in snap.docs) {
          idToBreed[doc.id] = doc.data()['breed'];
        }
      }

      // Aggregate counts by breed
      final Map<String, int> breedSales = {};
      for (var orderDoc in ordersSnapshot.docs) {
        final orderData = orderDoc.data();
        final items = List<Map<String, dynamic>>.from(orderData['items']);
        for (final item in items) {
          final String productId = item['productId'];
          final int quantity = item['quantity'];
          final String? breed = idToBreed[productId];
          if (breed != null) {
            breedSales[breed] = (breedSales[breed] ?? 0) + quantity;
          }
        }
      }

      if (breedSales.isEmpty) {
        emit(const PopularLoaded([], []));
        return;
      }

      // Sort breeds and take top 5
      final sortedBreeds = breedSales.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      final topBreeds = sortedBreeds.take(5).map((e) => e.key).toList();

      // Fetch all pets in those top breeds (could be >5 pets)
      final petsSnapshot = await FirebaseFirestore.instance
          .collection('Pets')
          .where('breed', whereIn: topBreeds)
          .get();
      
      // Filter to only show available pets (not sold)
      final pets = petsSnapshot.docs
          .where((doc) {
            final data = doc.data();
            final isAvailable = data['isAvailable'] ?? true;
            final status = data['status']?.toString().toLowerCase() ?? '';
            return isAvailable && status != 'sold';
          })
          .map((d) {
            final data = d.data();
            data['id'] = d.id; // Ensure id field exists
            return data;
          })
          .toList();

      emit(PopularLoaded(pets, topBreeds));
    } catch (e) {
      emit(PopularError('Lỗi khi lấy top giống phổ biến: $e'));
    }
  }
}
