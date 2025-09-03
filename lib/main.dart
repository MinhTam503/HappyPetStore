import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:pet_shop/auth/login_or_register.dart';
import 'package:pet_shop/auth/payment/keys.dart';
import 'package:pet_shop/bloc/cart_bloc_web/cart_bloc_web.dart';
import 'package:pet_shop/bloc/favBloc/fav_bloc.dart';
import 'package:pet_shop/debug_connection.dart';
import 'package:pet_shop/providers/locale_provider.dart';
import 'package:pet_shop/providers/theme_provider.dart';
import 'package:pet_shop/view/mobile/bottom_navigator.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:pet_shop/view/web_user/screens/cart_screen_web_new.dart';
import 'package:pet_shop/view/web_user/screens/home_page_web_user.dart';
import 'package:pet_shop/view/web_user/screens/payment_success_screen.dart';
import 'package:pet_shop/view/web/web_app_wrapper.dart';
import 'package:provider/provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:url_strategy/url_strategy.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'bloc/cartBloc/cart_bloc.dart';
import 'firebase_options.dart';
import 'core/di/service_locator.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Use path URL strategy on web to remove the `#` from routes.
  if (kIsWeb) setPathUrlStrategy();
  
  try {
    await dotenv.load();
  } catch (e) {
    // Non-fatal: if .env is missing on web or failed to load, continue with defaults.
    debugPrint('dotenv.load() failed (non-blocking): $e');
  }  
  
  // Initialize Stripe for both web and mobile
  try {
    if (PublishableKey.isNotEmpty) {
      // Initialize Stripe on both web and mobile platforms
      Stripe.publishableKey = PublishableKey;
      if (!kIsWeb) {
        await Stripe.instance.applySettings();
      }
      debugPrint('✅ Stripe initialized with publishable key: ${PublishableKey.substring(0, 20)}...');
    } else {
      debugPrint('❌ Stripe publishable key is empty; skipping Stripe initialization.');
    }
  } catch (e, st) {
    // Non-fatal: log and continue so the app can run even if Stripe init fails.
    debugPrint('❌ Stripe initialization failed: $e\n$st');
  }

  // Initialize Firebase FIRST
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  // Setup dependency injection AFTER Firebase is initialized
  serviceLocator.setup();
  
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        BlocProvider(create: (_) => CartBloc()),
        BlocProvider(create: (_) => FavBloc()),
        BlocProvider(create: (_) => CartBlocWeb()),
        BlocProvider(create: (_) => serviceLocator.createAprioriBloc()),
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
            themeMode: themeProvider.isDarkMode ? ThemeMode.dark : ThemeMode.light,
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
              if (settings.name != null && settings.name!.startsWith('/payment-success')) {
                final uri = Uri.parse(settings.name!);
                final sessionId = uri.queryParameters['session_id'];
                return MaterialPageRoute(
                  builder: (context) => PaymentSuccessScreen(sessionId: sessionId),
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
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(child: CircularProgressIndicator());
                        }
                        if (snapshot.hasData) {
                          return const BottomNavigator();
                        } else {
                          return const LoginOrRegister();
                        }
                      },
                    );
              },
              '/home': (context) => HomePageWebUser(),
              '/cart': (context) => CartScreenWeb(),
              '/debug': (context) => const DebugConnectionScreen(),
              '/payment-success': (context) {
                // Parse session_id from URL
                String? sessionId;
                if (kIsWeb) {
                  final uri = Uri.parse(WidgetsBinding.instance.window.defaultRouteName);
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
