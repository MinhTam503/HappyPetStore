import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:pet_shop/auth/login_or_register.dart';
import 'package:pet_shop/auth/stripe_helper.dart';
import 'package:pet_shop/core/di/recommendation_di.dart';
import 'package:pet_shop/core/services/onboarding_service.dart';
import 'package:pet_shop/core/services/recommendation_tracking_service.dart';
import 'package:pet_shop/core/services/search_recommendations_manager.dart';
import 'package:pet_shop/core/services/settings_service.dart';
import 'package:pet_shop/data/datasources/vnpay_service.dart';
import 'package:pet_shop/data/repositories/group_chat_repository_impl.dart';
import 'package:pet_shop/data/repositories/notification_repository.dart';
import 'package:pet_shop/data/repositories/viewed_pets/recent_pets_repository_impl.dart';
import 'package:pet_shop/data/repositories/vnpay_repository_impl.dart';
import 'package:pet_shop/domain/usecases/create_vnpay_payment_url.dart';
import 'package:pet_shop/domain/usecases/verify_vnpay_payment.dart';
import 'package:pet_shop/presentation/bloc/cart_bloc_web/cart_bloc_web.dart';
import 'package:pet_shop/presentation/bloc/favBloc/fav_bloc.dart';
import 'package:pet_shop/presentation/bloc/group_chat/group_chat_bloc.dart';
import 'package:pet_shop/presentation/bloc/recommendation/recommendation_bloc.dart';
import 'package:pet_shop/core/providers/locale_provider.dart';
import 'package:pet_shop/core/providers/theme_provider.dart';
import 'package:pet_shop/presentation/bloc/notification/notification_bloc.dart';
import 'package:pet_shop/presentation/bloc/popularBloc/popular_bloc.dart';
import 'package:pet_shop/presentation/bloc/viewedPets/recent_pets_bloc.dart';
import 'package:pet_shop/presentation/bloc/viewedPets/recent_pets_event.dart';
import 'package:pet_shop/presentation/bloc/vnpay/vnpay_bloc.dart';
import 'package:pet_shop/presentation/bloc/social/social_bloc.dart';
import 'package:pet_shop/presentation/bloc/chat/chat_bloc.dart';
import 'package:pet_shop/data/repositories/social_repository_impl.dart';
import 'package:pet_shop/data/repositories/user_chat_repository_impl.dart';
import 'package:pet_shop/domain/entities/social_pet_profile.dart';
import 'package:pet_shop/domain/entities/social_post.dart';
import 'package:pet_shop/presentation/pages/mobile/social/create_post_page.dart';
import 'package:pet_shop/presentation/pages/mobile/social/social_search_page.dart';
import 'package:pet_shop/presentation/pages/mobile/social/social_profile_page.dart';
import 'package:pet_shop/presentation/pages/mobile/social/edit_social_profile_page.dart';
import 'package:pet_shop/presentation/pages/mobile/social/edit_post_page.dart';
import 'package:pet_shop/presentation/pages/mobile/social/followers_list_page.dart';
import 'package:pet_shop/presentation/pages/mobile/social/chat_list_page_with_tabs.dart';
import 'package:pet_shop/presentation/pages/mobile/social/chat/chat_room_page.dart';
import 'package:pet_shop/presentation/pages/mobile/social/chat_group/group_chat_room_page.dart';
// import 'package:pet_shop/presentation/pages/mobile/pet/ar_viewer_page.dart';
import 'package:pet_shop/presentation/pages/mobile/get_started/get_started_page.dart';
import 'package:pet_shop/presentation/pages/mobile/tab/bottom_navigator.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:pet_shop/presentation/pages/web/screen_admin/shipping/shipping_management_page.dart';
import 'package:pet_shop/presentation/pages/web/screen_admin/order/orders_admin.dart';
import 'package:pet_shop/presentation/pages/web/screen_admin/home/home_page_admin.dart';
import 'package:pet_shop/presentation/pages/web/screen_admin/dashboard/dashboard_page.dart';
import 'package:pet_shop/presentation/pages/web/screen_admin/pet/pets_admin.dart';
import 'package:pet_shop/presentation/pages/web/screen_admin/category/category_admin.dart';
import 'package:pet_shop/presentation/pages/web/screen_admin/account/account_admin.dart';
import 'package:pet_shop/presentation/pages/web/screen_admin/notification/notification_management_panel.dart';
import 'package:pet_shop/presentation/pages/web/screen_admin/revenue/revenue_page.dart';
import 'package:pet_shop/presentation/pages/web/screen_admin/pet_analytics/pet_analytics_page.dart';
import 'package:pet_shop/presentation/pages/web/screen_admin/chat/inbox_page_admin.dart';
import 'package:pet_shop/presentation/pages/web/screen_admin/chat/ChatDetailPage.dart';
import 'package:pet_shop/presentation/pages/web/screen_admin/shop_info/shop_info.dart';
import 'package:pet_shop/presentation/pages/web/screen_admin/theme/theme_settings_admin.dart';
import 'package:pet_shop/core/services/theme_manager.dart';
import 'package:pet_shop/presentation/widgets/seasonal_effects_overlay.dart';
import 'package:pet_shop/presentation/pages/web_user/screens/cart_screen_web_new.dart';
import 'package:pet_shop/presentation/pages/web_user/screens/home/home_page_web_user.dart';
import 'package:pet_shop/presentation/pages/web_user/screens/payment_success_screen.dart';
import 'package:pet_shop/presentation/pages/web_user/screens/details/pet_detail_screen_web.dart';
import 'package:pet_shop/presentation/pages/web/web_app_wrapper.dart';
import 'package:provider/provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:url_strategy/url_strategy.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:pet_shop/presentation/pages/mobile/chat/chat_page.dart'
    as mobile_chat;
