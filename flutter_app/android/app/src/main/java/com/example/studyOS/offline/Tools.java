package com.example.studyOS.offline;

import android.annotation.SuppressLint;
import android.content.Context;
import android.content.Intent;
import android.content.pm.ApplicationInfo;
import android.content.pm.PackageManager;
import android.database.Cursor;
import android.hardware.camera2.CameraManager;
import android.media.AudioManager;
import android.net.Uri;
import android.net.wifi.WifiManager;
import android.os.Handler;
import android.os.Looper;
import android.provider.CalendarContract;
import android.provider.MediaStore;
import android.provider.Settings;
import android.util.Log;

import java.util.List;

public class Tools {

    private static final String TAG = "JarvisTools";
    private final Context context;
    private final Handler mainHandler;

    public Tools(Context context) {
        this.context = context;
        this.mainHandler = new Handler(Looper.getMainLooper());
    }

    // ==========================================
    // MULTIMEDIA & SUCHE
    // ==========================================

    public void searchYoutube(String content) {
        mainHandler.postDelayed(() -> {
            var intent = new Intent(Intent.ACTION_VIEW, Uri.parse("https://www.youtube.com/results?search_query=" + Uri.encode(content)));
            intent.setFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
            context.startActivity(intent);
        }, 600);
    }

    public String setVolume(int level) {
        try {
            AudioManager audioManager = (AudioManager) context.getSystemService(Context.AUDIO_SERVICE);
            int maxVolume = audioManager.getStreamMaxVolume(AudioManager.STREAM_MUSIC);
            int targetVolume = Math.max(0, Math.min(level, maxVolume)); // Begrenzt auf 0 bis Max

            audioManager.setStreamVolume(AudioManager.STREAM_MUSIC, targetVolume, AudioManager.FLAG_SHOW_UI);
            return "Lautstärke wurde auf " + targetVolume + " von " + maxVolume + " gesetzt.";
        } catch (Exception e) {
            Log.e(TAG, "Fehler bei Lautstärkeregelung", e);
            return "Systemfehler: Lautstärke konnte nicht geändert werden.";
        }
    }

    // ==========================================
    // HARDWARE-KONTROLLE
    // ==========================================

    public String toggleFlashlight(boolean state) {
        try {
            CameraManager camManager = (CameraManager) context.getSystemService(Context.CAMERA_SERVICE);
            if (camManager != null) {
                String cameraId = camManager.getCameraIdList()[0]; // Standardmäßig die Hauptkamera
                camManager.setTorchMode(cameraId, state);
                return "Taschenlampe wurde " + (state ? "eingeschaltet" : "ausgeschaltet") + ".";
            }
            return "Kamera-Service nicht verfügbar.";
        } catch (Exception e) {
            Log.e(TAG, "Fehler bei Taschenlampe", e);
            return "Systemfehler: Taschenlampe reagiert nicht.";
        }
    }

    // ==========================================
    // SYSTEM & NETZWERK (Toggles & Settings)
    // ==========================================

    public String toggleWifi(boolean state) {
        try {
            // Ab Android 10 (API 29) kann WifiManager.setWifiEnabled() fehlschlagen.
            // In dem Fall öffnen wir das Settings-Panel.
            WifiManager wifiManager = (WifiManager) context.getApplicationContext().getSystemService(Context.WIFI_SERVICE);
            if (wifiManager != null) {
                wifiManager.setWifiEnabled(state);
                return "WLAN wurde " + (state ? "eingeschaltet" : "ausgeschaltet") + ".";
            }
        } catch (Exception e) {
            openSettingsPanel(Settings.ACTION_WIFI_SETTINGS);
            return "Direkter WLAN-Zugriff verweigert. Einstellungen wurden geöffnet.";
        }
        return "WLAN-Status konnte nicht geändert werden.";
    }

    public String toggleBluetooth() {
        // Bluetooth direkt umschalten erfordert komplexe Permissions in modernen APIs.
        // Sicherer und zuverlässiger ist das direkte Öffnen der Bluetooth-Einstellungen.
        openSettingsPanel(Settings.ACTION_BLUETOOTH_SETTINGS);
        return "Bluetooth-Schnittstelle geöffnet.";
    }

    public String toggleGPS() {
        // GPS darf unter Android nicht direkt von Apps umgeschaltet werden.
        openSettingsPanel(Settings.ACTION_LOCATION_SOURCE_SETTINGS);
        return "Standort-Einstellungen geöffnet. Direkte Modifikation durch Protokolle gesperrt.";
    }

    public String toggleMobileData() {
        // Mobile Daten dürfen ebenfalls nicht direkt umgeschaltet werden.
        openSettingsPanel(Settings.ACTION_DATA_ROAMING_SETTINGS);
        return "Netzwerk-Einstellungen geöffnet.";
    }

    private void openSettingsPanel(String action) {
        Intent intent = new Intent(action);
        intent.setFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
        context.startActivity(intent);
    }

    // ==========================================
    // GERÄTE-STATUS
    // ==========================================

