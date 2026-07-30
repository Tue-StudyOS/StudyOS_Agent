package com.example.studyOS.Reminder;

import android.Manifest;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.app.Service;
import android.content.Context;
import android.content.Intent;
import android.content.pm.PackageManager;
import android.content.pm.ServiceInfo;
import android.media.MediaPlayer;
import android.os.Build;
import android.os.Handler;
import android.os.IBinder;
import android.os.Looper;
import android.os.PowerManager;

import androidx.core.app.ActivityCompat;
import androidx.core.app.NotificationCompat;

import com.studyostue.app.R;
import com.example.studyOS.Memory.FileIO;
import com.example.studyOS.Sensors.WorldStateProvider;
import com.example.studyOS.System.RuntimeEnvironment;
import com.example.studyOS.online.JarvisBrainOnline;
import com.example.studyOS.online.SpeechRecognitionManager;
import com.example.studyOS.online.TTS;
import com.example.studyOS.online.ToolManager;

import org.json.JSONObject;

import okhttp3.OkHttpClient;

public class ReminderService extends Service {

    private static final String CHANNEL = "jarvis_reminders";
    private static boolean running = false;
    private static MediaPlayer player;
    private PowerManager.WakeLock wakeLock;

    @Override
    public void onCreate() {
        super.onCreate();
        PowerManager pm =
                (PowerManager) getSystemService(POWER_SERVICE);

        wakeLock = pm.newWakeLock(
                PowerManager.PARTIAL_WAKE_LOCK,
                "jarvis:mic"
        );

        wakeLock.acquire();



        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            var channel = new NotificationChannel(CHANNEL, "Jarvis Reminder", NotificationManager.IMPORTANCE_HIGH);
            getSystemService(NotificationManager.class)
                    .createNotificationChannel(channel);
        }

        var notification = new NotificationCompat.Builder(this, CHANNEL)
                        .setContentTitle("JARVIS aktiv")
                        .setContentText("Reminder Service läuft")
                        .setSmallIcon(R.drawable.ic_launcher_foreground)
                        .build();

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE)
            startForeground(1, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PLAYBACK);
        else
            startForeground(1, notification);
    }


    @Override
    public int onStartCommand(Intent intent, int flags, int startId) {
        if (running)
            return START_NOT_STICKY;

        running = true;
        prepareJarvisBackgroundEnvironment();

        try {
            var title = intent.getStringExtra(ReminderManager.EXTRA_TITLE);
            var type = intent.getStringExtra(ReminderManager.EXTRA_TYPE);
            var repeat = intent.getStringExtra(ReminderManager.EXTRA_REPEAT);
            var time = intent.getLongExtra(ReminderManager.EXTRA_TIME, 0);

            /*  HIER:
                GPT API
                Wetter
                News
                TTS
                Onlinezugriffe
                etc.
             */

            if (type.equals("ALARM")) {
                // Playing morning alarm...
                if (player != null) {
                    try {
                        player.stop();
                        player.release();
                    } catch (Exception e) {
                        System.err.println("Error while releasing mediaplayer: " + e.getMessage());
                    }
                }

                // TODO implement a new player with a different alarm
                /* player = MediaPlayer.create(this, R.raw.ironman_morning);
                player.setOnCompletionListener(mp -> {
                    mp.release();
                    if(player == mp)
                        player = null;
                });

                player.start(); */


                // Open jarvis9
                var jarvisIntent = getPackageManager().getLaunchIntentForPackage(getPackageName());
                if (jarvisIntent != null) {
                    jarvisIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK | Intent.FLAG_ACTIVITY_SINGLE_TOP | Intent.FLAG_ACTIVITY_CLEAR_TOP);

                    new Handler().postDelayed(() -> {
                        startActivity(jarvisIntent);
                    }, 3000);
                }
            }

            if (type.equals("REMINDER")) {
                // TODO:
                // TTS sprechen
                // "Sir, Erinnerung: ..."



                JarvisBrainOnline.getInstance().process("SYSTEM: Die Errinerung wurde basierend auf der aktuellen Uhrzeit gestartet. Beachte dass der Nutzer vermutlich nicht weiß um was es geht. Sprich ihn auf seine Erinnerung an. Dies ist die Erinnerung: " + title);
                var jarvisIntent = getPackageManager().getLaunchIntentForPackage(getPackageName());
                if (jarvisIntent != null) {
                    jarvisIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK | Intent.FLAG_ACTIVITY_SINGLE_TOP | Intent.FLAG_ACTIVITY_CLEAR_TOP);
                    System.out.println("JARVIS gestartet!");
                    new Handler().postDelayed(() -> {
                        startActivity(jarvisIntent);
                    }, 3000);
                }

                // System.out.println();
            }

            if (type.equals("MORNING_ROUTINE")) {
                // TODO:
                // Wetter abrufen
                // Nachrichten
                // Musik
                // GPT Briefing
            }

            var obj = new JSONObject()
                    .put("id", intent.getStringExtra(ReminderManager.EXTRA_ID))
                    .put("title", title)
                    .put("type", type)
                    .put("repeat", repeat)
                    .put("time", time);

            ReminderManager.get().init(this);
            ReminderManager.get().next(obj);

        } catch (Exception ignored) {}

        running = false;
        return START_STICKY;
    }

    @Override
    public IBinder onBind(Intent intent) {
        return null;
    }

    @Override
    public void onDestroy() {

        if (wakeLock != null && wakeLock.isHeld())
            wakeLock.release();

        super.onDestroy();
    }


    // HELPER METHODS

    /**
     * Fährt die absolut notwendigen Jarvis-Infrastrukturen im Hintergrund hoch,
     * falls die App geschlossen war.
     */
    private void prepareJarvisBackgroundEnvironment() {
        Context context = getApplicationContext();

        // 1. Basis-Infrastruktur
        RuntimeEnvironment.init(context);
        FileIO.init(context);
        WorldStateProvider.init(context, 5000);

        // 2. Brain vorbereiten
        JarvisBrainOnline brain = JarvisBrainOnline.getInstance();
        brain.setToolManager(new ToolManager(new OkHttpClient(), context));

        // 3. TTS + SpeechRecognizer auf dem Main-Thread initialisieren
        //    → SpeechRecognizer benötigt zwingend einen laufenden Main-Looper
        new Handler(Looper.getMainLooper()).post(() -> {

            TTS backgroundTts = new TTS(context);
            brain.setTTS(backgroundTts);

            boolean locationGranted =
                    ActivityCompat.checkSelfPermission(context, Manifest.permission.ACCESS_FINE_LOCATION)   == PackageManager.PERMISSION_GRANTED
                            && ActivityCompat.checkSelfPermission(context, Manifest.permission.ACCESS_COARSE_LOCATION) == PackageManager.PERMISSION_GRANTED;

            if (!locationGranted) return;

            SpeechRecognitionManager srm = new SpeechRecognitionManager(context, backgroundTts);
            brain.setSpeechRecognitionManager(srm);

            // Callback-Kette: TTS fertig → SRM hört wieder zu
            backgroundTts.setOnDoneCallback(srm::startListening);
        });
    }
}