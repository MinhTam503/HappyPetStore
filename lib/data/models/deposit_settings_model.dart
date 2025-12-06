import 'package:cloud_firestore/cloud_firestore.dart';

/// Deposit calculation type
enum DepositType {
  percentage, // Tính theo %
  fixedAmount, // Số tiền cố định
}

/// Model for deposit settings (configured by admin)
class DepositSettingsModel {
  final String id; // Document ID (usually 'settings')
  final DepositType depositType; // Loại tính toán: % hoặc số tiền cố định
  final double depositPercentage; // Phần trăm cọc (0-100)
  final double depositFixedAmount; // Số tiền cọc cố định (VND)
  final int maxReservationDays; // Số ngày tối đa có thể đặt trước
  final bool isEnabled; // Bật/tắt chức năng đặt trước
  final DateTime updatedAt; // Thời gian cập nhật
  final String? updatedBy; // Admin ID cập nhật

  DepositSettingsModel({
    required this.id,
    this.depositType = DepositType.percentage,
    this.depositPercentage = 30.0, // Mặc định 30%
    this.depositFixedAmount = 100000.0, // Mặc định 100,000 VND
    this.maxReservationDays = 3, // Mặc định 3 ngày
    this.isEnabled = true, // Mặc định bật
    required this.updatedAt,
    this.updatedBy,
  });

  /// Factory constructor from Firestore document
  factory DepositSettingsModel.fromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>?;
    if (data == null) {
      return DepositSettingsModel(
        id: doc.id,
        updatedAt: DateTime.now(),
      );
    }
    return DepositSettingsModel.fromMap(doc.id, data);
  }

  /// Factory constructor from map
  factory DepositSettingsModel.fromMap(String id, Map<String, dynamic> data) {
    final depositTypeStr = data['depositType'] as String?;
    final depositType = depositTypeStr == 'fixedAmount' 
        ? DepositType.fixedAmount 
        : DepositType.percentage;
    
    return DepositSettingsModel(
      id: id,
      depositType: depositType,
      depositPercentage: (data['depositPercentage'] as num?)?.toDouble() ?? 30.0,
      depositFixedAmount: (data['depositFixedAmount'] as num?)?.toDouble() ?? 100000.0,
      maxReservationDays: (data['maxReservationDays'] as num?)?.toInt() ?? 3,
      isEnabled: data['isEnabled'] ?? true,
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedBy: data['updatedBy'],
    );
  }

  /// Convert to map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'depositType': depositType == DepositType.percentage ? 'percentage' : 'fixedAmount',
      'depositPercentage': depositPercentage,
      'depositFixedAmount': depositFixedAmount,
      'maxReservationDays': maxReservationDays,
      'isEnabled': isEnabled,
      'updatedAt': Timestamp.fromDate(updatedAt),
      'updatedBy': updatedBy,
    };
  }

  /// Copy with method for updates
  DepositSettingsModel copyWith({
    String? id,
    DepositType? depositType,
    double? depositPercentage,
    double? depositFixedAmount,
    int? maxReservationDays,
    bool? isEnabled,
    DateTime? updatedAt,
    String? updatedBy,
  }) {
    return DepositSettingsModel(
      id: id ?? this.id,
      depositType: depositType ?? this.depositType,
      depositPercentage: depositPercentage ?? this.depositPercentage,
      depositFixedAmount: depositFixedAmount ?? this.depositFixedAmount,
      maxReservationDays: maxReservationDays ?? this.maxReservationDays,
      isEnabled: isEnabled ?? this.isEnabled,
      updatedAt: updatedAt ?? this.updatedAt,
      updatedBy: updatedBy ?? this.updatedBy,
    );
  }

  /// Calculate deposit amount based on type
  double calculateDeposit(double totalAmount) {
    if (depositType == DepositType.fixedAmount) {
      return depositFixedAmount;
    }
    return totalAmount * (depositPercentage / 100);
  }
}
