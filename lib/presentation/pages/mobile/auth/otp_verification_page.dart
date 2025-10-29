import 'package:flutter/material.dart';
import 'package:pin_code_fields/pin_code_fields.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:pet_shop/auth/auth_service.dart';
import 'package:pet_shop/core/constants/app_constants.dart';
import 'package:pet_shop/core/utils/dialog_helper.dart';
import 'package:pet_shop/core/utils/localization_helper.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class OtpVerificationPage extends StatefulWidget {
  final String phoneNumber;
  final bool isRegistration;
  final Map<String, dynamic>? registrationData;

  const OtpVerificationPage({
    super.key,
    required this.phoneNumber,
    this.isRegistration = false,
    this.registrationData,
  });

  @override
  State<OtpVerificationPage> createState() => _OtpVerificationPageState();
}

class _OtpVerificationPageState extends State<OtpVerificationPage>
    with TickerProviderStateMixin {
  final TextEditingController _otpController = TextEditingController();
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  String _currentOTP = "";
  String? _verificationId;
  int _resendTokenDuration = 60;
  bool _canResend = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.elasticOut,
    ));
    _animationController.forward();

    // Send OTP when page loads - delay until after build is complete
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _sendOTP();
    });
    _startResendTimer();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  void _startResendTimer() {
    setState(() {
      _canResend = false;
      _resendTokenDuration = 60;
    });

    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (mounted) {
        setState(() {
          _resendTokenDuration--;
          if (_resendTokenDuration <= 0) {
            _canResend = true;
          }
        });
        return _resendTokenDuration > 0;
      }
      return false;
    });
  }

  void _sendOTP() async {
    if (!mounted) return;

    DialogHelper.showLoadingDialog(context,
        message: LocalizationHelper.getLocalizedText(context, 'sendingOtp'));

    try {
      await authService.value.verifyPhoneNumber(
        phoneNumber: widget.phoneNumber,
        verificationCompleted: (PhoneAuthCredential credential) async {
          if (mounted) {
            DialogHelper.hideLoadingDialog(context);
            await _verifyOTP(credential);
          }
        },
        verificationFailed: (FirebaseAuthException e) async {
          if (mounted) {
            DialogHelper.hideLoadingDialog(context);
            _showSnackbar(
                "${LocalizationHelper.getLocalizedText(context, 'otpSendFailed')}: ${e.message}");
          }
        },
        codeSent: (String verificationId, int? resendToken) async {
          if (mounted) {
            DialogHelper.hideLoadingDialog(context);
            setState(() {
              _verificationId = verificationId;
            });
            _showSnackbar(
                LocalizationHelper.getLocalizedText(context, 'otpSent'));
          }
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          if (mounted) {
            setState(() {
              _verificationId = verificationId;
            });
          }
        },
      );
    } catch (e) {
      if (mounted) {
        DialogHelper.hideLoadingDialog(context);
        _showSnackbar(
            "${LocalizationHelper.getLocalizedText(context, 'otpError')}: $e");
      }
    }
  }

  void _resendOTP() {
    if (_canResend) {
      _sendOTP();
      _startResendTimer();
    }
  }

  Future<void> _verifyOTP(PhoneAuthCredential? credential) async {
    if (_currentOTP.length != 6 && credential == null) {
      _showSnackbar(
          LocalizationHelper.getLocalizedText(context, 'enter6Digits'));
      return;
    }

    if (!mounted) return;
    DialogHelper.showLoadingDialog(context,
        message: LocalizationHelper.getLocalizedText(context, 'verifying'));

    try {
      PhoneAuthCredential finalCredential;

      if (credential != null) {
        finalCredential = credential;
      } else {
        if (_verificationId == null) {
          if (mounted) {
            DialogHelper.hideLoadingDialog(context);
            _showSnackbar(LocalizationHelper.getLocalizedText(
                context, 'verificationErrorRetry'));
          }
          return;
        }
        finalCredential = PhoneAuthProvider.credential(
          verificationId: _verificationId!,
          smsCode: _currentOTP,
        );
      }

      if (widget.isRegistration) {
        await _handlePhoneRegistration(finalCredential);
      } else {
        // Check if this is password reset
        if (widget.registrationData != null &&
            widget.registrationData!['resetPassword'] == true) {
          await _handlePasswordReset();
        } else {
          await _handlePhoneLogin(finalCredential);
        }
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        DialogHelper.hideLoadingDialog(context);
        String errorMessage =
            LocalizationHelper.getLocalizedText(context, 'verificationFailed');

        switch (e.code) {
          case 'invalid-verification-code':
            errorMessage =
                LocalizationHelper.getLocalizedText(context, 'incorrectOtp');
            break;
          case 'invalid-verification-id':
            errorMessage =
                LocalizationHelper.getLocalizedText(context, 'invalidSession');
            break;
          case 'session-expired':
            errorMessage =
                LocalizationHelper.getLocalizedText(context, 'sessionExpired');
            break;
          default:
            errorMessage =
                "${LocalizationHelper.getLocalizedText(context, 'authError')}: ${e.message}";
        }

        _showSnackbar(errorMessage);
      }
    } catch (e) {
      if (mounted) {
        DialogHelper.hideLoadingDialog(context);
        _showSnackbar(
            "${LocalizationHelper.getLocalizedText(context, 'unknownErrorOccurred')}: $e");
      }
    }
  }

  Future<void> _handlePhoneRegistration(PhoneAuthCredential credential) async {
    try {
      if (widget.registrationData == null) {
        await DialogHelper.hideLoadingDialog(context);
        _showSnackbar(LocalizationHelper.getLocalizedText(
            context, 'missingRegistrationInfo'));
        return;
      }

      final String phone = widget.registrationData!['phone'];
      final String name = widget.registrationData!['name'];

      // Sign in (or create) using phone credential directly
      UserCredential userCredential =
          await authService.value.signInWithPhoneCredential(credential);

      final user = userCredential.user;
      if (user != null) {
        // Update Firestore user profile to align with phone-only account (no fake email)
        await FirebaseFirestore.instance.collection("users").doc(user.uid).set({
          "uid": user.uid,
          "email": null,
          "displayName": name,
          "imageUrl": user.photoURL ??
              "https://i.pinimg.com/736x/8b/16/7a/8b167af653c2399dd93b952a48740620.jpg",
          "phone": phone,
          "phoneNumber": user.phoneNumber ?? phone,
          "provider": "phone",
          "role": "user",
          "address": [],
          "dateOfBirth": null,
          "gender": null,
          "bio": null,
          "createdAt": FieldValue.serverTimestamp(),
          "updatedAt": FieldValue.serverTimestamp(),
          "phoneVerified": true,
        }, SetOptions(merge: true));

        // Sign out to prevent auto-login after registration
        await authService.value.signOut();

        if (mounted) {
          DialogHelper.hideLoadingDialog(context);
          Navigator.pop(context, true);
        }
      }
    } catch (e) {
      if (mounted) {
        DialogHelper.hideLoadingDialog(context);
        _showSnackbar(
            "${LocalizationHelper.getLocalizedText(context, 'registrationError')}: $e");
      }
    }
  }

  Future<void> _handlePhoneLogin(PhoneAuthCredential credential) async {
    try {
      await authService.value.signInWithPhoneCredential(credential);

      await DialogHelper.hideLoadingDialog(context);

      if (mounted) {
        Navigator.pop(context, true); // Return success
      }
    } catch (e) {
      await DialogHelper.hideLoadingDialog(context);
      if (mounted) {
        _showSnackbar(
            "${LocalizationHelper.getLocalizedText(context, 'loginFailed')}: $e");
      }
    }
  }

  Future<void> _handlePasswordReset() async {
    try {
      await DialogHelper.hideLoadingDialog(context);

      if (mounted) {
        Navigator.pop(context, true); // Return success for password reset
      }
    } catch (e) {
      await DialogHelper.hideLoadingDialog(context);
      if (mounted) {
        _showSnackbar(
            "${LocalizationHelper.getLocalizedText(context, 'verificationError')}: $e");
      }
    }
  }

  String _getPageTitle() {
    if (widget.isRegistration) {
      return LocalizationHelper.getLocalizedText(
          context, 'verificationRegistrationTitle');
    } else if (widget.registrationData != null &&
        widget.registrationData!['resetPassword'] == true) {
      return LocalizationHelper.getLocalizedText(
          context, 'forgotPasswordVerificationTitle');
    } else {
      return LocalizationHelper.getLocalizedText(
          context, 'loginVerificationTitle');
    }
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
      backgroundColor: secondaryColor,
      appBar: AppBar(
        centerTitle: true,
        backgroundColor: secondaryColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context, false),
        ),
        title: Text(
          _getPageTitle(),
          style: const TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ScaleTransition(
                scale: _scaleAnimation,
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: Colors.pink.shade300,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.phone_android,
                    size: 60,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 30),
              Text(
                widget.isRegistration
                    ? LocalizationHelper.getLocalizedText(
                        context, 'verifyPhoneNumberTitle')
                    : LocalizationHelper.getLocalizedText(
                        context, 'loginWithOtpTitle'),
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text(
                "${LocalizationHelper.getLocalizedText(context, 'otpSentTo')}\n${widget.phoneNumber}",
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey.shade600,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),
              PinCodeTextField(
                appContext: context,
                length: 6,
                controller: _otpController,
                animationType: AnimationType.fade,
                pinTheme: PinTheme(
                  shape: PinCodeFieldShape.box,
                  borderRadius: BorderRadius.circular(12),
                  fieldHeight: 55,
                  fieldWidth: 45,
                  activeFillColor: Colors.white,
                  inactiveFillColor: Colors.grey.shade100,
                  selectedFillColor: Colors.pink.shade50,
                  activeColor: Colors.pink.shade300,
                  inactiveColor: Colors.grey.shade300,
                  selectedColor: Colors.pink.shade300,
                ),
                animationDuration: const Duration(milliseconds: 300),
                enableActiveFill: true,
                onCompleted: (value) {
                  setState(() {
                    _currentOTP = value;
                  });
                  _verifyOTP(null);
                },
                onChanged: (value) {
                  setState(() {
                    _currentOTP = value;
                  });
                },
              ),
              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed:
                      _currentOTP.length == 6 ? () => _verifyOTP(null) : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.pink.shade300,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    LocalizationHelper.getLocalizedText(
                        context, 'verifyButton'),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(LocalizationHelper.getLocalizedText(
                      context, 'didNotReceiveCode')),
                  GestureDetector(
                    onTap: _canResend ? _resendOTP : null,
                    child: Text(
                      _canResend
                          ? LocalizationHelper.getLocalizedText(
                              context, 'resendButton')
                          : "${LocalizationHelper.getLocalizedText(context, 'resendButtonTimer')} ($_resendTokenDuration)",
                      style: TextStyle(
                        color: _canResend ? Colors.pink.shade300 : Colors.grey,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
