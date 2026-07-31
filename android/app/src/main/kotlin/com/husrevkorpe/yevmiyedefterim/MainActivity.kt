package com.husrevkorpe.yevmiyedefterim

import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        bildirimKanaliniOlustur()
    }

    /**
     * Yoklama bildirim kanalı (Android 8+). Manifest'teki
     * `default_notification_channel_id` ile AYNI kimlik olmalı; kanal yoksa
     * bildirim adsız varsayılan kanala düşer, kullanıcı sesini/önemini ayrı
     * ayarlayamaz. Var olan kanalı yeniden oluşturmak zararsızdır (Android aynı
     * kimlikte kanalı tanır, kullanıcının değiştirdiği ayarları ezmez).
     */
    private fun bildirimKanaliniOlustur() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val kanal = NotificationChannel(
                "yoklama",
                "Yoklama bildirimleri",
                NotificationManager.IMPORTANCE_HIGH,
            )
            kanal.description =
                "Bir cihazda yoklama kaydedildiğinde diğer cihazlara düşer."
            val yonetici =
                getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            yonetici.createNotificationChannel(kanal)
        }
    }
}
