package com.example.studyOS.Reminder;

import android.app.AlarmManager;
import android.app.PendingIntent;
import android.content.Context;
import android.content.Intent;

import org.json.JSONArray;
import org.json.JSONObject;

import java.io.BufferedReader;
import java.io.InputStreamReader;
import java.time.LocalDateTime;
import java.time.ZoneId;
import java.util.UUID;

public class ReminderManager {

    public enum Type {
        MORNING_ROUTINE,
        REMINDER,
        ALARM
    }

    public enum Repeat {
        ONCE,
        DAILY,
        WEEKLY
    }

    public static final String EXTRA_ID = "id";
    public static final String EXTRA_TITLE = "title";
    public static final String EXTRA_TYPE = "type";
    public static final String EXTRA_REPEAT = "repeat";
    public static final String EXTRA_TIME = "time";

    private static final String FILE = "reminders.json";

    private static ReminderManager instance;
    private Context context;

    public static ReminderManager get() {
        if (instance == null) instance = new ReminderManager();
        return instance;
    }

    public void init(Context ctx) {
        context = ctx.getApplicationContext();
    }

    /**
        EINZIGE öffentliche Methode
     */
    public String create(String title, LocalDateTime time, Type type, Repeat repeat) {
        if (context == null)
            throw new IllegalStateException("ReminderManager is not initialized.");

        String id = UUID.randomUUID().toString().substring(0, 8);
        long trigger = time
                .atZone(ZoneId.systemDefault())
                .toInstant()
                .toEpochMilli();

        if (trigger <= System.currentTimeMillis())
            throw new RuntimeException("Zeitpunkt liegt in der Vergangenheit!");

        try {
            var obj = new JSONObject()
                    .put("id", id)
                    .put("title", title)
                    .put("type", type.name())
                    .put("repeat", repeat.name())
                    .put("time", trigger);

            JSONArray arr = load();
            arr.put(obj);
            save(arr);

            schedule(obj);
        } catch (Exception error) {
            throw new RuntimeException("Reminder could not be scheduled: " + error.getMessage(), error);
        }

        return id;
    }

    public void cancel(String id) {
        try {
            JSONArray old = load();
            JSONArray newer = new JSONArray();

            for (int i = 0; i < old.length(); i++) {
                var o = old.getJSONObject(i);
                if (!o.getString("id").equals(id))
                    newer.put(o);
            }

            save(newer);
        } catch (Exception ignored) {}
        AlarmManager am = (AlarmManager) context.getSystemService(Context.ALARM_SERVICE);
        PendingIntent pi = PendingIntent.getBroadcast(
                context,
                id.hashCode(),
                new Intent(context, ReminderReceiver.class),
                PendingIntent.FLAG_NO_CREATE | PendingIntent.FLAG_IMMUTABLE
        );

        if (pi != null) am.cancel(pi);
    }

    public void rescheduleAll() {
        try {
            JSONArray arr = load();
            for (int i = 0; i < arr.length(); i++) {
                JSONObject obj = arr.getJSONObject(i);

                long time = obj.getLong("time");
                if (time < System.currentTimeMillis()) {
                    Repeat repeat = Repeat.valueOf(obj.getString("repeat"));
                    if (repeat == Repeat.ONCE) continue;

                    while (time < System.currentTimeMillis()) {
                        if (repeat == Repeat.DAILY) time += 86400000L;
                        if (repeat == Repeat.WEEKLY) time += 604800000L;
                    }

                    obj.put("time", time);
                }

                schedule(obj);
            }

            save(arr);
        } catch (Exception ignored) {}
    }

    void next(JSONObject obj) {
        try {
            Repeat repeat = Repeat.valueOf(obj.getString("repeat"));
            if (repeat == Repeat.ONCE) {
                cancel(obj.getString("id"));
                return;
            }

            long time = obj.getLong("time");
            time += repeat == Repeat.DAILY
                    ? 86400000L
                    : 604800000L;

            obj.put("time", time);

            JSONArray arr = load();
            for (int i = 0; i < arr.length(); i++) {
                JSONObject r = arr.getJSONObject(i);
                if (r.getString("id").equals(obj.getString("id"))) {
                    arr.put(i, obj);
                    break;
                }
            }

            save(arr);
            schedule(obj);

        } catch (Exception ignored) {}
    }

    private void schedule(JSONObject obj) throws Exception {
        var id = obj.getString("id");
        var i = new Intent(context, ReminderReceiver.class)
                .putExtra(EXTRA_ID, id)
                .putExtra(EXTRA_TITLE, obj.getString("title"))
                .putExtra(EXTRA_TYPE, obj.getString("type"))
                .putExtra(EXTRA_REPEAT, obj.getString("repeat"))
                .putExtra(EXTRA_TIME, obj.getLong("time"));

        var pi = PendingIntent.getBroadcast(context, id.hashCode(), i, PendingIntent.FLAG_CANCEL_CURRENT | PendingIntent.FLAG_IMMUTABLE);
        var am = (AlarmManager) context.getSystemService(Context.ALARM_SERVICE);
        am.setAlarmClock(new AlarmManager.AlarmClockInfo(obj.getLong("time"), pi), pi);
    }

    private JSONArray load() {
        try (var fis = context.openFileInput(FILE);
             var br = new BufferedReader(new InputStreamReader(fis))) {

            var sb = new StringBuilder();
            String line;
            while ((line = br.readLine()) != null)
                sb.append(line);

            var txt = sb.toString();
            return txt.isEmpty()
                    ? new JSONArray()
                    : new JSONArray(txt);

        } catch (Exception e) {
            return new JSONArray();
        }
    }

    private void save(JSONArray arr) {
        try (var fos = context.openFileOutput(FILE, Context.MODE_PRIVATE)) {
            fos.write(arr.toString().getBytes());
        } catch (Exception ignored) {}
    }
}
