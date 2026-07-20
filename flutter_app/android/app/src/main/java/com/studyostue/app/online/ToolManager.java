package com.example.studyOS.online;

import android.content.Context;
import android.content.Intent;
import android.net.Uri;
import android.os.Handler;
import android.os.Looper;

import com.example.studyOS.DataStructures.MemoryEntry;
import com.example.studyOS.DataStructures.Speaker;
import com.example.studyOS.Memory.FileIO;
import com.example.studyOS.Memory.StorageFiles;
import com.example.studyOS.Reminder.ReminderManager;
import com.example.studyOS.Sensors.WorldStateProvider;

import org.json.JSONArray;
import org.json.JSONObject;

import java.time.LocalDateTime;

import okhttp3.OkHttpClient;
import okhttp3.Request;
import okhttp3.Response;

/**
 * Alle JARVIS-Tools an einem Ort.
 *
 * Neues Tool hinzufügen:
 *   1. Methode  private String tool_meinTool(JSONObject args)  schreiben
 *   2. Definition in  buildDefinitions()  eintragen
 *   3. Case in  dispatch()  eintragen
 */
public class ToolManager {

    private final OkHttpClient http;
    private Context context;

    public ToolManager(OkHttpClient http, Context context) {
        this.http = http;
        this.context = context.getApplicationContext();
    }


    // ─────────────────────────────────────────────────────────────────────────
    //  API-Schnittstelle
    // ─────────────────────────────────────────────────────────────────────────

    /** Liefert das "tools"-Array für den OpenAI-Request. */
    public JSONArray buildDefinitions() throws Exception {
        return new JSONArray()
                .put(tool("create_reminder",
                        "Setzt Erinnerungen oder Alarme.",
                        new JSONObject()
                                .put("type", "object")
                                .put("required", new JSONArray().put("title").put("time"))
                                .put("properties", new JSONObject()
                                        .put("title", param("string", "Woran erinnert werden soll"))
                                        .put("time", param("string", "z.B. 'in 5 Minuten', 'morgen 7 Uhr', '2026-05-20T08:00'"))
                                        .put("type", param("string", "REMINDER, ALARM oder MORNING_ROUTINE"))
                                        .put("repeat", param("string", "ONCE, DAILY oder WEEKLY")))))

                .put(tool("get_weather",
                        "Ruft das aktuelle Wetter für einen Ort ab (Temperatur, Bedingungen, Wind).",
                        new JSONObject()
                                .put("type", "object")
                                .put("required", new JSONArray().put("location"))
                                .put("properties", new JSONObject()
                                        .put("location", param("string",
                                                "Stadt und Ländercode, z.B. 'Berlin,DE'")))))

                .put(tool("get_local_news",
                        "Ruft aktuelle Schlagzeilen für eine Region oder ein Thema ab.",
                        new JSONObject()
                                .put("type", "object")
                                .put("required", new JSONArray().put("country"))
                                .put("properties", new JSONObject()
                                        .put("country", param("string", "ISO-Ländercode, z.B. 'de'"))
                                        .put("query",   param("string", "Optionales Thema, z.B. 'Verkehr'")))))

                .put(tool("search_youtube",
                "Öffnet die YouTube-App und sucht nach einem Begriff für Videos oder Musik.",
                new JSONObject()
                        .put("type", "object")
                        .put("required", new JSONArray().put("query"))
                        .put("properties", new JSONObject()
                                .put("query", param("string", "Der Suchbegriff für YouTube")))
        ));
    }

