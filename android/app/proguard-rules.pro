# Stripe Android SDK - Suppress warnings
-dontwarn com.stripe.android.pushProvisioning.PushProvisioningActivity$g
-dontwarn com.stripe.android.pushProvisioning.PushProvisioningActivityStarter$Args
-dontwarn com.stripe.android.pushProvisioning.PushProvisioningActivityStarter$Error
-dontwarn com.stripe.android.pushProvisioning.PushProvisioningActivityStarter
-dontwarn com.stripe.android.pushProvisioning.PushProvisioningEphemeralKeyProvider

# Suppress Kotlin warnings for third-party libraries
-dontwarn kotlin.**
-dontwarn kotlinx.**

# Stripe specific warnings suppression
-dontwarn com.flutter.stripe.**
-dontwarn com.reactnativestripesdk.**

# Keep Stripe classes but suppress warnings
-keep class com.stripe.** { *; }
-keep class com.flutter.stripe.** { *; }
-keep class com.reactnativestripesdk.** { *; }

# Material Components - Keep theme related classes
-keep class com.google.android.material.** { *; }
-keep class androidx.appcompat.** { *; }
-dontwarn com.google.android.material.**
-dontwarn androidx.appcompat.**