import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() {
  runApp(const StudyOsAgentApp());
}

class StudyOsAgentApp extends StatelessWidget {
  const StudyOsAgentApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'StudyOS Agent',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF3B82F6),
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: const Color(0xFF090D13),
        useMaterial3: true,
      ),
      home: const AgentHomePage(),
    );
  }
}

class NativeBridge {
  static const MethodChannel _methods = MethodChannel('studyos/native');
  static const EventChannel _events = EventChannel('studyos/events');

  Stream<NativeEvent> get events =>
      _events.receiveBroadcastStream().map((event) {
        if (event is Map) {
          return NativeEvent.fromMap(Map<String, Object?>.from(event));
        }
        return const NativeEvent(type: 'status', message: '', timestamp: '');
      });

  Future<Map<String, Object?>> initialize() async {
    final result = await _methods.invokeMapMethod<String, Object?>(
      'initialize',
    );
    return result ?? const {};
  }

  Future<Map<String, Object?>> getWorldState() async {
    final result = await _methods.invokeMapMethod<String, Object?>(
      'getWorldState',
    );
    return result ?? const {};
  }

  Future<Map<String, Object?>> getCapabilities() async {
    final result = await _methods.invokeMapMethod<String, Object?>(
      'getCapabilities',
    );
    return result ?? const {};
  }

  Future<String> sendMessage(String text) async {
    final result = await _methods.invokeMethod<String>(
      'sendMessage',
      <String, Object?>{'text': text},
    );
    return result ?? 'Native bridge returned no status.';
  }
}

class NativeEvent {
  const NativeEvent({
    required this.type,
    required this.message,
    required this.timestamp,
  });

  factory NativeEvent.fromMap(Map<String, Object?> map) {
    return NativeEvent(
      type: map['type']?.toString() ?? 'status',
      message: map['message']?.toString() ?? '',
      timestamp: map['timestamp']?.toString() ?? '',
    );
  }

  final String type;
  final String message;
  final String timestamp;
}

class ChatMessage {
  const ChatMessage({
    required this.author,
    required this.text,
    required this.isUser,
  });

  final String author;
  final String text;
  final bool isUser;
}

class AgentHomePage extends StatefulWidget {
  const AgentHomePage({super.key});

  @override
  State<AgentHomePage> createState() => _AgentHomePageState();
}

class _AgentHomePageState extends State<AgentHomePage> {
  final NativeBridge _bridge = NativeBridge();
  final TextEditingController _inputController = TextEditingController();
  final List<ChatMessage> _messages = <ChatMessage>[
    const ChatMessage(
      author: 'JARVIS',
      text: 'Flutter shell online. Native bridge pending initialization.',
      isUser: false,
    ),
  ];

