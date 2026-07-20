package com.example.studyOS.DataStructures;

public record WorldState(String date, String time, String weekday, DeviceStatus deviceStatus, GPS gps, String geocoded, MotionData motionData) {}
