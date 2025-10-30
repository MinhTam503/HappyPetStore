import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:pet_shop/core/constants/app_constants.dart';
import 'package:pet_shop/presentation/pages/mobile/auth/VerifyEmailPage.dart';

class ChangeEmailPage extends StatefulWidget {
  final String? currentEmail;
  const ChangeEmailPage({super.key, this.currentEmail});

  @override
  State<ChangeEmailPage> createState() => _ChangeEmailPageState();
}

class _ChangeEmailPageState extends State<ChangeEmailPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  bool _isSubmitting = false;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    final newEmail = _emailController.text.trim();
    if (newEmail == widget.currentEmail) {
      setState(() => _error = 'Email mới trùng với email hiện tại');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _error = null;
    });

    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) throw Exception('Chưa đăng nhập');

      // Check duplicates in Firestore (exclude current user)
      final dup = await FirebaseFirestore.instance
          .collection('users')
          .where('email', isEqualTo: newEmail)
          .limit(1)
          .get();
      if (dup.docs.isNotEmpty && dup.docs.first.id != uid) {
        throw Exception('Email này đã được sử dụng bởi tài khoản khác');
      }

      // Send verification email using verifyBeforeUpdateEmail
      await FirebaseAuth.instance.currentUser!.verifyBeforeUpdateEmail(newEmail);

      if (!mounted) return;
      final verified = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => VerifyEmailPage(email: newEmail),
        ),
      );

      if (verified == true) {
        // Reload and persist to Firestore
        await FirebaseAuth.instance.currentUser!.reload();
        final updated = FirebaseAuth.instance.currentUser;
        if (updated != null && updated.email == newEmail) {
          await FirebaseFirestore.instance.collection('users').doc(uid).update({
            'email': newEmail,
            // Keep emailVerified for backward compatibility; can be removed later
            'emailVerified': true,
            'updatedAt': FieldValue.serverTimestamp(),
          });
          if (mounted) Navigator.pop(context, true);
        } else {
          setState(() => _error = 'Không thể đồng bộ email mới. Vui lòng thử lại.');
        }
      }
    } on FirebaseAuthException catch (e) {
      if (e.code == 'requires-recent-login') {
        setState(() => _error = 'Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại để đổi email.');
      } else {
        setState(() => _error = e.message ?? 'Lỗi xác thực khi đổi email');
      }
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  String? _validateEmail(String? val) {
    final v = (val ?? '').trim();
    if (v.isEmpty) return 'Vui lòng nhập email mới';
    final emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    if (!emailRegex.hasMatch(v)) return 'Email không hợp lệ';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: secondaryColor,
      appBar: AppBar(
        backgroundColor: secondaryColor,
        elevation: 0,
        centerTitle: true,
        title: const Text('Đổi email', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Nhập email mới', style: TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Form(
                key: _formKey,
                child: TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    hintText: 'example@email.com',
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                  ),
                  validator: _validateEmail,
                ),
              ),
              const SizedBox(height: 12),
              if (_error != null)
                Text(_error!, style: const TextStyle(color: Colors.red)),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Tiếp tục', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
