import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:pet_shop/auth/login_or_register.dart';
import 'package:pet_shop/auth/payment/keys.dart';
import 'package:pet_shop/bloc/favBloc/fav_bloc.dart';
import 'package:pet_shop/view/mobile/bottom_navigator.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:pet_shop/view/web/screen_admin/home/home_page_admin.dart';
import 'package:pet_shop/view/web_user/screens/home_page_web_user.dart';
import 'package:provider/provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:url_strategy/url_strategy.dart';
import 'bloc/cartBloc/cart_bloc.dart';
import 'firebase_options.dart';

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
  if (!kIsWeb) {
    // Only initialize Stripe if a publishable key is available. dotenv.load()
    // may fail (for example when .env is missing), so skip Stripe init to
    // avoid platform exceptions from the native plugin.
    try {
      if (PublishableKey.isNotEmpty) {
        Stripe.publishableKey = PublishableKey;
        await Stripe.instance.applySettings();
      } else {
        debugPrint('Stripe publishable key is empty; skipping Stripe initialization.');
      }
    } catch (e, st) {
      // Non-fatal: log and continue so the app can run even if Stripe init fails.
      debugPrint('Stripe initialization failed: $e\n$st');
    }
  }

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
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
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        initialRoute: '/',
        // home: kIsWeb
        //     ? const HomePageAdmin()
        //     : StreamBuilder<User?>(
        //         stream: FirebaseAuth.instance.authStateChanges(),
        //         builder: (context, snapshot) {
        //           if (snapshot.connectionState == ConnectionState.waiting) {
        //             return const Center(child: CircularProgressIndicator());
        //           }
        //           if (snapshot.hasData) {
        //             return const BottomNavigator();
        //           } else {
        //             return const LoginOrRegister();
        //           }
        //         },
        //       ),
        routes: {
          '/': (context) => kIsWeb
              ? const HomePageAdmin()
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
                ),
          '/home': (context) => HomePageWebUser(),
        },
      ),
    );
  }
}
