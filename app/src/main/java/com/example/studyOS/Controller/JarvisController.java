package com.example.studyOS.Controller;

import android.Manifest;
import android.content.Context;
import android.content.pm.PackageManager;

import androidx.core.app.ActivityCompat;

import com.example.studyOS.DataStructures.MemoryEntry;
import com.example.studyOS.DataStructures.Message;
import com.example.studyOS.DataStructures.Speaker;
import com.example.studyOS.DataStructures.WorldState;
import com.example.studyOS.Interfaces.Brain;
import com.example.studyOS.Memory.FileIO;
import com.example.studyOS.Memory.StorageFiles;
import com.example.studyOS.Sensors.WorldStateProvider;
import com.example.studyOS.System.BrainFactory;
import com.example.studyOS.offline.JarvisBrainOffline;
import com.example.studyOS.online.JarvisBrainOnline;
import com.example.studyOS.online.SpeechRecognitionManager;
import com.example.studyOS.online.TTS;
import com.example.studyOS.online.ToolManager;

import okhttp3.OkHttpClient;

public class JarvisController {

    private static JarvisController instance;
    private final SpeechRecognitionManager speechRecognitionManager;
    private final TTS tts;


    private JarvisController(Context context) {
        this.tts = new TTS(context);
        ToolManager toolManager = new ToolManager(new OkHttpClient(), context);


        if (ActivityCompat.checkSelfPermission(context, Manifest.permission.ACCESS_FINE_LOCATION) != PackageManager.PERMISSION_GRANTED
                || ActivityCompat.checkSelfPermission(context, Manifest.permission.ACCESS_COARSE_LOCATION) != PackageManager.PERMISSION_GRANTED)
            System.err.println("Location permission required!");

        this.speechRecognitionManager = new SpeechRecognitionManager(context, tts);

        JarvisBrainOnline.getInstance().setTTS(tts);
        JarvisBrainOnline.getInstance().setSpeechRecognitionManager(speechRecognitionManager);
        JarvisBrainOnline.getInstance().setToolManager(toolManager);


        JarvisBrainOffline.getInstance().setTTS(tts);
        JarvisBrainOffline.getInstance().setSpeechRecognitionManager(speechRecognitionManager);
        JarvisBrainOffline.getInstance().initEngine(context);
    }

    public static synchronized JarvisController init(Context context) {
        if (instance == null)
            instance = new JarvisController(context);

        return instance;
    }

    public static JarvisController getInstance() {
        if (instance == null)
            throw new IllegalStateException("JarvisController not initialized");

        return instance;
    }

    // =========================================================
    // MAIN INPUT PIPELINE
    // =========================================================

    /**
     * Universeller Input.
     *
     * Egal ob:
     * - UI Text
     * - SpeechRecognition
     * - Bluetooth
     * - später Vision/OCR
     *
     * Alles landet hier.
     */
    public void process(Message message) {
        if (message == null || message.text().isBlank())
            return;

        if (message.speaker() == Speaker.JARVIS)
            return;

        var worldState = WorldStateProvider.getInstance().getWorldState();
        var memoryEntry = new MemoryEntry(message.speaker(), message.text(), worldState, "unknown", true); // TODO replace true by implementation of isSpeakingToJ -> TensorflowLite NN
        FileIO.getInstance().appendMemory(StorageFiles.MEMORY, memoryEntry);
        System.out.println("Storing to memory: " + memoryEntry.toString());

        // Prüfen ob gerade wirklich mit Jarvis gesprochen wird:
        if (!isSpeakingToJarvis(message.text(), worldState))
            return;

        // ONLINE / OFFLINE ENTSCHEIDUNG
        Brain selectedBrain = BrainFactory.getBrain();
        selectedBrain.process(message.text());
    }

    // =========================================================
    // FUTURE NN / TFLITE ACTIVATION DETECTION
    // =========================================================

    /**
     * Später:
     * TensorFlow Lite Modell.
     *
     * Soll erkennen:
     * - spricht User MIT Jarvis?
     * - oder nur nebenbei?
     * - oder Gespräch mit anderer Person?
     * - passive listening?
     */
    private boolean isSpeakingToJarvis(String text, WorldState worldState) {
        // TODO:
        // TensorFlow Lite Modell integrieren

        return true;
    }
}