    /** Führt das angeforderte Tool aus und gibt das Ergebnis zurück. */
    public String dispatch(String name, String argsJson) {
        try {
            var args = (argsJson == null || argsJson.isBlank())
                    ? new JSONObject()
                    : new JSONObject(argsJson);

            return switch (name) {
                // case "get_weather"    -> tool_getWeather(args);
                // case "get_local_news" -> tool_getLocalNews(args);
                case "create_reminder" -> createReminder(args);
                case "search_youtube" -> {
                    var query = args.getString("query");
                    yield searchYoutube(args.getString("query"));
                }
                default               -> "[Tool '" + name + "' nicht registriert]";
            };
        } catch (Exception e) {
            return "[Tool-Fehler bei '" + name + "': " + e.getMessage() + "]";
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    //  Tool-Implementierungen
    // ─────────────────────────────────────────────────────────────────────────

    // TODO add implementations

    // ─────────────────────────────────────────────────────────────────────────
    //  Hilfsmethoden
    // ─────────────────────────────────────────────────────────────────────────

    private JSONObject getJson(String url) throws Exception {
        Request req = new Request.Builder().url(url).build();
        try (Response res = http.newCall(req).execute()) {
            if (!res.isSuccessful() || res.body() == null)
                throw new Exception("HTTP " + res.code());
            return new JSONObject(res.body().string());
        }
    }

    /** Erzeugt ein einzelnes Tool-Objekt für das OpenAI-tools-Array. */
    private static JSONObject tool(String name, String description, JSONObject params)
            throws Exception {
        return new JSONObject()
                .put("type", "function")
                .put("function", new JSONObject()
                        .put("name",        name)
                        .put("description", description)
                        .put("parameters",  params));
    }

    /** Erzeugt ein einzelnes Parameter-Objekt für das JSON-Schema. */
    private static JSONObject param(String type, String description) throws Exception {
        return new JSONObject().put("type", type).put("description", description);
    }


    /**
     * Methods
     */
    private String createReminder(JSONObject args) {
        try {
            String title = args.getString("title");
            String rawTime = args.getString("time");
            String type = args.optString("type", "REMINDER");
            String repeat = args.optString("repeat", "ONCE");
            LocalDateTime time = parseReminderTime(rawTime);

            ReminderManager.get().create(
                    title,
                    time,
                    ReminderManager.Type.valueOf(type),
                    ReminderManager.Repeat.valueOf(repeat)
            );

            return "Sir, Erinnerung gesetzt: "
                    + title
                    + " um "
                    + time.getHour()
                    + ":"
                    + String.format("%02d", time.getMinute());

        } catch (Exception e) {
            return "Ich konnte die Erinnerung nicht setzen.";
        }
    }



    public String searchYoutube(String query) {
        Handler handler = new Handler(Looper.getMainLooper());


        handler.postDelayed(() -> {
            Intent ytIntent = new Intent(Intent.ACTION_VIEW, Uri.parse("https://www.youtube.com/results?search_query=" + Uri.encode(query)));
            ytIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
            context.startActivity(ytIntent);
        }, 600);

        // 4️⃣ App sauber beenden (KEIN System.exit!)
        handler.postDelayed(() -> {
            System.exit(0);
        }, 1200);

        // 5️⃣ Conversation loggen
        String message = "Ich suche in YouTube nach: " + query;
        var memoryEntry = new MemoryEntry(Speaker.JARVIS, message, WorldStateProvider.getInstance().getWorldState(), "unknown", false);
        FileIO.getInstance().appendMemory(StorageFiles.MEMORY, memoryEntry);

        return message;
    }









    // Helping methods:
    private LocalDateTime parseReminderTime(String input) {
        input = input.toLowerCase().trim();
        LocalDateTime now = LocalDateTime.now();

        try {
            if (input.matches(".*in \\d+ minuten?.*")) {
                int min = Integer.parseInt(input.replaceAll("\\D+", ""));
                return now.plusMinutes(min);
            }

            if (input.matches(".*in \\d+ stunden?.*")) {
                int h = Integer.parseInt(input.replaceAll("\\D+", ""));
                return now.plusHours(h);
            }

            if (input.contains("morgen"))
                return now.plusDays(1);

            if (input.contains("übermorgen"))
                return now.plusDays(2);

        } catch (Exception ignored) {}

        return LocalDateTime.parse(input);
    }

}