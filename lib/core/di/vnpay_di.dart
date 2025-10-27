import 'package:get_it/get_it.dart';
import 'package:pet_shop/data/datasources/vnpay_service.dart';
import 'package:pet_shop/data/repositories/vnpay_repository_impl.dart';
import 'package:pet_shop/domain/repositories/vnpay_repository.dart';
import 'package:pet_shop/domain/usecases/create_vnpay_payment_url.dart';
import 'package:pet_shop/domain/usecases/verify_vnpay_payment.dart';
import 'package:pet_shop/presentation/bloc/vnpay/vnpay_bloc.dart';

/// VNPay Dependency Injection Setup
/// Sử dụng GetIt để quản lý dependencies theo Clean Architecture
class VnpayDependencyInjection {
  static void init(GetIt sl) {
    // BLoC
    sl.registerFactory(
      () => VnpayBloc(
        createPaymentUrl: sl(),
        verifyPayment: sl(),
      ),
    );

    // Use Cases
    sl.registerLazySingleton(() => CreateVnpayPaymentUrl(sl()));
    sl.registerLazySingleton(() => VerifyVnpayPayment(sl()));

    // Repository
    sl.registerLazySingleton<VnpayRepository>(
      () => VnpayRepositoryImpl(sl()),
    );

    // Data Source
    sl.registerLazySingleton(() => VnpayService());
  }
}

// Example usage in main.dart:
/*
import 'package:get_it/get_it.dart';
import 'package:pet_shop/core/di/vnpay_di.dart';

final sl = GetIt.instance;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize VNPay DI
  VnpayDependencyInjection.init(sl);
  
  runApp(MyApp());
}

// Trong widget tree, inject VNPay BLoC:
BlocProvider(
  create: (context) => sl<VnpayBloc>(),
  child: CartScreen(),
)
*/
