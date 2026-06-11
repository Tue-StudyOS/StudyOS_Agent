package com.example.studyOS.offline;

import android.content.Context;
import android.location.Location;
import android.os.Handler;
import android.os.Looper;
import android.util.Log;

import com.example.studyOS.DataStructures.MemoryEntry;
import com.example.studyOS.DataStructures.Speaker;
import com.example.studyOS.Interfaces.Brain;
import com.example.studyOS.Memory.FileIO;
import com.example.studyOS.Memory.StorageFiles;
import com.example.studyOS.Sensors.WorldStateProvider;
import com.example.studyOS.UI.UIManager;
import com.example.studyOS.online.SpeechRecognitionManager;
import com.example.studyOS.online.TTS;

import com.google.ai.edge.litertlm.Backend;
import com.google.ai.edge.litertlm.Contents;
import com.google.ai.edge.litertlm.Conversation;
import com.google.ai.edge.litertlm.ConversationConfig;
import com.google.ai.edge.litertlm.Engine;
import com.google.ai.edge.litertlm.EngineConfig;
import com.google.ai.edge.litertlm.Message;
import com.google.ai.edge.litertlm.SamplerConfig;

import java.io.File;
import java.io.FileOutputStream;
import java.io.InputStream;
import java.util.Collections;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Objects;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.function.Function;
import java.util.regex.Matcher;
import java.util.regex.Pattern;
import java.util.stream.Collectors;

public class JarvisBrainOffline implements Brain {

    private static final String TAG = "JarvisBrainOffline";
    private static volatile JarvisBrainOffline instance;

    private Context context;
    private Tools tools;
    private TTS tts;
    private SpeechRecognitionManager speechRecognitionManager;
    private OfflineNavigationEngine navEngine;

    private Engine engine;
    private Conversation conversation;
    private boolean isInitialized = false;

    private final ExecutorService executorService = Executors.newSingleThreadExecutor();
    private final Handler mainHandler = new Handler(Looper.getMainLooper());

    // DIE WERKZEUG-REGISTRIERUNG (Das Herzstück für schnelle Erweiterungen)
    private final Map<String, Function<String, String>> toolRegistry = new HashMap<>();

    private final String currentSystemMessage = """
            Du bist J.A.R.V.I.S. (Just A Rather Very Intelligent System), Version 9.
            Proaktiv, formell, präzise – mit einem Hauch trockenen Humors.
            Deine Antworten sind kurz, informativ und auf Deutsch. Keine Sonderzeichen in der antwort wie Stichpunkte oder *
            
            WICHTIG FÜR TOOLS (3-Phasen-System):
            PHASE 1: Wenn der Nutzer eine Aktion fordert (z.B. Orte suchen), antworte AUSSCHLIESSLICH mit dem Tool-Befehl, z.B.: [TOOL:ANALYZE_NEARBY:1000].
            PHASE 2: Überprüfe ob weitere Aktionen oder Tools aufgerufen werden müssen. Starte anschließend entsprechende ToolCalls.
            PHASE 3: Das System führt das Tool aus und schickt dir die Ergebnisse. Sobald du diese System-Ergebnisse erhältst, fasst du sie in einem eleganten, natürlichen Satz für den Nutzer zusammen und liest die gefundenen Daten vor! Übersetze eventuelle Inhalte auf deutsch!
                     Sehr wichtig ist hierbei eine kurze und knackige antwort die flüssig zum sprechen ist, damit die unterhaltung fortlaufen kann!
            
            Verfügbare Tools:
            - Licht an/aus: [TOOL:LIGHT_CONTROL:ON] / [TOOL:LIGHT_CONTROL:OFF]
            - WLAN an/aus: [TOOL:WIFI_CONTROL:ON] / [TOOL:WIFI_CONTROL:OFF]
            - Sprache wechseln: [TOOL:SWITCH_LANGUAGE:englisch]
            - App öffnen: [TOOL:OPEN_APP:Kamera]
            - YouTube Suche: [TOOL:SEARCH_YOUTUBE:Iron Man]
            - Status abfragen: [TOOL:GET_STATUS:]
            - Kalender lesen: [TOOL:READ_CALENDAR:]
            - Notiz erstellen: [TOOL:CREATE_NOTE:Titel|Inhalt]
            - Nahe Orte analysieren: [TOOL:ANALYZE_NEARBY:1000] (Die Zahl ist der Radius in Metern)
            - Gezielte Suche nach Typ/Name: [TOOL:FIND_PLACE:Apotheke|1000] oder [TOOL:FIND_PLACE:mosque|2000]
            - Ferne Orte analysieren (Geocoding): [TOOL:ANALYZE_REMOTE:Flughafen Frankfurt|2000]
            - Navigation starten: [TOOL:START_NAVIGATION:49.4875,8.4660|Wasserturm]
            - Richtung zum Ziel abfragen: [TOOL:GET_DIRECTION:]
            
            Zustand während Initialisierung:
            """;

