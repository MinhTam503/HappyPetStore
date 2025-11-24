import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'dart:async';
import 'package:path_provider/path_provider.dart';

typedef NotificationTapHandler = void Function(String? payload, Map<String, dynamic>? data);

/// Top-level handler for background messages (required by FCM)
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();

  // Initialize local notifications for background
  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    PushNotificationService.defaultChannelId,
    'Thông báo chung',
    description: 'Kênh thông báo mặc định cho ứng dụng',
    importance: Importance.high,
  );

  final flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
  await flutterLocalNotificationsPlugin.initialize(
    const InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    ),
  );
  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);

  final notification = message.notification;
  final android = message.notification?.android;
  if (notification != null && android != null) {
    await flutterLocalNotificationsPlugin.show(
      message.hashCode,
      notification.title,
      notification.body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          PushNotificationService.defaultChannelId,
          'Thông báo chung',
          channelDescription: 'Kênh thông báo mặc định cho ứng dụng',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
      ),
      payload: message.data['route'] as String?,
    );
  }
}

class PushNotificationService {
  static const defaultChannelId = 'default_notifications';

  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _fln =
      FlutterLocalNotificationsPlugin();
  static StreamSubscription? _firestoreNotifSub;
  static StreamSubscription? _chatMessageSub;
  static StreamSubscription? _chatMessageSubLower;
  static final Set<String> _seenNotificationIds = <String>{};
  static final Set<String> _seenChatMessageIds = <String>{};
  static DateTime? _notifLastShownAt;
  static DateTime? _chatLastShownAt;
  static NotificationTapHandler? _tapHandler;
  static AndroidBitmap<Object>? _brandLargeIcon;
  static AndroidBitmap<Object>? _brandBigPicture;

  // Allow app to register a custom navigation handler
  static void registerTapHandler(NotificationTapHandler handler) {
    _tapHandler = handler;
  }

  static Future<void> initialize() async {
    if (kIsWeb) return; // Android only per current requirement

    // Android 13+ notifications permission
    if (Platform.isAndroid) {
      await _requestAndroidNotificationPermission();
    }

    // Local notifications setup
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidInit);
  await _fln.initialize(initSettings,
    onDidReceiveNotificationResponse: _onLocalNotificationTap);

