import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:pet_shop/auth/auth_service.dart';
import 'package:pet_shop/presentation/widgets/components/my_button.dart';
import 'package:pet_shop/presentation/widgets/components/my_textfield.dart';
import 'package:pet_shop/core/constants/app_constants.dart';
import 'package:pet_shop/core/utils/dialog_helper.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:pet_shop/presentation/pages/mobile/auth/otp_verification_page.dart';
import 'package:pet_shop/helpers/phone_utils.dart';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage>
    with TickerProviderStateMixin {
  final TextEditingController _accountController = TextEditingController();
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
    _animationController.dispose();
    super.dispose();
  }

  // Check if input is email or phone
  bool _isEmail(String input) {
    return RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(input);
  }

  bool _isPhoneNumber(String input) => PhoneUtils.isValidVN(input);
  String _formatPhoneNumber(String phone) => PhoneUtils.normalizeVN(phone) ?? phone;

  void _resetPassword() async {
    String account = _accountController.text.trim();

    if (account.isEmpty) {
      _showSnackbar(AppLocalizations.of(context)!.enterEmailOrPhone);
      return;
    }

    if (!_isEmail(account) && !_isPhoneNumber(account)) {
      _showSnackbar(AppLocalizations.of(context)!.invalidEmailOrPhone);
      return;
    }

    if (_isEmail(account)) {
      await _resetPasswordWithEmail(account);
    } else {
      await _resetPasswordWithPhone(account);
    }
  }

  Future<void> _resetPasswordWithEmail(String email) async {
  DialogHelper.showLoadingDialog(context, message: AppLocalizations.of(context)!.checkingEmail);

    try {
      // Check if email exists in Firestore
      QuerySnapshot emailQuery = await FirebaseFirestore.instance
          .collection("users")
          .where("email", isEqualTo: email)
          .get();

      if (emailQuery.docs.isEmpty) {
        await DialogHelper.hideLoadingDialog(context);
        if (mounted) {
          _showSnackbar(AppLocalizations.of(context)!.emailNotExist);
        }
        return;
      }

      // Send password reset email
      await authService.value.resetPassword(email: email);

      await DialogHelper.hideLoadingDialog(context);

      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        _showSuccessDialog(
          l10n.resetEmailSent,
          "${l10n.checkEmailInstructions} ($email)",
        );
      }
    } on FirebaseAuthException catch (e) {
      await DialogHelper.hideLoadingDialog(context);
      
      String errorMessage = AppLocalizations.of(context)!.sendEmailFailed;
      switch (e.code) {
        case 'user-not-found':
          errorMessage = AppLocalizations.of(context)!.emailNotExist;
          break;
        case 'invalid-email':
          errorMessage = AppLocalizations.of(context)!.invalidEmailOrPhone;
          break;
        default:
          errorMessage = "${AppLocalizations.of(context)!.errorOccurred(e.message ?? '')}";
      }
      
      if (mounted) {
        _showSnackbar(errorMessage);
      }
    } catch (e) {
      await DialogHelper.hideLoadingDialog(context);
      if (mounted) {
        _showSnackbar(AppLocalizations.of(context)!.errorOccurred(e.toString()));
      }
    }
  }

  Future<void> _resetPasswordWithPhone(String phone) async {
    String formattedPhone = _formatPhoneNumber(phone);
    
  DialogHelper.showLoadingDialog(context, message: AppLocalizations.of(context)!.checkingPhone);

    try {
      // Check if phone exists in Firestore (check both fields and legacy 09 format)
      final users = FirebaseFirestore.instance.collection("users");
      final local09 = PhoneUtils.toDisplay09(formattedPhone);
      QuerySnapshot q1 = await users.where("phone", isEqualTo: formattedPhone).limit(1).get();
      QuerySnapshot q2 = await users.where("phoneNumber", isEqualTo: formattedPhone).limit(1).get();
      QuerySnapshot q3 = await users.where("phone", isEqualTo: local09).limit(1).get();
      QuerySnapshot q4 = await users.where("phoneNumber", isEqualTo: local09).limit(1).get();

      if (q1.docs.isEmpty && q2.docs.isEmpty && q3.docs.isEmpty && q4.docs.isEmpty) {
        await DialogHelper.hideLoadingDialog(context);
        if (mounted) {
          _showSnackbar(AppLocalizations.of(context)!.phoneNotRegistered);
        }
        return;
      }

      await DialogHelper.hideLoadingDialog(context);

      if (!mounted) return;

      // Navigate to OTP verification for password reset
      bool otpVerified = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => OtpVerificationPage(
            phoneNumber: formattedPhone,
            isRegistration: false, // This is password reset
            registrationData: {
              'resetPassword': true,
              'phone': formattedPhone,
            },
          ),
        ),
      ) ?? false;

      if (otpVerified && mounted) {
        // After OTP verification, show instructions to reset password
        _showPasswordResetInstructions(formattedPhone);
      }
    } catch (e) {
      await DialogHelper.hideLoadingDialog(context);
      if (mounted) {
        _showSnackbar(AppLocalizations.of(context)!.phoneCheckError(e.toString()));
      }
    }
  }

  void _showPasswordResetInstructions(String phone) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.info, color: Colors.blue.shade600),
              const SizedBox(width: 10),
              Text(AppLocalizations.of(context)!.passwordResetGuideTitle),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppLocalizations.of(context)!.phoneVerifiedMessage(phone),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 15),
              Text(AppLocalizations.of(context)!.passwordResetStepsIntro),
              const SizedBox(height: 10),
              Text(AppLocalizations.of(context)!.passwordResetStep1),
              Text(AppLocalizations.of(context)!.passwordResetStep2),
              Text(AppLocalizations.of(context)!.passwordResetStep3),
              const SizedBox(height: 15),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.yellow.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  AppLocalizations.of(context)!.passwordResetNote,
                  style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).pop(); // Go back to login
              },
              child: Text(AppLocalizations.of(context)!.gotIt),
            ),
          ],
        );
      },
    );
  }

  void _showSuccessDialog(String title, String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green.shade600),
              const SizedBox(width: 10),
              Text(title),
            ],
          ),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).pop(); // Go back to login
              },
              child: Text(AppLocalizations.of(context)!.ok),
            ),
          ],
        );
      },
    );
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
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          AppLocalizations.of(context)!.forgotPasswordTitle,
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SafeArea(
        child: Stack(
          children: [
            // Background decorative circles
            Positioned(
              top: 10,
              left: 230,
              child: Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: Colors.pink.shade300,
                  shape: BoxShape.circle,
                ),
              ),
            ),
            Positioned(
              top: 20,
              left: 280,
              child: Container(
                width: 150,
                height: 150,
                decoration: BoxDecoration(
                  color: Colors.pink.shade300,
                  shape: BoxShape.circle,
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
                  color: Colors.pink.shade300,
                  shape: BoxShape.circle,
                ),
              ),
            ),
            Positioned(
              bottom: 20,
              right: 320,
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: Colors.pink.shade300,
                  shape: BoxShape.circle,
                ),
              ),
            ),
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 25),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Forgot Password Image
                    FadeTransition(
                      opacity: _fadeAnimation,
                      child: SlideTransition(
                        position: _slideAnimation,
                        child: Container(
                          width: 180,
                          height: 180,
                          decoration: BoxDecoration(
                            color: Colors.pink.shade300,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.pink.shade300.withOpacity(0.3),
                                spreadRadius: 5,
                                blurRadius: 15,
                                offset: const Offset(0, 5),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.lock_reset,
                            size: 80,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 40),
                    Text(
                      AppLocalizations.of(context)!.forgotPasswordHeading,
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      AppLocalizations.of(context)!.forgotPasswordSubtitle,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w300,
                        color: Colors.grey,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 40),
                    MyTextField(
                      hintText: AppLocalizations.of(context)!.emailOrPhoneHint,
                      icon: const Icon(Icons.contact_mail_outlined),
                      controller: _accountController,
                      obsecureText: false,
                    ),
                    const SizedBox(height: 30),
                    MyButton(
                      text: AppLocalizations.of(context)!.sendRequestButton,
                      onPressed: _resetPassword,
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(AppLocalizations.of(context)!.rememberPassword),
                        GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: Text(
                            AppLocalizations.of(context)!.loginNow,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.pink.shade300,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 30),
                    Container(
                      padding: const EdgeInsets.all(15),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Icon(Icons.info_outline, 
                                color: Colors.blue.shade600, size: 20),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  AppLocalizations.of(context)!.instructions,
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(
                            "${AppLocalizations.of(context)!.instructionsEmailBullet}\n${AppLocalizations.of(context)!.instructionsPhoneBullet}",
                            style: const TextStyle(fontSize: 14),
                          ),
                        ],
                      ),
                    ),
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