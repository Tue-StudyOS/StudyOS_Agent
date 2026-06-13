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
import java.util.Collections;
import java.util.List;
import java.util.Objects;
import java.util.stream.Collectors;

public class LiteRtLocalPromptClient implements AutoCloseable {
    private Engine engine;
    private Conversation conversation;
    private String activeModelPath;

    public synchronized String generate(String modelPath, String prompt, String cacheDir) throws Exception {
        ensureConversation(modelPath, cacheDir);
        return extractText(conversation.sendMessage(prompt, Collections.emptyMap()));
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
