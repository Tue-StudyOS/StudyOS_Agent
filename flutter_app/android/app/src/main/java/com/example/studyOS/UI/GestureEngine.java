package com.example.studyOS.UI;

import android.app.Activity;
import android.view.GestureDetector;
import android.view.MotionEvent;
import android.view.View;

import androidx.core.view.GravityCompat;
import androidx.drawerlayout.widget.DrawerLayout;

public class GestureEngine {

    private static GestureDetector detector;

    public static void init(Activity activity, DrawerLayout drawerLayout, View touchView) {

        detector = new GestureDetector(activity,
                new GestureDetector.SimpleOnGestureListener() {

                    private static final int THRESHOLD = 100;
                    private static final int VELOCITY = 100;

                    @Override
                    public boolean onFling(MotionEvent e1, MotionEvent e2, float vx, float vy) {

                        if (e1 == null || e2 == null) return false;

                        float diffX = e2.getX() - e1.getX();
                        float diffY = e2.getY() - e1.getY();

                        if (Math.abs(diffX) > Math.abs(diffY)) {

                            if (Math.abs(diffX) > THRESHOLD &&
                                    Math.abs(vx) > VELOCITY) {

                                if (diffX > 0) {

                                    drawerLayout.openDrawer(GravityCompat.START);
                                    return true;
                                }
                            }
                        }

                        return false;
                    }
                });

        touchView.setOnTouchListener((v, event) -> {
            detector.onTouchEvent(event);
            return false;
        });
    }
}