    private JarvisBrainOffline() {}

    public static JarvisBrainOffline getInstance() {
        if (instance == null) {
            synchronized (JarvisBrainOffline.class) {
                if (instance == null) instance = new JarvisBrainOffline();
            }
        }
        return instance;
    }

    public void setTTS(TTS tts) { this.tts = tts; }
    public void setSpeechRecognitionManager(SpeechRecognitionManager manager) { this.speechRecognitionManager = manager; }

    public void initEngine(Context context) {
        if (isInitialized) return;

        this.context = context.getApplicationContext();
        this.tools = new Tools(this.context);

        setupTools(); // Werkzeuge laden

        executorService.submit(() -> {
            try {
                String modelPath = setupModelFile("gemma_mini.litertlm");

                var engineConfig = new EngineConfig(modelPath, new Backend.CPU(), null, null, 10_000, null, this.context.getCacheDir().getAbsolutePath());
                engine = new Engine(engineConfig);
                engine.initialize();

                var worldState = WorldStateProvider.getInstance().getWorldState();
                System.out.println("OFFLINE WORLD: " + worldState.toString());

                var config = new ConversationConfig(
                        Contents.Companion.of(currentSystemMessage + "\n " + worldState.toString()),
                        List.of(Message.Companion.user("System-Check eingeleitet.")),
                        List.of(),
                        new SamplerConfig(10, 0.95, 0.8, 0)
                );

                conversation = engine.createConversation(config);
                isInitialized = true;
                Log.i(TAG, "[JARVIS-LOG] Jarvis Offline-Systeme aktiv.");
            } catch (Exception e) {
                Log.e(TAG, "Kritischer Fehler beim Engine-Start", e);
            }
        });
    }

