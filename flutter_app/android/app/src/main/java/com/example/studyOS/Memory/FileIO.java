package com.example.studyOS.Memory;

import android.content.Context;
import com.example.studyOS.DataStructures.MemoryEntry;
import com.example.studyOS.DataStructures.WorldState;
import com.google.gson.Gson;
import java.io.BufferedReader;
import java.io.File;
import java.io.FileReader;
import java.io.FileWriter;
import java.util.ArrayList;
import java.util.List;

public class FileIO {

    private static FileIO instance;

    private final File baseDir;
    private final Gson gson = new Gson();

    private FileIO(Context context) {
        baseDir = new File(context.getFilesDir(), "jarvis_storage");
        if (!baseDir.exists()) baseDir.mkdirs();
    }

    public static synchronized FileIO init(Context context) {
        if (instance == null)
            instance = new FileIO(context.getApplicationContext());

        return instance;
    }

    public static FileIO getInstance() {
        if (instance == null)
            throw new IllegalStateException("FileIO not initialized");

        return instance;
    }

    // =====================================================
    // JSONL READ&WRITE (MemoryEntry)
    // =====================================================
    public synchronized void appendMemory(String fileName, MemoryEntry entry) {
        try {
            var file = new File(baseDir, fileName + ".jsonl");
            var writer = new FileWriter(file, true);

            writer.write(gson.toJson(entry));
            writer.write("\n");
            writer.close();
        } catch (Exception e) {
            e.printStackTrace();
        }
    }

    public synchronized List<MemoryEntry> readJsonlToMemoryEntry(String fileName) {
        List<MemoryEntry> result = new ArrayList<>();
        File file = new File(baseDir, fileName + ".jsonl");

        if (!file.exists())
            return result;

        try (var reader = new BufferedReader(new FileReader(file))) {
            String line;
            while ((line = reader.readLine()) != null) {
                try {
                    var entry = gson.fromJson(line, MemoryEntry.class);
                    if (entry != null)
                        result.add(entry);
                } catch (Exception parseError) {
                    parseError.printStackTrace();
                }
            }

        } catch (Exception e) {
            throw new RuntimeException("Error reading JSONL file: " + fileName, e);
        }

        return result;
    }

        // =====================================================
    // JSONL READ (RAW)
    // =====================================================
    public synchronized String readJsonlRaw(String fileName) {
        var sb = new StringBuilder();

        try {
            var file = new File(baseDir, fileName + ".jsonl");
            if (!file.exists()) return "";

            var reader = new BufferedReader(new FileReader(file));
            String line;
            while ((line = reader.readLine()) != null)
                sb.append(line).append("\n");

            reader.close();
        } catch (Exception e) {
            e.printStackTrace();
        }

        return sb.toString();
    }

    // =====================================================
    // READ&WRITE JSONL WorldState
    // =====================================================
    public synchronized void appendWorldState(String fileName, WorldState state) {
        try {
            var file = new File(baseDir, fileName + ".jsonl");
            var writer = new FileWriter(file, true);

            writer.write(gson.toJson(state));
            writer.write("\n");
            writer.close();
        } catch (Exception e) {
            e.printStackTrace();
        }
    }

    public synchronized List<WorldState> readWorldStateJsonl(String fileName) {

        List<WorldState> result = new ArrayList<>();
        var file = new File(baseDir, fileName + ".jsonl");

        if (!file.exists())
            return result;

        try (var reader = new BufferedReader(new FileReader(file))) {

            String line;
            while ((line = reader.readLine()) != null) {
                try {
                    var state = gson.fromJson(line, WorldState.class);
                    if (state != null) result.add(state);
                } catch (Exception parseError) {
                    parseError.printStackTrace();
                }
            }
        } catch (Exception e) {
            throw new RuntimeException("Error reading WorldState JSONL: " + fileName, e);
        }

        return result;
    }

    // =====================================================
    // TEXT FILE WRITE
    // =====================================================
    public synchronized void appendText(String fileName, String text) {
        try {
            var file = new File(baseDir, fileName + ".txt");
            var writer = new FileWriter(file, true);

            writer.write(text);
            writer.write("\n");
            writer.close();
        } catch (Exception e) {
            e.printStackTrace();
        }
    }

    // =====================================================
    // TEXT FILE READ
    // =====================================================
    public synchronized String readText(String fileName) {
        var sb = new StringBuilder();

        try {
            var file = new File(baseDir, fileName + ".txt");
            if (!file.exists()) return "";

            var reader = new BufferedReader(new FileReader(file));
            String line;
            while ((line = reader.readLine()) != null)
                sb.append(line).append("\n");

            reader.close();
        } catch (Exception e) {
            e.printStackTrace();
        }

        return sb.toString();
    }

    // =====================================================
    // DELETE FILE
    // =====================================================
    public synchronized void delete(String fileName, String extension) {
        try {
            var file = new File(baseDir, fileName + "." + extension);
            if (file.exists()) file.delete();
        } catch (Exception e) {
            e.printStackTrace();
        }
    }

    // =====================================================
    // CLEAR ALL MEMORY (optional debug)
    // =====================================================
    public synchronized void clearAll() {
        var files = baseDir.listFiles();
        if (files == null) return;

        for (var f : files)
            f.delete();
    }
}