package com.example.studyOS.offline;

import android.util.Log;

import com.google.ai.edge.litertlm.Backend;
import com.google.ai.edge.litertlm.Contents;
import com.google.ai.edge.litertlm.Conversation;
import com.google.ai.edge.litertlm.ConversationConfig;
import com.google.ai.edge.litertlm.Engine;
import com.google.ai.edge.litertlm.EngineConfig;
import com.google.ai.edge.litertlm.Message;
import com.google.ai.edge.litertlm.MessageCallback;
import com.google.ai.edge.litertlm.SamplerConfig;

import java.io.File;
import java.util.Collections;
import java.util.List;
import java.util.Objects;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.TimeoutException;
import java.util.stream.Collectors;

/**
 * Thin wrapper over the LiteRT-LM engine for on-device generation.
 *
 * <p>This client is a <em>pure generator</em>: it streams tokens for one turn
 * and keeps no tool-calling logic. All StudyOS tool routing lives in the Dart
 * layer ({@code LocalNativeLlmProvider}), which owns the single {@code [TOOL:…]}
 * loop; the native side only produces text.
 *
 * <p>The system prompt is installed <em>once</em> as the conversation's system
 * instruction and reused across turns; the conversation (and its KV cache) is
 * only rebuilt when the model path, backend preference, or system instruction
 * actually changes (see {@link #ensureConversation}).
 */
public class LiteRtLocalPromptClient implements AutoCloseable {
    private static final String TAG = "LiteRtLocalPrompt";

    // Deterministic on-device sampling profile. LiteRT-LM 0.13.1 binds the
    // sampler once at conversation creation — there is no per-message override
    // (LiteRT-LM issue #2249), and rebuilding a conversation to change it would
    // drop the KV cache. So a single low-temperature profile is used for all
    // local generation, favouring reliable tool-directive/JSON formatting.
    private static final int LOCAL_SAMPLER_TOP_K = 10;
    private static final double LOCAL_SAMPLER_TOP_P = 0.95;
    private static final double LOCAL_SAMPLER_TEMPERATURE = 0.2;
    private static final int LOCAL_SAMPLER_RANDOM_SEED = 0;

    /** Upper bound on a single generation before it is cancelled and surfaced as an error. */
    private static final long GENERATION_TIMEOUT_SECONDS = 120;

    private static final String DEFAULT_SYSTEM_INSTRUCTION =
            "You are StudyOS Agent. Answer from the provided context.";

    /** Prefer the GPU backend, falling back to CPU when GPU init fails. */
    public static final String BACKEND_GPU = "gpu";
    /** Force the CPU backend, never touching the GPU. */
    public static final String BACKEND_CPU = "cpu";

    private Engine engine;
    private Conversation conversation;
    private String activeModelPath;
    private String activeSystemInstruction;
    private String activeBackend;
    private String activeBackendPreference;
    private volatile String backendPreference = BACKEND_GPU;

    /** Receives streamed tokens as they are generated. */
    public interface StreamListener {
        void onToken(String token);
    }

    /** The accelerator the live engine initialized on ("GPU" or "CPU"), or null. */
    public String getActiveBackend() {
        return activeBackend;
    }

    /**
     * Selects which accelerator the next generation should use. {@link #BACKEND_CPU}
     * forces CPU; anything else means "prefer GPU, fall back to CPU". Changing the
     * preference reinitializes the engine on the next generation even if the model
     * path is unchanged.
     */
    public void setBackendPreference(String preference) {
        backendPreference = BACKEND_CPU.equals(preference) ? BACKEND_CPU : BACKEND_GPU;
    }

    /**
     * Generates a reply for {@code prompt}, streaming tokens to {@code listener}.
     * {@code systemInstruction} is installed as the conversation's system prompt
     * and only triggers a conversation rebuild when it changes.
     */
    public synchronized String generateStreaming(
            String modelPath,
            String prompt,
            String cacheDir,
            String systemInstruction,
            StreamListener streamListener
    ) throws Exception {
        ensureConversation(modelPath, cacheDir, systemInstruction);
        return streamSendMessage(prompt, streamListener);
    }

    private String streamSendMessage(String prompt, StreamListener streamListener) throws Exception {
        final StringBuilder full = new StringBuilder();
        final CountDownLatch latch = new CountDownLatch(1);
        final Throwable[] failure = new Throwable[1];
        conversation.sendMessageAsync(prompt, new MessageCallback() {
            @Override
            public void onMessage(Message message) {
                String chunk = extractChunk(message);
                if (chunk.isEmpty()) {
                    return;
                }
                full.append(chunk);
                if (streamListener != null) {
                    streamListener.onToken(chunk);
                }
            }

            @Override
            public void onDone() {
                latch.countDown();
            }

            @Override
            public void onError(Throwable throwable) {
                failure[0] = throwable;
                latch.countDown();
            }
        }, Collections.emptyMap());

        boolean completed = latch.await(GENERATION_TIMEOUT_SECONDS, TimeUnit.SECONDS);
        if (!completed) {
            // The callback never settled. Cancel the in-flight decode and surface
            // a timeout instead of blocking the executor thread forever.
            cancel();
            throw new TimeoutException(
                    "Local generation timed out after " + GENERATION_TIMEOUT_SECONDS + "s.");
        }
        if (failure[0] != null) {
            if (failure[0] instanceof Exception) {
                throw (Exception) failure[0];
            }
            throw new RuntimeException(failure[0]);
        }
        return full.toString().trim();
    }

