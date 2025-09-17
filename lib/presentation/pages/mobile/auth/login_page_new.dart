import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:pet_shop/auth/auth_service.dart';
import 'package:pet_shop/presentation/widgets/components/my_button.dart';
import 'package:pet_shop/presentation/widgets/components/my_textfield.dart';
import 'package:pet_shop/core/constants/app_constants.dart';
import 'package:pet_shop/core/utils/dialog_helper.dart';
import 'package:pet_shop/presentation/pages/web/screen_admin/home/home_page_admin.dart';
import 'package:pet_shop/presentation/pages/mobile/bottom_navigator.dart';
import 'package:pet_shop/presentation/pages/mobile/auth/forgot_password_page.dart';

class LoginPageNew extends StatefulWidget {
  final void Function()? onTap;

  const LoginPageNew({super.key, required this.onTap});

  @override
  State<LoginPageNew> createState() => _LoginPageNewState();
}

class _LoginPageNewState extends State<LoginPageNew>
    with TickerProviderStateMixin {
  final TextEditingController _accountController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
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
    _animationController.dispose();
    super.dispose();
  }

  // Check if input is email or phone
  bool _isEmail(String input) {
    return RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(input);
  }

  bool _isPhoneNumber(String input) {
    // Remove spaces and special characters
    String cleaned = input.replaceAll(RegExp(r'[\s\-\(\)\+]'), '');
    // Check Vietnamese phone patterns
    return RegExp(r'^(\+84|84|0)[0-9]{8,9}$').hasMatch(cleaned);
  }

  String _formatPhoneNumber(String phone) {
    String cleaned = phone.replaceAll(RegExp(r'[\s\-\(\)]'), '');
    if (cleaned.startsWith('+84')) {
      return cleaned;
    } else if (cleaned.startsWith('84')) {
      return '+$cleaned';
    } else if (cleaned.startsWith('0')) {
      return '+84${cleaned.substring(1)}';
    } else {
      return '+84$cleaned';
    }
  }

  void _login(BuildContext context) async {
    String account = _accountController.text.trim();
    String password = _passwordController.text.trim();

    if (account.isEmpty || password.isEmpty) {
      _showSnackbar("Chưa điền đầy đủ thông tin");
      return;
    }

    DialogHelper.showLoadingDialog(context, message: "Đang đăng nhập...");

    try {
      UserCredential userCredential;

      if (_isEmail(account)) {
        // Login with email
        userCredential = await authService.value.signIn(
          email: account,
          password: password,
        );
      } else if (_isPhoneNumber(account)) {
        // For phone login, we need to find the user by phone first
        String formattedPhone = _formatPhoneNumber(account);

        // Query Firestore to find user with this phone number
        QuerySnapshot phoneQuery = await FirebaseFirestore.instance
            .collection("users")
            .where("phone", isEqualTo: formattedPhone)
            .get();

        if (phoneQuery.docs.isEmpty) {
          await DialogHelper.hideLoadingDialog(context);
          _showSnackbar("Số điện thoại chưa được đăng ký!");
          return;
        }

        // Get the email associated with this phone number
        String userEmail = phoneQuery.docs.first['email'];

        userCredential = await authService.value.signIn(
          email: userEmail,
          password: password,
        );
      } else {
        await DialogHelper.hideLoadingDialog(context);
        _showSnackbar("Định dạng tài khoản không hợp lệ!");
        return;
      }

      debugPrint(
          '🔐 Firebase signIn completed, user: ${userCredential.user?.uid}');

      if (userCredential.user != null) {
        DocumentSnapshot userDoc = await FirebaseFirestore.instance
            .collection("users")
            .doc(userCredential.user!.uid)
            .get();

        debugPrint('📄 User document exists: ${userDoc.exists}');

        if (userDoc.exists) {
          String role = userDoc['role'];
          debugPrint('👤 User role: $role');

          await DialogHelper.hideLoadingDialog(context);

          if (kIsWeb) {
            if (role == 'admin') {
              if (mounted) {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const HomePageAdmin()),
                );
              }
            } else {
              if (mounted) {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const BottomNavigator()),
                );
              }
            }
          } else {
            if (mounted) {
              debugPrint(
                  '✅ Login successful, letting authStateChanges handle navigation');
            }
          }
        }
      }
    } on FirebaseAuthException catch (e) {
      await DialogHelper.hideLoadingDialog(context);

      String errorMessage = "Đăng nhập thất bại";
      switch (e.code) {
        case 'user-not-found':
          errorMessage = "Tài khoản không tồn tại!";
          break;
        case 'wrong-password':
          errorMessage = "Mật khẩu không chính xác!";
          break;
        case 'invalid-email':
          errorMessage = "Email không hợp lệ!";
          break;
        case 'user-disabled':
          errorMessage = "Tài khoản đã bị vô hiệu hóa!";
          break;
        default:
          errorMessage = "Lỗi đăng nhập: ${e.message}";
      }

      if (mounted) {
        _showSnackbar(errorMessage);
      }
    } catch (e) {
      await DialogHelper.hideLoadingDialog(context);

      if (mounted) {
        _showSnackbar("Lỗi không xác định: $e");
      }
    }
  }

  void _signInWithGoogle() async {
    DialogHelper.showLoadingDialog(context,
        message: "Đang đăng nhập với Google...");

    try {
      UserCredential? userCredential =
          await authService.value.signInWithGoogle();

      if (userCredential?.user != null && mounted) {
        await _handleSuccessfulLogin(userCredential!.user!);
      } else {
        // User cancelled or no credential returned
        await DialogHelper.hideLoadingDialog(context);
      }
    } catch (e) {
      await DialogHelper.hideLoadingDialog(context);
      if (mounted) {
        // Check if user cancelled the login
        if (e.toString().contains('sign_in_canceled') || 
            e.toString().contains('CANCELLED') ||
            e.toString().contains('popup_closed') ||
            e.toString().contains('cancelled')) {
          // Don't show error for user cancellation
          return;
        }
        _showSnackbar("Đăng nhập Google thất bại: ${e.toString()}");
      }
    }
  }

  void _signInWithFacebook() async {
    DialogHelper.showLoadingDialog(context,
        message: "Đang đăng nhập với Facebook...");

    try {
      UserCredential? userCredential =
          await authService.value.signInWithFacebook();

      if (userCredential?.user != null && mounted) {
        await _handleSuccessfulLogin(userCredential!.user!);
      } else {
        // User cancelled or no credential returned
        await DialogHelper.hideLoadingDialog(context);
      }
    } catch (e) {
      await DialogHelper.hideLoadingDialog(context);
      if (mounted) {
        String errorMessage = "Đăng nhập Facebook thất bại";
        
        // Check if user cancelled the login
        if (e.toString().contains('sign_in_canceled') || 
            e.toString().contains('CANCELLED') ||
            e.toString().contains('popup_closed') ||
            e.toString().contains('cancelled')) {
          // Don't show error for user cancellation
          return;
        } else if (e.toString().contains('MissingPluginException')) {
          errorMessage =
              "Facebook đăng nhập chưa được cấu hình đầy đủ. Vui lòng sử dụng Google hoặc Email!";
        } else if (e.toString().contains('network')) {
          errorMessage = "Lỗi kết nối mạng. Vui lòng thử lại!";
        }
        _showSnackbar(errorMessage);
      }
    }
  }

  Future<void> _handleSuccessfulLogin(User user) async {
    try {
      // Check if user document exists
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection("users")
          .doc(user.uid)
          .get();

      String role = "user";
      if (userDoc.exists) {
        Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>;
        role = userData['role'] ?? 'user';
      }

      await DialogHelper.hideLoadingDialog(context);

      if (kIsWeb) {
        if (role == 'admin') {
          if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const HomePageAdmin()),
            );
          }
        } else {
          if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const BottomNavigator()),
            );
          }
        }
      } else {
        if (mounted) {
          debugPrint(
              '✅ Social login successful, letting authStateChanges handle navigation');
        }
      }
    } catch (e) {
      await DialogHelper.hideLoadingDialog(context);
      if (mounted) {
        _showSnackbar("Lỗi xử lý đăng nhập: $e");
      }
    }
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
            // Positioned(
            //   bottom: 80,
            //   right: 280,
            //   child: Container(
            //     width: 30,
            //     height: 30,
            //     decoration: BoxDecoration(
            //       color: Colors.pink.shade300,
            //       shape: BoxShape.circle,
            //     ),
            //   ),
            // ),
            // Positioned(
            //   bottom: 20,
            //   right: 320,
            //   child: Container(
            //     width: 80,
            //     height: 80,
            //     decoration: BoxDecoration(
            //       color: Colors.pink.shade300,
            //       shape: BoxShape.circle,
            //     ),
            //   ),
            // ),
            Center(
              child: Column(
                children: [
                  // Login Image
                  FadeTransition(
                    opacity: _fadeAnimation,
                    child: SlideTransition(
                      position: _slideAnimation,
                      child: Center(
                        child: Container(
                          width: MediaQuery.of(context).size.width,
                          height: 300,
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
                  const SizedBox(height: 30),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 25),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Login",
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 5),
                        const Text(
                          "Vui lòng đăng nhập để tiếp tục",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w300,
                          ),
                        ),
                        const SizedBox(height: 50),
                        MyTextField(
                          hintText: "Tài khoản (Email hoặc SĐT)",
                          icon: const Icon(Icons.account_circle_outlined),
                          controller: _accountController,
                          obsecureText: false,
                        ),
                        const SizedBox(height: 10),
                        MyTextField(
                          hintText: "Mật khẩu",
                          icon: const Icon(Icons.lock_outline),
                          controller: _passwordController,
                          obsecureText: true,
                        ),
                        const SizedBox(height: 5),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            GestureDetector(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => const ForgotPasswordPage(),
                                  ),
                                );
                              },
                              child: const Text(
                                "Quên mật khẩu?",
                                style: TextStyle(
                                  color: Colors.red,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 25),
                        MyButton(
                          text: 'ĐĂNG NHẬP',
                          onPressed: () => _login(context),
                        ),
                        const SizedBox(height: 15),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text("Not a member? "),
                            GestureDetector(
                              onTap: widget.onTap,
                              child: Text(
                                "Đăng ký ngay",
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.pink.shade300,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        const Center(
                          child: Text(
                            "Hoặc đăng nhập bằng",
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(height: 15),
                        // Social login buttons
                        Row(
                          children: [
                            // Google login
                            Expanded(
                              child: Container(
                                height: 50,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  border:
                                      Border.all(color: Colors.grey.shade300),
                                ),
                                child: InkWell(
                                  onTap: _signInWithGoogle,
                                  borderRadius: BorderRadius.circular(12),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      SizedBox(
                                        width: 24,
                                        height: 24,
                                        child: Image.asset(
                                            "assets/images/google.png"),
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
                            // Facebook login
                            Expanded(
                              child: Container(
                                height: 50,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1877F2),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: InkWell(
                                  onTap: _signInWithFacebook,
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
                      ],
                    ),
                  )
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