import 'presentation/bloc/cartBloc/cart_bloc.dart';
import 'firebase_options.dart';
import 'core/di/service_locator.dart';
import 'core/service_locator.dart' as chatbot_sl;
import 'core/services/user_manager.dart';
import 'core/services/push_notification_service.dart';

final GlobalKey<NavigatorState> _navKey = GlobalKey<NavigatorState>();

Future<void> main() async {
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

  // Initialize push notifications (Android)
  try {
    await PushNotificationService.initialize();
    // Register navigation handler for notification taps
    PushNotificationService.registerTapHandler((payload, data) {
      if (kIsWeb) return; // only handle on mobile app
      final nav = _navKey.currentState;
      if (nav == null) return;
      // Basic routing: chat notifications go to ChatPage
      final route = (payload ?? data?['route'] as String?) ?? '';
      if (route == 'chat' || data?['type'] == 'chat') {
        nav.push(
            MaterialPageRoute(builder: (_) => const mobile_chat.ChatPage()));
        return;
      }
    });
  } catch (e) {
    if (kDebugMode) {
      debugPrint('❌ Failed to initialize push notifications: $e');
    }
  }

  // Initialize recommendation system
  try {
    await setupRecommendationDI();
    await RecommendationTrackingService().initialize();

    // Initialize search recommendations manager with auto-refresh
    await SearchRecommendationsManager().initialize();

    if (kDebugMode) {
      debugPrint('🎯 Recommendation system initialized successfully');
    }
  } catch (e) {
    if (kDebugMode) {
      debugPrint('❌ Failed to initialize recommendation system: $e');
    }
  }

  // Load initial theme preference on mobile
  if (!kIsWeb) {
    try {
      final settingsService = SettingsService();
      final useAdminTheme = await settingsService.getUseAdminTheme();
      // Ensure stream gets initial value by setting it
      await settingsService.setUseAdminTheme(useAdminTheme);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Failed to load theme preference: $e');
      }
    }
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final service = VnpayService();
    final repository = VnpayRepositoryImpl(service);
    return MultiProvider(
      providers: [
        BlocProvider(create: (_) => CartBloc()),
        BlocProvider(create: (_) => FavBloc()),
        BlocProvider(create: (_) => CartBlocWeb()),
        BlocProvider(create: (_) => PopularBloc()),
        BlocProvider(
            create: (_) => VnpayBloc(
                  createPaymentUrl: CreateVnpayPaymentUrl(repository),
                  verifyPayment: VerifyVnpayPayment(repository),
                )),
        BlocProvider(
            create: (_) => NotificationBloc(
                notificationRepository: NotificationRepository())),
        BlocProvider(create: (_) => serviceLocator.createAprioriBloc()),
        BlocProvider(
          create: (_) => RecentPetsBloc(RecentPetsRepositoryImpl(
            settingsService: SettingsService(),
          ))
            ..add(LoadRecentPets()),
        ),
        BlocProvider(create: (_) => getIt<RecommendationBloc>()),
        BlocProvider(
            create: (_) => SocialBloc(repository: SocialRepositoryImpl())),
        BlocProvider(
            create: (_) => ChatBloc(
                  chatRepository: UserChatRepositoryImpl(),
                  socialRepository: SocialRepositoryImpl(),
                )),
        BlocProvider(
            create: (_) => GroupChatBloc(
                  repository: GroupChatRepositoryImpl(),
                )),
        ChangeNotifierProvider(create: (_) => LocaleProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
      ],
      child: Consumer2<LocaleProvider, ThemeProvider>(
          builder: (context, localeProvider, themeProvider, child) {
        final themeManager = ThemeManager();
        final settingsService = SettingsService();
        
        return StreamBuilder<SeasonalTheme>(
          stream: themeManager.stream,
          initialData: themeManager.current,
          builder: (context, themeSnapshot) {
            return StreamBuilder<bool>(
              stream: settingsService.useAdminThemeStream,
              initialData: true,
              builder: (context, settingsSnapshot) {
                final useAdminTheme = settingsSnapshot.data ?? true;
                final adminTheme = themeSnapshot.data ?? SeasonalTheme.defaultTheme;
                
                // On web (admin panel), always use default theme
                // On mobile, use admin theme if enabled, otherwise default
                final currentTheme = kIsWeb 
                    ? SeasonalTheme.defaultTheme 
                    : (useAdminTheme ? adminTheme : SeasonalTheme.defaultTheme);
                
                final lightScheme =
                    themeManager.colorSchemeFor(currentTheme, Brightness.light, isWebAdmin: kIsWeb);
                final darkScheme =
                    themeManager.colorSchemeFor(currentTheme, Brightness.dark, isWebAdmin: kIsWeb);

            return MaterialApp(
              navigatorKey: _navKey,
              debugShowCheckedModeBanner: false,
              initialRoute: '/',
              theme: ThemeData(colorScheme: lightScheme, useMaterial3: true),
              darkTheme: ThemeData(colorScheme: darkScheme, useMaterial3: true),
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

                // Web User deep links
                if (kIsWeb && settings.name != null) {
                  final uri = Uri.parse(settings.name!);
                  final segs = uri.pathSegments;
                  // Preferred: /home/pet/:id
                  if (segs.length >= 3 &&
                      segs[0] == 'home' &&
                      segs[1] == 'pet') {
                    final petId = segs[2];
                    return MaterialPageRoute(
                      builder: (_) => PetDetailScreenWeb(petId: petId),
                      settings: settings,
                    );
                  }
                  // Backward-compat: /pet/:id
                  if (segs.length >= 2 && segs[0] == 'pet') {
                    final petId = segs[1];
                    return MaterialPageRoute(
                      builder: (_) => PetDetailScreenWeb(petId: petId),
                      settings: settings,
                    );
                  }
                }

                // Web Admin deep links: /admin/*
                if (kIsWeb && settings.name != null) {
                  final uri = Uri.parse(settings.name!);
                  final segs = uri.pathSegments;
                  if (segs.isNotEmpty && segs.first == 'admin') {
                    // /admin
                    if (segs.length == 1) {
                      return MaterialPageRoute(
                          builder: (_) => const HomePageAdmin(),
                          settings: settings);
                    }
                    final section = segs[1];
                    switch (section) {
                      case 'home':
                        return MaterialPageRoute(
                            builder: (_) => const HomePageAdmin(),
                            settings: settings);
                      case 'dashboard':
                        return MaterialPageRoute(
                            builder: (_) => const DashboardPage(),
                            settings: settings);
                      case 'order':
                      case 'orders':
                        return MaterialPageRoute(
                            builder: (_) => const OrdersAdmin(),
                            settings: settings);
                      case 'shipping':
                        return MaterialPageRoute(
                            builder: (_) => const ShippingManagementPage(),
                            settings: settings);
                      case 'pet':
                      case 'pets':
                        return MaterialPageRoute(
                            builder: (_) => const PetsAdmin(),
                            settings: settings);
                      case 'category':
                        return MaterialPageRoute(
                            builder: (_) => const CategoryAdmin(),
                            settings: settings);
                      case 'account':
                      case 'accounts':
                        return MaterialPageRoute(
                            builder: (_) => const AccountAdmin(),
                            settings: settings);
                      case 'notification':
                      case 'notifications':
                        return MaterialPageRoute(
                            builder: (_) => const NotificationManagementPanel(),
                            settings: settings);
                      case 'revenue':
                        return MaterialPageRoute(
                            builder: (_) => const RevenuePage(),
                            settings: settings);
                      case 'analytics':
                      case 'pet-analytics':
                        return MaterialPageRoute(
                            builder: (_) => const PetAnalyticsPage(),
                            settings: settings);
                      case 'shop-info':
                        return MaterialPageRoute(
                            builder: (_) => const ShopInfo(),
                            settings: settings);
                      case 'theme':
                        return MaterialPageRoute(
                            builder: (_) => const ThemeSettingsAdmin(),
                            settings: settings);
                      case 'chat':
                      case 'inbox':
                        // /admin/chat/:email -> Chat detail; otherwise inbox
                        if (section == 'chat' && segs.length >= 3) {
                          final email =
                              Uri.decodeComponent(segs.sublist(2).join('/'));
                          return MaterialPageRoute(
                              builder: (_) =>
                                  ChatDetailPage(customerEmail: email),
                              settings: settings);
                        }
                        return MaterialPageRoute(
                            builder: (_) => const InboxPageAdmin(),
                            settings: settings);
                      default:
                        // Fallback to admin home
                        return MaterialPageRoute(
                            builder: (_) => const HomePageAdmin(),
                            settings: settings);
                    }
                  }
                }

                // Social Network routes
                if (settings.name == '/social/create-post') {
                  return MaterialPageRoute(
                    builder: (_) => const CreatePostPage(),
                    settings: settings,
                  );
                }

                if (settings.name == '/social/search') {
                  return MaterialPageRoute(
                    builder: (_) => const SocialSearchPage(),
                    settings: settings,
                  );
                }

                if (settings.name == '/social/profile') {
                  final userId = settings.arguments as String;
                  return MaterialPageRoute(
                    builder: (_) => SocialProfilePage(userId: userId),
                    settings: settings,
                  );
                }

                if (settings.name == '/social/edit-profile') {
                  final profile = settings.arguments as SocialPetProfile;
                  return MaterialPageRoute(
                    builder: (_) => EditSocialProfilePage(profile: profile),
                    settings: settings,
                  );
                }

                if (settings.name == '/social/edit-post') {
                  final post = settings.arguments as SocialPost;
                  return MaterialPageRoute(
                    builder: (_) => EditPostPage(post: post),
                    settings: settings,
                  );
                }

                if (settings.name == '/social/followers') {
                  final args = settings.arguments as Map<String, dynamic>;
                  return MaterialPageRoute(
                    builder: (_) => FollowersListPage(
                      userId: args['userId'],
                      isFollowersMode: args['isFollowersMode'],
                    ),
                    settings: settings,
                  );
                }

                if (settings.name == '/social/chat') {
                  return MaterialPageRoute(
                    builder: (_) => const ChatListPageWithTabs(),
                    settings: settings,
                  );
                }

                if (settings.name == '/social/chat/room') {
                  final args = settings.arguments as Map<String, dynamic>;
                  return MaterialPageRoute(
                    builder: (_) => ChatRoomPage(
                      conversationId: args['conversationId'],
                      otherUserId: args['otherUserId'],
                      otherUserName: args['otherUserName'],
                      otherUserAvatar: args['otherUserAvatar'],
                    ),
                    settings: settings,
                  );
                }

                if (settings.name == '/social/chat/group') {
                  final args = settings.arguments as Map<String, dynamic>;
                  return MaterialPageRoute(
                    builder: (_) => GroupChatRoomPage(
                      groupId: args['groupId'],
                      groupName: args['groupName'],
                      groupAvatar: args['groupAvatar'],
                    ),
                    settings: settings,
                  );
                }

                // if (settings.name == '/pet/ar-viewer') {
                //   final args = settings.arguments as Map<String, dynamic>?;
                //   return MaterialPageRoute(
                //     builder: (_) => ArViewerPage(
                //       modelPath: args?['modelPath'],
                //       petName: args?['petName'],
                //     ),
                //     settings: settings,
                //   );
                // }

                // Default routes
                return null;
              },
              routes: {
                '/': (context) {
                  return kIsWeb
                      ? const WebAppWrapper()
                      : FutureBuilder<bool>(
                          future: OnboardingService.hasSeenGetStarted(),
                          builder: (context, onboardingSnapshot) {
                            // Show loading while checking onboarding status
                            if (onboardingSnapshot.connectionState ==
                                ConnectionState.waiting) {
                              return const Scaffold(
                                body: Center(
                                  child: CircularProgressIndicator(
                                      color: Colors.pink),
                                ),
                              );
                            }

                            final hasSeenOnboarding =
                                onboardingSnapshot.data ?? false;

                            // If first time opening app, show GetStarted
                            if (!hasSeenOnboarding) {
                              return const GetStartedPage();
                            }

                            // Otherwise check auth state
                            return StreamBuilder<User?>(
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
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
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
                                    return SeasonalEffectsOverlay(
                                      child: const BottomNavigator(),
                                    );
                                  } else {
                                    if (kDebugMode) {
                                      debugPrint(
                                          ' Email not verified and not social login, showing LoginOrRegister');
                                    }
                                    return SeasonalEffectsOverlay(
                                      child: const LoginOrRegister(),
                                    );
                                  }
                                } else {
                                  // User is not authenticated
                                  if (kDebugMode) {
                                    debugPrint(
                                        ' User not authenticated, showing LoginOrRegister');
                                  }
                                  return SeasonalEffectsOverlay(
                                    child: const LoginOrRegister(),
                                  );
                                }
                              },
                            );
                          },
                        );
                },
                '/home': (context) => const HomePageWebUser(),
                '/cart': (context) => const CartScreenWeb(),
                '/shipping': (context) => const ShippingManagementPage(),
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
            );
          },
        );
      }),
    );
  }
}
