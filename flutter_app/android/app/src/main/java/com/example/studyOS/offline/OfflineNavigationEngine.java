package com.example.studyOS.offline;

import android.content.Context;
import android.content.Intent;
import android.database.Cursor;
import android.database.sqlite.SQLiteDatabase;
import android.location.Location;
import android.speech.tts.TextToSpeech;

import java.util.ArrayList;
import java.util.List;
import java.util.Locale;

public class OfflineNavigationEngine implements TextToSpeech.OnInitListener {

    private final Context context;
    private SQLiteDatabase db;
    private TextToSpeech tts;

    // Globale Positionsdaten (werden vom Hintergrund-Service oder der App gefüttert)
    private static Location currentLocation;
    private static float currentHeading = 0f;

    // Navigations-Zustand
    private Location targetLocation;
    private String currentTargetName = "";
    private boolean isNavigating = false;
    private float lastAnnouncedDistance = Float.MAX_VALUE;

    public OfflineNavigationEngine(Context context) {
        this.context = context.getApplicationContext();
        initDatabase();
        initTextToSpeech();
    }

    private void initDatabase() {
        try {
            // TODO adapt navigation path
            String dbPath = context.getDatabasePath("offline_navigation.db").getPath();
            System.out.println("DB PATH: " + dbPath);

            db = SQLiteDatabase.openDatabase(dbPath, null, SQLiteDatabase.OPEN_READONLY);
        } catch (Exception e) {
            e.printStackTrace();
        }
    }

    private void initTextToSpeech() {
        tts = new TextToSpeech(context, this);
    }

    @Override
    public void onInit(int status) {
        if (status == TextToSpeech.SUCCESS) tts.setLanguage(Locale.GERMAN);
    }

    // ==========================================
    // STATISCHE SETTER FÜR DIE SENSOR-DATEN
    // ==========================================
    public static void updateCurrentLocation(Location location) {
        currentLocation = location;
    }

    public static void updateCurrentHeading(float heading) {
        currentHeading = heading;
    }

    // ==========================================
    // KI / LLM SCHNITTSTELLEN-METHODEN
    // ==========================================

