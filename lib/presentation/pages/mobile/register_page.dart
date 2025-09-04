import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:pet_shop/auth/auth_service.dart';
import 'package:pet_shop/presentation/widgets/components/my_button.dart';
import 'package:pet_shop/presentation/widgets/components/my_textfield.dart';
import 'package:pet_shop/core/constants/app_constants.dart';
import 'package:pet_shop/presentation/pages/mobile/VerifyEmailPage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pet_shop/presentation/pages/mobile/login_page.dart';
import 'package:pet_shop/core/utils/dialog_helper.dart';
import 'package:flutter/foundation.dart';

class RegisterPage extends StatefulWidget {
  final void Function()? onTap;

  const RegisterPage({super.key, required this.onTap});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final TextEditingController _emailController = TextEditingController();

  final TextEditingController _passwordController = TextEditingController();

  final TextEditingController _confirmPasswordController =
      TextEditingController();

  void _dangKy(BuildContext context) async {
    String email = _emailController.text.trim();
    String password = _passwordController.text.trim();
    String confirmPassword = _confirmPasswordController.text.trim();
    
    if (email.isEmpty || password.isEmpty || confirmPassword.isEmpty) {
      _showSnackbar("Vui lòng nhập đầy đủ thông tin!");
      return;
    }
    if (password.length < 6) {
      _showSnackbar("Mật khẩu phải có ít nhất 6 ký tự!");
      return;
    }
    if (password != confirmPassword) {
      _showSnackbar("Mật khẩu xác nhận không khớp!");
      return;
    }

    // Show loading dialog
    DialogHelper.showLoadingDialog(context, message: "Đang tạo tài khoản...");

    try {
      debugPrint('🔄 Creating account for: $email');
      
      UserCredential userCredential = await authService.value
          .createAccount(email: email, password: password);
      User? user = userCredential.user;

      if (user != null) {
        debugPrint('✅ Account created, sending verification email...');
        
        await user.sendEmailVerification();
        
        // Hide loading dialog before showing verification page
        await DialogHelper.hideLoadingDialog(context);
        
        if (!mounted) return;
        
        _showSnackbar("Email xác nhận đã gửi! Vui lòng kiểm tra email.");
        
        // Navigate to verification page
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => VerifyEmailPage(email: email),
          ),
        );
        
        if (!mounted) return;
        
        // Check verification status after returning from verification page
        await user.reload();
        User? refreshedUser = FirebaseAuth.instance.currentUser;
        
        if (refreshedUser != null && refreshedUser.emailVerified) {
          debugPrint('✅ Email verified, creating user document...');
          
          // Create user document in Firestore
          await FirebaseFirestore.instance.collection("users").doc(refreshedUser.uid).set({
            "email": refreshedUser.email,
            "role": "user",
            "displayName": refreshedUser.displayName ?? "User",
            "imageUrl": refreshedUser.photoURL ?? "https://i.pinimg.com/736x/8b/16/7a/8b167af653c2399dd93b952a48740620.jpg",
            "address": [],
            "phone": "",
            "createdAt": FieldValue.serverTimestamp(),
          });
          
          // Sign out the user to prevent auto-login
          await authService.value.signOut();
          
          debugPrint('✅ User document created, signed out user');
          
          if (!mounted) return;
          
          // Clear form
          _emailController.clear();
          _passwordController.clear();
          _confirmPasswordController.clear();
          
          // Show success message and navigate to login
          _showSnackbar("Đăng ký thành công! Vui lòng đăng nhập.");
          
          // Navigate back to login page
          widget.onTap?.call();
          
        } else {
          debugPrint('❌ Email not verified, deleting account...');
          
          // Email not verified, delete the account
          if (refreshedUser != null) {
            await refreshedUser.delete();
          }
          
          if (!mounted) return;
          
          _emailController.clear();
          _passwordController.clear();
          _confirmPasswordController.clear();
          _showSnackbar("Xác nhận email không thành công. Đăng ký bị hủy.");
        }
      }
    } on FirebaseAuthException catch (e) {
      await DialogHelper.hideLoadingDialog(context);
      
      debugPrint('❌ Registration error: ${e.code} - ${e.message}');
      
      if (!mounted) return;
      
      if (e.code == 'email-already-in-use') {
        _showSnackbar("Tài khoản đã tồn tại");
      } else {
        _showSnackbar("Đăng ký thất bại: ${e.message}");
      }
      
      _emailController.clear();
      _passwordController.clear();
      _confirmPasswordController.clear();
    } catch (e) {
      await DialogHelper.hideLoadingDialog(context);
      
      debugPrint('❌ Unexpected error: $e');
      
      if (!mounted) return;
      
      _showSnackbar("Lỗi không xác định: $e");
      _emailController.clear();
      _passwordController.clear();
      _confirmPasswordController.clear();
    }
  }

  void _showSnackbar(String message) {
    if (!mounted) return; // Kiểm tra mounted trước khi sử dụng context
    
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
            Positioned(
                top: 10,
                left: 230,
                child: Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                      color: Colors.pink.shade300, shape: BoxShape.circle),
                )),
            Positioned(
                top: 20,
                left: 280,
                child: Container(
                  width: 150,
                  height: 150,
                  decoration: BoxDecoration(
                      color: Colors.pink.shade300, shape: BoxShape.circle),
                )),
            Positioned(
                bottom: 100,
                right: 280,
                child: Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                      color: Colors.pink.shade300, shape: BoxShape.circle),
                )),
            Positioned(
                bottom: 20,
                right: 320,
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                      color: Colors.pink.shade300, shape: BoxShape.circle),
                )),
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 25),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Đăng ký tài khoản",
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(
                      height: 50,
                    ),
                    MyTextField(
                      hintText: "Email",
                      icon: const Icon(Icons.email_outlined),
                      controller: _emailController,
                      obsecureText: false,
                    ),
                    const SizedBox(
                      height: 10,
                    ),
                    MyTextField(
                      hintText: "Password",
                      icon: const Icon(Icons.lock_outline),
                      controller: _passwordController,
                      obsecureText: true,
                    ),
                    const SizedBox(
                      height: 25,
                    ),
                    MyTextField(
                      hintText: "Xác nhận mật khẩu",
                      icon: const Icon(Icons.lock_outline),
                      controller: _confirmPasswordController,
                      obsecureText: true,
                    ),
                    const SizedBox(
                      height: 25,
                    ),
                    MyButton(
                        text: 'Đăng ký', onPressed: () => _dangKy(context)),
                    const SizedBox(
                      height: 25,
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text("Bạn đã có tài khoản? "),
                        GestureDetector(
                          onTap: widget.onTap,
                          child: Text(
                            "Đăng nhập ngay",
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.pink.shade300),
                          ),
                        )
                      ],
                    ),
                  ],
                ),
              ),
            )
          ],
        ),
      ),
    );
  }
}
