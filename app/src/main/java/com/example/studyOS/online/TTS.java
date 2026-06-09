package com.example.studyOS.online;

import android.Manifest;
import android.content.Context;
import android.media.AudioAttributes;
import android.os.Bundle;
import android.os.Handler;
import android.os.Looper;
import android.speech.tts.TextToSpeech;
import android.speech.tts.UtteranceProgressListener;

import androidx.annotation.RequiresPermission;

import java.util.ArrayList;
import java.util.Locale;
import java.util.UUID;

public class TTS implements TextToSpeech.OnInitListener {

    private final TextToSpeech tts;
    private Runnable onDoneCallback;
    Context context;


    public TTS(Context context) {
        this.context = context;
        tts = new TextToSpeech(context, this);
    }

    public String setTTSLanguage(String language) {
        String voicePackage = "de-de-x-deb-network";


        if (language.equalsIgnoreCase("englisch")) {
            tts.setLanguage(Locale.ENGLISH);
            voicePackage = "en-en-x-deb-network";
        } else if (language.equalsIgnoreCase("spanisch")) {
            voicePackage = "es-es-x-deb-network";
            tts.setLanguage(new Locale("es", "ES"));
        } else if (language.equalsIgnoreCase("türkisch")) {
            tts.setLanguage(new Locale("tr", "TR"));
            voicePackage = "tr-tr-x-deb-network";
        } else {
            voicePackage = "de-de-x-deb-network";
            tts.setLanguage(Locale.GERMAN);
        }

        // setting the voice
        var voices = tts.getVoices();
        var voiceList = new ArrayList<>(voices);
        voiceList.stream().filter(v -> v.getName().toLowerCase().contains("de")).forEach(v -> System.out.println("Voice: " + v.getName()));

        String finalVoicePackage = voicePackage;
        voiceList.stream()
                .filter(v -> v.getName().equalsIgnoreCase(finalVoicePackage))
                .findFirst()
                .ifPresent(tts::setVoice);

        return "TTS auf " + language;
    }

    public void setOnDoneCallback(Runnable onDoneCallback) {
        this.onDoneCallback = onDoneCallback;
    }


    @Override
    public void onInit(int status) {
        if (status == TextToSpeech.SUCCESS) {
            tts.setLanguage(Locale.GERMAN);
            tts.setEngineByPackageName("com.google.android.tts");

            tts.setSpeechRate(1.2f);
            tts.setPitch(0.98f);

            var audioAttributes = new AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_ASSISTANT)
                    .setContentType(AudioAttributes.CONTENT_TYPE_SPEECH)
                    .build();
            tts.setAudioAttributes(audioAttributes);

            // setting the voice
            var voices = tts.getVoices();
            var voiceList = new ArrayList<>(voices);
            voiceList.stream().filter(v -> v.getName().toLowerCase().contains("de")).forEach(v -> System.out.println("Voice: " + v.getName()));

            voiceList.stream()
                    .filter(v -> v.getName().equalsIgnoreCase("de-de-x-deb-network"))
                    .findFirst()
                    .ifPresent(tts::setVoice);


            tts.setOnUtteranceProgressListener(new UtteranceProgressListener() {
                @Override
                public void onDone(String utteranceId) {
                    // stopMicMonitoring();
                    triggerCallback();

                    // TODO needs to be tested -> trying to improve BLE connectivity
                    // new Handler(Looper.getMainLooper()).post(() -> bleSpeechRouter.routeToBleHeadset());
                }

                @Override
                public void onError(String utteranceId) {
                    // stopMicMonitoring();
                    // bleSpeechRouter.clearRouting();
                    System.err.println("An TTS ERROR!!!! " + utteranceId);
                    triggerCallback();
                }

                @RequiresPermission(Manifest.permission.RECORD_AUDIO)
                @Override
                public void onStart(String utteranceId) {
                    //startMicMonitoring();
                }
            });


        }
    }

    public void speakOut(String text) {
        // Pausen-Hack = Punkte und KOmmas verbessern, damit Google TTS atmet
        String optimizedText = text.replaceAll(",", " , ")
                .replace("Sir.", " Sir. ")
                .replaceAll(":", " : ")
                .replaceAll("\n", " . ")
                .replaceAll("!", " ! ")
                .replaceAll("J.A.R.V.I.S", "JARVIS")
                .replaceAll("(?i)J.A.R.V.I.S", "Dcharwis") // "J" weich aussprechen wie im Englischen
                .replaceAll("KI", "K I ")
                .replaceAll("(\\d+),(\\d+)", "$1 komma $2")
                .replaceAll("\\?", " ? ");


        var utteranceId = UUID.randomUUID().toString(); // einmalige ID
        var params = new Bundle();
        params.putFloat(TextToSpeech.Engine.KEY_PARAM_VOLUME, 1.0f);
        tts.speak(optimizedText, TextToSpeech.QUEUE_FLUSH, params, utteranceId);
    }

    /*public void stop() {
        if (tts.isSpeaking()) tts.stop();
    } */

    public void shutdown() {
        tts.stop();
        tts.shutdown();
    }

    public TextToSpeech getTTS() {
        return tts;
    }

    public void triggerCallback() {
        if (onDoneCallback != null) new Handler(Looper.getMainLooper()).post(onDoneCallback);
    }

}