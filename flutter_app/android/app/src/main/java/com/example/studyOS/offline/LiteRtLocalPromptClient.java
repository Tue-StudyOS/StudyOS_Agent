package com.example.studyOS.offline;

import android.util.Log;

import com.google.ai.edge.litertlm.Backend;
import com.google.ai.edge.litertlm.Content;
import com.google.ai.edge.litertlm.Contents;
import com.google.ai.edge.litertlm.Conversation;
import com.google.ai.edge.litertlm.ConversationConfig;
import com.google.ai.edge.litertlm.Engine;
import com.google.ai.edge.litertlm.EngineConfig;
import com.google.ai.edge.litertlm.Message;
import com.google.ai.edge.litertlm.MessageCallback;
import com.google.ai.edge.litertlm.OpenApiTool;
import com.google.ai.edge.litertlm.SamplerConfig;
import com.google.ai.edge.litertlm.ToolCall;
import com.google.ai.edge.litertlm.ToolKt;
import com.google.ai.edge.litertlm.ToolProvider;

import org.json.JSONArray;
import org.json.JSONObject;
import org.json.JSONTokener;

import java.io.File;
import java.util.ArrayList;
import java.util.Collections;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
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
    private String activeToolsSignature;
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
        ensureConversation(modelPath, cacheDir, systemInstruction, Collections.<String>emptyList());
        return streamSendMessage(prompt, streamListener);
    }

    /**
     * Native function-calling first turn (manual mode). Ensures a tool-enabled
     * conversation from {@code toolSchemasJson} (OpenAPI function declarations),
     * streams {@code prompt}, and returns a structured result map:
     * {@code {"type":"tool_calls","calls":[{"name","arguments"(JSON string)}]}}
     * or {@code {"type":"text","text"}}. Text fragments of a plain-answer turn are
     * streamed to {@code streamListener} as they arrive (a tool-request turn emits
     * no user-visible tokens); tool execution stays in the Dart layer, and results
     * come back via {@link #continueWithToolResults}.
     */
    public synchronized Map<String, Object> generateWithTools(
            String modelPath,
            String prompt,
            String cacheDir,
            String systemInstruction,
            List<String> toolSchemasJson,
            StreamListener streamListener
    ) throws Exception {
        ensureConversation(modelPath, cacheDir, systemInstruction, toolSchemasJson);
        return streamToolTurn(
                streamListener,
                callback -> conversation.sendMessageAsync(
                        prompt, callback, Collections.<String, Object>emptyMap()));
    }

    /**
     * Feeds executed tool results back into the active tool conversation and
     * streams the next turn (same shape as {@link #generateWithTools}). Each entry
     * is {@code {"name": String, "response": Object}}.
     */
    public synchronized Map<String, Object> continueWithToolResults(
            List<Map<String, Object>> results,
            StreamListener streamListener
    ) throws Exception {
        if (conversation == null) {
            throw new IllegalStateException(
                    "No active tool conversation. Send a tool message first.");
        }
        List<Content> contents = new ArrayList<>();
        for (Map<String, Object> result : results) {
            String name = String.valueOf(result.get("name"));
            Object response = result.get("response");
            contents.add(new Content.ToolResponse(name, response == null ? "" : response));
        }
        Message toolMessage = Message.Companion.tool(Contents.Companion.of(contents));
        return streamToolTurn(
                streamListener,
                callback -> conversation.sendMessageAsync(
                        toolMessage, callback, Collections.<String, Object>emptyMap()));
    }

    /**
     * Runs one tool-enabled turn with live token streaming. Text fragments are
     * streamed to {@code streamListener} as they arrive; any structured tool calls
     * the model emits are collected. Returns the structured map the Dart tool loop
     * expects: a {@code tool_calls} turn when the model requested tools, else a
     * {@code text} turn carrying the streamed final answer.
     *
     * <p>This is the streaming analogue of the old synchronous
     * {@code conversation.sendMessage} tool path. It reuses the same
     * {@link #GENERATION_TIMEOUT_SECONDS} latch/cancel guard as
     * {@link #streamSendMessage}, so a native function-calling turn is now bounded
     * and cancellable exactly like plain text generation.
     */
    private Map<String, Object> streamToolTurn(
            StreamListener streamListener, AsyncSend sender) throws Exception {
        final StringBuilder fullText = new StringBuilder();
        final List<ToolCall> collectedCalls = new ArrayList<>();
        final CountDownLatch latch = new CountDownLatch(1);
        final Throwable[] failure = new Throwable[1];
        sender.send(new MessageCallback() {
            @Override
            public void onMessage(Message message) {
                if (message == null) {
                    return;
                }
                // Tool calls ride Message.getToolCalls(), not the text contents, so
                // a tool-request delta streams no user-visible tokens. Collect calls
                // across deltas (mirroring the incremental text stream); the Dart
                // loop clears the live buffer before the follow-up answer streams.
                List<ToolCall> calls = message.getToolCalls();
                if (calls != null && !calls.isEmpty()) {
                    collectedCalls.addAll(calls);
                }
                String chunk = textContent(message);
                if (chunk.isEmpty()) {
                    return;
                }
                fullText.append(chunk);
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
        });
        awaitGeneration(latch, failure);
        return buildTurnResult(collectedCalls, fullText.toString().trim());
    }

    /** Dispatches an async send on the active conversation with our stream callback. */
    private interface AsyncSend {
        void send(MessageCallback callback) throws Exception;
    }

    /**
     * Builds the structured turn map from a completed stream: a {@code tool_calls}
     * turn when the model requested tools, else a {@code text} turn.
     */
    private static Map<String, Object> buildTurnResult(List<ToolCall> calls, String text) {
        Map<String, Object> out = new HashMap<>();
        if (calls != null && !calls.isEmpty()) {
            out.put("type", "tool_calls");
            out.put("calls", callsToMaps(calls));
        } else {
            out.put("type", "text");
            out.put("text", text);
        }
        return out;
    }

    /** Serializes structured tool calls into the Dart executor's name/arguments shape. */
    private static List<Map<String, Object>> callsToMaps(List<ToolCall> calls) {
        List<Map<String, Object>> callList = new ArrayList<>();
        for (ToolCall call : calls) {
            Map<String, Object> callMap = new HashMap<>();
            callMap.put("name", call.getName());
            callMap.put("arguments", argumentsToJson(call.getArguments()));
            callList.add(callMap);
        }
        return callList;
    }

    /** Serializes a tool call's argument map into a JSON string for the Dart executor. */
    private static String argumentsToJson(Map<String, Object> arguments) {
        if (arguments == null || arguments.isEmpty()) {
            return "{}";
        }
        try {
            JSONObject object = new JSONObject();
            for (Map.Entry<String, Object> entry : arguments.entrySet()) {
                object.put(entry.getKey(), jsonSafe(entry.getValue()));
            }
            return object.toString();
        } catch (Throwable error) {
            Log.w(TAG, "Failed to serialize tool arguments; sending empty object.", error);
            return "{}";
        }
    }

    /**
     * Coerces a value into an {@code org.json}-safe form. Gson elements (which
     * LiteRT-LM may hand back) are re-parsed from their JSON text so they are not
     * double-encoded; maps/lists recurse; primitives pass through.
     */
    private static Object jsonSafe(Object value) {
        if (value == null) {
            return JSONObject.NULL;
        }
        if (value instanceof com.google.gson.JsonElement) {
            try {
                return new JSONTokener(value.toString()).nextValue();
            } catch (Throwable ignored) {
                return value.toString();
            }
        }
        if (value instanceof Map) {
            JSONObject object = new JSONObject();
            Map<?, ?> map = (Map<?, ?>) value;
            for (Map.Entry<?, ?> entry : map.entrySet()) {
                try {
                    object.put(String.valueOf(entry.getKey()), jsonSafe(entry.getValue()));
                } catch (Throwable ignored) {
                    // Skip un-encodable entries rather than failing the whole call.
                }
            }
            return object;
        }
        if (value instanceof Iterable) {
            JSONArray array = new JSONArray();
            for (Object item : (Iterable<?>) value) {
                array.put(jsonSafe(item));
            }
            return array;
        }
        return value;
    }

    // ---- Native function-calling probe -------------------------------------
    // A throwaway spike (debug-only) that verifies whether LiteRT-LM 0.13.1's
    // manual tool-calling path works on the shipped model: it declares one
    // OpenApiTool, disables automaticToolCalling, and checks that the model
    // returns a *structured* ToolCall (Message.getToolCalls()) instead of the
    // bracketed [TOOL:] text the production path parses. It also round-trips a
    // Content.ToolResponse to confirm the model produces a final answer. This is
    // deliberately isolated from the cached production conversation and does not
    // touch the [TOOL:] loop — see local-inference-architecture memory.

    private static final String PROBE_TOOL_SCHEMA =
            "{\"name\":\"read_memories\","
                    + "\"description\":\"Read the student's saved long-term memory notes.\","
                    + "\"parameters\":{\"type\":\"object\",\"properties\":{},\"required\":[]}}";
    private static final String PROBE_SYSTEM_INSTRUCTION =
            "You are a StudyOS test agent. When the user asks about their saved memory "
                    + "notes, call the read_memories tool to look them up.";
    private static final String PROBE_USER_PROMPT =
            "What have I saved in my memory notes? Use the read_memories tool to check.";
    private static final String PROBE_TOOL_RESULT =
            "{\"memories\":\"Probe succeeded: the student prefers morning study sessions.\"}";

    /**
     * Runs the manual native tool-calling probe against {@code modelPath} and returns a
     * human-readable diagnostic report. Builds its own engine/conversation and closes them,
     * so the cached production conversation (and its KV cache) is left untouched. Any cached
     * production engine is released first to avoid holding two engines in memory at once.
     */
    public synchronized String probeToolCall(String modelPath, String cacheDir) throws Exception {
        File modelFile = new File(modelPath);
        if (!modelFile.exists()) {
            return "Model file does not exist: " + modelPath;
        }
        // Free any cached production engine so the probe engine does not double RAM.
        close();

        Engine probeEngine = null;
        Conversation probeConversation = null;
        StringBuilder report = new StringBuilder();
        try {
            try {
                probeEngine = createEngine(modelFile, cacheDir, new Backend.GPU());
                probeEngine.initialize();
                report.append("engine: GPU\n");
            } catch (Throwable gpuError) {
                closeQuietly(probeEngine);
                probeEngine = createEngine(modelFile, cacheDir, new Backend.CPU());
                probeEngine.initialize();
                report.append("engine: CPU (GPU fallback)\n");
            }

            OpenApiTool readMemoriesTool = new OpenApiTool() {
                @Override
                public String getToolDescriptionJsonString() {
                    return PROBE_TOOL_SCHEMA;
                }

                @Override
                public String execute(String argumentsJson) {
                    // Never invoked in manual mode (automaticToolCalling = false);
                    // present only to satisfy the interface.
                    return PROBE_TOOL_RESULT;
                }
            };

            ConversationConfig config = new ConversationConfig(
                    Contents.Companion.of(PROBE_SYSTEM_INSTRUCTION),
                    Collections.<Message>emptyList(),
                    List.of(ToolKt.tool(readMemoriesTool)),
                    new SamplerConfig(
                            LOCAL_SAMPLER_TOP_K,
                            LOCAL_SAMPLER_TOP_P,
                            LOCAL_SAMPLER_TEMPERATURE,
                            LOCAL_SAMPLER_RANDOM_SEED
                    ),
                    false /* automaticToolCalling: manual — hand tool calls back to us */
            );
            probeConversation = probeEngine.createConversation(config);

            Message first = probeConversation.sendMessage(
                    PROBE_USER_PROMPT, Collections.<String, Object>emptyMap());
            List<ToolCall> calls = first.getToolCalls();
            int callCount = calls == null ? 0 : calls.size();
            report.append("tool_calls_returned: ").append(callCount).append('\n');

            if (callCount == 0) {
                report.append("first_response_text: ").append(joinText(first)).append('\n');
                report.append("VERDICT: FAIL — model did not emit a structured tool call.\n");
                return report.toString();
            }

            ToolCall call = calls.get(0);
            report.append("call.name: ").append(call.getName()).append('\n');
            report.append("call.arguments: ").append(call.getArguments()).append('\n');

            // Round-trip a tool result and confirm the model produces a final answer.
            Content.ToolResponse toolResponse =
                    new Content.ToolResponse(call.getName(), PROBE_TOOL_RESULT);
            Message toolMessage = Message.Companion.tool(Contents.Companion.of(toolResponse));
            Message finalResp = probeConversation.sendMessage(
                    toolMessage, Collections.<String, Object>emptyMap());
            report.append("final_answer: ").append(joinText(finalResp)).append('\n');
            report.append("VERDICT: PASS — native function calling works on this model.\n");
            return report.toString();
        } catch (Throwable error) {
            report.append("VERDICT: ERROR — ").append(error).append('\n');
            return report.toString();
        } finally {
            if (probeConversation != null) {
                try {
                    probeConversation.close();
                } catch (Throwable ignored) {
                }
            }
            closeQuietly(probeEngine);
        }
    }

    /** Concatenates the text parts of a message, trimmed; ignores non-text content. */
    private static String joinText(Message message) {
        return textContent(message).trim();
    }

    /**
     * Concatenates the text parts of a message without trimming, so streamed
     * chunks keep their leading/trailing spacing. Tool-call content lives on
     * {@link Message#getToolCalls()} rather than here, so a pure tool-request delta
     * yields the empty string.
     */
    private static String textContent(Message message) {
        if (message == null
                || message.getContents() == null
                || message.getContents().getContents() == null) {
            return "";
        }
        StringBuilder sb = new StringBuilder();
        for (Content content : message.getContents().getContents()) {
            if (content instanceof Content.Text) {
                sb.append(((Content.Text) content).getText());
            }
        }
        return sb.toString();
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

        awaitGeneration(latch, failure);
        return full.toString().trim();
    }

    /**
     * Blocks until a streamed generation settles, enforcing the shared
     * {@link #GENERATION_TIMEOUT_SECONDS} bound. On timeout the in-flight decode is
     * cancelled and a {@link TimeoutException} is thrown instead of blocking the
     * executor thread forever; a callback failure is rethrown.
     */
    private void awaitGeneration(CountDownLatch latch, Throwable[] failure) throws Exception {
        boolean completed = latch.await(GENERATION_TIMEOUT_SECONDS, TimeUnit.SECONDS);
        if (!completed) {
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
    }

    private void ensureConversation(
            String modelPath,
            String cacheDir,
            String systemInstruction,
            List<String> toolSchemasJson
    ) throws Exception {
        String toolsSignature = toolsSignature(toolSchemasJson);
        if (conversation != null
                && modelPath.equals(activeModelPath)
                && backendPreference.equals(activeBackendPreference)
                && Objects.equals(systemInstruction, activeSystemInstruction)
                && Objects.equals(toolsSignature, activeToolsSignature)) {
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
        List<ToolProvider> toolProviders = new ArrayList<>();
        if (toolSchemasJson != null) {
            for (String schema : toolSchemasJson) {
                if (schema != null && !schema.isBlank()) {
                    toolProviders.add(ToolKt.tool(openApiToolFor(schema)));
                }
            }
        }
        // automaticToolCalling = false: even with tools declared, hand every tool
        // call back to the Dart loop rather than executing natively. Harmless when
        // toolProviders is empty (the plain text-generation path).
        ConversationConfig config = new ConversationConfig(
                Contents.Companion.of(instruction),
                Collections.<Message>emptyList(),
                toolProviders,
                new SamplerConfig(
                        LOCAL_SAMPLER_TOP_K,
                        LOCAL_SAMPLER_TOP_P,
                        LOCAL_SAMPLER_TEMPERATURE,
                        LOCAL_SAMPLER_RANDOM_SEED
                ),
                false
        );
        conversation = engine.createConversation(config);
        activeModelPath = modelFile.getAbsolutePath();
        activeSystemInstruction = systemInstruction;
        activeToolsSignature = toolsSignature;
    }

    /** A stable fingerprint of the declared tool schemas, for conversation reuse. */
    private static String toolsSignature(List<String> toolSchemasJson) {
        if (toolSchemasJson == null || toolSchemasJson.isEmpty()) {
            return "";
        }
        return String.join("", toolSchemasJson);
    }

    /**
     * Wraps one OpenAPI function declaration as an {@link OpenApiTool}. In manual
     * mode {@link OpenApiTool#execute} is never invoked (the Dart layer executes
     * tools), so it only needs to surface the declaration JSON.
     */
    private static OpenApiTool openApiToolFor(final String schemaJson) {
        return new OpenApiTool() {
            @Override
            public String getToolDescriptionJsonString() {
                return schemaJson;
            }

            @Override
            public String execute(String argumentsJson) {
                return "";
            }
        };
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
        activeToolsSignature = null;
    }
}
