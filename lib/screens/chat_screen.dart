import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../core/theme.dart';
import '../core/api_client.dart';
import '../core/local_storage.dart';

class ChatScreen extends StatefulWidget {
  final String chatType; // "counselor" or "legal"
  final String? caseId;

  const ChatScreen({super.key, required this.chatType, this.caseId});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  final List<Map<String, dynamic>> _messages = [];

  WebSocketChannel? _channel;
  String? _selectedCaseId;
  List<dynamic> _cases = [];
  bool _isConnected = false;
  bool _isLoadingHistory = false;
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _selectedCaseId = widget.caseId;
    _loadCases();
  }

  Future<void> _loadCases() async {
    try {
      final cases = await ApiClient().getCases();
      setState(() => _cases = cases);
      if (_selectedCaseId != null) {
        await _loadHistoryAndConnect();
      }
    } catch (e) {
      debugPrint('Error loading cases: $e');
    }
  }

  Future<void> _loadHistoryAndConnect() async {
    if (_selectedCaseId == null) return;
    setState(() => _isLoadingHistory = true);

    try {
      final history = await ApiClient().getChatHistory(_selectedCaseId!, widget.chatType);
      setState(() {
        _messages.clear();
        _messages.addAll(history.cast<Map<String, dynamic>>());
      });
    } catch (_) {}

    await _connectWebSocket();
    setState(() => _isLoadingHistory = false);
    _scrollToBottom();
  }

  Future<void> _connectWebSocket() async {
    final token = await LocalStorage().getToken();
    if (token == null || _selectedCaseId == null) return;

    _channel?.sink.close();

    final wsUrl =
        '${AppConstants.wsBaseUrl}/chat/ws/$_selectedCaseId/${widget.chatType}?token=$token';

    try {
      _channel = WebSocketChannel.connect(Uri.parse(wsUrl));
      setState(() => _isConnected = true);

      _channel!.stream.listen(
        (data) {
          final msg = jsonDecode(data as String);
          if (msg['type'] == 'message') {
            setState(() => _messages.add(msg));
            _scrollToBottom();
          }
        },
        onDone: () => setState(() => _isConnected = false),
        onError: (_) => setState(() => _isConnected = false),
      );
    } catch (e) {
      setState(() => _isConnected = false);
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _sendMessage() {
    final text = _messageController.text.trim();
    if (text.isEmpty || !_isConnected) return;

    _channel?.sink.add(jsonEncode({'type': 'message', 'content': text}));
    _messageController.clear();
  }

  @override
  void dispose() {
    _channel?.sink.close();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  String get _title =>
      widget.chatType == 'counselor' ? '💙 Counselor Chat' : '⚖️ Legal Guidance';

  String get _subtitle =>
      widget.chatType == 'counselor'
          ? 'Anonymous emotional support'
          : 'Understand your legal options';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_title, style: const TextStyle(fontSize: 16)),
            Text(_subtitle,
                style: const TextStyle(fontSize: 11, color: Colors.white70)),
          ],
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            child: Row(
              children: [
                Container(
                  width: 8, height: 8,
                  decoration: BoxDecoration(
                    color: _isConnected ? Colors.greenAccent : Colors.redAccent,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  _isConnected ? 'Live' : 'Offline',
                  style: const TextStyle(fontSize: 11, color: Colors.white70),
                ),
              ],
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Case selector
          if (_selectedCaseId == null)
            _CaseSelector(
              cases: _cases,
              onSelected: (caseId) {
                setState(() => _selectedCaseId = caseId);
                _loadHistoryAndConnect();
              },
            )
          else
            _ConnectedCaseBanner(caseId: _selectedCaseId!),

          // Disclaimer
          Container(
            color: widget.chatType == 'counselor'
                ? AppColors.accent.withOpacity(0.08)
                : AppColors.warning.withOpacity(0.08),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Icon(
                  widget.chatType == 'counselor'
                      ? Icons.favorite_border
                      : Icons.balance_outlined,
                  size: 14,
                  color: widget.chatType == 'counselor'
                      ? AppColors.accent
                      : AppColors.warning,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.chatType == 'counselor'
                        ? 'This is a confidential support chat. No legal actions are triggered here.'
                        : 'Legal guidance only. No automatic escalation. You control all actions.',
                    style: TextStyle(
                      fontSize: 11,
                      color: widget.chatType == 'counselor'
                          ? AppColors.accent
                          : AppColors.warning,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Messages
          Expanded(
            child: _isLoadingHistory
                ? const Center(child: CircularProgressIndicator())
                : _selectedCaseId == null
                    ? const Center(
                        child: Text(
                          'Select a case to start chatting',
                          style: TextStyle(color: AppColors.textHint),
                        ),
                      )
                    : _messages.isEmpty
                        ? _EmptyChatState(chatType: widget.chatType)
                        : ListView.builder(
                            controller: _scrollController,
                            padding: const EdgeInsets.all(16),
                            itemCount: _messages.length,
                            itemBuilder: (_, i) => _MessageBubble(
                              message: _messages[i],
                            ),
                          ),
          ),

          // Input
          if (_selectedCaseId != null)
            _ChatInput(
              controller: _messageController,
              isConnected: _isConnected,
              onSend: _sendMessage,
              chatType: widget.chatType,
            ),
        ],
      ),
    );
  }
}

class _CaseSelector extends StatelessWidget {
  final List<dynamic> cases;
  final Function(String) onSelected;

  const _CaseSelector({required this.cases, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    if (cases.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        color: Colors.orange.shade50,
        child: const Text(
          '⚠️ You need to create a case first before starting a chat.',
          style: TextStyle(fontSize: 13),
        ),
      );
    }

    return Container(
      color: AppColors.primary.withOpacity(0.05),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Select a case for this chat:',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: cases.map((c) => GestureDetector(
                onTap: () => onSelected(c['case_id']),
                child: Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    c['title'] ?? c['case_id'],
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
              )).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _ConnectedCaseBanner extends StatelessWidget {
  final String caseId;
  const _ConnectedCaseBanner({required this.caseId});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: AppColors.primary.withOpacity(0.06),
      child: Row(
        children: [
          const Icon(Icons.folder_outlined, size: 14, color: AppColors.primary),
          const SizedBox(width: 6),
          Text(
            'Case: $caseId',
            style: const TextStyle(
              fontSize: 11,
              fontFamily: 'monospace',
              color: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final Map<String, dynamic> message;
  const _MessageBubble({required this.message});

  bool get _isUser => message['sender_type'] == 'user';
  bool get _isSystem => message['sender_type'] == 'system';

  @override
  Widget build(BuildContext context) {
    if (_isSystem) {
      return Center(
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 8),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.divider,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            message['content'] ?? '',
            style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
          ),
        ),
      );
    }

    final time = message['timestamp'] != null
        ? DateTime.tryParse(message['timestamp'])
        : null;

    return Align(
      alignment: _isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Column(
        crossAxisAlignment:
            _isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.symmetric(vertical: 4),
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.72,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: _isUser ? AppColors.userBubble : AppColors.counselorBubble,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(16),
                topRight: const Radius.circular(16),
                bottomLeft: Radius.circular(_isUser ? 16 : 4),
                bottomRight: Radius.circular(_isUser ? 4 : 16),
              ),
            ),
            child: Text(
              message['content'] ?? '',
              style: TextStyle(
                color: _isUser ? Colors.white : AppColors.textPrimary,
                fontSize: 14,
                height: 1.4,
              ),
            ),
          ),
          if (time != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                DateFormat('hh:mm a').format(time),
                style: const TextStyle(fontSize: 10, color: AppColors.textHint),
              ),
            ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }
}

class _ChatInput extends StatelessWidget {
  final TextEditingController controller;
  final bool isConnected;
  final VoidCallback onSend;
  final String chatType;

  const _ChatInput({
    required this.controller,
    required this.isConnected,
    required this.onSend,
    required this.chatType,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        left: 16, right: 8, top: 8,
        bottom: MediaQuery.of(context).viewInsets.bottom + 8,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.divider)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              maxLines: 4,
              minLines: 1,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                hintText: isConnected
                    ? 'Type a message...'
                    : 'Connecting...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: AppColors.surface,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 10,
                ),
              ),
              onSubmitted: (_) => onSend(),
            ),
          ),
          const SizedBox(width: 8),
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            child: IconButton(
              onPressed: isConnected ? onSend : null,
              style: IconButton.styleFrom(
                backgroundColor: isConnected ? AppColors.primary : AppColors.divider,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.all(12),
              ),
              icon: const Icon(Icons.send_rounded, size: 20),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyChatState extends StatelessWidget {
  final String chatType;
  const _EmptyChatState({required this.chatType});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              chatType == 'counselor'
                  ? Icons.favorite_border
                  : Icons.balance_outlined,
              size: 56,
              color: AppColors.textHint,
            ),
            const SizedBox(height: 16),
            Text(
              chatType == 'counselor'
                  ? 'Start a conversation with a counselor'
                  : 'Get guidance on your legal options',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Your identity is anonymous. This conversation is private.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textHint, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
