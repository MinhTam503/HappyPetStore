import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import 'package:flutter/material.dart';
import 'package:pet_shop/auth/auth_service.dart';
import 'package:pet_shop/components/my_button.dart';
import 'package:pet_shop/components/my_textfield.dart';
import 'package:pet_shop/utils/contants.dart';
import 'package:pet_shop/view/web/screen_admin/home_page_admin.dart';

import '../../bottom_navigator.dart';

class LoginAdminPage extends StatefulWidget {
  const LoginAdminPage({super.key});

  @override
  State<LoginAdminPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginAdminPage> {
  final TextEditingController _emailController = TextEditingController();

  final TextEditingController _passwordController = TextEditingController();

  void showLoadingDialog(BuildContext context) {
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black54,
      builder: (context) {
        return const Dialog(
          elevation: 0,
          backgroundColor: Colors.transparent,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(
                  color: Colors.pink,
                ),
                SizedBox(height: 15),
                Text(
                  "Đang đăng nhập...",
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void Login(BuildContext context) async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Chưa điền đầy đủ thông tin")),
      );
      return;
    }

    showLoadingDialog(context);

    try {
      UserCredential userCredential = await authService.value.signIn(
        email: _emailController.text,
        password: _passwordController.text,
      );

      // Đảm bảo loading dialog được tắt
      if (mounted) Navigator.pop(context);

      if (userCredential.user != null) {
        DocumentSnapshot userDoc = await FirebaseFirestore.instance
            .collection("users")
            .doc(userCredential.user!.uid)
            .get();

        if (userDoc.exists) {
          String role = userDoc['role'];
          if (kIsWeb) {
            // Nếu đang trên web, mở trang admin
            if (role == 'admin') {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const HomePageAdmin()),
              );
            } else {
              // Nếu không phải admin, mở trang người dùng
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => const BottomNavigator(),
                ),
              );
            }
          } else {
            // Nếu đang trên di động, mở trang người dùng
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => const BottomNavigator(),
              ),
            );
          }
        } else {
          // Nếu không tìm thấy tài liệu người dùng
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Tài khoản không tồn tại")),
          );
        }
      }
    } on FirebaseAuthException catch (e) {
      // Đảm bảo loading dialog được tắt
      if (mounted) Navigator.pop(context);
      if (e.message ==
          "The supplied auth credential is incorrect, malformed or has expired.") {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Thông tin không chính xác"),
          ),
        );
      }
    } catch (e) {
      // Đảm bảo loading dialog được tắt
      if (mounted) Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Lỗi không xác định: $e")),
      );
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

    // Kiểm tra email có tồn tại trên Firestore không
    final querySnapshot = await FirebaseFirestore.instance
        .collection("users")
        .where("email", isEqualTo: email)
        .get();

    if (querySnapshot.docs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Email không tồn tại trong hệ thống!")),
      );
      return;
    }

    // Gửi email reset mật khẩu
    try {
      await authService.value.resetPassword(email: email);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Đã gửi email đặt lại mật khẩu!")),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Lỗi khi gửi email: $e")),
      );
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
              height: MediaQuery.of(context).size.height * 0.4,
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
              bottom: 120,
              right: 180,
              child: Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                    color: Colors.pink.shade300, shape: BoxShape.circle),
              ),
            ),
            Positioned(
              bottom: 210,
              right: 200,
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                    color: Colors.pink.shade300, shape: BoxShape.circle),
              ),
            ),
            Positioned(
              bottom: 120,
              left: 180,
              child: Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                    color: Colors.pink.shade300, shape: BoxShape.circle),
              ),
            ),
            Positioned(
              bottom: 210,
              left: 200,
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                    color: Colors.pink.shade300, shape: BoxShape.circle),
              ),
            ),
            Container(
              height: 800,
              padding: const EdgeInsets.only(left: 450, right: 450, top: 320),
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 25),
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: EdgeInsets.all(20),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // const SizedBox(height: 250),
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
                        height: 32,
                      ),
                      Center(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.pink.shade300,
                              foregroundColor: Colors.white),
                          onPressed: () => Login(context),
                          child: const Text("ĐĂNG NHẬP"),
                        ),
                      ),
                      const SizedBox(
                        height: 15,
                      ),
                      const SizedBox(
                        height: 10,
                      ),
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
