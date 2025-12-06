import 'package:cloud_firestore/cloud_firestore.dart';

/// Enum for reservation status
enum ReservationStatus {
  pending, // Chờ xác nhận
  confirmed, // Đã xác nhận (pet được ẩn)
  completed, // Đã hoàn thành (khách đã lấy)
  cancelled, // Đã hủy
  expired, // Hết hạn (quá ngày lấy)
}

/// Enum for payment status of reservation
enum ReservationPaymentStatus {
  depositPaid, // Đã cọc
  fullPaid, // Đã thanh toán đủ
  pending, // Chờ thanh toán
}

/// Extension to convert enum to string and vice versa
extension ReservationStatusExtension on ReservationStatus {
  String toShortString() {
    return toString().split('.').last;
  }

  static ReservationStatus fromString(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return ReservationStatus.pending;
      case 'confirmed':
        return ReservationStatus.confirmed;
      case 'completed':
        return ReservationStatus.completed;
      case 'cancelled':
        return ReservationStatus.cancelled;
      case 'expired':
        return ReservationStatus.expired;
      default:
        return ReservationStatus.pending;
    }
  }
}

extension ReservationPaymentStatusExtension on ReservationPaymentStatus {
  String toShortString() {
    return toString().split('.').last;
  }

  static ReservationPaymentStatus fromString(String status) {
    switch (status.toLowerCase()) {
      case 'depositpaid':
        return ReservationPaymentStatus.depositPaid;
      case 'fullpaid':
        return ReservationPaymentStatus.fullPaid;
      case 'pending':
        return ReservationPaymentStatus.pending;
      default:
        return ReservationPaymentStatus.pending;
    }
  }
}

/// Model for pet reservation (store pickup)
class ReservationModel {
  final String id; // Document ID
  final String userId; // User ID
  final String userIdentifier; // User identifier (phone/email)
  final String displayName; // Customer name
  final String phone; // Customer phone
  final String email; // Customer email

  // Pet information
  final List<Map<String, dynamic>> items; // List of pets in reservation

  // Reservation details
  final DateTime pickupDate; // Ngày khách đến lấy
  final DateTime createdAt; // Ngày tạo reservation
  final ReservationStatus status; // Trạng thái
  final ReservationPaymentStatus paymentStatus; // Trạng thái thanh toán

  // Payment details
  final double totalAmount; // Tổng tiền
  final double depositAmount; // Số tiền cọc
  final double paidAmount; // Số tiền đã trả
  final double remainingAmount; // Số tiền còn lại
  final String paymentMethod; // Phương thức thanh toán (vnpay, stripe, cod)

  // Timestamps
  final DateTime? confirmedAt; // Thời gian admin xác nhận
  final DateTime? completedAt; // Thời gian hoàn thành
  final DateTime? cancelledAt; // Thời gian hủy
  final String? cancelReason; // Lý do hủy
  final String? adminNote; // Ghi chú của admin

  ReservationModel({
    required this.id,
    required this.userId,
    required this.userIdentifier,
    required this.displayName,
    required this.phone,
    required this.email,
    required this.items,
    required this.pickupDate,
    required this.createdAt,
    required this.status,
    required this.paymentStatus,
    required this.totalAmount,
    required this.depositAmount,
    required this.paidAmount,
    required this.remainingAmount,
    required this.paymentMethod,
    this.confirmedAt,
    this.completedAt,
    this.cancelledAt,
    this.cancelReason,
    this.adminNote,
  });

  /// Factory constructor from Firestore document
  factory ReservationModel.fromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ReservationModel.fromMap(doc.id, data);
  }

  /// Factory constructor from map
  factory ReservationModel.fromMap(String id, Map<String, dynamic> data) {
    return ReservationModel(
      id: id,
      userId: data['userId'] ?? '',
      userIdentifier: data['userIdentifier'] ?? '',
      displayName: data['displayName'] ?? '',
      phone: data['phone'] ?? '',
      email: data['email'] ?? '',
      items: List<Map<String, dynamic>>.from(data['items'] ?? []),
      pickupDate: (data['pickupDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      status: ReservationStatusExtension.fromString(
        data['status']?.toString() ?? 'pending',
      ),
      paymentStatus: ReservationPaymentStatusExtension.fromString(
        data['paymentStatus']?.toString() ?? 'pending',
      ),
      totalAmount: (data['totalAmount'] as num?)?.toDouble() ?? 0.0,
      depositAmount: (data['depositAmount'] as num?)?.toDouble() ?? 0.0,
      paidAmount: (data['paidAmount'] as num?)?.toDouble() ?? 0.0,
      remainingAmount: (data['remainingAmount'] as num?)?.toDouble() ?? 0.0,
      paymentMethod: data['paymentMethod'] ?? 'cod',
      confirmedAt: (data['confirmedAt'] as Timestamp?)?.toDate(),
      completedAt: (data['completedAt'] as Timestamp?)?.toDate(),
      cancelledAt: (data['cancelledAt'] as Timestamp?)?.toDate(),
      cancelReason: data['cancelReason'],
      adminNote: data['adminNote'],
    );
  }

  /// Convert to map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'userIdentifier': userIdentifier,
      'displayName': displayName,
      'phone': phone,
      'email': email,
      'items': items,
      'pickupDate': Timestamp.fromDate(pickupDate),
      'createdAt': Timestamp.fromDate(createdAt),
      'status': status.toShortString(),
      'paymentStatus': paymentStatus.toShortString(),
      'totalAmount': totalAmount,
      'depositAmount': depositAmount,
      'paidAmount': paidAmount,
      'remainingAmount': remainingAmount,
      'paymentMethod': paymentMethod,
      'confirmedAt': confirmedAt != null ? Timestamp.fromDate(confirmedAt!) : null,
      'completedAt': completedAt != null ? Timestamp.fromDate(completedAt!) : null,
      'cancelledAt': cancelledAt != null ? Timestamp.fromDate(cancelledAt!) : null,
      'cancelReason': cancelReason,
      'adminNote': adminNote,
    };
  }

  /// Copy with method for updates
  ReservationModel copyWith({
    String? id,
    String? userId,
    String? userIdentifier,
    String? displayName,
    String? phone,
    String? email,
    List<Map<String, dynamic>>? items,
    DateTime? pickupDate,
    DateTime? createdAt,
    ReservationStatus? status,
    ReservationPaymentStatus? paymentStatus,
    double? totalAmount,
    double? depositAmount,
    double? paidAmount,
    double? remainingAmount,
    String? paymentMethod,
    DateTime? confirmedAt,
    DateTime? completedAt,
    DateTime? cancelledAt,
    String? cancelReason,
    String? adminNote,
  }) {
    return ReservationModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      userIdentifier: userIdentifier ?? this.userIdentifier,
      displayName: displayName ?? this.displayName,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      items: items ?? this.items,
      pickupDate: pickupDate ?? this.pickupDate,
      createdAt: createdAt ?? this.createdAt,
      status: status ?? this.status,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      totalAmount: totalAmount ?? this.totalAmount,
      depositAmount: depositAmount ?? this.depositAmount,
      paidAmount: paidAmount ?? this.paidAmount,
      remainingAmount: remainingAmount ?? this.remainingAmount,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      confirmedAt: confirmedAt ?? this.confirmedAt,
      completedAt: completedAt ?? this.completedAt,
      cancelledAt: cancelledAt ?? this.cancelledAt,
      cancelReason: cancelReason ?? this.cancelReason,
      adminNote: adminNote ?? this.adminNote,
    );
  }
}
