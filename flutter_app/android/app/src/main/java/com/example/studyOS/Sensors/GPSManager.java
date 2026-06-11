package com.example.studyOS.Sensors;

import android.annotation.SuppressLint;
import android.content.Context;
import android.location.Location;
import android.location.LocationListener;
import android.location.LocationManager;
import android.os.Looper;

import com.example.studyOS.DataStructures.GPS;

public class GPSManager {

    private final Context context;
    private final LocationManager locationManager;

    private volatile double lat = 0.0;
    private volatile double lon = 0.0;

    public GPSManager(Context context) {
        this.context = context;
        this.locationManager = (LocationManager) context.getSystemService(Context.LOCATION_SERVICE);
        startListening();
    }

    @SuppressLint("MissingPermission")
    private void startListening() {

        LocationListener listener = new LocationListener() {

            @Override
            public void onLocationChanged(Location location) {
                lat = location.getLatitude();
                lon = location.getLongitude();
            }
        };

        locationManager.requestLocationUpdates(
                LocationManager.GPS_PROVIDER,
                2000,   // 1 Sekunde
                1,      // 1 Meter
                listener,
                Looper.getMainLooper()
        );
    }

    public GPS getGPS() {
        return new GPS(lat, lon);
    }
}