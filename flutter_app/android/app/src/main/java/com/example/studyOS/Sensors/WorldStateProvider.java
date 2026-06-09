package com.example.studyOS.Sensors;

import android.content.Context;

import com.example.studyOS.DataStructures.WorldState;

import java.text.SimpleDateFormat;
import java.util.Date;
import java.util.Locale;

public class WorldStateProvider {

    private static WorldStateProvider instance;
    private final MotionSensorManager motionSensorManager;
    private final DeviceStatusManager deviceStatusManager;
    private final GPSManager gpsManager;
    private final GeoCodeManager geoCodeManager;
    private volatile WorldState currentWorldState;
    private long frequency;

    private WorldStateProvider(Context context, long frequency) {
        motionSensorManager = new MotionSensorManager(context);
        deviceStatusManager = new DeviceStatusManager(context);
        geoCodeManager = new GeoCodeManager(context);
        gpsManager = new GPSManager(context);

        this.frequency = frequency;
        startUpdater();
    }

    public static synchronized WorldStateProvider init(Context context, long frequency) {
        if (instance == null)
            instance = new WorldStateProvider(context.getApplicationContext(), frequency);

        return instance;
        /* return (instance == null)
                ? new WorldStateProvider(context.getApplicationContext())
                : instance; */
    }

    public static WorldStateProvider getInstance() {
        if (instance == null) {
            System.out.println("Fehler im WorldstateProvider initialization");
            throw new IllegalStateException("WorldStateProvider not initialized");
        }

        return instance;
    }

    /**
     * DIE globale Methode.
     */
    public WorldState getWorldState() {
        return currentWorldState;
    }

    public void setFrequence(long frequency) {
        this.frequency = frequency;
    }


    private void startUpdater() {
        new Thread(() -> {
            while (true) {
                try {
                    var motion = motionSensorManager.getMotionData();
                    var deviceStatus = deviceStatusManager.getDeviceStatus();
                    var gps = gpsManager.getGPS();
                    var now = new Date();

                    var date = new SimpleDateFormat("dd.MM.yyyy", Locale.getDefault()).format(now);
                    var time = new SimpleDateFormat("HH:mm:ss", Locale.getDefault()).format(now);
                    var weekday = new SimpleDateFormat("EEEE", Locale.getDefault()).format(now);

                    var geocoded = geoCodeManager.getAddress(gps);
                    System.out.println("geocoded: " + geocoded);

                    currentWorldState = new WorldState(date, time, weekday, deviceStatus, gps, geocoded, motion);
                    // System.out.println("WORLD_STATE: " + currentWorldState);

                    Thread.sleep(frequency);
                } catch (Exception e) {
                    e.printStackTrace();
                }
            }

        }).start();
    }
}