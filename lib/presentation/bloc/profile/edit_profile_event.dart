import 'package:equatable/equatable.dart';

sealed class EditProfileEvent extends Equatable {
  @override
  List<Object?> get props => [];
}

final class EditProfileStarted extends EditProfileEvent {}

final class EditProfileRealtimeUserChanged extends EditProfileEvent {
  final Map<String, dynamic> userData;
  EditProfileRealtimeUserChanged(this.userData);
  @override
  List<Object?> get props => [userData];
}

final class EditProfileUpdateSubmitted extends EditProfileEvent {
  final String displayName;
  final String phone;
  final String email; // có thể là email mới
  final List<Map<String, dynamic>> deliveryInfos;
  final String? gender;
  final DateTime? birthDate;
  final String imageUrl;
  EditProfileUpdateSubmitted({
    required this.displayName,
    required this.phone,
    required this.email,
    required this.deliveryInfos,
    required this.imageUrl,
    this.gender,
    this.birthDate,
  });
  @override
  List<Object?> get props => [displayName, phone, email, deliveryInfos, gender, birthDate, imageUrl];
}

final class EditProfileRequestEmailVerification extends EditProfileEvent {
  final String newEmail;
  EditProfileRequestEmailVerification(this.newEmail);
  @override
  List<Object?> get props => [newEmail];
}

final class EditProfileRefreshVerification extends EditProfileEvent {}

final class EditProfileStartPhoneVerification extends EditProfileEvent {
  final String phone;
  EditProfileStartPhoneVerification(this.phone);
  @override
  List<Object?> get props => [phone];
}

final class EditProfileSubmitOtp extends EditProfileEvent {
  final String verificationId;
  final String code;
  EditProfileSubmitOtp({required this.verificationId, required this.code});
  @override
  List<Object?> get props => [verificationId, code];
}

final class EditProfileUploadAvatar extends EditProfileEvent {
  final String filePath;
  EditProfileUploadAvatar(this.filePath);
  @override
  List<Object?> get props => [filePath];
}

// Khi verify email yêu cầu xác thực lại
final class EditProfileRetryPendingAction extends EditProfileEvent {}
