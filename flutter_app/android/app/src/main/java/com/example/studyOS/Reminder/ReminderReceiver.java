package com.example.studyOS.Reminder;

import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.app.PendingIntent;
import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.os.Build;

import androidx.core.app.NotificationCompat;

import com.studyos.studyos_agent.MainActivity;
import com.studyos.studyos_agent.R;

import org.json.JSONObject;

public class ReminderReceiver extends BroadcastReceiver {

    private static final String CHANNEL_ID = "studyos_reminders";
    private static long lastTrigger = 0;

    @Override
    public void onReceive(Context context, Intent intent) {

        // avoid multiple triggers
        long now = System.currentTimeMillis();
        if (now - lastTrigger < 5000)
            return;

        lastTrigger = now;

        // start service
        if (Intent.ACTION_BOOT_COMPLETED.equals(intent.getAction())) {
            ReminderManager.get().init(context);
            ReminderManager.get().rescheduleAll();
            return;
        }

        showReminderNotification(context, intent);
        advanceReminderSchedule(context, intent);
    }

    private void showReminderNotification(Context context, Intent intent) {
        createChannel(context);

        var title = intent.getStringExtra(ReminderManager.EXTRA_TITLE);
        if (title == null || title.trim().isEmpty())
            title = "StudyOS reminder";

        var type = intent.getStringExtra(ReminderManager.EXTRA_TYPE);
        var notificationTitle = "StudyOS reminder";
        if ("ALARM".equals(type))
            notificationTitle = "StudyOS alarm";
        if ("MORNING_ROUTINE".equals(type))
            notificationTitle = "StudyOS morning routine";

        var launchIntent = context.getPackageManager()
                .getLaunchIntentForPackage(context.getPackageName());
        if (launchIntent == null)
            launchIntent = new Intent(context, MainActivity.class);
        launchIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK | Intent.FLAG_ACTIVITY_SINGLE_TOP);

        var contentIntent = PendingIntent.getActivity(
                context,
                notificationId(intent),
                launchIntent,
                PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE
        );

        var notification = new NotificationCompat.Builder(context, CHANNEL_ID)
                .setSmallIcon(R.drawable.ic_launcher_foreground)
                .setContentTitle(notificationTitle)
                .setContentText(title)
                .setStyle(new NotificationCompat.BigTextStyle().bigText(title))
                .setContentIntent(contentIntent)
                .setAutoCancel(true)
                .setPriority(NotificationCompat.PRIORITY_HIGH)
                .setCategory(NotificationCompat.CATEGORY_REMINDER)
                .build();

        var manager = context.getSystemService(NotificationManager.class);
        if (manager != null)
            manager.notify(notificationId(intent), notification);
    }

    private void advanceReminderSchedule(Context context, Intent intent) {
        try {
            var obj = new JSONObject()
                    .put("id", intent.getStringExtra(ReminderManager.EXTRA_ID))
                    .put("title", intent.getStringExtra(ReminderManager.EXTRA_TITLE))
                    .put("type", intent.getStringExtra(ReminderManager.EXTRA_TYPE))
                    .put("repeat", intent.getStringExtra(ReminderManager.EXTRA_REPEAT))
                    .put("time", intent.getLongExtra(ReminderManager.EXTRA_TIME, 0));

            ReminderManager.get().init(context);
            ReminderManager.get().next(obj);
        } catch (Exception ignored) {}
    }

    private void createChannel(Context context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O)
            return;

        var channel = new NotificationChannel(
                CHANNEL_ID,
                "StudyOS reminders",
                NotificationManager.IMPORTANCE_HIGH
        );
        channel.setDescription("Local StudyOS reminder notifications.");
        var manager = context.getSystemService(NotificationManager.class);
        if (manager != null)
            manager.createNotificationChannel(channel);
    }

    private int notificationId(Intent intent) {
        var id = intent.getStringExtra(ReminderManager.EXTRA_ID);
        return id == null ? 31_031 : id.hashCode();
    }
}
