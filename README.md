# Pet Shop

Pet Shop is a cross-platform Flutter application for pet adoption and management, supporting both mobile and web. The app integrates Firebase for authentication, Firestore for data storage, Stripe for payments, Google Maps, and more. It is designed for both end-users and administrators, with a modern UI and robust state management using BLoC and Provider.

## Features
- User authentication (Email/Password, Google Sign-In)
- Pet listing, adoption, and management
- Shopping cart and order management
- Payment integration with Stripe
- Admin dashboard (web)
- Google Maps integration
- File/image picker for pet profiles
- Email sending functionality
- Real-time updates with Firestore
- Responsive UI for mobile and web

## Getting StartedƯ

### Prerequisites
- [Flutter SDK](https://flutter.dev/docs/get-started/install)
- [Firebase CLI](https://firebase.google.com/docs/cli)
- Android Studio/Xcode/VS Code (for mobile development)

### Installation
1. **Clone the repository:**
   ```bash
   git clone <your-repo-url>
   cd pet_shop
   ```
2. **Install dependencies:**
   ```bash
   flutter pub get
   ```
3. **Firebase setup:**
   - Add your `google-services.json` (Android) to `android/app/`.
   - Add your `GoogleService-Info.plist` (iOS) to `ios/Runner/`.
   - Configure Firebase project as per [FlutterFire docs](https://firebase.flutter.dev/docs/overview/).
4. **Environment variables:**
   - Create a `.env` file in `assets/` for Stripe and other secrets (see `.env.example` if available).

### Running the App
- **Mobile:**
  ```bash
  flutter run
  ```
- **Web:**
  ```bash
  flutter run -d chrome
  ```

## Project Structure
```
lib/
  main.dart                # App entry point
  firebase_options.dart    # Firebase config
  auth/                    # Authentication & payment modules
  bloc/                    # BLoC state management
  view/                    # UI screens (mobile/web)
  widgets/                 # Reusable widgets
  services/                # Business logic/services
assets/
  images/                  # App images
  orders_100.json          # Sample data
  loading.json             # Lottie animation
android/app/google-services.json # Firebase config (Android)
ios/Runner/GoogleService-Info.plist # Firebase config (iOS)
```

## Dependencies
- flutter, cupertino_icons
- firebase_core, firebase_auth, cloud_firestore, firebase_storage
- google_sign_in, flutter_stripe, provider, bloc, flutter_bloc
- fl_chart, lottie, intl, image_picker, file_picker, url_launcher, flutter_email_sender, google_maps_flutter, go_router, uuid, etc.

## Testing
Run widget tests:
```bash
flutter test
```

## Contribution
Pull requests are welcome! For major changes, please open an issue first to discuss what you would like to change.

## License
This project is licensed under the MIT License.
