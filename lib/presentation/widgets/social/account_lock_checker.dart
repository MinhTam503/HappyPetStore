import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:pet_shop/presentation/pages/mobile/tab/bottom_navigator.dart';

/// Widget to check if user account is locked and redirect if needed
class AccountLockChecker extends StatelessWidget {
  final String userId;
  final Widget child;

  const AccountLockChecker({
    Key? key,
    required this.userId,
    required this.child,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('socialPetProfiles')
          .doc(userId)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.data!.exists) {
          final data = snapshot.data!.data() as Map<String, dynamic>?;
          final isLocked = data?['isLocked'] == true;

          if (isLocked) {
            // Account locked - show warning and prevent access
            return _buildLockedScreen(context);
          }
        }

        return child;
      },
    );
  }

  Widget _buildLockedScreen(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n?.accountLocked ?? 'Tài khoản bị khóa'),
        backgroundColor: Colors.red,
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.lock, size: 100, color: Colors.red),
              const SizedBox(height: 24),
              Text(
                'Tài khoản bị khóa',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.red,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                'Tài khoản đã bị khóa vui lòng liên hệ quản trị viên để biết thêm thông tin!',
                style: TextStyle(fontSize: 16),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: () {
                  // Navigate to home (BottomNavigator index 0)
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(
                      builder: (context) => const BottomNavigator(initialIndex: 0),
                    ),
                    (route) => false,
                  );
                },
                icon: const Icon(Icons.exit_to_app),
                label: const Text('Thoát'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