    // ==========================================
    // TOOL-REGISTRY: Hier fügst du neue Tools ein!
    // ==========================================
    private void setupTools() {
        if (navEngine == null)
            navEngine = new OfflineNavigationEngine(context);


        toolRegistry.put("OPEN_MUSIC", arg -> "System-Status: Die Musik-Infrastruktur wurde hochgefahren.");

        toolRegistry.put("SEARCH_YOUTUBE", arg -> {
            String query = arg.isEmpty() ? "Musik" : arg;
            tools.searchYoutube(query);
            return "System-Status: YouTube-Suchmatrix für '" + query + "' wurde geöffnet.";
        });

        toolRegistry.put("ANALYZE_NEARBY", arg -> {
            try {
                // 1. Argument sauber parsen (Fallback auf 500m, wenn leer oder ungültig)
                double radius;
                try {
                    radius = arg.isEmpty() ? 500.0 : Double.parseDouble(arg.trim());
                } catch (NumberFormatException e) {
                    radius = 500.0;
                }

                // 2. Welt-Zustand abrufen
                var state = WorldStateProvider.getInstance().getWorldState();

                if (state == null || state.gps() == null || state.gps().lat() == 0.0) {
                    return "Fehler: GPS-Koordinaten sind noch nicht bereit. Bitte in ein paar Sekunden erneut versuchen, Sir.";
                }

                // 3. Echte Koordinaten aus den Sensoren extrahieren
                double currentLat = state.gps().lat();
                double currentLon = state.gps().lon();

                // 4. Offline Navigation Engine starten und abfragen (Genau wie in deinem Main-Test!)
                var navEngine = new OfflineNavigationEngine(context);

                // Führt die exakte Such-Methode aus, die du programmiert hast
                String result = navEngine.analyzeNearbyFromCoordinates(currentLat, currentLon, radius);

                // 5. Ergebnisse evaluieren und an das LLM schicken
                if (result == null || result.trim().isEmpty()) {
                    return "System-Status: Ich konnte keine relevanten POIs im Umkreis von " + radius + " Metern in der Datenbank finden.";
                }

                return "Umgebungsanalyse (Radius: " + radius + "m) erfolgreich. Folgende Orte wurden gefunden:\n" + result;

            } catch (Exception e) {
                Log.e(TAG, "Kritischer Fehler bei ANALYZE_NEARBY", e);
                return "Systemfehler: Die Umgebungsanalyse ist fehlgeschlagen.";
            }
        });

        toolRegistry.put("FIND_PLACE", arg -> {
            try {
                String[] parts = arg.split("\\|");
                String searchStr = parts[0].trim();
                double radius = parts.length > 1 ? Double.parseDouble(parts[1].trim()) : 1000.0;

                var state = WorldStateProvider.getInstance().getWorldState();
                if (state == null || state.gps() == null || state.gps().lat() == 0.0) {
                    return "Fehler: GPS-Koordinaten sind nicht verfügbar.";
                }

                // Globale Sensor-Daten für die OfflineNavigationEngine aktualisieren
                Location currentLoc = new Location("");
                currentLoc.setLatitude(state.gps().lat());
                currentLoc.setLongitude(state.gps().lon());
                OfflineNavigationEngine.updateCurrentLocation(currentLoc);

                String result = navEngine.findNearbyPlaces(searchStr, radius);

                if (result.contains("Keine passenden Orte")) {
                    return "System-Status: Es wurde kein Ort mit dem Namen oder Typ '" + searchStr + "' im Umkreis von " + radius + "m gefunden.";
                }
                return "Suche nach '" + searchStr + "' erfolgreich. Gefundene Orte:\n" + result;

            } catch (Exception e) {
                Log.e(TAG, "Fehler bei FIND_PLACE", e);
                return "Systemfehler bei der Ortssuche.";
            }
        });

        // TOOL 2: Suche an einem fernen Ort (z.B. "Flughafen Frankfurt")
        toolRegistry.put("ANALYZE_REMOTE", arg -> {
            try {
                String[] parts = arg.split("\\|");
                String locationName = parts[0].trim();
                double radius = parts.length > 1 ? Double.parseDouble(parts[1].trim()) : 2000.0;

                // Android Geocoder wandelt den String in Koordinaten um
                android.location.Geocoder geocoder = new android.location.Geocoder(context, java.util.Locale.getDefault());
                java.util.List<android.location.Address> addresses = geocoder.getFromLocationName(locationName, 1);

                if (addresses == null || addresses.isEmpty()) {
                    return "System-Status: Ich konnte die Koordinaten für den Ort '" + locationName + "' nicht auflösen.";
                }

                android.location.Address address = addresses.get(0);
                double targetLat = address.getLatitude();
                double targetLon = address.getLongitude();

                // Nutzt deine bestehende Koordinaten-Suchmethode
                String result = navEngine.analyzeNearbyFromCoordinates(targetLat, targetLon, radius);

                return "Analyse der Region '" + locationName + "' (Radius: " + radius + "m) erfolgreich:\n" + result;

            } catch (Exception e) {
                Log.e(TAG, "Fehler bei ANALYZE_REMOTE", e);
                return "Systemfehler: Der Geocoding-Service ist aktuell nicht erreichbar.";
            }
        });

        // TOOL 3: Richtung zum aktuellen Ziel abfragen
        toolRegistry.put("GET_DIRECTION", arg -> {
            try {
                var state = WorldStateProvider.getInstance().getWorldState();
                if (state != null && state.gps() != null) {
                    Location currentLoc = new Location("");
                    currentLoc.setLatitude(state.gps().lat());
                    currentLoc.setLongitude(state.gps().lon());
                    OfflineNavigationEngine.updateCurrentLocation(currentLoc);

                    // Falls du Kompass-Daten im WorldState hast, hier übergeben:
                    // OfflineNavigationEngine.updateCurrentHeading(state.compass().azimuth());
                }

                // Liest die Richtung aus der globalen Instanz
                System.out.println("direction: " + navEngine.getTargetDirection());
                return navEngine.getTargetDirection();

            } catch (Exception e) {
                Log.e(TAG, "Fehler bei GET_DIRECTION", e);
                return "Fehler beim Abrufen der Richtungsdaten.";
            }
        });

        // TOOL 4: Navigation manuell starten (damit GET_DIRECTION ein Ziel hat)
        toolRegistry.put("START_NAVIGATION", arg -> {
            try {
                String[] parts = arg.split("\\|");
                String[] coords = parts[0].split(",");
                double lat = Double.parseDouble(coords[0].trim());
                double lon = Double.parseDouble(coords[1].trim());
                String placeName = parts.length > 1 ? parts[1].trim() : "Unbekanntes Ziel";

                return navEngine.startNavigation(lat, lon, placeName);
            } catch (Exception e) {
                Log.e(TAG, "Fehler bei START_NAVIGATION", e);
                return "Fehler: Koordinatenformat ungültig.";
            }
        });

        toolRegistry.put("LIGHT_CONTROL", arg -> {
            boolean turnOn = arg.toUpperCase().contains("ON") || arg.toUpperCase().contains("AN");
            return tools.toggleFlashlight(turnOn);
        });

        toolRegistry.put("SWITCH_LANGUAGE", arg -> {
            String language = arg.toLowerCase();
            speechRecognitionManager.setRecognitionLanguage(language);
            return "Sprache wurde auf '" + language + "' gesetzt.";
        });


        // BEISPIEL FÜR NEUES TOOL (Einfach kopieren und anpassen):
        // toolRegistry.put("LIGHTS_ON", arg -> { tools.turnOnLights(); return "Beleuchtung aktiviert."; });
    }

