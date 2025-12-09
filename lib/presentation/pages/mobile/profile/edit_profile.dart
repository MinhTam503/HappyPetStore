import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'package:pet_shop/auth/login_or_register.dart';
import 'package:pet_shop/core/utils/notification_helper.dart';
import 'package:pet_shop/core/utils/dialog_helper.dart';
// import 'package:pet_shop/core/constants/list_city.dart';
import 'package:pet_shop/core/services/user_manager.dart';
import 'package:pet_shop/presentation/pages/mobile/address/address_list_page.dart';
import 'package:pet_shop/presentation/bloc/profile/edit_profile_bloc.dart';
import 'package:pet_shop/presentation/bloc/profile/edit_profile_event.dart';
import 'package:pet_shop/presentation/bloc/profile/edit_profile_state.dart';
import 'package:pet_shop/presentation/pages/mobile/profile/widgets/header_card.dart';
// section_title & delivery_info_tile đã được dùng trong ShippingInfoSection
import 'package:pet_shop/presentation/pages/mobile/profile/widgets/personal_info_card.dart';
import 'package:pet_shop/presentation/pages/mobile/profile/widgets/contact_info_card.dart';
import 'package:pet_shop/presentation/pages/mobile/profile/widgets/shipping_info_section.dart';
import 'package:pet_shop/presentation/pages/mobile/profile/widgets/save_button.dart';
import 'package:pet_shop/presentation/pages/mobile/profile/widgets/logout_countdown_dialog.dart';
import 'package:pet_shop/presentation/pages/mobile/profile/change_email_page.dart';
import 'package:pet_shop/presentation/pages/mobile/profile/change_phone_page.dart';

class EditProfile extends StatefulWidget {
  const EditProfile({super.key});

  @override
  State<EditProfile> createState() => _EditProfileState();
}

class _EditProfileState extends State<EditProfile> {
  Map<String, dynamic>? user;
  final TextEditingController displayNameController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  String? userIdentifier;
  String imageUrl = "";
  List<Map<String, dynamic>> deliveryInfos = [];
  DateTime? selectedBirthDate;
  String? selectedGender;
  bool emailVerified = false;
  bool phoneVerified = false;
  bool _isLogoutPromptVisible = false;
  String? _lastInfo;
  String? _lastError;

  void _log(String message) {
    // Centralized log for this screen
    debugPrint('🔐 EditProfile: $message');
  }

