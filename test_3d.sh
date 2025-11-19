#!/bin/bash

echo "🧹 Cleaning project..."
flutter clean

echo "📦 Getting dependencies..."
flutter pub get

echo "🔨 Building and running with verbose logs..."
flutter run --verbose 2>&1 | tee 3d_model_debug.log

# Instructions will appear after stopping the app
echo ""
echo "✅ Debug log saved to: 3d_model_debug.log"
echo ""
echo "📝 Để kiểm tra logs, tìm các dòng sau:"
echo "   🔍 Fetching 3D model from:"
echo "   ✅ 3D Model URL:"
echo "   🎨 Rendering in 3D mode"
echo "   📐 Model3DOverlay rendering:"
echo "   ModelViewer initializing..."
echo ""
echo "🌐 Để inspect WebView trên Chrome:"
echo "   1. Kết nối thiết bị qua USB"
echo "   2. Mở Chrome và vào: chrome://inspect"
echo "   3. Tìm WebView của app"
echo "   4. Click 'inspect' để xem console"
