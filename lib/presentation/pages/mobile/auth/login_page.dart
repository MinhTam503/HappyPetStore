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

import '../bottom_navigator.dart';

class LoginPage extends StatefulWidget {
  final void Function()? onTap;

  const LoginPage({super.key, required this.onTap});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void Login(BuildContext context) async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Chưa điền đầy đủ thông tin")),
      );
      return;
    }

    DialogHelper.showLoadingDialog(context, message: "Đang đăng nhập...");

    try {
      UserCredential userCredential = await authService.value.signIn(
        email: _emailController.text,
        password: _passwordController.text,
      );

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

          // Đóng dialog ngay lập tức bất kể web hay mobile
          await DialogHelper.hideLoadingDialog(context);

          debugPrint('✅ Dialog closed successfully');

          if (kIsWeb) {
            // Nếu đang trên web, navigate manually
            if (role == 'admin') {
              if (mounted) {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const HomePageAdmin()),
                );
              }
            } else {
              // Nếu không phải admin, mở trang người dùng
              if (mounted) {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const BottomNavigator(),
                  ),
                );
              }
            }
          } else {
            // Nếu đang trên di động, để authStateChanges handle navigation
            if (mounted) {
              debugPrint(
                  '✅ Login successful, dialog closed, letting authStateChanges handle navigation');
              debugPrint(
                  '🔄 Current user: ${authService.value.currentUser?.uid}');

              // Thêm một delay nhỏ để đảm bảo auth state được persist
              await Future.delayed(const Duration(milliseconds: 100));

              // Double check user is still authenticated
              if (authService.value.currentUser != null) {
                debugPrint('🔒 User still authenticated after delay');
              } else {
                debugPrint(
                    '⚠️ User not authenticated after delay - this is the problem!');
              }
            }
          }
        } else {
          // Đóng loading dialog trước khi hiện thông báo lỗi
          await DialogHelper.hideLoadingDialog(context);

          // Nếu không tìm thấy tài liệu người dùng
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Tài khoản không tồn tại")),
            );
          }
        }
      }
    } on FirebaseAuthException catch (e) {
      // Đảm bảo loading dialog được tắt
      await DialogHelper.hideLoadingDialog(context);

      if (mounted &&
          e.message ==
              "The supplied auth credential is incorrect, malformed or has expired.") {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Thông tin không chính xác"),
          ),
        );
      }
    } catch (e) {
      // Đảm bảo loading dialog được tắt
      await DialogHelper.hideLoadingDialog(context);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Lỗi không xác định: $e")),
        );
      }
    }
  }

  void sendEmailRestPassWord() async {
    final email = _emailController.text.trim();

    // Kiểm tra rỗng
    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Vui lòng nhập email!")),
      );
      return;
    }

    // Kiểm tra định dạng email bằng biểu thức chính quy
    final emailRegex = RegExp(r"^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$");
    if (!emailRegex.hasMatch(email)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Email không đúng định dạng!")),
      );
      return;
    }

    // Show loading dialog
    DialogHelper.showLoadingDialog(context, message: "Đang gửi email...");

    try {
      debugPrint('🔄 Checking if email exists in Firestore: $email');

      // Kiểm tra email có tồn tại trên Firestore không
      final querySnapshot = await FirebaseFirestore.instance
          .collection("users")
          .where("email", isEqualTo: email)
          .get();

      debugPrint(
          '📧 Email query result: ${querySnapshot.docs.length} documents found');

      if (querySnapshot.docs.isEmpty) {
        await DialogHelper.hideLoadingDialog(context);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text("Email không tồn tại trong hệ thống!")),
          );
        }
        return;
      }

      debugPrint('✅ Email exists, sending password reset...');

      // Gửi email reset mật khẩu
      await authService.value.resetPassword(email: email);

      await DialogHelper.hideLoadingDialog(context);

      debugPrint('✅ Password reset email sent successfully');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                "Đã gửi email đặt lại mật khẩu! Vui lòng kiểm tra hộp thư."),
            duration: Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      await DialogHelper.hideLoadingDialog(context);

      debugPrint('❌ Error sending password reset: $e');

      if (mounted) {
        String errorMessage = "Lỗi khi gửi email: ";

        // Handle specific Firebase errors
        if (e.toString().contains('user-not-found')) {
          errorMessage = "Không tìm thấy tài khoản với email này!";
        } else if (e.toString().contains('invalid-email')) {
          errorMessage = "Email không hợp lệ!";
        } else if (e.toString().contains('too-many-requests')) {
          errorMessage = "Quá nhiều yêu cầu! Vui lòng thử lại sau.";
        } else {
          errorMessage += e.toString();
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: secondaryColor,
      resizeToAvoidBottomInset: false,
      body: SafeArea(
        child: Stack(
          children: [
            Container(
              width: MediaQuery.of(context).size.width,
              height: MediaQuery.of(context).size.height * 0.28,
              decoration: const BoxDecoration(
                borderRadius: BorderRadius.only(
                  bottomRight: Radius.circular(10),
                  bottomLeft: Radius.circular(10),
                ),
              ),
              child: const ClipRRect(
                borderRadius: BorderRadius.only(
                  bottomRight: Radius.circular(10),
                  bottomLeft: Radius.circular(10),
                ),
                child: Image(
                  image: AssetImage("assets/images/loginImage.png"),
                  fit: BoxFit.cover, // Để ảnh phủ hết container
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
                    color: Colors.pink.shade300, shape: BoxShape.circle),
              ),
            ),
            Positioned(
              bottom: 20,
              right: 320,
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                    color: Colors.pink.shade300, shape: BoxShape.circle),
              ),
            ),
            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 25),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 100),
                    const Text(
                      "Login",
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(
                      height: 5,
                    ),
                    const Text(
                      "Vui lòng đăng nhập để tiếp tục",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w300,
                      ),
                    ),
                    const SizedBox(
                      height: 50,
                    ),
                    MyTextField(
                      hintText: "Tài khoản",
                      icon: const Icon(Icons.email_outlined),
                      controller: _emailController,
                      obsecureText: false,
                    ),
                    const SizedBox(
                      height: 10,
                    ),
                    MyTextField(
                      hintText: "Mật khẩu",
                      icon: const Icon(Icons.lock_outline),
                      controller: _passwordController,
                      obsecureText: true,
                    ),
                    const SizedBox(
                      height: 5,
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        GestureDetector(
                          onTap: () {
                            debugPrint('🔄 Forgot password tapped');
                            sendEmailRestPassWord();
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
                    const SizedBox(
                      height: 25,
                    ),
                    MyButton(
                        text: 'ĐĂNG NHẬP', onPressed: () => Login(context)),
                    const SizedBox(
                      height: 15,
                    ),
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
                                color: Colors.pink.shade300),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(
                      height: 10,
                    ),
                    // const Center(
                    //   child: Text(
                    //     "Đăng nhập bằng",
                    //     style: TextStyle(
                    //         fontSize: 14, fontWeight: FontWeight.bold),
                    //   ),
                    // ),
                    // const SizedBox(
                    //   height: 10,
                    // ),
                    // Center(
                    //   child: Container(
                    //     width: MediaQuery.of(context).size.width * 0.8,
                    //     height: 45,
                    //     decoration: BoxDecoration(
                    //       color: Colors.pink.shade100,
                    //       borderRadius: BorderRadius.circular(12),
                    //     ),
                    //     child: const Row(
                    //       mainAxisAlignment: MainAxisAlignment.center,
                    //       children: [
                    //         SizedBox(
                    //           width: 30,
                    //           height: 30,
                    //           child: Image(
                    //             image: AssetImage("assets/images/google.png"),
                    //           ),
                    //         ),
                    //         SizedBox(
                    //           width: 10,
                    //         ),
                    //         Text(
                    //           "G O O G L E",
                    //           style: TextStyle(
                    //             fontSize: 18,
                    //             fontWeight: FontWeight.bold,
                    //           ),
                    //         ),
                    //       ],
                    //     ),
                    //   ),
                    // ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
