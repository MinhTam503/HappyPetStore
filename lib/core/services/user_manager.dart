import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pet_shop/core/services/search_recommendations_cache.dart';
import 'package:pet_shop/services/recommendation_logger.dart';

/// Centralized user management service supporting multiple authentication methods
/// (email/password, phone, Facebook, Google) with local storage for offline access
class UserManager {
  static final UserManager _instance = UserManager._internal();
  factory UserManager() => _instance;
  UserManager._internal();

  // Keys for SharedPreferences
  static const String _userIdKey = 'current_user_id';
  static const String _userInfoKey = 'current_user_info';
  static const String _isLoggedInKey = 'is_logged_in';

  // Cached user data
  String? _currentUserId;
  Map<String, dynamic>? _currentUserInfo;
  bool _isInitialized = false;

  // Getters
  String? get currentUserId => _currentUserId;
  Map<String, dynamic>? get currentUserInfo => _currentUserInfo;
  bool get isLoggedIn => _currentUserId != null;
  String? get userEmail => _currentUserInfo?['email'];
  String? get userPhone => _currentUserInfo?['phone'];
  String? get displayName => _currentUserInfo?['displayName'];

  /// Initialize the UserManager - call this in main() or app startup
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      await _loadUserFromLocal();
      
      // Listen to Firebase auth state changes
      FirebaseAuth.instance.authStateChanges().listen(_onAuthStateChanged);
      
