package com.zoolgo.broker

import android.app.NotificationChannel
import android.app.NotificationManager
import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Channel for push notifications (FCM messages name it; see the manifest meta-data).
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel("zoolgo_default", "إشعارات ZoolGo", NotificationManager.IMPORTANCE_HIGH)
            channel.description = "الحجوزات والرحلات والتنبيهات"
            getSystemService(NotificationManager::class.java).createNotificationChannel(channel)
        }
    }
}