  @override
  void initState() {
    super.initState();
    _initializeUser();
    // Dispatch start event after first frame so context has access to provided bloc (from route)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      try {
        context.read<EditProfileBloc>().add(EditProfileStarted());
      } catch (_) {
        // If provider not found, navigation wrapper may be missing; UI will still render
      }
    });
  }

  @override
  void dispose() {
    super.dispose();
  }

  void _initializeUser() async {
    UserManager userManager = UserManager();
    userIdentifier = await userManager.getUserIdentifier();
    // Khởi động BLoC bằng cách gửi sự kiện bắt đầu
    // Controllers sẽ được điền từ state khi dữ liệu về
  }

  // =========================
  // Data
  // =========================
  Future<void> fetchUserData() async {
    // Dùng BLoC để tải lại dữ liệu
    context.read<EditProfileBloc>().add(EditProfileStarted());
  }

  Future<bool> _reauthenticateSmart() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;
    final providers = user.providerData.map((p) => p.providerId).toList();

    // Prefer password if available
    if (providers.contains('password') && user.email != null) {
      final ok = await _reauthenticateWithPassword(user.email!);
      if (ok) return true;
    }
    // Try Google
    if (providers.contains('google.com')) {
      final ok = await _reauthenticateWithGoogle();
      if (ok) return true;
    }
    // Try Facebook
    if (providers.contains('facebook.com')) {
      final ok = await _reauthenticateWithFacebook();
      if (ok) return true;
    }
    // Try Phone
    if (providers.contains('phone')) {
      final ok = await _reauthenticateWithPhone(
          user.phoneNumber ?? phoneController.text.trim());
      if (ok) return true;
    }
    return false;
  }

  Future<bool> _reauthenticateWithPassword(String email) async {
    final pwdController = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xác thực lại'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Nhập mật khẩu cho $email'),
            const SizedBox(height: 8),
            TextField(
              controller: pwdController,
              obscureText: true,
              decoration: const InputDecoration(hintText: 'Mật khẩu'),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Hủy')),
          TextButton(
            onPressed: () async {
              try {
                final cred = EmailAuthProvider.credential(
                    email: email, password: pwdController.text.trim());
                await FirebaseAuth.instance.currentUser
                    ?.reauthenticateWithCredential(cred);
                if (context.mounted) Navigator.pop(ctx, true);
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Sai mật khẩu hoặc lỗi re-auth: $e')),
                );
              }
            },
            child: const Text('Xác thực'),
          ),
        ],
      ),
    );
    return ok == true;
  }

  Future<bool> _reauthenticateWithGoogle() async {
    try {
      final google = GoogleSignIn();
      try {
        await google.signOut();
      } catch (_) {}
      final account = await google.signIn();
      if (account == null) return false;
      final auth = await account.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: auth.accessToken,
        idToken: auth.idToken,
      );
      await FirebaseAuth.instance.currentUser
          ?.reauthenticateWithCredential(credential);
      return true;
    } catch (e) {
      NotificationHelper.showError(
          context, 'Re-auth Google thất bại', e.toString());
      return false;
    }
  }

  Future<bool> _reauthenticateWithFacebook() async {
    try {
      final result = await FacebookAuth.instance
          .login(permissions: ['public_profile', 'email']);
      if (result.status != LoginStatus.success || result.accessToken == null)
        return false;
      final credential =
          FacebookAuthProvider.credential(result.accessToken!.token);
      await FirebaseAuth.instance.currentUser
          ?.reauthenticateWithCredential(credential);
      return true;
    } catch (e) {
      NotificationHelper.showError(
          context, 'Re-auth Facebook thất bại', e.toString());
      return false;
    }
  }

  Future<bool> _reauthenticateWithPhone(String phone) async {
    if (phone.isEmpty) {
      NotificationHelper.showWarning(
          context, 'Thiếu số điện thoại', 'Không có SĐT để xác thực lại');
      return false;
    }
    String? verificationId;
    final codeController = TextEditingController();
    final completer = Completer<bool>();
    try {
      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: phone,
        verificationCompleted: (cred) async {
          try {
            await FirebaseAuth.instance.currentUser
                ?.reauthenticateWithCredential(cred);
            completer.complete(true);
          } catch (e) {
            completer.complete(false);
          }
        },
        verificationFailed: (e) {
          NotificationHelper.showError(context, 'OTP thất bại', e.message);
          completer.complete(false);
        },
        codeSent: (id, _) async {
          verificationId = id;
          final ok = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Nhập mã OTP'),
              content: TextField(
                controller: codeController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(hintText: '6 chữ số'),
              ),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('Hủy')),
                TextButton(
                  onPressed: () async {
                    if (verificationId != null &&
                        codeController.text.trim().length == 6) {
                      try {
                        final cred = PhoneAuthProvider.credential(
                          verificationId: verificationId!,
                          smsCode: codeController.text.trim(),
                        );
                        await FirebaseAuth.instance.currentUser
                            ?.reauthenticateWithCredential(cred);
                        if (context.mounted) Navigator.pop(ctx, true);
                      } catch (e) {
                        NotificationHelper.showError(
                            context, 'Xác minh OTP thất bại', e.toString());
                      }
                    }
                  },
                  child: const Text('Xác thực'),
                ),
              ],
            ),
          );
          completer.complete(ok == true);
        },
        codeAutoRetrievalTimeout: (_) {},
      );
    } catch (e) {
      NotificationHelper.showError(context, 'Lỗi OTP', e.toString());
      return false;
    }
    return completer.future;
  }

  Future<void> _showLogoutCountdown(
      {required int seconds, String? reason}) async {
    if (_isLogoutPromptVisible) return;
    _isLogoutPromptVisible = true;
    await showLogoutCountdownDialog(
      context,
      seconds: seconds,
      reason: reason,
      onLogoutNow: () async {
        try {
          await FirebaseAuth.instance.signOut();
        } catch (e) {
          _log('logout error: $e');
        }
        if (!mounted) return;
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => LoginOrRegister()),
          (route) => false,
        );
      },
    );
    _isLogoutPromptVisible = false;
  }

  Future<void> pickImage() async {
    // Capture bloc before awaiting to avoid context lookup after await
    final bloc = context.read<EditProfileBloc>();
    final pickedFile =
        await ImagePicker().pickImage(source: ImageSource.gallery);
    if (pickedFile == null) return;
    if (!mounted) return;
    bloc.add(EditProfileUploadAvatar(pickedFile.path));
  }

  // =========================
  // Date Picker
  // =========================
  Future<void> _selectBirthDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: selectedBirthDate ??
          DateTime.now().subtract(const Duration(days: 365 * 18)),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      helpText: 'Chọn ngày sinh',
      cancelText: 'Hủy',
      confirmText: 'Chọn',
    );
    if (picked != null && picked != selectedBirthDate) {
      setState(() {
        selectedBirthDate = picked;
      });
    }
  }

  void removeDeliveryInfo(int index) {
    setState(() {
      bool wasDefault = deliveryInfos[index]['isDefault'] == true;
      deliveryInfos.removeAt(index);

      // If removed item was default, make first item default
      if (wasDefault && deliveryInfos.isNotEmpty) {
        deliveryInfos[0]['isDefault'] = true;
      }
    });
  }

  void setDefaultDeliveryInfo(int index) {
    setState(() {
      for (int i = 0; i < deliveryInfos.length; i++) {
        deliveryInfos[i]['isDefault'] = i == index;
      }
    });
  }

  // =========================
  // UI
  // =========================
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = MediaQuery.of(context).size;
    final isWide = size.width >= 900;
    final horizontal = isWide ? size.width * 0.15 : 16.0;

    return BlocListener<EditProfileBloc, EditProfileState>(
        listener: (context, state) async {
          // Global loading overlay for save/upload operations
          if (state.isSaving) {
            // Show loading overlay while saving or uploading avatar
            DialogHelper.showLoadingDialog(context, message: 'Đang xử lý...');
          } else {
            await DialogHelper.safeHideLoadingDialog();
          }

          // Cập nhật controllers từ state.user (lần đầu hoặc khi thay đổi quan trọng)
          final data = state.user;
          if (data != null) {
            if (displayNameController.text != (data['displayName'] ?? '')) {
              displayNameController.text = data['displayName'] ?? '';
            }
            final phoneDoc = data['phone'] ?? data['phoneNumber'];
            if (phoneDoc is String && phoneDoc != phoneController.text) {
              phoneController.text = phoneDoc;
            }
            // Filter out virtual emails created for phone-only accounts
            final emailDoc = data['email'] as String?;
            final isVirtualEmail = emailDoc != null && emailDoc.endsWith('@petshop.local');
            if (!isVirtualEmail && (emailDoc ?? '') != emailController.text) {
              emailController.text = emailDoc ?? '';
            } else if (isVirtualEmail && emailController.text.isEmpty) {
              emailController.text = ''; // Treat virtual email as no email
            }
            // deliveryInfos
            final deliveryData = data['deliveryInfos'];
            if (deliveryData is List) {
              deliveryInfos = List<Map<String, dynamic>>.from(deliveryData);
            }
            // birth date
            if (data['birthDate'] != null) {
              if (data['birthDate'] is Timestamp) {
                selectedBirthDate = (data['birthDate'] as Timestamp).toDate();
              }
            }
            selectedGender = data['gender'];
            imageUrl = state.imageUrl;
            emailVerified = state.emailVerified;
            phoneVerified = state.phoneVerified;
          }

          // Thông điệp
          if (state.infoMessage != null &&
              state.infoMessage!.isNotEmpty &&
              state.infoMessage != _lastInfo) {
            _lastInfo = state.infoMessage;
            NotificationHelper.showSuccess(
                context, 'Thành công', state.infoMessage!);
          }
          if (state.errorMessage != null &&
              state.errorMessage!.isNotEmpty &&
              state.errorMessage != _lastError) {
            _lastError = state.errorMessage;
            NotificationHelper.showError(context, 'Lỗi', state.errorMessage!);
            // Nếu lỗi yêu cầu xác thực lại → mở dialog re-auth, sau đó thử lại gửi xác minh (nếu có pendingEmail)
            if (state.errorMessage!.contains('xác thực lại')) {
              final ok = await _reauthenticateSmart();
              if (ok) {
                final retryEmail = emailController.text.trim();
                if (retryEmail.isNotEmpty) {
                  context
                      .read<EditProfileBloc>()
                      .add(EditProfileRequestEmailVerification(retryEmail));
                }
              }
            }
          }

          // OTP: nếu có verificationId, hiển thị dialog nhập OTP
          if (state.otpVerificationId != null) {
            final codeController = TextEditingController();
            await showDialog(
              context: context,
              builder: (dialogCtx) => BlocProvider.value(
                value: context.read<EditProfileBloc>(),
                child: AlertDialog(
                  title: const Text('Nhập mã OTP'),
                  content: TextField(
                    controller: codeController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(hintText: '6 chữ số'),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(dialogCtx),
                      child: const Text('Hủy'),
                    ),
                    TextButton(
                      onPressed: () {
                        final smsCode = codeController.text.trim();
                        if (smsCode.length == 6) {
                          Navigator.pop(dialogCtx);
                          dialogCtx
                              .read<EditProfileBloc>()
                              .add(EditProfileSubmitOtp(
                                verificationId: state.otpVerificationId!,
                                code: smsCode,
                              ));
                        }
                      },
                      child: const Text('Xác minh'),
                    ),
                  ],
                ),
              ),
            );
          }

          // Đếm ngược đăng xuất khi token hết hạn
          if (state.showLogoutCountdown) {
            _showLogoutCountdown(
                seconds: state.countdownSeconds, reason: state.logoutReason);
          }
        },
        child: BlocBuilder<EditProfileBloc, EditProfileState>(
          builder: (context, state) {
            final data = state.user;
            // Email verification UI moved to ContactInfoCard; state.emailVerified retained for compatibility

            return Scaffold(
              backgroundColor: Theme.of(context).colorScheme.surface,
              appBar: AppBar(
                backgroundColor: Theme.of(context).colorScheme.surface,
                elevation: 0,
                centerTitle: true,
                iconTheme: const IconThemeData(color: Colors.black),
                title: Text(
                  data?['displayName'] ?? "",
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: Colors.black,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              body: data == null
                  ? const Center(child: CircularProgressIndicator())
                  : RefreshIndicator(
                      onRefresh: fetchUserData,
                      child: ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding:
                            EdgeInsets.fromLTRB(horizontal, 16, horizontal, 24),
                        children: [
                          HeaderCard(
                              imageUrl: imageUrl,
                              displayName:
                                  (data['displayName'] ?? '') as String,
                              onEditAvatar: pickImage),
                          const SizedBox(height: 16),

                          // Thông tin cơ bản
                          PersonalInfoCard(
                            displayNameController: displayNameController,
                            phoneController: phoneController,
                            emailController: emailController,
                            selectedBirthDate: selectedBirthDate,
                            onSelectBirthDate: _selectBirthDate,
                            selectedGender: selectedGender,
                            onGenderChanged: (val) =>
                                setState(() => selectedGender = val),
                          ),
                          const SizedBox(height: 12),
                          ContactInfoCard(
                            currentEmail: (data['email'] as String?)?.endsWith('@petshop.local') == true
                                ? null // Treat virtual email as no email
                                : data['email'] as String?,
                            currentPhone: (data['phone'] ?? data['phoneNumber']) as String?,
                            onChangeEmail: () async {
                              final changed = await Navigator.push<bool>(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ChangeEmailPage(
                                      currentEmail: (data['email'] as String?)?.endsWith('@petshop.local') == true
                                          ? null // Treat virtual email as no email for edit
                                          : data['email'] as String?),
                                ),
                              );
                              if (changed == true) {
                                fetchUserData();
                              }
                            },
                            onChangePhone: () async {
                              final changed = await Navigator.push<bool>(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ChangePhonePage(
                                      currentPhone: (data['phone'] ??
                                          data['phoneNumber']) as String?),
                                ),
                              );
                              if (changed == true) {
                                fetchUserData();
                              }
                            },
                          ),
                          if (state.pendingEmail != null) ...[
                            const SizedBox(height: 6),
                            Text(
                              'Email mới đang chờ xác minh: ${state.pendingEmail}',
                              style: TextStyle(
                                  color: Colors.orange.shade700, fontSize: 12),
                            ),
                          ],

                          const SizedBox(height: 20),

                          // Thông tin giao hàng
                          ShippingInfoSection(
                            deliveryInfos: deliveryInfos,
                            onEditPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (context) =>
                                        const AddressListPage()),
                              );
                            },
                            onDeleteAt: (i) => removeDeliveryInfo(i),
                            onSetDefaultAt: (i) => setDefaultDeliveryInfo(i),
                          ),

                          const SizedBox(height: 24),

                          // Lưu
                          SaveButton(
                            isSaving: state.isSaving,
                            onPressed: () {
                              context.read<EditProfileBloc>().add(
                                EditProfileUpdateSubmitted(
                                  displayName: displayNameController.text.trim(),
                                  // Email/SĐT được đổi qua trang riêng; giữ nguyên giá trị hiện tại
                                  phone: ((data['phone'] ?? data['phoneNumber']) as String? ?? '').trim(),
                                  // Keep virtual email if exists (for authentication), but treat as empty for user
                                  email: (data['email'] as String? ?? '').trim(),
                                  deliveryInfos: deliveryInfos,
                                  imageUrl: imageUrl,
                                  gender: selectedGender,
                                  birthDate: selectedBirthDate,
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
            );
          },
        ),
      );
  }
}
