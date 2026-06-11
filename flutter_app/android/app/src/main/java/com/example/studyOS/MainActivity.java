package com.example.studyOS;

import android.Manifest;
import android.content.Context;
import android.content.Intent;
import android.content.pm.PackageManager;
import android.os.Bundle;
import android.os.Environment;
import android.os.Handler;

import androidx.activity.EdgeToEdge;
import androidx.appcompat.app.AppCompatActivity;
import androidx.core.app.ActivityCompat;
import androidx.core.view.WindowCompat;

import com.studyos.studyos_agent.R;
import com.example.studyOS.Controller.JarvisController;
import com.example.studyOS.DataStructures.WorldState;
import com.example.studyOS.Memory.FileIO;
import com.example.studyOS.Reminder.NotificationService;
import com.example.studyOS.Reminder.ReminderManager;
import com.example.studyOS.Sensors.WorldStateProvider;
import com.example.studyOS.System.RuntimeEnvironment;
import com.example.studyOS.UI.GestureEngine;
import com.example.studyOS.UI.UIManager;
import com.example.studyOS.online.SpeechRecognitionManager;
import com.example.studyOS.online.TTS;

import java.io.File;
import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.io.OutputStream;
import java.util.concurrent.atomic.AtomicReference;

public class MainActivity extends AppCompatActivity {

    private static final long WORLD_STATE_UPDATE_FREQUENCE_MILLIS = 5000;


    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);

        EdgeToEdge.enable(this);
        WindowCompat.setDecorFitsSystemWindows(getWindow(), false);
        setContentView(R.layout.activity_main);

        RuntimeEnvironment.init(this);

        if (ActivityCompat.checkSelfPermission(this, Manifest.permission.ACCESS_FINE_LOCATION) != PackageManager.PERMISSION_GRANTED
                || ActivityCompat.checkSelfPermission(this, Manifest.permission.ACCESS_COARSE_LOCATION) != PackageManager.PERMISSION_GRANTED)
            return;

        if (ActivityCompat.checkSelfPermission(this, Manifest.permission.RECORD_AUDIO) != PackageManager.PERMISSION_GRANTED) {
            ActivityCompat.requestPermissions(this, new String[]{
                    Manifest.permission.RECORD_AUDIO
            }, 200);
        }

        // startForegroundService(new Intent(this, ReminderService.class));

        FileIO.init(this);
        UIManager.init(this);
        GestureEngine.init(this, findViewById(R.id.drawerLayout), findViewById(R.id.chatRecyclerView));
        WorldStateProvider.init(this, WORLD_STATE_UPDATE_FREQUENCE_MILLIS);
        ReminderManager.get().init(this);

        AtomicReference<WorldState> currentWorldState = new AtomicReference<>();
        new Handler().postDelayed(() -> {
             currentWorldState.set(WorldStateProvider.getInstance().getWorldState());
            JarvisController.init(this);
        }, 2000);

        TTS tts = new TTS(this);
        SpeechRecognitionManager speechRecognitionManager = new SpeechRecognitionManager(this, tts);
        speechRecognitionManager.startListening();

        System.out.println("WORLD_STATE: " + currentWorldState);


        Intent serviceIntent = new Intent(this, NotificationService.class);
        this.startForegroundService(serviceIntent);


        // Test call
        UIManager.addSidebarFile(this, "BOSS.txt");
        UIManager.addSidebarFile(this, "PREFERENCES.txt");
        UIManager.addSidebarFile(this, "CONTACTS.txt");
        UIManager.addSidebarFile(this, "AUTOMATIONS.txt");

        setupDatabaseFromDownload();

        requestingPermissions(this);
    }

    @Override
    protected void onDestroy() {
        super.onDestroy();

        System.exit(0);
        // TODO implement
    }


    public void requestingPermissions(Context context) {
        // Berechtigungen anfragen
        if (ActivityCompat.checkSelfPermission(this, android.Manifest.permission.RECORD_AUDIO) != PackageManager.PERMISSION_GRANTED ||
                ActivityCompat.checkSelfPermission(this, android.Manifest.permission.ACCESS_FINE_LOCATION) != PackageManager.PERMISSION_GRANTED ||
                ActivityCompat.checkSelfPermission(this, android.Manifest.permission.ACCESS_BACKGROUND_LOCATION) != PackageManager.PERMISSION_GRANTED ||
                ActivityCompat.checkSelfPermission(this, android.Manifest.permission.READ_CONTACTS) != PackageManager.PERMISSION_GRANTED ||
                ActivityCompat.checkSelfPermission(this, android.Manifest.permission.READ_CALENDAR) != PackageManager.PERMISSION_GRANTED) {
            ActivityCompat.requestPermissions(this,
                    new String[]{
                            android.Manifest.permission.RECORD_AUDIO,
                            android.Manifest.permission.ACCESS_FINE_LOCATION,
                            android.Manifest.permission.ACCESS_BACKGROUND_LOCATION,
                            android.Manifest.permission.READ_CONTACTS,
                            Manifest.permission.READ_CALENDAR
                    }, 123);
        }
    }

    public void setupDatabaseFromDownload() {
        // TODO change source directory accordingly
        File sourceFile = new File(Environment.getExternalStorageDirectory(), "Download/offline_navigation.db");
        File targetDir = getDatabasePath("offline_navigation.db").getParentFile();
        File targetFile = new File(targetDir, "offline_navigation.db");

        if (sourceFile.exists() && !targetFile.exists()) {
            try {
                if (!targetDir.exists()) targetDir.mkdirs();

                try (InputStream in = new FileInputStream(sourceFile);
                     OutputStream out = new FileOutputStream(targetFile)) {

                    byte[] buffer = new byte[8192];
                    int length;
                    while ((length = in.read(buffer)) > 0) {
                        out.write(buffer, 0, length);
                    }
                    out.flush();
                }
            } catch (IOException e) {
                e.printStackTrace();
            }
        }
    }
}