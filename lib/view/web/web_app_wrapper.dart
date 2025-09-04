import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:pet_shop/view/web/screen_admin/home/home_page_admin.dart';
import 'package:pet_shop/view/web_user/screens/payment_success_screen.dart';

class WebAppWrapper extends StatefulWidget {
  const WebAppWrapper({Key? key}) : super(key: key);

  @override
  State<WebAppWrapper> createState() => _WebAppWrapperState();
}

class _WebAppWrapperState extends State<WebAppWrapper> {
  String? _sessionId;
  bool _isPaymentSuccess = false;

  @override
  void initState() {
    super.initState();
    _checkForPaymentSuccess();
  }

  void _checkForPaymentSuccess() {
    if (kIsWeb) {
      final currentUrl = WidgetsBinding.instance.window.defaultRouteName;
      if (kDebugMode) {
        print('🔍 Current URL: $currentUrl');
      }
      
      if (currentUrl.contains('/payment-success')) {
        try {
          final uri = Uri.parse(currentUrl);
          final sessionId = uri.queryParameters['session_id'];
          
          if (sessionId != null && sessionId.isNotEmpty) {
            setState(() {
              _sessionId = sessionId;
              _isPaymentSuccess = true;
            });
            
            if (kDebugMode) {
              print(' Payment success detected with session ID: $sessionId');
            }
          }
        } catch (e) {
          if (kDebugMode) {
            print(' Error parsing payment success URL: $e');
          }
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isPaymentSuccess) {
      return PaymentSuccessScreen(sessionId: _sessionId);
    }
    
    return const HomePageAdmin();
  }
}
