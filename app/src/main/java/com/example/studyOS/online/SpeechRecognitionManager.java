package com.example.studyOS.online;

import android.Manifest;
import android.app.Activity;
import android.content.Context;
import android.content.Intent;
import android.media.AudioManager;
import android.media.ToneGenerator;
import android.os.Bundle;
import android.os.Handler;
import android.os.Looper;
import android.speech.RecognitionListener;
import android.speech.RecognizerIntent;
import android.speech.SpeechRecognizer;

import androidx.annotation.RequiresPermission;

import com.example.studyOS.Sensors.BLERouter;
import com.example.studyOS.UI.UIManager;

import java.util.List;

public class SpeechRecognitionManager {

    private final Context context;
    private final SpeechRecognizer speechRecognizer;
    private final Intent intent;
    private final ToneGenerator toneGenerator;
    private final BLERouter bleRouter;
    private final TTS tts;

    // ==========================================
    // STATE & MEMORY
    // ==========================================
    private long lastRestartTime = 0;
    private boolean isListeningForInterrupt = false;
    private boolean isTtsJustFinished = false;

    // PASSIVE LISTENING FEATURE
    private boolean isPassiveMode = false;
    private final StringBuilder passiveMemory = new StringBuilder();

    @RequiresPermission(allOf = {Manifest.permission.ACCESS_FINE_LOCATION, Manifest.permission.ACCESS_COARSE_LOCATION})
    public SpeechRecognitionManager(Context context, TTS tts) {
        this.context = context;
        this.tts = tts;
        this.bleRouter = new BLERouter(context);
        this.toneGenerator = new ToneGenerator(AudioManager.STREAM_MUSIC, 70);

        this.intent = new Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH);
        this.intent.putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM);
        this.intent.putExtra(RecognizerIntent.EXTRA_LANGUAGE, setRecognitionLanguage("deutsch"));
        // Optimiert für schnelles Online-Erkennen
        this.intent.putExtra(RecognizerIntent.EXTRA_SPEECH_INPUT_COMPLETE_SILENCE_LENGTH_MILLIS, 2500L);
        this.intent.putExtra(RecognizerIntent.EXTRA_SPEECH_INPUT_POSSIBLY_COMPLETE_SILENCE_LENGTH_MILLIS, 2000L);
        this.intent.putExtra(RecognizerIntent.EXTRA_MAX_RESULTS, 1);
        this.intent.putExtra(RecognizerIntent.EXTRA_PREFER_OFFLINE, false); // Explizit für Online-Modus

        this.speechRecognizer = SpeechRecognizer.createSpeechRecognizer(context);
        this.speechRecognizer.setRecognitionListener(createRecognitionListener());

        this.tts.setOnDoneCallback(this::startListening);
    }

    // ==========================================
    // CONTROL METHODS
    // ==========================================

    public void startListening() {

        if (tts.getTTS().isSpeaking()) {
            System.out.println("SRM: Jarvis spricht noch, starte Zuhören nicht.");
            return;
        }

        speechRecognizer.cancel();
        isTtsJustFinished = true;

        new Handler(Looper.getMainLooper()).postDelayed(() -> {
            isTtsJustFinished = false;
            isListeningForInterrupt = true;
        }, 800);

        bleRouter.routeToBleHeadset(() -> {
            try {
                speechRecognizer.startListening(intent);
            } catch (Exception e) {
               System.err.println("Start Error: " + e.getMessage());
            }
        });
    }

    public void stopListening() {
        bleRouter.clearRouting();
        speechRecognizer.stopListening();
    }

    public void destroy() {
        if (toneGenerator != null) toneGenerator.release();
        speechRecognizer.destroy();
    }

    public String setRecognitionLanguage(String language) {
        String languageCode = "de-DE";

        if (language.equalsIgnoreCase("türkisch"))
            languageCode = "tr-TR";
        else if (language.equalsIgnoreCase("deutsch"))
            languageCode = "de-DE";
        else if (language.equalsIgnoreCase("englisch"))
            languageCode = "en-US";
        else if (language.equalsIgnoreCase("italienisch"))
            languageCode = "it-IT";
        else if (language.equalsIgnoreCase("spanisch"))
            languageCode = "es-ES";

        this.intent.putExtra(RecognizerIntent.EXTRA_LANGUAGE, languageCode);
        return languageCode;
    }

    // ==========================================
    // RECOGNITION LISTENER
    // ==========================================

    private RecognitionListener createRecognitionListener() {
        return new RecognitionListener() {
            @Override
            public void onReadyForSpeech(Bundle params) {
                // Nur im aktiven Modus piepen
                if (!isPassiveMode) {
                    toneGenerator.startTone(ToneGenerator.TONE_PROP_BEEP, 100);
                }
            }

            @Override
            public void onBeginningOfSpeech() {

                if (!isTtsJustFinished && isListeningForInterrupt && tts.getTTS().isSpeaking()) {
                    tts.getTTS().stop();
                    isListeningForInterrupt = false;
                }

            }

            @Override
            public void onBufferReceived(byte[] buffer) {}

            @Override
            public void onEndOfSpeech() {}

            @Override
            public void onError(int error) {
                if (error == SpeechRecognizer.ERROR_CLIENT || error == SpeechRecognizer.ERROR_RECOGNIZER_BUSY) {
                    speechRecognizer.cancel();
                }

                // Robustere Restart-Logik für durchgehendes Zuhören
                long now = System.currentTimeMillis();
                long delay = (now - lastRestartTime < 2000) ? 100 : 2000;
                lastRestartTime = now;

                System.out.println("Error: " + error + " - Delay: " + delay);

                new Handler(Looper.getMainLooper()).postDelayed(() -> {
                    if (!tts.getTTS().isSpeaking())
                        startListening();
                    else
                        tts.setOnDoneCallback(SpeechRecognitionManager.this::startListening);

                }, delay);
            }

            @Override
            public void onEvent(int eventType, Bundle params) {}

            @Override
            public void onPartialResults(Bundle partialResults) {}

            @RequiresPermission(allOf = {Manifest.permission.ACCESS_FINE_LOCATION, Manifest.permission.ACCESS_COARSE_LOCATION})
            @Override
            public void onResults(Bundle results) {
                var matches = results.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION);
                if (matches == null || matches.isEmpty()) {
                    startListening();
                    return;
                }

                bleRouter.clearRouting();
                String recognizedText = matches.get(0);

                // Textverarbeitung an die neue Logik übergeben
                processRecognizedText(recognizedText);

                // Loop am Laufen halten
                // startListening();
            }

            @Override
            public void onRmsChanged(float rmsdB) {}
        };
    }

    // ==========================================
    // LOGIC & NLP PIPELINE
    // ==========================================

    private void processRecognizedText(String text) {
        String lowerText = text.toLowerCase();

        var terminatingTerms = List.of("auf wiedersehen", "tschüss", "terminieren", "bye");
        var isTerminating = terminatingTerms.stream().anyMatch(lowerText::contains);

        if (isTerminating) {
            tts.speakOut("Auf wiedersehen Sir. Hintergrundprozesse gestartet. Bereitschaftsmodus aktiv.");
            new Handler(Looper.getMainLooper()).postDelayed(() -> {
                speechRecognizer.stopListening();
                if (context instanceof Activity) {
                    ((Activity) context).finishAffinity();
                }
                System.exit(0);
            }, 6000);

            return;
        }

        // 1. Prüfen ob wir in den PASSIV-MODUS wechseln sollen
        if (!isPassiveMode && isSleepCommand(lowerText)) {
            isPassiveMode = true;
            toneGenerator.startTone(ToneGenerator.TONE_PROP_PROMPT, 150); // Bestätigungston (Zwei tiefe Töne)
            //JarvisController.getInstance().process(new Message("Verstanden, Sir. Ich höre nur passiv zu.", Speaker.JARVIS));
            if (tts != null)
                tts.speakOut("Verstanden sir.");

            return;
        }

        // 2. Prüfen ob wir wieder in den AKTIV-MODUS wechseln sollen
        if (isPassiveMode && isWakeCommand(lowerText)) {
            isPassiveMode = false;
            toneGenerator.startTone(ToneGenerator.TONE_PROP_ACK, 100); // Aufwach-Ton

            String gatheredContext = passiveMemory.toString().trim();
            passiveMemory.setLength(0); // Speicher leeren

            String transitionMessage = text;
            if (!gatheredContext.isEmpty())
                transitionMessage = "[System-Info: Während du passiv warst, wurde folgendes gesprochen: '" + gatheredContext + "'] " + text;


            UIManager.addUserMessage(transitionMessage);
            // JarvisController.getInstance().process(new Message(transitionMessage, Speaker.BOSS));
            return;
        }

        // 3. Normales Verhalten basierend auf dem Modus
        if (isPassiveMode) {
            // Sammle den Text, aber reagiere nicht
            System.out.println("PASSIVE LISTENING: " + text);
            passiveMemory.append(text).append(". ");
            speechRecognizer.startListening(intent);
        } else {
            // Leite direkt an den Controller weiter
            toneGenerator.startTone(ToneGenerator.TONE_PROP_ACK, 100);
            UIManager.addUserMessage(text);
            //JarvisController.getInstance().process(new Message(text, Speaker.BOSS));
        }
    }

    // ==========================================
    // FLEXIBLE KEYWORD DETECTION (REGEX)
    // ==========================================

    /**
     * Reagiert auf Sätze wie:
     * "Jarvis, hör kurz weg"
     * "Ich rede mit jemand anderem"
     * "Pausiere kurz"
     * "Nicht zuhören"
     */
    private boolean isSleepCommand(String text) {
        String[] keywords = {"hör weg", "hör mal kurz weg", "leiser modus", "leise sein modus", "halt die fresse", "halt die klappe", "halts maul", "du musst kurz leise sein", "pause", "pausiere", "schlaf", "standby", "warte kurz", "warte mal kurz", "einen moment", "nicht zuhören", "sei leise", "leise sein", "leise", "sei mal kurz leise", "sei mal wieder kurz leise"};
        for (String word : keywords) {
            if (text.contains(word)) return true;
        }
        return false;
    }

    /**
     * Reagiert auf Sätze wie:
     * "Jarvis, bist du da?"
     * "Hörst du mich?"
     * "Weiter gehts"
     * "Aufwachen"
     */
    private boolean isWakeCommand(String text) {
        String[] keywords = {"jarvis", "bist du da", "hörst du mich", "weiter", "aufwachen", "hör wieder zu", "du kannst wieder", "lass mich ihn kurz fragen", "lass mich mal nachschauen", "lass mal nachschauen", "lass mal fragen", "lass mal nachfragen", "lass mich es fragen"};
        for (String word : keywords) {
            if (text.contains(word)) return true;
        }
        return false;
    }
}