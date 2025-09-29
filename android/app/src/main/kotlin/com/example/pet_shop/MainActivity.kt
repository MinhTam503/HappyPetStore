package com.example.pet_shop

import io.flutter.embedding.android.FlutterFragmentActivity
import android.os.Bundle

class MainActivity: FlutterFragmentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        // Set theme before calling super.onCreate()
        setTheme(R.style.AppTheme)
        super.onCreate(savedInstanceState)
    }
}
