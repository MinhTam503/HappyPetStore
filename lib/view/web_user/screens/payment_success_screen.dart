import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class PaymentSuccessScreen extends StatefulWidget {
  final String? sessionId;
  
  const PaymentSuccessScreen({Key? key, this.sessionId}) : super(key: key);

  @override
  State<PaymentSuccessScreen> createState() => _PaymentSuccessScreenState();
}

class _PaymentSuccessScreenState extends State<PaymentSuccessScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

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

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeIn,
    ));

    _animationController.forward();

    if (kDebugMode) {
      print('✅ Payment Success Screen loaded with session ID: ${widget.sessionId}');
    }
    
    // Save order info if session ID is available
    if (widget.sessionId != null) {
      _saveSuccessfulOrder();
    }
  }

  Future<void> _saveSuccessfulOrder() async {
    try {
      if (kDebugMode) {
        print('💳 Looking for pending order to update with session: ${widget.sessionId}');
      }
      
      // Strategy 1: Find by timestamp first, then filter by tempOrderId  
      final recentOrders = await FirebaseFirestore.instance
          .collection('ordersWeb')
          .orderBy('timestamp', descending: true)
          .limit(30)
          .get();
      
      DocumentSnapshot? orderToUpdate;
      
      // Look for orders with tempOrderId starting with "temp_"
      for (final doc in recentOrders.docs) {
        final data = doc.data();
        final tempId = data['tempOrderId']?.toString();
        
        if (tempId != null && tempId.startsWith('temp_')) {
          // Check if this is a recent order (within 2 hours)
          final timestamp = data['timestamp'] as Timestamp?;
          if (timestamp != null) {
            final orderTime = timestamp.toDate();
            final timeDiff = DateTime.now().difference(orderTime).inHours;
            
            if (timeDiff <= 2 && data['statusPayment'] == 'Pending Payment') {
              orderToUpdate = doc;
              if (kDebugMode) {
                print('🔍 Found pending order by tempOrderId: ${doc.id}');
                print('🔍 TempOrderId: $tempId');
                print('🔍 Customer: ${data['fullName']}');
              }
              break;
            }
          }
        }
      }
      
      // Strategy 2: Fallback - find recent pending orders
      if (orderToUpdate == null) {
        if (kDebugMode) {
          print('⚠️ No order found by tempOrderId, trying timestamp strategy...');
        }
        
        final allRecentOrders = await FirebaseFirestore.instance
            .collection('ordersWeb')
            .orderBy('timestamp', descending: true)
            .limit(20)
            .get();
        
        for (final doc in allRecentOrders.docs) {
          final data = doc.data();
          final timestamp = data['timestamp'] as Timestamp?;
          
          if (timestamp != null) {
            final orderTime = timestamp.toDate();
            final timeDiff = DateTime.now().difference(orderTime).inMinutes;
            
            if (timeDiff <= 30 && // Within 30 minutes
                data['statusPayment'] == 'Pending Payment' && 
                data['tempOrderId'] != null) {
              orderToUpdate = doc;
              if (kDebugMode) {
                print('🔍 Found pending order by timestamp: ${doc.id} (${timeDiff} minutes ago)');
              }
              break;
            }
          }
        }
      }
          
      if (orderToUpdate != null) {
        // Update the pending order with session ID
        await orderToUpdate.reference.update({
          "stripeSessionId": widget.sessionId,
          "statusPayment": "Payment Completed",
          "statusOrder": "Completed",
          "paymentConfirmedAt": FieldValue.serverTimestamp(),
          "tempOrderId": FieldValue.delete(), // Remove temp field
        });
        
        if (kDebugMode) {
          print('✅ Updated pending order with session ID: ${orderToUpdate.id}');
          final data = orderToUpdate.data() as Map<String, dynamic>?;
          print('✅ Order customer: ${data?['fullName'] ?? 'Unknown'}');
          print('✅ Order total: \$${data?['totalAmount'] ?? 0}');
          print('✅ Items count: ${(data?['items'] as List?)?.length ?? 0}');
        }
      } else {
        if (kDebugMode) {
          print('❌ NO PENDING ORDERS FOUND - This should not happen!');
          print('❌ Available orders in collection:');
          
          // Debug: List recent orders
          final debugOrders = await FirebaseFirestore.instance
              .collection('ordersWeb')
              .orderBy('timestamp', descending: true)
              .limit(5)
              .get();
              
          for (final doc in debugOrders.docs) {
            final data = doc.data();
            print('📋 Order ${doc.id}: status=${data['statusPayment']}, tempId=${data['tempOrderId']}');
          }
        }
        
        // This should NOT happen anymore, but keep as safeguard
        if (kDebugMode) {
          print('⚠️ Creating minimal fallback order (this indicates a bug)');
        }
        
        final orderRef = FirebaseFirestore.instance.collection('ordersWeb').doc();
        await orderRef.set({
          "orderId": orderRef.id,
          "stripeSessionId": widget.sessionId,
          "statusPayment": "Payment Completed",
          "statusOrder": "Completed",
          "timestamp": FieldValue.serverTimestamp(),
          "paymentMethod": "stripe_web",
          "source": "web_checkout_fallback",
        });
        
        if (kDebugMode) {
          print('✅ Created fallback order: ${orderRef.id}');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error updating order payment status: $e');
      }
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Success Animation
                AnimatedBuilder(
                  animation: _scaleAnimation,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: _scaleAnimation.value,
                      child: Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [
                              Colors.green.shade400,
                              Colors.green.shade600,
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.green.withOpacity(0.3),
                              blurRadius: 20,
                              spreadRadius: 5,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.check_rounded,
                          color: Colors.white,
                          size: 60,
                        ),
                      ),
                    );
                  },
                ),
                
                const SizedBox(height: 32),
                
                // Success Text
                FadeTransition(
                  opacity: _fadeAnimation,
                  child: Column(
                    children: [
                      Text(
                        'Thanh toán thành công!',
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.green.shade700,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      
                      const SizedBox(height: 16),
                      
                      Text(
                        'Cảm ơn bạn đã mua sắm tại Pet Shop!\nĐơn hàng của bạn đang được xử lý.',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: Colors.grey.shade600,
                          height: 1.5,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 48),
                
                // Order Details Card
                if (widget.sessionId != null)
                  FadeTransition(
                    opacity: _fadeAnimation,
                    child: Container(
                      width: double.infinity,
                      constraints: const BoxConstraints(maxWidth: 400),
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.grey.shade200,
                          width: 1,
                        ),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.receipt_long_rounded,
                                color: Colors.grey.shade600,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Mã đơn hàng',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey.shade700,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          SelectableText(
                            widget.sessionId!,
                            style: TextStyle(
                              fontFamily: 'monospace',
                              color: Colors.grey.shade600,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                
                const SizedBox(height: 48),
                
                // Action Buttons
                FadeTransition(
                  opacity: _fadeAnimation,
                  child: Column(
                    children: [
                      Container(
                        width: double.infinity,
                        constraints: const BoxConstraints(maxWidth: 300),
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.of(context).pushNamedAndRemoveUntil(
                              '/home',
                              (route) => false,
                            );
                          },
                          icon: const Icon(Icons.home_rounded),
                          label: const Text('Về trang chủ'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green.shade600,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                      
                      const SizedBox(height: 12),
                      
                      Container(
                        width: double.infinity,
                        constraints: const BoxConstraints(maxWidth: 300),
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Navigator.of(context).pushNamedAndRemoveUntil(
                              '/cart',
                              (route) => false,
                            );
                          },
                          icon: const Icon(Icons.shopping_cart_rounded),
                          label: const Text('Tiếp tục mua sắm'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.green.shade600,
                            side: BorderSide(color: Colors.green.shade600),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
