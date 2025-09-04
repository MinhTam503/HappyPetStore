# Navigation Stack Issue - Login After Logout

## Problem Analysis
- **First login**: Works perfectly → navigates to BottomNavigator ✅
- **After logout + login again**: Login successful but stays on LoginPage ❌

## Root Cause: Dual Navigation Stack
```
CORRECT FLOW (First login):
App start → main.dart StreamBuilder (Stack A) → LoginOrRegister
Login success → authStateChanges → BottomNavigator (Stack A) ✅

BROKEN FLOW (After logout):
User clicks logout → Navigator.pushReplacement → LoginOrRegister (Stack B) ❌
Login success → authStateChanges tries to navigate Stack A (not current Stack B)
Result: User stays on LoginPage in Stack B
```

## The Issue
In `profile_screen.dart`, logout was using:
```dart
// ❌ WRONG: Creates new navigation stack
authService.value.signOut();
Navigator.pushReplacement(
  context,
  MaterialPageRoute(builder: (context) => const LoginOrRegister()),
);
```

This bypasses the `StreamBuilder` in `main.dart` and creates a **second navigation stack**.

## Solution Applied
```dart
// ✅ CORRECT: Let authStateChanges handle navigation
authService.value.signOut();
// StreamBuilder automatically detects auth state change and shows LoginOrRegister
```

## How it Works
1. User clicks logout
2. `authService.value.signOut()` called
3. Firebase auth state changes to null
4. `StreamBuilder` in `main.dart` detects change
5. Automatically rebuilds with `LoginOrRegister`
6. User logs in again
7. `authStateChanges` detects authenticated user
8. Navigate to `BottomNavigator` ✅

## Benefits
- ✅ Single navigation stack maintained
- ✅ Consistent auth state management  
- ✅ StreamBuilder handles all navigation
- ✅ No more "stuck on login page" issue

## Files Modified
- `lib/presentation/pages/mobile/tab/profile_screen.dart`
  - Removed `Navigator.pushReplacement` from logout
  - Let `authStateChanges` handle all navigation
  - Added debug logging for logout flow

## Testing
Now the flow should be:
1. Login first time → BottomNavigator ✅
2. Logout → LoginOrRegister (via StreamBuilder) ✅  
3. Login again → BottomNavigator ✅
4. Repeat cycle works perfectly ✅

The key insight: **Always let StreamBuilder handle auth-based navigation, never manually navigate on auth state changes.**
