package com.example.studyOS.Sensors;

import android.content.Context;
import android.hardware.Sensor;
import android.hardware.SensorEvent;
import android.hardware.SensorEventListener;
import android.hardware.SensorManager;

import com.example.studyOS.DataStructures.MotionData;

public class MotionSensorManager implements SensorEventListener {

    private final SensorManager sensorManager;

    private final float[] gyro = new float[3];
    private final float[] accel = new float[3];
    private final float[] mag = new float[3];


    public MotionSensorManager(Context context) {
        sensorManager = (SensorManager) context.getSystemService(Context.SENSOR_SERVICE);
        registerSensors();
    }

    private void registerSensors() {
        int delay = SensorManager.SENSOR_DELAY_UI;
        sensorManager.registerListener(this, sensorManager.getDefaultSensor(Sensor.TYPE_GYROSCOPE), delay);
        sensorManager.registerListener(this, sensorManager.getDefaultSensor(Sensor.TYPE_ACCELEROMETER), delay);
        sensorManager.registerListener(this, sensorManager.getDefaultSensor(Sensor.TYPE_MAGNETIC_FIELD), delay);
    }

    public MotionData getMotionData() {
        return new MotionData(gyro[0], gyro[1], gyro[2], accel[0], accel[1], accel[2], mag[0], mag[1], mag[2]);
    }

    @Override
    public void onSensorChanged(SensorEvent event) {
        switch (event.sensor.getType()) {
            case Sensor.TYPE_GYROSCOPE -> System.arraycopy(event.values, 0, gyro, 0, 3);
            case Sensor.TYPE_ACCELEROMETER -> System.arraycopy(event.values, 0, accel, 0, 3);
            case Sensor.TYPE_MAGNETIC_FIELD -> System.arraycopy(event.values, 0, mag, 0, 3);
        }
    }

    @Override
    public void onAccuracyChanged(Sensor sensor, int accuracy) {

    }
}