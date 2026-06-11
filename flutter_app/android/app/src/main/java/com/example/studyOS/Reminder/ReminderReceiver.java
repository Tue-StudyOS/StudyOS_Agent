package com.example.studyOS.Reminder;

import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;

public class ReminderReceiver extends BroadcastReceiver {

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

        var service = new Intent(context, ReminderService.class);
        service.putExtras(intent);

        context.startForegroundService(service);
    }
}