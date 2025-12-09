import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fluttertoast/fluttertoast.dart';
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
    try {
      User? user = _auth.currentUser;
      if (user == null) {
        Fluttertoast.showToast(msg: "Phiên đăng nhập đã hết hạn!");
        return;
      }
      
      // Reload user from Firebase to get fresh emailVerified status
      await user.reload();
      user = _auth.currentUser; // Get updated user after reload
      
      if (user != null && user.emailVerified) {
        setState(() {
          _isVerified = true;
        });
        Fluttertoast.showToast(msg: "Email đã được xác thực thành công!");
        // Return true to RegisterPage
        Navigator.pop(context, true);
      } else {
        Fluttertoast.showToast(
            msg: "Email chưa được xác nhận. Vui lòng kiểm tra hộp thư và click vào link xác thực!");
      }
    } catch (e) {
      Fluttertoast.showToast(msg: "Lỗi khi kiểm tra xác thực: $e");
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
            style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
        iconTheme:
            IconThemeData(color: Theme.of(context).colorScheme.onSurface),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Card(
            elevation: 4,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: Padding(
              padding: const EdgeInsets.all(28.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.email_outlined,
                      size: 60, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(height: 18),
                  Text(
                    AppLocalizations.of(context)!.verifyAccount,
                    style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    AppLocalizations.of(context)!.pleaseCheckEmail,
                    style: TextStyle(
                        fontSize: 16,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withOpacity(0.87)),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "(${widget.email}) để xác minh tài khoản.",
                    style: TextStyle(
                        fontSize: 15,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withOpacity(0.54)),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: _checkEmailVerified,
                    icon: const Icon(Icons.verified, size: 20),
                    label: Text(AppLocalizations.of(context)!.iHaveVerified, style: TextStyle(color:  Theme.of(context).colorScheme.onSurface
                            .withOpacity(0.54)),),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 12),
                      textStyle:  TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold, color:  Theme.of(context).colorScheme.onSurface
                            .withOpacity(0.54)),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextButton.icon(
                    onPressed: _resendVerificationEmail,
                    icon: Icon(Icons.refresh,
                        color: Theme.of(context).colorScheme.primary),
                    label: Text(
                        AppLocalizations.of(context)!.resendVerificationEmail,
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.primary)),
                  ),
                  if (_isVerified)
                    const Padding(
                      padding: EdgeInsets.only(top: 16.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.check_circle,
                              color: Colors.green, size: 22),
                          SizedBox(width: 8),
                          Text("Email đã xác thực!",
                              style: TextStyle(
                                  color: Colors.green,
                                  fontWeight: FontWeight.bold)),
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
