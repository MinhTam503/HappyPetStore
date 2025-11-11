import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:pet_shop/auth/auth_service.dart';
import 'package:pet_shop/core/constants/app_constants.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class ChangePasswordPage extends StatefulWidget {
  const ChangePasswordPage({super.key});

  @override
  State<ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends State<ChangePasswordPage> {
  final oldPasswordController = TextEditingController();
  final newPasswordController = TextEditingController();
  final confirmPasswordController = TextEditingController();
  final email = FirebaseAuth.instance.currentUser!.email!;

  final _formKey = GlobalKey<FormState>();
  bool _hideOld = true;
  bool _hideNew = true;
  bool _hideConfirm = true;
  bool _isLoading = false;

  // Focus để chuyển trường nhanh hơn
  final _oldNode = FocusNode();
  final _newNode = FocusNode();
  final _confirmNode = FocusNode();

  @override
  void dispose() {
    oldPasswordController.dispose();
    newPasswordController.dispose();
    confirmPasswordController.dispose();
    _oldNode.dispose();
    _newNode.dispose();
    _confirmNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = MediaQuery.of(context).size;
    final isWide = size.width >= 900;
    final horizontal = isWide ? size.width * 0.2 : 20.0;

    return Scaffold(
      backgroundColor: secondaryColor,
      appBar: AppBar(
        backgroundColor: secondaryColor,
        centerTitle: true,
        elevation: 0,
        title: Text(
          AppLocalizations.of(context)!.changePassword,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            letterSpacing: .2,
          ),
        ),
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(horizontal, 20, horizontal, 24),
              child: Column(
                children: [
                  // Card header nhẹ nhàng
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      gradient: LinearGradient(
                        colors: [
                          Colors.white,
                          secondaryColor.withOpacity(.6),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(.05),
                          blurRadius: 12,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(.06),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: const Icon(Icons.lock_person_outlined),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            AppLocalizations.of(context)!.passwordChangeInfoBlurb,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: Colors.black54,
                              height: 1.25,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),

                  // FORM
                  Card(
                    elevation: 2.5,
                    color: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          children: [
                            // Mật khẩu cũ
                            _LabeledField(
                              label: AppLocalizations.of(context)!.oldPassword,
                              child: TextFormField(
                                controller: oldPasswordController,
                                focusNode: _oldNode,
                                textInputAction: TextInputAction.next,
                                obscureText: _hideOld,
                                decoration: _decoration(
                                  context,
                                  hint: AppLocalizations.of(context)!.enterOldPassword,
                                  icon: Icons.lock_outline,
                                  isObscure: _hideOld,
                                  onToggle: () =>
                                      setState(() => _hideOld = !_hideOld),
                                ),
                                validator: (v) {
                                  final l10n = AppLocalizations.of(context)!;
                                  if (v == null || v.trim().isEmpty) {
                                    return l10n.pleaseEnterOldPassword;
                                  }
                                  if (v.trim().length < 6) {
                                    return l10n.passwordMinLength;
                                  }
                                  return null;
                                },
                                onFieldSubmitted: (_) => FocusScope.of(context)
                                    .requestFocus(_newNode),
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Mật khẩu mới
                            _LabeledField(
                              label: AppLocalizations.of(context)!.newPassword,
                              child: TextFormField(
                                controller: newPasswordController,
                                focusNode: _newNode,
                                textInputAction: TextInputAction.next,
                                obscureText: _hideNew,
                                decoration: _decoration(
                                  context,
                                  hint: AppLocalizations.of(context)!.enterNewPassword,
                                  icon: Icons.lock_reset,
                                  isObscure: _hideNew,
                                  onToggle: () =>
                                      setState(() => _hideNew = !_hideNew),
                                ),
                                onChanged: (_) => setState(() {}),
                                validator: (v) {
                                  final l10n = AppLocalizations.of(context)!;
                                  if (v == null || v.trim().isEmpty) {
                                    return l10n.pleaseEnterNewPassword;
                                  }
                                  if (v.trim().length < 6) {
                                    return l10n.passwordMinLength;
                                  }
                                  if (v.trim() ==
                                      oldPasswordController.text.trim()) {
                                    return l10n.cannotMatchOldPassword;
                                  }
                                  return null;
                                },
                                onFieldSubmitted: (_) => FocusScope.of(context)
                                    .requestFocus(_confirmNode),
                              ),
                            ),
                            const SizedBox(height: 10),

                            // Thanh đánh giá độ mạnh (UI only)
                            _PasswordStrengthBar(
                                password: newPasswordController.text),

                            const SizedBox(height: 16),

                            // Xác nhận mật khẩu
                            _LabeledField(
                              label: AppLocalizations.of(context)!.confirmPassword,
                              child: TextFormField(
                                controller: confirmPasswordController,
                                focusNode: _confirmNode,
                                textInputAction: TextInputAction.done,
                                obscureText: _hideConfirm,
                                decoration: _decoration(
                                  context,
                                  hint: AppLocalizations.of(context)!.reenterNewPassword,
                                  icon: Icons.lock,
                                  isObscure: _hideConfirm,
                                  onToggle: () => setState(
                                      () => _hideConfirm = !_hideConfirm),
                                ),
                                validator: (v) {
                                  final l10n = AppLocalizations.of(context)!;
                                  if (v == null || v.trim().isEmpty) {
                                    return l10n.pleaseConfirmPassword;
                                  }
                                  if (v.trim() !=
                                      newPasswordController.text.trim()) {
                                    return l10n.passwordMismatch;
                                  }
                                  return null;
                                },
                              ),
                            ),

                            const SizedBox(height: 22),

                            // Nút đổi mật khẩu
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: _isLoading
                                    ? null
                                    : _onChangePasswordPressed,
                                style: ElevatedButton.styleFrom(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  backgroundColor:
                                      primaryColor, // dùng màu hệ thống app
                                  foregroundColor: Colors.black,
                                  disabledBackgroundColor: Colors.grey.shade300,
                                ),
                                child: _isLoading
                                    ? const SizedBox(
                                        height: 20,
                                        width: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2.4,
                                        ),
                                      )
                                    : Text(
                                        AppLocalizations.of(context)!
                                            .changePassword,
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  // =========================
  // UI helpers & actions
  // =========================

  InputDecoration _decoration(
    BuildContext context, {
    required String hint,
    required IconData icon,
    required bool isObscure,
    required VoidCallback onToggle,
  }) {
    final l10n = AppLocalizations.of(context)!;
    return InputDecoration(
      hintText: hint,
      prefixIcon: Icon(icon),
      suffixIcon: IconButton(
        onPressed: onToggle,
        icon: Icon(isObscure ? Icons.visibility_off : Icons.visibility),
        tooltip: isObscure ? l10n.showPassword : l10n.hidePassword,
      ),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: primaryColor, width: 1.6),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      filled: true,
      fillColor: Colors.white,
    );
  }

  Future<void> _onChangePasswordPressed() async {
    // Kiểm tra form trước
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final oldPass = oldPasswordController.text.trim();
    final newPass = newPasswordController.text.trim();
    final confirmPass = confirmPasswordController.text.trim();

    // Các kiểm tra bổ sung như code gốc (giữ logic)
    final l10n = AppLocalizations.of(context)!;
    if (oldPass.isEmpty || newPass.isEmpty || confirmPass.isEmpty) {
      showMessage(context, l10n.fillAllFields);
      return;
    }
    if (oldPass.length < 6 || newPass.length < 6) {
      showMessage(context, l10n.passwordMinLength);
      return;
    }
    if (newPass != confirmPass) {
      showMessage(context, l10n.passwordMismatch);
      return;
    }
    if (newPass == oldPass) {
      showMessage(context, l10n.cannotMatchOldPassword);
      return;
    }

    setState(() => _isLoading = true);
    try {
      await authService.value.resetPasswordFromCurrentPassword(
        email: email,
        password: oldPass,
        newPassword: newPass,
      );
      if (!mounted) return;
      showMessage(context, l10n.passwordChangeSuccess);
      Navigator.pop(context);
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      if (e.message ==
          'The supplied auth credential is incorrect, malformed or has expired.') {
        showMessage(context, l10n.incorrectOldPassword);
      } else {
        showMessage(context, l10n.errorOccurred(e.message ?? ''));
        // ignore: avoid_print
        print("Lỗi: ${e.message}");
      }
    } catch (e) {
      if (!mounted) return;
      showMessage(context, l10n.unknownErrorOccurred);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void showMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}

// =========================
// Sub-widgets
// =========================

class _LabeledField extends StatelessWidget {
  final String label;
  final Widget child;
  const _LabeledField({required this.label, required this.child, super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        child,
      ],
    );
  }
}

/// Thanh đánh giá độ mạnh của mật khẩu (UI-only, không thay đổi logic).
class _PasswordStrengthBar extends StatelessWidget {
  final String password;
  const _PasswordStrengthBar({required this.password, super.key});

  int _score(String p) {
    if (p.isEmpty) return 0;
    int s = 0;
    if (p.length >= 6) s++;
    if (p.length >= 10) s++;
    if (RegExp(r'[A-Z]').hasMatch(p)) s++;
    if (RegExp(r'[0-9]').hasMatch(p)) s++;
    if (RegExp(r'[^A-Za-z0-9]').hasMatch(p)) s++;
    return s.clamp(0, 4);
  }

  String _label(BuildContext context, int s) {
    final l10n = AppLocalizations.of(context)!;
    switch (s) {
      case 0:
        return l10n.passwordStrengthVeryWeak;
      case 1:
        return l10n.passwordStrengthWeak;
      case 2:
        return l10n.passwordStrengthMedium;
      case 3:
        return l10n.passwordStrengthGood;
      default:
        return l10n.passwordStrengthStrong;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final score = _score(password); // 0..4
    final segments = 4;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: List.generate(segments, (i) {
            final active = i < score;
            return Expanded(
              child: Container(
                height: 6,
                margin: EdgeInsets.only(right: i == segments - 1 ? 0 : 6),
                decoration: BoxDecoration(
                  color: active ? Colors.green : Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 6),
        Text(
          _label(context, score),
          style: theme.textTheme.bodySmall?.copyWith(
            color: Colors.black54,
          ),
        ),
      ],
    );
  }
}
