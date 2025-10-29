import 'package:equatable/equatable.dart';

class EditProfileState extends Equatable {
  final Map<String, dynamic>? user;
  final bool isLoading;
  final bool isSaving;
  final bool emailVerified;
  final bool phoneVerified;
  final String imageUrl;
  final String? pendingEmail;
  final String? infoMessage; // thông báo
  final String? errorMessage; // lỗi

  // OTP flow
  final String? otpVerificationId;

  // Đăng xuất đếm ngược khi token hết hạn
  final bool showLogoutCountdown;
  final int countdownSeconds;
  final String? logoutReason;

  const EditProfileState({
    this.user,
    this.isLoading = false,
    this.isSaving = false,
    this.emailVerified = false,
    this.phoneVerified = false,
    this.imageUrl = '',
    this.pendingEmail,
    this.infoMessage,
    this.errorMessage,
    this.otpVerificationId,
    this.showLogoutCountdown = false,
    this.countdownSeconds = 0,
    this.logoutReason,
  });

  EditProfileState copyWith({
    Map<String, dynamic>? user,
    bool? isLoading,
    bool? isSaving,
    bool? emailVerified,
    bool? phoneVerified,
    String? imageUrl,
    String? pendingEmail,
    String? infoMessage,
    String? errorMessage,
    String? otpVerificationId,
    bool? showLogoutCountdown,
    int? countdownSeconds,
    String? logoutReason,
  }) {
    return EditProfileState(
      user: user ?? this.user,
      isLoading: isLoading ?? this.isLoading,
      isSaving: isSaving ?? this.isSaving,
      emailVerified: emailVerified ?? this.emailVerified,
      phoneVerified: phoneVerified ?? this.phoneVerified,
      imageUrl: imageUrl ?? this.imageUrl,
      pendingEmail: pendingEmail ?? this.pendingEmail,
      infoMessage: infoMessage,
      errorMessage: errorMessage,
      otpVerificationId: otpVerificationId,
      showLogoutCountdown: showLogoutCountdown ?? this.showLogoutCountdown,
      countdownSeconds: countdownSeconds ?? this.countdownSeconds,
      logoutReason: logoutReason ?? this.logoutReason,
    );
  }

  @override
  List<Object?> get props => [
        user,
        isLoading,
        isSaving,
        emailVerified,
        phoneVerified,
        imageUrl,
        pendingEmail,
        infoMessage,
        errorMessage,
        otpVerificationId,
        showLogoutCountdown,
        countdownSeconds,
        logoutReason,
      ];
}

class EditProfileInitial extends EditProfileState {
  const EditProfileInitial();
}