      _isInitialized = true;
      if (kDebugMode) {
        print('🔐 UserManager initialized. User: ${_currentUserId ?? 'None'}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Failed to initialize UserManager: $e');
      }
    }
  }

  /// Handle Firebase auth state changes
  void _onAuthStateChanged(User? user) async {
    if (user != null) {
      // User signed in - if account changed, clear per-user caches, then fetch and cache user info
      final previousUserId = _currentUserId;
      if (previousUserId != null && previousUserId != user.uid) {
        try {
          await SearchRecommendationsCache.clearCache();
          if (kDebugMode) {
            print('🧹 Cleared search recommendations cache due to account switch: $previousUserId → ${user.uid}');
          }
        } catch (_) {}
      }

      // Initialize/rotate logger per user and clear on first login (fresh start for logs)
      try {
        await RecommendationLogger.initialize(
          userId: user.uid,
          perUserFile: true,
          clearExisting: previousUserId != user.uid, // clear if switching or first time
        );
      } catch (_) {}
      await refreshUserInfo();
    } else {
      // User signed out - clear cache
      await clearUserData();
    }
  }

  /// Save user ID to local storage
  Future<void> saveUserId(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_userIdKey, userId);
      await prefs.setBool(_isLoggedInKey, true);
      _currentUserId = userId;
      
      if (kDebugMode) {
        print('💾 User ID saved: $userId');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Failed to save user ID: $e');
      }
    }
  }

  /// Save complete user information to local storage
  Future<void> saveUserInfo(Map<String, dynamic> userInfo) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Convert Firestore Timestamp objects to milliseconds
      final cleanUserInfo = Map<String, dynamic>.from(userInfo);
      cleanUserInfo.forEach((key, value) {
        if (value is Timestamp) {
          cleanUserInfo[key] = value.millisecondsSinceEpoch;
        }
      });
      
      final jsonString = jsonEncode(cleanUserInfo);
      await prefs.setString(_userInfoKey, jsonString);
      _currentUserInfo = cleanUserInfo;
      
      if (kDebugMode) {
        print('💾 User info saved: ${cleanUserInfo['displayName'] ?? cleanUserInfo['email']}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Failed to save user info: $e');
      }
    }
  }

  /// Get current user information from cache or fetch from Firestore
  Future<Map<String, dynamic>?> getCurrentUserInfo() async {
    if (_currentUserInfo != null) {
      return _currentUserInfo;
    }
    
    // Try to refresh from Firestore
    return await refreshUserInfo();
  }

  /// Refresh user information from Firestore and update cache
  Future<Map<String, dynamic>?> refreshUserInfo() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      await clearUserData();
      return null;
    }

    try {
      // Get user info from Firestore using UID
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (userDoc.exists) {
        final userInfo = userDoc.data() as Map<String, dynamic>;
        
        // Add Firebase Auth info
        userInfo['uid'] = user.uid;
        userInfo['emailVerified'] = user.emailVerified;
        if (user.email != null) userInfo['email'] = user.email;
        if (user.phoneNumber != null) userInfo['phone'] = user.phoneNumber;
        
        // Save to cache and local storage
        await saveUserId(user.uid);
        await saveUserInfo(userInfo);
        
        return userInfo;
      } else {
        if (kDebugMode) {
          print('⚠️ User document not found in Firestore for UID: ${user.uid}');
        }
        await clearUserData();
        return null;
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Failed to refresh user info: $e');
      }
      return _currentUserInfo; // Return cached data on error
    }
  }

  /// Get user ID for cart/favorites operations - works with all login methods
  Future<String?> getUserIdForOperations() async {
    if (_currentUserId != null) {
      return _currentUserId;
    }
    
    // Try Firebase current user
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await saveUserId(user.uid);
      return user.uid;
    }
    
    return null;
  }

  /// Get unique identifier for cart/favorites - fallback to email if no UID
  Future<String?> getUserIdentifier() async {
    // Primary: Use UID
    final userId = await getUserIdForOperations();
    if (userId != null) return userId;
    
    // Fallback: Use email for backward compatibility
    final userInfo = await getCurrentUserInfo();
    return userInfo?['email'];
  }

  /// Check if current user has required information for checkout
  Future<bool> hasCompleteUserInfo() async {
    final userInfo = await getCurrentUserInfo();
    if (userInfo == null) return false;
    
    // Check required fields
    final hasName = userInfo['displayName'] != null && 
                   userInfo['displayName'].toString().trim().isNotEmpty;
    final hasContact = (userInfo['email'] != null && 
                       userInfo['email'].toString().trim().isNotEmpty) ||
                      (userInfo['phone'] != null && 
                       userInfo['phone'].toString().trim().isNotEmpty);
    
    return hasName && hasContact;
  }

  /// Clear all user data (logout)
  Future<void> clearUserData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_userIdKey);
      await prefs.remove(_userInfoKey);
      await prefs.setBool(_isLoggedInKey, false);
      
      _currentUserId = null;
      _currentUserInfo = null;
      
      if (kDebugMode) {
        print('🗑️ User data cleared');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Failed to clear user data: $e');
      }
    }
  }

  /// Load user data from local storage
  Future<void> _loadUserFromLocal() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final isLoggedIn = prefs.getBool(_isLoggedInKey) ?? false;
      
      if (isLoggedIn) {
        _currentUserId = prefs.getString(_userIdKey);
        final userInfoString = prefs.getString(_userInfoKey);
        
        if (userInfoString != null) {
          _currentUserInfo = jsonDecode(userInfoString) as Map<String, dynamic>;
        }
        
        if (kDebugMode) {
          print('📱 Loaded cached user: ${_currentUserId}');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Failed to load user from local storage: $e');
      }
    }
  }

  /// Update specific user information
  Future<void> updateUserInfo(Map<String, dynamic> updates) async {
    if (_currentUserInfo == null) return;
    
    try {
      // Update cache
      _currentUserInfo!.addAll(updates);
      await saveUserInfo(_currentUserInfo!);
      
      // Update Firestore if we have user ID
      if (_currentUserId != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(_currentUserId!)
            .update(updates);
      }
      
      if (kDebugMode) {
        print('📝 User info updated: ${updates.keys.join(', ')}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Failed to update user info: $e');
      }
    }
  }

  /// Get user info for order/cart operations with fallback
  Future<Map<String, dynamic>?> getUserInfoForOrder() async {
    final userInfo = await getCurrentUserInfo();
    if (userInfo == null) return null;
    
    return {
      'userId': _currentUserId,
      'email': userInfo['email'] ?? '',
      'phone': userInfo['phone'] ?? '',
      'displayName': userInfo['displayName'] ?? '',
      'address': userInfo['address'] ?? [],
    };
  }

  /// Debug method to print current state
  void debugPrintState() {
    if (kDebugMode) {
      print('🔍 UserManager State:');
      print('  - User ID: $_currentUserId');
      print('  - Is Logged In: $isLoggedIn');
      print('  - User Email: $userEmail');
      print('  - User Phone: $userPhone');
      print('  - Display Name: $displayName');
    }
  }
}

/// Global instance for easy access
final userManager = UserManager();