    @Override
    public void process(String text) {
        if (text == null || text.isBlank()) return;

        executorService.submit(() -> {
            try {
                var worldState = WorldStateProvider.getInstance().getWorldState();
                var textEnhanced = text + "\nAktuelle Kontextinformationen: " + worldState.toString();
                var response = ask(textEnhanced);

                mainHandler.post(() -> {
                    if (tts != null) tts.speakOut(response);
                    FileIO.getInstance().appendMemory(StorageFiles.MEMORY, new MemoryEntry(Speaker.JARVIS, response, worldState, "unknown", false));
                    UIManager.addJarvisMessage(response);
                });
            } catch (Exception e) {
                Log.e(TAG, "Inferenz-Absturz", e);
                mainHandler.post(() -> {
                    if (tts != null) tts.speakOut("Offline-Kerne blockieren.");
                    UIManager.addJarvisMessage("Systemfehler bei Verarbeitung.");
                });
            }
        });
    }

    private String ask(String text) {
        if (!isInitialized || conversation == null) return "Fehler: Lokale Systeme offline.";

        try {
            var responseText = extractTextFromMessage(conversation.sendMessage(text, Collections.emptyMap()));

            // Wenn mindestens ein Tool aufgerufen wurde, an den neuen Multi-Tool-Handler übergeben
            if (isToolCall(responseText))
                return executeMultipleToolCalls(responseText);


            return responseText;
        } catch (Exception e) {
            Log.e(TAG, "Inferenz-Fehler", e);
            return "Fehler beim Generieren der Antwort.";
        }
    }

