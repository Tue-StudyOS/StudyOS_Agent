package com.example.studyOS.offline;

import com.google.ai.edge.litertlm.Backend;
import com.google.ai.edge.litertlm.Contents;
import com.google.ai.edge.litertlm.Conversation;
import com.google.ai.edge.litertlm.ConversationConfig;
import com.google.ai.edge.litertlm.Engine;
import com.google.ai.edge.litertlm.EngineConfig;
import com.google.ai.edge.litertlm.Message;
import com.google.ai.edge.litertlm.SamplerConfig;

import java.io.File;
import java.util.ArrayList;
import java.util.Collections;
import java.util.List;
import java.util.Objects;
import java.util.regex.Matcher;
import java.util.regex.Pattern;
import java.util.stream.Collectors;

public class LiteRtLocalPromptClient implements AutoCloseable {
    private static final Pattern TOOL_CALL_PATTERN = Pattern.compile("\\[TOOL:([^:\\]]+):?([^\\]]*)\\]");
    private static final int MAX_TOOL_ROUNDS = 3;

    private Engine engine;
    private Conversation conversation;
    private String activeModelPath;

    public interface ToolExecutor {
        boolean canExecute(String toolName);

        String execute(String toolName, String argument);
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

    private boolean allCallsCanExecute(List<ToolCall> toolCalls, ToolExecutor toolExecutor) {
        for (ToolCall call : toolCalls) {
            if (!toolExecutor.canExecute(call.name)) {
                return false;
            }
        }
        return true;
    }

    private void ensureConversation(String modelPath, String cacheDir) throws Exception {
        if (conversation != null && modelPath.equals(activeModelPath)) {
            return;
        }
        close();

        File modelFile = new File(modelPath);
        if (!modelFile.exists()) {
            throw new IllegalArgumentException("Model file does not exist: " + modelPath);
        }

        EngineConfig engineConfig = new EngineConfig(
                modelFile.getAbsolutePath(),
                new Backend.CPU(),
                null,
                null,
                10_000,
                null,
                cacheDir
        );
        engine = new Engine(engineConfig);
        engine.initialize();
        ConversationConfig config = new ConversationConfig(
                Contents.Companion.of("You are StudyOS Agent. Answer from the provided context."),
                List.of(Message.Companion.user("System ready.")),
                List.of(),
                new SamplerConfig(10, 0.95, 0.8, 0)
        );
        conversation = engine.createConversation(config);
        activeModelPath = modelFile.getAbsolutePath();
    }

    private String extractText(Message message) {
        if (message == null || message.getContents() == null || message.getContents().getContents() == null) {
            return "";
        }
        return message.getContents().getContents().stream()
                .filter(Objects::nonNull)
                .map(Object::toString)
                .collect(Collectors.joining())
                .trim();
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
    }
}