    /**
     * Sucht Orte in der Nähe basierend auf einem Radius.
     * Perfekt für KI-Abfragen ("Wo ist der nächste Bahnhof?").
     */
    public String findNearbyPlaces(String searchStr, double radiusMeters) {
        if (db == null || !db.isOpen()) return "Fehler: Offline-Datenbank nicht bereit.";
        if (currentLocation == null) return "Fehler: Aktuell kein GPS-Signal vorhanden.";

        double lat = currentLocation.getLatitude();
        double lon = currentLocation.getLongitude();

        double latOffset = radiusMeters / 111320.0;
        double lonOffset = radiusMeters / (111320.0 * Math.cos(Math.toRadians(lat)));

        String query = "SELECT name, poi_type, lat, lon FROM nodes " +
                "WHERE lat BETWEEN ? AND ? AND lon BETWEEN ? AND ? " +
                "AND (name LIKE ? OR poi_type LIKE ?) LIMIT 15";

        String[] args = {
                String.valueOf(lat - latOffset), String.valueOf(lat + latOffset),
                String.valueOf(lon - lonOffset), String.valueOf(lon + lonOffset),
                "%" + searchStr + "%", "%" + searchStr + "%"
        };

        StringBuilder results = new StringBuilder();

        try (Cursor cursor = db.rawQuery(query, args)) {

            // Alle Kandidaten sammeln und nach Distanz sortieren
            List<PlaceCandidate> candidates = new ArrayList<>();

            while (cursor.moveToNext()) {
                String name  = cursor.getString(0);
                String type  = cursor.getString(1);
                double pLat  = cursor.getDouble(2);
                double pLon  = cursor.getDouble(3);

                Location loc = new Location("");
                loc.setLatitude(pLat);
                loc.setLongitude(pLon);
                int distance = (int) currentLocation.distanceTo(loc);

                candidates.add(new PlaceCandidate(name, type, pLat, pLon, distance));
            }

            if (candidates.isEmpty())
                return "Keine passenden Orte im Umkreis von " + (int) radiusMeters + "m gefunden.";

            // Nach Distanz sortieren — nächster zuerst
            candidates.sort((a, b) -> Integer.compare(a.distance, b.distance));

            // Ersten Treffer direkt als Navigationsziel setzen (kein extra Befehl nötig)
            PlaceCandidate nearest = candidates.get(0);
            targetLocation = new Location("");
            targetLocation.setLatitude(nearest.lat);
            targetLocation.setLongitude(nearest.lon);
            currentTargetName = nearest.name != null ? nearest.name : nearest.type;
            isNavigating = false; // Kein aktives Routing, nur Ziel gesetzt

            // Ergebnisliste aufbauen
            for (int i = 0; i < candidates.size(); i++) {
                PlaceCandidate p = candidates.get(i);

                // Absolute Richtung zum Ort berechnen
                float[] bearing = new float[2];
                Location.distanceBetween(lat, lon, p.lat, p.lon, bearing);
                float absoluteBearing  = (bearing[1] + 360f) % 360f;
                String relativeDir     = getRelativeDirectionInternal(absoluteBearing);

                String distFormatted = p.distance >= 1000
                        ? String.format(Locale.GERMAN, "%.1f km", p.distance / 1000f)
                        : p.distance + " m";

                results.append(i + 1).append(". ")
                        .append(p.name != null ? p.name : "Unbekannt")
                        .append(" | Typ: ").append(p.type != null ? p.type : "n/a")
                        .append(" | ").append(distFormatted)
                        .append(" | ").append(relativeDir)
                        .append("\n");
            }

            results.append("\nNavigation zu '").append(currentTargetName)
                    .append("' (").append(nearest.distance).append(" m) automatisch gesetzt.");
        }

        return results.toString().trim();
    }

    public String getTargetDirection() {
        // Funktioniert jetzt auch ohne aktive Navigation — nur Ziel muss gesetzt sein
        if (currentLocation == null || targetLocation == null)
            return "Aktuell ist kein Ziel gesetzt oder kein GPS-Signal vorhanden.";

        float bearingToTarget  = currentLocation.bearingTo(targetLocation);
        float relativeBearing  = (bearingToTarget - currentHeading + 360) % 360;
        int   distance         = (int) currentLocation.distanceTo(targetLocation);

        String directionText = getRelativeDirectionInternal(relativeBearing);

        String distFormatted = distance >= 1000
                ? String.format(Locale.GERMAN, "%.1f km", distance / 1000f)
                : distance + " m";

        return "Das Ziel '" + currentTargetName + "' liegt " + directionText + ", " + distFormatted + " entfernt.";
    }

    // ── Neue interne Hilfsmethode (kein public API-Bruch) ─────────────────────────
    private String getRelativeDirectionInternal(float relativeBearing) {
        if (relativeBearing >= 337.5 || relativeBearing <  22.5) return "direkt vor Ihnen";
        if (relativeBearing <  67.5)                              return "vorne rechts";
        if (relativeBearing < 112.5)                              return "rechts";
        if (relativeBearing < 157.5)                              return "hinten rechts";
        if (relativeBearing < 202.5)                              return "hinter Ihnen";
        if (relativeBearing < 247.5)                              return "hinten links";
        if (relativeBearing < 292.5)                              return "links";
        return                                                           "vorne links";
    }

    // ── Interner Hilfs-Record für die Sortierung ──────────────────────────────────
    private static class PlaceCandidate {
        final String name, type;
        final double lat, lon;
        final int    distance;

        PlaceCandidate(String name, String type, double lat, double lon, int distance) {
            this.name     = name;
            this.type     = type;
            this.lat      = lat;
            this.lon      = lon;
            this.distance = distance;
        }
    }


