package com.example.pet_shop

import io.flutter.embedding.android.FlutterFragmentActivity
import android.os.Bundle
import android.webkit.WebView

class MainActivity: FlutterFragmentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        // Set theme before calling super.onCreate()
        setTheme(R.style.AppTheme)
        super.onCreate(savedInstanceState)
        
        // Enable WebView debugging for model_viewer_plus
        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.KITKAT) {
            WebView.setWebContentsDebuggingEnabled(true)
        }
    }
}
