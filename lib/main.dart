import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:pet_shop/auth/login_or_register.dart';
import 'package:pet_shop/auth/stripe_helper.dart';
import 'package:pet_shop/data/repositories/notification_repository.dart';
import 'package:pet_shop/data/repositories/viewed_pets/recent_pets_repository_impl.dart';
import 'package:pet_shop/presentation/bloc/cart_bloc_web/cart_bloc_web.dart';
import 'package:pet_shop/presentation/bloc/favBloc/fav_bloc.dart';
import 'package:pet_shop/debug_connection.dart';
import 'package:pet_shop/core/providers/locale_provider.dart';
import 'package:pet_shop/core/providers/theme_provider.dart';
import 'package:pet_shop/presentation/bloc/notification/notification_bloc.dart';
import 'package:pet_shop/presentation/bloc/popularBloc/popular_bloc.dart';
import 'package:pet_shop/presentation/bloc/viewedPets/recent_pets_bloc.dart';
import 'package:pet_shop/presentation/bloc/viewedPets/recent_pets_event.dart';
import 'package:pet_shop/presentation/pages/mobile/tab/bottom_navigator.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:pet_shop/presentation/pages/web_user/screens/cart_screen_web_new.dart';
import 'package:pet_shop/presentation/pages/web_user/screens/home_page_web_user.dart';
import 'package:pet_shop/presentation/pages/web_user/screens/payment_success_screen.dart';
import 'package:pet_shop/presentation/pages/web/web_app_wrapper.dart';
import 'package:provider/provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:url_strategy/url_strategy.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'presentation/bloc/cartBloc/cart_bloc.dart';
import 'firebase_options.dart';
import 'core/di/service_locator.dart';
import 'core/service_locator.dart' as chatbot_sl;
import 'core/services/user_manager.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Use path URL strategy on web to remove the `#` from routes.
  if (kIsWeb) setPathUrlStrategy();

  // Initialize Firebase FIRST to avoid performance issues
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  try {
    await dotenv.load(fileName: ".env");
    if (kDebugMode) {
      debugPrint(' Environment variables loaded successfully');
    }
  } catch (e) {
    // Non-fatal: if .env is missing on web or failed to load, continue with defaults.
    if (kDebugMode) {
      debugPrint(' dotenv.load() failed (non-blocking): $e');
      debugPrint(' App will continue with hardcoded fallback values');
    }
  }

  // Initialize Stripe using helper
  final stripeInitialized = await StripeHelper.initialize();
  if (!stripeInitialized && kDebugMode) {
    debugPrint('Stripe initialization failed, payment features may not work');
  }

  // Setup dependency injection AFTER Firebase is initialized
  serviceLocator.setup();

  // Initialize ChatBot dependencies
  await chatbot_sl.setupServiceLocator();

  // Initialize UserManager for centralized user state management
  await userManager.initialize();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        BlocProvider(create: (_) => CartBloc()),
        BlocProvider(create: (_) => FavBloc()),
        BlocProvider(create: (_) => CartBlocWeb()),
        BlocProvider(create: (_) => PopularBloc()),
        BlocProvider(
            create: (_) => NotificationBloc(
                notificationRepository: NotificationRepository())),
        BlocProvider(create: (_) => serviceLocator.createAprioriBloc()),
        BlocProvider(
          create: (_) =>
              RecentPetsBloc(RecentPetsRepositoryImpl())..add(LoadRecentPets()),
        ),
        ChangeNotifierProvider(create: (_) => LocaleProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
      ],
      child: Consumer2<LocaleProvider, ThemeProvider>(
        builder: (context, localeProvider, themeProvider, child) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            initialRoute: '/',
            theme: themeProvider.lightTheme,
            darkTheme: themeProvider.darkTheme,
            themeMode:
                themeProvider.isDarkMode ? ThemeMode.dark : ThemeMode.light,
            locale: localeProvider.locale,
            supportedLocales: LocaleProvider.supportedLocales,
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            onGenerateRoute: (settings) {
              // Handle payment success URL with query parameters
              if (settings.name != null &&
                  settings.name!.startsWith('/payment-success')) {
                final uri = Uri.parse(settings.name!);
                final sessionId = uri.queryParameters['session_id'];
                return MaterialPageRoute(
                  builder: (context) =>
                      PaymentSuccessScreen(sessionId: sessionId),
                  settings: settings,
                );
              }

              // Default routes
              return null;
            },
            routes: {
              '/': (context) {
                return kIsWeb
                    ? const WebAppWrapper()
                    : StreamBuilder<User?>(
                        stream: FirebaseAuth.instance.authStateChanges(),
                        builder: (context, snapshot) {
                          if (kDebugMode) {
                            debugPrint(
                                ' AuthState: ${snapshot.connectionState}, hasData: ${snapshot.hasData}, user: ${snapshot.data?.uid}');
                          }

                          // Show loading during connection state waiting
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const Scaffold(
                              body: Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    CircularProgressIndicator(
                                        color: Colors.pink),
                                    SizedBox(height: 16),
                                    Text(
                                        'Đang kiểm tra trạng thái đăng nhập...'),
                                  ],
                                ),
                              ),
                            );
                          }

                          // User is authenticated
                          if (snapshot.hasData) {
                            final user = snapshot.data!;

                            if (kDebugMode) {
                              debugPrint(
                                  'User authenticated: ${user.uid}, emailVerified: ${user.emailVerified}');
                            }

                            // Check authentication provider
                            List<String> providers = user.providerData
                                .map((info) => info.providerId)
                                .toList();
                            bool isSocialLogin =
                                providers.contains('google.com') ||
                                    providers.contains('facebook.com') ||
                                    providers.contains('phone');

                            // Allow social login users to bypass email verification
                            // Email/password users still need email verification
                            if (user.emailVerified || isSocialLogin) {
                              if (kDebugMode) {
                                debugPrint(
                                    ' User verified (email: ${user.emailVerified}, social: $isSocialLogin), navigating to BottomNavigator');
                              }
                              return const BottomNavigator();
                            } else {
                              if (kDebugMode) {
                                debugPrint(
                                    ' Email not verified and not social login, showing LoginOrRegister');
                              }
                              return const LoginOrRegister();
                            }
                          } else {
                            // User is not authenticated
                            if (kDebugMode) {
                              debugPrint(
                                  ' User not authenticated, showing LoginOrRegister');
                            }
                            return const LoginOrRegister();
                          }
                        },
                      );
              },
              '/home': (context) => const HomePageWebUser(),
              '/cart': (context) => const CartScreenWeb(),
              '/debug': (context) => const DebugConnectionScreen(),
            
              '/payment-success': (context) {
                // Parse session_id from URL
                String? sessionId;
                if (kIsWeb) {
                  final uri = Uri.parse(
                      WidgetsBinding.instance.window.defaultRouteName);
                  sessionId = uri.queryParameters['session_id'];
                }
                return PaymentSuccessScreen(sessionId: sessionId);
              },
            },
          );
        },
      ),
    );
  }
}
