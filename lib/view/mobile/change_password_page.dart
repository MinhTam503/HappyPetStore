import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:pet_shop/auth/auth_service.dart';
import 'package:pet_shop/utils/contants.dart';

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
          "Change Password",
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
                            "Để bảo vệ tài khoản, hãy chọn mật khẩu mạnh và khác với những nơi khác.",
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
                              label: "Mật khẩu cũ",
                              child: TextFormField(
                                controller: oldPasswordController,
                                focusNode: _oldNode,
                                textInputAction: TextInputAction.next,
                                obscureText: _hideOld,
                                decoration: _decoration(
                                  context,
                                  hint: "Nhập mật khẩu cũ",
                                  icon: Icons.lock_outline,
                                  isObscure: _hideOld,
                                  onToggle: () => setState(() => _hideOld = !_hideOld),
                                ),
                                validator: (v) {
                                  if (v == null || v.trim().isEmpty) {
                                    return "Vui lòng nhập mật khẩu cũ";
                                  }
                                  if (v.trim().length < 6) {
                                    return "Mật khẩu phải từ 6 kí tự";
                                  }
                                  return null;
                                },
                                onFieldSubmitted: (_) =>
                                    FocusScope.of(context).requestFocus(_newNode),
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Mật khẩu mới
                            _LabeledField(
                              label: "Mật khẩu mới",
                              child: TextFormField(
                                controller: newPasswordController,
                                focusNode: _newNode,
                                textInputAction: TextInputAction.next,
                                obscureText: _hideNew,
                                decoration: _decoration(
                                  context,
                                  hint: "Nhập mật khẩu mới",
                                  icon: Icons.lock_reset,
                                  isObscure: _hideNew,
                                  onToggle: () => setState(() => _hideNew = !_hideNew),
                                ),
                                onChanged: (_) => setState(() {}),
                                validator: (v) {
                                  if (v == null || v.trim().isEmpty) {
                                    return "Vui lòng nhập mật khẩu mới";
                                  }
                                  if (v.trim().length < 6) {
                                    return "Mật khẩu phải từ 6 kí tự";
                                  }
                                  if (v.trim() == oldPasswordController.text.trim()) {
                                    return "Không thể trùng mật khẩu cũ";
                                  }
                                  return null;
                                },
                                onFieldSubmitted: (_) => FocusScope.of(context)
                                    .requestFocus(_confirmNode),
                              ),
                            ),
                            const SizedBox(height: 10),

                            // Thanh đánh giá độ mạnh (UI only)
                            _PasswordStrengthBar(password: newPasswordController.text),

                            const SizedBox(height: 16),

                            // Xác nhận mật khẩu
                            _LabeledField(
                              label: "Xác nhận mật khẩu",
                              child: TextFormField(
                                controller: confirmPasswordController,
                                focusNode: _confirmNode,
                                textInputAction: TextInputAction.done,
                                obscureText: _hideConfirm,
                                decoration: _decoration(
                                  context,
                                  hint: "Nhập lại mật khẩu mới",
                                  icon: Icons.lock,
                                  isObscure: _hideConfirm,
                                  onToggle: () => setState(() => _hideConfirm = !_hideConfirm),
                                ),
                                validator: (v) {
                                  if (v == null || v.trim().isEmpty) {
                                    return "Vui lòng xác nhận mật khẩu";
                                  }
                                  if (v.trim() != newPasswordController.text.trim()) {
                                    return "Mật khẩu mới không khớp";
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
                                onPressed: _isLoading ? null : _onChangePasswordPressed,
                                style: ElevatedButton.styleFrom(
                                  padding:
                                  const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  backgroundColor: primaryColor, // dùng màu hệ thống app
                                  foregroundColor: Colors.black,
                                  disabledBackgroundColor:
                                  Colors.grey.shade300,
                                ),
                                child: _isLoading
                                    ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.4,
                                  ),
                                )
                                    : const Text(
                                  "Đổi mật khẩu",
                                  style: TextStyle(
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
    return InputDecoration(
      hintText: hint,
      prefixIcon: Icon(icon),
      suffixIcon: IconButton(
        onPressed: onToggle,
        icon: Icon(isObscure ? Icons.visibility_off : Icons.visibility),
        tooltip: isObscure ? "Hiện mật khẩu" : "Ẩn mật khẩu",
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
    if (oldPass.isEmpty || newPass.isEmpty || confirmPass.isEmpty) {
      showMessage(context, "Vui lòng điền đầy đủ thông tin");
      return;
    }
    if (oldPass.length < 6 || newPass.length < 6) {
      showMessage(context, "Mật khẩu phải từ 6 kí tự");
      return;
    }
    if (newPass != confirmPass) {
      showMessage(context, "Mật khẩu mới không khớp");
      return;
    }
    if (newPass == oldPass) {
      showMessage(context, "Không thể trùng mật khẩu");
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
      showMessage(context, "Đổi mật khẩu thành công!");
      Navigator.pop(context);
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      if (e.message ==
          'The supplied auth credential is incorrect, malformed or has expired.') {
        showMessage(context, "Mật khẩu cũ không chính xác");
      } else {
        showMessage(context, "Lỗi: ${e.message}");
        // ignore: avoid_print
        print("Lỗi: ${e.message}");
      }
    } catch (e) {
      if (!mounted) return;
      showMessage(context, "Lỗi không xác định: ${e.toString()}");
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

  String _label(int s) {
    switch (s) {
      case 0:
        return "Rất yếu";
      case 1:
        return "Yếu";
      case 2:
        return "Trung bình";
      case 3:
        return "Khá";
      default:
        return "Mạnh";
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
          _label(score),
          style: theme.textTheme.bodySmall?.copyWith(
            color: Colors.black54,
          ),
        ),
      ],
    );
  }
}
