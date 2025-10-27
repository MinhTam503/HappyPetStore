import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:pet_shop/core/di/vnpay_di.dart';
import 'package:pet_shop/presentation/bloc/vnpay/vnpay_bloc.dart';

/// Example: Cách setup VNPay BLoC trong main.dart
/// 
/// Đây là ví dụ cách tích hợp VNPay vào ứng dụng của bạn

final sl = GetIt.instance;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 1. Initialize VNPay Dependency Injection
  VnpayDependencyInjection.init(sl);
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        // 2. Provide VNPay BLoC globally
        BlocProvider(
          create: (context) => sl<VnpayBloc>(),
        ),
        
        // Add other BLoCs here...
        // BlocProvider(create: (context) => CartBloc(...)),
        // BlocProvider(create: (context) => AuthBloc(...)),
      ],
      child: MaterialApp(
        title: 'HappyPet Store',
        home: const HomePage(),
      ),
    );
  }
}

class HomePage extends StatelessWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Home')),
      body: const Center(
        child: Text('VNPay Integration Example'),
      ),
    );
  }
}

/// Example: Cách sử dụng VNPay trong một screen
/// 
/// ```dart
/// import 'package:flutter/material.dart';
/// import 'package:flutter_bloc/flutter_bloc.dart';
/// import 'package:pet_shop/presentation/bloc/vnpay/vnpay_bloc.dart';
/// import 'package:pet_shop/presentation/bloc/vnpay/vnpay_event.dart';
/// import 'package:pet_shop/presentation/bloc/vnpay/vnpay_state.dart';
/// 
/// class PaymentScreen extends StatelessWidget {
///   final String orderId;
///   final double amount;
///   
///   const PaymentScreen({
///     Key? key,
///     required this.orderId,
///     required this.amount,
///   }) : super(key: key);
/// 
///   @override
///   Widget build(BuildContext context) {
///     return BlocListener<VnpayBloc, VnpayState>(
///       listener: (context, state) {
///         if (state is VnpayPaymentUrlCreated) {
///           // Open payment URL
///           final url = state.payment.paymentUrl;
///           if (url != null) {
///             // Launch URL...
///           }
///         } else if (state is VnpayError) {
///           // Show error
///           ScaffoldMessenger.of(context).showSnackBar(
///             SnackBar(content: Text(state.message)),
///           );
///         }
///       },
///       child: Scaffold(
///         appBar: AppBar(title: const Text('Payment')),
///         body: Center(
///           child: ElevatedButton(
///             onPressed: () {
///               // Trigger payment
///               context.read<VnpayBloc>().add(
///                 CreateVnpayPayment(
///                   orderId: orderId,
///                   amount: amount,
///                   orderInfo: 'Payment for order $orderId',
///                   returnUrl: 'happypetstore://vnpay-return',
///                 ),
///               );
///             },
///             child: const Text('Pay with VNPay'),
///           ),
///         ),
///       ),
///     );
///   }
/// }
/// ```