  StreamSubscription<NativeEvent>? _eventSubscription;
  Map<String, Object?> _capabilities = const {};
  Map<String, Object?> _worldState = const {};
  String _status = 'Starting';
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _eventSubscription = _bridge.events.listen(
      _handleNativeEvent,
      onError: (Object error) {
        if (mounted) setState(() => _status = 'Native events unavailable');
      },
    );
    unawaited(_initializeNativeLayer());
  }

  @override
  void dispose() {
    _eventSubscription?.cancel();
    _inputController.dispose();
    super.dispose();
  }

  Future<void> _initializeNativeLayer() async {
    try {
      final init = await _bridge.initialize();
      final capabilities = await _bridge.getCapabilities();
      final worldState = await _bridge.getWorldState();
      if (!mounted) return;

      setState(() {
        _status = init['status']?.toString() ?? 'Native bridge ready';
        _capabilities = capabilities;
        _worldState = worldState;
      });
    } on MissingPluginException {
      _addAssistantMessage('Native bridge is not implemented on this target.');
      setState(() => _status = 'Native bridge missing');
    } on PlatformException catch (error) {
      _addAssistantMessage('Native bridge failed: ${error.message}');
      setState(() => _status = 'Native bridge failed');
    }
  }

  void _handleNativeEvent(NativeEvent event) {
    if (!mounted || event.message.isEmpty) return;
    setState(() {
      _status = event.message;
      _messages.add(
        ChatMessage(author: 'Native', text: event.message, isUser: false),
      );
    });
  }

  Future<void> _sendMessage() async {
    final text = _inputController.text.trim();
    if (text.isEmpty || _isSending) return;

    setState(() {
      _isSending = true;
      _inputController.clear();
      _messages.add(ChatMessage(author: 'You', text: text, isUser: true));
    });

    try {
      final response = await _bridge.sendMessage(text);
      _addAssistantMessage(response);
      final worldState = await _bridge.getWorldState();
      if (!mounted) return;
      setState(() => _worldState = worldState);
    } on MissingPluginException {
      _addAssistantMessage('Native bridge is not implemented on this target.');
    } on PlatformException catch (error) {
      _addAssistantMessage('Native bridge error: ${error.message}');
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  void _addAssistantMessage(String text) {
    if (!mounted) return;
    setState(() {
      _messages.add(ChatMessage(author: 'JARVIS', text: text, isUser: false));
      _status = text;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: _MemoryDrawer(
        capabilities: _capabilities,
        worldState: _worldState,
      ),
      body: SafeArea(
        child: Column(
          children: <Widget>[
            _TopBar(status: _status),
            Expanded(child: _MessageList(messages: _messages)),
            _InputBar(
              controller: _inputController,
              isSending: _isSending,
              onSend: _sendMessage,
            ),
          ],
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 14, 14, 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: <Widget>[
          Builder(
            builder: (context) {
              return IconButton(
                tooltip: 'Open memory',
                onPressed: Scaffold.of(context).openDrawer,
                icon: const Icon(Icons.menu),
              );
            },
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'JARVIS 9',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
                ),
                SizedBox(height: 2),
                Text(
                  'Flutter shell with native Android bridge',
                  style: TextStyle(color: Color(0xFF93C5FD), fontSize: 12),
                ),
              ],
            ),
          ),
          const Icon(Icons.memory, color: Color(0xFF4ADE80)),
          const SizedBox(width: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 160),
            child: Text(
              status,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.end,
              style: const TextStyle(fontSize: 12, color: Color(0xFFCBD5E1)),
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageList extends StatelessWidget {
  const _MessageList({required this.messages});

  final List<ChatMessage> messages;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      itemCount: messages.length,
      itemBuilder: (context, index) {
        final message = messages[index];
        return Align(
          alignment: message.isUser
              ? Alignment.centerRight
              : Alignment.centerLeft,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 560),
            margin: const EdgeInsets.symmetric(vertical: 5),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: message.isUser
                  ? const Color(0xFF2563EB)
                  : Colors.white.withValues(alpha: 0.09),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  message.author,
                  style: TextStyle(
                    color: message.isUser
                        ? const Color(0xFFE0F2FE)
                        : const Color(0xFF93C5FD),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 5),
                Text(message.text, style: const TextStyle(fontSize: 15)),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _InputBar extends StatelessWidget {
  const _InputBar({
    required this.controller,
    required this.isSending,
    required this.onSend,
  });

  final TextEditingController controller;
  final bool isSending;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 14),
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: TextField(
              controller: controller,
              minLines: 1,
              maxLines: 4,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => onSend(),
              decoration: const InputDecoration(
                hintText: 'Nachricht an Jarvis...',
                border: InputBorder.none,
              ),
            ),
          ),
          IconButton(
            tooltip: 'Send',
            onPressed: isSending ? null : onSend,
            icon: isSending
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.send),
          ),
        ],
      ),
    );
  }
}

class _MemoryDrawer extends StatelessWidget {
  const _MemoryDrawer({required this.capabilities, required this.worldState});

  final Map<String, Object?> capabilities;
  final Map<String, Object?> worldState;

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: const Color(0xFF10151F),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(18),
          children: <Widget>[
            const Text(
              'MEMORY',
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            const Text(
              'Native capability matrix',
              style: TextStyle(color: Color(0xFF93C5FD)),
            ),
            const SizedBox(height: 18),
            _KeyValueSection(title: 'Capabilities', values: capabilities),
            const SizedBox(height: 18),
            _KeyValueSection(title: 'World State', values: worldState),
          ],
        ),
      ),
    );
  }
}

class _KeyValueSection extends StatelessWidget {
  const _KeyValueSection({required this.title, required this.values});

  final String title;
  final Map<String, Object?> values;

  @override
  Widget build(BuildContext context) {
    final entries = values.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        if (entries.isEmpty)
          const Text('No native data yet.', style: TextStyle(fontSize: 13)),
        for (final entry in entries)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(
                  child: Text(
                    entry.key,
                    style: const TextStyle(
                      color: Color(0xFFCBD5E1),
                      fontSize: 13,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Flexible(
                  child: Text(
                    '${entry.value}',
                    textAlign: TextAlign.end,
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