    public String getDeviceStatus() {
        StringBuilder status = new StringBuilder("Aktueller Systemstatus:\n");

        // Lautstärke
        AudioManager audio = (AudioManager) context.getSystemService(Context.AUDIO_SERVICE);
        if (audio != null) {
            status.append("- Medien-Lautstärke: ").append(audio.getStreamVolume(AudioManager.STREAM_MUSIC)).append("\n");
        }

        // WLAN Status
        WifiManager wifi = (WifiManager) context.getApplicationContext().getSystemService(Context.WIFI_SERVICE);
        if (wifi != null) {
            status.append("- WLAN: ").append(wifi.isWifiEnabled() ? "Aktiviert" : "Deaktiviert").append("\n");
        }

        // GPS Status
        try {
            int locationMode = Settings.Secure.getInt(context.getContentResolver(), Settings.Secure.LOCATION_MODE);
            status.append("- GPS/Standort: ").append(locationMode != Settings.Secure.LOCATION_MODE_OFF ? "Aktiviert" : "Deaktiviert").append("\n");
        } catch (Settings.SettingNotFoundException e) {
            status.append("- GPS/Standort: Unbekannt\n");
        }

        // Flugmodus
        boolean isAirplaneMode = Settings.Global.getInt(context.getContentResolver(), Settings.Global.AIRPLANE_MODE_ON, 0) != 0;
        status.append("- Flugmodus: ").append(isAirplaneMode ? "Aktiv" : "Inaktiv");

        return status.toString();
    }

    // ==========================================
    // APPS & TELEFONIE
    // ==========================================

    public String openApp(String appName) {
        String query = appName.toLowerCase();
        Intent intent = null;

        // Native System-Apps bevorzugt behandeln
        if (query.contains("kamera")) {
            intent = new Intent(MediaStore.INTENT_ACTION_STILL_IMAGE_CAMERA);
        } else if (query.contains("galerie") || query.contains("fotos")) {
            intent = new Intent(Intent.ACTION_VIEW, Uri.parse("content://media/internal/images/media"));
        } else {
            // Durchsuche alle installierten Apps nach dem passenden Namen
            PackageManager pm = context.getPackageManager();
            List<ApplicationInfo> packages = pm.getInstalledApplications(PackageManager.GET_META_DATA);

            for (ApplicationInfo packageInfo : packages) {
                String installedAppName = pm.getApplicationLabel(packageInfo).toString().toLowerCase();
                if (installedAppName.contains(query)) {
                    intent = pm.getLaunchIntentForPackage(packageInfo.packageName);
                    break;
                }
            }
        }

        if (intent != null) {
            intent.setFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
            context.startActivity(intent);
            return "Anwendung '" + appName + "' wurde gestartet.";
        }

        return "Sir, ich konnte keine App mit dem Namen '" + appName + "' finden.";
    }

    @SuppressLint("MissingPermission")
    public String makeCall(String phoneNumber) {
        if (phoneNumber == null || phoneNumber.isEmpty()) return "Fehler: Keine Nummer angegeben.";
        try {
            // ACTION_CALL ruft direkt an (benötigt CALL_PHONE Permission).
            // Alternativ: ACTION_DIAL öffnet nur das Tastenfeld mit der Nummer.
            Intent intent = new Intent(Intent.ACTION_CALL);
            intent.setData(Uri.parse("tel:" + phoneNumber.trim()));
            intent.setFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
            context.startActivity(intent);
            return "Verbindung zu " + phoneNumber + " wird hergestellt.";
        } catch (SecurityException e) {
            Log.e(TAG, "Berechtigung für Anrufe fehlt.", e);
            return "Zugriff verweigert. Ich benötige die Telefon-Berechtigung, Sir.";
        }
    }

    // ==========================================
    // KALENDER & NOTIZEN
    // ==========================================

    @SuppressLint("MissingPermission")
    public String readCalendar() {
        StringBuilder events = new StringBuilder("Anstehende Termine:\n");
        Uri.Builder builder = CalendarContract.Instances.CONTENT_URI.buildUpon();
        long now = System.currentTimeMillis();
        // Suche Termine für die nächsten 7 Tage
        long nextWeek = now + (7 * 24 * 60 * 60 * 1000L);

        android.content.ContentUris.appendId(builder, now);
        android.content.ContentUris.appendId(builder, nextWeek);

        String[] projection = new String[]{
                CalendarContract.Instances.TITLE,
                CalendarContract.Instances.BEGIN
        };

        try (Cursor cursor = context.getContentResolver().query(
                builder.build(), projection, null, null, CalendarContract.Instances.BEGIN + " ASC")) {

            if (cursor != null && cursor.moveToFirst()) {
                int count = 0;
                do {
                    String title = cursor.getString(0);
                    events.append("- ").append(title).append("\n");
                    count++;
                } while (cursor.moveToNext() && count < 5); // Maximal 5 Termine auslesen

                return events.toString();
            } else {
                return "Der Kalender ist leer, Sir. Keine anstehenden Termine.";
            }
        } catch (SecurityException e) {
            Log.e(TAG, "Berechtigung für Kalender fehlt.", e);
            return "Zugriff verweigert. Ich benötige die Kalender-Berechtigung, Sir.";
        } catch (Exception e) {
            Log.e(TAG, "Fehler beim Kalender lesen", e);
            return "Kalender-Datenbank konnte nicht abgefragt werden.";
        }
    }

    public String createNote(String title, String content) {
        // Öffnet den System-Teilen/Notizen-Dialog oder eine explizite Notiz-App
        try {
            Intent intent = new Intent(Intent.ACTION_SEND);
            intent.setType("text/plain");
            intent.putExtra(Intent.EXTRA_SUBJECT, title);
            intent.putExtra(Intent.EXTRA_TEXT, content);
            intent.setFlags(Intent.FLAG_ACTIVITY_NEW_TASK);

            // Nutze den Chooser, damit der Nutzer seine bevorzugte Notizen/Mail-App wählen kann
            Intent chooser = Intent.createChooser(intent, "Notiz speichern in...");
            chooser.setFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
            context.startActivity(chooser);

            return "Notiz-Protokoll wurde generiert und zur Speicherung übergeben.";
        } catch (Exception e) {
            Log.e(TAG, "Fehler beim Erstellen der Notiz", e);
            return "Fehler bei der Notiz-Erstellung.";
        }
    }
}