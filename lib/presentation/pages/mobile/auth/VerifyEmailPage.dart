
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:pet_shop/core/constants/app_constants.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';


class VerifyEmailPage extends StatefulWidget {
  final String email;

  const VerifyEmailPage({required this.email});

  @override
  _VerifyEmailPageState createState() => _VerifyEmailPageState();
}

class _VerifyEmailPageState extends State<VerifyEmailPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  bool _isVerified = false;

  @override
  void initState() {
    super.initState();
    // KHÔNG tự động kiểm tra xác thực email ở đây nữa!
    // _checkEmailVerified();
  }

  void _checkEmailVerified() async {
    User? user = _auth.currentUser;
    await user?.reload();
    user = _auth.currentUser; // Lấy user mới sau reload
    if (user != null && user.emailVerified) {
      setState(() {
        _isVerified = true;
      });
      // Chỉ chuyển trang khi bấm nút xác nhận
      Navigator.pop(context, true); // Trả về true cho RegisterPage biết đã xác thực
    } else {
      Fluttertoast.showToast(
          msg: "Email chưa được xác nhận. Vui lòng kiểm tra hộp thư!");
    }
  }

  void _resendVerificationEmail() async {
    User? user = _auth.currentUser;
    if (user != null) {
      await user.sendEmailVerification();
      Fluttertoast.showToast(msg: "Email xác nhận đã gửi lại!");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.surface,
        elevation: 0,
        title: Text(AppLocalizations.of(context)!.verifyEmail, 
                   style: TextStyle(color: Colors.black)),
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Card(
            elevation: 4,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: Padding(
              padding: const EdgeInsets.all(28.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.email_outlined, size: 60, color: primaryColor),
                  const SizedBox(height: 18),
                  Text(
                    AppLocalizations.of(context)!.verifyAccount,
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: primaryColor),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    AppLocalizations.of(context)!.pleaseCheckEmail,
                    style: TextStyle(fontSize: 16, color: Colors.black87),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "(${widget.email}) để xác minh tài khoản.",
                    style: TextStyle(fontSize: 15, color: Colors.black54),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: _checkEmailVerified,
                    icon: const Icon(Icons.verified, size: 20),
                    label: Text(AppLocalizations.of(context)!.iHaveVerified),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextButton.icon(
                    onPressed: _resendVerificationEmail,
                    icon: const Icon(Icons.refresh, color: primaryColor),
                    label: Text(AppLocalizations.of(context)!.resendVerificationEmail, 
                               style: TextStyle(color: primaryColor)),
                  ),
                  if (_isVerified)
                    const Padding(
                      padding: EdgeInsets.only(top: 16.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.check_circle, color: Colors.green, size: 22),
                          SizedBox(width: 8),
                          Text("Email đã xác thực!", style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
