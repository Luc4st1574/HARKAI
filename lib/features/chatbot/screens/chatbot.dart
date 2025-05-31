// Harki AI Chatbot Screen

import 'package:flutter/material.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart'; // Import flutter_dotenv

// Import the generated localizations file
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class ChatMessage {
  final String message;
  final bool isHarki;

  ChatMessage({required this.message, required this.isHarki});
}

class ChatBotScreen extends StatefulWidget {
  const ChatBotScreen({super.key});

  @override
  State<ChatBotScreen> createState() => _ChatBotScreenState();
}

class _ChatBotScreenState extends State<ChatBotScreen> {
  final TextEditingController _messageController = TextEditingController();
  final User? user = FirebaseAuth.instance.currentUser;

  late final GenerativeModel _model;
  ChatSession? _session;
  bool _isInitialized = false;
  bool _isLoadingResponse = false;
  final List<ChatMessage> _messages = [];

  final String _apiKey = dotenv.env['HARKI_KEY'] ?? "";

  // Helper to get localizations, ensure it's called where context is available
  AppLocalizations get localizations => AppLocalizations.of(context)!;

  @override
  void initState() {
    super.initState();
    // Localizations are not available in initState directly.
    // Defer messages that need localization or pass localizations instance.
    if (_apiKey.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        // Now context is available
        _showSnackbar(
          localizations.chatApiKeyNotConfigured, // Localized
          duration: const Duration(seconds: 10),
        );
      });
      setState(() {
        _isInitialized = false;
      });
    } else {
      _initializeHarki();
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _initializeHarki() async {
    if (_apiKey.isEmpty) {
      setState(() => _isInitialized = false);
      return;
    }
    try {
      // System prompt is part of the model's configuration, not directly user-facing UI text.
      // If you ever need to display parts of it or make it configurable by language, then localize it.
      const systemPrompt =
          "You are Harki, a helpful and empathetic AI assistant for citizen security. "
          "Your primary goal is to provide clear, concise, and actionable advice related to personal safety and community security. "
          "Maintain a supportive and calm tone. If a user seems distressed, offer to help them find appropriate resources if possible. "
          "Keep responses focused on the context of citizen security. Do not engage in off-topic conversations."
          "Answer in the language the user is using on the message.";

      _model = GenerativeModel(
        model: 'gemini-1.5-flash',
        apiKey: _apiKey,
        systemInstruction: Content('system', [TextPart(systemPrompt)]),
        generationConfig: GenerationConfig(
          temperature: 0.7,
          topK: 40,
          topP: 0.95,
          maxOutputTokens: 800,
        ),
      );

      _session = _model.startChat(history: []);

      setState(() => _isInitialized = true);
      _showSnackbar(localizations.chatHarkiAiInitializedSuccess, success: true); // Localized
    } catch (e) {
      _showSnackbar(
          '${localizations.chatHarkiAiInitFailedPrefix}${e.toString()}'); // Localized prefix
      setState(() => _isInitialized = false);
    }
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.isEmpty ||
        _isLoadingResponse ||
        !_isInitialized ||
        _session == null) {
      if (!_isInitialized) {
        _showSnackbar(localizations.chatHarkiAiNotInitializedOnSend); // Localized
      } else if (_session == null) {
        _showSnackbar(localizations.chatSessionNotStartedOnSend); // Localized
      }
      return;
    }
    final messageText = _messageController.text;
    _messageController.clear();

    setState(() {
      _isLoadingResponse = true;
      _messages.add(ChatMessage(message: messageText, isHarki: false));
    });

    try {
      final response = await _session!.sendMessage(Content.text(messageText));

      final harkiResponseText = response.text;
      if (harkiResponseText == null || harkiResponseText.isEmpty) {
        _showSnackbar(localizations.chatHarkiAiEmptyResponse); // Localized
        _messages.add(ChatMessage(
            message: localizations.chatHarkiAiEmptyResponseFallbackMessage, // Localized
            isHarki: true));
      } else {
        _messages.add(ChatMessage(message: harkiResponseText, isHarki: true));
      }
    } catch (e) {
      _showSnackbar(
          '${localizations.chatSendMessageFailedPrefix}${e.toString()}'); // Localized prefix
      _messages.add(ChatMessage(
          message: localizations.chatSendMessageErrorFallbackMessage, // Localized
          isHarki: true));
    } finally {
      setState(() => _isLoadingResponse = false);
    }
  }

  void _showSnackbar(String message,
      {bool success = false, Duration duration = const Duration(seconds: 4)}) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message), // Message is already localized when passed
          backgroundColor: success ? Colors.green[600] : Colors.red[600],
          duration: duration,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // localizations getter is already defined in the class for convenience

    return Scaffold(
      backgroundColor: const Color(0xFF001F3F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF001F3F),
        elevation: 0,
        title: Text(localizations.chatScreenTitle, // Localized
            style: const TextStyle(color: Color(0xFF57D463))),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 15),
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 5),
          child: Column(
            children: [
              Flexible(child: _buildMessageList()),
              if (!_isInitialized && !_isLoadingResponse) // Assuming this check is correct logic-wise
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const CircularProgressIndicator(strokeWidth: 2),
                      const SizedBox(width: 16),
                      Text(localizations.chatInitializingHarkiAiText, // Localized
                          style: const TextStyle(color: Colors.grey)),
                    ],
                  ),
                ),
              if (_isLoadingResponse) _buildLoadingIndicator(),
              _buildMessageInput(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMessageList() {
    return ListView.builder(
      reverse: true,
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        final message = _messages[_messages.length - 1 - index];
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment:
              message.isHarki ? MainAxisAlignment.start : MainAxisAlignment.end,
          children: [
            if (message.isHarki) _buildBotAvatar(),
            _buildMessageBubble(message),
            if (!message.isHarki) _buildUserAvatar(),
          ],
        );
      },
    );
  }

  Widget _buildUserAvatar() {
    return Padding(
      padding: const EdgeInsets.only(
          left: 10.0, right: 8.0, top: 12.0, bottom: 4.0),
      child: CircleAvatar(
        radius: 18,
        backgroundImage:
            user?.photoURL != null ? NetworkImage(user!.photoURL!) : null,
        backgroundColor: Colors.grey[300],
        child: user?.photoURL == null
            ? const Icon(Icons.person, color: Colors.white, size: 18)
            : null,
      ),
    );
  }

  Widget _buildBotAvatar() {
    return Padding(
      padding: const EdgeInsets.only(
          left: 8.0, right: 10.0, top: 12.0, bottom: 4.0),
      child: CircleAvatar(
        radius: 20,
        backgroundColor: const Color(0xFF57D463).withOpacity(0.2),
        child: const CircleAvatar(
          radius: 18,
          backgroundImage: AssetImage('assets/images/bot.png'),
          backgroundColor: Colors.transparent,
        ),
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage message) {
    bool isHarki = message.isHarki;
    // localizations getter is available here too if needed, but sender names are now localized
    return Flexible(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 0),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
        decoration: BoxDecoration(
          color: isHarki
              ? const Color(0xFF57D463).withAlpha((0.15 * 255).toInt())
              : Colors.blue.withAlpha((0.1 * 255).toInt()),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft:
                isHarki ? const Radius.circular(4) : const Radius.circular(16),
            bottomRight:
                isHarki ? const Radius.circular(16) : const Radius.circular(4),
          ),
        ),
        child: Column(
          crossAxisAlignment:
              isHarki ? CrossAxisAlignment.start : CrossAxisAlignment.end,
          children: [
            Text(
              isHarki ? localizations.chatSenderNameHarki : (user?.displayName ?? localizations.chatSenderNameUserFallback), // Localized
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isHarki
                    ? const Color(0xFF006400)
                    : Theme.of(context).colorScheme.primary,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              message.message, // This is the actual chat content, not localized from .arb
              style: const TextStyle(color: Colors.black87, fontSize: 15),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingIndicator() {
    // localizations getter is available
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 10),
          Text(localizations.chatHarkiIsTypingText, style: const TextStyle(color: Colors.grey)) // Localized
        ],
      ),
    );
  }

  Widget _buildMessageInput() {
    // localizations getter is available
    return Padding(
      padding: const EdgeInsets.all(10.0),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _messageController,
              enabled: _isInitialized && !_isLoadingResponse,
              style: const TextStyle(color: Colors.black, fontSize: 15),
              decoration: InputDecoration(
                hintText: _isInitialized
                    ? localizations.chatMessageHintReady // Localized
                    : localizations.chatMessageHintInitializing, // Localized
                hintStyle: TextStyle(color: Colors.grey[600]),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(25),
                  borderSide: BorderSide(color: Colors.grey[400]!),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(25),
                  borderSide: BorderSide(color: Colors.grey[400]!),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(25),
                  borderSide: BorderSide(
                      color: Theme.of(context).primaryColor, width: 1.5),
                ),
                filled: true,
                fillColor: Colors.grey[50],
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              ),
              onSubmitted: (_isLoadingResponse || !_isInitialized)
                  ? null
                  : (_) => _sendMessage(),
              textCapitalization: TextCapitalization.sentences,
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: _isLoadingResponse
                ? SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Theme.of(context).primaryColor),
                  )
                : Icon(Icons.send_rounded,
                    color: _isInitialized
                        ? Theme.of(context).primaryColor
                        : Colors.grey,
                    size: 28),
            onPressed: (_isLoadingResponse || !_isInitialized)
                ? null
                : _sendMessage,
          ),
        ],
      ),
    );
  }
}