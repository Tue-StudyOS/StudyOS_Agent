package com.example.studyOS.System;

import com.example.studyOS.Interfaces.Brain;
import com.example.studyOS.offline.JarvisBrainOffline;
import com.example.studyOS.online.JarvisBrainOnline;

public class BrainFactory {

    public static Brain getBrain(){
        if (RuntimeEnvironment.getInstance().isOnline())
            return JarvisBrainOnline.getInstance();

        return JarvisBrainOffline.getInstance();
    }
}
