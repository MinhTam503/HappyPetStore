import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:pet_shop/auth/auth_service.dart';
import 'package:pet_shop/presentation/widgets/components/my_button.dart';
import 'package:pet_shop/presentation/widgets/components/my_textfield.dart';
import 'package:pet_shop/core/constants/app_constants.dart';
import 'package:pet_shop/core/utils/localization_helper.dart';
import 'package:pet_shop/presentation/pages/mobile/auth/VerifyEmailPage.dart';
import 'package:pet_shop/presentation/pages/mobile/auth/otp_verification_page.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pet_shop/core/utils/dialog_helper.dart';
import 'package:flutter/foundation.dart';
import 'package:pet_shop/helpers/phone_utils.dart';

class RegisterPageNew extends StatefulWidget {
  final void Function()? onTap;

  const RegisterPageNew({super.key, required this.onTap});

  @override
  State<RegisterPageNew> createState() => _RegisterPageNewState();
}

class _RegisterPageNewState extends State<RegisterPageNew> 
    with TickerProviderStateMixin {
  final TextEditingController _accountController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeIn,
    ));
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutBack,
    ));
    _animationController.forward();
  }

  @override
  void dispose() {
    _accountController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _nameController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  // Check if input is email or phone
  bool _isEmail(String input) {
    return RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(input);
  }

  // Validate and normalize VN phone number to E.164 (+84XXXXXXXXX)
  bool _isPhoneNumber(String input) => PhoneUtils.isValidVN(input);
  String _formatPhoneNumber(String phone) => PhoneUtils.normalizeVN(phone) ?? phone;

  void _register(BuildContext context) async {
    String account = _accountController.text.trim();
    String password = _passwordController.text.trim();
    String confirmPassword = _confirmPasswordController.text.trim();
    String name = _nameController.text.trim();

    // Validation
    if (account.isEmpty || password.isEmpty || confirmPassword.isEmpty || name.isEmpty) {
      _showSnackbar(LocalizationHelper.getLocalizedText(context, 'fillAllFields'));
      return;
    }

    if (password.length < 6) {
      _showSnackbar(LocalizationHelper.getLocalizedText(context, 'passwordMinLength'));
      return;
    }

    if (password != confirmPassword) {
      _showSnackbar(LocalizationHelper.getLocalizedText(context, 'passwordMismatch'));
      return;
    }

    if (!_isEmail(account) && !_isPhoneNumber(account)) {
      _showSnackbar('Số điện thoại không hợp lệ. Cho phép nhập 09xxxxxxxx; hệ thống sẽ lưu +84xxxxxxxxx.');
      return;
    }

    DialogHelper.showLoadingDialog(context, message: "Đang tạo tài khoản...");

    try {
      if (_isEmail(account)) {
        // Register with email - require email verification
        await _registerWithEmail(account, password, name);
      } else {
        // Register with phone - require OTP verification
        await _registerWithPhone(account, password, name);
      }
    } catch (e) {
      await DialogHelper.hideLoadingDialog(context);
      if (mounted) {
        _showSnackbar("${LocalizationHelper.getLocalizedText(context, 'registrationError')}: $e");
      }
    }
  }

  Future<void> _registerWithEmail(String email, String password, String name) async {
    try {
      debugPrint('🔄 Creating account for email: $email');

      // Check if email already exists
      QuerySnapshot emailQuery = await FirebaseFirestore.instance
          .collection("users")
          .where("email", isEqualTo: email)
          .get();

      if (emailQuery.docs.isNotEmpty) {
        await DialogHelper.hideLoadingDialog(context);
        if (mounted) {
          _showSnackbar(LocalizationHelper.getLocalizedText(context, 'emailAlreadyUsed'));
        }
        return;
      }

      UserCredential userCredential = await authService.value
          .createAccount(email: email, password: password);
      User? user = userCredential.user;

      if (user != null) {
        debugPrint('✅ Account created, sending verification email...');

        await user.sendEmailVerification();

        await DialogHelper.hideLoadingDialog(context);

        if (!mounted) return;

        _showSnackbar(LocalizationHelper.getLocalizedText(context, 'verificationEmailSent'));

        // Navigate to verification page
        bool emailVerified = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => VerifyEmailPage(email: email),
          ),
        ) ?? false;

        if (!mounted) return;

        if (emailVerified) {
          debugPrint('✅ Email verified, creating user document...');

          // Create user document in Firestore
          await FirebaseFirestore.instance.collection("users").doc(user.uid).set({
            "email": email,
            "role": "user",
            "displayName": name,
            "imageUrl": "https://i.pinimg.com/736x/8b/16/7a/8b167af653c2399dd93b952a48740620.jpg",
            "address": [],
            "phone": "",
            "createdAt": FieldValue.serverTimestamp(),
            "authProvider": "email",
          });

          // Sign out to prevent auto-login
          await authService.value.signOut();

          _showSnackbar(LocalizationHelper.getLocalizedText(context, 'registrationSuccess'));
          _clearForm();
        } else {
          // Email not verified, delete the account
          debugPrint('❌ Email not verified, deleting account...');
          await user.delete();
          _showSnackbar(LocalizationHelper.getLocalizedText(context, 'emailNotVerified'));
        }
      }
    } on FirebaseAuthException catch (e) {
      await DialogHelper.hideLoadingDialog(context);

      String errorMessage = "Đăng ký thất bại";
      switch (e.code) {
        case 'weak-password':
          errorMessage = "Mật khẩu quá yếu!";
          break;
        case 'email-already-in-use':
          errorMessage = "Email đã được sử dụng!";
          break;
        case 'invalid-email':
          errorMessage = "Email không hợp lệ!";
          break;
        default:
          errorMessage = "Lỗi đăng ký: ${e.message}";
      }

      if (mounted) {
        _showSnackbar(errorMessage);
      }
    }
  }

  Future<void> _registerWithPhone(String phone, String password, String name) async {
    try {
      String formattedPhone = _formatPhoneNumber(phone);
      debugPrint('🔄 Creating account for phone: $formattedPhone');

      // Check if phone already exists (check both fields and both formats)
      final users = FirebaseFirestore.instance.collection("users");
      final local09 = PhoneUtils.toDisplay09(formattedPhone);
      QuerySnapshot q1 = await users.where("phone", isEqualTo: formattedPhone).limit(1).get();
      QuerySnapshot q2 = await users.where("phoneNumber", isEqualTo: formattedPhone).limit(1).get();
      QuerySnapshot q3 = await users.where("phone", isEqualTo: local09).limit(1).get();
      QuerySnapshot q4 = await users.where("phoneNumber", isEqualTo: local09).limit(1).get();

      if (q1.docs.isNotEmpty || q2.docs.isNotEmpty || q3.docs.isNotEmpty || q4.docs.isNotEmpty) {
        await DialogHelper.hideLoadingDialog(context);
        if (mounted) {
          _showSnackbar("Số điện thoại đã được sử dụng!");
        }
        return;
      }

      await DialogHelper.hideLoadingDialog(context);

      if (!mounted) return;

      // Navigate to OTP verification with registration data
      bool otpVerified = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => OtpVerificationPage(
            phoneNumber: formattedPhone,
            isRegistration: true,
            registrationData: {
              'phone': formattedPhone,
              'password': password,
              'name': name,
            },
          ),
        ),
      ) ?? false;

      if (otpVerified && mounted) {
        _showSnackbar("Đăng ký thành công! Vui lòng đăng nhập.");
        _clearForm();
      }
    } catch (e) {
      await DialogHelper.hideLoadingDialog(context);
      if (mounted) {
        _showSnackbar("${LocalizationHelper.getLocalizedText(context, 'phoneRegistrationError')}: $e");
      }
    }
  }

  void _signUpWithGoogle() async {
    DialogHelper.showLoadingDialog(context, message: "Đang đăng ký với Google...");

    try {
      UserCredential? userCredential = await authService.value.signInWithGoogle();

      if (userCredential?.user != null && mounted) {
        // Check if user already exists in our system
        User user = userCredential!.user!;
        QuerySnapshot userQuery = await FirebaseFirestore.instance
            .collection("users")
            .where("email", isEqualTo: user.email)
            .get();

        await DialogHelper.hideLoadingDialog(context);

        if (userQuery.docs.isNotEmpty) {
          // User already exists - this is registration, not login
          _showSnackbar(LocalizationHelper.getLocalizedText(context, 'accountExistsPleaseLogin'));
          // Sign out the user since they should login instead
          await authService.value.signOut();
          return;
        }

        // Create new user in our system
        await _createSocialUser(user, 'google');
        _showSnackbar("Đăng ký thành công với Google!");
        _clearForm();
      } else {
        // User cancelled or authentication failed
        await DialogHelper.hideLoadingDialog(context);
        if (mounted) {
          debugPrint('Google registration cancelled or no credential returned');
        }
      }
    } catch (e) {
      // Always ensure loading dialog is hidden first
      await DialogHelper.hideLoadingDialog(context);
      
      if (mounted) {
        debugPrint('Google Sign Up Error: $e');
        
        // Check if user cancelled the registration
        if (e.toString().contains('sign_in_canceled') || 
            e.toString().contains('CANCELLED') ||
            e.toString().contains('popup_closed') ||
            e.toString().contains('cancelled')) {
          debugPrint('Google registration was cancelled by user');
          return; // Don't show error for user cancellation
        }
        
        String errorMessage = "Đăng ký Google thất bại";
        
        // Handle specific error cases
        if (e.toString().contains('ApiException: 10')) {
          // DEVELOPER_ERROR - Configuration issue
          errorMessage = "Lỗi cấu hình Google Sign-In. Vui lòng sử dụng email thường hoặc thử trên thiết bị thật!";
        } else if (e.toString().contains('sign_in_failed') && 
                   e.toString().contains('ApiException')) {
          // Other API exceptions
          errorMessage = "Google Sign-In không khả dụng trên emulator. Vui lòng sử dụng email thường!";
        } else if (e.toString().contains('network')) {
          errorMessage = "Lỗi kết nối mạng. Vui lòng thử lại!";
        } else {
          errorMessage = "Đăng ký Google thất bại. Vui lòng thử lại với email thường!";
        }
        
        _showSnackbar(errorMessage);
      }
    } finally {
      // Additional safety net to ensure dialog is always hidden
      try {
        await DialogHelper.hideLoadingDialog(context);
      } catch (e) {
        debugPrint('Error hiding dialog in finally block: $e');
      }
    }
  }

  void _signUpWithFacebook() async {
    DialogHelper.showLoadingDialog(context, message: "Đang đăng ký với Facebook...");

    try {
      UserCredential? userCredential = await authService.value.signInWithFacebook();

      if (userCredential?.user != null && mounted) {
        // Check if user already exists in our system
        User user = userCredential!.user!;
        QuerySnapshot userQuery = await FirebaseFirestore.instance
            .collection("users")
            .where("email", isEqualTo: user.email)
            .get();

        await DialogHelper.hideLoadingDialog(context);

        if (userQuery.docs.isNotEmpty) {
          // User already exists - this is registration, not login
          _showSnackbar(LocalizationHelper.getLocalizedText(context, 'accountExistsPleaseLogin'));
          // Sign out the user since they should login instead
          await authService.value.signOut();
          return;
        }

        // Create new user in our system
        await _createSocialUser(user, 'facebook');
        _showSnackbar("Đăng ký thành công với Facebook!");
        _clearForm();
      } else {
        // User cancelled or authentication failed
        await DialogHelper.hideLoadingDialog(context);
        if (mounted) {
          debugPrint('Facebook registration cancelled or no credential returned');
        }
      }
    } catch (e) {
      // Always ensure loading dialog is hidden first
      await DialogHelper.hideLoadingDialog(context);
      
      if (mounted) {
        debugPrint('Facebook Sign Up Error: $e');
        
        String errorMessage = "Đăng ký Facebook thất bại";
        
        // Check if user cancelled the registration
        if (e.toString().contains('sign_in_canceled') || 
            e.toString().contains('CANCELLED') ||
            e.toString().contains('popup_closed') ||
            e.toString().contains('cancelled')) {
          debugPrint('Facebook registration was cancelled by user');
          return; // Don't show error for user cancellation
        } else if (e.toString().contains('MissingPluginException')) {
          errorMessage = "Facebook đăng ký chưa được cấu hình đầy đủ. Vui lòng sử dụng Google hoặc Email!";
        } else if (e.toString().contains('network')) {
          errorMessage = "Lỗi kết nối mạng. Vui lòng thử lại!";
        } else if (e.toString().contains('WebView')) {
          errorMessage = "Lỗi WebView Facebook. Vui lòng thử lại hoặc sử dụng Email!";
        } else if (e.toString().contains('Facebook login failed')) {
          errorMessage = "Facebook không thể đăng ký. Vui lòng thử lại!";
        }
        
        _showSnackbar(errorMessage);
      }
    } finally {
      // Additional safety net to ensure dialog is always hidden
      try {
        await DialogHelper.hideLoadingDialog(context);
      } catch (e) {
        debugPrint('Error hiding dialog in finally block: $e');
      }
    }
  }

  Future<void> _createSocialUser(User user, String provider) async {
    try {
      String? fullName = user.displayName ?? "";
      
      if (fullName.isEmpty) {
        fullName = "User";
      }

      // Split full name into first and last name
      List<String> nameParts = fullName.split(' ');
      String firstName = nameParts.isNotEmpty ? nameParts.first : "User";
      String lastName = nameParts.length > 1 ? nameParts.skip(1).join(' ') : "";

      // Create user data directly in Firestore
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'uid': user.uid,
        'email': user.email,
        'displayName': user.displayName,
        'firstName': firstName,
        'lastName': lastName,
        'photoURL': user.photoURL ?? 'https://i.pinimg.com/736x/8b/16/7a/8b167af653c2399dd93b952a48740620.jpg',
        'phoneNumber': user.phoneNumber,
        'provider': provider,
        'role': 'user',
        'address': null,
        'dateOfBirth': null,
        'gender': null,
        'bio': null,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
    } catch (e) {
      debugPrint('Error creating social user: $e');
      await authService.value.signOut();
      throw Exception("Có lỗi xảy ra khi tạo tài khoản. Vui lòng thử lại!");
    }
  }

  void _clearForm() {
    _accountController.clear();
    _passwordController.clear();
    _confirmPasswordController.clear();
    _nameController.clear();
  }

  void _showSnackbar(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Colors.pink.shade300,
        content: Center(child: Text(message)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: secondaryColor,
      body: SafeArea(
        child: Stack(
          children: [
            // Background decorative circles
            Positioned(
              top: 10,
              left: 230,
              child: Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: Colors.pink.shade300,
                  shape: BoxShape.circle,
                ),
              ),
            ),
            Positioned(
              top: 20,
              left: 280,
              child: Container(
                width: 150,
                height: 150,
                decoration: BoxDecoration(
                  color: Colors.pink.shade300,
                  shape: BoxShape.circle,
                ),
              ),
            ),
            Positioned(
              bottom: 100,
              right: 280,
              child: Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: Colors.pink.shade300,
                  shape: BoxShape.circle,
                ),
              ),
            ),
            Positioned(
              bottom: 20,
              right: 320,
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: Colors.pink.shade300,
                  shape: BoxShape.circle,
                ),
              ),
            ),
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 25),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Register Image
                      FadeTransition(
                        opacity: _fadeAnimation,
                        child: SlideTransition(
                          position: _slideAnimation,
                          child: Center(
                            child: Container(
                              width: 180,
                              height: 180,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.pink.shade300.withOpacity(0.3),
                                    spreadRadius: 5,
                                    blurRadius: 15,
                                    offset: const Offset(0, 5),
                                  ),
                                ],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(20),
                                child: Image.asset(
                                  "assets/images/loginImage.png",
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        "Đăng ký tài khoản",
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 30),
                      MyTextField(
                        hintText: LocalizationHelper.getLocalizedText(context, 'fullNameHint'),
                        icon: const Icon(Icons.person_outline),
                        controller: _nameController,
                        obsecureText: false,
                      ),
                      const SizedBox(height: 10),
                      MyTextField(
                        hintText: LocalizationHelper.getLocalizedText(context, 'accountHint'),
                        icon: const Icon(Icons.account_circle_outlined),
                        controller: _accountController,
                        obsecureText: false,
                      ),
                      const SizedBox(height: 10),
                      MyTextField(
                        hintText: LocalizationHelper.getLocalizedText(context, 'passwordHint'),
                        icon: const Icon(Icons.lock_outline),
                        controller: _passwordController,
                        obsecureText: true,
                      ),
                      const SizedBox(height: 10),
                      MyTextField(
                        hintText: LocalizationHelper.getLocalizedText(context, 'confirmPasswordHint'),
                        icon: const Icon(Icons.lock_outline),
                        controller: _confirmPasswordController,
                        obsecureText: true,
                      ),
                      const SizedBox(height: 25),
                      MyButton(
                        text: LocalizationHelper.getLocalizedText(context, 'registerButton'),
                        onPressed: () => _register(context),
                      ),
                      const SizedBox(height: 15),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(LocalizationHelper.getLocalizedText(context, 'alreadyHaveAccount')),
                          GestureDetector(
                            onTap: widget.onTap,
                            child: Text(
                              LocalizationHelper.getLocalizedText(context, 'loginNow'),
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.pink.shade300,
                              ),
                            ),
                          )
                        ],
                      ),
                      const SizedBox(height: 20),
                      Center(
                        child: Text(
                          LocalizationHelper.getLocalizedText(context, 'orRegisterWith'),
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(height: 15),
                      // Social registration buttons
                      Row(
                        children: [
                          // Google registration
                          Expanded(
                            child: Container(
                              height: 50,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.grey.shade300),
                              ),
                              child: InkWell(
                                onTap: _signUpWithGoogle,
                                borderRadius: BorderRadius.circular(12),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: Image.asset("assets/images/google.png"),
                                    ),
                                    const SizedBox(width: 10),
                                    const Text(
                                      "Google",
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 15),
                          // Facebook registration
                          Expanded(
                            child: Container(
                              height: 50,
                              decoration: BoxDecoration(
                                color: const Color(0xFF1877F2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: InkWell(
                                onTap: _signUpWithFacebook,
                                borderRadius: BorderRadius.circular(12),
                                child: const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.facebook,
                                      color: Colors.white,
                                      size: 24,
                                    ),
                                    SizedBox(width: 10),
                                    Text(
                                      "Facebook",
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}