    private void ensureConversation(String modelPath, String cacheDir, String systemInstruction)
            throws Exception {
        if (conversation != null
                && modelPath.equals(activeModelPath)
                && backendPreference.equals(activeBackendPreference)
                && Objects.equals(systemInstruction, activeSystemInstruction)) {
            return;
        }
        close();

        File modelFile = new File(modelPath);
        if (!modelFile.exists()) {
            throw new IllegalArgumentException("Model file does not exist: " + modelPath);
        }

        engine = initializeEngine(modelFile, cacheDir);
        String instruction = (systemInstruction == null || systemInstruction.isBlank())
                ? DEFAULT_SYSTEM_INSTRUCTION
                : systemInstruction;
        ConversationConfig config = new ConversationConfig(
                Contents.Companion.of(instruction),
                List.of(),
                List.of(),
                new SamplerConfig(
                        LOCAL_SAMPLER_TOP_K,
                        LOCAL_SAMPLER_TOP_P,
                        LOCAL_SAMPLER_TEMPERATURE,
                        LOCAL_SAMPLER_RANDOM_SEED
                )
        );
        conversation = engine.createConversation(config);
        activeModelPath = modelFile.getAbsolutePath();
        activeSystemInstruction = systemInstruction;
    }

    /**
     * Builds and initializes the LiteRT-LM engine according to {@link #backendPreference}.
     * {@link #BACKEND_CPU} forces CPU. Otherwise GPU is preferred and CPU is used as a
     * fallback when GPU initialization fails — unsupported driver, out-of-memory during
     * weight upload, or a model without GPU kernels. The winning accelerator is recorded
     * in {@link #activeBackend}.
     */
    private Engine initializeEngine(File modelFile, String cacheDir) throws Exception {
        final String preference = backendPreference;
        activeBackendPreference = preference;

        if (BACKEND_CPU.equals(preference)) {
            Engine cpuEngine = createEngine(modelFile, cacheDir, new Backend.CPU());
            cpuEngine.initialize();
            activeBackend = "CPU";
            Log.i(TAG, "LiteRT-LM initialized on CPU backend (forced).");
            return cpuEngine;
        }

        Engine gpuEngine = null;
        try {
            gpuEngine = createEngine(modelFile, cacheDir, new Backend.GPU());
            gpuEngine.initialize();
            activeBackend = "GPU";
            Log.i(TAG, "LiteRT-LM initialized on GPU backend.");
            return gpuEngine;
        } catch (Throwable gpuError) {
            Log.w(TAG, "GPU backend init failed; falling back to CPU.", gpuError);
            closeQuietly(gpuEngine);
        }

        Engine cpuEngine = createEngine(modelFile, cacheDir, new Backend.CPU());
        cpuEngine.initialize();
        activeBackend = "CPU";
        Log.i(TAG, "LiteRT-LM initialized on CPU backend (GPU fallback).");
        return cpuEngine;
    }

    private Engine createEngine(File modelFile, String cacheDir, Backend backend) {
        EngineConfig engineConfig = new EngineConfig(
                modelFile.getAbsolutePath(),
                backend,
                null,
                null,
                10_000,
                null,
                cacheDir
        );
        return new Engine(engineConfig);
    }

    private static void closeQuietly(Engine engine) {
        if (engine == null) {
            return;
        }
        try {
            engine.close();
        } catch (Throwable ignored) {
        }
    }

    /** Joins a message's contents without trimming, preserving token spacing. */
    private String extractChunk(Message message) {
        if (message == null || message.getContents() == null || message.getContents().getContents() == null) {
            return "";
        }
        return message.getContents().getContents().stream()
                .filter(Objects::nonNull)
                .map(Object::toString)
                .collect(Collectors.joining());
    }

    /**
     * Best-effort cancel of an in-flight generation. Safe to call from another
     * thread than the one blocked in {@link #streamSendMessage}; the pending
     * {@link MessageCallback} completes and releases its latch.
     */
    public void cancel() {
        Conversation active = conversation;
        if (active != null) {
            try {
                active.cancelProcess();
            } catch (Throwable ignored) {
            }
        }
    }

    @Override
    public synchronized void close() {
        try {
            if (conversation != null) conversation.close();
        } catch (Exception ignored) {
        }
        try {
            if (engine != null) engine.close();
        } catch (Exception ignored) {
        }
        conversation = null;
        engine = null;
        activeModelPath = null;
        activeSystemInstruction = null;
        activeBackend = null;
        activeBackendPreference = null;
    }
}
