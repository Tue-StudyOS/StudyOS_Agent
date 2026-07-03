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
import java.util.ArrayList;
import java.util.Collections;
import java.util.List;
import java.util.Objects;
import java.util.concurrent.CountDownLatch;
import java.util.regex.Matcher;
import java.util.regex.Pattern;
import java.util.stream.Collectors;

public class LiteRtLocalPromptClient implements AutoCloseable {
    private static final String TAG = "LiteRtLocalPrompt";
    private static final Pattern TOOL_CALL_PATTERN = Pattern.compile("\\[TOOL:([^:\\]]+):?([^\\]]*)\\]");
    private static final int MAX_TOOL_ROUNDS = 3;
    private static final int TOOL_SAMPLER_TOP_K = 10;
    private static final double TOOL_SAMPLER_TOP_P = 0.95;
    private static final double TOOL_SAMPLER_TEMPERATURE = 0.2;
    private static final int TOOL_SAMPLER_RANDOM_SEED = 0;

    /** Prefer the GPU backend, falling back to CPU when GPU init fails. */
    public static final String BACKEND_GPU = "gpu";
    /** Force the CPU backend, never touching the GPU. */
    public static final String BACKEND_CPU = "cpu";

    private Engine engine;
    private Conversation conversation;
    private String activeModelPath;
    private String activeBackend;
    private String activeBackendPreference;
    private volatile String backendPreference = BACKEND_GPU;

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

    public interface ToolExecutor {
        boolean canExecute(String toolName);

        String execute(String toolName, String argument);
    }

    /** Receives streamed tokens and a reset signal between tool rounds. */
    public interface StreamListener {
        void onToken(String token);

        void onReset();
    }

    public synchronized String generate(String modelPath, String prompt, String cacheDir) throws Exception {
        ensureConversation(modelPath, cacheDir);
        return extractText(conversation.sendMessage(prompt, Collections.emptyMap()));
    }

    public synchronized String generateWithTools(
            String modelPath,
            String prompt,
            String cacheDir,
            ToolExecutor toolExecutor
    ) throws Exception {
        ensureConversation(modelPath, cacheDir);
        String responseText = extractText(conversation.sendMessage(prompt, Collections.emptyMap()));

        for (int round = 0; round < MAX_TOOL_ROUNDS; round++) {
            List<ToolCall> toolCalls = parseToolCalls(responseText);
            if (toolCalls.isEmpty()) {
                return responseText;
            }
            if (!allCallsCanExecute(toolCalls, toolExecutor)) {
                return responseText;
            }

            StringBuilder feedback = new StringBuilder();
            for (ToolCall call : toolCalls) {
                String output = toolExecutor.execute(call.name, call.argument);
                feedback
                        .append("- ")
                        .append(call.name)
                        .append(": ")
                        .append(output == null ? "" : output.trim())
                        .append("\n");
            }

            String instruction = "System feedback from executed Android local tools:\n"
                    + feedback.toString().trim()
                    + "\n\nIf another tool is still needed, respond only with "
                    + "[TOOL:TOOL_NAME:ARGUMENT]. Otherwise answer the user naturally "
                    + "using the tool results and provided StudyOS context.";
            responseText = extractText(conversation.sendMessage(instruction, Collections.emptyMap()));
        }

        return responseText;
    }

    /**
     * Like {@link #generateWithTools}, but streams each round's tokens to
     * {@code streamListener}. When a round resolves into a tool directive, the
     * listener is reset so the bracketed call does not linger in the live UI
     * before the follow-up answer streams.
     */
    public synchronized String generateWithToolsStreaming(
            String modelPath,
            String prompt,
            String cacheDir,
            ToolExecutor toolExecutor,
            StreamListener streamListener
    ) throws Exception {
        ensureConversation(modelPath, cacheDir);
        String responseText = streamSendMessage(prompt, streamListener);

        for (int round = 0; round < MAX_TOOL_ROUNDS; round++) {
            List<ToolCall> toolCalls = parseToolCalls(responseText);
            if (toolCalls.isEmpty()) {
                return responseText;
            }
            if (!allCallsCanExecute(toolCalls, toolExecutor)) {
                return responseText;
            }

            // This round was a tool directive, not a user-facing answer.
            if (streamListener != null) {
                streamListener.onReset();
            }

            StringBuilder feedback = new StringBuilder();
            for (ToolCall call : toolCalls) {
                String output = toolExecutor.execute(call.name, call.argument);
                feedback
                        .append("- ")
                        .append(call.name)
                        .append(": ")
                        .append(output == null ? "" : output.trim())
                        .append("\n");
            }

            String instruction = "System feedback from executed Android local tools:\n"
                    + feedback.toString().trim()
                    + "\n\nIf another tool is still needed, respond only with "
                    + "[TOOL:TOOL_NAME:ARGUMENT]. Otherwise answer the user naturally "
                    + "using the tool results and provided StudyOS context.";
            responseText = streamSendMessage(instruction, streamListener);
        }

        return responseText;
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

        latch.await();
        if (failure[0] != null) {
            if (failure[0] instanceof Exception) {
                throw (Exception) failure[0];
            }
            throw new RuntimeException(failure[0]);
        }
        return full.toString().trim();
    }

    private boolean allCallsCanExecute(List<ToolCall> toolCalls, ToolExecutor toolExecutor) {
        for (ToolCall call : toolCalls) {
            if (!toolExecutor.canExecute(call.name)) {
                return false;
            }
        }
        return true;
    }

    private void ensureConversation(String modelPath, String cacheDir) throws Exception {
        if (conversation != null
                && modelPath.equals(activeModelPath)
                && backendPreference.equals(activeBackendPreference)) {
            return;
        }
        close();

        File modelFile = new File(modelPath);
        if (!modelFile.exists()) {
            throw new IllegalArgumentException("Model file does not exist: " + modelPath);
        }

        engine = initializeEngine(modelFile, cacheDir);
        ConversationConfig config = new ConversationConfig(
                Contents.Companion.of("You are StudyOS Agent. Answer from the provided context."),
                List.of(Message.Companion.user("System ready.")),
                List.of(),
                new SamplerConfig(
                        TOOL_SAMPLER_TOP_K,
                        TOOL_SAMPLER_TOP_P,
                        TOOL_SAMPLER_TEMPERATURE,
                        TOOL_SAMPLER_RANDOM_SEED
                )
        );
        conversation = engine.createConversation(config);
        activeModelPath = modelFile.getAbsolutePath();
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

    private String extractText(Message message) {
        return extractChunk(message).trim();
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

    private List<ToolCall> parseToolCalls(String text) {
        if (text == null || text.isBlank()) {
            return Collections.emptyList();
        }
        Matcher matcher = TOOL_CALL_PATTERN.matcher(text);
        List<ToolCall> toolCalls = new ArrayList<>();
        while (matcher.find()) {
            String name = matcher.group(1) == null ? "" : matcher.group(1).trim();
            String argument = matcher.group(2) == null ? "" : matcher.group(2).trim();
            if (!name.isEmpty()) {
                toolCalls.add(new ToolCall(name, argument));
            }
        }
        return toolCalls;
    }

    private static final class ToolCall {
        private final String name;
        private final String argument;

        private ToolCall(String name, String argument) {
            this.name = name;
            this.argument = argument;
        }
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
        activeBackend = null;
        activeBackendPreference = null;
    }
}
