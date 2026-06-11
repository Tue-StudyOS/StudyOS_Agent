package com.example.studyOS.online;

import android.os.Handler;
import android.os.Looper;

import com.example.studyOS.DataStructures.MemoryEntry;
import com.example.studyOS.DataStructures.Speaker;
import com.example.studyOS.Interfaces.Brain;
import com.example.studyOS.Memory.FileIO;
import com.example.studyOS.Memory.StorageFiles;
import com.example.studyOS.Sensors.WorldStateProvider;
import com.example.studyOS.UI.UIManager;

import org.json.JSONArray;
import org.json.JSONObject;

import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

import okhttp3.MediaType;
import okhttp3.OkHttpClient;
import okhttp3.Request;
import okhttp3.RequestBody;

public class JarvisBrainOnline implements Brain {

    private static final String TAG = "JarvisBrainOnline";
    // private final String model = "gpt-4.1-mini-2025-04-14";
    private final String model = "gpt-4o-mini-2024-07-18";
    private static final String ENDPOINT = "https://api.openai.com/v1/chat/completions";
    private static final MediaType JSON = MediaType.get("application/json; charset=utf-8");
    private static final String API_KEY = "TODO API-KEY";
    private static final int MAX_TOOL_ROUNDS = 10;


    private static final String SYSTEM_PROMPT = """
            Du bist J.A.R.V.I.S. (Just A Rather Very Intelligent System), Version 9.
            Proaktiv, formell, präzise – mit einem Hauch trockenen Humors.
            Nutze verfügbare Tools eigenständig, ohne Rückfragen. Antworte stets auf Deutsch.
    """;

    private static volatile JarvisBrainOnline instance;

    public static JarvisBrainOnline getInstance() {
        if (instance == null)
            synchronized (JarvisBrainOnline.class) {
                if (instance == null) instance = new JarvisBrainOnline();
            }

        return instance;
    }

    private final OkHttpClient httpClient = new OkHttpClient();
    private final ExecutorService executorService = Executors.newSingleThreadExecutor();
    // private final ToolManager toolManager = new ToolManager(httpClient);
    private final JSONArray history = new JSONArray();
    private SpeechRecognitionManager speechRecognitionManager;
    private ToolManager toolManager;
    private  TTS tts;

    private JarvisBrainOnline() {}

    public void setTTS(TTS tts) {
        this.tts = tts;
    }

    public void setToolManager(ToolManager toolManager) {
        this.toolManager = toolManager;
    }

    public void setSpeechRecognitionManager(SpeechRecognitionManager speechRecognitionManager) {
        this.speechRecognitionManager = speechRecognitionManager;
    }

    @Override
    public void process(String text) {
        if (text == null || text.isBlank()) return;

        executorService.submit(() -> {
            try {
                var worldState = WorldStateProvider.getInstance().getWorldState();
                var response = agenticLoop();

                // Main-Thread für Hardware-Kommunikation
                new Handler(Looper.getMainLooper()).post(() ->  {
                    System.out.println("RESPONSE: " + response);
                    if (tts != null) tts.speakOut(response);

                    var memoryEntry = new MemoryEntry(Speaker.JARVIS, response, worldState, "unknown", false);
                    FileIO.getInstance().appendMemory(StorageFiles.MEMORY, memoryEntry);
                    UIManager.addJarvisMessage(response);
                });

            } catch (Exception e) {
                System.err.println("Error while starting agent: " + e.getMessage());
                new Handler(Looper.getMainLooper()).post(() -> {
                    // if (speechRecognitionManager != null) speechRecognitionManager.stopListening();
                    if (tts != null) tts.speakOut("Entschuldigung, Sir. Ein Systemfehler ist aufgetreten.");
                    UIManager.addJarvisMessage("Systemfehler bei Verarbeitung.");
                });
            }
        });
    }

    // Agentic Loop
    private String agenticLoop() throws Exception {
        for (int round = 0; round < MAX_TOOL_ROUNDS; round++) {
            JSONObject response = callApi();
            JSONObject choice = response.getJSONArray("choices").getJSONObject(0);
            JSONObject message = choice.getJSONObject("message");
            String finishReason = choice.getString("finish_reason");

            if ("stop".equalsIgnoreCase(finishReason))
                return message.optString("content", "").trim();

            if ("tool_calls".equalsIgnoreCase(finishReason)) {
                var memoryEntry = new MemoryEntry(Speaker.JARVIS, message.optString("content", "").trim(), WorldStateProvider.getInstance().getWorldState(), "unknown", false);
                FileIO.getInstance().appendMemory(StorageFiles.MEMORY, memoryEntry);

                executeToolCalls(message.getJSONArray("tool_calls"));
                continue;
            }

            var content = message.optString("content", "").trim();
            if (!content.isEmpty()) return content;
            break;
        }

        return "[Maximale Denkiterationen erreicht - bitte Anfrage präzisieren, Sir.]";
    }


    public void executeToolCalls(JSONArray toolCalls) throws Exception {
        for (int i = 0; i < toolCalls.length(); i++) {
            var call = toolCalls.getJSONObject(i);
            var id = call.getString("id");
            var name = call.getJSONObject("function").getString("name");
            var args = call.getJSONObject("function").optString("arguments", "{}");

            var result = toolManager.dispatch(name, args);

            FileIO.getInstance().appendMemory(StorageFiles.MEMORY, new MemoryEntry(Speaker.JARVIS, result, WorldStateProvider.getInstance().getWorldState(), "unknown", false));
        }
    }


    // API-Call
    private JSONObject callApi() throws Exception {
        var request = new Request.Builder()
                .url(ENDPOINT)
                .addHeader("Authorization", "Bearer " + API_KEY)
                .addHeader("Content-Type", "application/json")
                .post(RequestBody.create(buildRequestBody().toString(), JSON))
                .build();

        try (var response = httpClient.newCall(request).execute()) {
            if (response.body() == null)
                throw new Exception("Leere Response von OpenAI");

            var bodyStr = response.body().string();
            if (!response.isSuccessful())
                throw new Exception("API-Call fehlgeschlagen: " + bodyStr);

            return new JSONObject(bodyStr);
        }
    }

    private JSONObject buildRequestBody() throws Exception {
        var messages = new JSONArray();
        messages.put(new JSONObject()
                .put("role", "system")
                .put("content", SYSTEM_PROMPT));

        var history = FileIO.getInstance().readJsonlToMemoryEntry(StorageFiles.MEMORY);
        int start = Math.max(0, history.size() - 10);
        for (int i = start; i < history.size(); i++) {
            var entry = history.get(i);

            var role = (entry.speaker() == com.example.studyOS.DataStructures.Speaker.BOSS)
                    ? "user"
                    : "assistant";

            messages.put(new JSONObject()
                    .put("role", role)
                    .put("content", entry.text())
            );
        }

        return new JSONObject()
                .put("model", model)
                .put("messages", messages)
                .put("tools", toolManager.buildDefinitions())
                .put("tool_choice", "auto");
    }


}
