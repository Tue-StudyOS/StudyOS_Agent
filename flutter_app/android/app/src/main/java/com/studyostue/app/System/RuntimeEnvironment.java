package com.example.studyOS.System;

import android.content.Context;
import android.net.ConnectivityManager;
import android.net.Network;
import android.net.NetworkCapabilities;

public class RuntimeEnvironment {

    private static RuntimeEnvironment instance;
    private final ConnectivityManager connectivityManager;
    private volatile RuntimeMode currentMode;

    private RuntimeEnvironment(Context context) {
        connectivityManager = (ConnectivityManager) context.getApplicationContext().getSystemService(Context.CONNECTIVITY_SERVICE);
        determineInitialMode();
        registerNetworkListener();
    }

    public static synchronized RuntimeEnvironment init(Context context) {
        if (instance == null)
            instance = new RuntimeEnvironment(context.getApplicationContext());

        return (instance == null)
                ? new RuntimeEnvironment(context.getApplicationContext())
                : instance;
    }

    public static RuntimeEnvironment getInstance() {
        if (instance == null)
            throw new IllegalStateException("RuntimeEnvironment not initialized!");

        return instance;
    }

    /**
     * DIE globale Methode
     */
    public RuntimeMode getMode() {
        return currentMode;
    }

    /**
     * Einfacher Shortcut
     */
    public boolean isOnline() {
        return currentMode == RuntimeMode.ONLINE;
    }

    public boolean isOffline() {
        return currentMode == RuntimeMode.OFFLINE;
    }

    /**
     * Prüft beim Start
     */
    private void determineInitialMode() {
        var network = connectivityManager.getActiveNetwork();

        if (network == null) {
            switchToOffline();
            return;
        }

        var capabilities = connectivityManager.getNetworkCapabilities(network);
        var hasInternet = capabilities != null && (capabilities.hasTransport(NetworkCapabilities.TRANSPORT_WIFI) || capabilities.hasTransport(NetworkCapabilities.TRANSPORT_CELLULAR));

        if (hasInternet) switchToOnline();
        else switchToOffline();
    }

    /**
     * Hört dauerhaft auf Änderungen
     */
    private void registerNetworkListener() {
        connectivityManager.registerDefaultNetworkCallback(new ConnectivityManager.NetworkCallback() {

                    @Override
                    public void onAvailable(Network network) {
                        var capabilities = connectivityManager.getNetworkCapabilities(network);
                        var valid = capabilities != null && (capabilities.hasTransport(NetworkCapabilities.TRANSPORT_WIFI) || capabilities.hasTransport(NetworkCapabilities.TRANSPORT_CELLULAR));
                        if (valid)
                            switchToOnline();
                    }

                    @Override
                    public void onLost(Network network) {
                        var active = connectivityManager.getActiveNetwork();
                        if (active == null)
                            switchToOffline();
                    }
                }
        );
    }

    private synchronized void switchToOnline() {
        if (currentMode == RuntimeMode.ONLINE)
            return;

        currentMode = RuntimeMode.ONLINE;
        System.out.println("JARVIS -> ONLINE MODE");
    }

    private synchronized void switchToOffline() {
        if (currentMode == RuntimeMode.OFFLINE)
            return;

        currentMode = RuntimeMode.OFFLINE;
        System.out.println("JARVIS -> OFFLINE MODE");
    }
}
