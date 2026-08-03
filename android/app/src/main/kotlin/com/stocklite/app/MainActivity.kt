package com.stocklite.app

import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        createDefaultNotificationChannel()
    }

    /**
     * Tạo kênh thông báo "ưu tiên cao" khớp với
     * com.google.firebase.messaging.default_notification_channel_id trong Manifest.
     * Bắt buộc trên Android 8 (API 26) trở lên để thông báo đẩy hiển thị đúng kênh
     * (heads-up + âm thanh) kể cả khi app đang chạy nền hoặc đã tắt.
     */
    private fun createDefaultNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                "high_importance_channel",
                "Thông báo quan trọng",
                NotificationManager.IMPORTANCE_HIGH,
            ).apply {
                description = "Kênh thông báo đẩy của Tuấn Mây Mobile"
                enableVibration(true)
            }
            val manager =
                getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            manager.createNotificationChannel(channel)
        }
    }
}
