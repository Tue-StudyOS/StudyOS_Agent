package com.example.studyOS.UI;

import android.graphics.Color;
import android.view.Gravity;
import android.view.View;
import android.view.ViewGroup;
import android.widget.FrameLayout;
import android.widget.TextView;

import androidx.annotation.NonNull;
import androidx.recyclerview.widget.RecyclerView;

import com.example.studyOS.DataStructures.Message;
import com.example.studyOS.DataStructures.Speaker;
import com.example.studyOS.R; // Stelle sicher, dass dein R-Package importiert ist

import java.util.List;

public class ChatAdapter extends RecyclerView.Adapter<ChatAdapter.ViewHolder> {

    private final List<Message> messages;

    public ChatAdapter(List<Message> messages) {
        this.messages = messages;
    }

    @NonNull
    @Override
    public ViewHolder onCreateViewHolder(@NonNull ViewGroup parent, int viewType) {
        FrameLayout root = new FrameLayout(parent.getContext());
        RecyclerView.LayoutParams rootParams = new RecyclerView.LayoutParams(
                RecyclerView.LayoutParams.MATCH_PARENT,
                RecyclerView.LayoutParams.WRAP_CONTENT
        );
        root.setLayoutParams(rootParams);

        // FrameLayout statt CardView für die Chat-Blase
        FrameLayout bubbleLayout = new FrameLayout(parent.getContext());
        FrameLayout.LayoutParams bubbleParams = new FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.WRAP_CONTENT,
                FrameLayout.LayoutParams.WRAP_CONTENT
        );
        bubbleParams.setMargins(20, 20, 20, 20);
        bubbleLayout.setLayoutParams(bubbleParams);

        TextView textView = new TextView(parent.getContext());
        textView.setTextIsSelectable(true);
        textView.setTextColor(Color.WHITE);
        textView.setTextSize(17);
        textView.setPadding(46, 34, 46, 34); // Etwas mehr Padding sieht bei Glas besser aus

        bubbleLayout.addView(textView);
        root.addView(bubbleLayout);

        return new ViewHolder(root, bubbleLayout, textView, bubbleParams);
    }

    @Override
    public void onBindViewHolder(@NonNull ViewHolder holder, int position) {
        Message message = messages.get(position);
        holder.textView.setText(message.text());

        if (message.speaker().equals(Speaker.BOSS)) {
            holder.bubbleParams.gravity = Gravity.END;
            holder.bubbleLayout.setBackgroundResource(R.drawable.bg_chat_user);
        } else {
            holder.bubbleParams.gravity = Gravity.START;
            holder.bubbleLayout.setBackgroundResource(R.drawable.bg_chat_jarvis);
        }

        holder.bubbleLayout.setLayoutParams(holder.bubbleParams);
    }

    @Override
    public int getItemCount() {
        return messages.size();
    }

    static class ViewHolder extends RecyclerView.ViewHolder {
        FrameLayout bubbleLayout;
        TextView textView;
        FrameLayout.LayoutParams bubbleParams;

        public ViewHolder(@NonNull View itemView, FrameLayout bubbleLayout, TextView textView, FrameLayout.LayoutParams bubbleParams) {
            super(itemView);
            this.bubbleLayout = bubbleLayout;
            this.textView = textView;
            this.bubbleParams = bubbleParams;
        }
    }
}