    // Create default channel
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      defaultChannelId,
      'Thông báo chung',
      description: 'Kênh thông báo mặc định cho ứng dụng',
      importance: Importance.high,
    );
    await _fln
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

  // Preload brand images (from assets to a temp file) for large icon/big picture styling
  await _ensureBrandImagesLoaded();

  // Background handler
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    // Foreground notifications presentation (Android shows by default via local plugin)
    FirebaseMessaging.onMessage.listen(_onForegroundMessage);
  FirebaseMessaging.onMessageOpenedApp.listen(_onFcmMessageOpened);

    // If app was launched by tapping a notification from terminated state
    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      _onFcmMessageOpened(initialMessage);
    }

    // iOS presentation options (no-op on Android)
    await _messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    // Token lifecycle
    await _syncFcmToken();
    FirebaseMessaging.instance.onTokenRefresh.listen((token) {
      _saveToken(token);
    });

    // When the auth state changes (e.g., user logs in), ensure the token is saved under that user
    FirebaseAuth.instance.authStateChanges().listen((user) async {
      if (user != null) {
        // User just signed in -> ensure we save the current token for this UID
        await _syncFcmToken();
        _startFirestoreNotificationListener(user.uid);
        // Start chat listener using best-available conversation id
        final convId = await _getConversationIdForUser(user);
        if (convId != null) {
          _startChatMessageListener(convId);
        }
      } else {
        await _firestoreNotifSub?.cancel();
        _firestoreNotifSub = null;
        _seenNotificationIds.clear();
        await _chatMessageSub?.cancel();
        _chatMessageSub = null;
        _seenChatMessageIds.clear();
        _notifLastShownAt = null;
        _chatLastShownAt = null;
      }
    });

    if (kDebugMode) {
      final token = await _messaging.getToken();
      debugPrint('🔔 FCM token: $token');
    }

    // Ensure listeners also start immediately for already-authenticated users
    final current = FirebaseAuth.instance.currentUser;
    if (current != null) {
      if (kDebugMode) {
        debugPrint('🔔 Initializing listeners for existing user ${current.uid}');
      }
      await _syncFcmToken();
      _startFirestoreNotificationListener(current.uid);
      final convId = await _getConversationIdForUser(current);
      if (convId != null) {
        _startChatMessageListener(convId);
      } else {
        if (kDebugMode) debugPrint('⚠️ No conversationId (email) found for user; chat listener not started');
      }
    }
  }

  // Determine the conversation id used in Firestore (prefer email stored in users doc)
  static Future<String?> _getConversationIdForUser(User user) async {
    // Prefer FirebaseAuth email if present
    if ((user.email ?? '').isNotEmpty) return user.email;
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      final data = doc.data();
      final email = data?['email'] as String?;
      if ((email ?? '').isNotEmpty) return email;
    } catch (_) {}
    // No email available → cannot subscribe to conversations/{email}
    return null;
  }

  // Public helper to force-sync token on demand (e.g., when landing on Home)
  static Future<void> syncNow() => _syncFcmToken();

  static Future<void> _requestAndroidNotificationPermission() async {
    // On Android 13+, this prompts user; on lower versions, it is ignored
    await _messaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );
  }

  static void _onForegroundMessage(RemoteMessage message) async {
    final notification = message.notification;
    final android = notification?.android;
    if (notification != null && android != null) {
      await _fln.show(
        message.hashCode,
        notification.title,
        notification.body,
        _buildNotificationDetails(),
        payload: message.data['route'] as String?,
      );
    }
  }

  static void _onLocalNotificationTap(NotificationResponse response) {
    if (kDebugMode) {
      debugPrint('🔔 Local notification tapped with payload: ${response.payload}');
    }
    // Delegate to app if registered
    _tapHandler?.call(response.payload, null);
  }

  static void _onFcmMessageOpened(RemoteMessage message) {
    if (kDebugMode) {
      debugPrint('🔔 FCM message opened with data: ${message.data}');
    }
    // Delegate to app if registered
    _tapHandler?.call(message.data['route'] as String?, message.data);
  }

  static Future<void> _syncFcmToken() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      final token = await _messaging.getToken();
      if (token == null) return;
      await _saveToken(token);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Error syncing FCM token: $e');
      }
    }
  }

  static Future<void> _saveToken(String token) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      final userDoc = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid);

      await userDoc.set({
        // Keep a list of known tokens for this user (multiple devices supported)
        'fcmTokens': FieldValue.arrayUnion([token]),
        // Convenience fields for quick access/debugging
        'lastFcmToken': token,
        'fcmTokenPlatform': Platform.isAndroid ? 'android' : Platform.operatingSystem,
        'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Error saving FCM token: $e');
      }
    }
  }

  /// Optional: Listen to Firestore notifications for the signed-in user and
  /// display a local notification when a new document appears. This works when
  /// the app is in foreground or background, but NOT when the app is terminated.
  static void _startFirestoreNotificationListener(String uid) async {
    try {
      _firestoreNotifSub?.cancel();
      // load last shown timestamp to avoid re-showing older notifications
      try {
        final userDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
        final ts = userDoc.data()?['notifLastShownAt'];
        if (ts is Timestamp) _notifLastShownAt = ts.toDate();
      } catch (_) {}
      _firestoreNotifSub = FirebaseFirestore.instance
          .collection('notifications')
          .where('userId', isEqualTo: uid)
          .snapshots()
          .listen((snapshot) async {
        if (kDebugMode) {
          debugPrint('📥 notifications snapshot changes: ${snapshot.docChanges.length}');
        }
        DateTime? maxShown;
        for (final doc in snapshot.docChanges) {
          if (doc.type == DocumentChangeType.added) {
            final id = doc.doc.id;
            if (_seenNotificationIds.contains(id)) continue;
            _seenNotificationIds.add(id);
            final data = doc.doc.data();
            if (data == null) continue;
            final title = data['title'] as String? ?? 'Thông báo';
            final body = data['content'] as String? ?? '';
            final route = (data['data'] is Map && data['data']['route'] is String)
                ? data['data']['route'] as String
                : null;
            // Check createdAt/timestamp to avoid older items
            DateTime? createdAt;
            final ca = data['createdAt'] ?? data['timestamp'];
            if (ca is Timestamp) createdAt = ca.toDate();
            // If we don't have createdAt, skip filtering to not spam
            if (_notifLastShownAt != null && createdAt != null) {
              if (!createdAt.isAfter(_notifLastShownAt!)) {
                continue; // older or equal; already shown in a previous session
              }
            }

            await _fln.show(
              id.hashCode,
              title,
              body,
              _buildNotificationDetails(),
              payload: route,
            );

            if (createdAt != null) {
              if (maxShown == null || createdAt.isAfter(maxShown)) {
                maxShown = createdAt;
              }
            }
          }
        }
        // Persist latest shown timestamp to user doc
        if (maxShown != null) {
          _notifLastShownAt = maxShown;
          try {
            await FirebaseFirestore.instance.collection('users').doc(uid).set({
              'notifLastShownAt': Timestamp.fromDate(maxShown),
            }, SetOptions(merge: true));
          } catch (_) {}
        }
      });
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Error starting Firestore notification listener: $e');
      }
    }
  }

  /// Listen for chat messages directed to the current user's email and show a push-like local notification.
  /// This does NOT add to the general notifications collection.
  static void _startChatMessageListener(String conversationId) async {
    try {
      _chatMessageSub?.cancel();
      _chatMessageSubLower?.cancel();
      // load last shown chat timestamp
      try {
        final uid = FirebaseAuth.instance.currentUser?.uid;
        if (uid != null) {
          final userDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
          final ts = userDoc.data()?['chatLastShownAt'];
          if (ts is Timestamp) _chatLastShownAt = ts.toDate();
        }
      } catch (_) {}

      // (removed unused helper)

      // Primary listener
      _chatMessageSub = FirebaseFirestore.instance
          .collection('conversations')
          .doc(conversationId)
          .collection('messages')
          .orderBy('timestamp')
          .snapshots()
          .listen((snapshot) async {
            if (kDebugMode) debugPrint('📥 chat snapshot changes (${conversationId}): ${snapshot.docChanges.length}');
            DateTime? maxShown;
            for (final change in snapshot.docChanges) {
              if (change.type == DocumentChangeType.added) {
                final id = change.doc.id;
                if (_seenChatMessageIds.contains(id)) continue;
                _seenChatMessageIds.add(id);
                final data = change.doc.data();
                if (data == null) continue;
                final sender = data['sender'] as String?;
                final me = conversationId;
                if (sender == null || sender == me) continue;
                DateTime? ts;
                final tsv = data['timestamp'];
                if (tsv is Timestamp) ts = tsv.toDate();
                if (_chatLastShownAt != null && ts != null) {
                  if (!ts.isAfter(_chatLastShownAt!)) {
                    continue;
                  }
                }
                final body = (data['message'] as String?) ?? '';
                await _fln.show(
                  id.hashCode,
                  'Tin nhắn từ cửa hàng',
                  body,
                  _buildNotificationDetails(),
                  payload: 'chat',
                );
                if (ts != null) {
                  if (maxShown == null || ts.isAfter(maxShown)) {
                    maxShown = ts;
                  }
                }
              }
            }
            if (maxShown != null) {
              _chatLastShownAt = maxShown;
              try {
                final uid = FirebaseAuth.instance.currentUser?.uid;
                if (uid != null) {
                  await FirebaseFirestore.instance.collection('users').doc(uid).set({
                    'chatLastShownAt': Timestamp.fromDate(maxShown),
                  }, SetOptions(merge: true));
                }
              } catch (_) {}
            }
          });

      // Secondary listener for lowercase-id (handles case mismatch)
      final lower = conversationId.toLowerCase();
      if (lower != conversationId) {
        _chatMessageSubLower = FirebaseFirestore.instance
            .collection('conversations')
            .doc(lower)
            .collection('messages')
            .orderBy('timestamp')
            .snapshots()
            .listen((snapshot) async {
              if (kDebugMode) debugPrint('📥 chat snapshot changes (${lower}): ${snapshot.docChanges.length}');
              DateTime? maxShown;
              for (final change in snapshot.docChanges) {
                if (change.type == DocumentChangeType.added) {
                  final id = change.doc.id;
                  if (_seenChatMessageIds.contains(id)) continue;
                  _seenChatMessageIds.add(id);
                  final data = change.doc.data();
                  if (data == null) continue;
                  final sender = data['sender'] as String?;
                  final me = lower;
                  if (sender == null || sender == me) continue;
                  DateTime? ts;
                  final tsv = data['timestamp'];
                  if (tsv is Timestamp) ts = tsv.toDate();
                  if (_chatLastShownAt != null && ts != null) {
                    if (!ts.isAfter(_chatLastShownAt!)) {
                      continue;
                    }
                  }
                  final body = (data['message'] as String?) ?? '';
                  await _fln.show(
                    id.hashCode,
                    'Tin nhắn từ cửa hàng',
                    body,
                    _buildNotificationDetails(),
                    payload: 'chat',
                  );
                  if (ts != null) {
                    if (maxShown == null || ts.isAfter(maxShown)) {
                      maxShown = ts;
                    }
                  }
                }
              }
              if (maxShown != null) {
                _chatLastShownAt = maxShown;
                try {
                  final uid = FirebaseAuth.instance.currentUser?.uid;
                  if (uid != null) {
                    await FirebaseFirestore.instance.collection('users').doc(uid).set({
                      'chatLastShownAt': Timestamp.fromDate(maxShown),
                    }, SetOptions(merge: true));
                  }
                } catch (_) {}
              }
            });
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Error starting chat message listener: $e');
      }
    }
  }
}

