import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pet_shop/data/models/reservation_model.dart';
import 'package:pet_shop/data/models/deposit_settings_model.dart';

/// Service to handle reservation operations
class ReservationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Collection references
  CollectionReference get _reservationsCollection =>
      _firestore.collection('reservations');
  DocumentReference get _settingsDoc =>
      _firestore.collection('settings').doc('reservationSettings');

  /// Get deposit settings
  Future<DepositSettingsModel> getDepositSettings() async {
    try {
      final doc = await _settingsDoc.get();
      if (doc.exists) {
        return DepositSettingsModel.fromDocument(doc);
      }
      // Return default settings if not exists
      return DepositSettingsModel(
        id: 'reservationSettings',
        updatedAt: DateTime.now(),
      );
    } catch (e) {
      print('Error getting deposit settings: $e');
      return DepositSettingsModel(
        id: 'reservationSettings',
        updatedAt: DateTime.now(),
      );
    }
  }

  /// Update deposit settings (admin only)
  Future<void> updateDepositSettings(DepositSettingsModel settings) async {
    try {
      await _settingsDoc.set(settings.toMap(), SetOptions(merge: true));
    } catch (e) {
      print('Error updating deposit settings: $e');
      rethrow;
    }
  }

  /// Create a new reservation
  Future<String> createReservation(ReservationModel reservation) async {
    try {
      // Use transaction to ensure atomicity
      return await _firestore.runTransaction<String>((transaction) async {
        // Create reservation document
        final reservationRef = _reservationsCollection.doc();
        final reservationWithId = reservation.copyWith(id: reservationRef.id);
        
        transaction.set(reservationRef, reservationWithId.toMap());

        // Update pet status to 'reserved' for all items
        for (var item in reservation.items) {
          final petId = item['productId']?.toString() ?? item['id']?.toString();
          if (petId != null && petId.isNotEmpty) {
            final petRef = _firestore.collection('Pets').doc(petId);
            final petSnap = await transaction.get(petRef);
            
            if (!petSnap.exists) {
              throw Exception('Pet $petId không tồn tại!');
            }

            final petData = petSnap.data() as Map<String, dynamic>;
            final status = petData['status'] ?? 'available';
            final isAvailable = petData['isAvailable'] ?? false;

            // Check if pet is available
            if (status != 'available' || !isAvailable) {
              throw Exception('Thú cưng ${petData['name'] ?? petId} đã được đặt hoặc bán!');
            }

            // Reserve the pet
            transaction.update(petRef, {
              'status': 'reserved',
              'isAvailable': false,
              'reservedAt': FieldValue.serverTimestamp(),
              'reservationId': reservationRef.id,
            });
          }
        }

        return reservationRef.id;
      });
    } catch (e) {
      print('Error creating reservation: $e');
      rethrow;
    }
  }

  /// Get user's reservations
  Stream<List<ReservationModel>> getUserReservations(String userId) {
    return _reservationsCollection
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ReservationModel.fromDocument(doc))
            .toList());
  }

  /// Get all reservations (admin)
  Stream<List<ReservationModel>> getAllReservations() {
    return _reservationsCollection
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ReservationModel.fromDocument(doc))
            .toList());
  }

  /// Get reservation by ID
  Future<ReservationModel?> getReservationById(String id) async {
    try {
      final doc = await _reservationsCollection.doc(id).get();
      if (doc.exists) {
        return ReservationModel.fromDocument(doc);
      }
      return null;
    } catch (e) {
      print('Error getting reservation: $e');
      return null;
    }
  }

  /// Confirm reservation (admin)
  Future<void> confirmReservation(String reservationId, {String? adminNote}) async {
    try {
      await _firestore.runTransaction((transaction) async {
        final reservationRef = _reservationsCollection.doc(reservationId);
        final reservationSnap = await transaction.get(reservationRef);

        if (!reservationSnap.exists) {
          throw Exception('Reservation không tồn tại!');
        }

        final reservation = ReservationModel.fromDocument(reservationSnap);

        // Update reservation status
        transaction.update(reservationRef, {
          'status': ReservationStatus.confirmed.toShortString(),
          'confirmedAt': FieldValue.serverTimestamp(),
          if (adminNote != null) 'adminNote': adminNote,
        });

        // Update all pets to confirmed reserved (hide from selling list)
        for (var item in reservation.items) {
          final petId = item['productId']?.toString() ?? item['id']?.toString();
          if (petId != null && petId.isNotEmpty) {
            final petRef = _firestore.collection('Pets').doc(petId);
            transaction.update(petRef, {
              'status': 'reserved',
              'isAvailable': false,
              'confirmedAt': FieldValue.serverTimestamp(),
            });
          }
        }
      });
    } catch (e) {
      print('Error confirming reservation: $e');
      rethrow;
    }
  }

  /// Cancel reservation
  Future<void> cancelReservation(
    String reservationId, {
    String? cancelReason,
    bool isAdmin = false,
  }) async {
    try {
      await _firestore.runTransaction((transaction) async {
        final reservationRef = _reservationsCollection.doc(reservationId);
        final reservationSnap = await transaction.get(reservationRef);

        if (!reservationSnap.exists) {
          throw Exception('Reservation không tồn tại!');
        }

        final reservation = ReservationModel.fromDocument(reservationSnap);

        // Update reservation status
        transaction.update(reservationRef, {
          'status': ReservationStatus.cancelled.toShortString(),
          'cancelledAt': FieldValue.serverTimestamp(),
          if (cancelReason != null) 'cancelReason': cancelReason,
        });

        // Release all pets back to available
        for (var item in reservation.items) {
          final petId = item['productId']?.toString() ?? item['id']?.toString();
          if (petId != null && petId.isNotEmpty) {
            final petRef = _firestore.collection('Pets').doc(petId);
            transaction.update(petRef, {
              'status': 'available',
              'isAvailable': true,
              'reservedAt': FieldValue.delete(),
              'reservationId': FieldValue.delete(),
              'confirmedAt': FieldValue.delete(),
              'cancelledAt': FieldValue.serverTimestamp(),
            });
          }
        }
      });
    } catch (e) {
      print('Error cancelling reservation: $e');
      rethrow;
    }
  }

  /// Complete reservation (customer picked up)
  Future<void> completeReservation(
    String reservationId, {
    double? additionalPayment,
    String? adminNote,
  }) async {
    try {
      await _firestore.runTransaction((transaction) async {
        final reservationRef = _reservationsCollection.doc(reservationId);
        final reservationSnap = await transaction.get(reservationRef);

        if (!reservationSnap.exists) {
          throw Exception('Reservation không tồn tại!');
        }

        final reservation = ReservationModel.fromDocument(reservationSnap);

        // Calculate final paid amount
        double finalPaidAmount = reservation.paidAmount;
        if (additionalPayment != null && additionalPayment > 0) {
          finalPaidAmount += additionalPayment;
        }

        // Update reservation status
        transaction.update(reservationRef, {
          'status': ReservationStatus.completed.toShortString(),
          'paymentStatus': ReservationPaymentStatus.fullPaid.toShortString(),
          'paidAmount': finalPaidAmount,
          'remainingAmount': 0,
          'completedAt': FieldValue.serverTimestamp(),
          if (adminNote != null) 'adminNote': adminNote,
        });

        // Update all pets to sold
        for (var item in reservation.items) {
          final petId = item['productId']?.toString() ?? item['id']?.toString();
          if (petId != null && petId.isNotEmpty) {
            final petRef = _firestore.collection('Pets').doc(petId);
            transaction.update(petRef, {
              'status': 'sold',
              'isAvailable': false,
              'soldAt': FieldValue.serverTimestamp(),
            });
          }
        }
      });
    } catch (e) {
      print('Error completing reservation: $e');
      rethrow;
    }
  }

  /// Update reservation payment
  Future<void> updateReservationPayment(
    String reservationId,
    double paidAmount,
  ) async {
    try {
      final reservation = await getReservationById(reservationId);
      if (reservation == null) {
        throw Exception('Reservation không tồn tại!');
      }

      final newPaidAmount = reservation.paidAmount + paidAmount;
      final newRemainingAmount = reservation.totalAmount - newPaidAmount;
      
      final paymentStatus = newRemainingAmount <= 0
          ? ReservationPaymentStatus.fullPaid
          : ReservationPaymentStatus.depositPaid;

      await _reservationsCollection.doc(reservationId).update({
        'paidAmount': newPaidAmount,
        'remainingAmount': newRemainingAmount,
        'paymentStatus': paymentStatus.toShortString(),
      });
    } catch (e) {
      print('Error updating reservation payment: $e');
      rethrow;
    }
  }

  /// Check for expired reservations and update status
  Future<void> checkAndUpdateExpiredReservations() async {
    try {
      final now = DateTime.now();
      final snapshot = await _reservationsCollection
          .where('status', whereIn: ['pending', 'confirmed'])
          .get();

      for (var doc in snapshot.docs) {
        final reservation = ReservationModel.fromDocument(doc);
        
        // If pickup date has passed, mark as expired
        if (reservation.pickupDate.isBefore(now)) {
          await cancelReservation(
            reservation.id,
            cancelReason: 'Hết hạn - Quá ngày lấy hàng',
            isAdmin: true,
          );
        }
      }
    } catch (e) {
      print('Error checking expired reservations: $e');
    }
  }

  /// Get reservation statistics (admin)
  Future<Map<String, int>> getReservationStats() async {
    try {
      final snapshot = await _reservationsCollection.get();
      
      Map<String, int> stats = {
        'total': 0,
        'pending': 0,
        'confirmed': 0,
        'completed': 0,
        'cancelled': 0,
        'expired': 0,
      };

      for (var doc in snapshot.docs) {
        stats['total'] = (stats['total'] ?? 0) + 1;
        final data = doc.data() as Map<String, dynamic>;
        final status = data['status']?.toString() ?? 'pending';
        stats[status] = (stats[status] ?? 0) + 1;
      }

      return stats;
    } catch (e) {
      print('Error getting reservation stats: $e');
      return {
        'total': 0,
        'pending': 0,
        'confirmed': 0,
        'completed': 0,
        'cancelled': 0,
        'expired': 0,
      };
    }
  }
}