    public String analyzeNearby(double radiusMeters) {
        if (db == null || !db.isOpen()) return "Fehler: Offline-Datenbank nicht bereit.";
        if (currentLocation == null) return "Fehler: Aktuell kein GPS-Signal vorhanden.";

        double lat = currentLocation.getLatitude();
        double lon = currentLocation.getLongitude();

        // Berechnung des Suchradius
        double latOffset = radiusMeters / 111320.0;
        double lonOffset = radiusMeters / (111320.0 * Math.cos(Math.toRadians(lat)));

        // Hier wurde die Einschränkung auf name/poi_type komplett entfernt
        String query = "SELECT name, poi_type, lat, lon FROM nodes " +
                "WHERE lat BETWEEN ? AND ? AND lon BETWEEN ? AND ? " +
                "ORDER BY (lat - ?) * (lat - ?) + (lon - ?) * (lon - ?) ASC";

        String[] args = {
                String.valueOf(lat - latOffset), String.valueOf(lat + latOffset),
                String.valueOf(lon - lonOffset), String.valueOf(lon + lonOffset),
                String.valueOf(lat), String.valueOf(lat), String.valueOf(lon), String.valueOf(lon)
        };

        StringBuilder results = new StringBuilder();
        results.append("Orte in der Umgebung:\n");

        try (Cursor cursor = db.rawQuery(query, args)) {
            while (cursor.moveToNext()) {
                String name = cursor.getString(0);
                String type = cursor.getString(1);
                double pLat = cursor.getDouble(2);
                double pLon = cursor.getDouble(3);

                System.out.println("LAT: " + pLat + ", LON: " + pLon + ", NAME: " + name);

                Location loc = new Location("");
                loc.setLatitude(pLat);
                loc.setLongitude(pLon);
                int distance = (int) currentLocation.distanceTo(loc);

                results.append("- ").append(name != null ? name : "Unbekannt").append(" (Typ: ")
                        .append(type != null ? type : "n/a").append(", Distanz: ")
                        .append(distance).append("m)\n");
            }
        } catch (Exception e) {
            return "Fehler bei der Abfrage: " + e.getMessage();
        }

        return results.length() > 21 ? results.toString() : "Keine Orte im Umkreis von " + (int)radiusMeters + "m gefunden.";
    }


    public String analyzeNearbyFromCoordinates(double centerLat, double centerLon, double radiusMeters) {
        if (db == null || !db.isOpen())
            return "Fehler: DB nicht geöffnet.";

        double latOffset = radiusMeters / 111320.0;
        double lonOffset = radiusMeters / (111320.0 * Math.cos(Math.toRadians(centerLat)));

        String query = """
                SELECT name, poi_type, lat, lon
                      FROM nodes
                      WHERE lat BETWEEN ? AND ?
                      AND lon BETWEEN ? AND ? AND (
                        (name IS NOT NULL AND name != '')
                        OR
                        (poi_type IS NOT NULL AND poi_type != '')
                      )
                      ORDER BY ((lat - ?) * (lat - ?) + (lon - ?) * (lon - ?)) ASC
                      LIMIT 30
        """;

        String[] args = {
                String.valueOf(centerLat - latOffset),
                String.valueOf(centerLat + latOffset),

                String.valueOf(centerLon - lonOffset),
                String.valueOf(centerLon + lonOffset),

                String.valueOf(centerLat),
                String.valueOf(centerLat),

                String.valueOf(centerLon),
                String.valueOf(centerLon)
        };

        StringBuilder results = new StringBuilder();

        results.append("POIs nahe ")
                .append(centerLat)
                .append(", ")
                .append(centerLon)
                .append("\n\n");

        try (Cursor cursor = db.rawQuery(query, args)) {

            int count = 0;

            while (cursor.moveToNext()) {

                String name = cursor.getString(0);
                String type = cursor.getString(1);

                double lat = cursor.getDouble(2);
                double lon = cursor.getDouble(3);

                float[] distanceResult = new float[1];

                Location.distanceBetween(
                        centerLat,
                        centerLon,
                        lat,
                        lon,
                        distanceResult
                );

                int distance = (int) distanceResult[0];
                results.append(count + 1)
                        .append(". ")
                        .append(name != null ? name : "Unbekannt")
                        .append(" | Typ: ")
                        .append(type != null ? type : "n/a")
                        .append(" | Distanz: ")
                        .append(distance)
                        .append("m")
                        .append("\n");

                System.out.println(
                        "FOUND NODE: " +
                                name + " | " +
                                type + " | " +
                                lat + "," + lon
                );

                count++;
            }

            if (count == 0)
                return "Keine POI-Nodes gefunden.";

        } catch (Exception e) {
            e.printStackTrace();
            return "SQL Fehler: " + e.getMessage();
        }

        return results.toString();
    }

