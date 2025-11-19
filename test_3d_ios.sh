#!/bin/bash

echo "🍎 Testing 3D Model on iOS Device"
echo "=================================="
echo ""

# Check if device is connected
DEVICE_COUNT=$(xcrun xctrace list devices 2>/dev/null | grep -i "iphone\|ipad" | grep -v "Simulator" | wc -l)

if [ "$DEVICE_COUNT" -eq 0 ]; then
    echo "❌ No iOS device detected!"
    echo ""
    echo "Please make sure:"
    echo "  1. Your iOS device is connected via USB or WiFi"
    echo "  2. Trust this computer on your device"
    echo "  3. Developer Mode is enabled (iOS 16+)"
    echo ""
    exit 1
fi

echo "✅ iOS device detected"
echo ""

echo "🧹 Cleaning iOS build cache..."
cd ios
rm -rf Pods Podfile.lock .symlinks
cd ..
flutter clean

echo ""
echo "📦 Getting dependencies..."
flutter pub get

echo ""
echo "📱 Installing CocoaPods..."
cd ios
pod install --repo-update
cd ..

echo ""
echo "🔨 Building and running on iOS device with verbose logs..."
echo ""
echo "⏰ This may take a few minutes..."
echo ""

flutter run --verbose --release 2>&1 | tee 3d_model_ios_debug.log

# Instructions after stopping
echo ""
echo "✅ iOS debug log saved to: 3d_model_ios_debug.log"
echo ""
echo "📝 To check logs, look for:"
echo "   🔍 Fetching 3D model from:"
echo "   ✅ 3D Model URL:"
echo "   🎨 Rendering in 3D mode"
echo "   📐 Model3DOverlay rendering:"
echo "   ModelViewer initializing..."
echo ""
echo "🔍 iOS-specific debugging:"
echo "   1. Open Safari on Mac"
echo "   2. Menu: Develop → [Your iPhone Name]"
echo "   3. Select the WebView context"
echo "   4. Check console for errors"
echo ""
echo "🎯 Known iOS issues:"
echo "   - iOS requires HTTPS for external resources"
echo "   - Firebase Storage URLs should work (already HTTPS)"
echo "   - WKWebView has stricter security than Android WebView"
echo "   - Check if device has enough free storage (models load to cache)"
echo ""
