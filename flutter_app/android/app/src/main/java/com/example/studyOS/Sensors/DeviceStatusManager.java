package com.example.studyOS.Sensors;

import android.app.KeyguardManager;
import android.bluetooth.BluetoothAdapter;
import android.content.Context;
import android.location.LocationManager;
import android.media.AudioManager;
import android.net.ConnectivityManager;
import android.net.NetworkCapabilities;
import android.os.PowerManager;

import com.example.studyOS.DataStructures.DeviceStatus;

public class DeviceStatusManager {

    private final Context context;

    public DeviceStatusManager(Context context) {
        this.context = context;
    }

    public DeviceStatus getDeviceStatus() {

        var bluetoothAdapter = BluetoothAdapter.getDefaultAdapter();
        boolean bluetooth = bluetoothAdapter != null && bluetoothAdapter.isEnabled();

        var connectivityManager = (ConnectivityManager) context.getSystemService(Context.CONNECTIVITY_SERVICE);
        var capabilities = connectivityManager.getNetworkCapabilities(connectivityManager.getActiveNetwork());
        boolean wifi = capabilities != null && capabilities.hasTransport(NetworkCapabilities.TRANSPORT_WIFI);
        boolean mobileData = capabilities != null && capabilities.hasTransport(NetworkCapabilities.TRANSPORT_CELLULAR);

        var locationManager = (LocationManager) context.getSystemService(Context.LOCATION_SERVICE);
        boolean gps = locationManager.isProviderEnabled(LocationManager.GPS_PROVIDER);

        var keyguardManager = (KeyguardManager) context.getSystemService(Context.KEYGUARD_SERVICE);
        boolean screenLock = keyguardManager.isDeviceLocked();

        var audioManager = (AudioManager) context.getSystemService(Context.AUDIO_SERVICE);
        int volume = audioManager.getStreamVolume(AudioManager.STREAM_MUSIC);
        var powerManager = (PowerManager) context.getSystemService(Context.POWER_SERVICE);
        boolean screen = powerManager.isInteractive();

        return new DeviceStatus(
                bluetooth,
                gps,
                screenLock,
                mobileData,
                screen,
                volume,
                wifi
        );
    }
}