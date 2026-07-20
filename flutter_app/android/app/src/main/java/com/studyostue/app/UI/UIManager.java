package com.example.studyOS.UI;

import android.app.Activity;
import android.view.Gravity;
import android.view.Window;
import android.view.WindowManager;
import android.widget.ImageButton;
import android.widget.LinearLayout;
import android.widget.TextView;

import androidx.drawerlayout.widget.DrawerLayout;
import androidx.recyclerview.widget.LinearLayoutManager;
import androidx.recyclerview.widget.RecyclerView;

import com.example.studyOS.Controller.JarvisController;
import com.example.studyOS.DataStructures.Message;
import com.example.studyOS.DataStructures.Speaker;
import com.studyostue.app.R;
import com.google.android.material.textfield.TextInputEditText;

import java.util.ArrayList;
import java.util.List;

public class UIManager {

    private static DrawerLayout drawerLayout;

    private static RecyclerView recyclerView;
    private static ChatAdapter chatAdapter;

    private static TextInputEditText inputField;
    private static ImageButton sendButton;

    private static Activity activity;

    private static final List<Message> messages = new ArrayList<>();

    // =========================================================
    // INIT
    // =========================================================

    public static void init(Activity act) {

        Window window = act.getWindow();
        window.addFlags(WindowManager.LayoutParams.FLAG_DRAWS_SYSTEM_BAR_BACKGROUNDS);
        window.clearFlags(WindowManager.LayoutParams.FLAG_TRANSLUCENT_STATUS);
        window.setStatusBarColor(act.getResources().getColor(R.color.black));

        activity = act;
        drawerLayout = act.findViewById(R.id.drawerLayout);

        recyclerView = act.findViewById(R.id.chatRecyclerView);
        recyclerView.setLayoutManager(new LinearLayoutManager(act));

        chatAdapter = new ChatAdapter(messages);
        recyclerView.setAdapter(chatAdapter);

        inputField = act.findViewById(R.id.inputField);
        sendButton = act.findViewById(R.id.sendButton);

        sendButton.setOnClickListener(v -> {
            String text = getInputText();
            if (!text.isEmpty()) {
                addUserMessage(text);
                clearInput();
            }
        });

        ImageButton menuButton = act.findViewById(R.id.menuButton);
        menuButton.setOnClickListener(v -> openSidebar());

        ImageButton addFileButton = act.findViewById(R.id.addFileButton);
        addFileButton.setOnClickListener(v -> onCreateNewFile());
    }

    // =========================================================
    // INPUT API
    // =========================================================

    public static String getInputText() {
        return inputField.getText() != null
                ? inputField.getText().toString().trim()
                : "";
    }

    public static void setInputText(String text) {
        inputField.setText(text);
    }

    public static void clearInput() {
        inputField.setText("");
    }

    public static void sendCurrentInput() {
        String text = getInputText();

        if (!text.isEmpty()) {
            addUserMessage(text);
            clearInput();
        }
    }

    public static void send(String text) {
        if (text != null && !text.trim().isEmpty()) {
            addUserMessage(text);
        }
    }

    // =========================================================
    // CHAT
    // =========================================================

    public static void addUserMessage(String text) {
        if (activity == null)
            return;

        JarvisController.getInstance().process(new Message(text, Speaker.BOSS));
        messages.add(new Message(text, Speaker.BOSS));
        updateChat();
    }

    public static void addJarvisMessage(String text) {
        if (activity == null)
            return;

        activity.runOnUiThread(() -> {
            JarvisController.getInstance().process(new Message(text, Speaker.JARVIS));
            messages.add(new Message(text, Speaker.JARVIS));
            updateChat();
        });
    }

    private static void updateChat() {
        chatAdapter.notifyItemInserted(messages.size() - 1);
        recyclerView.smoothScrollToPosition(messages.size() - 1);
    }

    // =========================================================
    // SIDEBAR
    // =========================================================

    public static void openSidebar() {
        drawerLayout.openDrawer(Gravity.LEFT);
    }

    public static void closeSidebar() {
        drawerLayout.closeDrawer(Gravity.LEFT);
    }

    public static void addSidebarFile(Activity act, String fileName) {

        LinearLayout container =
                act.findViewById(R.id.fileContainer);

        TextView file = new TextView(act);

        file.setText(fileName);
        file.setTextSize(18);
        file.setPadding(40, 40, 40, 40);
        file.setTextColor(0xFFFFFFFF);

        file.setOnClickListener(v -> onFileClicked(fileName));

        container.addView(file);
    }

    // =========================================================
    // CALLBACKS
    // =========================================================

    public static void onFileClicked(String fileName) {}

    public static void onCreateNewFile() {}
}
