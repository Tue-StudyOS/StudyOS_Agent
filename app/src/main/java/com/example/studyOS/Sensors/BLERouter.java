package com.example.studyOS.Sensors;

import android.content.Context;
import android.media.AudioDeviceInfo;
import android.media.AudioFocusRequest;
import android.media.AudioManager;
import android.media.audiofx.AcousticEchoCanceler;
import android.media.audiofx.NoiseSuppressor;
import android.os.Handler;
import android.os.Looper;

import androidx.annotation.Nullable;

public class BLERouter {
    private final AudioManager audioManager;
    private AudioFocusRequest focusRequest;
    private final Context context;

    @FunctionalInterface
    public interface OnRouteReadyListener {
        void onRouteReady();
    }

    public BLERouter(Context context) {
        this.context = context;
        this.audioManager = (AudioManager) context.getSystemService(Context.AUDIO_SERVICE);
    }

    private @Nullable AudioDeviceInfo findBleHeadset() {
        for (var d : audioManager.getDevices(AudioManager.GET_DEVICES_OUTPUTS)) {
            if (d.getType() == AudioDeviceInfo.TYPE_BLE_HEADSET || d.getType() == AudioDeviceInfo.TYPE_BLUETOOTH_SCO) {
                return d;
            }
        }
        return null;
    }

    public void routeToBleHeadset(OnRouteReadyListener listener) {
        var target = findBleHeadset();

        if (target == null) {
            if (listener != null) listener.onRouteReady();
            return;
        }

        audioManager.setMode(AudioManager.MODE_IN_COMMUNICATION);

        focusRequest = new AudioFocusRequest.Builder(AudioManager.AUDIOFOCUS_GAIN_TRANSIENT_EXCLUSIVE)
                .setOnAudioFocusChangeListener(focusChange -> {})
                .build();

        audioManager.requestAudioFocus(focusRequest);
        audioManager.setCommunicationDevice(target);

        // 🔹 Hardware-Filter aktivieren
        try {
            int audioSessionId = audioManager.generateAudioSessionId();
            if (NoiseSuppressor.isAvailable()) {
                NoiseSuppressor.create(audioSessionId);
            }
            if (AcousticEchoCanceler.isAvailable()) {
                AcousticEchoCanceler.create(audioSessionId);
            }
        } catch (Exception e) {
            System.err.println("Konnte Hardware-Filter nicht laden: " + e.getMessage());
        }

        new Handler(Looper.getMainLooper()).postDelayed(() -> {
            if (listener != null) listener.onRouteReady();
        }, 800);
    }

    public void clearRouting() {
        audioManager.clearCommunicationDevice();
        if (focusRequest != null) {
            audioManager.abandonAudioFocusRequest(focusRequest);
            focusRequest = null;
        }
        audioManager.setMode(AudioManager.MODE_NORMAL);
    }
}