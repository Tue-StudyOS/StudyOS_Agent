package com.example.studyOS.Reminder;

import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.app.Service;
import android.content.Context;
import android.content.Intent;
import android.content.pm.ServiceInfo;
import android.media.AudioManager;
import android.os.IBinder;
import android.os.PowerManager;
import android.speech.SpeechRecognizer;
import android.util.Log;
import androidx.core.app.NotificationCompat;

public class NotificationService extends Service {

    private static final String TAG = "JarvisNotificationService";
    private static final String CHANNEL_ID = "Jarvis_Voice_Channel";
    private static final int NOTIFICATION_ID = 9912;

    private SpeechRecognizer speechRecognizer;
    private PowerManager.WakeLock wakeLock;
    private AudioManager audioManager;

    @Override
    public void onCreate() {
        super.onCreate();
        Log.d(TAG, "Service wird initialisiert...");

        // 1. CPU wach halten, wenn das Display ausgeht
        var powerManager = (PowerManager) getSystemService(Context.POWER_SERVICE);
        if (powerManager != null) {
            wakeLock = powerManager.newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "Jarvis::VoiceWakeLock");
            wakeLock.acquire(10 * 60 * 1000L); // 10 Minuten Sicherheits-Timeout
        }

        audioManager = (AudioManager) getSystemService(Context.AUDIO_SERVICE);
        createNotificationChannel();
    }

    @Override
    public int onStartCommand(Intent intent, int flags, int startId) {
        Log.d(TAG, "Service gestartet. Aktiviere Foreground...");

        // 2. Notification bauen
        var notification = new NotificationCompat.Builder(this, CHANNEL_ID)
                .setContentTitle("Jarvis Sprachsystem")
                .setContentText("Ich höre dir auch im Standby zu...")
                .setSmallIcon(android.R.drawable.ic_btn_speak_now)
                .setPriority(NotificationCompat.PRIORITY_HIGH)
                .setCategory(NotificationCompat.CATEGORY_SERVICE)
                .build();

        // 3. Als ForegroundService starten (Zwingend mit Typen für Android 14+)
        startForeground(NOTIFICATION_ID, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_MICROPHONE | ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PLAYBACK);

        // 4. Spracherkennung verzögert auf dem Main-Looper zünden
       //  new Handler(Looper.getMainLooper()).postDelayed(this::startListeningOnLockscreen, 1000);

        return START_STICKY;
    }

    private void createNotificationChannel() {
        NotificationChannel channel = new NotificationChannel(CHANNEL_ID, "Jarvis Voice Service", NotificationManager.IMPORTANCE_HIGH);
        channel.setDescription("Jarvis Sprachsystem. Bereit für Sie Sir");

        var manager = getSystemService(NotificationManager.class);
        if (manager != null) manager.createNotificationChannel(channel);

    }

    @Override
    public void onDestroy() {
        super.onDestroy();
        if (speechRecognizer != null) speechRecognizer.destroy();
        if (wakeLock != null && wakeLock.isHeld()) wakeLock.release();

        Log.d(TAG, "Service beendet.");
    }

    @Override
    public IBinder onBind(Intent intent) {
        return null;
    }
}