    /**
     * Startet die Navigation zu bestimmten Koordinaten.
     * Aktiviert automatisch den Hintergrunddienst, falls noch nicht geschehen.
     */
    public String startNavigation(double targetLat, double targetLon, String placeName) {
        targetLocation = new Location("");
        targetLocation.setLatitude(targetLat);
        targetLocation.setLongitude(targetLon);
        currentTargetName = placeName;
        isNavigating = true;
        lastAnnouncedDistance = Float.MAX_VALUE;

        // Startet den Hintergrunddienst, damit GPS auch bei Display-Aus weiterläuft
        Intent serviceIntent = new Intent(context, NavigationBackgroundService.class);
        context.startForegroundService(serviceIntent);

        speak("Navigation zu " + placeName + " gestartet.");
        return "Navigation zu '" + placeName + "' wurde erfolgreich initialisiert.";
    }

    /**
     * Wird vom Hintergrund-Service bei jedem GPS-Update aufgerufen.
     * Regelt die intelligenten Sprachausgaben (Geofencing / seltener sprechen).
     */
    public void processNavigationUpdate(Location location) {
        if (!isNavigating || targetLocation == null) return;

        float distance = location.distanceTo(targetLocation);

        // 1. Ziel erreicht (Geofence Trigger)
        if (distance < 15.0) {
            speak("Du hast dein Ziel " + currentTargetName + " erreicht. Navigation beendet.");
            isNavigating = false;
            context.stopService(new Intent(context, NavigationBackgroundService.class));
            return;
        }

        // 2. Intelligente Sprachausgabe: Nur sprechen, wenn signifikante Fortschritte gemacht wurden
        // Verhindert, dass die App alle 2 Sekunden "Noch 500 Meter" plappert.
        if (lastAnnouncedDistance == Float.MAX_VALUE) {
            lastAnnouncedDistance = distance;
        } else {
            float diff = lastAnnouncedDistance - distance;
            // Sprich nur alle 200 Meter, oder wenn man unter 100m nah dran ist alle 30 Meter
            if ((distance > 100 && diff >= 200) || (distance <= 100 && diff >= 30)) {
                speak("Noch " + (int) distance + " Meter bis zum Ziel.");
                lastAnnouncedDistance = distance;
            }
        }
    }

    public void logDatabaseColumns() {
        if (db == null || !db.isOpen()) return;

        try (Cursor cursor = db.rawQuery("PRAGMA table_info(nodes)", null)) {
            int nameIndex = cursor.getColumnIndex("name");

            System.out.println("--- Tabellenstruktur von 'nodes' ---");
            while (cursor.moveToNext()) {
                if (nameIndex != -1) {
                    String columnName = cursor.getString(nameIndex);
                    System.out.println("Spalte gefunden: " + columnName);
                }
            }
            System.out.println("------------------------------------");
        } catch (Exception e) {
            e.printStackTrace();
        }
    }

    private void speak(String text) {
        if (tts != null)
            tts.speak(text, TextToSpeech.QUEUE_FLUSH, null, null);
    }

    public void shutdown() {
        if (tts != null) { tts.stop(); tts.shutdown(); }
        if (db != null && db.isOpen()) db.close();
    }
}