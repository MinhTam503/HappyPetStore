import 'package:flutter/material.dart';
import 'package:pet_shop/presentation/pages/mobile/auth/login_page_new.dart';
import 'package:pet_shop/presentation/pages/mobile/auth/register_page_new.dart';

class LoginOrRegister extends StatefulWidget {
  const LoginOrRegister({super.key});

  @override
  State<LoginOrRegister> createState() => _LoginOrRegisterState();
}

class _LoginOrRegisterState extends State<LoginOrRegister> {
  bool showLoginPage = true;

  void togglePages() {
    setState(() {
      showLoginPage = !showLoginPage;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (showLoginPage) {
      return LoginPageNew(
        onTap: togglePages,
      );
    } else {
      return RegisterPageNew(onTap: togglePages);
    }
  }
}
