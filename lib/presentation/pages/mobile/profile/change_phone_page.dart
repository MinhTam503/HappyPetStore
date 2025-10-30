import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:pet_shop/core/constants/app_constants.dart';
import 'package:pin_code_fields/pin_code_fields.dart';
import 'package:pet_shop/helpers/phone_utils.dart';

class ChangePhonePage extends StatefulWidget {
  final String? currentPhone;
  const ChangePhonePage({super.key, this.currentPhone});

  @override
  State<ChangePhonePage> createState() => _ChangePhonePageState();
}

class _ChangePhonePageState extends State<ChangePhonePage> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _codeController = TextEditingController();
  bool _isSending = false;
  bool _isVerifying = false;
  bool _isCodeSentUIVisible = false; // chỉ hiện OTP sau khi gửi mã thành công
  String? _error;
  String? _verificationId;
  int _resendSeconds = 0;
  Timer? _timer;
  String? _pendingE164; // lưu số +84 đã chuẩn hóa cho lần xác minh hiện tại

  @override
  void dispose() {
    _phoneController.dispose();
    _codeController.dispose();
    _timer?.cancel();
    super.dispose();
  }

  void _startResendTimer() {
    _timer?.cancel();
    setState(() => _resendSeconds = 60);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      if (_resendSeconds <= 0) {
        t.cancel();
      } else {
        setState(() => _resendSeconds--);
      }
    });
  }

  Future<void> _sendCode() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    final phone = _phoneController.text.trim();
    if (widget.currentPhone != null &&
        PhoneUtils.equals(phone, widget.currentPhone!)) {
      setState(() => _error = 'Số điện thoại mới trùng với hiện tại');
      return;
    }

    setState(() {
      _isSending = true;
      _error = null;
      _isCodeSentUIVisible = false;
      _verificationId = null;
      _pendingE164 = null;
    });

    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) throw Exception('Chưa đăng nhập');

  final e164 = PhoneUtils.normalizeVN(phone);
      if (e164 == null)
        throw Exception(
            'Số điện thoại không hợp lệ. Vui lòng nhập dạng 09xxxxxxxx (9 số).');
      final local09 = PhoneUtils.toDisplay09(e164);
  _pendingE164 = e164;

      // Duplicate check (exclude current user)
      final users = FirebaseFirestore.instance.collection('users');
      final q1 = await users.where('phone', isEqualTo: e164).limit(1).get();
      final q2 =
          await users.where('phoneNumber', isEqualTo: e164).limit(1).get();
      final q3 = await users.where('phone', isEqualTo: local09).limit(1).get();
      final q4 =
          await users.where('phoneNumber', isEqualTo: local09).limit(1).get();
      bool hasDup = false;
      for (final s in [q1, q2, q3, q4]) {
        if (s.docs.isNotEmpty && s.docs.first.id != uid) {
          hasDup = true;
          break;
        }
      }
      if (hasDup)
        throw Exception('Số điện thoại đã được sử dụng bởi tài khoản khác');

      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: e164,
        verificationCompleted: (cred) async {
          // Instant verification on some devices
          await _applyPhoneCredential(e164, cred);
        },
        verificationFailed: (e) {
          setState(() => _error = e.message ?? 'Gửi OTP thất bại');
        },
        codeSent: (id, _) {
          setState(() {
            _verificationId = id;
            _isCodeSentUIVisible = true;
          });
          _startResendTimer();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Đã gửi mã OTP')),
          );
        },
        codeAutoRetrievalTimeout: (id) {
          setState(() => _verificationId = id);
        },
      );
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _verifyCode() async {
    final code = _codeController.text.trim();
    if ((_verificationId ?? '').isEmpty || code.length != 6) return;

    setState(() {
      _isVerifying = true;
      _error = null;
    });

    try {
      final cred = PhoneAuthProvider.credential(
        verificationId: _verificationId!,
        smsCode: code,
      );
      final normalized = _pendingE164 ?? PhoneUtils.normalizeVN(_phoneController.text.trim()) ?? _phoneController.text.trim();
      await _applyPhoneCredential(normalized, cred);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _isVerifying = false);
    }
  }

  Future<void> _applyPhoneCredential(
      String phone, PhoneAuthCredential cred) async {
    try {
      final current = FirebaseAuth.instance.currentUser;
      if (current == null) throw Exception('Chưa đăng nhập');

      // Update or link phone
      if ((current.phoneNumber ?? '').isNotEmpty) {
        await current.updatePhoneNumber(cred);
      } else {
        await current.linkWithCredential(cred);
      }

      // Persist to Firestore
      await FirebaseFirestore.instance
          .collection('users')
          .doc(current.uid)
          .update({
        'phone': phone,
        'phoneNumber': phone,
        // Keep for backward compatibility; can be removed later
        'phoneVerified': true,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      Navigator.pop(context, true);
    } on FirebaseAuthException catch (e) {
      setState(() => _error = e.message ?? 'Lỗi xác minh số điện thoại');
    } catch (e) {
      setState(() => _error = e.toString());
    }
  }

  String? _validatePhone(String? val) {
    final v = (val ?? '').trim();
    if (v.isEmpty) return 'Vui lòng nhập số điện thoại';
    if (!PhoneUtils.isValidVN(v)) {
      return 'Số điện thoại không hợp lệ. Cho phép nhập 09xxxxxxxx, hệ thống sẽ lưu dạng +84';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final canResend = _resendSeconds == 0;
    return Scaffold(
      backgroundColor: secondaryColor,
      appBar: AppBar(
        backgroundColor: secondaryColor,
        elevation: 0,
        centerTitle: true,
        title: const Text('Đổi số điện thoại',
            style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Nhập số điện thoại mới',
                  style: TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Form(
                key: _formKey,
                child: TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    // hintText: '09xxxxxxxx hoặc +84xxxxxxxxx',
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                  ),
                  validator: _validatePhone,
                ),
              ),
              const SizedBox(height: 8),
              if (_error != null)
                Text(_error!, style: const TextStyle(color: Colors.red)),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isSending ? null : _sendCode,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: _isSending
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : const Text('Gửi mã OTP',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  TextButton(
                    onPressed: canResend && !_isSending ? _sendCode : null,
                    child: Text(
                        canResend ? 'Gửi lại' : 'Gửi lại (${_resendSeconds}s)'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (_isCodeSentUIVisible) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Nhập mã OTP', style: TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      PinCodeTextField(
                        appContext: context,
                        length: 6,
                        controller: _codeController,
                        animationType: AnimationType.fade,
                        backgroundColor: Colors.transparent,
                        cursorColor: Colors.black87,
                        keyboardType: TextInputType.number,
                        enableActiveFill: true,
                        pinTheme: PinTheme(
                          shape: PinCodeFieldShape.box,
                          borderRadius: BorderRadius.circular(8),
                          fieldHeight: 46,
                          fieldWidth: 40,
                          inactiveColor: Colors.grey.shade300,
                          selectedColor: primaryColor,
                          activeColor: Colors.grey.shade500,
                          inactiveFillColor: Colors.white,
                          selectedFillColor: Colors.white,
                          activeFillColor: Colors.white,
                        ),
                        onChanged: (_) {},
                        onCompleted: (_) {
                          if (!_isVerifying) _verifyCode();
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: (_verificationId ?? '').isEmpty || _isVerifying ? null : _verifyCode,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _isVerifying
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Text('Xác minh', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              // const Text(
              //   'Lưu ý: Bạn có thể nhập 09xxxxxxxx, hệ thống sẽ tự động lưu theo chuẩn +84xxxxxxxxx.',
              //   style: TextStyle(fontSize: 12, color: Colors.black54),
              // ),
            ],
          ),
        ),
      ),
    );
  }
}
