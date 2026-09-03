package com.example.not_volga

import android.app.Application
import android.util.Log
import com.yandex.mapkit.MapKitFactory

class MainApplication : Application() {
    override fun onCreate() {
        super.onCreate()
        try {
            val key = BuildConfig.MAPKIT_API_KEY
            Log.d("MapKit", "Initializing MapKit with key length: ${key.length}")
            if (key.isNotEmpty()) {
                MapKitFactory.setApiKey(key)
            }
            MapKitFactory.setLocale("ru_RU")
        } catch (e: Exception) {
            Log.e("MapKit", "Failed to initialize MapKit", e)
        }
    }
}