// Helpers to brand notifications with app image
Future<void> _ensureBrandImagesLoaded() async {
  try {
    // Already loaded
    if (PushNotificationService._brandBigPicture != null) return;
    const assetPath = 'assets/images/splash_screen_mobile.png';
    final bytes = await rootBundle.load(assetPath);
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/splash_screen_mobile.png');
    await file.writeAsBytes(bytes.buffer.asUint8List(), flush: true);

    // Use file path based bitmaps for broad compatibility
    PushNotificationService._brandLargeIcon = FilePathAndroidBitmap(file.path);
    PushNotificationService._brandBigPicture = FilePathAndroidBitmap(file.path);
  } catch (e) {
    if (kDebugMode) {
      debugPrint('⚠️ Could not load brand image for notifications: $e');
    }
  }
}

NotificationDetails _buildNotificationDetails() {
  final androidDetails = AndroidNotificationDetails(
    PushNotificationService.defaultChannelId,
    'Thông báo chung',
    channelDescription: 'Kênh thông báo mặc định cho ứng dụng',
    importance: Importance.high,
    priority: Priority.high,
    icon: '@mipmap/ic_launcher',
    largeIcon: PushNotificationService._brandLargeIcon,
    styleInformation: (PushNotificationService._brandBigPicture != null)
        ? BigPictureStyleInformation(
            PushNotificationService._brandBigPicture!,
            largeIcon: PushNotificationService._brandLargeIcon,
            hideExpandedLargeIcon: false,
          )
        : null,
  );
  return NotificationDetails(android: androidDetails);
}
