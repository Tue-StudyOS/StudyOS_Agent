package com.example.studyOS.offline;

import android.app.Notification;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.app.Service;
import android.content.Intent;
import android.hardware.Sensor;
import android.hardware.SensorEvent;
import android.hardware.SensorEventListener;
import android.hardware.SensorManager;
import android.location.Location;
import android.location.LocationListener;
import android.location.LocationManager;
import android.os.IBinder;

public class NavigationBackgroundService extends Service implements LocationListener, SensorEventListener {

    private LocationManager locationManager;
    private SensorManager sensorManager;
    private OfflineNavigationEngine navigationEngine;

    @Override
    public void onCreate() {
        super.onCreate();
        navigationEngine = new OfflineNavigationEngine(this);

        // GPS anwerfen
        locationManager = (LocationManager) getSystemService(LOCATION_SERVICE);
        try {
            locationManager.requestLocationUpdates(LocationManager.GPS_PROVIDER, 2000, 3, this);
        } catch (SecurityException e) { e.printStackTrace(); }

        // Kompass anwerfen
        sensorManager = (SensorManager) getSystemService(SENSOR_SERVICE);
        Sensor rotationVector = sensorManager.getDefaultSensor(Sensor.TYPE_ROTATION_VECTOR);
        if (rotationVector != null) {
            sensorManager.registerListener(this, rotationVector, SensorManager.SENSOR_DELAY_UI);
        }

        startForeground(99, createNotification());
    }

    @Override
    public void onLocationChanged(Location location) {
        // Daten in die Engine pumpen
        OfflineNavigationEngine.updateCurrentLocation(location);
        // navigationEngine.processNavigationUpdate(location);
    }

    @Override
    public void onSensorChanged(SensorEvent event) {
        if (event.sensor.getType() == Sensor.TYPE_ROTATION_VECTOR) {
            float[] rotationMatrix = new float[9];
            float[] orientationAngles = new float[3];
            SensorManager.getRotationMatrixFromVector(rotationMatrix, event.values);
            SensorManager.getOrientation(rotationMatrix, orientationAngles);

            float heading = (float) Math.toDegrees(orientationAngles[0]);
            if (heading < 0) heading += 360;

            // OfflineNavigationEngine.updateCurrentHeading(heading);
        }
    }

    private Notification createNotification() {
        String channelId = "offline_nav_channel";
        NotificationManager nm = (NotificationManager) getSystemService(NOTIFICATION_SERVICE);
        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
            NotificationChannel channel = new NotificationChannel(channelId, "Offline Navigation", NotificationManager.IMPORTANCE_LOW);
            nm.createNotificationChannel(channel);
        }
        return new Notification.Builder(this, channelId)
                .setContentTitle("StudyOS Offline-Navigation")
                .setContentText("Positions- und Richtungstracking im Hintergrund aktiv.")
                .build();
    }

    @Override public int onStartCommand(Intent intent, int flags, int startId) { return START_STICKY; }
    @Override public IBinder onBind(Intent intent) { return null; }
    @Override public void onAccuracyChanged(Sensor sensor, int accuracy) {}

    @Override
    public void onDestroy() {
        super.onDestroy();
        if (locationManager != null) locationManager.removeUpdates(this);
        if (sensorManager != null) sensorManager.unregisterListener(this);
        // if (navigationEngine != null) navigationEngine.shutdown();
    }
}