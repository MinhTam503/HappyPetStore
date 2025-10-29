import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'edit_profile_event.dart';
import 'edit_profile_state.dart';

class EditProfileBloc extends Bloc<EditProfileEvent, EditProfileState> {
  EditProfileBloc() : super(const EditProfileInitial()) {
    on<EditProfileStarted>(_onStarted);
    on<EditProfileRealtimeUserChanged>(_onRealtimeUserChanged);
    on<EditProfileUpdateSubmitted>(_onUpdateSubmitted);
    on<EditProfileRequestEmailVerification>(_onRequestEmailVerification);
    on<EditProfileRefreshVerification>(_onRefreshVerification);
    on<EditProfileStartPhoneVerification>(_onStartPhoneVerification);
    on<EditProfileSubmitOtp>(_onSubmitOtp);
    on<EditProfileUploadAvatar>(_onUploadAvatar);
  }

  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _userSub;
  String? _lastPendingEmail; // dùng để retry nếu cần

  FirebaseAuth get _auth => FirebaseAuth.instance;
  FirebaseFirestore get _db => FirebaseFirestore.instance;
  FirebaseStorage get _storage => FirebaseStorage.instance;

  void _log(String msg) {
    if (kDebugMode) debugPrint('🔐 EditProfileBloc: $msg');
  }

