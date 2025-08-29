import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import 'package:pet_shop/auth/auth_service.dart';
import 'package:pet_shop/utils/contants.dart';
import 'package:pet_shop/view/web/screen_admin/home/home_page_admin.dart';
import '../../../mobile/bottom_navigator.dart';

class LoginAdminPage extends StatefulWidget {
  const LoginAdminPage({super.key});

  @override
  State<LoginAdminPage> createState() => _LoginAdminPageState();
}

class _LoginAdminPageState extends State<LoginAdminPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscure = true;
  bool _loading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);

    try {
      final cred = await authService.value.signIn(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      final user = cred.user;
      if (user == null) {
        throw FirebaseAuthException(
            code: 'user-null', message: 'Không xác định được người dùng.');
      }

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (!userDoc.exists) {
        _showSnack('Tài khoản không tồn tại trong hệ thống.');
        return;
      }

      final role = (userDoc.data() ?? {})['role']?.toString() ?? 'user';

      if (!mounted) return;
      if (kIsWeb && role == 'admin') {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const HomePageAdmin()),
        );
      } else {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const BottomNavigator()),
        );
      }
    } on FirebaseAuthException catch (e) {
      _showSnack(_mapFirebaseError(e));
    } catch (e) {
      _showSnack('Đã xảy ra lỗi: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _mapFirebaseError(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-email':
        return 'Email không hợp lệ.';
      case 'user-disabled':
        return 'Tài khoản đã bị vô hiệu hóa.';
      case 'user-not-found':
        return 'Không tìm thấy tài khoản.';
      case 'wrong-password':
        return 'Mật khẩu không chính xác.';
      case 'invalid-credential':
        return 'Thông tin đăng nhập không hợp lệ.';
      default:
        return e.message ?? 'Lỗi xác thực.';
    }
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: backgroundColorWeb,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 900;

          final form = Stack(

            children: [
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: Card(
                    elevation: 8,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              'Đăng nhập',
                              style: theme.textTheme.headlineSmall
                                  ?.copyWith(fontWeight: FontWeight.bold),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Vui lòng đăng nhập để tiếp tục',
                              style: theme.textTheme.bodyMedium,
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 24),
                            TextFormField(
                              controller: _emailController,
                              textInputAction: TextInputAction.next,
                              autofillHints: const [
                                AutofillHints.username,
                                AutofillHints.email
                              ],
                              keyboardType: TextInputType.emailAddress,
                              decoration: const InputDecoration(
                                labelText: 'Email',
                                prefixIcon: Icon(Icons.email_outlined),
                                border: OutlineInputBorder(),
                              ),
                              validator: (v) {
                                final text = v?.trim() ?? '';
                                if (text.isEmpty) return 'Vui lòng nhập email';
                                final emailRegex =
                                    RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
                                if (!emailRegex.hasMatch(text))
                                  return 'Email không hợp lệ';
                                return null;
                              },
                              onFieldSubmitted: (_) =>
                                  FocusScope.of(context).nextFocus(),
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _passwordController,
                              textInputAction: TextInputAction.done,
                              obscureText: _obscure,
                              autofillHints: const [AutofillHints.password],
                              decoration: InputDecoration(
                                labelText: 'Mật khẩu',
                                prefixIcon: const Icon(Icons.lock_outline),
                                border: const OutlineInputBorder(),
                                suffixIcon: IconButton(
                                  tooltip: _obscure
                                      ? 'Hiện mật khẩu'
                                      : 'Ẩn mật khẩu',
                                  icon: Icon(_obscure
                                      ? Icons.visibility
                                      : Icons.visibility_off),
                                  onPressed: () =>
                                      setState(() => _obscure = !_obscure),
                                ),
                              ),
                              validator: (v) {
                                final text = v ?? '';
                                if (text.isEmpty)
                                  return 'Vui lòng nhập mật khẩu';
                                if (text.length < 6)
                                  return 'Mật khẩu tối thiểu 6 ký tự';
                                return null;
                              },
                              onFieldSubmitted: (_) => _submit(),
                            ),
                            // const SizedBox(height: 8),
                            // Align(
                            //   alignment: Alignment.centerRight,
                            //   child: TextButton(
                            //     onPressed: () {},
                            //     child: const Text('Quên mật khẩu?'),
                            //   ),
                            // ),
                            const SizedBox(height: 28),
                            SizedBox(
                              height: 48,
                              child: FilledButton(
                                style: FilledButton.styleFrom(
                                  backgroundColor: primaryColor,
                                  foregroundColor: Colors.white,
                                ),
                                autofocus: true,
                                onPressed: _loading ? null : _submit,
                                child: const Text('ĐĂNG NHẬP'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );

          final hero = _HeroPane();

          return Stack(
            children: [
              if (isWide)
                Row(
                  children: [
                    Expanded(child: hero),
                    Expanded(
                        child: SingleChildScrollView(
                            child: Padding(
                                padding: const EdgeInsets.all(24),
                                child: form))),
                  ],
                )
              else
                CustomScrollView(
                  slivers: [
                    SliverToBoxAdapter(
                        child: SizedBox(height: 280, child: hero)),
                    SliverToBoxAdapter(
                        child: Padding(
                            padding: const EdgeInsets.all(16), child: form)),
                  ],
                ),
              if (_loading) const _LoadingOverlay(),
            ],
          );
        },
      ),
    );
  }
}

class _HeroPane extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Replace with your AssetImage if available
        Image.asset(
          'assets/images/loginImage.png',
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Container(color: Colors.pink.shade100),
        ),
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.black.withOpacity(0.4), Colors.transparent],
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
            ),
          ),
        ),
        // Optional floating accents
      ],
    );
  }
}

class _LoadingOverlay extends StatelessWidget {
  const _LoadingOverlay();

  @override
  Widget build(BuildContext context) {
    return AbsorbPointer(
      child: Container(
        color: Colors.black45,
        alignment: Alignment.center,
        child: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 12),
            Text('Đang đăng nhập...', style: TextStyle(color: Colors.white)),
          ],
        ),
      ),
    );
  }
}