    private boolean isToolCall(String text) {
        return text != null && text.contains("[TOOL:");
    }

    // Der NEUE Handler für beliebig viele Tools
    private String executeMultipleToolCalls(String responseText) {
        Log.w(TAG, "Tool-Anfragen erkannt: \n" + responseText);

        Pattern pattern = Pattern.compile("\\[TOOL:([^:]+):?(.*?)\\]");
        Matcher matcher = pattern.matcher(responseText);

        StringBuilder combinedFeedback = new StringBuilder();
        boolean foundAtLeastOne = false;

        while (matcher.find()) {
            foundAtLeastOne = true;
            String toolName = matcher.group(1).trim();
            String argument = matcher.group(2) != null ? matcher.group(2).trim() : "";

            System.err.println("Ausführung -> Tool: " + toolName + " | Argument: " + argument);
            String nativeResult = toolRegistry.getOrDefault(toolName,
                            arg -> "System-Status: Tool '" + toolName + "' nicht unterstützt.")
                    .apply(argument);

            combinedFeedback.append(nativeResult).append("\n");
        }

        if (foundAtLeastOne) {
            try {
                // HIER IST DER MAGISCHE TRICK: Wir zwingen die KI zur Sprachausgabe!
                String llmInstruction = "System-Rückmeldung der ausgeführten Tools:\n"
                        + combinedFeedback.toString().trim()
                        + "\n\nAnweisung: Antworte dem Nutzer jetzt basierend auf diesen Daten in natürlicher, formeller Sprache. Lies gefundene Orte oder Statusberichte vor. Bitte übersetze alles auf deutsch bevor du antwortest";

                Log.w(TAG, "Sende gesammeltes Feedback an LLM:\n" + llmInstruction);

                // Feedback + Anweisung an das Modell senden
                var finalResponse = conversation.sendMessage(llmInstruction, Collections.emptyMap());
                return extractTextFromMessage(finalResponse);

            } catch (Exception e) {
                Log.e(TAG, "Fehler beim Tool-Feedback", e);
                return "Aktionen wurden ausgeführt, aber die Sprach-Ausgabe ist blockiert.";
            }
        }

        return responseText;
    }

    // ==========================================
    // HILFSMETHODEN (Kompakt und ausgelagert)
    // ==========================================

    private String extractTextFromMessage(Message message) {
        if (message == null || message.getContents() == null || message.getContents().getContents() == null) return "";
        // Nutzt moderne Java Streams für einen sauberen Einzeiler statt einer for-Schleife
        return message.getContents().getContents().stream()
                .filter(Objects::nonNull)
                .map(Object::toString)
                .collect(Collectors.joining()).trim();
    }

    private String setupModelFile(String fileName) throws Exception {
        File targetFile = new File(context.getFilesDir(), fileName);
        if (!targetFile.exists()) {
            Log.i(TAG, "Kopiere Modell...");
            try (InputStream in = context.getAssets().open(fileName);
                 FileOutputStream out = new FileOutputStream(targetFile)) {
                byte[] buffer = new byte[8192]; // Größerer Buffer für mehr Speed
                int read;
                while ((read = in.read(buffer)) != -1) out.write(buffer, 0, read);
            }
        }
        return targetFile.getAbsolutePath();
    }

    public void shutdown() {
        Log.i(TAG, "Fahre Offline-Kern herunter.");
        try { if (conversation != null) conversation.close(); } catch (Exception ignored) {}
        try { if (engine != null) engine.close(); } catch (Exception ignored) {}
        isInitialized = false;
    }
}