  Future<void> _onStarted(
    EditProfileStarted event,
    Emitter<EditProfileState> emit,
  ) async {
    final user = _auth.currentUser;
    if (user == null) return;
    emit(state.copyWith(isLoading: true, infoMessage: null, errorMessage: null));

    try {
      final doc = await _db.collection('users').doc(user.uid).get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        final emailVerifiedDoc = data['emailVerified'] == true;
        emit(state.copyWith(
          isLoading: false,
          user: data,
          emailVerified: emailVerifiedDoc || user.emailVerified,
          phoneVerified: (user.phoneNumber?.isNotEmpty == true) || (data['phoneVerified'] == true),
          imageUrl: (data['imageUrl'] as String?) ?? '',
        ));
      } else {
        emit(state.copyWith(isLoading: false));
      }

      // subscribe realtime changes
      await _userSub?.cancel();
      _userSub = _db.collection('users').doc(user.uid).snapshots().listen(
        (snap) {
          if (snap.exists && snap.data() != null) {
            add(EditProfileRealtimeUserChanged(snap.data()!));
          }
        },
        onError: (e) => _log('Realtime error: $e'),
      );
    } catch (e) {
      emit(state.copyWith(isLoading: false, errorMessage: e.toString()));
    }
  }

  void _onRealtimeUserChanged(
    EditProfileRealtimeUserChanged event,
    Emitter<EditProfileState> emit,
  ) {
    final data = event.userData;
    _log('rt: users change -> email=${data['email']}, emailVerified=${data['emailVerified']}');
    emit(state.copyWith(
      user: data,
      emailVerified: (data['emailVerified'] == true) || state.emailVerified,
      phoneVerified: (data['phoneVerified'] == true) || state.phoneVerified,
      imageUrl: (data['imageUrl'] as String?) ?? state.imageUrl,
    ));
  }

  Future<void> _onUpdateSubmitted(
    EditProfileUpdateSubmitted event,
    Emitter<EditProfileState> emit,
  ) async {
    final user = _auth.currentUser;
    if (user == null) return;

    emit(state.copyWith(isSaving: true, infoMessage: null, errorMessage: null));
    try {
      final updateData = <String, dynamic>{
        'displayName': event.displayName,
        'phone': event.phone,
        'deliveryInfos': event.deliveryInfos,
        'imageUrl': event.imageUrl,
        'gender': event.gender,
      }..removeWhere((k, v) => v == null);

      if (event.birthDate != null) {
        updateData['birthDate'] = Timestamp.fromDate(event.birthDate!);
      }

      // Email mới: nếu khác Auth -> gửi xác minh + cập nhật Firestore (emailVerified=false)
      final newEmail = event.email.trim();
      if (newEmail.isNotEmpty && newEmail != (user.email ?? '')) {
        final sent = await _verifyBeforeUpdateEmailInternal(newEmail);
        if (sent) {
          _lastPendingEmail = newEmail;
          updateData['email'] = newEmail;
          updateData['emailVerified'] = false;
        } else {
          emit(state.copyWith(errorMessage: 'Cần xác thực lại trước khi gửi email xác minh.'));
        }
      }

      await _db.collection('users').doc(user.uid).update(updateData);

      emit(state.copyWith(
        isSaving: false,
        infoMessage: newEmail.isNotEmpty && newEmail != (user.email ?? '')
            ? 'Đã gửi email xác minh. Hãy kiểm tra hộp thư "$newEmail" để xác minh.'
            : 'Thông tin hồ sơ đã được lưu.',
        pendingEmail: _lastPendingEmail ?? state.pendingEmail,
      ));
    } catch (e) {
      emit(state.copyWith(isSaving: false, errorMessage: e.toString()));
    }
  }

  Future<void> _onRequestEmailVerification(
    EditProfileRequestEmailVerification event,
    Emitter<EditProfileState> emit,
  ) async {
    final sent = await _verifyBeforeUpdateEmailInternal(event.newEmail);
    if (sent) {
      emit(state.copyWith(
        infoMessage: 'Đã gửi email xác minh. Kiểm tra hộp thư "${event.newEmail}" để xác minh.',
        pendingEmail: event.newEmail,
      ));
    } else {
      emit(state.copyWith(errorMessage: 'Cần xác thực lại trước khi gửi email xác minh.'));
    }
  }

  Future<bool> _verifyBeforeUpdateEmailInternal(String newEmail) async {
    final user = _auth.currentUser;
    if (user == null) return false;
    try {
      await user.verifyBeforeUpdateEmail(newEmail);
      _log('verifyBeforeUpdateEmail: sent to $newEmail');
      try {
        await _db.collection('users').doc(user.uid).update({
          'email': newEmail,
          'emailVerified': false,
        });
      } catch (e) {
        _log('update users.email failed: $e');
      }
      return true;
    } catch (e) {
      if (e is FirebaseAuthException && e.code == 'requires-recent-login') {
        // UI sẽ thực hiện re-auth và gọi lại event RetryPendingAction hoặc RequestEmailVerification
        _log('requires-recent-login when verify email');
        // phát thông điệp để UI hiển thị yêu cầu xác thực lại
        addError('Cần xác thực lại phiên đăng nhập để gửi email xác minh.');
      }
      _log('verifyBeforeUpdateEmail error: $e');
      return false;
    }
  }

  Future<void> _onRefreshVerification(
    EditProfileRefreshVerification event,
    Emitter<EditProfileState> emit,
  ) async {
    try {
      await _auth.currentUser?.reload();
      final u = _auth.currentUser;
      if (u == null) return;
      final currentEmail = state.user?['email'] as String?;
      if (u.email != null && u.email != currentEmail) {
        await _db.collection('users').doc(u.uid).update({
          'email': u.email,
          'emailVerified': true,
        });
        emit(state.copyWith(
          emailVerified: true,
          user: {...?state.user, 'email': u.email, 'emailVerified': true},
          infoMessage: 'Email đã được đồng bộ với tài khoản.',
          pendingEmail: null,
        ));
      } else {
        final firestoreVerified = state.user?['emailVerified'] == true;
        if (u.emailVerified && !firestoreVerified) {
          await _db.collection('users').doc(u.uid).update({'emailVerified': true});
          emit(state.copyWith(
            emailVerified: true,
            user: {...?state.user, 'emailVerified': true},
            infoMessage: 'Email đã được đồng bộ với tài khoản.',
          ));
        } else {
          emit(state.copyWith(infoMessage: 'Trạng thái đã được cập nhật.'));
        }
      }
    } catch (e) {
      if (e is FirebaseAuthException && e.code == 'user-token-expired') {
        emit(state.copyWith(
          showLogoutCountdown: true,
          countdownSeconds: 10,
          logoutReason: e.message,
        ));
        return;
      }
      emit(state.copyWith(errorMessage: 'Lỗi trạng thái xác minh: $e'));
    }
  }

  Future<void> _onStartPhoneVerification(
    EditProfileStartPhoneVerification event,
    Emitter<EditProfileState> emit,
  ) async {
    final phone = event.phone.trim();
    if (phone.isEmpty) {
      emit(state.copyWith(errorMessage: 'Vui lòng nhập số điện thoại để xác minh'));
      return;
    }

    try {
      await _auth.verifyPhoneNumber(
        phoneNumber: phone,
        verificationCompleted: (cred) async {
          try {
            await _auth.currentUser?.linkWithCredential(cred);
            final uid = _auth.currentUser!.uid;
            await _db.collection('users').doc(uid).update({
              'phone': phone,
              'phoneNumber': phone,
              'phoneVerified': true,
            });
            emit(state.copyWith(phoneVerified: true, infoMessage: 'Xác minh SĐT thành công'));
          } catch (e) {
            emit(state.copyWith(errorMessage: 'Lỗi liên kết SĐT: $e'));
          }
        },
        verificationFailed: (e) {
          emit(state.copyWith(errorMessage: 'Gửi OTP thất bại: ${e.message}'));
        },
        codeSent: (id, _) async {
          emit(state.copyWith(otpVerificationId: id, infoMessage: 'Mã OTP đã được gửi'));
        },
        codeAutoRetrievalTimeout: (_) {},
      );
    } catch (e) {
      emit(state.copyWith(errorMessage: 'Lỗi xác minh: $e'));
    }
  }

  Future<void> _onSubmitOtp(
    EditProfileSubmitOtp event,
    Emitter<EditProfileState> emit,
  ) async {
    final id = event.verificationId;
    final code = event.code;
    try {
      final cred = PhoneAuthProvider.credential(verificationId: id, smsCode: code);
      await _auth.currentUser?.linkWithCredential(cred);
      final uid = _auth.currentUser!.uid;
      // Lưu phone vào Firestore nếu có trong state
      await _db.collection('users').doc(uid).update({
        'phoneVerified': true,
      });
      emit(state.copyWith(phoneVerified: true, infoMessage: 'Xác minh SĐT thành công', otpVerificationId: null));
    } catch (e) {
      emit(state.copyWith(errorMessage: 'Xác minh OTP thất bại: $e'));
    }
  }

  Future<void> _onUploadAvatar(
    EditProfileUploadAvatar event,
    Emitter<EditProfileState> emit,
  ) async {
    final user = _auth.currentUser;
    if (user == null) return;
    try {
      final file = File(event.filePath);
      final fileName = 'profile_${user.uid}.jpg';
      final ref = _storage.ref().child('profile_images/$fileName');
      await ref.putFile(file);
      final url = await ref.getDownloadURL();
      await _db.collection('users').doc(user.uid).update({'imageUrl': url});
      emit(state.copyWith(imageUrl: url, infoMessage: 'Ảnh đại diện đã được cập nhật'));
    } catch (e) {
      emit(state.copyWith(errorMessage: 'Cập nhật ảnh thất bại: $e'));
    }
  }

  @override
  Future<void> close() {
    _userSub?.cancel();
    return super.close();
  }
}
